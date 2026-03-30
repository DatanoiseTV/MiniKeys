import Foundation

struct Preset: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var layout: ControlLayout

    // Migration: decode old presets that only had knobs
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        if let layout = try? container.decode(ControlLayout.self, forKey: .layout) {
            self.layout = layout
        } else if let knobs = try? container.decode([CCKnobConfig].self, forKey: .knobs) {
            // Migrate old knob-only presets
            self.layout = ControlLayout(
                controls: knobs.map { knob in
                    CCControl(
                        id: knob.id, type: .knob, label: knob.label,
                        ccNumber: knob.ccNumber, minValue: knob.minValue,
                        maxValue: knob.maxValue, step: knob.step,
                        currentValue: knob.currentValue
                    )
                }
            )
        } else {
            self.layout = ControlLayout()
        }
    }

    init(name: String, layout: ControlLayout) {
        self.name = name
        self.layout = layout
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, layout, knobs
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(layout, forKey: .layout)
    }
}

// Keep for migration
struct CCKnobConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var label: String = "CC"
    var ccNumber: UInt8 = 1
    var minValue: UInt8 = 0
    var maxValue: UInt8 = 127
    var step: UInt8 = 1
    var currentValue: UInt8 = 64
}
