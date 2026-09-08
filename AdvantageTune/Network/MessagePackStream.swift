// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

/// Streaming MessagePack decoder supporting concatenated multi-message frames.
public struct MessagePackStream {

  public indirect enum Value: Equatable, Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case uint(UInt64)
    case float(Float)
    case double(Double)
    case string(String)
    case binary(Data)
    case array([Value])
    case map([(key: Value, value: Value)])
    case ext(Int8, Data)

    public var asInt64: Int64? {
      switch self {
      case .int(let i): return i
      case .uint(let u): return Int64(u)
      case .double(let d): return Int64(d)
      case .float(let f): return Int64(f)
      case .bool(let b): return b ? 1 : 0
      default: return nil
      }
    }

    public var asDouble: Double? {
      switch self {
      case .double(let d): return d
      case .float(let f): return Double(f)
      case .int(let i): return Double(i)
      case .uint(let u): return Double(u)
      case .bool(let b): return b ? 1.0 : 0.0
      default: return nil
      }
    }

    public var asBool: Bool? {
      switch self {
      case .bool(let b): return b
      case .int(let i): return i != 0
      case .uint(let u): return u != 0
      default: return nil
      }
    }

    public var asString: String? {
      switch self {
      case .string(let s): return s
      default: return nil
      }
    }

    public var asBinary: Data? {
      switch self {
      case .binary(let data): return data
      case .string(let s): return s.data(using: .utf8)
      default: return nil
      }
    }

    public static func == (lhs: Value, rhs: Value) -> Bool {
      switch (lhs, rhs) {
      case (.null, .null): return true
      case (.bool(let a), .bool(let b)): return a == b
      case (.int(let a), .int(let b)): return a == b
      case (.uint(let a), .uint(let b)): return a == b
      case (.float(let a), .float(let b)): return a == b
      case (.double(let a), .double(let b)): return a == b
      case (.string(let a), .string(let b)): return a == b
      case (.binary(let a), .binary(let b)): return a == b
      case (.array(let a), .array(let b)): return a == b
      case (.map(let a), .map(let b)):
        guard a.count == b.count else { return false }
        for i in 0..<a.count {
          if a[i].key != b[i].key || a[i].value != b[i].value { return false }
        }
        return true
      case (.ext(let t1, let d1), .ext(let t2, let d2)): return t1 == t2 && d1 == d2
      default: return false
      }
    }

    public func hash(into hasher: inout Hasher) {
      switch self {
      case .null: hasher.combine(0)
      case .bool(let b):
        hasher.combine(1)
        hasher.combine(b)
      case .int(let i):
        hasher.combine(2)
        hasher.combine(i)
      case .uint(let u):
        hasher.combine(3)
        hasher.combine(u)
      case .float(let f):
        hasher.combine(4)
        hasher.combine(f)
      case .double(let d):
        hasher.combine(5)
        hasher.combine(d)
      case .string(let s):
        hasher.combine(6)
        hasher.combine(s)
      case .binary(let b):
        hasher.combine(7)
        hasher.combine(b)
      case .array(let arr):
        hasher.combine(8)
        hasher.combine(arr)
      case .map(let map):
        hasher.combine(9)
        for item in map {
          hasher.combine(item.key)
          hasher.combine(item.value)
        }
      case .ext(let t, let d):
        hasher.combine(10)
        hasher.combine(t)
        hasher.combine(d)
      }
    }
  }

  // MARK: - Streaming Multi-Decode

  /// Unpacks all concatenated MessagePack objects contained in a Data buffer.
  public static func unpackAll(from data: Data) -> [Value] {
    var results: [Value] = []
    var offset = 0
    let count = data.count

    data.withUnsafeBytes { rawBuffer in
      guard let ptr = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }

      while offset < count {
        if let (val, bytesRead) = decodeValue(from: ptr, count: count, offset: offset),
          bytesRead > 0
        {
          results.append(val)
          offset += bytesRead
        } else {
          break
        }
      }
    }

    return results
  }

  private static func decodeValue(from ptr: UnsafePointer<UInt8>, count: Int, offset: Int) -> (
    Value, Int
  )? {
    guard offset < count else { return nil }
    let start = offset
    let b0 = ptr[start]

    // Positive fixint: 0x00 - 0x7f
    if b0 <= 0x7f {
      return (.int(Int64(b0)), 1)
    }
    // Negative fixint: 0xe0 - 0xff
    if b0 >= 0xe0 {
      let signed = Int8(bitPattern: b0)
      return (.int(Int64(signed)), 1)
    }
    // Fixmap: 0x80 - 0x8f
    if (b0 & 0xf0) == 0x80 {
      let mapCount = Int(b0 & 0x0f)
      return decodeMap(ptr: ptr, count: count, start: start, headerSize: 1, numEntries: mapCount)
    }
    // Fixarray: 0x90 - 0x9f
    if (b0 & 0xf0) == 0x90 {
      let arrCount = Int(b0 & 0x0f)
      return decodeArray(ptr: ptr, count: count, start: start, headerSize: 1, numElements: arrCount)
    }
    // Fixstr: 0xa0 - 0xbf
    if (b0 & 0xe0) == 0xa0 {
      let strLen = Int(b0 & 0x1f)
      guard start + 1 + strLen <= count else { return nil }
      let strData = Data(bytes: ptr + start + 1, count: strLen)
      let str = String(data: strData, encoding: .utf8) ?? ""
      return (.string(str), 1 + strLen)
    }

    switch b0 {
    case 0xc0:  // nil
      return (.null, 1)
    case 0xc2:  // false
      return (.bool(false), 1)
    case 0xc3:  // true
      return (.bool(true), 1)

    case 0xc4:  // bin 8
      guard start + 2 <= count else { return nil }
      let len = Int(ptr[start + 1])
      guard start + 2 + len <= count else { return nil }
      let data = Data(bytes: ptr + start + 2, count: len)
      return (.binary(data), 2 + len)

    case 0xc5:  // bin 16
      guard start + 3 <= count else { return nil }
      let len = Int(readUInt16(ptr: ptr + start + 1))
      guard start + 3 + len <= count else { return nil }
      let data = Data(bytes: ptr + start + 3, count: len)
      return (.binary(data), 3 + len)

    case 0xc6:  // bin 32
      guard start + 5 <= count else { return nil }
      let len = Int(readUInt32(ptr: ptr + start + 1))
      guard start + 5 + len <= count else { return nil }
      let data = Data(bytes: ptr + start + 5, count: len)
      return (.binary(data), 5 + len)

    case 0xc7:  // ext 8
      guard start + 3 <= count else { return nil }
      let len = Int(ptr[start + 1])
      let extType = Int8(bitPattern: ptr[start + 2])
      guard start + 3 + len <= count else { return nil }
      let data = Data(bytes: ptr + start + 3, count: len)
      return (.ext(extType, data), 3 + len)

    case 0xc8:  // ext 16
      guard start + 4 <= count else { return nil }
      let len = Int(readUInt16(ptr: ptr + start + 1))
      let extType = Int8(bitPattern: ptr[start + 3])
      guard start + 4 + len <= count else { return nil }
      let data = Data(bytes: ptr + start + 4, count: len)
      return (.ext(extType, data), 4 + len)

    case 0xc9:  // ext 32
      guard start + 6 <= count else { return nil }
      let len = Int(readUInt32(ptr: ptr + start + 1))
      let extType = Int8(bitPattern: ptr[start + 5])
      guard start + 6 + len <= count else { return nil }
      let data = Data(bytes: ptr + start + 6, count: len)
      return (.ext(extType, data), 6 + len)

    case 0xca:  // float 32
      guard start + 5 <= count else { return nil }
      let u = readUInt32(ptr: ptr + start + 1)
      let f = Float(bitPattern: u)
      return (.float(f), 5)

    case 0xcb:  // float 64
      guard start + 9 <= count else { return nil }
      let u = readUInt64(ptr: ptr + start + 1)
      let d = Double(bitPattern: u)
      return (.double(d), 9)

    case 0xcc:  // uint 8
      guard start + 2 <= count else { return nil }
      return (.uint(UInt64(ptr[start + 1])), 2)

    case 0xcd:  // uint 16
      guard start + 3 <= count else { return nil }
      return (.uint(UInt64(readUInt16(ptr: ptr + start + 1))), 3)

    case 0xce:  // uint 32
      guard start + 5 <= count else { return nil }
      return (.uint(UInt64(readUInt32(ptr: ptr + start + 1))), 5)

    case 0xcf:  // uint 64
      guard start + 9 <= count else { return nil }
      return (.uint(readUInt64(ptr: ptr + start + 1)), 9)

    case 0xd0:  // int 8
      guard start + 2 <= count else { return nil }
      let val = Int8(bitPattern: ptr[start + 1])
      return (.int(Int64(val)), 2)

    case 0xd1:  // int 16
      guard start + 3 <= count else { return nil }
      let val = Int16(bitPattern: readUInt16(ptr: ptr + start + 1))
      return (.int(Int64(val)), 3)

    case 0xd2:  // int 32
      guard start + 5 <= count else { return nil }
      let val = Int32(bitPattern: readUInt32(ptr: ptr + start + 1))
      return (.int(Int64(val)), 5)

    case 0xd3:  // int 64
      guard start + 9 <= count else { return nil }
      let val = Int64(bitPattern: readUInt64(ptr: ptr + start + 1))
      return (.int(val), 9)

    case 0xd4:  // fixext 1
      guard start + 3 <= count else { return nil }
      return (.ext(Int8(bitPattern: ptr[start + 1]), Data(bytes: ptr + start + 2, count: 1)), 3)

    case 0xd5:  // fixext 2
      guard start + 4 <= count else { return nil }
      return (.ext(Int8(bitPattern: ptr[start + 1]), Data(bytes: ptr + start + 2, count: 2)), 4)

    case 0xd6:  // fixext 4
      guard start + 6 <= count else { return nil }
      return (.ext(Int8(bitPattern: ptr[start + 1]), Data(bytes: ptr + start + 2, count: 4)), 6)

    case 0xd7:  // fixext 8
      guard start + 10 <= count else { return nil }
      return (.ext(Int8(bitPattern: ptr[start + 1]), Data(bytes: ptr + start + 2, count: 8)), 10)

    case 0xd8:  // fixext 16
      guard start + 18 <= count else { return nil }
      return (.ext(Int8(bitPattern: ptr[start + 1]), Data(bytes: ptr + start + 2, count: 16)), 18)

    case 0xd9:  // str 8
      guard start + 2 <= count else { return nil }
      let len = Int(ptr[start + 1])
      guard start + 2 + len <= count else { return nil }
      let strData = Data(bytes: ptr + start + 2, count: len)
      return (.string(String(data: strData, encoding: .utf8) ?? ""), 2 + len)

    case 0xda:  // str 16
      guard start + 3 <= count else { return nil }
      let len = Int(readUInt16(ptr: ptr + start + 1))
      guard start + 3 + len <= count else { return nil }
      let strData = Data(bytes: ptr + start + 3, count: len)
      return (.string(String(data: strData, encoding: .utf8) ?? ""), 3 + len)

    case 0xdb:  // str 32
      guard start + 5 <= count else { return nil }
      let len = Int(readUInt32(ptr: ptr + start + 1))
      guard start + 5 + len <= count else { return nil }
      let strData = Data(bytes: ptr + start + 5, count: len)
      return (.string(String(data: strData, encoding: .utf8) ?? ""), 5 + len)

    case 0xdc:  // array 16
      guard start + 3 <= count else { return nil }
      let len = Int(readUInt16(ptr: ptr + start + 1))
      return decodeArray(ptr: ptr, count: count, start: start, headerSize: 3, numElements: len)

    case 0xdd:  // array 32
      guard start + 5 <= count else { return nil }
      let len = Int(readUInt32(ptr: ptr + start + 1))
      return decodeArray(ptr: ptr, count: count, start: start, headerSize: 5, numElements: len)

    case 0xde:  // map 16
      guard start + 3 <= count else { return nil }
      let len = Int(readUInt16(ptr: ptr + start + 1))
      return decodeMap(ptr: ptr, count: count, start: start, headerSize: 3, numEntries: len)

    case 0xdf:  // map 32
      guard start + 5 <= count else { return nil }
      let len = Int(readUInt32(ptr: ptr + start + 1))
      return decodeMap(ptr: ptr, count: count, start: start, headerSize: 5, numEntries: len)

    default:
      return nil
    }
  }

  private static func decodeArray(
    ptr: UnsafePointer<UInt8>,
    count: Int,
    start: Int,
    headerSize: Int,
    numElements: Int
  ) -> (Value, Int)? {
    var elements: [Value] = []
    elements.reserveCapacity(numElements)
    var cur = start + headerSize

    for _ in 0..<numElements {
      guard let (elem, bytesRead) = decodeValue(from: ptr, count: count, offset: cur), bytesRead > 0
      else {
        return nil
      }
      elements.append(elem)
      cur += bytesRead
    }

    return (.array(elements), cur - start)
  }

  private static func decodeMap(
    ptr: UnsafePointer<UInt8>,
    count: Int,
    start: Int,
    headerSize: Int,
    numEntries: Int
  ) -> (Value, Int)? {
    var map: [(key: Value, value: Value)] = []
    map.reserveCapacity(numEntries)
    var cur = start + headerSize

    for _ in 0..<numEntries {
      guard let (key, kBytes) = decodeValue(from: ptr, count: count, offset: cur), kBytes > 0 else {
        return nil
      }
      cur += kBytes
      guard let (val, vBytes) = decodeValue(from: ptr, count: count, offset: cur), vBytes > 0 else {
        return nil
      }
      cur += vBytes
      map.append((key: key, value: val))
    }

    return (.map(map), cur - start)
  }

  // MARK: - Big Endian Helpers

  private static func readUInt16(ptr: UnsafePointer<UInt8>) -> UInt16 {
    (UInt16(ptr[0]) << 8) | UInt16(ptr[1])
  }

  private static func readUInt32(ptr: UnsafePointer<UInt8>) -> UInt32 {
    (UInt32(ptr[0]) << 24) | (UInt32(ptr[1]) << 16) | (UInt32(ptr[2]) << 8) | UInt32(ptr[3])
  }

  private static func readUInt64(ptr: UnsafePointer<UInt8>) -> UInt64 {
    (UInt64(ptr[0]) << 56) | (UInt64(ptr[1]) << 48) | (UInt64(ptr[2]) << 40)
      | (UInt64(ptr[3]) << 32) | (UInt64(ptr[4]) << 24) | (UInt64(ptr[5]) << 16)
      | (UInt64(ptr[6]) << 8) | UInt64(ptr[7])
  }

  // MARK: - Encoding

  public static func pack(_ value: Value) -> Data {
    var data = Data()
    encode(value, into: &data)
    return data
  }

  private static func encode(_ value: Value, into data: inout Data) {
    switch value {
    case .null:
      data.append(0xc0)
    case .bool(let b):
      data.append(b ? 0xc3 : 0xc2)
    case .int(let i):
      if i >= 0 && i <= 127 {
        data.append(UInt8(i))
      } else if i >= -32 && i < 0 {
        data.append(UInt8(bitPattern: Int8(i)))
      } else if i >= Int64(Int8.min) && i <= Int64(Int8.max) {
        data.append(0xd0)
        data.append(UInt8(bitPattern: Int8(i)))
      } else if i >= Int64(Int16.min) && i <= Int64(Int16.max) {
        data.append(0xd1)
        var be = Int16(i).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else if i >= Int64(Int32.min) && i <= Int64(Int32.max) {
        data.append(0xd2)
        var be = Int32(i).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else {
        data.append(0xd3)
        var be = i.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      }
    case .uint(let u):
      if u <= 127 {
        data.append(UInt8(u))
      } else if u <= UInt64(UInt8.max) {
        data.append(0xcc)
        data.append(UInt8(u))
      } else if u <= UInt64(UInt16.max) {
        data.append(0xcd)
        var be = UInt16(u).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else if u <= UInt64(UInt32.max) {
        data.append(0xce)
        var be = UInt32(u).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else {
        data.append(0xcf)
        var be = u.bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      }
    case .float(let f):
      data.append(0xca)
      var be = f.bitPattern.bigEndian
      withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    case .double(let d):
      data.append(0xcb)
      var be = d.bitPattern.bigEndian
      withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
    case .string(let s):
      let utf8 = Data(s.utf8)
      let len = utf8.count
      if len <= 31 {
        data.append(0xa0 | UInt8(len))
      } else if len <= UInt8.max {
        data.append(0xd9)
        data.append(UInt8(len))
      } else if len <= UInt16.max {
        data.append(0xda)
        var be = UInt16(len).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else {
        data.append(0xdb)
        var be = UInt32(len).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      }
      data.append(utf8)
    case .binary(let b):
      let len = b.count
      if len <= UInt8.max {
        data.append(0xc4)
        data.append(UInt8(len))
      } else if len <= UInt16.max {
        data.append(0xc5)
        var be = UInt16(len).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else {
        data.append(0xc6)
        var be = UInt32(len).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      }
      data.append(b)
    case .array(let arr):
      let count = arr.count
      if count <= 15 {
        data.append(0x90 | UInt8(count))
      } else if count <= UInt16.max {
        data.append(0xdc)
        var be = UInt16(count).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else {
        data.append(0xdd)
        var be = UInt32(count).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      }
      for elem in arr {
        encode(elem, into: &data)
      }
    case .map(let map):
      let count = map.count
      if count <= 15 {
        data.append(0x80 | UInt8(count))
      } else if count <= UInt16.max {
        data.append(0xde)
        var be = UInt16(count).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      } else {
        data.append(0xdf)
        var be = UInt32(count).bigEndian
        withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
      }
      for item in map {
        encode(item.key, into: &data)
        encode(item.value, into: &data)
      }
    case .ext(let type, let extData):
      data.append(0xc7)
      data.append(UInt8(extData.count))
      data.append(UInt8(bitPattern: type))
      data.append(extData)
    }
  }
}
