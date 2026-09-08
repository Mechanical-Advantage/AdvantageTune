// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct StructInspectorView: View {
  public let structValue: StructValue
  public let rootTypeName: String
  public let topicPath: String?
  public var isEditable: Bool = false
  public var onUpdate: ((StructValue) -> Void)? = nil

  public init(
    structValue: StructValue,
    rootTypeName: String,
    topicPath: String? = nil,
    isEditable: Bool = false,
    onUpdate: ((StructValue) -> Void)? = nil
  ) {
    self.structValue = structValue
    self.rootTypeName = rootTypeName
    self.topicPath = topicPath
    self.isEditable = isEditable
    self.onUpdate = onUpdate
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label(StructDecoder.shared.cleanTypeName(rootTypeName), systemImage: "cube.transparent")
          .font(.subheadline.weight(.semibold))
          .foregroundColor(.purple)
        Spacer()
      }

      Divider()

      renderValue(structValue, parentKey: topicPath ?? "")
    }
    .padding(.vertical, 4)
    .transaction { transaction in
      transaction.animation = nil
    }
  }

  @ViewBuilder
  private func renderValue(_ value: StructValue, parentKey: String) -> some View {
    switch value {
    case .object(let fields):
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(fields.enumerated()), id: \.element.key) { index, field in
          let currentPath = parentKey.isEmpty ? field.key : "\(parentKey).\(field.key)"
          StructFieldRow(
            key: field.key,
            path: currentPath,
            value: field.value,
            isEditable: isEditable
          ) { newChildVal in
            var newFields = fields
            newFields[index].value = newChildVal
            onUpdate?(.object(newFields))
          }
        }
      }

    case .array(let elements):
      VStack(alignment: .leading, spacing: 10) {
        ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
          let currentPath = "\(parentKey)[\(index)]"
          StructFieldRow(
            key: "[\(index)]",
            path: currentPath,
            value: element,
            isEditable: isEditable
          ) { newChildVal in
            var newElements = elements
            newElements[index] = newChildVal
            onUpdate?(.array(newElements))
          }
        }
      }

    default:
      if isEditable {
        StructLeafEditor(
          label: parentKey.isEmpty ? nil : parentKey, topicPath: parentKey, value: value
        ) { newLeaf in
          onUpdate?(newLeaf)
        }
        .padding(.vertical, 2)
      } else {
        HStack {
          Text(value.formattedSummary)
            .font(.system(.body, design: .monospaced).weight(.semibold))
            .foregroundColor(.primary)
          Spacer()
        }
        .padding(.vertical, 4)
      }
    }
  }
}

private struct StructFieldRow: View {
  let key: String
  let path: String
  let value: StructValue
  var isEditable: Bool = false
  var onUpdate: ((StructValue) -> Void)? = nil
  @State private var isExpanded: Bool = true

  var body: some View {
    switch value {
    case .object(let fields):
      DisclosureGroup(isExpanded: $isExpanded) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(fields.enumerated()), id: \.element.key) { index, child in
            let childPath = "\(path).\(child.key)"
            StructFieldRow(
              key: child.key,
              path: childPath,
              value: child.value,
              isEditable: isEditable
            ) { newChildVal in
              var newFields = fields
              newFields[index].value = newChildVal
              onUpdate?(.object(newFields))
            }
          }
        }
        .padding(.leading, 12)
        .padding(.top, 6)
      } label: {
        HStack {
          Text(key)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.primary)
          Spacer()
          Text("{\(fields.count)}")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.15))
            .foregroundColor(.purple)
            .clipShape(Capsule())
        }
      }
      .animation(nil, value: isExpanded)

    case .array(let elements):
      DisclosureGroup(isExpanded: $isExpanded) {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(Array(elements.enumerated()), id: \.offset) { index, child in
            let childPath = "\(path)[\(index)]"
            StructFieldRow(
              key: "[\(index)]",
              path: childPath,
              value: child,
              isEditable: isEditable
            ) { newChildVal in
              var newElements = elements
              newElements[index] = newChildVal
              onUpdate?(.array(newElements))
            }
          }
        }
        .padding(.leading, 12)
        .padding(.top, 6)
      } label: {
        HStack {
          Text(key)
            .font(.subheadline.weight(.medium))
            .foregroundColor(.primary)
          Spacer()
          Text("[\(elements.count)]")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.purple.opacity(0.15))
            .foregroundColor(.purple)
            .clipShape(Capsule())
        }
      }
      .animation(nil, value: isExpanded)

    default:
      if isEditable {
        StructLeafEditor(label: key, topicPath: path, value: value) { newLeaf in
          onUpdate?(newLeaf)
        }
        .padding(.vertical, 2)
      } else {
        HStack {
          Text(key)
            .font(.subheadline)
            .foregroundColor(.secondary)
          Spacer()
          if case .enumValue(let name, _, _) = value {
            Text(name)
              .font(.system(.subheadline, design: .monospaced).weight(.semibold))
              .foregroundColor(.purple)
              .padding(.horizontal, 8)
              .padding(.vertical, 2)
              .background(Color.purple.opacity(0.12))
              .clipShape(Capsule())
          } else if case .bool(let b) = value {
            Text(b ? "true" : "false")
              .font(.system(.subheadline, design: .monospaced).weight(.semibold))
              .foregroundColor(b ? .accentColor : .secondary)
          } else {
            Text(value.formattedSummary)
              .font(.system(.subheadline, design: .monospaced).weight(.semibold))
              .foregroundColor(.primary)
              .lineLimit(1)
          }
        }
        .padding(.vertical, 4)
        .frame(minHeight: 32)
      }
    }
  }
}
