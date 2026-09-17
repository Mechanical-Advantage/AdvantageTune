// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct BrowseView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Bindable var store: NTStore
  @State private var selectedTopic: NT4Topic?

  public init(store: NTStore) {
    self.store = store
  }

  public var body: some View {
    if horizontalSizeClass == .regular {
      HStack(spacing: 0) {
        // Left: Message/Topic List Pane
        NavigationStack {
          VStack(spacing: 0) {
            ConnectionBar(store: store)

            Divider()

            if !store.connectionStatus.isConnected && store.topicTree.isEmpty {
              ContentUnavailableView(
                "Not Connected",
                systemImage: "network.slash",
                description: Text("Connect to a NetworkTables server to browse topics.")
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              FolderListView(store: store, node: nil, selectedTopic: $selectedTopic)
            }
          }
          .navigationTitle("Browse")
          .navigationBarTitleDisplayMode(.inline)
          .navigationDestination(for: TopicNode.self) { node in
            if case .folder = node {
              FolderListView(store: store, node: node, selectedTopic: $selectedTopic)
            }
          }
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)

        Divider()

        // Right: Message/Topic Detail Content Pane
        Group {
          if let selectedTopic {
            NavigationStack {
              TopicDetailView(store: store, topic: selectedTopic)
            }
            .id(selectedTopic.name)
          } else {
            if !store.connectionStatus.isConnected && store.topicTree.isEmpty {
              ContentUnavailableView(
                "AdvantageTune", systemImage: "antenna.radiowaves.left.and.right",
                description: Text("Connect to your robot to get started."))
            } else {
              ContentUnavailableView(
                "No Topic Selected",
                systemImage: "slider.horizontal.3",
                description: Text("Select a topic from the list to view and tune values.")
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(Color(.systemGroupedBackground))
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .padding(.top, 1)
    } else {
      // iPhone / Compact single-column NavigationStack
      NavigationStack {
        VStack(spacing: 0) {
          ConnectionBar(store: store)

          Divider()

          if !store.connectionStatus.isConnected && store.topicTree.isEmpty {
            ContentUnavailableView(
              "Not Connected",
              systemImage: "network.slash",
              description: Text("Connect to a NetworkTables server to browse topics.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            FolderListView(store: store, node: nil)
          }
        }
        .navigationTitle("Browse")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: TopicNode.self) { node in
          switch node {
          case .folder:
            FolderListView(store: store, node: node)
          case .topic(_, _, _, let topic, _, _):
            TopicDetailView(store: store, topic: topic)
          }
        }
      }
    }
  }
}
