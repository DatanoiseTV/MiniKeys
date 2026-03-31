import Foundation
import Observation

/// A single mapping from a macro to a CC destination.
/// When the macro moves from 0-127, the destination CC moves
/// from destMin to destMax (or reversed if inverted).
struct MacroMapping: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var destCCNumber: UInt8 = 1
    var destMin: UInt8 = 0
    var destMax: UInt8 = 127
    var curve: MacroCurve = .linear

    /// Map a macro value (0-127) to the destination range
    func mapValue(_ macroValue: UInt8) -> UInt8 {
        let norm = Double(macroValue) / 127.0
        let curved: Double
        switch curve {
        case .linear: curved = norm
        case .exponential: curved = norm * norm
        case .logarithmic: curved = sqrt(norm)
        case .sCurve: curved = norm * norm * (3.0 - 2.0 * norm)
        case .inverted: curved = 1.0 - norm
        }
        let range = Double(destMax) - Double(destMin)
        return UInt8(clamping: Int(Double(destMin) + curved * range))
    }
}

enum MacroCurve: String, Codable, CaseIterable {
    case linear, exponential, logarithmic, sCurve, inverted

    var displayName: String {
        switch self {
        case .linear: "Linear"
        case .exponential: "Exp"
        case .logarithmic: "Log"
        case .sCurve: "S-Curve"
        case .inverted: "Invert"
        }
    }
}

/// A macro control that drives multiple CC destinations simultaneously.
struct MacroControl: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = "Macro"
    var value: UInt8 = 64
    var mappings: [MacroMapping] = []
    var color: MacroColor = .blue

    /// Morph targets: save two states and blend between them
    var morphA: UInt8 = 0
    var morphB: UInt8 = 127
}

enum MacroColor: String, Codable, CaseIterable {
    case blue, purple, orange, green, red, yellow

    var displayName: String { rawValue.capitalized }
}

@Observable
final class MacroEngine {
    var macros: [MacroControl] = []
    var onSendCC: ((UInt8, UInt8, UInt8) -> Void)?  // (cc, value, channel)

    func addMacro() {
        let idx = macros.count + 1
        macros.append(MacroControl(label: "Macro \(idx)"))
    }

    func removeMacro(_ id: UUID) {
        macros.removeAll { $0.id == id }
    }

    /// Update a macro's value and send all mapped CCs
    func setMacroValue(_ macroID: UUID, value: UInt8, channel: UInt8) {
        guard let idx = macros.firstIndex(where: { $0.id == macroID }) else { return }
        macros[idx].value = value

        for mapping in macros[idx].mappings {
            let destValue = mapping.mapValue(value)
            onSendCC?(mapping.destCCNumber, destValue, channel)
        }
    }

    /// Morph: interpolate between morphA and morphB positions
    func morphTo(_ macroID: UUID, position: Double, channel: UInt8) {
        guard let idx = macros.firstIndex(where: { $0.id == macroID }) else { return }
        let a = Double(macros[idx].morphA)
        let b = Double(macros[idx].morphB)
        let value = UInt8(clamping: Int(a + (b - a) * position))
        setMacroValue(macroID, value: value, channel: channel)
    }

    /// Save current macro value as morph point A
    func saveMorphA(_ macroID: UUID) {
        guard let idx = macros.firstIndex(where: { $0.id == macroID }) else { return }
        macros[idx].morphA = macros[idx].value
    }

    /// Save current macro value as morph point B
    func saveMorphB(_ macroID: UUID) {
        guard let idx = macros.firstIndex(where: { $0.id == macroID }) else { return }
        macros[idx].morphB = macros[idx].value
    }
}
