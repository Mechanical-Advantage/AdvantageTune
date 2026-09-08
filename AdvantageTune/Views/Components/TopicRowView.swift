// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct TopicRowView: View {
  @Bindable var store: NTStore
  public let topic: NT4Topic
  public var title: String? = nil
  public var isPublished: Bool = false

  public init(
    store: NTStore,
    topic: NT4Topic,
    title: String? = nil,
    isPublished: Bool = false
  ) {
    self.store = store
    self.topic = topic
    self.title = title
    self.isPublished = isPublished
  }

  private var displayTitle: String {
    title ?? topic.name
  }

  private var liveValue: TopicValue? {
    store.latestValues[topic.name]
  }

  public var body: some View {
    HStack(spacing: 10) {
      TypeBadgeView(typeName: topic.type, compact: true)

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(displayTitle)
            .font(.body.weight(.medium))
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.head)

          if isPublished {
            Text("PUB")
              .font(.system(size: 9, weight: .bold))
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(Color.orange.opacity(0.2))
              .foregroundColor(.orange)
              .clipShape(RoundedRectangle(cornerRadius: 3))
          }
        }

        Text(TypeBadgeView.shortTypeLabel(for: topic.type))
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer()

      if let val = liveValue {
        Text(val.formattedString)
          .font(.system(.subheadline, design: .monospaced).weight(.semibold))
          .foregroundColor(.primary)
          .lineLimit(1)
          .multilineTextAlignment(.trailing)
      } else {
        Text("—")
          .font(.subheadline)
          .foregroundColor(.secondary)
      }
    }
    .contentShape(Rectangle())
    .onAppear {
      store.acquireSubscription(for: topic.name)
    }
    .onDisappear {
      store.releaseSubscription(for: topic.name)
    }
    .topicContextMenu(store: store, topic: topic, value: liveValue)
  }
}
