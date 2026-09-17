// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct BrowseView: View {
  @Bindable var store: NTStore

  public init(store: NTStore) {
    self.store = store
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Connection bar under navigation title
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
      .navigationTitleDisplayModeCompat(.large)
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
