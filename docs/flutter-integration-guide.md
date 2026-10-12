# Flutter 集成指南

## 1. 概述

FindMyTag SDK 提供 iOS XCFramework 原生包。Flutter 项目通过 Platform Channel 桥接原生 SDK。
本指南提供 iOS 端桥接代码模板和最佳实践。

> **注意**：SDK 不提供 Flutter 插件包。您需基于原生 SDK 自行实现 Platform Channel 桥接。

## 2. 架构

```
Flutter (Dart)
    │
    ├── MethodChannel: 'com.findmytag.sdk/commands'
    │     ├── createSession(deviceId) → sessionId
    │     ├── startRanging(sessionId)
    │     ├── stopRanging(sessionId)
    │     ├── playSound(sessionId)
    │     ├── requestBattery(sessionId) → int
    │     └── closeSession(sessionId)
    │
    ├── EventChannel: 'com.findmytag.sdk/measurements'
    │     └── Stream<Map>: { sessionId, distance, azimuth, elevation, isConverged }
    │
    └── EventChannel: 'com.findmytag.sdk/state'
          └── Stream<Map>: { sessionId, state }
    │
iOS Native
    │
    └── FindMyTagSDK → RangingSession
```

## 3. Dart 端

创建 `lib/findmytag_bridge.dart`：

```dart
import 'dart:async';
import 'package:flutter/services.dart';

class FindMyTagBridge {
  static const _commands = MethodChannel('com.findmytag.sdk/commands');
  static const _measurements = EventChannel('com.findmytag.sdk/measurements');
  static const _state = EventChannel('com.findmytag.sdk/state');

  /// 创建测距会话。deviceId 为 BLE 外设标识符（UUID 字符串）。
  Future<String> createSession(String deviceId) async {
    final sessionId = await _commands.invokeMethod<String>(
      'createSession',
      {'deviceId': deviceId},
    );
    return sessionId!;
  }

  Future<void> startRanging(String sessionId) =>
      _commands.invokeMethod('startRanging', {'sessionId': sessionId});

  Future<void> stopRanging(String sessionId) =>
      _commands.invokeMethod('stopRanging', {'sessionId': sessionId});

  Future<void> playSound(String sessionId) =>
      _commands.invokeMethod('playSound', {'sessionId': sessionId});

  Future<void> stopSound(String sessionId) =>
      _commands.invokeMethod('stopSound', {'sessionId': sessionId});

  Future<int> requestBattery(String sessionId) async {
    final level = await _commands.invokeMethod<int>(
      'requestBattery',
      {'sessionId': sessionId},
    );
    return level!;
  }

  Future<void> closeSession(String sessionId) =>
      _commands.invokeMethod('closeSession', {'sessionId': sessionId});

  Stream<Map<String, dynamic>> get measurements =>
      _measurements.receiveBroadcastStream().map(
        (event) => Map<String, dynamic>.from(event as Map),
      );

  Stream<Map<String, dynamic>> get stateChanges =>
      _state.receiveBroadcastStream().map(
        (event) => Map<String, dynamic>.from(event as Map),
      );
}
```

## 4. iOS 端

创建 `ios/Runner/FindMyTagPlugin.swift`：

```swift
import Flutter
import FindMyTagKit

class FindMyTagPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private let sdk = FindMyTagSDK()
    private var sessions: [String: RangingSession] = [:]
    private var measurementSink: FlutterEventSink?
    private var stateSink: FlutterEventSink?

    static func register(with registrar: FlutterPluginRegistrar) {
        let commands = FlutterMethodChannel(
            name: "com.findmytag.sdk/commands",
            binaryMessenger: registrar.messenger()
        )
        let measurements = FlutterEventChannel(
            name: "com.findmytag.sdk/measurements",
            binaryMessenger: registrar.messenger()
        )
        let state = FlutterEventChannel(
            name: "com.findmytag.sdk/state",
            binaryMessenger: registrar.messenger()
        )
        let instance = FindMyTagPlugin()
        registrar.addMethodCallDelegate(instance, channel: commands)
        measurements.setStreamHandler(instance)
        state.setStreamHandler(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        switch call.method {
        case "createSession":
            let deviceId = args!["deviceId"] as! String
            // 您需要在此处通过 deviceId 查找已建立的 BLE 连接
            let transport = getTransport(for: deviceId)
            let session = sdk.createSession(transport: transport)
            let sessionId = deviceId
            sessions[sessionId] = session

            // 桥接状态到 EventChannel
            session.stateHandler = { [weak self] s in
                self?.stateSink?([
                    "sessionId": sessionId,
                    "state": "\(s)",
                ])
            }
            result(sessionId)

        case "startRanging":
            let sessionId = args!["sessionId"] as! String
            guard let session = sessions[sessionId] else {
                result(FlutterError(code: "NOT_FOUND", message: nil, details: nil))
                return
            }
            session.rangingHandler = { [weak self] m in
                self?.measurementSink?([
                    "sessionId": sessionId,
                    "distance": m.distance,
                    "azimuth": m.azimuth as Any,
                    "elevation": m.elevation as Any,
                    "rawUwbDistance": m.rawUwbDistance,
                    "isConverged": m.isConverged,
                ])
            }
            session.startRanging()
            result(nil)

        case "stopRanging":
            let sessionId = args!["sessionId"] as! String
            sessions[sessionId]?.stopRanging()
            result(nil)

        case "playSound":
            let sessionId = args!["sessionId"] as! String
            do {
                try sessions[sessionId]?.playSound()
                result(nil)
            } catch {
                result(FlutterError(code: "CMD_FAIL", message: error.localizedDescription, details: nil))
            }

        case "stopSound":
            let sessionId = args!["sessionId"] as! String
            do {
                try sessions[sessionId]?.stopSound()
                result(nil)
            } catch {
                result(FlutterError(code: "CMD_FAIL", message: error.localizedDescription, details: nil))
            }

        case "requestBattery":
            let sessionId = args!["sessionId"] as! String
            sessions[sessionId]?.requestBattery { r in
                switch r {
                case .success(let level): result(level)
                case .failure(let error):
                    result(FlutterError(code: "BATTERY_FAIL", message: error.localizedDescription, details: nil))
                }
            }

        case "closeSession":
            let sessionId = args!["sessionId"] as! String
            sessions.removeValue(forKey: sessionId)?.close()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        measurementSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        measurementSink = nil
        return nil
    }

    // 您的 App 需要实现此方法，根据 deviceId 查找已连接的 BLE 外设
    private func getTransport(for deviceId: String) -> TransportHandle {
        // 返回您已建立的 TransportHandle
        fatalError("Implement: find your CBPeripheral by deviceId and create TransportHandle")
    }
}
```

在 `ios/Runner/AppDelegate.swift` 中注册：

```swift
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        FindMyTagPlugin.register(with: self.registrar(forPlugin: "FindMyTagPlugin")!)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

## 5. 注意事项

- BLE 扫描和连接管理仍在原生侧（或 Flutter 侧通过 `flutter_blue_plus` 等插件完成）
- `TransportHandle` 必须在原生侧创建，不能通过 Platform Channel 传递
- 建议在原生侧维护 `deviceId → TransportHandle` 映射
- `enableARFusion` 可通过 MethodChannel 参数传递，或在原生侧硬编码
