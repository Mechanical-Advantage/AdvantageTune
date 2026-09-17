// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct AdaptiveContentView: View {
  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  @State private var store = NTStore()

  public init() {}

  public var body: some View {
    #if os(macOS)
    SplitContentView(store: store)
      .onAppear {
        store.connect()
      }
    #else
    if horizontalSizeClass == .regular {
      SplitContentView(store: store)
        .onAppear {
          store.connect()
        }
    } else {
      MainTabView(store: store)
    }
    #endif
  }
}
