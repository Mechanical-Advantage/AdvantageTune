// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

public enum UserDefaultsKeys {
  public static let serverHost = "server_host"
  public static let defaultStepSize = "default_step_size"

  public static func stepSize(for topicPath: String) -> String {
    "step_size_\(topicPath)"
  }
}
