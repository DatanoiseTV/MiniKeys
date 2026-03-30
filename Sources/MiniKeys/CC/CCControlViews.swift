import SwiftUI

// MARK: - Dispatcher

struct CCControlView: View {
    @Binding var control: CCControl
    let isSelected: Bool
    let editMode: Bool
    let onValueChange: (CCControl, UInt8) -> Void
    let onSelect: () -> Void
    let onDelete: () -> Void
    @Environment(\.controlScale) private var scale

    @ViewBuilder
    private var controlContent: some View {
        switch control.type {
        case .knob:
            KnobControlView(control: $control, onValueChange: onValueChange)
        case .slider:
            SliderControlView(control: $control, onValueChange: onValueChange)
        case .button:
            ButtonControlView(control: $control, onValueChange: onValueChange)
        case .toggle:
            ToggleControlView(control: $control, onValueChange: onValueChange)
        case .select:
            SelectControlView(control: $control, onValueChange: onValueChange)
        case .adsr:
            ADSRControlView(control: $control, onValueChange: onValueChange)
        case .xyPad:
            XYPadControlView(control: $control, onValueChange: onValueChange)
        }
    }

    var body: some View {
        controlContent
        .scaleEffect(scale)
        .frame(
            width: intrinsicWidth * scale,
            height: intrinsicHeight * scale
        )
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
        )
        .overlay {
            // In edit mode, cover with a transparent tap target
            if editMode {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect() }
            }
        }
        .contextMenu {
            if editMode {
                Button("Delete", role: .destructive) { onDelete() }
            }
        }
    }

    private var intrinsicWidth: CGFloat {
        switch control.type {
        case .knob: 72
        case .slider: 52
        case .button: 72
        case .toggle: 72
        case .select: max(82, control.options.count > 6 ? 140 : 82)
        case .adsr: 172
        case .xyPad: 160
        }
    }
    private var intrinsicHeight: CGFloat {
        switch control.type {
        case .knob: return 110
        case .slider: return 140
        case .button: return 110
        case .toggle: return 110
        case .select:
            let rows = control.options.count > 6 ? (control.options.count + 1) / 2 : control.options.count
            return CGFloat(32 + rows * 20)
        case .adsr: return 150
        case .xyPad: return 180
        }
    }
}

// MARK: - Knob

struct KnobControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    @State private var dragStartValue: Double = 0
    @State private var isDragging = false

    private var normalizedValue: Double {
        guard control.maxValue > control.minValue else { return 0 }
        return Double(control.currentValue - control.minValue) / Double(control.maxValue - control.minValue)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(control.label)
                .font(.system(.caption2))
                .lineLimit(2)
                .frame(width: 60)

            ZStack {
                KnobArc(normalized: 1.0)
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 44, height: 44)

                if normalizedValue > 0 {
                    KnobArc(normalized: normalizedValue)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 44, height: 44)
                }

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.2), radius: 2)

                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 12)
                    .offset(y: -8)
                    .rotationEffect(.degrees(225 + normalizedValue * 270))
            }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = normalizedValue
                        }
                        let delta = -value.translation.height / 400.0
                        let range = Double(control.maxValue - control.minValue)
                        guard range > 0 else { return }
                        let stepSize = Double(control.step) / range
                        let newNorm = max(0, min(1, dragStartValue + delta))
                        let stepped = (newNorm / stepSize).rounded() * stepSize
                        let newValue = UInt8(clamping: Int(Double(control.minValue) + stepped * range))
                        if newValue != control.currentValue {
                            control.currentValue = newValue
                            onValueChange(control, newValue)
                        }
                    }
                    .onEnded { _ in isDragging = false }
            )

            Text("\(control.currentValue)")
                .font(.system(.caption2))
                .foregroundStyle(.secondary)

            Text("CC \(control.ccNumber)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Slider

struct SliderControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    @State private var dragStartValue: Double = 0
    @State private var isDragging = false

    private var normalizedValue: Double {
        guard control.maxValue > control.minValue else { return 0 }
        return Double(control.currentValue - control.minValue) / Double(control.maxValue - control.minValue)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(control.label)
                .font(.system(.caption2))
                .lineLimit(2)
                .frame(width: 40)

            ZStack(alignment: .bottom) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 80)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 8, height: max(2, 80 * normalizedValue))

                // Thumb
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 20, height: 8)
                    .shadow(color: .black.opacity(0.3), radius: 2)
                    .offset(y: -(80 * normalizedValue - 4))
            }
            .frame(height: 80)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = normalizedValue
                        }
                        let delta = -value.translation.height / 80.0
                        let range = Double(control.maxValue - control.minValue)
                        guard range > 0 else { return }
                        let stepSize = Double(control.step) / range
                        let newNorm = max(0, min(1, dragStartValue + delta))
                        let stepped = (newNorm / stepSize).rounded() * stepSize
                        let newValue = UInt8(clamping: Int(Double(control.minValue) + stepped * range))
                        if newValue != control.currentValue {
                            control.currentValue = newValue
                            onValueChange(control, newValue)
                        }
                    }
                    .onEnded { _ in isDragging = false }
            )

            Text("\(control.currentValue)")
                .font(.system(.caption2))
                .foregroundStyle(.secondary)

            Text("CC \(control.ccNumber)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Button (Momentary)

struct ButtonControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 4) {
            Text(control.label)
                .font(.system(.caption2))
                .lineLimit(2)
                .frame(width: 60)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(isPressed ? 0.1 : 0.25), radius: isPressed ? 1 : 3, y: isPressed ? 0 : 2)

                Image(systemName: "circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(isPressed ? .white : .gray.opacity(0.5))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            control.currentValue = control.maxValue
                            onValueChange(control, control.maxValue)
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        control.currentValue = control.minValue
                        onValueChange(control, control.minValue)
                    }
            )

            Text(isPressed ? "\(control.maxValue)" : "\(control.minValue)")
                .font(.system(.caption2))
                .foregroundStyle(.secondary)

            Text("CC \(control.ccNumber)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Toggle (Latching)

struct ToggleControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text(control.label)
                .font(.system(.caption2))
                .lineLimit(2)
                .frame(width: 60)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(control.isOn ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
                    .frame(width: 44, height: 44)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 1)

                Image(systemName: control.isOn ? "power.circle.fill" : "power.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(control.isOn ? .white : .gray.opacity(0.6))
            }
            .onTapGesture {
                control.isOn.toggle()
                let value = control.isOn ? control.maxValue : control.minValue
                control.currentValue = value
                onValueChange(control, value)
            }

            Text(control.isOn ? "\(control.maxValue)" : "\(control.minValue)")
                .font(.system(.caption2))
                .foregroundStyle(.secondary)

            Text("CC \(control.ccNumber)")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Select (Segmented pills)

struct SelectControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    private var selectedIndex: Int {
        control.options.firstIndex(where: { $0.id == control.selectedOptionID }) ?? 0
    }

    var body: some View {
        VStack(spacing: 6) {
            // Label + CC
            HStack(spacing: 4) {
                Text(control.label)
                    .font(.system(.caption2))
                    .lineLimit(2)
                Spacer()
                Text("CC \(control.ccNumber)")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }

            if control.options.count <= 6 {
                VStack(spacing: 3) {
                    ForEach(control.options) { option in
                        SelectPill(
                            label: option.label,
                            value: option.value,
                            isSelected: option.id == control.selectedOptionID,
                            onTap: {
                                control.selectedOptionID = option.id
                                control.currentValue = option.value
                                onValueChange(control, option.value)
                            }
                        )
                    }
                }
            } else {
                // Grid for many options
                let columns = [GridItem(.flexible(), spacing: 3), GridItem(.flexible(), spacing: 3)]
                LazyVGrid(columns: columns, spacing: 3) {
                    ForEach(control.options) { option in
                        SelectPill(
                            label: option.label,
                            value: option.value,
                            isSelected: option.id == control.selectedOptionID,
                            onTap: {
                                control.selectedOptionID = option.id
                                control.currentValue = option.value
                                onValueChange(control, option.value)
                            }
                        )
                    }
                }
            }
        }
        .padding(4)
        .frame(minWidth: 80)
    }
}

struct SelectPill: View {
    let label: String
    let value: UInt8
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 3) {
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                    .lineLimit(2)
                Spacer()
                Text("\(value)")
                    .font(.system(size: 7))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.6) : Color.gray)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor).opacity(0.6))
            )
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ADSR Envelope

struct ADSRControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    private let paramLabels = ["A", "D", "S", "R"]

    private func norm(_ i: Int) -> Double {
        Double(control.adsrValues[i]) / 127.0
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(control.label)
                .font(.system(.caption2))
                .lineLimit(2)
                .frame(width: 160)

            EnvelopeShape(a: norm(0), d: norm(1), s: norm(2), r: norm(3))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .background(
                    EnvelopeShape(a: norm(0), d: norm(1), s: norm(2), r: norm(3))
                        .fill(Color.accentColor.opacity(0.1))
                )
                .frame(width: 150, height: 50)
                .padding(.vertical, 2)

            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { i in
                    ADSRParamSlider(
                        label: paramLabels[i],
                        value: Binding(
                            get: { control.adsrValues[i] },
                            set: { newVal in
                                control.adsrValues[i] = newVal
                                // Create a temporary control with just the CC for this ADSR param
                                var paramControl = control
                                paramControl.ccNumber = control.adsrCCs[i]
                                paramControl.messageType = .cc
                                onValueChange(paramControl, newVal)
                            }
                        ),
                        ccNumber: control.adsrCCs[i]
                    )
                }
            }
        }
    }
}

struct ADSRParamSlider: View {
    let label: String
    @Binding var value: UInt8
    let ccNumber: UInt8

    @State private var dragStartValue: Double = 0
    @State private var isDragging = false

    private var normalized: Double {
        Double(value) / 127.0
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.gray.opacity(0.25))
                    .frame(width: 6, height: 40)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor)
                    .frame(width: 6, height: max(1, 40 * normalized))

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 14, height: 5)
                    .shadow(color: .black.opacity(0.3), radius: 1)
                    .offset(y: -(40 * normalized - 2.5))
            }
            .frame(height: 40)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { drag in
                        if !isDragging {
                            isDragging = true
                            dragStartValue = normalized
                        }
                        let delta = -drag.translation.height / 50.0
                        let newNorm = max(0, min(1, dragStartValue + delta))
                        let newVal = UInt8(clamping: Int(newNorm * 127))
                        if newVal != value { value = newVal }
                    }
                    .onEnded { _ in isDragging = false }
            )

            Text("\(value)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
    }
}

struct EnvelopeShape: Shape {
    let a: Double  // attack time (0..1) -> width of attack phase
    let d: Double  // decay time (0..1) -> width of decay phase
    let s: Double  // sustain level (0..1) -> height of sustain
    let r: Double  // release time (0..1) -> width of release phase

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let top = rect.minY + 2
        let bottom = rect.maxY

        // A, D, R are times -> they control segment widths proportionally
        // Reserve 15% of width for a minimum sustain hold segment
        let sustainHold = w * 0.15
        let available = w - sustainHold

        // Scale A, D, R widths proportionally. Each gets its fraction of the available space.
        // Use a minimum so even a 0-value param has a tiny visible segment.
        let rawA = max(a, 0.05)
        let rawD = max(d, 0.05)
        let rawR = max(r, 0.05)
        let total = rawA + rawD + rawR
        let attackW = (rawA / total) * available
        let decayW = (rawD / total) * available
        let releaseW = (rawR / total) * available

        // S is a level (amplitude) -> controls Y position
        let sustainY = top + (1.0 - s) * (bottom - top)

        var path = Path()
        let x0: Double = 0
        path.move(to: CGPoint(x: x0, y: bottom))

        // Attack: linear rise from bottom to peak
        let x1 = x0 + attackW
        path.addLine(to: CGPoint(x: x1, y: top))

        // Decay: linear fall from peak to sustain level
        let x2 = x1 + decayW
        path.addLine(to: CGPoint(x: x2, y: sustainY))

        // Sustain: flat hold at sustain level
        let x3 = x2 + sustainHold
        path.addLine(to: CGPoint(x: x3, y: sustainY))

        // Release: linear fall from sustain to zero
        let x4 = x3 + releaseW
        path.addLine(to: CGPoint(x: x4, y: bottom))

        // Close for fill
        path.addLine(to: CGPoint(x: x0, y: bottom))
        path.closeSubpath()

        return path
    }
}

// MARK: - X/Y Pad

struct XYPadControlView: View {
    @Binding var control: CCControl
    let onValueChange: (CCControl, UInt8) -> Void

    @State private var isDragging = false

    private let padSize: CGFloat = 130

    private var normX: CGFloat {
        CGFloat(control.currentValue) / 127.0
    }
    private var normY: CGFloat {
        CGFloat(control.yValue) / 127.0
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(control.label)
                .font(.system(.caption2))
                .lineLimit(2)

            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.4))
                    .frame(width: padSize, height: padSize)

                // Grid lines
                Path { path in
                    let mid = padSize / 2
                    path.move(to: CGPoint(x: mid, y: 0))
                    path.addLine(to: CGPoint(x: mid, y: padSize))
                    path.move(to: CGPoint(x: 0, y: mid))
                    path.addLine(to: CGPoint(x: padSize, y: mid))
                }
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
                .frame(width: padSize, height: padSize)

                // Crosshair position lines
                Path { path in
                    let x = normX * padSize
                    let y = (1 - normY) * padSize
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: padSize))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: padSize, y: y))
                }
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
                .frame(width: padSize, height: padSize)

                // Cursor dot
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: isDragging ? 12 : 8, height: isDragging ? 12 : 8)
                    .shadow(color: Color.accentColor.opacity(0.5), radius: isDragging ? 6 : 3)
                    .position(
                        x: normX * padSize,
                        y: (1 - normY) * padSize
                    )
                    .frame(width: padSize, height: padSize)
            }
            .frame(width: padSize, height: padSize)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let x = max(0, min(1, value.location.x / padSize))
                        let y = max(0, min(1, 1 - value.location.y / padSize))
                        let xVal = UInt8(clamping: Int(x * 127))
                        let yVal = UInt8(clamping: Int(y * 127))

                        if xVal != control.currentValue {
                            control.currentValue = xVal
                            onValueChange(control, xVal)
                        }
                        if yVal != control.yValue {
                            control.yValue = yVal
                            // Send Y axis as a separate CC
                            var yControl = control
                            yControl.ccNumber = control.yCCNumber
                            onValueChange(yControl, yVal)
                        }
                    }
                    .onEnded { _ in isDragging = false }
            )

            // Value labels
            HStack {
                Text("X:\(control.currentValue) CC\(control.ccNumber)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Y:\(control.yValue) CC\(control.yCCNumber)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
            .frame(width: padSize)
        }
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Knob Arc Shape

struct KnobArc: Shape {
    let normalized: Double

    private let startAngle: Double = 135
    private let totalSweep: Double = 270

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: min(rect.width, rect.height) / 2,
            startAngle: .degrees(startAngle),
            endAngle: .degrees(startAngle + totalSweep * normalized),
            clockwise: false
        )
        return path
    }
}
