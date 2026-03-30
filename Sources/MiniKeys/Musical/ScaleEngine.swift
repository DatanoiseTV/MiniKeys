import Foundation
import Observation

enum ScaleType: String, CaseIterable, Codable {
    case chromatic
    case major
    case naturalMinor
    case harmonicMinor
    case melodicMinor
    case dorian
    case phrygian
    case lydian
    case mixolydian
    case locrian
    case pentatonicMajor
    case pentatonicMinor
    case blues
    case wholeNote
    case diminished
    case augmented

    var displayName: String {
        switch self {
        case .chromatic: "Chromatic"
        case .major: "Major"
        case .naturalMinor: "Minor"
        case .harmonicMinor: "Harm. Minor"
        case .melodicMinor: "Mel. Minor"
        case .dorian: "Dorian"
        case .phrygian: "Phrygian"
        case .lydian: "Lydian"
        case .mixolydian: "Mixolydian"
        case .locrian: "Locrian"
        case .pentatonicMajor: "Pent. Major"
        case .pentatonicMinor: "Pent. Minor"
        case .blues: "Blues"
        case .wholeNote: "Whole Tone"
        case .diminished: "Diminished"
        case .augmented: "Augmented"
        }
    }

    /// Semitone intervals from root that belong to the scale
    var intervals: Set<Int> {
        switch self {
        case .chromatic:       [0,1,2,3,4,5,6,7,8,9,10,11]
        case .major:           [0,2,4,5,7,9,11]
        case .naturalMinor:    [0,2,3,5,7,8,10]
        case .harmonicMinor:   [0,2,3,5,7,8,11]
        case .melodicMinor:    [0,2,3,5,7,9,11]
        case .dorian:          [0,2,3,5,7,9,10]
        case .phrygian:        [0,1,3,5,7,8,10]
        case .lydian:          [0,2,4,6,7,9,11]
        case .mixolydian:      [0,2,4,5,7,9,10]
        case .locrian:         [0,1,3,5,6,8,10]
        case .pentatonicMajor: [0,2,4,7,9]
        case .pentatonicMinor: [0,3,5,7,10]
        case .blues:           [0,3,5,6,7,10]
        case .wholeNote:       [0,2,4,6,8,10]
        case .diminished:      [0,2,3,5,6,8,9,11]
        case .augmented:       [0,3,4,7,8,11]
        }
    }
}

enum RootNote: UInt8, CaseIterable, Codable {
    case c = 0, cSharp = 1, d = 2, dSharp = 3
    case e = 4, f = 5, fSharp = 6, g = 7
    case gSharp = 8, a = 9, aSharp = 10, b = 11

    var displayName: String {
        switch self {
        case .c: "C"
        case .cSharp: "C#"
        case .d: "D"
        case .dSharp: "D#"
        case .e: "E"
        case .f: "F"
        case .fSharp: "F#"
        case .g: "G"
        case .gSharp: "G#"
        case .a: "A"
        case .aSharp: "A#"
        case .b: "B"
        }
    }
}

enum ScaleForceMode: String, CaseIterable, Codable {
    case off       // no scale filtering
    case filter    // out-of-scale notes are blocked (no sound)
    case snapUp    // out-of-scale notes snap to nearest scale note above
    case snapDown  // snap to nearest below
    case snapNearest // snap to nearest (up or down)

    var displayName: String {
        switch self {
        case .off: "Off"
        case .filter: "Filter"
        case .snapUp: "Snap Up"
        case .snapDown: "Snap Down"
        case .snapNearest: "Snap Near"
        }
    }
}

@Observable
@MainActor
final class ScaleEngine {
    var enabled = false { didSet { invalidateCache() } }
    var scale: ScaleType = .major { didSet { invalidateCache() } }
    var root: RootNote = .c { didSet { invalidateCache() } }
    var forceMode: ScaleForceMode = .snapNearest

    private var _cachedScaleNotes: Set<UInt8>?

    /// Returns the set of MIDI note numbers (0-127) that are in the current scale
    var scaleNotes: Set<UInt8> {
        if let cached = _cachedScaleNotes { return cached }
        let result: Set<UInt8>
        if !enabled || scale == .chromatic {
            result = Set(0...127)
        } else {
            var notes = Set<UInt8>()
            let ints = scale.intervals
            for midi in 0...127 {
                let degree = (midi - Int(root.rawValue) + 120) % 12 // +120 to avoid negative mod
                if ints.contains(degree) {
                    notes.insert(UInt8(midi))
                }
            }
            result = notes
        }
        _cachedScaleNotes = result
        return result
    }

    private func invalidateCache() {
        _cachedScaleNotes = nil
    }

    /// Process a MIDI note through the scale filter/snap.
    /// Returns nil if the note should be blocked, or the (possibly adjusted) note.
    func process(note: UInt8) -> UInt8? {
        guard enabled, scale != .chromatic else { return note }

        let degree = (Int(note) - Int(root.rawValue) + 120) % 12
        if scale.intervals.contains(degree) {
            return note // already in scale
        }

        switch forceMode {
        case .off:
            return note
        case .filter:
            return nil
        case .snapUp:
            return snapUp(from: note)
        case .snapDown:
            return snapDown(from: note)
        case .snapNearest:
            let up = snapUp(from: note)
            let down = snapDown(from: note)
            guard let u = up, let d = down else { return up ?? down }
            return (u - note) <= (note - d) ? u : d
        }
    }

    private func snapUp(from note: UInt8) -> UInt8? {
        for offset in 1...6 {
            let candidate = Int(note) + offset
            if candidate > 127 { return nil }
            let degree = (candidate - Int(root.rawValue) + 120) % 12
            if scale.intervals.contains(degree) { return UInt8(candidate) }
        }
        return nil
    }

    private func snapDown(from note: UInt8) -> UInt8? {
        for offset in 1...6 {
            let candidate = Int(note) - offset
            if candidate < 0 { return nil }
            let degree = (candidate - Int(root.rawValue) + 120) % 12
            if scale.intervals.contains(degree) { return UInt8(candidate) }
        }
        return nil
    }

    /// Check if a given MIDI note is in the current scale (for keyboard highlighting)
    func isInScale(_ note: UInt8) -> Bool {
        guard enabled, scale != .chromatic else { return true }
        let degree = (Int(note) - Int(root.rawValue) + 120) % 12
        return scale.intervals.contains(degree)
    }
}
