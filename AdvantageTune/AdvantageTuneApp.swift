// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

@main
struct AdvantageTuneApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        #if os(macOS)
        .frame(minWidth: 800, minHeight: 520)
        #endif
    }
    #if os(macOS)
    .defaultSize(width: 960, height: 640)
    #endif
  }
}
