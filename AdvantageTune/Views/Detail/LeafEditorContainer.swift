// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct LeafEditorContainer<Input: View>: View {
  let label: LocalizedStringKey?
  let verbatimLabel: String?
  let isFocused: Bool
  let onDelete: (() -> Void)?
  let onCommit: () -> Void
  let input: Input

  public init(
    label: LocalizedStringKey? = nil,
    verbatimLabel: String? = nil,
    isFocused: Bool,
    onDelete: (() -> Void)?,
    onCommit: @escaping () -> Void,
    @ViewBuilder input: () -> Input
  ) {
    self.label = label
    self.verbatimLabel = verbatimLabel
    self.isFocused = isFocused
    self.onDelete = onDelete
    self.onCommit = onCommit
    self.input = input()
  }

  public var body: some View {
    HStack {
      if let label = label {
        Text(label)
          .foregroundColor(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      } else if let verbatimLabel = verbatimLabel {
        Text(verbatim: verbatimLabel)
          .foregroundColor(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 20)

      HStack(spacing: 4) {
        input
      }
      .frame(minWidth: 70)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(Color.secondary.opacity(0.15))
      .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .stroke(isFocused ? Color.accentColor : Color.clear, lineWidth: 1.5)
      )

      if isFocused {
        Button {
          Haptics.impact(.light)
          onCommit()
        } label: {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.accentColor)
            .font(.body)
        }
        .buttonStyle(.borderless)
      }

      if let onDelete = onDelete {
        Button(role: .destructive) {
          Haptics.impact(.medium)
          onDelete()
        } label: {
          Image(systemName: "trash")
            .font(.caption)
            .foregroundColor(.red.opacity(0.8))
            .padding(.leading, 6)
        }
        .buttonStyle(.borderless)
      }
    }
  }
}
