// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct SearchView: View {
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

  private var filteredTopics: [NT4Topic] {
    store.searchTopics(query: searchText, filter: selectedTypeFilter.rawValue, limit: 100)
  }

  public var body: some View {
    NavigationStack {
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
                NavigationLink(destination: TopicDetailView(store: store, topic: topic)) {
                  TopicRowView(store: store, topic: topic, isPublished: isPublished)
                }
              }
            } header: {
              Text("Results (\(filteredTopics.count))")
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("Search")
      .navigationBarTitleDisplayMode(.large)
      .searchable(text: $searchText, placement: .automatic, prompt: "Search topics...")
    }
  }
}
