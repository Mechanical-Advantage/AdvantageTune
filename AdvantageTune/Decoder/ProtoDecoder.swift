// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation
import SwiftProtobuf

/// Dynamic Protobuf wire-format decoder and encoder using `SwiftProtobuf` descriptors.
public actor ProtoDecoder {
  public static let shared = ProtoDecoder()

  public init() {}

  // MARK: - Decoding

  /// Decodes a protobuf binary buffer given its type name into a `StructValue`.
  public func decode(typeName: String, data: Data) async -> StructValue? {
    guard let descriptor = await ProtoSchemaRegistry.shared.findMessageDescriptor(typeName) else {
      return nil
    }
    return await decodeMessage(data: data, descriptor: descriptor)
  }

  private func decodeMessage(data: Data, descriptor: Google_Protobuf_DescriptorProto) async
    -> StructValue
  {
    let fieldByNumber = Dictionary(uniqueKeysWithValues: descriptor.field.map { ($0.number, $0) })
    var fieldValues: [Int32: [StructValue]] = [:]

    var offset = 0
    while offset < data.count {
      guard let (tag, nextOffset) = decodeVarint(data: data, offset: offset) else { break }
      offset = nextOffset

      let fieldNumber = Int32(tag >> 3)
      let wireType = Int(tag & 0x7)

      guard let fieldDesc = fieldByNumber[fieldNumber] else {
        offset = skipWireField(data: data, offset: offset, wireType: wireType)
        continue
      }

      switch wireType {
      case 0:  // Varint
        guard let (rawVarint, newOffset) = decodeVarint(data: data, offset: offset) else { break }
        offset = newOffset
        let val = await decodeVarintField(rawVarint, fieldDesc: fieldDesc)
        fieldValues[fieldNumber, default: []].append(val)

      case 1:  // 64-bit fixed
        guard offset + 8 <= data.count else { break }
        let slice = data.subdata(in: offset..<offset + 8)
        offset += 8
        let val = decodeFixed64Field(slice, fieldDesc: fieldDesc)
        fieldValues[fieldNumber, default: []].append(val)

      case 2:  // Length-delimited
        guard let (lengthU64, newOffset) = decodeVarint(data: data, offset: offset) else { break }
        let length = Int(lengthU64)
        offset = newOffset
        guard offset + length <= data.count else { break }
        let slice = data.subdata(in: offset..<offset + length)
        offset += length

        let vals = await decodeLengthDelimitedField(slice, fieldDesc: fieldDesc)
        fieldValues[fieldNumber, default: []].append(contentsOf: vals)

      case 5:  // 32-bit fixed
        guard offset + 4 <= data.count else { break }
        let slice = data.subdata(in: offset..<offset + 4)
        offset += 4
        let val = decodeFixed32Field(slice, fieldDesc: fieldDesc)
        fieldValues[fieldNumber, default: []].append(val)

      default:
        break
      }
    }

    // Assemble StructValue.object in descriptor field order
    var resultObj: [(key: String, value: StructValue)] = []
    for field in descriptor.field {
      let values = fieldValues[field.number] ?? []
      if field.label == .repeated {
        resultObj.append((key: field.name, value: .array(values)))
      } else if let first = values.last {
        resultObj.append((key: field.name, value: first))
      } else {
        resultObj.append((key: field.name, value: await defaultStructValue(for: field)))
      }
    }

    return .object(resultObj)
  }

  // MARK: - Wire Type Helpers

  private func decodeVarint(data: Data, offset: Int) -> (UInt64, Int)? {
    var result: UInt64 = 0
    var shift: UInt64 = 0
    var cur = offset
    while cur < data.count {
      let byte = data[cur]
      cur += 1
      result |= UInt64(byte & 0x7F) << shift
      if (byte & 0x80) == 0 {
        return (result, cur)
      }
      shift += 7
      if shift > 64 { return nil }
    }
    return nil
  }

  private func decodeVarintField(_ raw: UInt64, fieldDesc: Google_Protobuf_FieldDescriptorProto)
    async -> StructValue
  {
    switch fieldDesc.type {
    case .bool:
      return .bool(raw != 0)
    case .enum:
      let rawInt = Int64(bitPattern: raw)
      if let enumDesc = await ProtoSchemaRegistry.shared.findEnumDescriptor(fieldDesc.typeName) {
        var options: [Int64: String] = [:]
        for val in enumDesc.value {
          options[Int64(val.number)] = val.name
        }
        let name = options[rawInt] ?? "\(rawInt)"
        return .enumValue(name: name, rawValue: rawInt, options: options)
      }
      return .int(rawInt)
    case .sint32:
      let decoded = (raw >> 1) ^ (UInt64(bitPattern: -Int64(raw & 1)))
      return .int(Int64(Int32(truncatingIfNeeded: decoded)))
    case .sint64:
      let decoded = (raw >> 1) ^ (UInt64(bitPattern: -Int64(raw & 1)))
      return .int(Int64(bitPattern: decoded))
    case .uint32, .uint64:
      return .uint(raw)
    case .int32, .int64:
      return .int(Int64(bitPattern: raw))
    default:
      return .int(Int64(bitPattern: raw))
    }
  }

  private func decodeFixed64Field(_ slice: Data, fieldDesc: Google_Protobuf_FieldDescriptorProto)
    -> StructValue
  {
    let u64 = slice.withUnsafeBytes { $0.load(as: UInt64.self).littleEndian }
    if fieldDesc.type == .double {
      return .double(Double(bitPattern: u64))
    } else if fieldDesc.type == .sfixed64 {
      return .int(Int64(bitPattern: u64))
    } else {
      return .uint(u64)
    }
  }

  private func decodeFixed32Field(_ slice: Data, fieldDesc: Google_Protobuf_FieldDescriptorProto)
    -> StructValue
  {
    let u32 = slice.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    if fieldDesc.type == .float {
      return .float(Float(bitPattern: u32))
    } else if fieldDesc.type == .sfixed32 {
      return .int(Int64(Int32(bitPattern: u32)))
    } else {
      return .uint(UInt64(u32))
    }
  }

  private func decodeLengthDelimitedField(
    _ slice: Data, fieldDesc: Google_Protobuf_FieldDescriptorProto
  ) async -> [StructValue] {
    switch fieldDesc.type {
    case .string:
      return [.string(String(data: slice, encoding: .utf8) ?? "")]

    case .bytes:
      let hex = slice.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " ")
      return [.string("0x\(hex)")]

    case .message:
      if let subDesc = await ProtoSchemaRegistry.shared.findMessageDescriptor(fieldDesc.typeName) {
        return [await decodeMessage(data: slice, descriptor: subDesc)]
      }
      return [.object([])]

    case .double:  // Packed repeated doubles
      var doubles: [StructValue] = []
      var cur = 0
      while cur + 8 <= slice.count {
        let u64 = slice.subdata(in: cur..<cur + 8).withUnsafeBytes {
          $0.load(as: UInt64.self).littleEndian
        }
        doubles.append(.double(Double(bitPattern: u64)))
        cur += 8
      }
      return doubles

    case .float:  // Packed repeated floats
      var floats: [StructValue] = []
      var cur = 0
      while cur + 4 <= slice.count {
        let u32 = slice.subdata(in: cur..<cur + 4).withUnsafeBytes {
          $0.load(as: UInt32.self).littleEndian
        }
        floats.append(.float(Float(bitPattern: u32)))
        cur += 4
      }
      return floats

    default:
      return [.string("\(slice.count) bytes")]
    }
  }

  private func skipWireField(data: Data, offset: Int, wireType: Int) -> Int {
    var cur = offset
    switch wireType {
    case 0:  // Varint
      while cur < data.count {
        let b = data[cur]
        cur += 1
        if (b & 0x80) == 0 { break }
      }
      return cur
    case 1:  // 64-bit
      return min(cur + 8, data.count)
    case 2:  // Length-delimited
      if let (len, next) = decodeVarint(data: data, offset: cur) {
        return min(next + Int(len), data.count)
      }
      return data.count
    case 5:  // 32-bit
      return min(cur + 4, data.count)
    default:
      return data.count
    }
  }

  private func defaultStructValue(for field: Google_Protobuf_FieldDescriptorProto) async
    -> StructValue
  {
    switch field.type {
    case .bool: return .bool(false)
    case .double: return .double(0.0)
    case .float: return .float(0.0)
    case .int32, .int64, .sint32, .sint64, .sfixed32, .sfixed64: return .int(0)
    case .uint32, .uint64, .fixed32, .fixed64: return .uint(0)
    case .string: return .string("")
    case .enum:
      if let enumDesc = await ProtoSchemaRegistry.shared.findEnumDescriptor(field.typeName),
        let firstVal = enumDesc.value.first
      {
        var options: [Int64: String] = [:]
        for val in enumDesc.value {
          options[Int64(val.number)] = val.name
        }
        return .enumValue(name: firstVal.name, rawValue: Int64(firstVal.number), options: options)
      }
      return .int(0)
    case .message: return .object([])
    default: return .string("")
    }
  }

  // MARK: - Encoding

  /// Encodes a `StructValue` into a binary Protobuf buffer given its type name.
  public func encode(typeName: String, value: StructValue) async -> Data? {
    guard let descriptor = await ProtoSchemaRegistry.shared.findMessageDescriptor(typeName) else {
      return nil
    }
    return await encodeMessage(value: value, descriptor: descriptor)
  }

  private func encodeMessage(value: StructValue, descriptor: Google_Protobuf_DescriptorProto) async
    -> Data
  {
    guard case .object(let fields) = value else { return Data() }
    let fieldMap = Dictionary(uniqueKeysWithValues: fields.map { ($0.key, $0.value) })

    var output = Data()

    for field in descriptor.field {
      guard let val = fieldMap[field.name] else { continue }

      if field.label == .repeated {
        if case .array(let elements) = val {
          for elem in elements {
            await encodeField(field: field, value: elem, into: &output)
          }
        }
      } else {
        await encodeField(field: field, value: val, into: &output)
      }
    }

    return output
  }

  private func encodeField(
    field: Google_Protobuf_FieldDescriptorProto, value: StructValue, into data: inout Data
  ) async {
    let tag = UInt64((field.number << 3) | wireType(for: field.type))

    switch field.type {
    case .bool:
      if case .bool(let b) = value {
        writeVarint(tag, into: &data)
        writeVarint(b ? 1 : 0, into: &data)
      }

    case .double:
      let d: Double
      if case .double(let val) = value {
        d = val
      } else if case .float(let val) = value {
        d = Double(val)
      } else {
        return
      }
      writeVarint(tag, into: &data)
      var bits = d.bitPattern.littleEndian
      withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }

    case .float:
      let f: Float
      if case .float(let val) = value {
        f = val
      } else if case .double(let val) = value {
        f = Float(val)
      } else {
        return
      }
      writeVarint(tag, into: &data)
      var bits = f.bitPattern.littleEndian
      withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }

    case .int32, .int64, .enum:
      let i: Int64
      if case .int(let val) = value {
        i = val
      } else if case .enumValue(_, let val, _) = value {
        i = val
      } else if case .uint(let val) = value {
        i = Int64(val)
      } else {
        return
      }
      writeVarint(tag, into: &data)
      writeVarint(UInt64(bitPattern: i), into: &data)

    case .uint32, .uint64:
      let u: UInt64
      if case .uint(let val) = value {
        u = val
      } else if case .int(let val) = value {
        u = UInt64(max(0, val))
      } else {
        return
      }
      writeVarint(tag, into: &data)
      writeVarint(u, into: &data)

    case .sint32, .sint64:
      let i: Int64 = (value.asInt64 ?? 0)
      let zigzag = UInt64((i << 1) ^ (i >> 63))
      writeVarint(tag, into: &data)
      writeVarint(zigzag, into: &data)

    case .string:
      if case .string(let s) = value, let utf8 = s.data(using: .utf8) {
        writeVarint(tag, into: &data)
        writeVarint(UInt64(utf8.count), into: &data)
        data.append(utf8)
      }

    case .message:
      if let subDesc = await ProtoSchemaRegistry.shared.findMessageDescriptor(field.typeName) {
        let subData = await encodeMessage(value: value, descriptor: subDesc)
        writeVarint(tag, into: &data)
        writeVarint(UInt64(subData.count), into: &data)
        data.append(subData)
      }

    default:
      break
    }
  }

  private func wireType(for type: Google_Protobuf_FieldDescriptorProto.TypeEnum) -> Int32 {
    switch type {
    case .double, .fixed64, .sfixed64: return 1
    case .float, .fixed32, .sfixed32: return 5
    case .string, .bytes, .message: return 2
    default: return 0  // varint
    }
  }

  private func writeVarint(_ value: UInt64, into data: inout Data) {
    var v = value
    while v >= 0x80 {
      data.append(UInt8((v & 0x7F) | 0x80))
      v >>= 7
    }
    data.append(UInt8(v & 0x7F))
  }
}

extension StructValue {
  fileprivate nonisolated var asInt64: Int64? {
    switch self {
    case .int(let i): return i
    case .uint(let u): return Int64(u)
    case .enumValue(_, let v, _): return v
    default: return nil
    }
  }
}
