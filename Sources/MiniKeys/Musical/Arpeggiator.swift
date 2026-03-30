import Foundation
import Observation

enum ArpMode: String, CaseIterable, Codable {
    case up, down, upDown, downUp, random, order

    var displayName: String {
        switch self {
        case .up: "Up"
        case .down: "Down"
        case .upDown: "Up-Down"
        case .downUp: "Down-Up"
        case .random: "Random"
        case .order: "As Played"
        }
    }
}

enum ArpDivision: String, CaseIterable, Codable {
    case whole, half, quarter, eighth, sixteenth, thirtysecond
    case dottedEighth, tripletEighth

    var displayName: String {
        switch self {
        case .whole: "1"
        case .half: "1/2"
        case .quarter: "1/4"
        case .eighth: "1/8"
        case .sixteenth: "1/16"
        case .thirtysecond: "1/32"
        case .dottedEighth: "1/8."
        case .tripletEighth: "1/8T"
        }
    }

    var beatsPerStep: Double {
        switch self {
        case .whole: 4.0
        case .half: 2.0
        case .quarter: 1.0
        case .eighth: 0.5
        case .sixteenth: 0.25
        case .thirtysecond: 0.125
        case .dottedEighth: 0.75
        case .tripletEighth: 1.0 / 3.0
        }
    }
}

enum ArpStackMode: String, CaseIterable, Codable {
    case sorted      // notes ordered by pitch (low to high in stack)
    case newest      // last pressed note at top of stack
    case oldest      // first pressed note at top of stack

    var displayName: String {
        switch self {
        case .sorted: "Sorted"
        case .newest: "Newest"
        case .oldest: "Oldest"
        }
    }

    var noteStackMode: NoteStackMode {
        switch self {
        case .sorted: .sortedHold
        case .newest: .pushTopHold
        case .oldest: .pushBottomHold
        }
    }
}

enum GateStep: Int, Codable {
    case off = 0      // silence this step
    case on = 1       // normal gate
    case accent = 2   // louder hit
    case tie = 3      // extend previous note (no retrigger)
}

@Observable
@MainActor
final class Arpeggiator {
    var enabled = false
    var mode: ArpMode = .up
    var bpm: Double = 120
    var division: ArpDivision = .eighth
    var gatePercent: Double = 80
    var octaveRange: Int = 1
    var swing: Double = 50
    var stackMode: ArpStackMode = .sorted {
        didSet {
            if oldValue != stackMode {
                stop()
                noteStack = NoteStack(mode: stackMode.noteStackMode, capacity: 20)
            }
        }
    }

    var hold: Bool = false {
        didSet {
            if !hold && noteStack.activeCount == 0 && noteStack.count > 0 {
                // Hold was just turned off and no keys are pressed — stop
                stopTimer()
                silenceCurrent()
                noteStack.removeNonActiveNotes()
                orderStack.removeNonActiveNotes()
                sequence = []
            }
        }
    }

    // Gate pattern (16 steps, default all on)
    var gatePattern: [GateStep] = Array(repeating: .on, count: 16)
    var patternLength: Int = 16
    var useGatePattern: Bool = false

    private var noteStack = NoteStack(mode: .sortedHold, capacity: 20)
    private var orderStack = NoteStack(mode: .pushBottomHold, capacity: 20)

    private var dispatchTimer: DispatchSourceTimer?
    private var gateDispatchTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.minikeys.arpeggiator", qos: .userInteractive)
    @ObservationIgnored nonisolated(unsafe) var currentNote: UInt8?
    // nonisolated(unsafe) so they can be called from the timer queue without main actor hop
    @ObservationIgnored nonisolated(unsafe) var sendNoteOnDirect: ((UInt8, UInt8) -> Void)?
    @ObservationIgnored nonisolated(unsafe) var sendNoteOffDirect: ((UInt8) -> Void)?
    private var lastVelocity: UInt8 = 100
    private var isOnSwingBeat = false
    private weak var metronome: Metronome?

    private var sequence: [UInt8] = []
    @ObservationIgnored nonisolated(unsafe) var stepIndex = 0
    @ObservationIgnored nonisolated(unsafe) var patternIndex = 0

    func configure(noteOn: @escaping (UInt8, UInt8) -> Void, noteOff: @escaping (UInt8) -> Void, metronome: Metronome) {
        sendNoteOnDirect = noteOn
        sendNoteOffDirect = noteOff
        self.metronome = metronome
    }

    func notePressed(_ note: UInt8, velocity vel: UInt8) {
        lastVelocity = vel
        noteStack.push(note: note, velocity: vel)
        orderStack.push(note: note, velocity: vel)
        rebuildSequence()

        if noteStack.activeCount == 1 && noteStack.count == 1 {
            stepIndex = 0
            patternIndex = 0
            startTimer()
        }
    }

    func noteReleased(_ note: UInt8) {
        let result = noteStack.pop(note: note)
        _ = orderStack.pop(note: note)

        if result == .allDepressed {
            if hold {
                // Hold mode: keep playing the held notes, don't stop
                // The sequence stays as-is (all notes are depressed but still in stack)
            } else {
                stopTimer()
                silenceCurrent()
                noteStack.removeNonActiveNotes()
                orderStack.removeNonActiveNotes()
                sequence = []
            }
        } else {
            rebuildSequence()
            if stepIndex >= sequence.count && !sequence.isEmpty {
                stepIndex = stepIndex % sequence.count
            }
        }
    }

    func stop() {
        stopTimer()
        silenceCurrent()
        noteStack.clear()
        orderStack.clear()
        sequence = []
    }

    private func rebuildSequence() {
        let notes: [UInt8]
        if mode == .order {
            notes = orderStack.allNotes.map(\.note)
        } else {
            notes = noteStack.allNotes.map(\.note)
        }

        guard !notes.isEmpty else { sequence = []; return }

        var base: [UInt8]
        switch mode {
        case .up:
            base = notes
        case .down:
            base = notes.reversed()
        case .upDown:
            if notes.count > 1 {
                base = notes + notes.dropFirst().dropLast().reversed()
            } else {
                base = notes
            }
        case .downUp:
            let desc = notes.reversed() as [UInt8]
            if desc.count > 1 {
                base = desc + desc.dropFirst().dropLast().reversed()
            } else {
                base = desc
            }
        case .random:
            base = notes
        case .order:
            base = notes
        }

        var expanded: [UInt8] = []
        for oct in 0..<octaveRange {
            for note in base {
                let shifted = Int(note) + oct * 12
                if shifted <= 127 { expanded.append(UInt8(shifted)) }
            }
        }

        sequence = expanded
    }

    private var stepInterval: TimeInterval {
        let beatsPerSecond = bpm / 60.0
        let baseInterval = division.beatsPerStep / beatsPerSecond

        if swing != 50 {
            let swingFactor = swing / 100.0
            if isOnSwingBeat {
                return baseInterval * (2.0 * swingFactor)
            } else {
                return baseInterval * (2.0 * (1.0 - swingFactor))
            }
        }
        return baseInterval
    }

    private func startTimer() {
        stopTimer()
        tick()
        scheduleNext()
    }

    private func scheduleNext() {
        let delay: TimeInterval
        if let metro = metronome, metro.enabled {
            let nextGrid = metro.nextGridTime(beatsPerStep: division.beatsPerStep)
            delay = max(0.001, nextGrid - ProcessInfo.processInfo.systemUptime)
        } else {
            delay = stepInterval
        }

        // Snapshot state for the timer closure (avoids main actor access)
        let seq = sequence
        let noteOn = sendNoteOnDirect
        let noteOff = sendNoteOffDirect
        let vel = lastVelocity
        let gate = gatePercent
        let si = stepInterval
        let usePattern = useGatePattern
        let pattern = gatePattern
        let patLen = patternLength
        let arpMode = mode

        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + delay)
        timer.setEventHandler { [weak self] in
            guard let self else { return }

            guard self.enabled, !seq.isEmpty,
                  let noteOn, let noteOff else { return }

            // Silence previous note (on timer queue, direct MIDI call)
            if let prev = self.currentNote {
                noteOff(prev)
                self.currentNote = nil
            }

            // Gate pattern step
            let gateStep: GateStep
            if usePattern {
                let pi = self.patternIndex % patLen
                gateStep = pi < pattern.count ? pattern[pi] : .on
                self.patternIndex += 1
            } else {
                gateStep = .on
            }

            // Handle tie
            if gateStep == .tie {
                // Don't play new note, just schedule next
                self.advanceStepNonisolated(seq: seq, arpMode: arpMode)
                DispatchQueue.main.async { self.scheduleNext() }
                return
            }

            // Handle off
            if gateStep == .off {
                self.advanceStepNonisolated(seq: seq, arpMode: arpMode)
                DispatchQueue.main.async { self.scheduleNext() }
                return
            }

            // Get note
            let note: UInt8
            if arpMode == .random {
                note = seq.randomElement()!
            } else {
                let idx = self.stepIndex % seq.count
                note = seq[idx]
            }
            self.advanceStepNonisolated(seq: seq, arpMode: arpMode)

            let actualVel = gateStep == .accent ? UInt8(min(127, Int(vel) + 20)) : vel

            self.currentNote = note
            noteOn(note, actualVel)

            // Schedule gate off on timer queue
            let gateInterval = si * (gate / 100.0)
            let gateTimer = DispatchSource.makeTimerSource(queue: self.timerQueue)
            gateTimer.schedule(deadline: .now() + gateInterval)
            gateTimer.setEventHandler { [weak self] in
                if self?.currentNote == note {
                    noteOff(note)
                    self?.currentNote = nil
                }
            }
            gateTimer.resume()
            self.gateDispatchTimer = gateTimer

            self.isOnSwingBeat.toggle()
            DispatchQueue.main.async { self.scheduleNext() }
        }
        timer.resume()
        dispatchTimer = timer
    }

    private nonisolated func advanceStepNonisolated(seq: [UInt8], arpMode: ArpMode) {
        if arpMode != .random {
            stepIndex += 1
            if stepIndex >= seq.count { stepIndex = 0 }
        }
    }

    private func stopTimer() {
        dispatchTimer?.cancel()
        dispatchTimer = nil
        gateDispatchTimer?.cancel()
        gateDispatchTimer = nil
    }

    /// First tick when arp starts — plays immediately on main actor
    private func tick() {
        guard !sequence.isEmpty,
              let noteOn = sendNoteOnDirect,
              let noteOff = sendNoteOffDirect else { return }

        silenceCurrent()

        let note: UInt8
        if mode == .random {
            note = sequence.randomElement()!
        } else {
            if stepIndex >= sequence.count { stepIndex = 0 }
            note = sequence[stepIndex]
            stepIndex += 1
        }

        currentNote = note
        noteOn(note, lastVelocity)

        // Gate off
        let noteToOff = note
        let gateInterval = stepInterval * (gatePercent / 100.0)
        let gt = DispatchSource.makeTimerSource(queue: timerQueue)
        gt.schedule(deadline: .now() + gateInterval)
        gt.setEventHandler { [weak self] in
            if self?.currentNote == noteToOff {
                noteOff(noteToOff)
                self?.currentNote = nil
            }
        }
        gt.resume()
        gateDispatchTimer = gt
    }

    private func silenceCurrent() {
        if let note = currentNote, let noteOff = sendNoteOffDirect {
            noteOff(note)
            currentNote = nil
        }
    }
}
