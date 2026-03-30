import Foundation

enum CCControlType: String, Codable, CaseIterable {
    case knob
    case slider
    case button   // momentary: sends max on press, min on release
    case toggle   // latching: alternates between min and max
    case select   // dropdown with named options, each sends a CC value
    case adsr     // 4 params: attack, decay, sustain, release - each on its own CC
    case xyPad    // 2D pad controlling two CCs (X and Y axis)

    var icon: String {
        switch self {
        case .knob: "dial.low"
        case .slider: "slider.vertical.3"
        case .button: "button.vertical.right.press"
        case .toggle: "switch.2"
        case .select: "list.bullet"
        case .adsr: "waveform.path.ecg"
        case .xyPad: "square.grid.2x2"
        }
    }

    var displayName: String {
        switch self {
        case .adsr: "ADSR"
        case .xyPad: "X/Y Pad"
        default: rawValue.capitalized
        }
    }
}

struct SelectOption: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String
    var value: UInt8
}

enum CCMessageType: String, Codable, CaseIterable {
    case cc
    case nrpn
}

struct CCControl: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var type: CCControlType = .knob
    var label: String = "CC"
    var ccNumber: UInt8 = 1
    var minValue: UInt8 = 0
    var maxValue: UInt8 = 127
    var step: UInt8 = 1
    var currentValue: UInt8 = 0
    var groupID: UUID? = nil
    var isOn: Bool = false
    // For select type
    var options: [SelectOption] = []
    var selectedOptionID: UUID? = nil
    // For ADSR type: separate CC numbers and values for A, D, S, R
    var adsrCCs: [UInt8] = [73, 75, 70, 72]
    var adsrValues: [UInt8] = [20, 40, 80, 60]
    // X/Y pad: second CC for Y axis (ccNumber is X axis)
    var yCCNumber: UInt8 = 2
    var yValue: UInt8 = 64
    // NRPN support
    var messageType: CCMessageType = .cc
    var nrpnMSB: UInt8 = 0
    var nrpnLSB: UInt8 = 0
    var nrpnMaxValue: UInt16 = 127  // 127 for 7-bit, 16383 for 14-bit
}

struct CCGroup: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = "Group"
}

struct ControlLayout: Codable, Equatable {
    var controls: [CCControl] = []
    var groups: [CCGroup] = []
}
