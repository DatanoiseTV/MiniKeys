import SwiftUI

struct MacroSidebarView: View {
    @Bindable var engine: MacroEngine
    let channel: UInt8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Macros")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: { engine.addMacro() }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if engine.macros.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text("No macros")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Click + to add one")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach($engine.macros) { $macro in
                            MacroControlView(
                                macro: $macro,
                                channel: channel,
                                engine: engine
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
        .frame(width: 180)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }
}

// MARK: - Single Macro Control

struct MacroControlView: View {
    @Binding var macro: MacroControl
    let channel: UInt8
    let engine: MacroEngine

    @State private var isDragging = false
    @State private var dragStart: Double = 0
    @State private var isExpanded = false

    private var normalizedValue: Double {
        Double(macro.value) / 127.0
    }

    private var accentColor: Color {
        switch macro.color {
        case .blue: .blue
        case .purple: .purple
        case .orange: .orange
        case .green: .green
        case .red: .red
        case .yellow: .yellow
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            // Label
            Text(macro.label)
                .font(.system(.caption))
                .lineLimit(1)

            // Knob
            ZStack {
                KnobArc(normalized: 1.0)
                    .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)

                if normalizedValue > 0 {
                    KnobArc(normalized: normalizedValue)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 50, height: 50)
                }

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 40, height: 40)
                    .shadow(color: .black.opacity(0.15), radius: 2)

                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: 14)
                    .offset(y: -10)
                    .rotationEffect(.degrees(225 + normalizedValue * 270))
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStart = normalizedValue
                        }
                        let delta = -value.translation.height / 300.0
                        let newNorm = max(0, min(1, dragStart + delta))
                        let newVal = UInt8(clamping: Int(newNorm * 127))
                        engine.setMacroValue(macro.id, value: newVal, channel: channel)
                    }
                    .onEnded { _ in isDragging = false }
            )

            // Value
            Text("\(macro.value)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

            // Morph slider
            HStack(spacing: 4) {
                Text("A")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                Slider(value: Binding(
                    get: {
                        let a = Double(macro.morphA)
                        let b = Double(macro.morphB)
                        guard b != a else { return 0 }
                        return (Double(macro.value) - a) / (b - a)
                    },
                    set: { pos in
                        engine.morphTo(macro.id, position: max(0, min(1, pos)), channel: channel)
                    }
                ), in: 0...1)
                Text("B")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
            }

            // Expand/collapse mappings
            Button(action: { withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7))
                    Text("\(macro.mappings.count) mappings")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)

            if isExpanded {
                MacroMappingsEditor(macro: $macro, engine: engine, channel: channel)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .contextMenu {
            Menu("Color") {
                ForEach(MacroColor.allCases, id: \.self) { color in
                    Button(color.displayName) { macro.color = color }
                }
            }
            Divider()
            Button("Set Morph A") { engine.saveMorphA(macro.id) }
            Button("Set Morph B") { engine.saveMorphB(macro.id) }
            Divider()
            Button("Delete", role: .destructive) { engine.removeMacro(macro.id) }
        }
    }
}

// MARK: - Mappings Editor

struct MacroMappingsEditor: View {
    @Binding var macro: MacroControl
    let engine: MacroEngine
    let channel: UInt8

    var body: some View {
        VStack(spacing: 4) {
            ForEach($macro.mappings) { $mapping in
                HStack(spacing: 4) {
                    VStack(spacing: 1) {
                        Text("CC")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                        TextField("", value: $mapping.destCCNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 30)
                            .font(.system(size: 9))
                    }

                    VStack(spacing: 1) {
                        Text("Min")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                        TextField("", value: $mapping.destMin, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 26)
                            .font(.system(size: 9))
                    }

                    VStack(spacing: 1) {
                        Text("Max")
                            .font(.system(size: 7))
                            .foregroundStyle(.tertiary)
                        TextField("", value: $mapping.destMax, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 26)
                            .font(.system(size: 9))
                    }

                    Picker("", selection: $mapping.curve) {
                        ForEach(MacroCurve.allCases, id: \.self) { c in
                            Text(c.displayName).tag(c)
                        }
                    }
                    .frame(width: 45)
                    .font(.system(size: 8))

                    Button(action: { macro.mappings.removeAll { $0.id == mapping.id } }) {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: { macro.mappings.append(MacroMapping()) }) {
                HStack(spacing: 2) {
                    Image(systemName: "plus")
                        .font(.system(size: 8, weight: .bold))
                    Text("Add")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }
}
