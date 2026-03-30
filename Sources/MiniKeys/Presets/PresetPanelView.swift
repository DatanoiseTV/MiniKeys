import SwiftUI

struct PresetPanelView: View {
    @Bindable var presetManager: PresetManager
    @Binding var layout: ControlLayout

    @State private var showSaveDialog = false
    @State private var savePresetName = ""

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                if presetManager.presets.isEmpty {
                    Text("No saved presets")
                } else {
                    ForEach(presetManager.presets, id: \.self) { name in
                        Button(name) {
                            if let loaded = presetManager.load(name: name) {
                                layout = loaded
                            }
                        }
                    }
                    Divider()
                    Menu("Delete") {
                        ForEach(presetManager.presets, id: \.self) { name in
                            Button(name, role: .destructive) {
                                presetManager.delete(name: name)
                            }
                        }
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
            .help("Export preset to file")
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
    }
}
