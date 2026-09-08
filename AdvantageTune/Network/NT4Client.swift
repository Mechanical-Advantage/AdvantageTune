// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation
import Starscream

public protocol NT4ClientDelegate: AnyObject, Sendable {
  func clientDidConnect(_ client: NT4Client)
  func clientDidDisconnect(_ client: NT4Client, error: Error?)
  func client(_ client: NT4Client, didAnnounceTopics topics: [NT4Topic])
  func client(_ client: NT4Client, didUnannounceTopic topicName: String, topicId: Int)
  func client(
    _ client: NT4Client, didUpdateProperties topicName: String, properties: [String: String])
  func client(
    _ client: NT4Client,
    didReceiveValues values: [(
      topicId: Int, topicName: String, topicType: String, timestampUs: Int64, value: TopicValue
    )])
  func client(_ client: NT4Client, didUpdateLatencyMs latencyMs: Double)
}

public final class NT4Client: WebSocketDelegate, @unchecked Sendable {
  public weak var delegate: NT4ClientDelegate?

  private var socket: WebSocket?
  private var rttSocket: WebSocket?
  private let timeSync = NT4TimeSync()

  private var currentHost: String = NT4Constants.defaultHost
  private var currentPort: Int = NT4Constants.defaultPort
  private var isConnectionRequested: Bool = false
  private var isConnected: Bool = false
  private var isV41: Bool = false

  // Heartbeat & timeout tracking
  private var lastReceivedDate: Date = .distantPast
  private let rttPeriodV40: TimeInterval = 1.0
  private let rttPeriodV41: TimeInterval = 0.25
  private let serverTimeoutV40: TimeInterval = 5.0
  private let serverTimeoutV41: TimeInterval = 1.0
  private let connectTimeoutInterval: TimeInterval = 3.0  // Timeout for initial TCP/mDNS handshake

  private var heartbeatTimer: Timer?
  private var connectWatchdogTimer: Timer?
  private var reconnectTimer: Timer?

  private var subscriptions: [Int: NT4SubscriptionOptions] = [:]
  private var publishedTopics: [String: NT4Topic] = [:]
  private var serverTopicsById: [Int: NT4Topic] = [:]
  private var serverTopicsByName: [String: NT4Topic] = [:]

  public init() {}

  private var currentTimeoutInterval: TimeInterval {
    (isV41 && rttSocket != nil) ? serverTimeoutV41 : serverTimeoutV40
  }

  private var currentPingPeriod: TimeInterval {
    (isV41 && rttSocket != nil) ? rttPeriodV41 : rttPeriodV40
  }

  // MARK: - Connection Management

  public func connect(host: String = NT4Constants.defaultHost, port: Int = NT4Constants.defaultPort) {
    self.currentHost = host
    self.currentPort = port
    self.isConnectionRequested = true

    startConnectionAttempt()
  }

  public func disconnect() {
    self.isConnectionRequested = false
    self.isConnected = false
    self.isV41 = false
    stopAllTimers()
    timeSync.reset()
    serverTopicsById.removeAll()
    serverTopicsByName.removeAll()
    publishedTopics.removeAll()
    subscriptions.removeAll()

    let oldSocket = socket
    socket?.delegate = nil
    socket = nil

    let oldRttSocket = rttSocket
    rttSocket?.delegate = nil
    rttSocket = nil

    oldSocket?.disconnect()
    oldRttSocket?.disconnect()

    delegate?.clientDidDisconnect(self, error: nil)
  }

  private func startConnectionAttempt() {
    guard isConnectionRequested else {
      return
    }

    // Clean up old sockets safely by removing delegate first
    let oldSocket = socket
    socket?.delegate = nil
    socket = nil

    let oldRttSocket = rttSocket
    rttSocket?.delegate = nil
    rttSocket = nil
    self.isV41 = false

    oldSocket?.disconnect()
    oldRttSocket?.disconnect()

    let cleanHost = currentHost.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanHost.isEmpty,
      let url = URL(string: "ws://\(cleanHost):\(currentPort)/nt/\(NT4Constants.appName)")
    else {
      scheduleReconnect()
      return
    }

    var request = URLRequest(url: url)
    request.timeoutInterval = connectTimeoutInterval
    request.setValue(NT4Constants.defaultSubprotocols, forHTTPHeaderField: "Sec-WebSocket-Protocol")

    let ws = WebSocket(request: request)
    ws.delegate = self

    self.socket = ws

    // Arm connection handshake timeout watchdog
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.connectWatchdogTimer?.invalidate()
      self.connectWatchdogTimer = Timer.scheduledTimer(
        withTimeInterval: self.connectTimeoutInterval, repeats: false
      ) { [weak self] _ in
        guard let self = self else { return }
        let connected = self.isConnected
        let requested = self.isConnectionRequested

        if requested && !connected {
          let timeoutError = NSError(
            domain: "NT4Client",
            code: -1001,
            userInfo: [NSLocalizedDescriptionKey: "Connection handshake timed out"]
          )
          self.handleDisconnect(error: timeoutError)
        }
      }
    }

    ws.connect()
  }

  private func startRttSocket() {
    let cleanHost = currentHost.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanHost.isEmpty,
      let url = URL(string: "ws://\(cleanHost):\(currentPort)/nt/\(NT4Constants.appName)")
    else { return }

    var request = URLRequest(url: url)
    request.timeoutInterval = connectTimeoutInterval
    request.setValue(NT4Constants.subprotocolRTT, forHTTPHeaderField: "Sec-WebSocket-Protocol")

    let rttWs = WebSocket(request: request)
    rttWs.delegate = self

    let oldRtt = self.rttSocket
    self.rttSocket = rttWs

    oldRtt?.delegate = nil
    oldRtt?.disconnect()

    rttWs.connect()
  }

  private func scheduleReconnect() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      let requested = self.isConnectionRequested
      let connected = self.isConnected

      guard requested && !connected else { return }

      self.reconnectTimer?.invalidate()
      self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) {
        [weak self] _ in
        self?.startConnectionAttempt()
      }
    }
  }

  private func startHeartbeat() {
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.connectWatchdogTimer?.invalidate()
      self.connectWatchdogTimer = nil

      self.heartbeatTimer?.invalidate()
      let period = self.currentPingPeriod

      self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: true) {
        [weak self] _ in
        self?.checkHeartbeatAndPing()
      }
    }
  }

  private func stopAllTimers() {
    DispatchQueue.main.async { [weak self] in
      self?.heartbeatTimer?.invalidate()
      self?.heartbeatTimer = nil
      self?.connectWatchdogTimer?.invalidate()
      self?.connectWatchdogTimer = nil
      self?.reconnectTimer?.invalidate()
      self?.reconnectTimer = nil
    }
  }

  private func checkHeartbeatAndPing() {
    guard isConnected else {
      return
    }

    let timeSinceLastRx = Date().timeIntervalSince(lastReceivedDate)
    let timeout = currentTimeoutInterval
    if timeSinceLastRx > timeout {
      let timeoutError = NSError(
        domain: "NT4Client",
        code: -1002,
        userInfo: [
          NSLocalizedDescriptionKey:
            "Server heartbeat timed out (no response for \(String(format: "%.1f", timeSinceLastRx))s)"
        ]
      )
      handleDisconnect(error: timeoutError)
      return
    }

    sendRttPing()
  }

  // MARK: - Subscriptions & Publishing

  public func subscribe(topics: [String], subuid: Int, options: NT4SubscriptionOptions) {
    subscriptions[subuid] = options

    let msg = NT4ClientMessage.subscribe(topics: topics, subuid: subuid, options: options)
    sendClientMessage(msg)
  }

  public func unsubscribe(subuid: Int) {
    subscriptions.removeValue(forKey: subuid)

    let msg = NT4ClientMessage.unsubscribe(subuid: subuid)
    sendClientMessage(msg)
  }

  public func publish(name: String, type: String, pubuid: Int, properties: [String: String] = [:]) {
    let topic = NT4Topic(id: pubuid, name: name, type: type, properties: properties, pubuid: pubuid)
    publishedTopics[name] = topic

    let msg = NT4ClientMessage.publish(
      name: name, type: type, pubuid: pubuid, properties: properties)
    sendClientMessage(msg)
  }

  public func unpublish(pubuid: Int) {
    publishedTopics = publishedTopics.filter { $0.value.pubuid != pubuid }

    let msg = NT4ClientMessage.unpublish(pubuid: pubuid)
    sendClientMessage(msg)
  }

  public func setValue(_ value: TopicValue, forPubuid pubuid: Int, typeIndex: Int) {
    let timestampUs = timeSync.serverTimeUs
    let payload: MessagePackStream.Value = .array([
      .int(Int64(pubuid)),
      .int(timestampUs),
      .int(Int64(typeIndex)),
      value.toMessagePackStreamValue(),
    ])

    let data = MessagePackStream.pack(payload)
    socket?.write(data: data)
  }

  private func sendClientMessage(_ message: NT4ClientMessage) {
    guard let data = message.toJSONData(),
      let string = String(data: data, encoding: .utf8)
    else { return }
    socket?.write(string: string)
  }

  private func sendRttPing() {
    guard isConnected else {
      return
    }
    let ping = timeSync.createPingValue()
    let targetSocket = rttSocket ?? socket

    let pingArray: MessagePackStream.Value = .array([
      .int(Int64(ping.topicId)),
      .int(ping.timestampUs),
      .int(Int64(ping.typeIdx)),
      .int(ping.value),
    ])
    let data = MessagePackStream.pack(pingArray)
    targetSocket?.write(data: data)
  }

  // MARK: - Starscream WebSocketDelegate

  public func didReceive(event: WebSocketEvent, client: any WebSocketClient) {
    let isPrimary = (client === socket)
    let isRTT = (client === rttSocket)
    guard isPrimary || isRTT else {
      return
    }

    if isRTT {
      handleRttSocketEvent(event)
    } else {
      handlePrimarySocketEvent(event)
    }
  }

  private func handleRttSocketEvent(_ event: WebSocketEvent) {
    switch event {
    case .connected:
      lastReceivedDate = Date()
      sendRttPing()
      startHeartbeat()

    case .binary(let data):
      lastReceivedDate = Date()
      handleBinaryMessage(data)

    case .disconnected, .error, .cancelled, .peerClosed:
      rttSocket?.delegate = nil
      rttSocket = nil
      startHeartbeat()  // Fall back to primary socket ping schedule

    case .text, .ping, .pong, .viabilityChanged, .reconnectSuggested:
      break
    }
  }

  private func handlePrimarySocketEvent(_ event: WebSocketEvent) {
    switch event {
    case .connected(let headers):
      let protocolHeader =
        headers.first { $0.key.caseInsensitiveCompare("Sec-WebSocket-Protocol") == .orderedSame }?
        .value ?? ""
      let negotiatedV41 = protocolHeader.contains(NT4Constants.subprotocolV41)

      isConnected = true
      isV41 = negotiatedV41
      lastReceivedDate = Date()
      serverTopicsById.removeAll()
      serverTopicsByName.removeAll()

      DispatchQueue.main.async { [weak self] in
        self?.reconnectTimer?.invalidate()
        self?.reconnectTimer = nil
        self?.connectWatchdogTimer?.invalidate()
        self?.connectWatchdogTimer = nil
      }

      if negotiatedV41 {
        startRttSocket()
      } else {
        sendRttPing()
      }

      startHeartbeat()
      delegate?.clientDidConnect(self)

    case .disconnected(let reason, let code):
      handleDisconnect(
        error: NSError(
          domain: "NT4", code: Int(code), userInfo: [NSLocalizedDescriptionKey: reason]))

    case .text(let string):
      lastReceivedDate = Date()
      handleTextMessage(string)

    case .binary(let data):
      lastReceivedDate = Date()
      handleBinaryMessage(data)

    case .error(let error):
      handleDisconnect(error: error)

    case .cancelled, .peerClosed:
      handleDisconnect(error: nil)

    case .ping, .pong:
      lastReceivedDate = Date()

    case .viabilityChanged, .reconnectSuggested:
      break
    }
  }

  private func handleDisconnect(error: Error?) {
    let wasConnected = isConnected
    let requested = isConnectionRequested
    isConnected = false
    isV41 = false
    timeSync.reset()
    serverTopicsById.removeAll()
    serverTopicsByName.removeAll()
    publishedTopics.removeAll()
    subscriptions.removeAll()

    let oldSocket = socket
    socket?.delegate = nil
    socket = nil

    let oldRttSocket = rttSocket
    rttSocket?.delegate = nil
    rttSocket = nil

    oldSocket?.disconnect()
    oldRttSocket?.disconnect()

    stopAllTimers()

    if wasConnected || requested {
      delegate?.clientDidDisconnect(self, error: error)
    }

    if requested {
      scheduleReconnect()
    }
  }

  // MARK: - Message Parsers

  private func handleTextMessage(_ string: String) {
    guard let data = string.data(using: .utf8),
      let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return
    }

    var announcedBatch: [NT4Topic] = []

    for msg in json {
      guard let method = msg["method"] as? String,
        let params = msg["params"] as? [String: Any]
      else { continue }

      switch method {
      case "announce":
        guard let name = params["name"] as? String,
          let id = params["id"] as? Int,
          let type = params["type"] as? String
        else { continue }

        let rawProps = params["properties"] as? [String: Any] ?? [:]
        var props: [String: String] = [:]
        for (k, v) in rawProps {
          props[k] = "\(v)"
        }
        let pubuid = params["pubuid"] as? Int

        let topic = NT4Topic(id: id, name: name, type: type, properties: props, pubuid: pubuid)

        serverTopicsById[id] = topic
        serverTopicsByName[name] = topic

        announcedBatch.append(topic)

      case "unannounce":
        guard let name = params["name"] as? String,
          let id = params["id"] as? Int
        else { continue }

        serverTopicsById.removeValue(forKey: id)
        serverTopicsByName.removeValue(forKey: name)

        delegate?.client(self, didUnannounceTopic: name, topicId: id)

      case "properties":
        guard let name = params["name"] as? String,
          let update = params["update"] as? [String: Any]
        else { continue }

        var props: [String: String] = [:]
        for (k, v) in update {
          props[k] = "\(v)"
        }

        if var existing = serverTopicsByName[name] {
          for (k, v) in props {
            existing.properties[k] = v
          }
          serverTopicsByName[name] = existing
          if let id = existing.id as Int? {
            serverTopicsById[id] = existing
          }
        }

        delegate?.client(self, didUpdateProperties: name, properties: props)

      default:
        break
      }
    }

    if !announcedBatch.isEmpty {
      delegate?.client(self, didAnnounceTopics: announcedBatch)
    }
  }

  private func handleBinaryMessage(_ data: Data) {
    let unpackedValues = MessagePackStream.unpackAll(from: data)
    var valueBatch: [(topicId: Int, topicName: String, topicType: String, timestampUs: Int64, value: TopicValue)] =
      []

    for val in unpackedValues {
      if case .array(let elements) = val, elements.count >= 4,
        let topicId = elements[0].asInt64.map(Int.init),
        let timestampUs = elements[1].asInt64,
        let typeIdx = elements[2].asInt64.map(Int.init)
      {

        let rawVal = elements[3]

        if topicId == -1 {
          let clientSendUs = rawVal.asInt64 ?? 0
          let latency = timeSync.handlePong(
            serverTimestampUs: timestampUs, clientSendTimestampUs: clientSendUs)
          delegate?.client(self, didUpdateLatencyMs: latency)
        } else {
          let topic = serverTopicsById[topicId]

          let topicValue = TopicValue.from(typeIndex: typeIdx, value: rawVal)
          let topicName = topic?.name ?? ""
          let topicType = topic?.type ?? ""
          valueBatch.append(
            (
              topicId: topicId, topicName: topicName, topicType: topicType,
              timestampUs: timestampUs, value: topicValue
            ))
        }
      }
    }

    if !valueBatch.isEmpty {
      delegate?.client(self, didReceiveValues: valueBatch)
    }
  }
}
