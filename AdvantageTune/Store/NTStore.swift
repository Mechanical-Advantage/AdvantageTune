// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation
import SwiftUI

public enum ConnectionStatus: Equatable {
  case disconnected
  case connecting
  case connected(latencyMs: Double)

  public var isConnected: Bool {
    if case .connected = self { return true }
    return false
  }
}

public struct TunedEntry: Identifiable, Hashable, Sendable {
  public var id: String { topicPath }
  public let topicPath: String
  public let topicType: String
  public var currentValue: TopicValue
  public var originalValue: TopicValue?
  public var pubuid: Int
  public var lastModified: Date

  public init(
    topicPath: String,
    topicType: String,
    currentValue: TopicValue,
    originalValue: TopicValue? = nil,
    pubuid: Int,
    lastModified: Date = Date()
  ) {
    self.topicPath = topicPath
    self.topicType = topicType
    self.currentValue = currentValue
    self.originalValue = originalValue
    self.pubuid = pubuid
    self.lastModified = lastModified
  }
}

@Observable
@MainActor
public final class NTStore: NT4ClientDelegate {
  private let client = NT4Client()

  // MARK: - Server & Connection State
  public var serverHost: String {
    didSet {
      UserDefaults.standard.set(serverHost, forKey: UserDefaultsKeys.serverHost)
      if isDemoMode {
        connect()
      } else if oldValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "demo" {
        disconnect()
        topicsByName.removeAll()
        topicsById.removeAll()
        latestValues.removeAll()
        valueTimestamps.removeAll()
        rebuildTree()
      }
    }
  }

  public var isDemoMode: Bool {
    parsedHost.lowercased() == "demo"
  }

  public var parsedHost: String {
    let trimmed = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.hasPrefix("[") && trimmed.contains("]") {
      if let closeBracket = trimmed.firstIndex(of: "]") {
        let hostInside = String(trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket])
        return hostInside.isEmpty ? NT4Constants.defaultHost : hostInside
      }
    }
    if let colonIndex = trimmed.lastIndex(of: ":") {
      let hostPart = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
      return hostPart.isEmpty ? NT4Constants.defaultHost : hostPart
    }
    return trimmed.isEmpty ? NT4Constants.defaultHost : trimmed
  }

  public var parsedPort: Int {
    let trimmed = serverHost.trimmingCharacters(in: .whitespacesAndNewlines)
    if let colonIndex = trimmed.lastIndex(of: ":") {
      let portPart = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(
        in: .whitespacesAndNewlines)
      if let customPort = Int(portPart), customPort > 0 && customPort <= 65535 {
        return customPort
      }
    }
    return NT4Constants.defaultPort
  }

  public private(set) var connectionStatus: ConnectionStatus = .disconnected
  public private(set) var isConnectionRequested: Bool = false
  private var lastLatencyUpdate: Date = .distantPast

  // MARK: - Data State
  public private(set) var topicsByName: [String: NT4Topic] = [:]
  public private(set) var topicsById: [Int: NT4Topic] = [:]
  public var latestValues: [String: TopicValue] = [:]
  public private(set) var valueTimestamps: [String: Date] = [:]
  public private(set) var topicTree: [TopicNode] = []

  // MARK: - Publishing & Tuning
  public private(set) var tunedEntries: [String: TunedEntry] = [:]  // Path -> TunedEntry
  private var nextPubUid: Int = 0
  private var nextSubUid: Int = 0

  public func isPublished(topicName: String) -> Bool {
    tunedEntries[topicName] != nil
  }

  public var publishedTopics: [String: Int] {
    tunedEntries.mapValues { $0.pubuid }
  }

  // MARK: - Subscription Tracking
  private struct ActiveSub {
    let subuid: Int
    var refCount: Int
  }
  private var activePathSubs: [String: ActiveSub] = [:]

  // Rate-limit tree rebuilding
  private var isTreeUpdatePending = false

  public init() {
    let savedHost =
      UserDefaults.standard.string(forKey: UserDefaultsKeys.serverHost)
      ?? NT4Constants.defaultHost
    self.serverHost = savedHost
    self.client.delegate = self
  }

  // MARK: - Connection Actions

  public func connect() {
    isConnectionRequested = true
    if isDemoMode {
      client.disconnect()
      loadDemoMode()
      return
    }
    connectionStatus = .connecting
    client.connect(host: parsedHost, port: parsedPort)
  }

  private func loadDemoMode() {
    connectionStatus = .connected(latencyMs: 0)
    topicsByName.removeAll()
    topicsById.removeAll()
    latestValues.removeAll()
    valueTimestamps.removeAll()

    Task { @MainActor in
      let demoData = await DemoDataProvider.loadDemoData()
      guard self.isDemoMode && self.isConnectionRequested else { return }

      let now = Date()
      for topic in demoData.topics {
        self.topicsByName[topic.name] = topic
        self.topicsById[topic.id] = topic
      }
      for (name, val) in demoData.values {
        self.latestValues[name] = val
        self.valueTimestamps[name] = now
      }
      self.rebuildTree()
      self.republishTunedValues()
    }
  }

  public func disconnect() {
    isConnectionRequested = false
    connectionStatus = .disconnected
    if !isDemoMode {
      client.disconnect()
    }
  }

  public func reconnect() {
    disconnect()
    connect()
  }

  // MARK: - Subscription Management

  /// Acquires an on-demand streaming subscription for an exact topic.
  public func acquireSubscription(for topicName: String) {
    guard !topicName.isEmpty else { return }

    if var existing = activePathSubs[topicName] {
      existing.refCount += 1
      activePathSubs[topicName] = existing
    } else {
      let subuid = nextSubUid
      nextSubUid += 1
      activePathSubs[topicName] = ActiveSub(subuid: subuid, refCount: 1)

      if connectionStatus.isConnected && !isDemoMode {
        let options = NT4SubscriptionOptions(
          periodic: 0.02, all: false, topicsonly: false, prefix: false)
        client.subscribe(topics: [topicName], subuid: subuid, options: options)
      }
    }
  }

  /// Acquires on-demand streaming subscriptions for a batch of exact topic names.
  public func acquireSubscriptions(for topicNames: [String]) {
    for name in topicNames {
      acquireSubscription(for: name)
    }
  }

  /// Releases the on-demand streaming subscription for an exact topic.
  public func releaseSubscription(for topicName: String) {
    guard var existing = activePathSubs[topicName] else { return }
    existing.refCount -= 1

    if existing.refCount <= 0 {
      activePathSubs.removeValue(forKey: topicName)
      if connectionStatus.isConnected && !isDemoMode {
        client.unsubscribe(subuid: existing.subuid)
      }
    } else {
      activePathSubs[topicName] = existing
    }
  }

  /// Releases on-demand streaming subscriptions for a batch of exact topic names.
  public func releaseSubscriptions(for topicNames: [String]) {
    for name in topicNames {
      releaseSubscription(for: name)
    }
  }

  // MARK: - Value Publishing & Editing

  /// Updates a topic value. If not published, automatically publishes it first.
  public func updateValue(for topic: NT4Topic, newValue: TopicValue) {
    let topicName = topic.name
    let now = Date()

    let pubuid: Int
    let orig: TopicValue?

    if let existing = tunedEntries[topicName] {
      pubuid = existing.pubuid
      orig = existing.originalValue ?? latestValues[topicName]
    } else {
      pubuid = nextPubUid
      nextPubUid += 1
      orig = latestValues[topicName]
      if !isDemoMode {
        client.publish(
          name: topicName, type: topic.type, pubuid: pubuid, properties: topic.properties)
      }
    }

    // Record in tuned entries
    tunedEntries[topicName] = TunedEntry(
      topicPath: topicName,
      topicType: topic.type,
      currentValue: newValue,
      originalValue: orig,
      pubuid: pubuid,
      lastModified: now
    )

    // Send new value to server
    if !isDemoMode {
      client.setValue(newValue, forPubuid: pubuid, typeIndex: topic.typeIndex)
    }

    // Update local state
    latestValues[topicName] = newValue
    valueTimestamps[topicName] = now
  }

  /// Reverts a topic's value back to its baseline server value.
  public func revertValue(name: String) {
    guard let entry = tunedEntries[name], let orig = entry.originalValue else { return }

    // Push baseline value to server
    if !isDemoMode, let topic = topicsByName[name] {
      client.setValue(orig, forPubuid: entry.pubuid, typeIndex: topic.typeIndex)
    }

    latestValues[name] = orig
    let now = Date()
    valueTimestamps[name] = now

    var updated = entry
    updated.currentValue = orig
    updated.lastModified = now
    tunedEntries[name] = updated
  }

  /// Unpublishes a topic and removes it from tuned entries.
  public func unpublishTopic(name: String) {
    guard let entry = tunedEntries.removeValue(forKey: name) else { return }
    if !isDemoMode {
      client.unpublish(pubuid: entry.pubuid)
    }
  }

  /// Convenience to revert value and unpublish topic.
  public func revertAndUnpublishTopic(name: String) {
    if let entry = tunedEntries[name], let orig = entry.originalValue {
      if !isDemoMode {
        let typeIndex = NT4Constants.typeIndex(for: entry.topicType)
        client.setValue(orig, forPubuid: entry.pubuid, typeIndex: typeIndex)
      }
      latestValues[name] = orig
      valueTimestamps[name] = Date()
    }
    unpublishTopic(name: name)
  }

  /// Reverts all tuned values back to baseline server values, unpublishes them, and clears tuned entries.
  public func revertAllTunedTopics() {
    let topicNames = Array(tunedEntries.keys)
    for name in topicNames {
      revertAndUnpublishTopic(name: name)
    }
  }

  /// Unpublishes all currently published tuned topics and clears tuned entries.
  public func unpublishAllTunedTopics() {
    let topicNames = Array(tunedEntries.keys)
    for name in topicNames {
      unpublishTopic(name: name)
    }
  }

  /// Clears all tuned values history.
  public func clearTunedHistory() {
    unpublishAllTunedTopics()
  }

  // MARK: - Search

  public func searchTopics(query: String, filter: String = "All", limit: Int = 100) -> [NT4Topic] {
    let clean = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !clean.isEmpty else {
      return []  // Never return thousands of topics when query is empty
    }

    var matches: [NT4Topic] = []
    matches.reserveCapacity(min(limit, 100))

    for topic in topicsByName.values {
      guard !topic.isSchema else { continue }

      // Filter match
      let matchesFilter: Bool
      switch filter {
      case "Numeric":
        matchesFilter = (topic.type == "double" || topic.type == "float" || topic.type == "int")
      case "Boolean":
        matchesFilter = (topic.type == "boolean")
      case "String":
        matchesFilter = (topic.type == "string" || topic.type == "json")
      case "Arrays":
        matchesFilter = topic.isArray
      case "Struct/Proto":
        matchesFilter = (topic.isStruct || topic.isProtobuf)
      default:
        matchesFilter = true
      }

      guard matchesFilter else { continue }

      // Query match
      if topic.name.lowercased().contains(clean) || topic.type.lowercased().contains(clean) {
        matches.append(topic)
        if matches.count >= limit { break }
      }
    }

    return matches.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  // MARK: - Tree Lookups & Rebuilding

  public func node(for path: String) -> TopicNode? {
    func find(in nodes: [TopicNode], target: String) -> TopicNode? {
      for node in nodes {
        if node.path == target { return node }
        if case .folder(_, _, _, let children) = node {
          if let found = find(in: children, target: target) {
            return found
          }
        }
      }
      return nil
    }
    return find(in: topicTree, target: path)
  }

  private func scheduleTreeUpdate() {
    guard !isTreeUpdatePending else { return }
    isTreeUpdatePending = true

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
      guard let self = self else { return }
      self.isTreeUpdatePending = false
      self.rebuildTree()
    }
  }

  private func rebuildTree() {
    self.topicTree = TopicTreeBuilder.buildTree(
      topics: Array(topicsByName.values),
      values: latestValues,
      timestamps: valueTimestamps,
      hideSchemaTopics: true
    )
  }

  /// Republishes all active tuned values upon connection or reconnection.
  public func republishTunedValues() {
    for (topicName, var entry) in tunedEntries {
      let pubuid = nextPubUid
      nextPubUid += 1
      entry.pubuid = pubuid
      tunedEntries[topicName] = entry

      let topicType = entry.topicType
      let typeIndex = NT4Constants.typeIndex(for: topicType)
      let properties = topicsByName[topicName]?.properties ?? [:]

      if !isDemoMode {
        client.publish(name: topicName, type: topicType, pubuid: pubuid, properties: properties)
        client.setValue(entry.currentValue, forPubuid: pubuid, typeIndex: typeIndex)
      }

      latestValues[topicName] = entry.currentValue
      valueTimestamps[topicName] = Date()
    }
  }

  // MARK: - NT4ClientDelegate Callbacks

  public nonisolated func clientDidConnect(_ client: NT4Client) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      self.connectionStatus = .connected(latencyMs: 0)
      self.lastLatencyUpdate = .distantPast

      // Clear old session topics before receiving fresh announcements
      self.topicsByName.removeAll()
      self.topicsById.removeAll()
      self.rebuildTree()

      self.nextSubUid = 0
      self.nextPubUid = 0

      // Subscribe to topic list
      let rootOpts = NT4SubscriptionOptions(
        periodic: 0.02, all: false, topicsonly: true, prefix: true)
      let rootSubUid = self.nextSubUid
      self.nextSubUid += 1
      self.client.subscribe(topics: [""], subuid: rootSubUid, options: rootOpts)

      // Subscribe to schemas
      let schemaOpts = NT4SubscriptionOptions(
        periodic: 0.02, all: true, topicsonly: false, prefix: true)
      let schemaSubUid = self.nextSubUid
      self.nextSubUid += 1
      self.client.subscribe(
        topics: ["/.schema/", "/AdvantageKit/.schema/"], subuid: schemaSubUid, options: schemaOpts)

      // Restore any active view subscriptions
      var remappedActiveSubs: [String: ActiveSub] = [:]
      for (path, activeSub) in self.activePathSubs {
        let subuid = self.nextSubUid
        self.nextSubUid += 1
        remappedActiveSubs[path] = ActiveSub(subuid: subuid, refCount: activeSub.refCount)
        let options = NT4SubscriptionOptions(
          periodic: 0.02, all: false, topicsonly: false, prefix: false)
        self.client.subscribe(topics: [path], subuid: subuid, options: options)
      }
      self.activePathSubs = remappedActiveSubs

      // Republish all tuned values
      self.republishTunedValues()
    }
  }

  public nonisolated func clientDidDisconnect(_ client: NT4Client, error: Error?) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      self.lastLatencyUpdate = .distantPast
      if self.isConnectionRequested {
        self.connectionStatus = .connecting
      } else {
        self.connectionStatus = .disconnected
      }
    }
  }

  public nonisolated func client(_ client: NT4Client, didAnnounceTopics topics: [NT4Topic]) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      for topic in topics {
        self.topicsByName[topic.name] = topic
        self.topicsById[topic.id] = topic
      }
      self.scheduleTreeUpdate()
    }
  }

  public nonisolated func client(
    _ client: NT4Client, didUnannounceTopic topicName: String, topicId: Int
  ) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      self.topicsByName.removeValue(forKey: topicName)
      self.topicsById.removeValue(forKey: topicId)
      self.latestValues.removeValue(forKey: topicName)
      self.valueTimestamps.removeValue(forKey: topicName)
      self.scheduleTreeUpdate()
    }
  }

  public nonisolated func client(
    _ client: NT4Client, didUpdateProperties topicName: String, properties: [String: String]
  ) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      if var topic = self.topicsByName[topicName] {
        for (k, v) in properties {
          topic.properties[k] = v
        }
        self.topicsByName[topicName] = topic
        if let id = topic.id as Int? {
          self.topicsById[id] = topic
        }
        self.scheduleTreeUpdate()
      }
    }
  }

  public nonisolated func client(
    _ client: NT4Client,
    didReceiveValues values: [(
      topicId: Int, topicName: String, topicType: String, timestampUs: Int64, value: TopicValue
    )]
  ) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      let now = Date()
      for item in values {
        let topicName =
          item.topicName.isEmpty ? (self.topicsById[item.topicId]?.name ?? "") : item.topicName
        guard !topicName.isEmpty else { continue }
        let topicType =
          item.topicType.isEmpty ? (self.topicsById[item.topicId]?.type ?? "") : item.topicType

        var processedValue = item.value

        // Process schema registrations
        if topicName.contains(".schema/struct:") {
          let schemaName = topicName.components(separatedBy: ".schema/struct:").last ?? ""
          if case .raw(let data) = item.value {
            await StructDecoder.shared.addSchema(name: schemaName, schemaData: data)
          }
        } else if topicName.contains(".schema/proto:") {
          let schemaName = topicName.components(separatedBy: ".schema/proto:").last ?? ""
          if case .raw(let data) = item.value {
            await ProtoSchemaRegistry.shared.addDescriptor(name: schemaName, data: data)
          }
        }

        // Process struct / proto decoding for regular topics
        if case .raw(let rawData) = item.value {
          let isStruct = topicType.hasPrefix("struct:")
          let isProto = topicType.hasPrefix("proto:")
          if isStruct {
            if let decoded = await StructDecoder.shared.decode(typeName: topicType, data: rawData) {
              processedValue = .structValue(typeName: topicType, value: decoded, raw: rawData)
            }
          } else if isProto {
            if let decoded = await ProtoDecoder.shared.decode(typeName: topicType, data: rawData) {
              processedValue = .structValue(typeName: topicType, value: decoded, raw: rawData)
            } else {
              processedValue = .protoRaw(typeName: topicType, data: rawData)
            }
          }
        }

        self.latestValues[topicName] = processedValue
        self.valueTimestamps[topicName] = now
      }
    }
  }

  public nonisolated func client(_ client: NT4Client, didUpdateLatencyMs latencyMs: Double) {
    Task { @MainActor in
      guard !self.isDemoMode else { return }
      guard self.connectionStatus.isConnected else { return }
      let now = Date()
      if now.timeIntervalSince(self.lastLatencyUpdate) >= 1.0 {
        self.lastLatencyUpdate = now
        self.connectionStatus = .connected(latencyMs: latencyMs)
      }
    }
  }
}
