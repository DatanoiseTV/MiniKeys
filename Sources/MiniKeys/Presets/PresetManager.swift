import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class PresetManager {
    var presets: [String] = []
    var currentPresetName: String? = nil

    private let presetsDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        presetsDirectory = appSupport.appendingPathComponent("MiniKeys/Presets", isDirectory: true)
        try? FileManager.default.createDirectory(at: presetsDirectory, withIntermediateDirectories: true)
        refreshPresets()
    }

    func refreshPresets() {
        let files = (try? FileManager.default.contentsOfDirectory(at: presetsDirectory, includingPropertiesForKeys: nil)) ?? []
        presets = files
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }

    func save(name: String, layout: ControlLayout) {
        let preset = Preset(name: name, layout: layout)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(preset) else { return }

        let url = presetsDirectory.appendingPathComponent("\(name).json")
        try? data.write(to: url, options: .atomic)
        currentPresetName = name
        refreshPresets()
    }

    func load(name: String) -> ControlLayout? {
        let url = presetsDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let preset = try? JSONDecoder().decode(Preset.self, from: data) else { return nil }
        currentPresetName = name
        return preset.layout
    }

    func delete(name: String) {
        let url = presetsDirectory.appendingPathComponent("\(name).json")
        try? FileManager.default.removeItem(at: url)
        if currentPresetName == name { currentPresetName = nil }
        refreshPresets()
    }

    func exportPreset(layout: ControlLayout, name: String) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(name).json"
        panel.title = "Export Preset"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let preset = Preset(name: name, layout: layout)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(preset) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func importPreset() -> ControlLayout? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.title = "Import Preset"

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let preset = try? JSONDecoder().decode(Preset.self, from: data) else { return nil }

        save(name: preset.name, layout: preset.layout)
        return preset.layout
    }
}
