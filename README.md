# MiniKeys

A virtual MIDI keyboard and controller builder for macOS. Play notes with your computer keyboard or mouse, build custom CC control surfaces, and route everything through an arpeggiator, chord engine, quantizer, or scale filter before it hits your DAW or synth.

MiniKeys shows up as a virtual MIDI source that any app can see. It also supports direct output to hardware MIDI devices and can receive MIDI input from external keyboards.

## Screenshots

<img width="1256" height="803" alt="Screenshot 2026-03-30 at 22 05 17" src="https://github.com/user-attachments/assets/0e48c37e-8321-44ba-8fb9-0b26f0124c81" />
<img width="1256" height="803" alt="Screenshot 2026-03-30 at 22 06 25" src="https://github.com/user-attachments/assets/053d8147-0a7d-46b6-b117-1af6e4a6f4e3" />
<img width="1256" height="803" alt="Screenshot 2026-03-30 at 22 07 07" src="https://github.com/user-attachments/assets/0f2d4f9c-89c6-49da-895b-3048b2cc9bbe" />

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
| Left Shift | Sustain (hold) |

You can also click and drag across the on-screen piano with your mouse or trackpad. Ghost octaves on each side show surrounding context.

## CC Control Surface

Build custom MIDI controller layouts with drag-and-drop widgets:

- **Knobs** -- rotary controls, drag vertically to change
- **Sliders** -- vertical faders
- **Buttons** -- momentary, sends a value on press and another on release
- **Toggles** -- latching on/off switches
- **Select** -- segmented pill buttons for switching between named options (waveforms, filter modes, etc.)
- **ADSR** -- four-parameter envelope with a visual display
- **X/Y Pad** -- two-dimensional control surface sending two CCs at once

All controls support both standard MIDI CC and NRPN (7-bit and 14-bit). Click **Edit** to enter edit mode, where you can add, configure, delete, multi-select, and group controls into labeled sections. Use the zoom buttons to scale the control surface up or down.

Layouts can be saved as presets and loaded later. Import/export to JSON files.

## Device Preset Browser

MiniKeys can fetch MIDI CC and NRPN mappings for 300+ hardware synthesizers and effects from 90+ manufacturers. Open the device browser, pick your gear, and load a ready-made control surface with all parameters organized into groups.

Loaded device presets are automatically saved to your preset library. The browser checks for updates to the mapping database and lets you pull new devices with one click.

Device mappings are sourced from [pencilresearch/midi](https://github.com/pencilresearch/midi).

## Arpeggiator

Hold one or more keys and the arpeggiator plays them back as a pattern.

- **Modes**: Up, Down, Up-Down, Down-Up, Random, As Played
- **Note priority**: Sorted by pitch, Newest first, or Oldest first
- **Timing**: BPM, note division (1/1 to 1/32, dotted, triplet), swing
- **Gate**: adjustable note length from 5% to 100%
- **Octave range**: spread the pattern across 1 to 4 octaves
- **Hold**: keep the pattern running after you release all keys
- **Gate pattern**: a 16-step sequencer where each step can be On, Accent, Tie, or Off -- for rhythmic variation beyond a simple gate length

The arpeggiator syncs to the metronome when both are active.

## Chord Mode

Press a single key and MiniKeys plays a full chord. Choose from 16 chord types (Major, Minor, Sus2, Sus4, Dim, Aug, various 7ths, Add9, Power) with inversions. Chord notes are highlighted on the keyboard so you can see what's playing.

## Metronome

An audio metronome with configurable BPM, time signature (2/4 to 7/4), volume, and a visual beat indicator. The metronome provides a shared master clock -- the arpeggiator locks to its grid for tight timing.

## Live Quantizer

Snaps your playing to a rhythmic grid in real time. Choose a grid division (1/4 to 1/32, with dotted and triplet options) and a strength amount. At 100% strength, notes snap exactly to the grid. At lower values, they're nudged toward it.

## Scale Engine

Constrain your playing to a specific scale and key. Pick from 16 scales (Major, Minor, Dorian, Pentatonic, Blues, Whole Tone, etc.) and 12 root notes. Choose how out-of-scale notes are handled:

- **Off** -- scale is shown visually but all notes play normally
- **Filter** -- out-of-scale notes are blocked
- **Snap Up / Down / Nearest** -- out-of-scale notes are redirected to the closest in-scale note

Out-of-scale keys are shown with dimmed labels on the keyboard for quick visual reference.

## MIDI Input

Connect an external MIDI keyboard or controller through the input picker in the toolbar. Incoming notes are routed through the full processing chain -- arpeggiator, chord mode, quantizer, scale engine -- before being sent to the output.

## Architecture

```
Sources/MiniKeys/
  App/            Entry point, main window
  MIDI/           CoreMIDI (virtual source, output, input, NRPN)
  Keyboard/       Key mapping, state, input monitoring, piano view
  CC/             Control types, views, panel layout, inline editor
  Musical/        Arpeggiator, chords, metronome, quantizer, scales, notestack
  Presets/        Save/load/import/export
  DeviceDB/       Device database, CSV parser, browser
```

Timing-critical paths (arpeggiator, metronome, gate events) run on dedicated background dispatch queues so UI interaction never disrupts playback.

## License

MIT
