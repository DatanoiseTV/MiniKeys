import SwiftUI

struct MusicalToolsView: View {
    @Bindable var arpeggiator: Arpeggiator
    @Bindable var chordEngine: ChordEngine
    @Bindable var metronome: Metronome
    @Bindable var quantizer: LiveQuantizer
    @Bindable var scaleEngine: ScaleEngine
    var onModeChange: () -> Void = {}

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 12) {
                // Metronome
                GroupBox {
                    HStack(spacing: 8) {
                        Toggle("Metro", isOn: $metronome.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(.caption).bold())

                        if metronome.enabled {
                            HStack(spacing: 2) {
                                Text("BPM")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                TextField("", value: $metronome.bpm, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 42)
                                    .onChange(of: metronome.bpm) { _, newBPM in
                                        arpeggiator.bpm = newBPM
                                        quantizer.bpm = newBPM
                                    }
                            }

                            Picker("", selection: $metronome.beatsPerBar) {
                                ForEach([2, 3, 4, 5, 6, 7], id: \.self) { n in
                                    Text("\(n)/4").tag(n)
                                }
                            }
                            .frame(width: 52)

                            HStack(spacing: 2) {
                                Text("Vol")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Slider(value: $metronome.volume, in: 0...1)
                                    .frame(width: 40)
                            }

                            // Beat indicator
                            HStack(spacing: 3) {
                                ForEach(0..<metronome.beatsPerBar, id: \.self) { beat in
                                    Circle()
                                        .fill(beat == metronome.currentBeat ? (beat == 0 ? Color.orange : Color.accentColor) : Color.gray.opacity(0.25))
                                        .frame(width: 8, height: 8)
                                }
                            }
                        }
                    }
                }

                // Quantizer
                GroupBox {
                    HStack(spacing: 8) {
                        Toggle("Quantize", isOn: $quantizer.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(.caption).bold())

                        if quantizer.enabled {
                            Picker("", selection: $quantizer.division) {
                                ForEach(QuantizeDivision.allCases, id: \.self) { d in
                                    Text(d.displayName).tag(d)
                                }
                            }
                            .fixedSize()

                            HStack(spacing: 4) {
                                Text("Strength")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Slider(value: $quantizer.strength, in: 0...100, step: 10)
                                    .frame(width: 80)
                                Text("\(Int(quantizer.strength))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                            }

                            Toggle("Note-off", isOn: $quantizer.quantizeNoteOff)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 10))
                                .help("Also quantize note-off events")
                        }
                    }
                }

                // Scale
                GroupBox {
                    HStack(spacing: 8) {
                        Toggle("Scale", isOn: $scaleEngine.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(.caption).bold())
                            .onChange(of: scaleEngine.enabled) { _, _ in onModeChange() }

                        if scaleEngine.enabled {
                            Picker("", selection: $scaleEngine.root) {
                                ForEach(RootNote.allCases, id: \.self) { r in
                                    Text(r.displayName).tag(r)
                                }
                            }
                            .fixedSize()

                            Picker("", selection: $scaleEngine.scale) {
                                ForEach(ScaleType.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .fixedSize()

                            Picker("", selection: $scaleEngine.forceMode) {
                                ForEach(ScaleForceMode.allCases, id: \.self) { m in
                                    Text(m.displayName).tag(m)
                                }
                            }
                            .fixedSize()
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                // Arpeggiator
                GroupBox {
                    HStack(spacing: 10) {
                        Toggle("Arp", isOn: $arpeggiator.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(.caption).bold())
                            .onChange(of: arpeggiator.enabled) { _, on in
                                if on { chordEngine.enabled = false }
                                onModeChange()
                            }

                        if arpeggiator.enabled {
                            Picker("", selection: $arpeggiator.mode) {
                                ForEach(ArpMode.allCases, id: \.self) { m in
                                    Text(m.displayName).tag(m)
                                }
                            }
                            .frame(width: 80)

                            Picker("", selection: $arpeggiator.stackMode) {
                                ForEach(ArpStackMode.allCases, id: \.self) { s in
                                    Text(s.displayName).tag(s)
                                }
                            }
                            .frame(width: 72)
                            .help("Note priority / sorting")

                            HStack(spacing: 2) {
                                Text("BPM")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                TextField("", value: $arpeggiator.bpm, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 42)
                                    .onChange(of: arpeggiator.bpm) { _, newBPM in
                                        metronome.bpm = newBPM
                                        quantizer.bpm = newBPM
                                    }
                            }

                            Picker("", selection: $arpeggiator.division) {
                                ForEach(ArpDivision.allCases, id: \.self) { d in
                                    Text(d.displayName).tag(d)
                                }
                            }
                            .frame(width: 56)

                            HStack(spacing: 2) {
                                Text("Gate")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Slider(value: $arpeggiator.gatePercent, in: 5...100, step: 5)
                                    .frame(width: 50)
                                Text("\(Int(arpeggiator.gatePercent))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 26, alignment: .trailing)
                            }

                            HStack(spacing: 2) {
                                Text("Oct")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Picker("", selection: $arpeggiator.octaveRange) {
                                    ForEach(1...4, id: \.self) { n in Text("\(n)").tag(n) }
                                }
                                .frame(width: 40)
                            }

                            HStack(spacing: 4) {
                                Text("Swing")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                                Slider(value: $arpeggiator.swing, in: 0...100)
                                    .frame(width: 60)
                                Text("\(Int(arpeggiator.swing))%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 30, alignment: .trailing)
                            }

                            Toggle("Hold", isOn: $arpeggiator.hold)
                                .toggleStyle(.checkbox)
                                .font(.system(size: 10))
                        }
                    }
                }

                // Chord Mode
                GroupBox {
                    HStack(spacing: 10) {
                        Toggle("Chord", isOn: $chordEngine.enabled)
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .font(.system(.caption).bold())
                            .onChange(of: chordEngine.enabled) { _, on in
                                if on { arpeggiator.enabled = false }
                                onModeChange()
                            }

                        if chordEngine.enabled {
                            Picker("", selection: $chordEngine.chordType) {
                                ForEach(ChordType.allCases, id: \.self) { t in
                                    Text(t.displayName).tag(t)
                                }
                            }
                            .fixedSize()

                            Picker("Inversion", selection: $chordEngine.inversion) {
                                ForEach(0...3, id: \.self) { n in
                                    Text("Inv \(n)").tag(n)
                                }
                            }
                            .fixedSize()
                        }
                    }
                }
            }
            .font(.system(.caption))

            // Gate pattern
            if arpeggiator.enabled {
                GatePatternView(
                    pattern: $arpeggiator.gatePattern,
                    length: $arpeggiator.patternLength,
                    usePattern: $arpeggiator.useGatePattern
                )
            }
        }
    }
}

// MARK: - Gate Pattern Editor

struct GatePatternView: View {
    @Binding var pattern: [GateStep]
    @Binding var length: Int
    @Binding var usePattern: Bool

    var body: some View {
        HStack(spacing: 6) {
            Toggle("Pattern", isOn: $usePattern)
                .toggleStyle(.checkbox)
                .font(.system(size: 10))

            if usePattern {
                HStack(spacing: 2) {
                    ForEach(0..<length, id: \.self) { i in
                        GateStepCell(step: $pattern[i], index: i)
                    }
                }

                Picker("Length", selection: $length) {
                    ForEach([4, 8, 12, 16], id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .frame(width: 80)

                // Legend
                HStack(spacing: 6) {
                    LegendDot(color: .accentColor, label: "On")
                    LegendDot(color: .orange, label: "Accent")
                    LegendDot(color: .green, label: "Tie")
                    LegendDot(color: .gray.opacity(0.3), label: "Off")
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            }
        }
    }
}

struct GateStepCell: View {
    @Binding var step: GateStep
    let index: Int

    private var color: Color {
        switch step {
        case .off: .gray
        case .on: .accentColor
        case .accent: .orange
        case .tie: .green
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color.opacity(step == .off ? 0.2 : 0.8))
            .frame(width: 18, height: 18)
            .overlay(
                Group {
                    if step == .accent {
                        Text("!")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                    } else if step == .tie {
                        Text("~")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(index % 4 == 0 ? Color.white.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .onTapGesture {
                // Cycle: on -> accent -> tie -> off -> on
                switch step {
                case .on: step = .accent
                case .accent: step = .tie
                case .tie: step = .off
                case .off: step = .on
                }
            }
            .contextMenu {
                Button("On") { step = .on }
                Button("Accent") { step = .accent }
                Button("Tie") { step = .tie }
                Divider()
                Button("Off") { step = .off }
            }
    }
}

struct LegendDot: View {
    let color: Color
    let label: String
    var body: some View {
        HStack(spacing: 2) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}
