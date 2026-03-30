import Foundation
import Observation

@Observable
@MainActor
final class KeyboardState {
    var octave: Int = 4
    var velocity: UInt8 = 100
    var sustainActive: Bool = false
    var pressedKeys: Set<UInt16> = []
    var mouseNote: UInt8? = nil

    let arpeggiator = Arpeggiator()
    let chordEngine = ChordEngine()
    let metronome = Metronome()
    let quantizer = LiveQuantizer()
    let scaleEngine = ScaleEngine()

    private var keyNoteMap: [UInt16: UInt8] = [:]
    private var noteStack = NoteStack(mode: .pushTop, capacity: 20)
    private var sustainedNotes: Set<UInt8> = []
    private let midiEngine: MIDIEngine
    private var pendingQuantizedNoteOns: Set<UInt8> = []
    private var scaleNoteMap: [UInt8: UInt8] = [:] // original -> scale-adjusted  // notes waiting to sound

    init(midiEngine: MIDIEngine) {
        self.midiEngine = midiEngine
        arpeggiator.configure(
            noteOn: { [weak self] (note: UInt8, vel: UInt8) in
                guard let self else { return }
                self.midiEngine.sendNoteOn(note: note, velocity: vel, channel: self.midiEngine.channel)
            },
            noteOff: { [weak self] (note: UInt8) in
                guard let self else { return }
                self.midiEngine.sendNoteOff(note: note, channel: self.midiEngine.channel)
            },
            metronome: metronome
        )

        // Wire external MIDI input
        midiEngine.onExternalNoteOn = { [weak self] (note: UInt8, vel: UInt8) in
            guard let self else { return }
            self.velocity = vel
            self.handleNoteOn(note)
        }
        midiEngine.onExternalNoteOff = { [weak self] (note: UInt8) in
            guard let self else { return }
            self.handleNoteOff(note)
        }
    }

    // MARK: - Note routing

    private func handleNoteOn(_ midiNote: UInt8) {
        // Apply scale
        guard let scaledNote = scaleEngine.process(note: midiNote) else {
            return // filtered out by scale
        }
        scaleNoteMap[midiNote] = scaledNote

        let delay = quantizer.delayForNoteOn()

        if delay > 0.001 {
            pendingQuantizedNoteOns.insert(scaledNote)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
                pendingQuantizedNoteOns.remove(scaledNote)
                fireNoteOn(scaledNote)
            }
        } else {
            fireNoteOn(scaledNote)
        }
    }

    private func fireNoteOn(_ midiNote: UInt8) {
        if arpeggiator.enabled {
            arpeggiator.notePressed(midiNote, velocity: velocity)
        } else if chordEngine.enabled {
            chordEngine.press(root: midiNote, velocity: velocity) { note, vel in
                midiEngine.sendNoteOn(note: note, velocity: vel, channel: midiEngine.channel)
            }
        } else {
            noteStack.push(note: midiNote, velocity: velocity)
            midiEngine.sendNoteOn(note: midiNote, velocity: velocity, channel: midiEngine.channel)
        }
    }

    private func handleNoteOff(_ midiNote: UInt8) {
        let scaledNote = scaleNoteMap.removeValue(forKey: midiNote) ?? midiNote

        if pendingQuantizedNoteOns.contains(scaledNote) {
            DispatchQueue.main.asyncAfter(deadline: .now() + quantizer.delayForNoteOn() + 0.01) { [self] in
                fireNoteOff(scaledNote)
            }
        } else {
            fireNoteOff(scaledNote)
        }
    }

    private func fireNoteOff(_ midiNote: UInt8) {
        if arpeggiator.enabled {
            arpeggiator.noteReleased(midiNote)
        } else if chordEngine.enabled {
            chordEngine.release(root: midiNote) { note in
                midiEngine.sendNoteOff(note: note, channel: midiEngine.channel)
            }
        } else {
            noteStack.pop(note: midiNote)
            if sustainActive {
                sustainedNotes.insert(midiNote)
            } else {
                midiEngine.sendNoteOff(note: midiNote, channel: midiEngine.channel)
            }
        }
    }

    // MARK: - Keyboard input

    func keyDown(keyCode: UInt16) {
        guard !pressedKeys.contains(keyCode) else { return }
        pressedKeys.insert(keyCode)

        guard let action = KeyboardMapping.actions[keyCode] else { return }

        switch action {
        case .note(let offset):
            let midiNote = UInt8(clamping: octave * 12 + offset)
            guard midiNote <= 127 else { return }
            keyNoteMap[keyCode] = midiNote
            handleNoteOn(midiNote)

        case .octaveDown:
            octave = max(0, octave - 1)
        case .octaveUp:
            octave = min(8, octave + 1)
        case .velocityDown:
            velocity = UInt8(max(1, Int(velocity) - 10))
        case .velocityUp:
            velocity = UInt8(min(127, Int(velocity) + 10))
        case .sustain:
            sustainActive = true
            midiEngine.sendCC(controller: 64, value: 127, channel: midiEngine.channel)
        }
    }

    func keyUp(keyCode: UInt16) {
        pressedKeys.remove(keyCode)
        guard let action = KeyboardMapping.actions[keyCode] else { return }

        switch action {
        case .note:
            guard let midiNote = keyNoteMap.removeValue(forKey: keyCode) else { return }
            handleNoteOff(midiNote)

        case .sustain:
            sustainActive = false
            midiEngine.sendCC(controller: 64, value: 0, channel: midiEngine.channel)
            for note in sustainedNotes {
                midiEngine.sendNoteOff(note: note, channel: midiEngine.channel)
            }
            sustainedNotes.removeAll()

        default:
            break
        }
    }

    // MARK: - Mouse input

    func mouseNoteOn(semitoneOffset: Int) {
        let midiNote = UInt8(clamping: octave * 12 + semitoneOffset)
        guard midiNote <= 127 else { return }
        if let prev = mouseNote, prev != midiNote {
            handleNoteOff(prev)
        }
        if mouseNote != midiNote {
            mouseNote = midiNote
            handleNoteOn(midiNote)
        }
    }

    func mouseNoteOff() {
        if let note = mouseNote {
            handleNoteOff(note)
            mouseNote = nil
        }
    }

    // MARK: - Cleanup

    func allNotesOff() {
        pendingQuantizedNoteOns.removeAll()
        scaleNoteMap.removeAll()

        for item in noteStack.allNotes where !item.isEmpty {
            midiEngine.sendNoteOff(note: item.note, channel: midiEngine.channel)
        }
        noteStack.clear()
        keyNoteMap.removeAll()

        for note in sustainedNotes {
            midiEngine.sendNoteOff(note: note, channel: midiEngine.channel)
        }
        sustainedNotes.removeAll()
        sustainActive = false
        pressedKeys.removeAll()

        arpeggiator.stop()
        chordEngine.allOff { [weak self] (note: UInt8) in
            guard let self else { return }
            self.midiEngine.sendNoteOff(note: note, channel: self.midiEngine.channel)
        }

        if let note = mouseNote {
            midiEngine.sendNoteOff(note: note, channel: midiEngine.channel)
            mouseNote = nil
        }

        // Send sustain off + all notes off CC
        midiEngine.sendCC(controller: 64, value: 0, channel: midiEngine.channel)
        midiEngine.sendCC(controller: 123, value: 0, channel: midiEngine.channel)
    }
}
