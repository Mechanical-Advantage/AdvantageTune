# AdvantageTune

[![Build](https://github.com/Mechanical-Advantage/AdvantageTune/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/Mechanical-Advantage/AdvantageTune/actions/workflows/build.yml)

AdvantageTune is a NetworkTables viewer and tuning application for iPhone and iPad developed by Littleton Robotics and intended for use by FIRST teams. It connects to [NetworkTables](https://docs.wpilib.org/en/stable/docs/software/networktables/index.html) servers (such as FIRST robots) with a native interface for viewing and modifying topics, including easy export of tuned values for use in robot code development. AdvantageTune supports reading and writing most data types, including primitives, arrays, WPILib structs, and Protobufs.

AdvantageTune is designed to provide a lightweight tuning experience to complement [AdvantageScope](https://docs.advantagescope.org). To keep the mobile experience streamlined and focused, more complex features (such as plotting, field visualization, and log viewing) are intentionally out of scope and are best served by AdvantageScope on the desktop.

## Development

AdvantageTune can be developed most easily using the iOS Simulator, as simulator builds do not require code signing.

1. Open `AdvantageTune.xcodeproj` in Xcode.
2. Select the `AdvantageTune` scheme and choose an iOS Simulator target (iPhone/iPad).
3. Build and run.

To test on a physical device using a free Apple Developer account:

1. In Xcode, select the `AdvantageTune` project > `AdvantageTune` target > `Signing & Capabilities`.
2. Change the team to your personal team and update the bundle identifier to a unique prefix (e.g., `com.<username>.advantagetune`).
3. On your iOS device, enable Developer Mode under `Settings` > `Privacy & Security` > `Developer Mode` (requires a restart).
4. Build and run the app on your device from Xcode. On the first run, trust your developer certificate under `Settings` > `General` > `VPN & Device Management`.

### Code Formatting

AdvantageTune uses Apple's `swift-format` tool (bundled with Xcode) for code formatting.

- Run `./format.sh` to automatically format all Swift files in-place.
- Run `./format.sh --check` to verify that all Swift files are properly formatted (this check runs automatically in CI).
