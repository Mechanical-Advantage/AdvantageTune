// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct MainTabView: View {
  @Bindable var store: NTStore
  @State private var selectedTab: AppTab = .browse

  public init(store: NTStore? = nil) {
    self.store = store ?? NTStore()
  }

  public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case browse = "Browse"
    case values = "Values"
    case search = "Search"

    public var id: String { rawValue }
  }

  public var body: some View {
    TabView(selection: $selectedTab) {
      Tab("Browse", systemImage: "folder", value: .browse) {
        BrowseView(store: store)
      }

      Tab("Tuning", systemImage: "slider.horizontal.3", value: .values) {
        TuningView(store: store)
      }
      .badge(store.tunedEntries.count)

      Tab(value: .search, role: .search) {
        SearchView(store: store)
      }
    }
    .tabViewStyle(.sidebarAdaptable)
    .onAppear {
      store.connect()
    }
    .onChange(of: store.connectionStatus.isConnected) { oldVal, newVal in
      if !oldVal && newVal {
        Haptics.notification(.success)
      } else if oldVal && !newVal {
        Haptics.impact(.light)
      }
    }
  }
}
