// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation
import SwiftProtobuf

/// Registry for Protobuf `FileDescriptorProto` schemas announced over NetworkTables.
public actor ProtoSchemaRegistry {
  public static let shared = ProtoSchemaRegistry()

  private var fileDescriptors: [String: Google_Protobuf_FileDescriptorProto] = [:]
  private var rawDescriptors: [String: Data] = [:]
  private var messageDescriptors: [String: Google_Protobuf_DescriptorProto] = [:]
  private var enumDescriptors: [String: Google_Protobuf_EnumDescriptorProto] = [:]

  public init() {}

  /// Registers a binary protobuf file descriptor announced under `/.schema/proto:<TypeName>` or `/AdvantageKit/.schema/proto:<TypeName>`.
  public func addDescriptor(name: String, data: Data) {

    let cleanName = cleanTypeName(name)
    rawDescriptors[cleanName] = data

    if let fileDescriptor = try? Google_Protobuf_FileDescriptorProto(serializedBytes: data) {
      fileDescriptors[cleanName] = fileDescriptor
      indexFile(fileDescriptor, registeredName: cleanName)
    } else if let set = try? Google_Protobuf_FileDescriptorSet(serializedBytes: data) {
      for file in set.file {
        fileDescriptors[file.name] = file
        indexFile(file, registeredName: cleanName)
      }
    }
  }

  private func indexFile(_ file: Google_Protobuf_FileDescriptorProto, registeredName: String) {
    let pkg = file.package

    for msg in file.messageType {
      indexMessage(msg, package: pkg, registeredName: registeredName)
    }

    for en in file.enumType {
      let fullName = pkg.isEmpty ? en.name : "\(pkg).\(en.name)"
      enumDescriptors[en.name] = en
      enumDescriptors[fullName] = en
      enumDescriptors[".\(fullName)"] = en
    }
  }

  private func indexMessage(
    _ msg: Google_Protobuf_DescriptorProto, package: String, registeredName: String
  ) {
    let fullName = package.isEmpty ? msg.name : "\(package).\(msg.name)"

    messageDescriptors[msg.name] = msg
    messageDescriptors[fullName] = msg
    messageDescriptors[".\(fullName)"] = msg
    messageDescriptors[registeredName] = msg

    // Also index with simple message name if registeredName has package
    if registeredName.contains(".") {
      let lastPart = registeredName.components(separatedBy: ".").last ?? registeredName
      messageDescriptors[lastPart] = msg
    }

    for nested in msg.nestedType {
      let nestedPkg = fullName
      indexMessage(nested, package: nestedPkg, registeredName: "\(registeredName).\(nested.name)")
    }

    for en in msg.enumType {
      let enumFullName = "\(fullName).\(en.name)"
      enumDescriptors[en.name] = en
      enumDescriptors[enumFullName] = en
      enumDescriptors[".\(enumFullName)"] = en
    }
  }

  /// Checks if a protobuf schema is registered.
  public func hasDescriptor(for typeName: String) -> Bool {
    let clean = cleanTypeName(typeName)
    return messageDescriptors[clean] != nil || fileDescriptors[clean] != nil
      || rawDescriptors[clean] != nil
  }

  /// Finds a message descriptor by name or type path.
  public func findMessageDescriptor(_ typeName: String) -> Google_Protobuf_DescriptorProto? {
    let clean = cleanTypeName(typeName)
    if let msg = messageDescriptors[clean] {
      return msg
    }
    if let msg = messageDescriptors[".\(clean)"] {
      return msg
    }
    if let last = clean.components(separatedBy: ".").last, let msg = messageDescriptors[last] {
      return msg
    }
    return nil
  }

  /// Finds an enum descriptor by name or type path.
  public func findEnumDescriptor(_ typeName: String) -> Google_Protobuf_EnumDescriptorProto? {
    let clean = cleanTypeName(typeName)
    if let en = enumDescriptors[clean] {
      return en
    }
    if let en = enumDescriptors[".\(clean)"] {
      return en
    }
    if let last = clean.components(separatedBy: ".").last, let en = enumDescriptors[last] {
      return en
    }
    return nil
  }

  /// Returns the parsed FileDescriptorProto if available.
  public func descriptor(for typeName: String) -> Google_Protobuf_FileDescriptorProto? {
    let clean = cleanTypeName(typeName)
    return fileDescriptors[clean]
  }

  nonisolated public func cleanTypeName(_ typeName: String) -> String {
    var clean = typeName
    if clean.hasPrefix("proto:") {
      clean = String(clean.dropFirst("proto:".count))
    }
    if clean.hasSuffix("[]") {
      clean = String(clean.dropLast(2))
    }
    return clean
  }
}
