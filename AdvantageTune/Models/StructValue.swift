// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

/// Recursive representation of structured data (e.g. WPILib Structs).
public enum StructValue: Equatable, Hashable, Sendable {
  case bool(Bool)
  case int(Int64)
  case uint(UInt64)
  case float(Float)
  case double(Double)
  case string(String)
  case enumValue(name: String, rawValue: Int64, options: [Int64: String] = [:])
  case array([StructValue])
  case object([(key: String, value: StructValue)])

  // MARK: - Equatable & Hashable

  public static func == (lhs: StructValue, rhs: StructValue) -> Bool {
    switch (lhs, rhs) {
    case (.bool(let a), .bool(let b)): return a == b
    case (.int(let a), .int(let b)): return a == b
    case (.uint(let a), .uint(let b)): return a == b
    case (.float(let a), .float(let b)): return a == b
    case (.double(let a), .double(let b)): return a == b
    case (.string(let a), .string(let b)): return a == b
    case (.enumValue(let n1, let v1, let o1), .enumValue(let n2, let v2, let o2)):
      return n1 == n2 && v1 == v2 && o1 == o2
    case (.array(let a), .array(let b)): return a == b
    case (.object(let a), .object(let b)):
      guard a.count == b.count else { return false }
      for i in 0..<a.count {
        if a[i].key != b[i].key || a[i].value != b[i].value { return false }
      }
      return true
    default: return false
    }
  }

  public func hash(into hasher: inout Hasher) {
    switch self {
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
    case .enumValue(let n, let v, let o):
      hasher.combine(7)
      hasher.combine(n)
      hasher.combine(v)
      for (k, val) in o {
        hasher.combine(k)
        hasher.combine(val)
      }
    case .array(let arr):
      hasher.combine(8)
      hasher.combine(arr)
    case .object(let obj):
      hasher.combine(9)
      for item in obj {
        hasher.combine(item.key)
        hasher.combine(item.value)
      }
    }
  }

  // MARK: - String Formatting

  private var unclippedSummary: String {
    switch self {
    case .bool(let b):
      return b ? "true" : "false"
    case .int(let i):
      return "\(i)"
    case .uint(let u):
      return "\(u)"
    case .float(let f):
      return f.cleanFormatted
    case .double(let d):
      return d.cleanFormatted
    case .string(let s):
      return "\"\(s)\""
    case .enumValue(let name, _, _):
      return name
    case .array(let arr):
      return "[" + arr.map { $0.unclippedSummary }.joined(separator: ", ") + "]"
    case .object(let obj):
      return "{" + obj.map { "\($0.key): \($0.value.unclippedSummary)" }.joined(separator: ", ")
        + "}"
    }
  }

  /// Summary for previewing in rows and details, capped by total character length.
  public var formattedSummary: String {
    let summary = unclippedSummary
    if summary.count > 200 {
      return String(summary.prefix(197)) + "…"
    }
    return summary
  }

  /// Complete string representation without truncation or floating point noise (suitable for copying and exporting).
  public var fullString: String {
    switch self {
    case .bool(let b):
      return b ? "true" : "false"
    case .int(let i):
      return "\(i)"
    case .uint(let u):
      return "\(u)"
    case .float(let f):
      return f.cleanFormatted
    case .double(let d):
      return d.cleanFormatted
    case .string(let s):
      return "\"\(s)\""
    case .enumValue(let name, let val, _):
      return "\(name) (\(val))"
    case .array(let arr):
      return "[" + arr.map { $0.fullString }.joined(separator: ", ") + "]"
    case .object(let obj):
      return "{" + obj.map { "\"\($0.key)\": \($0.value.fullString)" }.joined(separator: ", ") + "}"
    }
  }
}
