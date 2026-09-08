// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

/// Engine to compile WPILib Struct schemas and decode binary struct payloads.
///
/// Specification: https://github.com/wpilibsuite/allwpilib/blob/main/wpiutil/doc/struct.adoc
public actor StructDecoder {
  public static let shared = StructDecoder()

  private var schemaStrings: [String: String] = [:]
  private var schemas: [String: Schema] = [:]

  public init() {}

  // MARK: - Schema Management

  /// Registers a schema buffer announced under `/.schema/struct:<TypeName>`.
  public func addSchema(name: String, schemaData: Data) {
    guard let schemaStr = String(data: schemaData, encoding: .utf8) else { return }

    if schemaStrings[name] != nil { return }
    schemaStrings[name] = schemaStr

    // Iteratively compile schemas in dependency order
    while true {
      var compileSuccess = false
      for (schemaName, str) in schemaStrings {
        if schemas[schemaName] == nil {
          let success = compileSchema(name: schemaName, schema: str)
          if success {
            compileSuccess = true
          }
        }
      }
      if !compileSuccess {
        break
      }
    }
  }

  /// Checks if a struct schema is registered and compiled.
  public func hasSchema(for typeName: String) -> Bool {
    let clean = cleanTypeName(typeName)
    return schemas[clean] != nil
  }

  nonisolated public func cleanTypeName(_ typeName: String) -> String {
    var clean = typeName
    if clean.hasPrefix("struct:") {
      clean = String(clean.dropFirst("struct:".count))
    }
    if clean.hasSuffix("[]") {
      clean = String(clean.dropLast(2))
    }
    return clean
  }

  // MARK: - Schema Compilation

  private func compileSchema(name: String, schema: String) -> Bool {
    let valueSchemaStrs =
      schema
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .split(separator: ";")
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }

    var valueSchemas: [ValueSchema] = []

    for rawStr in valueSchemaStrs {
      var schemaStr = rawStr
      var enumData: [Int64: String]? = nil

      // Check for enum declaration: enum {A = 0, B = 1} int8 fieldName or enum Name { ... }
      if schemaStr.hasPrefix("enum") {
        if let startIdx = schemaStr.firstIndex(of: "{"),
          let endIdx = schemaStr.firstIndex(of: "}")
        {
          let enumBody = schemaStr[schemaStr.index(after: startIdx)..<endIdx]
          var dict: [Int64: String] = [:]
          let pairs = enumBody.split(separator: ",")
          for pair in pairs {
            let trimmedPair = pair.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPair.isEmpty else { continue }
            let parts = trimmedPair.split(separator: "=").map {
              $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if parts.count == 2 {
              let rawValStr = parts[1]
              let rawVal: Int64?
              if rawValStr.hasPrefix("0x") || rawValStr.hasPrefix("0X") {
                rawVal = Int64(rawValStr.dropFirst(2), radix: 16)
              } else {
                rawVal = Int64(rawValStr)
              }
              if let val = rawVal {
                dict[val] = parts[0]
              }
            }
          }
          enumData = dict.isEmpty ? nil : dict
          schemaStr = String(schemaStr[schemaStr.index(after: endIdx)...]).trimmingCharacters(
            in: .whitespacesAndNewlines)
        }
      }

      var tokens = schemaStr.split(separator: " ").map { String($0) }.filter { !$0.isEmpty }
      guard !tokens.isEmpty else { continue }

      var typeStr = tokens.removeFirst()
      if typeStr.hasPrefix("struct:") {
        typeStr = String(typeStr.dropFirst("struct:".count))
      }

      // If custom type and not compiled yet, fail dependency
      if ValueType(rawValue: typeStr) == nil && schemas[typeStr] == nil {
        return false
      }

      let nameStr = tokens.joined()
      var fieldName: String
      var bitfieldWidth: Int? = nil
      var arrayLength: Int? = nil

      if nameStr.contains(":") {
        let parts = nameStr.split(separator: ":").map { String($0) }
        fieldName = parts[0]
        if parts.count > 1, let width = Int(parts[1]) {
          bitfieldWidth = width
        }
      } else if nameStr.contains("[") {
        let parts = nameStr.split(separator: "[").map { String($0) }
        fieldName = parts[0]
        if parts.count > 1 {
          let lenStr = parts[1].replacingOccurrences(of: "]", with: "").trimmingCharacters(
            in: .whitespaces)
          arrayLength = Int(lenStr)
        }
      } else {
        fieldName = nameStr
      }

      valueSchemas.append(
        ValueSchema(
          name: fieldName,
          type: typeStr,
          enumData: enumData,
          bitfieldWidth: bitfieldWidth,
          arrayLength: arrayLength,
          bitRange: (0, 0)
        ))
    }

    // Calculate bit positions
    var bitPosition = 0
    var bitfieldPosition: Int? = nil
    var bitfieldLength: Int? = nil

    for i in 0..<valueSchemas.count {
      let valSchema = valueSchemas[i]

      if let primitiveType = ValueType(rawValue: valSchema.type) {
        let typeLength = primitiveType.maxBits

        if let bfWidth = valSchema.bitfieldWidth {
          let valueBitLength = min(bfWidth, typeLength)
          if bitfieldPosition == nil || bitfieldLength == nil
            || (primitiveType != .bool && bitfieldLength != typeLength)
            || (bitfieldPosition! + valueBitLength > bitfieldLength!)
          {

            if let pos = bitfieldPosition, let len = bitfieldLength {
              bitPosition += len - pos
            }
            bitfieldPosition = 0
            bitfieldLength = typeLength
          }

          valueSchemas[i].bitRange = (bitPosition, bitPosition + valueBitLength)
          bitfieldPosition = bitfieldPosition! + valueBitLength
          bitPosition += valueBitLength
        } else {
          if let pos = bitfieldPosition, let len = bitfieldLength {
            bitPosition += len - pos
          }
          bitfieldPosition = nil
          bitfieldLength = nil

          var bitLength = typeLength
          if let arrLen = valSchema.arrayLength {
            bitLength *= arrLen
          }
          valueSchemas[i].bitRange = (bitPosition, bitPosition + bitLength)
          bitPosition += bitLength
        }
      } else if let childSchema = schemas[valSchema.type] {
        // Child struct
        if let pos = bitfieldPosition, let len = bitfieldLength {
          bitPosition += len - pos
        }
        bitfieldPosition = nil
        bitfieldLength = nil

        var length = childSchema.length
        if let arrLen = valSchema.arrayLength {
          length *= arrLen
        }
        valueSchemas[i].bitRange = (bitPosition, bitPosition + length)
        bitPosition += length
      }
    }

    if let pos = bitfieldPosition, let len = bitfieldLength {
      bitPosition += len - pos
    }

    schemas[name] = Schema(length: bitPosition, valueSchemas: valueSchemas)
    return true
  }

  // MARK: - Decoding

  /// Decodes a struct binary buffer given its schema name.
  public func decode(typeName: String, data: Data) -> StructValue? {

    let clean = cleanTypeName(typeName)
    let isArray = typeName.hasSuffix("[]")

    if isArray {
      return decodeArrayInternal(name: clean, data: data)
    } else {
      return decodeInternal(name: clean, data: data)
    }
  }

  // MARK: - Encoding / Binary Packing

  /// Encodes a StructValue back into a WPILib struct binary buffer according to the registered schema.
  public func encode(typeName: String, value: StructValue) -> Data? {

    let clean = cleanTypeName(typeName)
    let isArray = typeName.hasSuffix("[]")

    if isArray {
      guard case .array(let elements) = value else { return nil }
      var result = Data()
      for element in elements {
        guard let itemData = encodeInternal(name: clean, value: element) else { return nil }
        result.append(itemData)
      }
      return result
    } else {
      return encodeInternal(name: clean, value: value)
    }
  }

  private func encodeInternal(name: String, value: StructValue) -> Data? {
    guard let schema = schemas[name] else { return nil }
    guard case .object(let fields) = value else { return nil }

    let fieldMap = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.value) })
    var bits = Array(repeating: false, count: schema.length)

    for valueSchema in schema.valueSchemas {
      let fieldVal = fieldMap[valueSchema.name]
      let range = valueSchema.bitRange
      let bitLen = range.1 - range.0

      if let primitiveType = ValueType(rawValue: valueSchema.type) {
        if let arrayLength = valueSchema.arrayLength {
          let elements: [StructValue]
          if let f = fieldVal, case .array(let arr) = f {
            elements = arr
          } else if let f = fieldVal, case .string(let str) = f, primitiveType == .char {
            elements = str.map { StructValue.string(String($0)) }
          } else {
            elements = []
          }

          let itemBits = bitLen / max(arrayLength, 1)
          for i in 0..<arrayLength {
            let itemVal = i < elements.count ? elements[i] : defaultValue(for: primitiveType)
            let itemBitArray = encodePrimitiveToBits(value: itemVal, type: primitiveType)
            let targetStart = range.0 + (i * itemBits)
            for b in 0..<min(itemBits, itemBitArray.count) {
              if targetStart + b < bits.count {
                bits[targetStart + b] = itemBitArray[b]
              }
            }
          }
        } else {
          let val = fieldVal ?? defaultValue(for: primitiveType)
          let fieldBitArray = encodePrimitiveToBits(value: val, type: primitiveType)
          for b in 0..<min(bitLen, fieldBitArray.count) {
            if range.0 + b < bits.count {
              bits[range.0 + b] = fieldBitArray[b]
            }
          }
        }
      } else if schemas[valueSchema.type] != nil {
        // Child struct
        if let arrayLength = valueSchema.arrayLength {
          var elements: [StructValue] = []
          if let f = fieldVal, case .array(let arr) = f {
            elements = arr
          }
          let childSchemaLen = schemas[valueSchema.type]!.length
          for i in 0..<arrayLength {
            let childVal = i < elements.count ? elements[i] : StructValue.object([])
            if let childData = encodeInternal(name: valueSchema.type, value: childVal) {
              let childBits = dataToBits(childData)
              let targetStart = range.0 + (i * childSchemaLen)
              for b in 0..<min(childSchemaLen, childBits.count) {
                if targetStart + b < bits.count {
                  bits[targetStart + b] = childBits[b]
                }
              }
            }
          }
        } else {
          let childVal = fieldVal ?? StructValue.object([])
          if let childData = encodeInternal(name: valueSchema.type, value: childVal) {
            let childBits = dataToBits(childData)
            for b in 0..<min(bitLen, childBits.count) {
              if range.0 + b < bits.count {
                bits[range.0 + b] = childBits[b]
              }
            }
          }
        }
      }
    }

    return bitsToData(bits)
  }

  private func encodePrimitiveToBits(value: StructValue, type: ValueType) -> [Bool] {
    var rawData = Data(count: type.maxBits / 8)

    switch (type, value) {
    case (.bool, .bool(let b)):
      rawData[0] = b ? 1 : 0
    case (.char, .string(let s)):
      if let first = s.utf8.first { rawData[0] = first }
    case (.int8, .int(let i)), (.int8, .enumValue(_, let i, _)):
      var val = Int8(truncatingIfNeeded: i)
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<1, with: $0) }
    case (.int16, .int(let i)), (.int16, .enumValue(_, let i, _)):
      var val = Int16(truncatingIfNeeded: i).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<2, with: $0) }
    case (.int32, .int(let i)), (.int32, .enumValue(_, let i, _)):
      var val = Int32(truncatingIfNeeded: i).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<4, with: $0) }
    case (.int64, .int(let i)), (.int64, .enumValue(_, let i, _)):
      var val = i.littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<8, with: $0) }
    case (.uint8, .uint(let u)):
      var val = UInt8(truncatingIfNeeded: u)
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<1, with: $0) }
    case (.uint8, .int(let i)), (.uint8, .enumValue(_, let i, _)):
      var val = UInt8(truncatingIfNeeded: i)
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<1, with: $0) }
    case (.uint16, .uint(let u)):
      var val = UInt16(truncatingIfNeeded: u).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<2, with: $0) }
    case (.uint16, .int(let i)), (.uint16, .enumValue(_, let i, _)):
      var val = UInt16(truncatingIfNeeded: i).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<2, with: $0) }
    case (.uint32, .uint(let u)):
      var val = UInt32(truncatingIfNeeded: u).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<4, with: $0) }
    case (.uint32, .int(let i)), (.uint32, .enumValue(_, let i, _)):
      var val = UInt32(truncatingIfNeeded: i).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<4, with: $0) }
    case (.uint64, .uint(let u)):
      var val = u.littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<8, with: $0) }
    case (.uint64, .int(let i)), (.uint64, .enumValue(_, let i, _)):
      var val = UInt64(bitPattern: i).littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<8, with: $0) }
    case (.float, .float(let f)), (.float32, .float(let f)):
      var val = f.bitPattern.littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<4, with: $0) }
    case (.float, .double(let d)), (.float32, .double(let d)):
      var val = Float(d).bitPattern.littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<4, with: $0) }
    case (.double, .double(let d)), (.float64, .double(let d)):
      var val = d.bitPattern.littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<8, with: $0) }
    case (.double, .float(let f)), (.float64, .float(let f)):
      var val = Double(f).bitPattern.littleEndian
      withUnsafeBytes(of: &val) { rawData.replaceSubrange(0..<8, with: $0) }
    default:
      break
    }

    return dataToBits(rawData)
  }

  private func defaultValue(for type: ValueType) -> StructValue {
    switch type {
    case .bool: return .bool(false)
    case .char: return .string("\0")
    case .int8, .int16, .int32, .int64: return .int(0)
    case .uint8, .uint16, .uint32, .uint64: return .uint(0)
    case .float, .float32: return .float(0)
    case .double, .float64: return .double(0)
    }
  }

  private func dataToBits(_ data: Data) -> [Bool] {
    var bits: [Bool] = []
    bits.reserveCapacity(data.count * 8)
    for byte in data {
      for shift in 0..<8 {
        bits.append(((byte >> shift) & 1) != 0)
      }
    }
    return bits
  }

  private func bitsToData(_ bits: [Bool]) -> Data {
    let byteCount = (bits.count + 7) / 8
    var result = Data(count: byteCount)
    for i in 0..<bits.count {
      if bits[i] {
        let byteIdx = i / 8
        let bitIdx = i % 8
        result[byteIdx] |= (1 << bitIdx)
      }
    }
    return result
  }

  private func decodeInternal(name: String, data: Data) -> StructValue? {
    guard let schema = schemas[name] else { return nil }
    var resultObj: [(key: String, value: StructValue)] = []

    for valueSchema in schema.valueSchemas {
      let slicedData = sliceBits(data: data, range: valueSchema.bitRange)

      if let primitiveType = ValueType(rawValue: valueSchema.type) {
        if let arrayLength = valueSchema.arrayLength {
          var arrayValues: [StructValue] = []
          let totalBits = valueSchema.bitRange.1 - valueSchema.bitRange.0
          let itemBits = totalBits / max(arrayLength, 1)

          for i in 0..<arrayLength {
            let itemRange = (i * itemBits, (i + 1) * itemBits)
            let itemData = sliceBits(data: slicedData, range: itemRange)
            if let decoded = decodePrimitive(
              data: itemData, type: primitiveType, enumData: valueSchema.enumData)
            {
              arrayValues.append(decoded)
            }
          }

          if primitiveType == .char {
            let chars = arrayValues.compactMap { val -> Character? in
              if case .string(let s) = val, let ch = s.first { return ch }
              return nil
            }
            let fullString = String(chars)
            let cString = String(fullString.prefix(while: { $0 != "\0" }))
            resultObj.append((key: valueSchema.name, value: .string(cString)))
          } else {
            resultObj.append((key: valueSchema.name, value: .array(arrayValues)))
          }
        } else {
          if let decoded = decodePrimitive(
            data: slicedData, type: primitiveType, enumData: valueSchema.enumData)
          {
            resultObj.append((key: valueSchema.name, value: decoded))
          }
        }
      } else if schemas[valueSchema.type] != nil {
        // Child struct
        if let arrayLength = valueSchema.arrayLength {
          if let decodedArr = decodeArrayInternal(
            name: valueSchema.type, data: slicedData, arrayLength: arrayLength)
          {
            resultObj.append((key: valueSchema.name, value: decodedArr))
          }
        } else {
          if let child = decodeInternal(name: valueSchema.type, data: slicedData) {
            resultObj.append((key: valueSchema.name, value: child))
          }
        }
      }
    }

    return .object(resultObj)
  }

  private func decodeArrayInternal(name: String, data: Data, arrayLength: Int? = nil)
    -> StructValue?
  {
    guard let schema = schemas[name] else { return nil }
    let itemByteCount = max(schema.length / 8, 1)
    let totalCount = arrayLength ?? (data.count / itemByteCount)

    var elements: [StructValue] = []
    for i in 0..<totalCount {
      let start = i * itemByteCount
      let end = min(start + itemByteCount, data.count)
      guard start < data.count else { break }
      let slice = data.subdata(in: start..<end)
      if let item = decodeInternal(name: name, data: slice) {
        elements.append(item)
      }
    }

    return .array(elements)
  }

  // MARK: - Primitive Value Decoding

  private func decodePrimitive(data: Data, type: ValueType, enumData: [Int64: String]?)
    -> StructValue?
  {
    var padded = Data(count: type.maxBits / 8)
    let copyLen = min(data.count, padded.count)
    padded.replaceSubrange(0..<copyLen, with: data.prefix(copyLen))

    var output: StructValue?

    padded.withUnsafeBytes { rawBuffer in
      guard let ptr = rawBuffer.baseAddress else { return }

      switch type {
      case .bool:
        let b = ptr.load(as: UInt8.self) != 0
        output = .bool(b)
      case .char:
        let c = ptr.load(as: UInt8.self)
        output = .string(String(UnicodeScalar(c)))
      case .int8:
        let v = ptr.load(as: Int8.self)
        output = .int(Int64(v))
      case .int16:
        let v = Int16(littleEndian: ptr.load(as: Int16.self))
        output = .int(Int64(v))
      case .int32:
        let v = Int32(littleEndian: ptr.load(as: Int32.self))
        output = .int(Int64(v))
      case .int64:
        let v = Int64(littleEndian: ptr.load(as: Int64.self))
        output = .int(v)
      case .uint8:
        let v = ptr.load(as: UInt8.self)
        output = .uint(UInt64(v))
      case .uint16:
        let v = UInt16(littleEndian: ptr.load(as: UInt16.self))
        output = .uint(UInt64(v))
      case .uint32:
        let v = UInt32(littleEndian: ptr.load(as: UInt32.self))
        output = .uint(UInt64(v))
      case .uint64:
        let v = UInt64(littleEndian: ptr.load(as: UInt64.self))
        output = .uint(v)
      case .float, .float32:
        let u = UInt32(littleEndian: ptr.load(as: UInt32.self))
        let f = Float(bitPattern: u)
        output = .float(f)
      case .double, .float64:
        let u = UInt64(littleEndian: ptr.load(as: UInt64.self))
        let d = Double(bitPattern: u)
        output = .double(d)
      }
    }

    if let enums = enumData {
      if case .int(let intVal) = output {
        let enumName = enums[intVal] ?? "\(intVal)"
        return .enumValue(name: enumName, rawValue: intVal, options: enums)
      }
      if case .uint(let uintVal) = output {
        let raw = Int64(uintVal)
        let enumName = enums[raw] ?? "\(raw)"
        return .enumValue(name: enumName, rawValue: raw, options: enums)
      }
    }

    return output
  }

  // MARK: - Bit Slicing

  private func sliceBits(data: Data, range: (Int, Int)) -> Data {
    let bitLen = range.1 - range.0
    guard bitLen > 0 else { return Data() }

    if range.0 % 8 == 0 && range.1 % 8 == 0 {
      let startByte = range.0 / 8
      let endByte = min(range.1 / 8, data.count)
      guard startByte < data.count else { return Data() }
      return data.subdata(in: startByte..<endByte)
    }

    // Bit-level slice
    var bits: [Bool] = []
    bits.reserveCapacity(data.count * 8)
    for byte in data {
      for shift in 0..<8 {
        bits.append(((byte >> shift) & 1) != 0)
      }
    }

    guard range.0 < bits.count else { return Data() }
    let slicedBits = Array(bits[range.0..<min(range.1, bits.count)])

    let byteCount = (slicedBits.count + 7) / 8
    var result = Data(count: byteCount)
    for i in 0..<slicedBits.count {
      if slicedBits[i] {
        let byteIdx = i / 8
        let bitIdx = i % 8
        result[byteIdx] |= (1 << bitIdx)
      }
    }
    return result
  }
}

// MARK: - Private Schema Types

private struct Schema {
  let length: Int
  let valueSchemas: [ValueSchema]
}

private struct ValueSchema {
  let name: String
  let type: String
  let enumData: [Int64: String]?
  let bitfieldWidth: Int?
  let arrayLength: Int?
  var bitRange: (Int, Int)
}

private enum ValueType: String, CaseIterable, Sendable {
  case bool = "bool"
  case char = "char"
  case int8 = "int8"
  case int16 = "int16"
  case int32 = "int32"
  case int64 = "int64"
  case uint8 = "uint8"
  case uint16 = "uint16"
  case uint32 = "uint32"
  case uint64 = "uint64"
  case float = "float"
  case float32 = "float32"
  case double = "double"
  case float64 = "float64"

  nonisolated var maxBits: Int {
    switch self {
    case .bool, .char, .int8, .uint8: return 8
    case .int16, .uint16: return 16
    case .int32, .uint32, .float, .float32: return 32
    case .int64, .uint64, .double, .float64: return 64
    }
  }
}
