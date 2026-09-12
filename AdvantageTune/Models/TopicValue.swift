// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

public enum TopicValue: Equatable, Hashable, CustomStringConvertible, Sendable {
  case boolean(Bool)
  case double(Double)
  case int(Int64)
  case float(Float)
  case string(String)
  case booleanArray([Bool])
  case doubleArray([Double])
  case intArray([Int64])
  case floatArray([Float])
  case stringArray([String])
  case raw(Data)
  case structValue(typeName: String, value: StructValue, raw: Data)
  case protoRaw(typeName: String, data: Data)
  case unsupported(String)

  public var description: String {
    formattedString
  }

  public var formattedString: String {
    switch self {
    case .boolean(let val):
      return val ? "true" : "false"
    case .double(let val):
      return val.cleanFormatted
    case .int(let val):
      return val.formatted(.number.grouping(.never))
    case .float(let val):
      return val.cleanFormatted
    case .string(let val):
      if val.count > 60 {
        return String(val.prefix(57)) + "…"
      }
      return val
    case .booleanArray(let arr):
      return Self.formatArray(arr, transform: { $0 ? "true" : "false" })
    case .doubleArray(let arr):
      return Self.formatArray(arr, transform: { $0.cleanFormatted })
    case .intArray(let arr):
      return Self.formatArray(arr, transform: { $0.formatted(.number.grouping(.never)) })
    case .floatArray(let arr):
      return Self.formatArray(arr, transform: { $0.cleanFormatted })
    case .stringArray(let arr):
      return Self.formatArray(arr, transform: { "\"\($0)\"" })
    case .structValue(_, let structVal, _):
      return structVal.formattedSummary
    case .protoRaw(let typeName, let data):
      return "\(typeName) (\(data.count) bytes)"
    case .raw(let data):
      return "\(data.count) bytes"
    case .unsupported(let desc):
      return desc
    }
  }

  /// Complete string representation without truncation or floating point noise (suitable for copying and exporting).
  public var fullString: String {
    switch self {
    case .boolean(let val):
      return val ? "true" : "false"
    case .double(let val):
      return val.cleanFormatted
    case .int(let val):
      return "\(val)"
    case .float(let val):
      return val.cleanFormatted
    case .string(let val):
      return val
    case .booleanArray(let arr):
      return "[" + arr.map { $0 ? "true" : "false" }.joined(separator: ", ") + "]"
    case .doubleArray(let arr):
      return "[" + arr.map { $0.cleanFormatted }.joined(separator: ", ") + "]"
    case .intArray(let arr):
      return "[" + arr.map { "\($0)" }.joined(separator: ", ") + "]"
    case .floatArray(let arr):
      return "[" + arr.map { $0.cleanFormatted }.joined(separator: ", ") + "]"
    case .stringArray(let arr):
      return "[" + arr.map { "\"\($0)\"" }.joined(separator: ", ") + "]"
    case .structValue(_, let structVal, _):
      return structVal.fullString
    case .protoRaw(_, let data):
      return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    case .raw(let data):
      return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    case .unsupported(let desc):
      return desc
    }
  }

  public var typeDisplayName: String {
    switch self {
    case .boolean: return "Boolean"
    case .double: return "Double"
    case .int: return "Integer"
    case .float: return "Float"
    case .string: return "String"
    case .booleanArray: return "Boolean[]"
    case .doubleArray: return "Double[]"
    case .intArray: return "Integer[]"
    case .floatArray: return "Float[]"
    case .stringArray: return "String[]"
    case .raw: return "Raw Data"
    case .structValue(let typeName, _, _): return typeName
    case .protoRaw(let typeName, _): return typeName
    case .unsupported(let desc): return desc
    }
  }

  public var isPrimitive: Bool {
    switch self {
    case .double, .int, .float, .boolean: return true
    default: return false
    }
  }

  public var isArray: Bool {
    switch self {
    case .booleanArray, .doubleArray, .intArray, .floatArray, .stringArray: return true
    default: return false
    }
  }

  public var isRaw: Bool {
    switch self {
    case .raw, .protoRaw: return true
    default: return false
    }
  }

  public var asDouble: Double? {
    switch self {
    case .double(let v): return v
    case .int(let v): return Double(v)
    case .float(let v): return Double(v)
    case .boolean(let v): return v ? 1.0 : 0.0
    case .string(let v): return Double(v)
    default: return nil
    }
  }

  public func cast(to targetType: String) -> TopicValue? {
    switch targetType.lowercased() {
    case "boolean", "bool":
      return .boolean(asDouble != nil ? asDouble != 0 : false)
    case "double":
      return .double((asDouble ?? 0.0))
    case "int", "int64":
      return .int(Int64(asDouble ?? 0.0))
    case "float", "float32":
      return .float(Float(asDouble ?? 0.0))
    case "string":
      return .string(formattedString)
    case "double[]":
      if case .doubleArray(let arr) = self { return .doubleArray(arr.map { $0 }) }
      return .doubleArray([])
    default:
      return self
    }
  }

  public var structValueRepresentation: StructValue {
    switch self {
    case .boolean(let b):
      return .bool(b)
    case .int(let i):
      return .int(i)
    case .double(let d):
      return .double(d)
    case .float(let f):
      return .float(f)
    case .string(let s):
      return .string(s)
    case .booleanArray(let arr):
      return .array(arr.map { .bool($0) })
    case .doubleArray(let arr):
      return .array(arr.map { .double($0) })
    case .intArray(let arr):
      return .array(arr.map { .int($0) })
    case .floatArray(let arr):
      return .array(arr.map { .float($0) })
    case .stringArray(let arr):
      return .array(arr.map { .string($0) })
    case .structValue(_, let structVal, _):
      return structVal
    case .protoRaw(_, let data):
      return .string("Protobuf (\(data.count) bytes)")
    case .raw(let data):
      return .string("\(data.count) bytes")
    case .unsupported(let desc):
      return .string(desc)
    }
  }

  // MARK: - MessagePack Stream Conversions

  public static func from(typeIndex: Int, value: MessagePackStream.Value) -> TopicValue {
    switch typeIndex {
    case 0:  // boolean
      return .boolean(value.asBool ?? false)

    case 1:  // double
      return .double(value.asDouble ?? 0.0)

    case 2:  // int
      return .int(value.asInt64 ?? 0)

    case 3:  // float
      return .float(Float(value.asDouble ?? 0.0))

    case 4:  // string / json
      if case .string(let str) = value {
        return .string(str)
      }
      return .string("\(value)")

    case 5:  // raw / binary
      if case .binary(let data) = value {
        return .raw(data)
      }
      if case .string(let str) = value, let data = str.data(using: .utf8) {
        return .raw(data)
      }
      return .unsupported("Raw data")

    case 16:  // boolean[]
      if case .array(let elements) = value {
        let bools = elements.map { $0.asBool ?? false }
        return .booleanArray(bools)
      }
      return .booleanArray([])

    case 17:  // double[]
      if case .array(let elements) = value {
        let doubles = elements.compactMap { $0.asDouble }
        return .doubleArray(doubles)
      }
      return .doubleArray([])

    case 18:  // int[]
      if case .array(let elements) = value {
        let ints = elements.compactMap { $0.asInt64 }
        return .intArray(ints)
      }
      return .intArray([])

    case 19:  // float[]
      if case .array(let elements) = value {
        let floats = elements.compactMap { $0.asDouble.map { Float($0) } }
        return .floatArray(floats)
      }
      return .floatArray([])

    case 20:  // string[]
      if case .array(let elements) = value {
        let strings = elements.compactMap { $0.asString ?? "\($0)" }
        return .stringArray(strings)
      }
      return .stringArray([])

    default:
      return .unsupported("Type Index \(typeIndex)")
    }
  }

  public func toMessagePackStreamValue() -> MessagePackStream.Value {
    switch self {
    case .boolean(let b):
      return .bool(b)
    case .double(let d):
      return .double(d)
    case .int(let i):
      return .int(i)
    case .float(let f):
      return .float(f)
    case .string(let s):
      return .string(s)
    case .booleanArray(let arr):
      return .array(arr.map { .bool($0) })
    case .doubleArray(let arr):
      return .array(arr.map { .double($0) })
    case .intArray(let arr):
      return .array(arr.map { .int($0) })
    case .floatArray(let arr):
      return .array(arr.map { .float($0) })
    case .stringArray(let arr):
      return .array(arr.map { .string($0) })
    case .structValue(_, _, let data):
      return .binary(data)
    case .protoRaw(_, let data):
      return .binary(data)
    case .raw(let data):
      return .binary(data)
    case .unsupported(let desc):
      return .string(desc)
    }
  }

  // MARK: - Formatting Helpers

  private static func formatArray<T>(_ arr: [T], transform: (T) -> String, maxCharacters: Int = 200)
    -> String
  {
    let prefixArr = arr.prefix(maxCharacters)
    let full =
      "[" + prefixArr.map(transform).joined(separator: ", ")
      + (arr.count > prefixArr.count ? ", …" : "") + "]"
    if full.count > maxCharacters {
      return String(full.prefix(maxCharacters - 3)) + "…"
    }
    return full
  }
}

// MARK: - Double & Float Clean Formatting

extension Double {
  /// Formats the double cleanly without IEEE-754 epsilon noise or awkward "-0" signs.
  public var cleanFormatted: String {
    if self.isZero || (self > -1e-12 && self < 1e-12) { return "0" }
    if self.isNaN { return "NaN" }
    if self.isInfinite { return self > 0 ? "Infinity" : "-Infinity" }

    let rounded = (self * 1e12).rounded() / 1e12
    let val = abs(self - rounded) < 1e-13 ? rounded : self
    let s = val.formatted(.number.grouping(.never))
    if s == "-0" || s == "-0.0" || s == "-0,0" { return "0" }
    return s
  }
}

extension Float {
  /// Formats the float cleanly without IEEE-754 epsilon noise or awkward "-0" signs.
  public var cleanFormatted: String {
    if self.isZero || (self > -1e-6 && self < 1e-6) { return "0" }
    if self.isNaN { return "NaN" }
    if self.isInfinite { return self > 0 ? "Infinity" : "-Infinity" }

    let d = Double(self)
    let rounded = (d * 1e6).rounded() / 1e6
    let val = abs(d - rounded) < 1e-7 ? rounded : d
    let s = val.formatted(.number.grouping(.never))
    if s == "-0" || s == "-0.0" || s == "-0,0" { return "0" }
    return s
  }
}
