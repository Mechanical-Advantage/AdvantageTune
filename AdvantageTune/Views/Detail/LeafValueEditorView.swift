// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import SwiftUI

// MARK: - Double & Float Leaf Editor

public struct DoubleLeafEditor: View {
  public let label: String?
  public let topicPath: String?
  public let value: Double
  public let isFloat: Bool
  public let showStepPicker: Bool
  public let onDelete: (() -> Void)?
  public let onCommit: (Double) -> Void

  @State private var localValue: Double
  @State private var stepSize: Double
  @FocusState private var isFocused: Bool

  public init(
    label: String? = nil,
    topicPath: String? = nil,
    value: Double,
    isFloat: Bool = false,
    showStepPicker: Bool = true,
    onDelete: (() -> Void)? = nil,
    onCommit: @escaping (Double) -> Void
  ) {
    self.label = label
    self.topicPath = topicPath
    self.value = value
    self.isFloat = isFloat
    self.showStepPicker = showStepPicker
    self.onDelete = onDelete
    self.onCommit = onCommit
    _localValue = State(initialValue: value)

    let initialStep: Double
    if let path = topicPath,
      let saved = UserDefaults.standard.object(forKey: UserDefaultsKeys.stepSize(for: path))
        as? Double
    {
      initialStep = saved
    } else if let global =
      (UserDefaults.standard.object(forKey: UserDefaultsKeys.defaultStepSize)
      ?? UserDefaults.standard.object(forKey: "preferredDoubleStepSize")) as? Double
    {
      initialStep = global
    } else {
      initialStep = 0.1
    }
    _stepSize = State(initialValue: initialStep)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LeafEditorContainer(
        label: label,
        isFocused: isFocused,
        onDelete: onDelete,
        onCommit: {
          commitValue(localValue)
          isFocused = false
        }
      ) {
        TextField("0.0", value: $localValue, format: .number.grouping(.never))
          .focused($isFocused)
          .keyboardType(.numbersAndPunctuation)
          .multilineTextAlignment(.trailing)
          .font(.system(.subheadline, design: .monospaced).weight(.semibold))
          .onSubmit {
            commitValue(localValue)
          }
      }

      // Stepper Buttons
      HStack(spacing: 8) {
        Button {
          Haptics.impact(.light)
          localValue = applyStep(-stepSize)
          commitValue(localValue)
        } label: {
          Text("-\(formattedStep)")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)

        Button {
          Haptics.impact(.light)
          localValue = applyStep(stepSize)
          commitValue(localValue)
        } label: {
          Text("+\(formattedStep)")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
      }

      // Step Size Selector
      if showStepPicker {
        Picker(
          "Step Size",
          selection: Binding(
            get: { stepSize },
            set: { newStep in
              if stepSize != newStep {
                Haptics.selection()
              }
              stepSize = newStep
              if let path = topicPath {
                UserDefaults.standard.set(newStep, forKey: UserDefaultsKeys.stepSize(for: path))
              }
              UserDefaults.standard.set(newStep, forKey: UserDefaultsKeys.defaultStepSize)
            }
          )
        ) {
          Text("0.001").tag(0.001)
          Text("0.01").tag(0.01)
          Text("0.1").tag(0.1)
          Text("1.0").tag(1.0)
          Text("10").tag(10.0)
        }
        .pickerStyle(.segmented)
      }
    }
    .padding(.vertical, 4)
    .onChange(of: isFocused) { _, focused in
      if !focused {
        commitValue(localValue)
      }
    }
    .onChange(of: value) { _, newValue in
      if !isFocused {
        localValue = newValue
      }
    }
    .onChange(of: topicPath) { _, newPath in
      if let path = newPath,
        let saved = UserDefaults.standard.object(forKey: UserDefaultsKeys.stepSize(for: path))
          as? Double
      {
        stepSize = saved
      }
    }
  }

  private var formattedStep: String {
    if stepSize == 0.001 { return "0.001" }
    if stepSize == 0.01 { return "0.01" }
    if stepSize == 0.1 { return "0.1" }
    if stepSize == 1.0 { return "1.0" }
    if stepSize == 10.0 { return "10" }
    return stepSize.formatted(.number.grouping(.never))
  }

  private func applyStep(_ delta: Double) -> Double {
    let raw = localValue + delta
    let precision: Double
    if stepSize == 0.001 {
      precision = 1000
    } else if stepSize == 0.01 {
      precision = 100
    } else if stepSize == 0.1 {
      precision = 10
    } else if stepSize == 1.0 {
      precision = 1
    } else if stepSize == 10.0 {
      precision = 0.1
    } else {
      precision = 1_000_000
    }

    let rounded = (raw * precision).rounded() / precision
    return rounded
  }

  private func commitValue(_ val: Double) {
    let clean = val
    if clean != value {
      onCommit(clean)
    }
  }
}

// MARK: - Integer Leaf Editor

public struct IntLeafEditor: View {
  public let label: String?
  public let value: Int64
  public let isUnsigned: Bool
  public let onDelete: (() -> Void)?
  public let onCommit: (Int64) -> Void

  @State private var localValue: Int64
  @FocusState private var isFocused: Bool

  public init(
    label: String? = nil,
    value: Int64,
    isUnsigned: Bool = false,
    onDelete: (() -> Void)? = nil,
    onCommit: @escaping (Int64) -> Void
  ) {
    self.label = label
    self.value = value
    self.isUnsigned = isUnsigned
    self.onDelete = onDelete
    self.onCommit = onCommit
    _localValue = State(initialValue: value)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      LeafEditorContainer(
        label: label,
        isFocused: isFocused,
        onDelete: onDelete,
        onCommit: {
          commitValue(localValue)
          isFocused = false
        }
      ) {
        TextField("0", value: $localValue, format: .number.grouping(.never))
          .focused($isFocused)
          .keyboardType(isUnsigned ? .numberPad : .numbersAndPunctuation)
          .multilineTextAlignment(.trailing)
          .font(.system(.subheadline, design: .monospaced).weight(.semibold))
          .onSubmit {
            commitValue(localValue)
          }
      }

      HStack(spacing: 8) {
        Button {
          if !isUnsigned || localValue > 0 {
            Haptics.impact(.light)
            localValue -= 1
            commitValue(localValue)
          }
        } label: {
          Text("-1")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)

        Button {
          Haptics.impact(.light)
          localValue += 1
          commitValue(localValue)
        } label: {
          Text("+1")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.borderless)
      }
    }
    .padding(.vertical, 4)
    .onChange(of: isFocused) { _, focused in
      if !focused {
        commitValue(localValue)
      }
    }
    .onChange(of: value) { _, newValue in
      if !isFocused {
        localValue = newValue
      }
    }
  }

  private func commitValue(_ val: Int64) {
    if val != value {
      onCommit(val)
    }
  }
}

// MARK: - Boolean Leaf Editor

public struct BoolLeafEditor: View {
  public let label: String?
  public let value: Bool
  public let onDelete: (() -> Void)?
  public let onCommit: (Bool) -> Void

  public init(
    label: String? = nil,
    value: Bool,
    onDelete: (() -> Void)? = nil,
    onCommit: @escaping (Bool) -> Void
  ) {
    self.label = label
    self.value = value
    self.onDelete = onDelete
    self.onCommit = onCommit
  }

  public var body: some View {
    HStack {
      Toggle(
        isOn: Binding(
          get: { value },
          set: { newBool in
            onCommit(newBool)
          }
        )
      ) {
        if let label = label {
          Text(label)
            .foregroundColor(.secondary)
        }
      }
      .tint(.accentColor)

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
    .padding(.vertical, 4)
    .frame(minHeight: 38)
  }
}

// MARK: - String Leaf Editor

public struct StringLeafEditor: View {
  public let label: String?
  public let value: String
  public let onDelete: (() -> Void)?
  public let onCommit: (String) -> Void

  @State private var localValue: String
  @FocusState private var isFocused: Bool

  public init(
    label: String? = nil,
    value: String,
    onDelete: (() -> Void)? = nil,
    onCommit: @escaping (String) -> Void
  ) {
    self.label = label
    self.value = value
    self.onDelete = onDelete
    self.onCommit = onCommit
    _localValue = State(initialValue: value)
  }

  public var body: some View {
    LeafEditorContainer(
      label: label,
      isFocused: isFocused,
      onDelete: onDelete,
      onCommit: {
        commit()
        isFocused = false
      }
    ) {
      TextField("Value", text: $localValue)
        .focused($isFocused)
        .multilineTextAlignment(.trailing)
        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
        .onSubmit {
          commit()
        }
    }
    .padding(.vertical, 4)
    .onChange(of: isFocused) { _, focused in
      if !focused {
        commit()
      }
    }
    .onChange(of: value) { _, newValue in
      if !isFocused {
        localValue = newValue
      }
    }
  }

  private func commit() {
    if localValue != value {
      onCommit(localValue)
    }
  }
}

// MARK: - Enum Menu Button

struct EnumMenuButton: UIViewRepresentable {
  let title: String
  let options: [(key: Int64, value: String)]
  let selectedKey: Int64
  let onSelect: (String, Int64) -> Void

  final class Coordinator {
    var options: [(key: Int64, value: String)] = []
    var selectedKey: Int64 = 0
    var onSelect: ((String, Int64) -> Void)?
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  func makeUIView(context: Context) -> UIButton {
    let button = UIButton(type: .system)
    button.showsMenuAsPrimaryAction = true
    button.setContentHuggingPriority(.required, for: .horizontal)
    button.setContentCompressionResistancePriority(.required, for: .horizontal)
    button.setContentHuggingPriority(.required, for: .vertical)
    button.setContentCompressionResistancePriority(.required, for: .vertical)

    let coordinator = context.coordinator
    coordinator.options = options
    coordinator.selectedKey = selectedKey
    coordinator.onSelect = onSelect

    button.menu = UIMenu(children: [
      UIDeferredMenuElement.uncached { [weak coordinator] completion in
        guard let coordinator = coordinator else {
          completion([])
          return
        }
        let currentKey = coordinator.selectedKey
        let actions = coordinator.options.map { opt in
          UIAction(
            title: "\(opt.value) (\(opt.key))",
            state: opt.key == currentKey ? .on : .off
          ) { _ in
            Haptics.selection()
            DispatchQueue.main.async {
              coordinator.onSelect?(opt.value, opt.key)
            }
          }
        }
        completion(actions)
      }
    ])

    updateButtonConfiguration(button)
    return button
  }

  func updateUIView(_ button: UIButton, context: Context) {
    context.coordinator.options = options
    context.coordinator.selectedKey = selectedKey
    context.coordinator.onSelect = onSelect

    updateButtonConfiguration(button)
  }

  private func updateButtonConfiguration(_ button: UIButton) {
    var config = UIButton.Configuration.tinted()
    config.baseBackgroundColor = .systemPurple
    config.baseForegroundColor = .systemPurple
    config.cornerStyle = .capsule
    config.contentInsets = NSDirectionalEdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10)

    let chevronConfig = UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)
    config.image = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: chevronConfig)
    config.imagePlacement = .trailing
    config.imagePadding = 5

    var attrTitle = AttributedString(title)
    attrTitle.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
    config.attributedTitle = attrTitle

    button.configuration = config
  }
}

// MARK: - Enum Leaf Editor

public struct EnumLeafEditor: View {
  public let label: String?
  public let name: String
  public let rawValue: Int64
  public let options: [Int64: String]
  public let onDelete: (() -> Void)?
  public let onCommit: (String, Int64) -> Void

  public init(
    label: String? = nil,
    name: String,
    rawValue: Int64,
    options: [Int64: String],
    onDelete: (() -> Void)? = nil,
    onCommit: @escaping (String, Int64) -> Void
  ) {
    self.label = label
    self.name = name
    self.rawValue = rawValue
    self.options = options
    self.onDelete = onDelete
    self.onCommit = onCommit
  }

  private var sortedOptions: [(key: Int64, value: String)] {
    options.sorted { $0.key < $1.key }
  }

  private var currentDisplayName: String {
    if let optName = options[rawValue] {
      return optName
    }
    if !name.isEmpty {
      return name
    }
    return "\(rawValue)"
  }

  public var body: some View {
    HStack {
      if let label = label {
        Text(label)
          .foregroundColor(.secondary)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      Spacer(minLength: 20)

      if !options.isEmpty {
        EnumMenuButton(
          title: currentDisplayName,
          options: sortedOptions,
          selectedKey: rawValue
        ) { newName, newRaw in
          onCommit(newName, newRaw)
        }
        .fixedSize()
      } else {
        Text(currentDisplayName)
          .font(.system(.subheadline, design: .monospaced).weight(.semibold))
          .foregroundColor(.purple)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(Color.purple.opacity(0.12))
          .clipShape(Capsule())
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
    .padding(.vertical, 4)
    .frame(minHeight: 38)
  }
}

// MARK: - Struct Leaf Editor

public struct StructLeafEditor: View {
  public let label: String?
  public let topicPath: String?
  public let value: StructValue
  public let onCommit: (StructValue) -> Void

  public init(
    label: String? = nil, topicPath: String? = nil, value: StructValue,
    onCommit: @escaping (StructValue) -> Void
  ) {
    self.label = label
    self.topicPath = topicPath
    self.value = value
    self.onCommit = onCommit
  }

  public var body: some View {
    switch value {
    case .bool(let b):
      BoolLeafEditor(label: label, value: b) { newB in
        onCommit(.bool(newB))
      }

    case .double(let d):
      DoubleLeafEditor(
        label: label, topicPath: topicPath, value: d, isFloat: false, showStepPicker: true
      ) { newD in
        onCommit(.double(newD))
      }

    case .float(let f):
      DoubleLeafEditor(
        label: label, topicPath: topicPath, value: Double(f), isFloat: true, showStepPicker: true
      ) { newD in
        onCommit(.float(Float(newD)))
      }

    case .int(let i):
      IntLeafEditor(label: label, value: i, isUnsigned: false) { newI in
        onCommit(.int(newI))
      }

    case .uint(let u):
      IntLeafEditor(label: label, value: Int64(u), isUnsigned: true) { newI in
        onCommit(.uint(UInt64(max(0, newI))))
      }

    case .string(let s):
      StringLeafEditor(label: label, value: s) { newS in
        onCommit(.string(newS))
      }

    case .enumValue(let name, let rawVal, let options):
      EnumLeafEditor(label: label, name: name, rawValue: rawVal, options: options) {
        newName, newI in
        onCommit(.enumValue(name: newName, rawValue: newI, options: options))
      }

    default:
      EmptyView()
    }
  }
}

public struct ArrayEditorContainer<Element, ElementEditor: View>: View {
  public let elements: [Element]
  public let defaultValue: Element
  public let onUpdate: ([Element]) -> Void
  @ViewBuilder public let editor: (Int, Element, @escaping (Element) -> Void, @escaping () -> Void) -> ElementEditor

  public init(
    elements: [Element],
    defaultValue: Element,
    onUpdate: @escaping ([Element]) -> Void,
    @ViewBuilder editor:
      @escaping (Int, Element, @escaping (Element) -> Void, @escaping () -> Void) -> ElementEditor
  ) {
    self.elements = elements
    self.defaultValue = defaultValue
    self.onUpdate = onUpdate
    self.editor = editor
  }

  public var body: some View {
    ForEach(Array(elements.enumerated()), id: \.offset) { index, item in
      editor(
        index,
        item,
        { newValue in
          var newArr = elements
          if index < newArr.count {
            newArr[index] = newValue
            onUpdate(newArr)
          }
        },
        {
          Haptics.impact(.medium)
          var newArr = elements
          if index < newArr.count {
            newArr.remove(at: index)
            onUpdate(newArr)
          }
        }
      )
      .padding(.vertical, 2)
    }

    Button {
      Haptics.impact(.light)
      var newArr = elements
      newArr.append(defaultValue)
      onUpdate(newArr)
    } label: {
      Label("Add Element", systemImage: "plus.circle.fill")
        .font(.subheadline.weight(.semibold))
        .foregroundColor(.accentColor)
    }
    .padding(.vertical, 4)
  }
}

// MARK: - Topic Array Editor View

public struct TopicArrayEditorView: View {
  public let topicName: String
  public let value: TopicValue
  public let onCommit: (TopicValue) -> Void

  public init(topicName: String, value: TopicValue, onCommit: @escaping (TopicValue) -> Void) {
    self.topicName = topicName
    self.value = value
    self.onCommit = onCommit
  }

  public var body: some View {
    switch value {
    case .doubleArray(let arr):
      ArrayEditorContainer(
        elements: arr, defaultValue: 0.0, onUpdate: { onCommit(.doubleArray($0)) }
      ) { index, item, commit, delete in
        DoubleLeafEditor(
          label: "[\(index)]",
          topicPath: "\(topicName)[\(index)]",
          value: item,
          isFloat: false,
          showStepPicker: true,
          onDelete: delete,
          onCommit: commit
        )
      }

    case .floatArray(let arr):
      ArrayEditorContainer(
        elements: arr, defaultValue: 0.0, onUpdate: { onCommit(.floatArray($0)) }
      ) { index, item, commit, delete in
        DoubleLeafEditor(
          label: "[\(index)]",
          topicPath: "\(topicName)[\(index)]",
          value: Double(item),
          isFloat: true,
          showStepPicker: true,
          onDelete: delete,
          onCommit: { commit(Float($0)) }
        )
      }

    case .intArray(let arr):
      ArrayEditorContainer(elements: arr, defaultValue: 0, onUpdate: { onCommit(.intArray($0)) }) {
        index, item, commit, delete in
        IntLeafEditor(
          label: "[\(index)]",
          value: item,
          onDelete: delete,
          onCommit: commit
        )
      }

    case .booleanArray(let arr):
      ArrayEditorContainer(
        elements: arr, defaultValue: false, onUpdate: { onCommit(.booleanArray($0)) }
      ) { index, item, commit, delete in
        BoolLeafEditor(
          label: "[\(index)]",
          value: item,
          onDelete: delete,
          onCommit: commit
        )
      }

    case .stringArray(let arr):
      ArrayEditorContainer(
        elements: arr, defaultValue: "", onUpdate: { onCommit(.stringArray($0)) }
      ) { index, item, commit, delete in
        StringLeafEditor(
          label: "[\(index)]",
          value: item,
          onDelete: delete,
          onCommit: commit
        )
      }

    default:
      Text("Unsupported array format")
        .foregroundColor(.secondary)
    }
  }
}
