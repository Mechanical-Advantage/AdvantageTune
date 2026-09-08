// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct TypeBadgeView: View {
  public let typeName: String
  public var compact: Bool = false

  public init(typeName: String, compact: Bool = false) {
    self.typeName = typeName
    self.compact = compact
  }

  private var badgeColor: Color {
    let lower = typeName.lowercased()
    if lower.hasPrefix("bool") {
      return .green
    } else if lower.hasPrefix("double") || lower.hasPrefix("float") {
      return .blue
    } else if lower.hasPrefix("int") {
      return .indigo
    } else if lower.hasPrefix("string") || lower.hasPrefix("json") {
      return .orange
    } else if lower.contains("struct:") || lower.contains("proto:") {
      return .purple
    } else if lower.contains("[]") {
      return .teal
    } else {
      return .gray
    }
  }

  private var iconName: String {
    let lower = typeName.lowercased()
    if lower == "boolean" {
      return "switch.2"
    } else if lower == "boolean[]" {
      return "checklist"
    } else if lower == "double" || lower == "float" {
      return "chart.xyaxis.line"
    } else if lower == "double[]" || lower == "float[]" {
      return "chart.bar.xaxis"
    } else if lower == "int" {
      return "number"
    } else if lower == "int[]" {
      return "number.square"
    } else if lower == "string" || lower == "json" {
      return "text.quote"
    } else if lower == "string[]" {
      return "list.bullet"
    } else if lower.hasPrefix("struct:") {
      return "cube.transparent"
    } else if lower.hasPrefix("proto:") {
      return "shippingbox"
    } else {
      return "memorychip"
    }
  }

  public static func shortTypeLabel(for typeName: String) -> String {
    if typeName.hasPrefix("struct:") {
      return String(typeName.dropFirst(7))
    } else if typeName.hasPrefix("proto:") {
      return String(typeName.dropFirst(6))
    }
    return typeName
  }

  public var shortTypeLabel: String {
    Self.shortTypeLabel(for: typeName)
  }

  public var body: some View {
    if compact {
      Image(systemName: iconName)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(badgeColor)
        .frame(width: 22, height: 22)
        .background(badgeColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    } else {
      HStack(spacing: 4) {
        Image(systemName: iconName)
          .font(.caption2.weight(.bold))
        Text(shortTypeLabel)
          .font(.caption2.weight(.medium))
      }
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(badgeColor.opacity(0.15))
      .foregroundColor(badgeColor)
      .clipShape(Capsule())
    }
  }
}
