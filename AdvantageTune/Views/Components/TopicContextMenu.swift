// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct TopicContextMenuModifier: ViewModifier {
  public let store: NTStore?
  public let topic: NT4Topic?
  public let topicName: String
  public let value: TopicValue?
  public let rawData: Data?

  public init(
    store: NTStore? = nil,
    topic: NT4Topic? = nil,
    topicName: String? = nil,
    value: TopicValue? = nil,
    rawData: Data? = nil
  ) {
    self.store = store
    self.topic = topic
    self.topicName = topic?.name ?? topicName ?? ""
    self.value = value
    self.rawData = rawData
  }

  public func body(content: Content) -> some View {
    content.contextMenu {
      // Interactive topic actions (if store is provided)
      if let store = store {
        let resolvedTopic = topic ?? store.topicsByName[topicName]
        let isImmutable = resolvedTopic?.isImmutable ?? false

        if !isImmutable {
          let isPublished = store.isPublished(topicName: topicName)
          if isPublished {
            Button {
              store.unpublishTopic(name: topicName)
            } label: {
              Label("Unpublish", systemImage: "xmark.octagon")
            }

            Button(role: .destructive) {
              store.revertAndUnpublishTopic(name: topicName)
            } label: {
              Label("Revert", systemImage: "arrow.uturn.backward")
            }
          } else if let val = value, let resolved = resolvedTopic {
            Button {
              store.updateValue(for: resolved, newValue: val)
            } label: {
              Label("Publish", systemImage: "arrow.up.circle")
            }
          }
        }

        Divider()
      }

      // Clipboard actions
      if let rawData = rawData {
        Button {
          let hex = rawData.map { String(format: "%02X", $0) }.joined(separator: " ")
          UIPasteboard.general.string = hex
        } label: {
          Label("Copy Value", systemImage: "doc.on.clipboard")
        }
      } else if let val = value {
        Button {
          UIPasteboard.general.string = val.fullString
        } label: {
          Label("Copy Value", systemImage: "doc.on.clipboard")
        }
      }

      if !topicName.isEmpty {
        Button {
          UIPasteboard.general.string = topicName
        } label: {
          Label("Copy Key", systemImage: "doc.on.doc")
        }
      }
    }
  }
}

extension View {
  public func topicContextMenu(
    store: NTStore? = nil,
    topic: NT4Topic? = nil,
    topicName: String? = nil,
    value: TopicValue? = nil,
    rawData: Data? = nil
  ) -> some View {
    modifier(
      TopicContextMenuModifier(
        store: store,
        topic: topic,
        topicName: topicName,
        value: value,
        rawData: rawData
      ))
  }
}
