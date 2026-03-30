import AVFoundation
import Foundation
import Observation

@Observable
final class Metronome {
    var enabled = false {
        didSet {
            if enabled { start() } else { stop() }
        }
    }
    var bpm: Double = 120 {
        didSet { if enabled { reschedule() } }
    }
    var beatsPerBar: Int = 4
    var volume: Float = 0.6

    private(set) var currentBeat: Int = 0

    // Shared master clock
    private(set) var clockStartUptime: TimeInterval = ProcessInfo.processInfo.systemUptime

    private var dispatchTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.minikeys.metronome", qos: .userInteractive)
    private var engine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var clickBuffer: AVAudioPCMBuffer?
    private var accentBuffer: AVAudioPCMBuffer?

    init() {
        setupAudio()
    }

    private func setupAudio() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        engine.attach(player)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        engine.connect(player, to: engine.mainMixerNode, format: format)

        clickBuffer = generateClick(frequency: 800, duration: 0.02, amplitude: 0.5, format: format)
        accentBuffer = generateClick(frequency: 1200, duration: 0.03, amplitude: 0.8, format: format)

        do {
            try engine.start()
            player.play()
        } catch {
            print("Metronome audio engine failed: \(error)")
        }

        self.engine = engine
        self.playerNode = player
    }

    private func generateClick(frequency: Double, duration: Double, amplitude: Float, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let data = buffer.floatChannelData![0]
        for i in 0..<Int(frameCount) {
            let t = Double(i) / sampleRate
            let envelope = Float(exp(-t * 200))
            data[i] = amplitude * envelope * sin(Float(2.0 * .pi * frequency * t))
        }

        return buffer
    }

    var beatInterval: TimeInterval {
        60.0 / bpm
    }

    func nextGridTime(beatsPerStep: Double) -> TimeInterval {
        let interval = beatInterval * beatsPerStep
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = now - clockStartUptime
        let phase = elapsed.truncatingRemainder(dividingBy: interval)
        return now + (interval - phase)
    }

    private func start() {
        stop()
        clockStartUptime = ProcessInfo.processInfo.systemUptime
        currentBeat = 0
        playClick()
        scheduleNextBeat()
    }

    private func reschedule() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        scheduleNextBeat()
    }

    private func scheduleNextBeat() {
        let nextTime = nextGridTime(beatsPerStep: 1.0)
        let delay = max(0.001, nextTime - ProcessInfo.processInfo.systemUptime)

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.enabled else { return }
                self.currentBeat = (self.currentBeat + 1) % self.beatsPerBar
                self.playClick()
                self.scheduleNextBeat()
            }
        }
        timer.resume()
        dispatchTimer = timer
    }

    private func playClick() {
        guard let player = playerNode else { return }
        let isAccent = currentBeat == 0
        guard let buf = isAccent ? accentBuffer : clickBuffer else { return }
        player.volume = volume
        player.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
    }

    func stop() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        currentBeat = 0
    }
}
