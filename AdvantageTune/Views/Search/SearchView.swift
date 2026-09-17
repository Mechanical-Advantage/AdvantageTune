// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct SearchView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Bindable var store: NTStore
  public enum FilterOption: String, CaseIterable, Identifiable {
    case all = "All"
    case numeric = "Numeric"
    case boolean = "Boolean"
    case string = "String"
    case arrays = "Arrays"
    case structProto = "Struct/Proto"

    public var id: String { rawValue }

    public var titleKey: LocalizedStringKey {
      switch self {
      case .all: return "All"
      case .numeric: return "Numeric"
      case .boolean: return "Boolean"
      case .string: return "String"
      case .arrays: return "Arrays"
      case .structProto: return "Struct/Proto"
      }
    }
  }

  @State private var searchText: String = ""
  @State private var selectedTypeFilter: FilterOption = .all
  @State private var selectedTopic: NT4Topic?

  private var filteredTopics: [NT4Topic] {
    store.searchTopics(query: searchText, filter: selectedTypeFilter.rawValue, limit: 100)
  }

  public var body: some View {
    if horizontalSizeClass == .regular {
      HStack(spacing: 0) {
        // Left: Search results list
        NavigationStack {
          searchListView(isRegular: true)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .automatic, prompt: "Search topics...")
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)

        Divider()

        // Right: Topic detail pane
        Group {
          if let selectedTopic {
            NavigationStack {
              TopicDetailView(store: store, topic: selectedTopic)
            }
            .id(selectedTopic.name)
          } else {
            if filteredTopics.isEmpty {
              ContentUnavailableView(
                "AdvantageTune", systemImage: "magnifyingglass", description: Text("Search for topics."))
            } else {
              ContentUnavailableView(
                "No Topic Selected",
                systemImage: "magnifyingglass",
                description: Text("Select a topic from the search results to inspect or edit.")
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
        searchListView(isRegular: false)
          .navigationTitle("Search")
          .navigationBarTitleDisplayMode(.large)
          .searchable(text: $searchText, placement: .automatic, prompt: "Search topics...")
      }
    }
  }

  @ViewBuilder
  private func searchListView(isRegular: Bool) -> some View {
    VStack(spacing: 0) {
      // Connection bar
      ConnectionBar(store: store)

      Divider()

      // Filter picker
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(FilterOption.allCases) { filter in
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
                    : Color(.secondarySystemBackground)
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
      .background(Color(.systemBackground))

      Divider()

      // Results
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
        List {
          Section {
            ForEach(filteredTopics) { topic in
              let isPublished = store.isPublished(topicName: topic.name)
              let isSelected = isRegular && selectedTopic?.name == topic.name

              if isRegular {
                Button {
                  selectedTopic = topic
                } label: {
                  TopicRowView(
                    store: store,
                    topic: topic,
                    isPublished: isPublished,
                    isSelected: isSelected
                  )
                }
                .buttonStyle(.plain)
                .listRowBackground(
                  isSelected ? Color.accentColor.opacity(0.12) : nil
                )
              } else {
                NavigationLink(destination: TopicDetailView(store: store, topic: topic)) {
                  TopicRowView(store: store, topic: topic, isPublished: isPublished)
                }
              }
            }
          } header: {
            Text("Results (\(filteredTopics.count))")
          }
        }
        .listStyle(.insetGrouped)
      }
    }
  }
}
