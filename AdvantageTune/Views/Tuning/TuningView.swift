// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct TuningView: View {
  @Bindable var store: NTStore

  private var entries: [TunedEntry] {
    Array(store.tunedEntries.values)
      .sorted { $0.topicPath.localizedStandardCompare($1.topicPath) == .orderedAscending }
  }

  private var formattedShareText: String {
    guard !entries.isEmpty else {
      return String(localized: "No tuned values.")
    }

    var lines: [String] = []
    for entry in entries {
      lines.append("\(entry.topicPath) = \(entry.currentValue.fullString)")
    }

    return lines.joined(separator: "\n")
  }

  public var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Connection bar
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
            } header: {
              Text("Tuned Values (\(entries.count))")
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("Tuning")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
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
  }
}
