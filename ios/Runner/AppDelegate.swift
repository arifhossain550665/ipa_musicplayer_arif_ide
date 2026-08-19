import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  static let methodChannelName = "com.ah.audio.player/native_engine"
  static let positionChannelName = "com.ah.audio.player/position_stream"
  static let stateChannelName = "com.ah.audio.player/state_stream"
  static let indexChannelName = "com.ah.audio.player/index_stream"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(
        name: AppDelegate.methodChannelName,
        binaryMessenger: controller.binaryMessenger)
      methodChannel.setMethodCallHandler { [weak self] call, result in
        self?.handleMethodCall(call, result: result)
      }

      let positionChannel = FlutterEventChannel(
        name: AppDelegate.positionChannelName,
        binaryMessenger: controller.binaryMessenger)
      positionChannel.setStreamHandler(PositionStreamHandler())

      let stateChannel = FlutterEventChannel(
        name: AppDelegate.stateChannelName,
        binaryMessenger: controller.binaryMessenger)
      stateChannel.setStreamHandler(StateStreamHandler())

      let indexChannel = FlutterEventChannel(
        name: AppDelegate.indexChannelName,
        binaryMessenger: controller.binaryMessenger)
      indexChannel.setStreamHandler(IndexStreamHandler())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let engine = NativeAudioEngine.shared
    let args = call.arguments as? [String: Any]

    switch call.method {
    case "setPlaylist":
      let paths = args?["paths"] as? [String] ?? []
      engine.setPlaylist(paths: paths)
      result(nil)

    case "playAtIndex":
      let index = args?["index"] as? Int ?? 0
      engine.playAtIndex(index)
      result(nil)

    case "play":
      engine.play()
      result(nil)

    case "pause":
      engine.pause()
      result(nil)

    case "seekToNext":
      engine.seekToNext()
      result(nil)

    case "seekToPrevious":
      engine.seekToPrevious()
      result(nil)

    case "seek":
      let seconds = args?["seconds"] as? Double ?? 0
      engine.seek(toSeconds: seconds)
      result(nil)

    case "removeAtIndex":
      let index = args?["index"] as? Int ?? -1
      engine.removeAtIndex(index)
      result(nil)

    case "setEqualizerEnabled":
      let enabled = args?["enabled"] as? Bool ?? false
      engine.setEqualizerEnabled(enabled)
      result(nil)

    case "setBandGain":
      let index = args?["index"] as? Int ?? 0
      let gain = args?["gain"] as? Double ?? 0
      engine.setBandGain(index: index, gain: Float(gain))
      result(nil)

    case "applyPreset":
      let gains = (args?["gains"] as? [Any])?.compactMap { ($0 as? NSNumber)?.floatValue } ?? []
      engine.applyPreset(gains: gains)
      result(nil)

    case "getBandFrequencies":
      result(NativeAudioEngine.bandFrequencies.map { Double($0) })

    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

// 🔴 প্রতি 0.5 সেকেন্ডে position/duration আপডেট পাঠায়
class PositionStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    NativeAudioEngine.shared.onPositionUpdate = { position, duration in
      events(["position": position, "duration": duration])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NativeAudioEngine.shared.onPositionUpdate = nil
    return nil
  }
}

// 🔴 play/pause state বদলালে জানায়
class StateStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    NativeAudioEngine.shared.onPlaybackStateChanged = { playing in
      events(playing)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NativeAudioEngine.shared.onPlaybackStateChanged = nil
    return nil
  }
}

// 🔴 প্লেলিস্টে কোন index চলছে সেটা বদলালে জানায় (auto-advance সহ)
class IndexStreamHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    NativeAudioEngine.shared.onIndexChanged = { index in
      events(index)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NativeAudioEngine.shared.onIndexChanged = nil
    return nil
  }
}
