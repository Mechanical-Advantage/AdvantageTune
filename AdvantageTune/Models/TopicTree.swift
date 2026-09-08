// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

public indirect enum TopicNode: Identifiable, Hashable, Sendable {
  case folder(id: String, name: String, path: String, children: [TopicNode])
  case topic(
    id: String, name: String, path: String, topic: NT4Topic, latestValue: TopicValue?,
    lastUpdated: Date?)

  public var id: String {
    switch self {
    case .folder(let id, _, _, _):
      return id
    case .topic(let id, _, _, _, _, _):
      return id
    }
  }

  public var name: String {
    switch self {
    case .folder(_, let name, _, _):
      return name
    case .topic(_, let name, _, _, _, _):
      return name
    }
  }

  public var path: String {
    switch self {
    case .folder(_, _, let path, _):
      return path
    case .topic(_, _, let path, _, _, _):
      return path
    }
  }

  public var isFolder: Bool {
    switch self {
    case .folder: return true
    case .topic: return false
    }
  }

  public var children: [TopicNode] {
    switch self {
    case .folder(_, _, _, let children): return children
    case .topic: return []
    }
  }

  public var topic: NT4Topic? {
    switch self {
    case .folder: return nil
    case .topic(_, _, _, let topic, _, _): return topic
    }
  }

  public var latestValue: TopicValue? {
    switch self {
    case .folder: return nil
    case .topic(_, _, _, _, let val, _): return val
    }
  }
}

public struct TopicTreeBuilder {
  /// Builds a hierarchical list of root `TopicNode` items from a list of topics and their latest values.
  public static func buildTree(
    topics: [NT4Topic],
    values: [String: TopicValue],
    timestamps: [String: Date] = [:],
    hideSchemaTopics: Bool = true
  ) -> [TopicNode] {
    class MutableNode {
      let name: String
      let path: String
      var topic: NT4Topic?
      var children: [String: MutableNode] = [:]

      init(name: String, path: String, topic: NT4Topic? = nil) {
        self.name = name
        self.path = path
        self.topic = topic
      }

      func toTopicNode(values: [String: TopicValue], timestamps: [String: Date]) -> TopicNode {
        if let topic = topic, children.isEmpty {
          return .topic(
            id: topic.name,
            name: name,
            path: path,
            topic: topic,
            latestValue: values[topic.name],
            lastUpdated: timestamps[topic.name]
          )
        } else {
          let sortedChildren = children.values
            .map { $0.toTopicNode(values: values, timestamps: timestamps) }
            .sorted { nodeA, nodeB in
              if nodeA.isFolder != nodeB.isFolder {
                return nodeA.isFolder && !nodeB.isFolder
              }
              return nodeA.name.localizedStandardCompare(nodeB.name) == .orderedAscending
            }

          return .folder(
            id: path.isEmpty ? "/" : path,
            name: name.isEmpty ? "/" : name,
            path: path.isEmpty ? "/" : path,
            children: sortedChildren
          )
        }
      }
    }

    let root = MutableNode(name: "", path: "")

    for topic in topics {
      if hideSchemaTopics && topic.isSchema {
        continue
      }

      let cleanPath = topic.name.hasPrefix("/") ? String(topic.name.dropFirst()) : topic.name
      let segments = cleanPath.split(separator: "/").map(String.init)

      guard !segments.isEmpty else { continue }

      // Skip any hidden directories
      if hideSchemaTopics && segments.contains(where: { $0.hasPrefix(".") || $0.hasPrefix("$") }) {
        continue
      }

      var current = root
      var currentPath = ""

      for (index, segment) in segments.enumerated() {
        currentPath += "/" + segment
        let isLeaf = (index == segments.count - 1)

        if let existing = current.children[segment] {
          if isLeaf {
            existing.topic = topic
          }
          current = existing
        } else {
          let newNode = MutableNode(
            name: segment,
            path: currentPath,
            topic: isLeaf ? topic : nil
          )
          current.children[segment] = newNode
          current = newNode
        }
      }
    }

    return root.children.values
      .map { $0.toTopicNode(values: values, timestamps: timestamps) }
      .sorted { nodeA, nodeB in
        if nodeA.isFolder != nodeB.isFolder {
          return nodeA.isFolder && !nodeB.isFolder
        }
        return nodeA.name.localizedStandardCompare(nodeB.name) == .orderedAscending
      }
  }
}
