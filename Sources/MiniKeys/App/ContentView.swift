import CoreMIDI
import SwiftUI

struct ContentView: View {
    @Environment(MIDIEngine.self) private var midiEngine
    @Environment(KeyboardState.self) private var keyboardState

    @State private var layout = ControlLayout()
    @State private var presetManager = PresetManager()
    @State private var dbManager = DeviceDBManager()
    @State private var gamepadManager = GamepadManager()
    @State private var keyboardMonitor: KeyboardMonitor?
    @State private var showDeviceBrowser = false

    var body: some View {
        @Bindable var engine = midiEngine

        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 12) {
                HStack(spacing: 4) {
                    Image(systemName: "cable.connector")
                        .foregroundStyle(.secondary)
                    Picker("", selection: $engine.selectedDestinationID) {
                        Text("Virtual Output Only")
                            .tag(nil as MIDIEndpointRef?)
                        if !midiEngine.destinations.isEmpty {
                            Divider()
                            ForEach(midiEngine.destinations) { dest in
                                Text(dest.name).tag(dest.id as MIDIEndpointRef?)
                            }
                        }
                    }
                    .frame(minWidth: 180)
                }

                HStack(spacing: 4) {
                    Text("Ch")
                        .font(.system(.caption))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $engine.channel) {
                        ForEach(0..<16, id: \.self) { ch in
                            Text("\(ch + 1)").tag(UInt8(ch))
                        }
                    }
                    .frame(width: 60)
                }

                // MIDI Input
                HStack(spacing: 4) {
                    Image(systemName: "pianokeys.inverse")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 10))
                    Picker("", selection: $engine.selectedSourceID) {
                        Text("No Input")
                            .tag(nil as MIDIEndpointRef?)
                        if !midiEngine.sources.isEmpty {
                            Divider()
                            ForEach(midiEngine.sources) { src in
                                Text(src.name).tag(src.id as MIDIEndpointRef?)
                            }
                        }
                    }
                    .frame(minWidth: 100)
                }

                Button(action: { showDeviceBrowser = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pianokeys")
                        Text("Devices")
                            .font(.system(.caption))
                    }
                }
                .help("Browse device MIDI mappings")

                Spacer()

                Button(action: { keyboardState.allNotesOff() }) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Panic — all notes off")

                PresetPanelView(presetManager: presetManager, layout: $layout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // CC Panel
            CCPanelView(layout: $layout) { control, value in
                sendControlValue(control: control, value: value)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Keyboard
            KeyboardView(
                pressedKeys: keyboardState.pressedKeys,
                mouseNote: keyboardState.mouseNote,
                chordNotes: keyboardState.chordEngine.allSoundingNotes,
                scaleNotes: keyboardState.scaleEngine.scaleNotes,
                octave: keyboardState.octave,
                velocity: keyboardState.velocity,
                sustainActive: keyboardState.sustainActive,
                onMouseNote: { offset in keyboardState.mouseNoteOn(semitoneOffset: offset) },
                onMouseNoteOff: { keyboardState.mouseNoteOff() }
            )
            .padding(12)

            // Musical tools below keyboard
            MusicalToolsView(
                arpeggiator: keyboardState.arpeggiator,
                chordEngine: keyboardState.chordEngine,
                metronome: keyboardState.metronome,
                quantizer: keyboardState.quantizer,
                scaleEngine: keyboardState.scaleEngine,
                gamepadManager: gamepadManager,
                controls: layout.controls,
                onModeChange: { keyboardState.allNotesOff() }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
        .frame(minWidth: 700)
        .background(Color(nsColor: .underPageBackgroundColor))
        .onAppear {
            let monitor = KeyboardMonitor(keyboardState: keyboardState)
            monitor.start()
            keyboardMonitor = monitor

            // Wire gamepad axis changes to CC controls
            gamepadManager.onAxisChange = { [self] controlID, value in
                if let idx = layout.controls.firstIndex(where: { $0.id == controlID }) {
                    layout.controls[idx].currentValue = value
                    sendControlValue(control: layout.controls[idx], value: value)
                }
            }

            // Wire incoming MIDI CC to update on-screen controls (bidirectional feedback)
            midiEngine.onExternalCC = { [self] (cc: UInt8, value: UInt8) in
                updateControlFromMIDI(cc: cc, value: value)
            }

            // Wire incoming NRPN to update NRPN-mode controls
            midiEngine.onExternalNRPN = { [self] (msb: UInt8, lsb: UInt8, value: UInt8) in
                for i in layout.controls.indices {
                    if layout.controls[i].messageType == .nrpn
                        && layout.controls[i].nrpnMSB == msb
                        && layout.controls[i].nrpnLSB == lsb {
                        layout.controls[i].currentValue = value
                    }
                }
            }
        }
        .onDisappear {
            keyboardMonitor?.stop()
            keyboardMonitor = nil
            gamepadManager.stopPolling()
        }
        .sheet(isPresented: $showDeviceBrowser) {
            DeviceBrowserView(dbManager: dbManager) { deviceLayout, deviceName in
                layout = deviceLayout
                presetManager.save(name: deviceName, layout: deviceLayout)
            }
        }
    }

    /// Update on-screen controls when MIDI CC is received from external input
    @MainActor private func updateControlFromMIDI(cc: UInt8, value: UInt8) {
        // Update all controls that match this CC number
        for i in layout.controls.indices {
            let control = layout.controls[i]

            // Standard CC match
            if control.messageType == .cc && control.ccNumber == cc {
                switch control.type {
                case .knob, .slider:
                    layout.controls[i].currentValue = value
                case .toggle:
                    layout.controls[i].isOn = value >= 64
                    layout.controls[i].currentValue = value >= 64 ? control.maxValue : control.minValue
                case .button:
                    layout.controls[i].currentValue = value
                case .select:
                    // Find the closest option
                    if let closest = control.options.min(by: {
                        abs(Int($0.value) - Int(value)) < abs(Int($1.value) - Int(value))
                    }) {
                        layout.controls[i].selectedOptionID = closest.id
                        layout.controls[i].currentValue = closest.value
                    }
                case .xyPad:
                    // X axis
                    layout.controls[i].currentValue = value
                case .adsr:
                    // Match individual ADSR CCs
                    for p in 0..<4 {
                        if control.adsrCCs[p] == cc {
                            layout.controls[i].adsrValues[p] = value
                        }
                    }
                }
            }

            // X/Y pad Y axis
            if control.type == .xyPad && control.yCCNumber == cc {
                layout.controls[i].yValue = value
            }
        }
    }

    @MainActor private func sendControlValue(control: CCControl, value: UInt8) {
        switch control.messageType {
        case .nrpn:
            if control.nrpnMaxValue > 127 {
                let scaled = UInt16(Double(value) / 127.0 * Double(control.nrpnMaxValue))
                midiEngine.sendNRPN(msb: control.nrpnMSB, lsb: control.nrpnLSB, value: scaled, channel: midiEngine.channel)
            } else {
                midiEngine.sendNRPN7(msb: control.nrpnMSB, lsb: control.nrpnLSB, value: value, channel: midiEngine.channel)
            }
        case .cc:
            midiEngine.sendCC(controller: control.ccNumber, value: value, channel: midiEngine.channel)
        }
    }
}
