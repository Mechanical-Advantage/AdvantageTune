// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import UIKit

public enum Haptics {
  /// Feedback for changing selections (e.g. filter pills, tabs).
  public static func selection() {
    UISelectionFeedbackGenerator().selectionChanged()
  }

  /// Feedback for physical impacts (e.g. steppers, buttons, insertions).
  public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
  }

  /// Feedback for discrete task outcomes (e.g. connected, warning, revert, delete).
  public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
    UINotificationFeedbackGenerator().notificationOccurred(type)
  }
}
