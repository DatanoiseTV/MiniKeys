# MiniKeys

A macOS-native virtual MIDI keyboard and controller prototyping tool. MiniKeys presents itself as a virtual MIDI output visible to any DAW or synthesizer, while also supporting direct output to system MIDI destinations. It includes an Ableton-style computer keyboard layout, configurable CC controls, an arpeggiator, chord mode, metronome, live quantizer, scale enforcement, and a device preset browser with 300+ hardware synth MIDI mappings.

## Screenshots

<img width="1256" height="803" alt="Screenshot 2026-03-30 at 22 05 17" src="https://github.com/user-attachments/assets/0e48c37e-8321-44ba-8fb9-0b26f0124c81" />
<img width="1256" height="803" alt="Screenshot 2026-03-30 at 22 06 25" src="https://github.com/user-attachments/assets/053d8147-0a7d-46b6-b117-1af6e4a6f4e3" />
<img width="1256" height="803" alt="Screenshot 2026-03-30 at 22 07 07" src="https://github.com/user-attachments/assets/0f2d4f9c-89c6-49da-895b-3048b2cc9bbe" />

## Features

### Virtual MIDI Keyboard
- Computer keyboard mapping: middle row (A-L) plays white keys, upper row (W/E/T/U/O/P) plays black keys
- Mouse/trackpad playable with click-and-drag across keys
- Ghost octaves on each side for visual context
- Y/X for octave down/up, C/V for velocity, Left Shift for sustain
- Uses hardware scancodes, so key mapping works regardless of keyboard layout (US, DE, etc.)
- Creates a "MiniKeys" virtual MIDI source visible to all apps
- Optional direct output to any system MIDI destination
- MIDI input from external devices (routes through arp/chord/quantizer)
- Channel selection (1-16)

### CC Control Surface
- Knobs, sliders, buttons (momentary), toggles (latching), select (segmented pills), ADSR envelopes, and X/Y pads
- All controls support CC and NRPN (7-bit and 14-bit)
- Wrapping flow layout with zoom controls
- Grouping: select multiple controls and group them into labeled containers
- Inline property editor: type, label, CC number, min/max/step, group assignment
- Edit mode with pencil toggle; controls are non-interactive in edit mode for easy selection
- Right-click to delete controls

### Arpeggiator
- Modes: Up, Down, Up-Down, Down-Up, Random, As Played
- Note priority: Sorted (by pitch), Newest, Oldest (backed by a proper notestack implementation)
- BPM with metronome sync
- Note divisions: 1/1 through 1/32, dotted and triplet variants
- Gate length slider (5-100%)
- Octave range (1-4 octaves)
- Swing control
- Hold mode: arpeggio continues after all keys are released
- 16-step gate pattern sequencer: click steps to cycle On/Accent/Tie/Off, right-click for direct selection, configurable length (4/8/12/16)

### Chord Mode
- 16 chord types: Major, Minor, Sus2, Sus4, Dim, Aug, 7, Maj7, Min7, mMaj7, Dim7, m7b5, Aug7, Add9, mAdd9, Power (5th)
- Inversion control (root through third inversion)
- Visual feedback: chord notes highlighted on the keyboard
- Mutually exclusive with arpeggiator (toggling one disables the other)

### Metronome
- Audio click via AVAudioEngine (accented downbeat)
- Configurable time signature (2/4 through 7/4)
- Volume control
- Visual beat indicator
- Shared master clock: arpeggiator syncs to metronome grid when both are active
- Runs on a background dispatch queue so UI interactions never block timing

### Live Quantizer
- Grid divisions: 1/4, 1/8, 1/16, 1/32, dotted variants, triplet variants
- Strength control (0-100%): how hard notes snap to the grid
- Optional note-off quantization
- Uses high-precision monotonic clock (ProcessInfo.systemUptime)

### Scale Engine
- 16 scales: Chromatic, Major, Minor, Harmonic Minor, Melodic Minor, Dorian, Phrygian, Lydian, Mixolydian, Locrian, Pentatonic Major/Minor, Blues, Whole Tone, Diminished, Augmented
- 12 root notes
- Force modes: Off (visual only), Filter (block out-of-scale), Snap Up, Snap Down, Snap Nearest
- Out-of-scale keys shown with dimmed labels on the keyboard

### Device Preset Browser
- Fetches MIDI CC and NRPN mappings from [pencilresearch/midi](https://github.com/pencilresearch/midi) (300+ devices, 90+ manufacturers)
- Three-column Finder-style browser: Manufacturer, Device, Parameter preview
- Search across manufacturers and devices
- Toggle between CC and NRPN output per device
- Automatic update checking via git remote comparison
- Loading a device preset auto-generates a full control layout with groups (from the device's parameter sections), knobs, toggles, and selects as appropriate
- Loaded device presets are saved to the user's preset library

### Presets
- Save and load CC control layouts as named presets
- Stored in `~/Library/Application Support/MiniKeys/Presets/` as JSON
- Import/export to arbitrary file locations
- Preset dropdown in the toolbar with delete support

## Building

Requires macOS 14 (Sonoma) or later and Swift 5.10+.

```
git clone git@github.com:DatanoiseTV/MiniKeys.git
cd MiniKeys
./build.sh
open MiniKeys.app
```

The build script compiles a release binary with `swift build`, creates a `.app` bundle with the included Info.plist, and ad-hoc signs it.

For development:

```
swift build
.build/debug/MiniKeys
```

## Architecture

```
Sources/MiniKeys/
  App/            Entry point, main window, content view
  MIDI/           CoreMIDI engine (virtual source, output port, input port, NRPN)
  Keyboard/       Key mapping, keyboard state, input monitoring, keyboard view
  CC/             Control model, control views (knob/slider/button/toggle/select/ADSR/XY),
                  panel layout, flow layout, inline editor
  Musical/        Arpeggiator, chord engine, metronome, live quantizer,
                  scale engine, notestack
  Presets/        Preset model, preset manager, preset panel view
  DeviceDB/       Device database manager, CSV parser, browser view
```

The notestack supports push-top, push-bottom, sorted, and hold variants for proper note priority handling in the arpeggiator.

Timing-critical code (arpeggiator steps, metronome clicks, gate-off events) runs on dedicated background dispatch queues to avoid blocking during UI interaction. MIDI send functions are nonisolated and thread-safe.

## License

MIT
