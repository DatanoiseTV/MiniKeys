# MiniKeys

A virtual MIDI keyboard and controller builder for macOS. Play notes with your computer keyboard or mouse, build custom CC control surfaces, and route everything through an arpeggiator, chord engine, quantizer, or scale filter before it hits your DAW or synth.

MiniKeys shows up as a virtual MIDI source that any app can see. It also supports direct output to hardware MIDI devices and can receive MIDI input from external keyboards and controllers.

## Screenshots
<img width="1028" height="954" alt="Screenshot 2026-03-31 at 01 44 50" src="https://github.com/user-attachments/assets/ca6d1589-19fd-4d51-a4c6-7dfdf8ff8abd" />
<img width="1028" height="954" alt="Screenshot 2026-03-31 at 01 45 17" src="https://github.com/user-attachments/assets/4acc3df1-43f3-426c-bd0a-8effd3e79909" />
<img width="923" height="463" alt="Screenshot 2026-03-31 at 02 28 22" src="https://github.com/user-attachments/assets/174fe0aa-4244-4621-8081-fa62b154ec18" />

## Getting Started

Download the latest build from [Releases](https://github.com/DatanoiseTV/MiniKeys/releases), unzip, and open `MiniKeys.app`. Requires macOS 14 (Sonoma) or later. Universal binary -- runs natively on both Apple Silicon and Intel.

Since the app is not notarized, macOS will quarantine it on first launch. Remove the quarantine flag before opening:

```
xattr -cr MiniKeys.app
open MiniKeys.app
```

Or build from source:

```
git clone https://github.com/DatanoiseTV/MiniKeys.git
cd MiniKeys
./build.sh
open MiniKeys.app
```

## Keyboard

The middle row of your keyboard (A through L and ; ') plays white keys. The upper row (W, E, T, U, O, P) plays sharps and flats. This uses hardware scancodes, so it works the same regardless of your keyboard layout (US, German, French, etc.).

| Key | Function |
|-----|----------|
| A S D F G H J K L ; ' | White keys (C D E F G A B C D E F) |
| W E T U O P | Black keys (C# D# F# A# C# D#) |
| Y | Octave down |
| X | Octave up |
| C / V | Velocity down / up |
| Z | Sustain (hold) |

You can also click and drag across the on-screen piano with your mouse or trackpad. Ghost octaves on each side show the surrounding notes for context.

Clicking anywhere outside a text field returns keyboard focus to the piano, so you can immediately play after editing a control.

## CC Control Surface

Build custom MIDI controller layouts with these widget types:

- **Knobs** -- rotary controls, drag vertically to change
- **Sliders** -- vertical faders
- **Buttons** -- momentary, sends a value on press and releases on mouse-up
- **Toggles** -- latching on/off switches
- **Select** -- pill buttons for few options, dropdown menu for many (waveform lists, filter types, etc.)
- **ADSR** -- four-parameter envelope with linear visual display
- **X/Y Pad** -- two-dimensional control surface sending two CCs simultaneously

All controls support both standard MIDI CC and NRPN (7-bit and 14-bit). Controls wrap to fit the window width automatically.

Click **Edit** to enter edit mode, where you can add, configure, delete, multi-select, and group controls into labeled sections. In edit mode, clicking a control selects it for editing rather than changing its value. The inline editor lets you change the control type, label, CC number, NRPN settings, min/max/step, and group assignment.

### Snapshots

Save the current state of all control values as a named snapshot using the camera icon in the CC Controls header. Recall any saved snapshot to restore all knob positions, toggle states, and selections instantly. Useful for comparing parameter settings or quickly switching between sound variations without changing the control layout.

### Undo / Redo

In edit mode, undo and redo arrows appear in the CC Controls header. Adding controls, deleting controls or groups, and loading snapshots are all tracked in a 50-step undo history.

### Presets

Save and load entire control layouts (including groups, control types, and configurations) as named presets. Presets are stored as JSON in `~/Library/Application Support/MiniKeys/Presets/`. Import and export presets to share them.

### Bidirectional MIDI Feedback

Incoming CC and NRPN messages from external MIDI input automatically update the corresponding on-screen controls. Move a knob on your hardware and the on-screen knob follows. This works for all control types -- knobs, sliders, toggles, selects, X/Y pads, and ADSR envelopes.

## Device Preset Browser

MiniKeys can fetch MIDI CC and NRPN mappings for 300+ hardware synthesizers and effects from 90+ manufacturers. Open the device browser from the toolbar, pick your manufacturer and device in the three-column Finder-style browser, and load a ready-made control surface with all parameters organized into groups.

You can choose between CC and NRPN output per device. Loaded device presets are automatically saved to your preset library. The browser checks for database updates and lets you pull new device mappings with one click.

Device mappings are sourced from [pencilresearch/midi](https://github.com/pencilresearch/midi).

## Musical Tools

The tools bar below the keyboard gives you quick access to six processing modules. Each tool has a toggle switch to enable/disable it and a clickable pill to expand its settings. Only one tool's settings are shown at a time to keep the interface compact.

### Metronome

Audio click with configurable BPM, time signature (2/4 to 7/4), and volume. A visual beat indicator shows the current beat. The metronome provides a shared master clock -- the arpeggiator syncs to its grid when both are active.

BPM can be set by typing a value, dragging the BPM display up/down, or using the tap tempo button. Tap tempo averages your last 12 taps with recent taps weighted more heavily, and waits for 3 taps before committing a value.

### Live Quantizer

Snaps your playing to a rhythmic grid in real time. Choose a grid division (1/4 to 1/32, with dotted and triplet options) and a strength amount. At 100% strength, notes snap exactly to the grid. At lower values, they're nudged toward it. Optionally quantize note-off events as well.

### Scale Engine

Constrain your playing to a specific scale and key. 16 scales (Major, Minor, Harmonic Minor, Melodic Minor, Dorian, Phrygian, Lydian, Mixolydian, Locrian, Pentatonic Major/Minor, Blues, Whole Tone, Diminished, Augmented) and 12 root notes. Choose how out-of-scale notes are handled:

- **Off** -- scale is shown visually but all notes play normally
- **Filter** -- out-of-scale notes are blocked
- **Snap Up / Down / Nearest** -- out-of-scale notes are redirected to the closest in-scale note

Out-of-scale keys are shown with dimmed labels on the keyboard.

### Arpeggiator

Hold one or more keys and the arpeggiator plays them back as a pattern.

- **Modes**: Up, Down, Up-Down, Down-Up, Random, As Played
- **Note priority**: Sorted by pitch, Newest first, or Oldest first
- **Timing**: BPM (syncs to metronome), note division (1/1 to 1/32, dotted, triplet), swing
- **Gate**: adjustable note length from 5% to 100%
- **Octave range**: spread the pattern across 1 to 4 octaves
- **Hold**: keep the pattern running after you release all keys
- **Gate pattern**: a 16-step sequencer where each step can be On, Accent, Tie, or Off. Click a step to cycle through states, right-click to pick directly. Configurable length (4, 8, 12, or 16 steps).

The arpeggiator uses a proper notestack implementation with push-top, push-bottom, sorted, and hold variants for correct note priority handling.

### Chord Mode

Press a single key and MiniKeys plays a full chord. 16 chord types: Major, Minor, Sus2, Sus4, Dim, Aug, 7, Maj7, Min7, mMaj7, Dim7, m7b5, Aug7, Add9, mAdd9, Power (5th). Inversions from root through third. Chord notes are highlighted on the keyboard in a subtle color so you can see what's playing.

Arpeggiator and chord mode are mutually exclusive -- enabling one disables the other.

### Gamepad

Map gamepad axes and buttons to CC controls. Connect a PS, Xbox, Switch Pro, or any MFi/HID gamepad and bind its sticks, triggers, d-pad, shoulders, and face buttons to any control in your layout. Each binding has configurable deadzone and invert settings. Polling runs at 120Hz on a background thread.

## MIDI Input / Output

- **Virtual output**: MiniKeys creates a "MiniKeys" virtual MIDI source visible to all apps on the system
- **Direct output**: optionally send to any connected hardware MIDI destination
- **Input**: select an external MIDI source to receive notes and CCs. Incoming notes pass through the full processing chain (arpeggiator, chord mode, quantizer, scale engine)
- **Channel**: selectable MIDI channel (1-16) for all output
- **Panic**: the panic button in the toolbar sends all-notes-off and sustain-off immediately

## Architecture

```
Sources/MiniKeys/
  App/            Entry point, main window
  MIDI/           CoreMIDI (virtual source, output, input, NRPN)
  Keyboard/       Key mapping, state, input monitoring, piano view
  CC/             Control types, views, panel layout, inline editor,
                  snapshots, undo/redo
  Musical/        Arpeggiator, chords, metronome, quantizer, scales, notestack
  Gamepad/        GameController framework, axis bindings
  Presets/        Save/load/import/export
  DeviceDB/       Device database, CSV parser, browser
```

Timing-critical paths (arpeggiator, metronome, gate events) run on dedicated background dispatch queues so UI interaction never disrupts playback. MIDI send functions are thread-safe and called directly from timer queues without main thread involvement.

## License

MIT
