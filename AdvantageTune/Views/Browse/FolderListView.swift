// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct FolderListView: View {
  @Bindable var store: NTStore
  public let node: TopicNode?

  public init(store: NTStore, node: TopicNode? = nil) {
    self.store = store
    self.node = node
  }

  private var isRoot: Bool {
    node == nil
  }

  private var folderPath: String {
    node?.path ?? "/"
  }

  private var currentChildren: [TopicNode] {
    if let node {
      return (store.node(for: node.path) ?? node).children
    }
    return store.topicTree
  }

  private var subfolders: [TopicNode] {
    currentChildren.filter { $0.isFolder }
  }

  private var topics: [TopicNode] {
    currentChildren.filter { !$0.isFolder }
  }

  public var body: some View {
    Group {
      if subfolders.isEmpty && topics.isEmpty {
        if isRoot {
          ContentUnavailableView(
            "No Topics Announced",
            systemImage: "tray",
            description: Text("Waiting for the server to announce NetworkTables topics.")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ContentUnavailableView(
            "Empty Table",
            systemImage: "folder",
            description: Text("No sub-tables or keys found under \(folderPath).")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        List {
          // Keys
          if !topics.isEmpty {
            Section {
              ForEach(topics) { child in
                if let topic = child.topic {
                  let isPublished = store.isPublished(topicName: topic.name)
                  NavigationLink(value: child) {
                    TopicRowView(
                      store: store, topic: topic, title: child.name, isPublished: isPublished)
                  }
                }
              }
            } header: {
              Text("Keys (\(topics.count))")
            }
          }

          // Subtables
          if !subfolders.isEmpty {
            Section {
              ForEach(subfolders) { child in
                FolderTreeNodeView(store: store, node: child)
              }
            } header: {
              Text("Tables (\(subfolders.count))")
            }
          }
        }
        .listStyle(.insetGrouped)
      }
    }
    .navigationTitle(isRoot ? Text("Browse") : Text(verbatim: node?.name ?? ""))
    .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
  }
}
