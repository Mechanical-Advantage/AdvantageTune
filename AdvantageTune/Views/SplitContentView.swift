// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct SplitContentView: View {
  @Bindable var store: NTStore
  @State private var selectedTab: MainTabView.AppTab? = .browse
  @State private var selectedTopic: NT4Topic? = nil
  @State private var columnVisibility: NavigationSplitViewVisibility = .all

  public init(store: NTStore) {
    self.store = store
  }

  public var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
      // Column 1: Sidebar
      List(selection: $selectedTab) {
        Section("Navigation") {
          ForEach(MainTabView.AppTab.allCases) { tab in
            NavigationLink(value: tab) {
              switch tab {
              case .browse:
                Label("Browse", systemImage: "folder")
              case .values:
                HStack {
                  Label("Tuning", systemImage: "slider.horizontal.3")
                  Spacer()
                  if !store.tunedEntries.isEmpty {
                    Text("\(store.tunedEntries.count)")
                      .font(.caption2.weight(.bold))
                      .padding(.horizontal, 6)
                      .padding(.vertical, 2)
                      .background(Color.accentColor.opacity(0.15))
                      .foregroundColor(.accentColor)
                      .clipShape(Capsule())
                  }
                }
              case .search:
                Label("Search", systemImage: "magnifyingglass")
              }
            }
          }
        }
      }
      .listStyle(.sidebar)
      .navigationTitle("AdvantageTune")
      .safeAreaInset(edge: .bottom) {
        ConnectionBar(store: store)
      }
    } content: {
      // Column 2: Content
      Group {
        switch selectedTab ?? .browse {
        case .browse:
          BrowseContentSplitView(store: store, selectedTopic: $selectedTopic)
        case .values:
          TuningContentSplitView(store: store, selectedTopic: $selectedTopic)
        case .search:
          SearchContentSplitView(store: store, selectedTopic: $selectedTopic)
        }
      }
    } detail: {
      // Column 3: Detail
      if let topic = selectedTopic {
        TopicDetailView(store: store, topic: topic)
          .id(topic.name)
      } else {
        ContentUnavailableView(
          "No Topic Selected",
          systemImage: "slider.horizontal.2",
          description: Text("Select a topic from the list to view live telemetry and tune values.")
        )
      }
    }
    .navigationSplitViewStyle(.balanced)
    .onChange(of: store.connectionStatus.isConnected) { oldVal, newVal in
      if !oldVal && newVal {
        Haptics.notification(.success)
      } else if oldVal && !newVal {
        Haptics.impact(.light)
      }
    }
  }
}

// MARK: - Split Content Subviews

struct BrowseContentSplitView: View {
  @Bindable var store: NTStore
  @Binding var selectedTopic: NT4Topic?

  var body: some View {
    VStack(spacing: 0) {
      if !store.connectionStatus.isConnected && store.topicTree.isEmpty {
        ContentUnavailableView(
          "Not Connected",
          systemImage: "network.slash",
          description: Text("Connect to a NetworkTables server to browse topics.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if store.topicTree.isEmpty {
        ContentUnavailableView(
          "No Topics Announced",
          systemImage: "tray",
          description: Text("Waiting for the server to announce NetworkTables topics.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(selection: $selectedTopic) {
          FolderSplitTreeListView(store: store, nodes: store.topicTree, selectedTopic: $selectedTopic)
        }
        .listStyle(.inset)
      }
    }
    .navigationTitle("Browse")
  }
}

struct FolderSplitTreeListView: View {
  @Bindable var store: NTStore
  let nodes: [TopicNode]
  @Binding var selectedTopic: NT4Topic?

  private var subfolders: [TopicNode] {
    nodes.filter { $0.isFolder }
  }

  private var topics: [TopicNode] {
    nodes.filter { !$0.isFolder }
  }

  var body: some View {
    if !topics.isEmpty {
      Section("Keys (\(topics.count))") {
        ForEach(topics) { child in
          if let topic = child.topic {
            let isPublished = store.isPublished(topicName: topic.name)
            Button {
              selectedTopic = topic
            } label: {
              TopicRowView(
                store: store, topic: topic, title: child.name, isPublished: isPublished)
            }
            .buttonStyle(.plain)
            .listRowBackground(
              selectedTopic == topic
                ? Color.accentColor.opacity(0.15)
                : Color.clear
            )
          }
        }
      }
    }

    if !subfolders.isEmpty {
      Section("Tables (\(subfolders.count))") {
        ForEach(subfolders) { child in
          FolderSplitTreeNodeView(store: store, node: child, selectedTopic: $selectedTopic)
        }
      }
    }
  }
}

struct FolderSplitTreeNodeView: View {
  @Bindable var store: NTStore
  let node: TopicNode
  @Binding var selectedTopic: NT4Topic?
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

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      ForEach(topics) { child in
        if let topic = child.topic {
          let isPublished = store.isPublished(topicName: topic.name)
          Button {
            selectedTopic = topic
          } label: {
            TopicRowView(
              store: store, topic: topic, title: child.name, isPublished: isPublished)
          }
          .buttonStyle(.plain)
          .listRowBackground(
            selectedTopic == topic
              ? Color.accentColor.opacity(0.15)
              : Color.clear
          )
        }
      }

      ForEach(subfolders) { child in
        FolderSplitTreeNodeView(store: store, node: child, selectedTopic: $selectedTopic)
      }
    } label: {
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
          .background(Color.secondary.opacity(0.15))
          .foregroundColor(.secondary)
          .clipShape(Capsule())
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

struct TuningContentSplitView: View {
  @Bindable var store: NTStore
  @Binding var selectedTopic: NT4Topic?

  private var entries: [TunedEntry] {
    Array(store.tunedEntries.values)
      .sorted { $0.topicPath.localizedStandardCompare($1.topicPath) == .orderedAscending }
  }

  private var formattedShareText: String {
    guard !entries.isEmpty else {
      return String(localized: "No tuned values.")
    }

    let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    var lines: [String] = [
      String(localized: "AdvantageTune Values (\(dateStr))"),
      "",
    ]

    for entry in entries {
      lines.append("\(entry.topicPath) = \(entry.currentValue.fullString)")
    }

    return lines.joined(separator: "\n")
  }

  var body: some View {
    VStack(spacing: 0) {
      if entries.isEmpty {
        ContentUnavailableView(
          "No Tuned Values",
          systemImage: "slider.horizontal.3",
          description: Text("Modified values will appear here for quick access and sharing.")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List(selection: $selectedTopic) {
          Section("Tuned Values (\(entries.count))") {
            ForEach(entries) { entry in
              let topic =
                store.topicsByName[entry.topicPath]
                ?? NT4Topic(id: -1, name: entry.topicPath, type: entry.topicType)
              let displayValue = store.latestValues[entry.topicPath] ?? entry.currentValue

              Button {
                selectedTopic = topic
              } label: {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text(entry.topicPath)
                      .font(.subheadline.weight(.semibold))
                      .foregroundColor(.primary)
                      .lineLimit(1)
                      .truncationMode(.head)

                    Spacer()

                    Text("PUBLISHED")
                      .font(.system(size: 9, weight: .bold))
                      .padding(.horizontal, 6)
                      .padding(.vertical, 2)
                      .background(Color.orange.opacity(0.2))
                      .foregroundColor(.orange)
                      .clipShape(RoundedRectangle(cornerRadius: 4))
                  }

                  HStack {
                    Text(displayValue.formattedString)
                      .font(.system(.subheadline, design: .monospaced).weight(.bold))
                      .foregroundColor(.accentColor)

                    Spacer()

                    Text(entry.lastModified.formatted(date: .omitted, time: .standard))
                      .font(.caption2)
                      .foregroundColor(.secondary)
                  }
                }
                .padding(.vertical, 6)
              }
              .buttonStyle(.plain)
              .listRowBackground(
                selectedTopic == topic
                  ? Color.accentColor.opacity(0.15)
                  : Color.clear
              )
              .topicContextMenu(store: store, topic: topic, value: displayValue)
              .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                  Haptics.notification(.warning)
                  store.revertAndUnpublishTopic(name: entry.topicPath)
                } label: {
                  Label("Revert", systemImage: "arrow.uturn.backward")
                }

                Button {
                  Haptics.impact(.medium)
                  store.unpublishTopic(name: entry.topicPath)
                } label: {
                  Label("Unpublish", systemImage: "xmark.octagon")
                }
                .tint(.secondary)
              }
              .onAppear {
                store.acquireSubscription(for: entry.topicPath)
              }
              .onDisappear {
                store.releaseSubscription(for: entry.topicPath)
              }
            }
          }
        }
        .listStyle(.inset)
      }
    }
    .navigationTitle("Tuning")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        if !entries.isEmpty {
          HStack(spacing: 20) {
            ShareLink(item: formattedShareText) {
              Image(systemName: "square.and.arrow.up")
                .font(.body)
                .frame(width: 32, height: 32)
            }

            Menu {
              Button {
                Haptics.impact(.medium)
                store.unpublishAllTunedTopics()
              } label: {
                Label("Unpublish All", systemImage: "xmark.octagon")
              }

              Button(role: .destructive) {
                Haptics.notification(.warning)
                store.revertAllTunedTopics()
              } label: {
                Label("Revert All", systemImage: "arrow.uturn.backward")
              }
            } label: {
              Image(systemName: "trash")
                .font(.body)
                .foregroundColor(.red)
                .frame(width: 32, height: 32)
            }
          }
          .padding(.trailing, 4)
        }
      }
    }
  }
}

struct SearchContentSplitView: View {
  @Bindable var store: NTStore
  @Binding var selectedTopic: NT4Topic?
  @State private var searchText: String = ""
  @State private var selectedTypeFilter: SearchView.FilterOption = .all

  private var filteredTopics: [NT4Topic] {
    store.searchTopics(query: searchText, filter: selectedTypeFilter.rawValue, limit: 100)
  }

  var body: some View {
    VStack(spacing: 0) {
      // Filter picker
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(SearchView.FilterOption.allCases) { filter in
            Button {
              if selectedTypeFilter != filter {
                Haptics.selection()
                selectedTypeFilter = filter
              }
            } label: {
              Text(filter.titleKey)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                  selectedTypeFilter == filter
                    ? Color.accentColor
                    : Color.secondary.opacity(0.12)
                )
                .foregroundColor(
                  selectedTypeFilter == filter ? .white : .primary
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      }
      .background(.background)

      Divider()

      if filteredTopics.isEmpty {
        if searchText.isEmpty {
          ContentUnavailableView(
            "Search Topics",
            systemImage: "magnifyingglass",
            description: Text("Find a NetworkTables topic by name.")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
          ContentUnavailableView(
            "No Results for “\(searchText)”",
            systemImage: "magnifyingglass",
            description: Text("Check the spelling or try a new search.")
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        List(selection: $selectedTopic) {
          Section("Results (\(filteredTopics.count))") {
            ForEach(filteredTopics) { topic in
              let isPublished = store.isPublished(topicName: topic.name)
              Button {
                selectedTopic = topic
              } label: {
                TopicRowView(store: store, topic: topic, isPublished: isPublished)
              }
              .buttonStyle(.plain)
              .listRowBackground(
                selectedTopic == topic
                  ? Color.accentColor.opacity(0.15)
                  : Color.clear
              )
            }
          }
        }
        .listStyle(.inset)
      }
    }
    .navigationTitle("Search")
    .searchable(text: $searchText, placement: .automatic, prompt: "Search topics...")
  }
}
