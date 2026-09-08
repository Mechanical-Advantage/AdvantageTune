// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct FolderTreeNodeView: View {
  @Bindable var store: NTStore
  public let node: TopicNode

  @State private var isExpanded: Bool = false

  private var liveNode: TopicNode {
    store.node(for: node.path) ?? node
  }

  private var subfolders: [TopicNode] {
    liveNode.children.filter { $0.isFolder }
  }

  private var topics: [TopicNode] {
    liveNode.children.filter { !$0.isFolder }
  }

  public var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      // Keys
      ForEach(topics) { child in
        if let topic = child.topic {
          let isPublished = store.isPublished(topicName: topic.name)
          NavigationLink(value: child) {
            TopicRowView(store: store, topic: topic, title: child.name, isPublished: isPublished)
          }
        }
      }

      // Subfolders
      ForEach(subfolders) { child in
        FolderTreeNodeView(store: store, node: child)
      }
    } label: {
      NavigationLink(value: node) {
        HStack(spacing: 10) {
          Image(systemName: "folder.fill")
            .foregroundColor(.accentColor)
            .font(.body)

          Text(node.name)
            .font(.body.weight(.medium))
            .foregroundColor(.primary)

          Spacer()

          Text("\(liveNode.children.count)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(.systemGray5))
            .foregroundColor(.secondary)
            .clipShape(Capsule())
        }
      }
    }
    .onChange(of: isExpanded) { _, expanded in
      let topicNames = topics.compactMap { $0.topic?.name }
      if expanded {
        store.acquireSubscriptions(for: topicNames)
      } else {
        store.releaseSubscriptions(for: topicNames)
      }
    }
    .onDisappear {
      if isExpanded {
        let topicNames = topics.compactMap { $0.topic?.name }
        store.releaseSubscriptions(for: topicNames)
      }
    }
  }
}
