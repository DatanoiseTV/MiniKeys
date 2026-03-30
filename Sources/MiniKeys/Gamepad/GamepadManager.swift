import GameController
import Foundation
import Observation

struct GamepadBinding: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var axisName: String          // e.g. "leftThumbstickX", "rightTrigger"
    var controlID: UUID?          // bound CC control ID
    var controlLabel: String = "" // for display
    var inverted: Bool = false
    var deadzone: Double = 0.1
}

@Observable
final class GamepadManager {
    var connectedGamepads: [GCController] = []
    var selectedGamepadIndex: Int? = nil
    var bindings: [GamepadBinding] = []
    var isActive = false

    // Callback: (controlID, value 0-127)
    var onAxisChange: ((UUID, UInt8) -> Void)?

    private var pollTimer: DispatchSourceTimer?
    private let pollQueue = DispatchQueue(label: "com.minikeys.gamepad", qos: .userInteractive)

    init() {
        setupNotifications()
        refreshGamepads()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshGamepads()
        }
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshGamepads()
        }
    }

    func refreshGamepads() {
        connectedGamepads = GCController.controllers()
        if let idx = selectedGamepadIndex, idx >= connectedGamepads.count {
            selectedGamepadIndex = connectedGamepads.isEmpty ? nil : 0
        }
    }

    var selectedGamepad: GCController? {
        guard let idx = selectedGamepadIndex, idx < connectedGamepads.count else { return nil }
        return connectedGamepads[idx]
    }

    /// Available axes on the selected gamepad
    var availableAxes: [String] {
        guard let pad = selectedGamepad?.extendedGamepad else {
            // Try micro gamepad
            if let micro = selectedGamepad?.microGamepad {
                return ["dpadX", "dpadY", "buttonA", "buttonX"]
            }
            return []
        }

        var axes: [String] = []
        axes.append(contentsOf: ["leftThumbstickX", "leftThumbstickY"])
        axes.append(contentsOf: ["rightThumbstickX", "rightThumbstickY"])
        axes.append(contentsOf: ["leftTrigger", "rightTrigger"])
        axes.append(contentsOf: ["dpadX", "dpadY"])
        // Shoulder buttons as axes (0 or 1)
        axes.append(contentsOf: ["leftShoulder", "rightShoulder"])
        axes.append(contentsOf: ["buttonA", "buttonB", "buttonX", "buttonY"])
        return axes
    }

    func startPolling() {
        stopPolling()
        guard isActive else { return }

        let timer = DispatchSource.makeTimerSource(queue: pollQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(8)) // ~120Hz
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.poll()
            }
        }
        timer.resume()
        pollTimer = timer
    }

    func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func poll() {
        guard isActive, let pad = selectedGamepad?.extendedGamepad else { return }

        for binding in bindings {
            guard let controlID = binding.controlID else { continue }

            let rawValue = readAxis(name: binding.axisName, pad: pad)
            guard let raw = rawValue else { continue }

            // Apply deadzone
            var value = raw
            if abs(value) < Float(binding.deadzone) { value = 0 }

            // Invert
            if binding.inverted { value = -value }

            // Map from -1..1 or 0..1 to 0..127
            let midi: UInt8
            if isButtonAxis(binding.axisName) {
                // Buttons: 0 or 1 -> 0 or 127
                midi = value > 0.5 ? 127 : 0
            } else if isTriggerAxis(binding.axisName) {
                // Triggers: 0..1 -> 0..127
                midi = UInt8(clamping: Int(value * 127))
            } else {
                // Sticks/dpad: -1..1 -> 0..127
                midi = UInt8(clamping: Int((value + 1) / 2.0 * 127))
            }

            onAxisChange?(controlID, midi)
        }
    }

    private func readAxis(name: String, pad: GCExtendedGamepad) -> Float? {
        switch name {
        case "leftThumbstickX": return pad.leftThumbstick.xAxis.value
        case "leftThumbstickY": return pad.leftThumbstick.yAxis.value
        case "rightThumbstickX": return pad.rightThumbstick.xAxis.value
        case "rightThumbstickY": return pad.rightThumbstick.yAxis.value
        case "leftTrigger": return pad.leftTrigger.value
        case "rightTrigger": return pad.rightTrigger.value
        case "dpadX": return pad.dpad.xAxis.value
        case "dpadY": return pad.dpad.yAxis.value
        case "leftShoulder": return pad.leftShoulder.value
        case "rightShoulder": return pad.rightShoulder.value
        case "buttonA": return pad.buttonA.value
        case "buttonB": return pad.buttonB.value
        case "buttonX": return pad.buttonX.value
        case "buttonY": return pad.buttonY.value
        default: return nil
        }
    }

    private func isButtonAxis(_ name: String) -> Bool {
        ["buttonA", "buttonB", "buttonX", "buttonY", "leftShoulder", "rightShoulder"].contains(name)
    }

    private func isTriggerAxis(_ name: String) -> Bool {
        ["leftTrigger", "rightTrigger"].contains(name)
    }

    func addBinding(axis: String) {
        bindings.append(GamepadBinding(axisName: axis))
    }

    func removeBinding(_ id: UUID) {
        bindings.removeAll { $0.id == id }
    }
}
