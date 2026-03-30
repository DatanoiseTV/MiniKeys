import Foundation
import Observation

enum ChordType: String, CaseIterable, Codable {
    case major, minor, sus2, sus4
    case dim, aug
    case dom7, maj7, min7, minMaj7
    case dim7, halfDim7, aug7
    case add9, madd9
    case power

    var displayName: String {
        switch self {
        case .major: "Major"
        case .minor: "Minor"
        case .sus2: "Sus2"
        case .sus4: "Sus4"
        case .dim: "Dim"
        case .aug: "Aug"
        case .dom7: "7"
        case .maj7: "Maj7"
        case .min7: "Min7"
        case .minMaj7: "mMaj7"
        case .dim7: "Dim7"
        case .halfDim7: "m7b5"
        case .aug7: "Aug7"
        case .add9: "Add9"
        case .madd9: "mAdd9"
        case .power: "5th"
        }
    }

    /// Semitone intervals from root
    var intervals: [Int] {
        switch self {
        case .major:    [0, 4, 7]
        case .minor:    [0, 3, 7]
        case .sus2:     [0, 2, 7]
        case .sus4:     [0, 5, 7]
        case .dim:      [0, 3, 6]
        case .aug:      [0, 4, 8]
        case .dom7:     [0, 4, 7, 10]
        case .maj7:     [0, 4, 7, 11]
        case .min7:     [0, 3, 7, 10]
        case .minMaj7:  [0, 3, 7, 11]
        case .dim7:     [0, 3, 6, 9]
        case .halfDim7: [0, 3, 6, 10]
        case .aug7:     [0, 4, 8, 10]
        case .add9:     [0, 4, 7, 14]
        case .madd9:    [0, 3, 7, 14]
        case .power:    [0, 7]
        }
    }
}

@Observable
@MainActor
final class ChordEngine {
    var enabled = false
    var chordType: ChordType = .major
    var inversion: Int = 0  // 0 = root, 1 = first, 2 = second, etc.

    private(set) var activeChords: [UInt8: [UInt8]] = [:] // root -> sounding notes

    /// All MIDI notes currently sounding from chords
    var allSoundingNotes: Set<UInt8> {
        Set(activeChords.values.flatMap { $0 })
    }

    func notesForChord(root: UInt8) -> [UInt8] {
        var intervals = chordType.intervals
        let noteCount = intervals.count

        // Apply inversion: move N bottom notes up an octave
        let inv = min(inversion, noteCount - 1)
        for i in 0..<inv {
            intervals[i] += 12
        }

        return intervals.compactMap { offset in
            let note = Int(root) + offset
            return note <= 127 ? UInt8(note) : nil
        }
    }

    func press(root: UInt8, velocity: UInt8, sendNoteOn: (UInt8, UInt8) -> Void) {
        let notes = notesForChord(root: root)
        activeChords[root] = notes
        for note in notes {
            sendNoteOn(note, velocity)
        }
    }

    func release(root: UInt8, sendNoteOff: (UInt8) -> Void) {
        guard let notes = activeChords.removeValue(forKey: root) else { return }
        for note in notes {
            sendNoteOff(note)
        }
    }

    func allOff(sendNoteOff: (UInt8) -> Void) {
        for (_, notes) in activeChords {
            for note in notes { sendNoteOff(note) }
        }
        activeChords.removeAll()
    }
}
