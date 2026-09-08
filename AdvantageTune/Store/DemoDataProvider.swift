// Copyright (c) 2026 Littleton Robotics
// http://github.com/Mechanical-Advantage
//
// Use of this source code is governed by a BSD
// license that can be found in the LICENSE file
// at the root directory of this project.

import Foundation

public struct DemoDataProvider {

  public static func loadDemoData() async -> (topics: [NT4Topic], values: [String: TopicValue]) {
    // Register struct schemas
    let translationSchema = "double x; double y;"
    let motorConfigSchema =
      "double targetVelocity; double currentVelocity; double pidGains[3]; bool inverted; int32 currentLimit;"
    let driverStationSchema =
      "enum { Disabled = 0, Autonomous = 1, Teleop = 2, Test = 3 } uint8 mode; bool enabled:1; bool estop:1; bool dsAttached:1; bool fmsAttached:1; int8 errorCount:4;"
    let pathPlanSchema = "char name[12]; Translation2d start; Translation2d waypoints[2];"

    await StructDecoder.shared.addSchema(
      name: "Translation2d", schemaData: translationSchema.data(using: .utf8)!)
    await StructDecoder.shared.addSchema(
      name: "MotorConfig", schemaData: motorConfigSchema.data(using: .utf8)!)
    await StructDecoder.shared.addSchema(
      name: "DriverStation", schemaData: driverStationSchema.data(using: .utf8)!)
    await StructDecoder.shared.addSchema(
      name: "PathPlan", schemaData: pathPlanSchema.data(using: .utf8)!)

    // Build struct values
    let translationValue = StructValue.object([
      (key: "x", value: .double(2.5)),
      (key: "y", value: .double(-1.75)),
    ])
    let translationRaw =
      await StructDecoder.shared.encode(typeName: "struct:Translation2d", value: translationValue)
      ?? Data()

    let motorConfigValue = StructValue.object([
      (key: "targetVelocity", value: .double(3000.0)),
      (key: "currentVelocity", value: .double(2998.5)),
      (key: "pidGains", value: .array([.double(0.1), .double(0.0), .double(0.05)])),
      (key: "inverted", value: .bool(false)),
      (key: "currentLimit", value: .int(40)),
    ])
    let motorConfigRaw =
      await StructDecoder.shared.encode(typeName: "struct:MotorConfig", value: motorConfigValue)
      ?? Data()

    let driverStationValue = StructValue.object([
      (
        key: "mode",
        value: .enumValue(
          name: "Teleop", rawValue: 2,
          options: [0: "Disabled", 1: "Autonomous", 2: "Teleop", 3: "Test"])
      ),
      (key: "enabled", value: .bool(true)),
      (key: "estop", value: .bool(false)),
      (key: "dsAttached", value: .bool(true)),
      (key: "fmsAttached", value: .bool(false)),
      (key: "errorCount", value: .int(0)),
    ])
    let driverStationRaw =
      await StructDecoder.shared.encode(typeName: "struct:DriverStation", value: driverStationValue)
      ?? Data()

    let pathPlanValue = StructValue.object([
      (key: "name", value: .string("AutoPathA")),
      (
        key: "start",
        value: .object([
          (key: "x", value: .double(0.0)),
          (key: "y", value: .double(0.0)),
        ])
      ),
      (
        key: "waypoints",
        value: .array([
          .object([(key: "x", value: .double(1.5)), (key: "y", value: .double(2.0))]),
          .object([(key: "x", value: .double(3.0)), (key: "y", value: .double(1.0))]),
        ])
      ),
    ])
    let pathPlanRaw =
      await StructDecoder.shared.encode(typeName: "struct:PathPlan", value: pathPlanValue) ?? Data()

    let waypointsValue = StructValue.array([
      .object([(key: "x", value: .double(0.0)), (key: "y", value: .double(0.0))]),
      .object([(key: "x", value: .double(1.5)), (key: "y", value: .double(2.0))]),
      .object([(key: "x", value: .double(3.0)), (key: "y", value: .double(1.0))]),
      .object([(key: "x", value: .double(4.5)), (key: "y", value: .double(-0.5))]),
    ])
    let waypointsRaw =
      await StructDecoder.shared.encode(typeName: "struct:Translation2d[]", value: waypointsValue)
      ?? Data()

    // Define topics and values
    var topics: [NT4Topic] = []
    var values: [String: TopicValue] = [:]

    // Root topic
    let teamNumberTopic = NT4Topic(id: 1, name: "/TeamNumber", type: "int")
    topics.append(teamNumberTopic)
    values[teamNumberTopic.name] = .int(6328)

    // Struct topics
    let tTranslation = NT4Topic(
      id: 10, name: "/Structs/Translation2d", type: "struct:Translation2d")
    topics.append(tTranslation)
    values[tTranslation.name] = .structValue(
      typeName: "struct:Translation2d", value: translationValue, raw: translationRaw)

    let tMotorConfig = NT4Topic(id: 11, name: "/Structs/MotorConfig", type: "struct:MotorConfig")
    topics.append(tMotorConfig)
    values[tMotorConfig.name] = .structValue(
      typeName: "struct:MotorConfig", value: motorConfigValue, raw: motorConfigRaw)

    let tDriverStation = NT4Topic(
      id: 12, name: "/Structs/DriverStation", type: "struct:DriverStation")
    topics.append(tDriverStation)
    values[tDriverStation.name] = .structValue(
      typeName: "struct:DriverStation", value: driverStationValue, raw: driverStationRaw)

    let tPathPlan = NT4Topic(id: 13, name: "/Structs/PathPlan", type: "struct:PathPlan")
    topics.append(tPathPlan)
    values[tPathPlan.name] = .structValue(
      typeName: "struct:PathPlan", value: pathPlanValue, raw: pathPlanRaw)

    let tWaypoints = NT4Topic(id: 14, name: "/Structs/Waypoints", type: "struct:Translation2d[]")
    topics.append(tWaypoints)
    values[tWaypoints.name] = .structValue(
      typeName: "struct:Translation2d[]", value: waypointsValue, raw: waypointsRaw)

    // Primitive topics
    let pBool = NT4Topic(id: 20, name: "/Primitives/Boolean", type: "boolean")
    let pDouble = NT4Topic(id: 21, name: "/Primitives/Double", type: "double")
    let pInt = NT4Topic(id: 22, name: "/Primitives/Integer", type: "int")
    let pFloat = NT4Topic(id: 23, name: "/Primitives/Float", type: "float")
    let pString = NT4Topic(id: 24, name: "/Primitives/String", type: "string")
    let pRaw = NT4Topic(id: 26, name: "/Primitives/Raw", type: "raw")

    topics.append(contentsOf: [pBool, pDouble, pInt, pFloat, pString, pRaw])
    values[pBool.name] = .boolean(true)
    values[pDouble.name] = .double(3.14159)
    values[pInt.name] = .int(42)
    values[pFloat.name] = .float(1.41421)
    values[pString.name] = .string("Littleton")
    values[pRaw.name] = .raw(Data([0x01, 0x02, 0x03, 0x04, 0x05, 0xAA, 0xBB, 0xCC]))

    // Array topics
    let aBool = NT4Topic(id: 30, name: "/Arrays/BooleanArray", type: "boolean[]")
    let aDouble = NT4Topic(id: 31, name: "/Arrays/DoubleArray", type: "double[]")
    let aInt = NT4Topic(id: 32, name: "/Arrays/IntegerArray", type: "int[]")
    let aFloat = NT4Topic(id: 33, name: "/Arrays/FloatArray", type: "float[]")
    let aString = NT4Topic(id: 34, name: "/Arrays/StringArray", type: "string[]")

    topics.append(contentsOf: [aBool, aDouble, aInt, aFloat, aString])
    values[aBool.name] = .booleanArray([true, false, true, true, false])
    values[aDouble.name] = .doubleArray([3.14159, 2.71828, 2.66514, 0.11, 0.00787])
    values[aInt.name] = .intArray([1, 1, 2, 3, 5, 8, 13, 21])
    values[aFloat.name] = .floatArray([0.1, 0.2, 0.3, 0.4, 0.5])
    values[aString.name] = .stringArray(["Alpha", "Beta", "Gamma", "Delta", "Epsilon"])

    // Schema announcement topics
    let sTranslation = NT4Topic(id: 100, name: "/.schema/struct:Translation2d", type: "raw")
    let sMotorConfig = NT4Topic(id: 101, name: "/.schema/struct:MotorConfig", type: "raw")
    let sDriverStation = NT4Topic(id: 102, name: "/.schema/struct:DriverStation", type: "raw")
    let sPathPlan = NT4Topic(id: 103, name: "/.schema/struct:PathPlan", type: "raw")
    topics.append(contentsOf: [sTranslation, sMotorConfig, sDriverStation, sPathPlan])
    values[sTranslation.name] = .raw(translationSchema.data(using: .utf8)!)
    values[sMotorConfig.name] = .raw(motorConfigSchema.data(using: .utf8)!)
    values[sDriverStation.name] = .raw(driverStationSchema.data(using: .utf8)!)
    values[sPathPlan.name] = .raw(pathPlanSchema.data(using: .utf8)!)

    return (topics, values)
  }
}
