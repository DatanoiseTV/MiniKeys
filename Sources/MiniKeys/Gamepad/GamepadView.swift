import SwiftUI

struct GamepadView: View {
    @Bindable var gamepadManager: GamepadManager
    let controls: [CCControl]

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                // Header
                HStack(spacing: 8) {
                    Toggle("Gamepad", isOn: $gamepadManager.isActive)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.system(.caption).bold())
                        .onChange(of: gamepadManager.isActive) { _, on in
                            if on { gamepadManager.startPolling() }
                            else { gamepadManager.stopPolling() }
                        }

                    if gamepadManager.isActive {
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
                }

                // Bindings
                if gamepadManager.isActive && !gamepadManager.connectedGamepads.isEmpty {
                    if gamepadManager.bindings.isEmpty {
                        HStack {
                            Text("No bindings. Add an axis to map it to a CC control.")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    ForEach($gamepadManager.bindings) { $binding in
                        GamepadBindingRow(
                            binding: $binding,
                            availableAxes: gamepadManager.availableAxes,
                            controls: controls,
                            onDelete: { gamepadManager.removeBinding(binding.id) }
                        )
                    }

                    // Add binding
                    Menu {
                        ForEach(gamepadManager.availableAxes, id: \.self) { axis in
                            Button(axis) {
                                gamepadManager.addBinding(axis: axis)
                            }
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
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }
            }
        }
    }
}

struct GamepadBindingRow: View {
    @Binding var binding: GamepadBinding
    let availableAxes: [String]
    let controls: [CCControl]
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Axis picker
            Picker("", selection: $binding.axisName) {
                ForEach(availableAxes, id: \.self) { axis in
                    Text(axis).tag(axis)
                }
            }
            .frame(width: 130)

            Image(systemName: "arrow.right")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            // Target CC control picker
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
