// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct TuningView: View {
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Bindable var store: NTStore
  @State private var selectedTopic: NT4Topic?

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

  public var body: some View {
    if horizontalSizeClass == .regular {
      HStack(spacing: 0) {
        // Left: Tuned items list
        NavigationStack {
          VStack(spacing: 0) {
            ConnectionBar(store: store)

            Divider()

            if entries.isEmpty {
              ContentUnavailableView(
                "No Tuned Values",
                systemImage: "slider.horizontal.3",
                description: Text("Modified values will appear here for quick access and sharing.")
              )
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
              List {
                Section {
                  ForEach(entries) { entry in
                    let topic =
                      store.topicsByName[entry.topicPath]
                      ?? NT4Topic(id: -1, name: entry.topicPath, type: entry.topicType)
                    let displayValue = store.latestValues[entry.topicPath] ?? entry.currentValue
                    let isSelected = selectedTopic?.name == topic.name

                    Button {
                      selectedTopic = topic
                    } label: {
                      entryRowContent(entry: entry, displayValue: displayValue)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                      isSelected ? Color.accentColor.opacity(0.12) : nil
                    )
                    .topicContextMenu(store: store, topic: topic, value: displayValue)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                      swipeButtons(for: entry)
                    }
                    .onAppear {
                      store.acquireSubscription(for: entry.topicPath)
                    }
                    .onDisappear {
                      store.releaseSubscription(for: entry.topicPath)
                    }
                  }
                } header: {
                  Text("Tuned Values (\(entries.count))")
                }
              }
              .listStyle(.insetGrouped)
            }
          }
          .navigationTitle("Tuning")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar { toolbarContent }
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
            if entries.isEmpty {
              ContentUnavailableView(
                "AdvantageTune", systemImage: "slider.horizontal.3", description: Text("Tuned values will appear here.")
              )
            } else {
              ContentUnavailableView(
                "No Value Selected",
                systemImage: "slider.horizontal.3",
                description: Text("Select a tuned value from the list to view and edit.")
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

          if entries.isEmpty {
            ContentUnavailableView(
              "No Tuned Values",
              systemImage: "slider.horizontal.3",
              description: Text("Modified values will appear here for quick access and sharing.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            List {
              Section {
                ForEach(entries) { entry in
                  let topic =
                    store.topicsByName[entry.topicPath]
                    ?? NT4Topic(id: -1, name: entry.topicPath, type: entry.topicType)
                  let displayValue = store.latestValues[entry.topicPath] ?? entry.currentValue

                  NavigationLink(destination: TopicDetailView(store: store, topic: topic)) {
                    entryRowContent(entry: entry, displayValue: displayValue)
                  }
                  .topicContextMenu(store: store, topic: topic, value: displayValue)
                  .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    swipeButtons(for: entry)
                  }
                  .onAppear {
                    store.acquireSubscription(for: entry.topicPath)
                  }
                  .onDisappear {
                    store.releaseSubscription(for: entry.topicPath)
                  }
                }
              } header: {
                Text("Tuned Values (\(entries.count))")
              }
            }
            .listStyle(.insetGrouped)
          }
        }
        .navigationTitle("Tuning")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
      }
    }
  }

  private func entryRowContent(entry: TunedEntry, displayValue: TopicValue) -> some View {
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

  @ViewBuilder
  private func swipeButtons(for entry: TunedEntry) -> some View {
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

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
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
