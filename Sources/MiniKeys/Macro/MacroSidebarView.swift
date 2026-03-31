import SwiftUI

struct MacroSidebarView: View {
    @Bindable var engine: MacroEngine
    let channel: UInt8

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Macros")
                    .font(.system(.body, weight: .semibold))
                Spacer()
                Button(action: { engine.addMacro() }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Add macro")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if engine.macros.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "slider.horizontal.2.square")
                        .font(.system(size: 24))
                        .foregroundStyle(.quaternary)
                    Text("Add a macro to control\nmultiple CCs at once")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 14) {
                        ForEach($engine.macros) { $macro in
                            MacroCardView(
                                macro: $macro,
                                channel: channel,
                                engine: engine
                            )
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 200)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.2))
    }
}

// MARK: - Macro Card

struct MacroCardView: View {
    @Binding var macro: MacroControl
    let channel: UInt8
    let engine: MacroEngine

    @State private var isDragging = false
    @State private var dragStart: Double = 0
    @State private var showMappings = false
    @State private var isRenaming = false

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
        VStack(spacing: 8) {
            // Label (double-click to rename)
            if isRenaming {
                TextField("", text: $macro.label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption))
                    .multilineTextAlignment(.center)
                    .onSubmit { isRenaming = false }
                    .onExitCommand { isRenaming = false }
            } else {
                Text(macro.label)
                    .font(.system(.caption, weight: .medium))
                    .lineLimit(1)
                    .onTapGesture(count: 2) { isRenaming = true }
            }

            // Knob
            ZStack {
                KnobArc(normalized: 1.0)
                    .stroke(Color.gray.opacity(0.2), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)

                if normalizedValue > 0 {
                    KnobArc(normalized: normalizedValue)
                        .stroke(accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .frame(width: 56, height: 56)
                }

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.15), radius: 2)

                Rectangle()
                    .fill(accentColor)
                    .frame(width: 2, height: 16)
                    .offset(y: -12)
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

            Text("\(macro.value)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            // Morph A/B
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Button("A") { engine.saveMorphA(macro.id) }
                        .font(.system(size: 9, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .help("Save current position as Morph A (\(macro.morphA))")

                    Slider(value: Binding(
                        get: {
                            let a = Double(macro.morphA)
                            let b = Double(macro.morphB)
                            guard b != a else { return 0 }
                            return max(0, min(1, (Double(macro.value) - a) / (b - a)))
                        },
                        set: { pos in
                            engine.morphTo(macro.id, position: max(0, min(1, pos)), channel: channel)
                        }
                    ), in: 0...1)

                    Button("B") { engine.saveMorphB(macro.id) }
                        .font(.system(size: 9, weight: .bold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.tertiary)
                        .help("Save current position as Morph B (\(macro.morphB))")
                }

                Text("Morph \(macro.morphA) \u{2194} \(macro.morphB)")
                    .font(.system(size: 8))
                    .foregroundStyle(.quaternary)
            }

            // Mappings toggle
            Button(action: { withAnimation(.easeInOut(duration: 0.12)) { showMappings.toggle() } }) {
                HStack(spacing: 3) {
                    Image(systemName: showMappings ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7))
                    Text("\(macro.mappings.count) mapping\(macro.mappings.count == 1 ? "" : "s")")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if showMappings {
                VStack(spacing: 6) {
                    ForEach($macro.mappings) { $mapping in
                        MacroMappingRow(mapping: $mapping, onDelete: {
                            macro.mappings.removeAll { $0.id == mapping.id }
                        })
                    }

                    Button(action: { macro.mappings.append(MacroMapping()) }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                            Text("Add mapping")
                                .font(.system(size: 9))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
        .contextMenu {
            Menu("Color") {
                ForEach(MacroColor.allCases, id: \.self) { color in
                    Button(color.displayName) { macro.color = color }
                }
            }
            Button("Rename") { isRenaming = true }
            Divider()
            Button("Delete", role: .destructive) { engine.removeMacro(macro.id) }
        }
    }
}

// MARK: - Mapping Row

struct MacroMappingRow: View {
    @Binding var mapping: MacroMapping
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text("CC \(mapping.destCCNumber)")
                    .font(.system(size: 9, weight: .medium))
                Spacer()
                Picker("", selection: $mapping.curve) {
                    ForEach(MacroCurve.allCases, id: \.self) { c in
                        Text(c.displayName).tag(c)
                    }
                }
                .fixedSize()
                .font(.system(size: 8))

                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 4) {
                TextField("CC", value: $mapping.destCCNumber, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 34)
                    .font(.system(size: 9))

                Text("\(mapping.destMin)")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.15))
                            .frame(height: 4)
                            .cornerRadius(2)

                        Rectangle()
                            .fill(Color.accentColor.opacity(0.4))
                            .frame(
                                width: geo.size.width * CGFloat(mapping.destMax - mapping.destMin) / 127.0,
                                height: 4
                            )
                            .offset(x: geo.size.width * CGFloat(mapping.destMin) / 127.0)
                            .cornerRadius(2)
                    }
                    .frame(height: 4)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
                .frame(height: 12)

                Text("\(mapping.destMax)")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                TextField("Min", value: $mapping.destMin, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 30)
                    .font(.system(size: 8))
                Spacer()
                TextField("Max", value: $mapping.destMax, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 30)
                    .font(.system(size: 8))
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        )
    }
}
