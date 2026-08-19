import AVFoundation
import Flutter
import Foundation
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

// ═══════════════════════════════════════════════════════════════════════
// 🎚️ NativeAudioEngine — iPhone-এর জন্য real-time audio Equalizer।
// AVAudioEngine + AVAudioUnitEQ ব্যবহার করে সরাসরি audio signal-এ filter
// apply করা হয়। AppDelegate.swift-এর ভিতরেই রাখা হয়েছে (আলাদা ফাইল না)
// যাতে CI build-এ Xcode project (.pbxproj)-এ আলাদা করে file registration
// লাগে না — command-line xcodebuild দিয়ে build করলেও ঠিকভাবে compile হবে।
//
// Bands: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 6kHz, 12kHz (৭টা parametric band)
// ═══════════════════════════════════════════════════════════════════════
final class NativeAudioEngine: NSObject {
    static let shared = NativeAudioEngine()

    static let bandFrequencies: [Float] = [60, 150, 400, 1000, 2400, 6000, 12000]

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    let equalizer = AVAudioUnitEQ(numberOfBands: NativeAudioEngine.bandFrequencies.count)

    private var playlist: [URL] = []
    private var currentIndex: Int = -1
    private var audioFile: AVAudioFile?
    private var sampleRate: Double = 44100
    private var seekOffsetFrames: AVAudioFramePosition = 0
    private var playSessionToken: Int = 0

    var onIndexChanged: ((Int) -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onPositionUpdate: ((Double, Double) -> Void)?
    var onCompleted: (() -> Void)?

    private var positionTimer: Timer?

    private override init() {
        super.init()
        setupEngine()
    }

    private func setupEngine() {
        for (i, band) in equalizer.bands.enumerated() {
            band.filterType = .parametric
            band.frequency = i < NativeAudioEngine.bandFrequencies.count
                ? NativeAudioEngine.bandFrequencies[i]
                : 1000
            band.bandwidth = 1.0
            band.gain = 0
            band.bypass = false
        }
        equalizer.globalGain = 0

        engine.attach(playerNode)
        engine.attach(equalizer)
        engine.connect(playerNode, to: equalizer, format: nil)
        engine.connect(equalizer, to: engine.mainMixerNode, format: nil)

        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("NativeAudioEngine: AudioSession error: \(error)")
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification, object: nil)

        do {
            try engine.start()
        } catch {
            print("NativeAudioEngine: engine start error: \(error)")
        }
    }

    @objc private func handleInterruption(notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        if type == .began {
            pause()
        } else if type == .ended {
            if let optionsValue = info[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    play()
                }
            }
        }
    }

    // MARK: - Playlist

    func setPlaylist(paths: [String]) {
        playerNode.stop()
        stopPositionTimer()
        playlist = paths.map { URL(fileURLWithPath: $0) }
        currentIndex = -1
        audioFile = nil
    }

    func playAtIndex(_ index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        currentIndex = index
        loadAndPlayCurrent(seekSeconds: 0)
    }

    private func loadAndPlayCurrent(seekSeconds: Double) {
        guard currentIndex >= 0 && currentIndex < playlist.count else { return }
        let url = playlist[currentIndex]
        let token = playSessionToken + 1
        playSessionToken = token

        playerNode.stop()

        do {
            let file = try AVAudioFile(forReading: url)
            audioFile = file
            sampleRate = file.processingFormat.sampleRate

            let startFrame = AVAudioFramePosition(max(0, seekSeconds) * sampleRate)
            seekOffsetFrames = startFrame
            let remainingFrames = file.length - startFrame
            let framesToPlay = AVAudioFrameCount(max(0, remainingFrames))

            if !engine.isRunning {
                try? engine.start()
            }

            if startFrame > 0 && framesToPlay > 0 {
                playerNode.scheduleSegment(
                    file, startingFrame: startFrame, frameCount: framesToPlay, at: nil
                ) { [weak self] in
                    self?.handleSegmentFinished(token: token)
                }
            } else {
                playerNode.scheduleFile(file, at: nil) { [weak self] in
                    self?.handleSegmentFinished(token: token)
                }
            }

            playerNode.play()
            onIndexChanged?(currentIndex)
            onPlaybackStateChanged?(true)
            startPositionTimer()
        } catch {
            print("NativeAudioEngine: failed to load \(url): \(error)")
        }
    }

    private func handleSegmentFinished(token: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, token == self.playSessionToken else { return }
            if self.currentIndex + 1 < self.playlist.count {
                self.currentIndex += 1
                self.loadAndPlayCurrent(seekSeconds: 0)
            } else {
                self.onPlaybackStateChanged?(false)
                self.stopPositionTimer()
                self.onCompleted?()
            }
        }
    }

    // MARK: - Transport controls

    func play() {
        if !engine.isRunning { try? engine.start() }
        playerNode.play()
        onPlaybackStateChanged?(true)
        startPositionTimer()
    }

    func pause() {
        playerNode.pause()
        onPlaybackStateChanged?(false)
    }

    func seekToNext() {
        if currentIndex + 1 < playlist.count {
            currentIndex += 1
            loadAndPlayCurrent(seekSeconds: 0)
        }
    }

    func seekToPrevious() {
        if currentIndex - 1 >= 0 {
            currentIndex -= 1
            loadAndPlayCurrent(seekSeconds: 0)
        }
    }

    func seek(toSeconds seconds: Double) {
        loadAndPlayCurrent(seekSeconds: seconds)
    }

    func removeAtIndex(_ index: Int) {
        guard index >= 0 && index < playlist.count else { return }
        playlist.remove(at: index)
        if index == currentIndex {
            playerNode.stop()
            stopPositionTimer()
            currentIndex = -1
        } else if index < currentIndex {
            currentIndex -= 1
        }
    }

    func currentPositionSeconds() -> Double {
        guard playerNode.isPlaying || audioFile != nil,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return Double(seekOffsetFrames) / sampleRate
        }
        let currentFrame = Double(seekOffsetFrames) + Double(playerTime.sampleTime)
        return max(0, currentFrame / sampleRate)
    }

    func durationSeconds() -> Double {
        guard let file = audioFile else { return 0 }
        return Double(file.length) / sampleRate
    }

    private func startPositionTimer() {
        stopPositionTimer()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in
            guard let self = self else { return }
            self.onPositionUpdate?(self.currentPositionSeconds(), self.durationSeconds())
        }
        if let timer = positionTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPositionTimer() {
        positionTimer?.invalidate()
        positionTimer = nil
    }

    // MARK: - Equalizer

    func setEqualizerEnabled(_ enabled: Bool) {
        equalizer.bypass = !enabled
    }

    func setBandGain(index: Int, gain: Float) {
        guard index >= 0 && index < equalizer.bands.count else { return }
        equalizer.bands[index].gain = gain
    }

    func applyPreset(gains: [Float]) {
        for (i, g) in gains.enumerated() where i < equalizer.bands.count {
            equalizer.bands[i].gain = g
        }
    }
}
