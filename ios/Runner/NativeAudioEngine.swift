import AVFoundation
import Foundation

// 🎚️ iPhone-এর জন্য real-time audio Equalizer। AVAudioEngine + AVAudioUnitEQ
// ব্যবহার করে সরাসরি audio signal-এ filter apply করা হয় — এটাই আসল, hardware
// -level EQ, just_audio এর মতো "শুধু UI" না।
//
// Bands: 60Hz, 150Hz, 400Hz, 1kHz, 2.4kHz, 6kHz, 12kHz (৭টা parametric band,
// জনপ্রিয় graphic equalizer app গুলোর মতো layout)
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

    // 🔴 Flutter-এর দিকে event পাঠানোর জন্য callback (AppDelegate থেকে সেট হবে)
    var onIndexChanged: ((Int) -> Void)?
    var onPlaybackStateChanged: ((Bool) -> Void)?
    var onPositionUpdate: ((Double, Double) -> Void)? // (positionSeconds, durationSeconds)
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
        // 🔴 কল আসা বা অন্য app audio নিলে gracefully pause করা
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

    // 🔴 গান শেষ হলে বা skip/seek হলে বারবার কল হতে পারে; token দিয়ে চেক
    // করা হচ্ছে যাতে পুরনো segment-এর completion handler নতুন গান শুরুর পর
    // ভুলবশত পরের গান স্কিপ করিয়ে না দেয়
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
