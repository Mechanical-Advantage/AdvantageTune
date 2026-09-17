// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public enum Clipboard {
  public static func copy(_ string: String) {
    #if os(iOS)
    UIPasteboard.general.string = string
    #elseif os(macOS)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(string, forType: .string)
    #endif
  }
}

public enum CompactTitleDisplayMode {
  case automatic
  case inline
  case large
}

public enum CompactKeyboardType {
  case `default`
  case asciiCapable
  case numbersAndPunctuation
  case numberPad
  case decimalPad
}

extension View {
  @ViewBuilder
  public func navigationTitleDisplayModeCompat(_ mode: CompactTitleDisplayMode) -> some View {
    #if os(iOS)
    switch mode {
    case .automatic:
      self.navigationBarTitleDisplayMode(.automatic)
    case .inline:
      self.navigationBarTitleDisplayMode(.inline)
    case .large:
      self.navigationBarTitleDisplayMode(.large)
    }
    #else
    self
    #endif
  }

  @ViewBuilder
  public func keyboardTypeCompat(_ type: CompactKeyboardType) -> some View {
    #if os(iOS)
    switch type {
    case .default:
      self.keyboardType(.default)
    case .asciiCapable:
      self.keyboardType(.asciiCapable)
    case .numbersAndPunctuation:
      self.keyboardType(.numbersAndPunctuation)
    case .numberPad:
      self.keyboardType(.numberPad)
    case .decimalPad:
      self.keyboardType(.decimalPad)
    }
    #else
    self
    #endif
  }

  @ViewBuilder
  public func textInputAutocapitalizationNeverCompat() -> some View {
    #if os(iOS)
    self.textInputAutocapitalization(.never)
    #else
    self
    #endif
  }

  @ViewBuilder
  public func submitLabelDoneCompat() -> some View {
    #if os(iOS)
    self.submitLabel(.done)
    #else
    self.submitLabel(.return)
    #endif
  }

  @ViewBuilder
  public func listStyleInsetGroupedCompat() -> some View {
    #if os(iOS)
    self.listStyle(.insetGrouped)
    #else
    self.listStyle(.inset)
    #endif
  }
}
