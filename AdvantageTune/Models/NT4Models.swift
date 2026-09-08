// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

public enum NT4Constants {
  public static let defaultHost = "robot.local"
  public static let defaultPort = 5810
  public static let appName = "AdvantageTune"
  public static let subprotocolV41 = "v4.1.networktables.first.wpi.edu"
  public static let subprotocolV40 = "networktables.first.wpi.edu"
  public static let subprotocolRTT = "rtt.networktables.first.wpi.edu"
  public static let defaultSubprotocols = "\(subprotocolV41), \(subprotocolV40)"
  public static let subprotocol = defaultSubprotocols

  public static let typeIndexLookup: [String: Int] = [
    "boolean": 0,
    "double": 1,
    "int": 2,
    "float": 3,
    "string": 4,
    "json": 4,
    "raw": 5,
    "rpc": 5,
    "msgpack": 5,
    "protobuf": 5,
    "boolean[]": 16,
    "double[]": 17,
    "int[]": 18,
    "float[]": 19,
    "string[]": 20,
  ]

  public static func typeIndex(for typeString: String) -> Int {
    if let idx = typeIndexLookup[typeString] {
      return idx
    }
    return 5  // Default to binary / raw
  }
}

public struct NT4SubscriptionOptions: Codable, Equatable, Hashable, Sendable {
  public var periodic: Double = 0.02  // 50 Hz default
  public var all: Bool = false
  public var topicsonly: Bool = false
  public var prefix: Bool = false

  public init(
    periodic: Double = 0.02, all: Bool = false, topicsonly: Bool = false, prefix: Bool = false
  ) {
    self.periodic = periodic
    self.all = all
    self.topicsonly = topicsonly
    self.prefix = prefix
  }

  enum CodingKeys: String, CodingKey {
    case periodic
    case all
    case topicsonly
    case prefix
  }
}

public struct NT4Topic: Identifiable, Equatable, Hashable, Sendable {
  public let id: Int  // Assigned by server ("id") or publisher ("pubuid")
  public let name: String
  public let type: String
  public var properties: [String: String]
  public var pubuid: Int?

  public init(
    id: Int, name: String, type: String, properties: [String: String] = [:], pubuid: Int? = nil
  ) {
    self.id = id
    self.name = name
    self.type = type
    self.properties = properties
    self.pubuid = pubuid
  }

  public var typeIndex: Int {
    NT4Constants.typeIndex(for: type)
  }

  public var isSchema: Bool {
    name.hasPrefix("/.schema") || name.hasPrefix(".schema") || name.contains("/.schema")
      || name.contains(".schema") || name.hasPrefix("/_") || name.hasPrefix("/$")
      || name.hasPrefix("$")
  }

  public var isImmutable: Bool {
    // Table "AdvantageKit" check
    let cleanName = name.hasPrefix("/") ? String(name.dropFirst()) : name
    if cleanName == "AdvantageKit" || cleanName.hasPrefix("AdvantageKit/") {
      return true
    }

    // Property check for "mutable"
    if let mutableVal = properties["mutable"]?.trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    {
      if mutableVal == "false" || mutableVal == "0" {
        return true
      }
      if mutableVal == "true" || mutableVal == "1" {
        return false
      }
    }

    return false
  }

  public var isMutable: Bool {
    !isImmutable
  }

  public var isStruct: Bool {
    type.hasPrefix("struct:")
  }

  public var isProtobuf: Bool {
    type.hasPrefix("proto:")
  }

  public var isRaw: Bool {
    typeIndex == 5 || isStruct || isProtobuf || type == "raw" || type == "binary"
      || type == "msgpack" || type == "rpc"
  }

  public var isArray: Bool {
    typeIndex >= 16 && typeIndex <= 20 || type.contains("[]")
  }
}

// MARK: - JSON Protocol Wire Messages

public enum NT4ClientMessage {
  case publish(name: String, type: String, pubuid: Int, properties: [String: String])
  case unpublish(pubuid: Int)
  case setProperties(name: String, update: [String: String])
  case subscribe(topics: [String], subuid: Int, options: NT4SubscriptionOptions)
  case unsubscribe(subuid: Int)

  public func toJSONData() -> Data? {
    var dict: [String: Any] = [:]
    switch self {
    case .publish(let name, let type, let pubuid, let properties):
      dict["method"] = "publish"
      dict["params"] =
        [
          "name": name,
          "type": type,
          "pubuid": pubuid,
          "properties": properties,
        ] as [String: Any]

    case .unpublish(let pubuid):
      dict["method"] = "unpublish"
      dict["params"] = [
        "pubuid": pubuid
      ]

    case .setProperties(let name, let update):
      dict["method"] = "setproperties"
      dict["params"] =
        [
          "name": name,
          "update": update,
        ] as [String: Any]

    case .subscribe(let topics, let subuid, let options):
      dict["method"] = "subscribe"
      dict["params"] =
        [
          "topics": topics,
          "subuid": subuid,
          "options": [
            "periodic": options.periodic,
            "all": options.all,
            "topicsonly": options.topicsonly,
            "prefix": options.prefix,
          ] as [String: Any],
        ] as [String: Any]

    case .unsubscribe(let subuid):
      dict["method"] = "unsubscribe"
      dict["params"] = [
        "subuid": subuid
      ]
    }

    let array = [dict]
    return try? JSONSerialization.data(withJSONObject: array)
  }
}
