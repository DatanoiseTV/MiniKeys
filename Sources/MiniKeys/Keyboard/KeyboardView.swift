import SwiftUI

struct KeyboardView: View {
    let pressedKeys: Set<UInt16>
    let mouseNote: UInt8?
    let chordNotes: Set<UInt8>
    let scaleNotes: Set<UInt8>  // notes in current scale (all 128 if off)
    let octave: Int
    let velocity: UInt8
    let sustainActive: Bool
    let onMouseNote: (Int) -> Void
    let onMouseNoteOff: () -> Void

    private let whiteKeyWidth: CGFloat = 48
    private let whiteKeyHeight: CGFloat = 120
    private let blackKeyWidth: CGFloat = 32
    private let blackKeyHeight: CGFloat = 75

    private func midiNoteForKey(_ keyCode: UInt16) -> UInt8? {
        guard let offset = KeyboardMapping.semitoneOffset(for: keyCode) else { return nil }
        let note = octave * 12 + offset
        return note <= 127 ? UInt8(note) : nil
    }

    enum KeyState {
        case inactive, chordHighlight, active, outOfScale
    }

    private func whiteKeyState(_ key: (keyCode: UInt16, label: String, noteName: String)) -> KeyState {
        if pressedKeys.contains(key.keyCode) { return .active }
        if let mn = mouseNote, let note = midiNoteForKey(key.keyCode), mn == note { return .active }
        if let note = midiNoteForKey(key.keyCode), chordNotes.contains(note) { return .chordHighlight }
        if let note = midiNoteForKey(key.keyCode), !scaleNotes.contains(note) { return .outOfScale }
        return .inactive
    }

    private func blackKeyState(_ key: (keyCode: UInt16, label: String, noteName: String, positionIndex: Int)) -> KeyState {
        if pressedKeys.contains(key.keyCode) { return .active }
        if let mn = mouseNote, let note = midiNoteForKey(key.keyCode), mn == note { return .active }
        if let note = midiNoteForKey(key.keyCode), chordNotes.contains(note) { return .chordHighlight }
        if let note = midiNoteForKey(key.keyCode), !scaleNotes.contains(note) { return .outOfScale }
        return .inactive
    }

    // Standard white/black note pattern for one octave (C to B)
    private static let octaveWhiteNotes = ["C", "D", "E", "F", "G", "A", "B"]
    // Black key positions within a 7-white-key octave (index among whites, 0-based)
    private static let octaveBlackPositions = [0, 1, 3, 4, 5] // C#, D#, F#, G#, A#

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                // Left ghost octave
                ghostOctave(octaveNumber: octave - 1)
                    .padding(.trailing, 4)

                // Main playable keyboard
                ZStack(alignment: .topLeading) {
                    // White keys
                    HStack(spacing: 2) {
                        ForEach(KeyboardMapping.whiteKeyOrder, id: \.keyCode) { key in
                            WhiteKeyView(
                                label: key.label,
                                noteName: key.noteName,
                                state: whiteKeyState(key)
                            )
                            .frame(width: whiteKeyWidth, height: whiteKeyHeight)
                        }
                    }

                    // Black keys overlaid
                    ForEach(KeyboardMapping.blackKeyOrder, id: \.keyCode) { key in
                        BlackKeyView(
                            label: key.label,
                            noteName: key.noteName,
                            state: blackKeyState(key)
                        )
                        .frame(width: blackKeyWidth, height: blackKeyHeight)
                        .offset(x: blackKeyXOffset(positionIndex: key.positionIndex), y: 0)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if let offset = hitTest(point: value.location) {
                                onMouseNote(offset)
                            }
                        }
                        .onEnded { _ in
                            onMouseNoteOff()
                        }
                )

                // Right ghost octave
                ghostOctave(octaveNumber: octave + 2)
                    .padding(.leading, 4)
            }

            HStack(spacing: 20) {
                Label("Octave: C\(octave)", systemImage: "pianokeys")
                    .font(.system(.body))

                Label("Velocity: \(velocity)", systemImage: "gauge.with.needle")
                    .font(.system(.body))

                HStack(spacing: 4) {
                    Circle()
                        .fill(sustainActive ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                    Text("Sustain")
                        .font(.system(.body))
                }

                Spacer()

                Text("Y: Oct\u{2193}  X: Oct\u{2191}  C/V: Vel  \u{21E7}: Sus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    private func blackKeyXOffset(positionIndex: Int) -> CGFloat {
        let keySpacing = whiteKeyWidth + 2
        return CGFloat(positionIndex) * keySpacing + (whiteKeyWidth - blackKeyWidth / 2) + 1
    }

    // Hit-test: check black keys first (on top), then white keys
    private func hitTest(point: CGPoint) -> Int? {
        // Black keys
        for key in KeyboardMapping.blackKeyOrder {
            let x = blackKeyXOffset(positionIndex: key.positionIndex)
            let rect = CGRect(x: x, y: 0, width: blackKeyWidth, height: blackKeyHeight)
            if rect.contains(point) {
                return KeyboardMapping.semitoneOffset(for: key.keyCode)
            }
        }

        // White keys
        let keySpacing = whiteKeyWidth + 2
        for (i, key) in KeyboardMapping.whiteKeyOrder.enumerated() {
            let x = CGFloat(i) * keySpacing
            let rect = CGRect(x: x, y: 0, width: whiteKeyWidth, height: whiteKeyHeight)
            if rect.contains(point) {
                return KeyboardMapping.semitoneOffset(for: key.keyCode)
            }
        }

        return nil
    }

    // Ghost octave: dimmed, non-interactive keys for visual context
    @ViewBuilder
    private func ghostOctave(octaveNumber: Int) -> some View {
        let ghostH = whiteKeyHeight * 0.85
        let ghostW = whiteKeyWidth * 0.8
        let ghostBlackW = blackKeyWidth * 0.8
        let ghostBlackH = blackKeyHeight * 0.85
        let whiteNotes = ["C", "D", "E", "F", "G", "A", "B"]
        let blackPositions = [0, 1, 3, 4, 5]

        ZStack(alignment: .topLeading) {
            HStack(spacing: 2) {
                ForEach(0..<7, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: ghostW, height: ghostH)
                        .overlay(
                            VStack {
                                Spacer()
                                Text(whiteNotes[i])
                                    .font(.system(size: 8))
                                    .foregroundStyle(.white.opacity(0.15))
                                    .padding(.bottom, 4)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 3)
                                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                        )
                }
            }

            ForEach(blackPositions, id: \.self) { pos in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.04))
                    .frame(width: ghostBlackW, height: ghostBlackH)
                    .offset(
                        x: CGFloat(pos) * (ghostW + 2) + (ghostW - ghostBlackW / 2) + 1,
                        y: 0
                    )
            }
        }
        .overlay(
            Text("C\(octaveNumber)")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.15))
                .padding(4),
            alignment: .topLeading
        )
    }
}

struct WhiteKeyView: View {
    let label: String
    let noteName: String
    let state: KeyboardView.KeyState

    private var fillColor: Color {
        switch state {
        case .active: Color.accentColor.opacity(0.7)
        case .chordHighlight: Color.accentColor.opacity(0.25)
        case .outOfScale, .inactive: Color.white
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(fillColor)
                .shadow(color: .black.opacity(0.2), radius: 1, y: 1)

            VStack {
                Spacer()
                Text(noteName)
                    .font(.caption2)
                    .foregroundStyle(state == .active ? Color.white.opacity(0.7) : state == .outOfScale ? Color.gray.opacity(0.15) : Color.gray)
                Text(label)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundStyle(state == .active ? .white : state == .outOfScale ? Color.gray.opacity(0.15) : Color(nsColor: .darkGray))
                    .padding(.bottom, 6)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
    }
}

struct BlackKeyView: View {
    let label: String
    let noteName: String
    let state: KeyboardView.KeyState

    private var fillColor: Color {
        switch state {
        case .active: Color.accentColor
        case .chordHighlight: Color.accentColor.opacity(0.4)
        case .outOfScale, .inactive: Color(nsColor: .darkGray)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(fillColor)
                .shadow(color: .black.opacity(0.4), radius: 2, y: 2)

            VStack {
                Spacer()
                Text(label)
                    .font(.system(.caption2, design: .monospaced).bold())
                    .foregroundStyle(state == .outOfScale ? Color.white.opacity(0.15) : .white)
                    .padding(.bottom, 4)
            }
        }
    }
}
