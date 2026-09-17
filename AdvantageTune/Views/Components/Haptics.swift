// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum HapticImpactStyle {
  case light
  case medium
  case heavy
  case soft
  case rigid
}

public enum HapticNotificationType {
  case success
  case warning
  case error
}

public enum Haptics {
  /// Feedback for changing selections (e.g. filter pills, tabs).
  public static func selection() {
    #if os(iOS)
    UISelectionFeedbackGenerator().selectionChanged()
    #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    #endif
  }

  /// Feedback for physical impacts (e.g. steppers, buttons, insertions).
  public static func impact(_ style: HapticImpactStyle = .light) {
    #if os(iOS)
    let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
    switch style {
    case .light: uiStyle = .light
    case .medium: uiStyle = .medium
    case .heavy: uiStyle = .heavy
    case .soft: uiStyle = .soft
    case .rigid: uiStyle = .rigid
    }
    UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
    #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    #endif
  }

  /// Feedback for discrete task outcomes (e.g. connected, warning, revert, delete).
  public static func notification(_ type: HapticNotificationType) {
    #if os(iOS)
    let uiType: UINotificationFeedbackGenerator.FeedbackType
    switch type {
    case .success: uiType = .success
    case .warning: uiType = .warning
    case .error: uiType = .error
    }
    UINotificationFeedbackGenerator().notificationOccurred(uiType)
    #elseif os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    #endif
  }
}

