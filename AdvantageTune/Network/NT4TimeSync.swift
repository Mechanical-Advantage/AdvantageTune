// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

public final class NT4TimeSync: @unchecked Sendable {
  private var serverTimeOffsetUs: Int64 = 0
  private var networkLatencyUs: Int64 = 0
  private var smoothedLatencyMs: Double = 0
  private var hasSynced: Bool = false

  /// Exponential moving average smoothing factor
  private let smoothingFactor: Double = 0.1

  public init() {}

  public static func clientTimeUs() -> Int64 {
    Int64(Date().timeIntervalSince1970 * 1_000_000)
  }

  /// Generates the payload for an outgoing RTT ping frame `[-1, 0, 2, client_time_us]`
  public func createPingValue() -> (topicId: Int, timestampUs: Int64, typeIdx: Int, value: Int64) {
    return (-1, 0, 2, Self.clientTimeUs())
  }

  /// Handles an incoming RTT pong frame from the server: `[-1, server_time_us, 2, client_send_time_us]`
  public func handlePong(serverTimestampUs: Int64, clientSendTimestampUs: Int64) -> Double {
    let clientReceiveUs = Self.clientTimeUs()
    let rttUs = max(0, clientReceiveUs - clientSendTimestampUs)
    let sampleLatencyMs = Double(rttUs) / 2000.0  // Instantaneous one-way latency
    let serverEstimateUs = serverTimestampUs + (rttUs / 2)
    let offsetUs = serverEstimateUs - clientReceiveUs

    self.networkLatencyUs = rttUs / 2
    self.serverTimeOffsetUs = offsetUs

    if !hasSynced {
      self.smoothedLatencyMs = sampleLatencyMs
      self.hasSynced = true
    } else {
      self.smoothedLatencyMs =
        (smoothingFactor * sampleLatencyMs) + ((1.0 - smoothingFactor) * self.smoothedLatencyMs)
    }

    return self.smoothedLatencyMs
  }

  public var latencyMs: Double {
    smoothedLatencyMs
  }

  public var serverTimeUs: Int64 {
    if !hasSynced {
      return 0
    }
    return Self.clientTimeUs() + serverTimeOffsetUs
  }

  public var isSynced: Bool {
    hasSynced
  }

  public func reset() {
    serverTimeOffsetUs = 0
    networkLatencyUs = 0
    smoothedLatencyMs = 0
    hasSynced = false
  }
}
