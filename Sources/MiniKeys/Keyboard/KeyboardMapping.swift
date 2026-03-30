import Carbon.HIToolbox

enum KeyAction {
    case note(semitoneOffset: Int)
    case octaveDown
    case octaveUp
    case velocityDown
    case velocityUp
    case sustain
}

struct KeyLabel {
    let keyChar: String
    let noteName: String?
    let isBlack: Bool
}

struct KeyboardMapping {
    // macOS keyCodes for the Ableton-style layout
    // White keys (middle row): A S D F G H J K L ; '
    // Black keys (upper row):  W E   T   U   O P
    // Controls: Z=octave down, Y=octave up, X=sustain, C=vel down, V=vel up

    static let actions: [UInt16: KeyAction] = [
        // White keys - middle row
        0x00: .note(semitoneOffset: 0),   // A -> C
        0x01: .note(semitoneOffset: 2),   // S -> D
        0x02: .note(semitoneOffset: 4),   // D -> E
        0x03: .note(semitoneOffset: 5),   // F -> F
        0x05: .note(semitoneOffset: 7),   // G -> G
        0x04: .note(semitoneOffset: 9),   // H -> A
        0x26: .note(semitoneOffset: 11),  // J -> B
        0x28: .note(semitoneOffset: 12),  // K -> C+1
        0x25: .note(semitoneOffset: 14),  // L -> D+1
        0x29: .note(semitoneOffset: 16),  // ; -> E+1
        0x27: .note(semitoneOffset: 17),  // ' -> F+1

        // Black keys - upper row
        0x0D: .note(semitoneOffset: 1),   // W -> C#
        0x0E: .note(semitoneOffset: 3),   // E -> D#
        0x11: .note(semitoneOffset: 6),   // T -> F#
        0x20: .note(semitoneOffset: 10),  // U -> A#
        0x1F: .note(semitoneOffset: 13),  // O -> C#+1
        0x23: .note(semitoneOffset: 15),  // P -> D#+1

        // Controls (by physical key position, layout-independent)
        // 0x10 = physical Y/Z key (rightmost top-left area)
        0x06: .sustain,      // Z (US) / Y (DE) - sustain
        0x10: .octaveDown,   // Y (US) / Z (DE) - octave down
        0x07: .octaveUp,     // X - octave up
        0x08: .velocityDown, // C - velocity down
        0x09: .velocityUp,   // V - velocity up
    ]

    // Keys that represent notes, in display order
    static let whiteKeyOrder: [(keyCode: UInt16, label: String, noteName: String)] = [
        (0x00, "A", "C"), (0x01, "S", "D"), (0x02, "D", "E"),
        (0x03, "F", "F"), (0x05, "G", "G"), (0x04, "H", "A"),
        (0x26, "J", "B"), (0x28, "K", "C"), (0x25, "L", "D"),
        (0x29, ";", "E"), (0x27, "'", "F"),
    ]

    static let blackKeyOrder: [(keyCode: UInt16, label: String, noteName: String, positionIndex: Int)] = [
        (0x0D, "W", "C#", 0),   // between A and S (C and D)
        (0x0E, "E", "D#", 1),   // between S and D (D and E)
        // gap at position 2 (no black key between E and F)
        (0x11, "T", "F#", 3),   // between F and G (F and G)
        // Y is octave up, skip G# position
        (0x20, "U", "A#", 5),   // between H and J (A and B)
        // gap at position 6 (no black key between B and C)
        (0x1F, "O", "C#", 7),   // between K and L
        (0x23, "P", "D#", 8),   // between L and ;
    ]

    static func isBlackKey(_ keyCode: UInt16) -> Bool {
        blackKeyOrder.contains { $0.keyCode == keyCode }
    }

    static func semitoneOffset(for keyCode: UInt16) -> Int? {
        if case .note(let offset) = actions[keyCode] {
            return offset
        }
        return nil
    }
}
