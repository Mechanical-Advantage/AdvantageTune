// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct RawTelemetryView: View {
  public let topic: NT4Topic
  public let rawData: Data?
  public let fallbackValue: TopicValue?

  public init(topic: NT4Topic, rawData: Data?, fallbackValue: TopicValue? = nil) {
    self.topic = topic
    self.rawData = rawData
    self.fallbackValue = fallbackValue
  }

  private var rawTelemetryLabelKey: LocalizedStringKey {
    if topic.type.hasPrefix("proto:") || topic.isProtobuf {
      return "Protobuf Value"
    } else if topic.type.hasPrefix("struct:") || topic.isStruct {
      return "Struct Value"
    } else {
      return "Server Value"
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label(rawTelemetryLabelKey, systemImage: "memorychip")
          .font(.subheadline.weight(.medium))
          .foregroundColor(.secondary)
        Spacer()
        if let rawData = rawData {
          Text("\(rawData.count) bytes")
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15))
            .clipShape(Capsule())
        } else {
          Text("Waiting for value...")
            .italic()
            .foregroundColor(.secondary)
        }
      }

      if let rawData = rawData, !rawData.isEmpty {
        let hexSnippet = rawData.prefix(512).map { String(format: "%02X", $0) }.joined(
          separator: " ")
        Text("Hex: \(hexSnippet)\(rawData.count > 512 ? " …" : "")")
          .font(.system(.caption2, design: .monospaced))
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .topicContextMenu(topicName: topic.name, value: fallbackValue, rawData: rawData)
  }
}
