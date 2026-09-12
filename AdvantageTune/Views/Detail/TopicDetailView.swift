// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

public struct TopicDetailView: View {
  @Bindable var store: NTStore
  public let topic: NT4Topic

  // Local primitive editing state
  @State private var boolValue: Bool = false
  @State private var textValue: String = ""
  @State private var doubleValue: Double = 0.0
  @State private var intValue: Int64 = 0
  @State private var localStructValue: StructValue? = nil
  @State private var hasInitialized = false

  private var isPublished: Bool {
    store.isPublished(topicName: topic.name)
  }

  private var latestValue: TopicValue? {
    store.latestValues[topic.name]
  }

  public var body: some View {
    List {
      // MARK: - Metadata
      Section {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            TypeBadgeView(typeName: topic.type, compact: false)
            Spacer()
            if topic.isImmutable {
              Text("READ ONLY")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.2))
                .foregroundColor(.secondary)
                .clipShape(Capsule())
            } else if isPublished {
              Text("PUBLISHED")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.2))
                .foregroundColor(.orange)
                .clipShape(Capsule())
            }
          }

          Text(topic.name)
            .font(.headline)
            .lineLimit(2)
            .truncationMode(.middle)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .topicContextMenu(topicName: topic.name, value: latestValue)
      } header: {
        Text("Topic Details")
      }

      // MARK: - Live Telemetry
      if !isRawTopic || isDecodedStruct {
        Section {
          Group {
            if isCompositeValue {
              VStack(alignment: .leading, spacing: 6) {
                Text("Server Value")
                  .font(.subheadline.weight(.medium))
                  .foregroundColor(.secondary)

                if let val = latestValue {
                  Text(val.formattedString)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(8)
                    .multilineTextAlignment(.leading)
                } else {
                  Text("Waiting for value...")
                    .italic()
                    .foregroundColor(.secondary)
                }
              }
              .padding(.vertical, 4)
            } else {
              HStack {
                Text("Server Value")
                  .foregroundColor(.secondary)
                Spacer()
                if let val = latestValue {
                  Text(val.formattedString)
                    .font(.system(.body, design: .monospaced).weight(.bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.trailing)
                } else {
                  Text("Waiting for value...")
                    .italic()
                    .foregroundColor(.secondary)
                }
              }
            }
          }
          .contentShape(Rectangle())
          .topicContextMenu(topicName: topic.name, value: latestValue)
        } header: {
          Text("Live Telemetry")
        }
      }

      // MARK: - Struct Inspector
      if let activeStruct =
        (topic.isImmutable ? currentLatestStruct : (localStructValue ?? currentLatestStruct)),
        let structTypeName = currentStructTypeName
      {
        Section {
          StructInspectorView(
            structValue: activeStruct,
            rootTypeName: structTypeName,
            topicPath: topic.name,
            isEditable: !topic.isImmutable
          ) { updatedStruct in
            localStructValue = updatedStruct
            Task { @MainActor in
              if topic.type.hasPrefix("proto:") || topic.isProtobuf {
                if let encodedData = await ProtoDecoder.shared.encode(
                  typeName: structTypeName, value: updatedStruct)
                {
                  applyUpdate(
                    .structValue(typeName: structTypeName, value: updatedStruct, raw: encodedData))
                }
              } else {
                if let encodedData = await StructDecoder.shared.encode(
                  typeName: structTypeName, value: updatedStruct)
                {
                  applyUpdate(
                    .structValue(typeName: structTypeName, value: updatedStruct, raw: encodedData))
                }
              }
            }
          }
        } header: {
          Text(
            topic.type.hasPrefix("proto:") || topic.isProtobuf
              ? "Protobuf Fields" : "Struct Fields" as LocalizedStringKey
          )
        } footer: {
          if !topic.isImmutable {
            Text("Subfield edits are packed into binary format and published automatically.")
          }
        }
      }

      // MARK: - Binary Telemetry
      if isRawTopic {
        Section {
          RawTelemetryView(topic: topic, rawData: latestValueData, fallbackValue: latestValue)
        } header: {
          Text("Binary Telemetry")
        }
      }

      // MARK: - Primitive Array Editor
      if isPrimitiveArrayTopic && !topic.isImmutable {
        Section {
          if let val = latestValue {
            TopicArrayEditorView(topicName: topic.name, value: val, onCommit: applyUpdate)
          } else {
            Text("Waiting for array data...")
              .italic()
              .foregroundColor(.secondary)
          }
        } header: {
          Text("Edit Array Elements")
        } footer: {
          Text("Changes are published automatically to NetworkTables.")
        }
      }

      // MARK: - Primitive Value Editor
      if !topic.isImmutable && !topic.isArray && !isRawTopic && !topic.type.hasPrefix("struct:")
        && !topic.type.hasPrefix("proto:")
      {
        Section {
          primitiveEditorControls
        } header: {
          Text("Edit Value")
        } footer: {
          Text("Changes are published automatically to NetworkTables.")
        }
      }

      // MARK: - Actions Section
      if isPublished && !topic.isImmutable {
        Section {
          Button {
            Haptics.impact(.medium)
            store.unpublishTopic(name: topic.name)
          } label: {
            HStack {
              Spacer()
              Label("Unpublish", systemImage: "xmark.octagon")
              Spacer()
            }
          }
          .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }

          Button(role: .destructive) {
            Haptics.notification(.warning)
            store.revertAndUnpublishTopic(name: topic.name)
            syncLocalStateWithLatest()
          } label: {
            HStack {
              Spacer()
              Label("Revert", systemImage: "arrow.uturn.backward")
                .foregroundColor(.red)
              Spacer()
            }
          }
          .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        }
      }
    }
    .navigationTitle(topic.name.split(separator: "/").last.map(String.init) ?? topic.name)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      store.acquireSubscription(for: topic.name)
      syncLocalStateWithLatest()
    }
    .onDisappear {
      store.releaseSubscription(for: topic.name)
    }
    .onChange(of: latestValue) { _, _ in
      if !hasInitialized || (!isPublished && localStructValue == nil) {
        syncLocalStateWithLatest()
      }
    }
  }

  private var isRawTopic: Bool {
    topic.isRaw
  }

  private var isDecodedStruct: Bool {
    if case .structValue = latestValue {
      return true
    }
    return false
  }

  private var currentStructTypeName: String? {
    if case .structValue(let typeName, _, _) = latestValue {
      return typeName
    }
    if topic.type.hasPrefix("struct:") || topic.type.hasPrefix("proto:") {
      return topic.type
    }
    return nil
  }

  private var currentLatestStruct: StructValue? {
    if case .structValue(_, let structVal, _) = latestValue {
      return structVal
    }
    return nil
  }

  private var isPrimitiveArrayTopic: Bool {
    topic.isArray && !topic.type.hasPrefix("struct:") && !topic.type.hasPrefix("proto:")
  }

  private var isCompositeValue: Bool {
    isDecodedStruct || isPrimitiveArrayTopic
  }

  // MARK: - Primitive Value Editor

  @ViewBuilder
  private var primitiveEditorControls: some View {
    let type = topic.type.lowercased()

    if type == "boolean" {
      BoolLeafEditor(label: "Local Value", value: boolValue) { newBool in
        boolValue = newBool
        applyUpdate(.boolean(newBool))
      }

    } else if type == "double" {
      DoubleLeafEditor(
        label: "Local Value", topicPath: topic.name, value: doubleValue,
        isFloat: false
      ) { newDouble in
        doubleValue = newDouble
        applyUpdate(.double(newDouble))
      }

    } else if type == "float" {
      DoubleLeafEditor(
        label: "Local Value", topicPath: topic.name, value: doubleValue,
        isFloat: true
      ) { newDouble in
        doubleValue = newDouble
        applyUpdate(.float(Float(newDouble)))
      }

    } else if type == "int" {
      IntLeafEditor(
        label: "Local Value", value: intValue, isUnsigned: false
      ) { newInt in
        intValue = newInt
        applyUpdate(.int(newInt))
      }

    } else {
      StringLeafEditor(label: "Local Value", value: textValue) { newText in
        textValue = newText
        applyUpdate(.string(newText))
      }
    }
  }

  private var latestValueData: Data? {
    if case .raw(let d) = latestValue {
      return d
    }
    if case .structValue(_, _, let d) = latestValue {
      return d
    }
    if case .protoRaw(_, let d) = latestValue {
      return d
    }
    return nil
  }

  private func syncLocalStateWithLatest() {
    let valToUse = store.tunedEntries[topic.name]?.currentValue ?? latestValue
    guard let val = valToUse else { return }
    hasInitialized = true
    switch val {
    case .boolean(let b):
      boolValue = b
    case .double(let d):
      doubleValue = d
    case .float(let f):
      doubleValue = Double(f)
    case .int(let i):
      intValue = i
    case .string(let s):
      textValue = s
    case .raw:
      textValue = ""
    case .structValue(_, let structVal, _):
      localStructValue = structVal
    default:
      textValue = val.formattedString
    }
  }

  private func applyUpdate(_ newValue: TopicValue) {
    store.updateValue(for: topic, newValue: newValue)
  }
}
