import SwiftUI

struct PresetPanelView: View {
    @Bindable var presetManager: PresetManager
    @Binding var layout: ControlLayout

    @State private var showSaveDialog = false
    @State private var savePresetName = ""
    @State private var showExportCSV = false
    @State private var exportManufacturer = ""
    @State private var exportDevice = ""
    @State private var presetToDelete: String? = nil
    @State private var showDeleteConfirm = false
    @State private var skipDeleteConfirm = false

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                layout = ControlLayout()
                presetManager.currentPresetName = nil
            }) {
                Image(systemName: "doc.badge.plus")
            }
            .buttonStyle(.plain)
            .help("New empty preset")

            Menu {
                if presetManager.presets.isEmpty {
                    Text("No saved presets")
                } else {
                    ForEach(presetManager.presets, id: \.self) { name in
                        PresetMenuRow(name: name, onLoad: {
                            if let loaded = presetManager.load(name: name) {
                                layout = loaded
                            }
                        }, onDelete: {
                            if skipDeleteConfirm {
                                presetManager.delete(name: name)
                            } else {
                                presetToDelete = name
                                showDeleteConfirm = true
                            }
                        })
                    }
                }
                Divider()
                Button("Import...") {
                    if let imported = presetManager.importPreset() {
                        layout = imported
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.plaintext")
                    Text(presetManager.currentPresetName ?? "Presets")
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 100)

            Button(action: { showSaveDialog = true }) {
                Image(systemName: "square.and.arrow.down")
            }
            .help("Save preset")

            Button(action: {
                presetManager.exportPreset(
                    layout: layout,
                    name: presetManager.currentPresetName ?? "Untitled"
                )
            }) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Export preset as JSON")

            Button(action: { showExportCSV = true }) {
                Image(systemName: "tablecells")
            }
            .help("Export as MIDI mapping CSV (pencilresearch format)")
        }
        .alert("Save Preset", isPresented: $showSaveDialog) {
            TextField("Preset name", text: $savePresetName)
            Button("Save") {
                guard !savePresetName.isEmpty else { return }
                presetManager.save(name: savePresetName, layout: layout)
                savePresetName = ""
            }
            Button("Cancel", role: .cancel) { savePresetName = "" }
        } message: {
            Text("Enter a name for this preset")
        }
        .alert("Export MIDI Mapping", isPresented: $showExportCSV) {
            TextField("Manufacturer", text: $exportManufacturer)
            TextField("Device name", text: $exportDevice)
            Button("Export") {
                guard !exportManufacturer.isEmpty, !exportDevice.isEmpty else { return }
                DeviceExporter.saveCSV(
                    layout: layout,
                    manufacturer: exportManufacturer,
                    device: exportDevice
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter manufacturer and device name for the CSV export")
        }
        .alert("Delete Preset", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let name = presetToDelete {
                    presetManager.delete(name: name)
                    presetToDelete = nil
                }
            }
            Button("Delete (Don't ask again)", role: .destructive) {
                if let name = presetToDelete {
                    presetManager.delete(name: name)
                    presetToDelete = nil
                    skipDeleteConfirm = true
                }
            }
            Button("Cancel", role: .cancel) { presetToDelete = nil }
        } message: {
            Text("Delete \"\(presetToDelete ?? "")\"? This cannot be undone.")
        }
    }
}

// MARK: - Preset Menu Row with hover delete

struct PresetMenuRow: View {
    let name: String
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onLoad) {
            HStack {
                Text(name)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
