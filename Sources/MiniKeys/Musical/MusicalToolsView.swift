import SwiftUI

enum MusicalTool: String, CaseIterable {
    case metronome, quantize, scale, arp, chord, gamepad

    var label: String {
        switch self {
        case .metronome: "Metro"
        case .quantize: "Quantize"
        case .scale: "Scale"
        case .arp: "Arp"
        case .chord: "Chord"
        case .gamepad: "Gamepad"
        }
    }

    var icon: String {
        switch self {
        case .metronome: "metronome"
        case .quantize: "square.grid.3x3"
        case .scale: "music.note.list"
        case .arp: "arrow.up.arrow.down"
        case .chord: "music.note"
        case .gamepad: "gamecontroller"
        }
    }
}

struct MusicalToolsView: View {
    @Bindable var arpeggiator: Arpeggiator
    @Bindable var chordEngine: ChordEngine
    @Bindable var metronome: Metronome
    @Bindable var quantizer: LiveQuantizer
    @Bindable var scaleEngine: ScaleEngine
    @Bindable var gamepadManager: GamepadManager
    let controls: [CCControl]
    var onModeChange: () -> Void = {}

    @State private var expandedTool: MusicalTool? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Toggle pills row
            HStack(spacing: 4) {
                ForEach(MusicalTool.allCases, id: \.self) { tool in
                    ToolPill(
                        tool: tool,
                        isActive: isToolActive(tool),
                        isExpanded: expandedTool == tool,
                        onToggleActive: { toggleActive(tool) },
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedTool = expandedTool == tool ? nil : tool
                            }
                        }
                    )
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)

            // Expanded settings for the selected tool
            if let tool = expandedTool {
                toolSettings(for: tool)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
                    )
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Active state

    private func isToolActive(_ tool: MusicalTool) -> Bool {
        switch tool {
        case .metronome: metronome.enabled
        case .quantize: quantizer.enabled
        case .scale: scaleEngine.enabled
        case .arp: arpeggiator.enabled
        case .chord: chordEngine.enabled
        case .gamepad: gamepadManager.isActive
        }
    }

    private func toggleActive(_ tool: MusicalTool) {
        switch tool {
        case .metronome: metronome.enabled.toggle()
        case .quantize: quantizer.enabled.toggle()
        case .scale:
            scaleEngine.enabled.toggle()
            onModeChange()
        case .arp:
            arpeggiator.enabled.toggle()
            if arpeggiator.enabled { chordEngine.enabled = false }
            onModeChange()
        case .chord:
            chordEngine.enabled.toggle()
            if chordEngine.enabled { arpeggiator.enabled = false }
            onModeChange()
        case .gamepad:
            gamepadManager.isActive.toggle()
            if gamepadManager.isActive { gamepadManager.startPolling() }
            else { gamepadManager.stopPolling() }
        }
    }

    // MARK: - Settings panels

    @ViewBuilder
    private func toolSettings(for tool: MusicalTool) -> some View {
        switch tool {
        case .metronome: metronomeSettings
        case .quantize: quantizeSettings
        case .scale: scaleSettings
        case .arp: arpSettings
        case .chord: chordSettings
        case .gamepad: gamepadSettings
        }
    }

    private var metronomeSettings: some View {
        HStack(spacing: 10) {
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
                TapTempoButton { newBPM in
                    metronome.bpm = newBPM
                    arpeggiator.bpm = newBPM
                    quantizer.bpm = newBPM
                }
            }

            Picker("", selection: $metronome.beatsPerBar) {
                ForEach([2, 3, 4, 5, 6, 7], id: \.self) { n in
                    Text("\(n)/4").tag(n)
                }
            }
            .fixedSize()

            HStack(spacing: 2) {
                Text("Vol")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Slider(value: $metronome.volume, in: 0...1)
                    .frame(width: 50)
            }

            HStack(spacing: 3) {
                ForEach(0..<metronome.beatsPerBar, id: \.self) { beat in
                    Circle()
                        .fill(beat == metronome.currentBeat ? (beat == 0 ? Color.orange : Color.accentColor) : Color.gray.opacity(0.25))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .font(.system(.caption))
    }

    private var quantizeSettings: some View {
        HStack(spacing: 10) {
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
        }
        .font(.system(.caption))
    }

    private var scaleSettings: some View {
        HStack(spacing: 10) {
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
        .font(.system(.caption))
    }

    private var arpSettings: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Picker("", selection: $arpeggiator.mode) {
                    ForEach(ArpMode.allCases, id: \.self) { m in
                        Text(m.displayName).tag(m)
                    }
                }
                .fixedSize()

                Picker("", selection: $arpeggiator.stackMode) {
                    ForEach(ArpStackMode.allCases, id: \.self) { s in
                        Text(s.displayName).tag(s)
                    }
                }
                .fixedSize()

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
                .fixedSize()

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
                    .fixedSize()
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

            // Gate pattern
            GatePatternView(
                pattern: $arpeggiator.gatePattern,
                length: $arpeggiator.patternLength,
                usePattern: $arpeggiator.useGatePattern
            )
        }
        .font(.system(.caption))
    }

    private var chordSettings: some View {
        HStack(spacing: 10) {
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
        .font(.system(.caption))
    }

    private var gamepadSettings: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if gamepadManager.connectedGamepads.isEmpty {
                    Text("No gamepad connected")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Picker("", selection: $gamepadManager.selectedGamepadIndex) {
                        ForEach(0..<gamepadManager.connectedGamepads.count, id: \.self) { i in
                            Text(gamepadManager.connectedGamepads[i].vendorName ?? "Gamepad \(i + 1)")
                                .tag(i as Int?)
                        }
                    }
                    .fixedSize()

                    Button(action: { gamepadManager.refreshGamepads() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !gamepadManager.connectedGamepads.isEmpty {
                ForEach($gamepadManager.bindings) { $binding in
                    GamepadBindingRow(
                        binding: $binding,
                        availableAxes: gamepadManager.availableAxes,
                        controls: controls,
                        onDelete: { gamepadManager.removeBinding(binding.id) }
                    )
                }

                Menu {
                    ForEach(gamepadManager.availableAxes, id: \.self) { axis in
                        Button(axis) { gamepadManager.addBinding(axis: axis) }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .bold))
                        Text("Add Axis")
                            .font(.system(size: 10))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.15)))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
        .font(.system(.caption))
    }
}

// MARK: - Tool Pill

struct ToolPill: View {
    let tool: MusicalTool
    let isActive: Bool
    let isExpanded: Bool
    let onToggleActive: () -> Void
    let onToggleExpand: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // On/off indicator — click to toggle
            Circle()
                .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 7, height: 7)
                .onTapGesture { onToggleActive() }

            Image(systemName: tool.icon)
                .font(.system(size: 9))

            Text(tool.label)
                .font(.system(size: 10, weight: isActive ? .semibold : .regular))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isActive ? Color.accentColor.opacity(0.15) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isExpanded ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
        .foregroundStyle(isActive ? Color.accentColor : .secondary)
        .onTapGesture { onToggleExpand() }
    }
}

// MARK: - Gate Pattern

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
                        Text("!").font(.system(size: 8, weight: .black)).foregroundStyle(.white)
                    } else if step == .tie {
                        Text("~").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(index % 4 == 0 ? Color.primary.opacity(0.2) : Color.clear, lineWidth: 1)
            )
            .onTapGesture {
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

// MARK: - Tap Tempo

struct TapTempoButton: View {
    let onBPM: (Double) -> Void

    @State private var taps: [TimeInterval] = []
    @State private var lastTapTime: TimeInterval = 0
    @State private var isFlashing = false

    private let maxTaps = 8
    private let resetTimeout: TimeInterval = 2.0

    var body: some View {
        Button(action: tap) {
            Text("Tap")
                .font(.system(size: 9, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isFlashing ? Color.accentColor.opacity(0.4) : Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
        .help("Tap repeatedly to set BPM")
    }

    private func tap() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastTapTime > resetTimeout { taps.removeAll() }
        taps.append(now)
        lastTapTime = now
        if taps.count > maxTaps { taps.removeFirst() }

        if taps.count >= 2 {
            let totalInterval = taps.last! - taps.first!
            let avgInterval = totalInterval / Double(taps.count - 1)
            let bpm = min(300, max(20, 60.0 / avgInterval))
            onBPM(Double(Int(bpm * 10)) / 10.0)
        }

        isFlashing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { isFlashing = false }
    }
}

// MARK: - Gamepad Binding Row

struct GamepadBindingRow: View {
    @Binding var binding: GamepadBinding
    let availableAxes: [String]
    let controls: [CCControl]
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $binding.axisName) {
                ForEach(availableAxes, id: \.self) { axis in
                    Text(axis).tag(axis)
                }
            }
            .frame(width: 130)

            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Picker("", selection: $binding.controlID) {
                Text("None").tag(nil as UUID?)
                ForEach(controls) { control in
                    Text("\(control.label) (CC \(control.ccNumber))")
                        .tag(control.id as UUID?)
                }
            }
            .fixedSize()
            .onChange(of: binding.controlID) { _, newID in
                if let id = newID, let ctrl = controls.first(where: { $0.id == id }) {
                    binding.controlLabel = ctrl.label
                }
            }

            Toggle("Inv", isOn: $binding.inverted)
                .toggleStyle(.checkbox)
                .font(.system(size: 9))

            HStack(spacing: 2) {
                Text("DZ")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Slider(value: $binding.deadzone, in: 0...0.5, step: 0.05)
                    .frame(width: 40)
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 10))
                    .foregroundStyle(.red.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
        .font(.system(.caption))
    }
}
