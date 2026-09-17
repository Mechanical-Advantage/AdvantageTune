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
  @Binding var selectedTopic: NT4Topic?

  public init(
    store: NTStore,
    node: TopicNode? = nil,
    selectedTopic: Binding<NT4Topic?> = .constant(nil)
  ) {
    self.store = store
    self.node = node
    self._selectedTopic = selectedTopic
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
        List(selection: $selectedTopic) {
          // Keys
          if !topics.isEmpty {
            Section {
              ForEach(topics) { child in
                if let topic = child.topic {
                  let isPublished = store.isPublished(topicName: topic.name)

                  TopicRowView(
                    store: store,
                    topic: topic,
                    title: child.name,
                    isPublished: isPublished,
                    isSelected: false
                  )
                  .tag(topic)
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
                NavigationLink(value: child) {
                  HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                      .foregroundColor(.accentColor)
                      .font(.body)

                    Text(child.name)
                      .font(.body.weight(.medium))
                      .foregroundColor(.primary)

                    Spacer()

                    let count = (store.node(for: child.path) ?? child).children.count
                    Text("\(count)")
                      .font(.caption2.weight(.bold))
                      .padding(.horizontal, 6)
                      .padding(.vertical, 2)
                      .background(Color(.systemGray5))
                      .foregroundColor(.secondary)
                      .clipShape(Capsule())
                  }
                }
              }
            } header: {
              Text("Tables (\(subfolders.count))")
            }
          }
        }
        .listStyle(.insetGrouped)
        .onAppear {
          let topicNames = topics.compactMap { $0.topic?.name }
          store.acquireSubscriptions(for: topicNames)
        }
        .onDisappear {
          let topicNames = topics.compactMap { $0.topic?.name }
          store.releaseSubscriptions(for: topicNames)
        }
      }
    }
    .navigationTitle(isRoot ? Text("Browse") : Text(verbatim: node?.name ?? ""))
    .navigationBarTitleDisplayMode(isRoot ? .large : .inline)
  }
}
