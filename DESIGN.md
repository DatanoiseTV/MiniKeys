# Design System

Internal reference for visual and interaction patterns used across Datanoise products. Not part of the public repository.

## Principles

- Native first. Use system controls and conventions unless there's a strong reason not to. Users shouldn't have to learn a new UI language.
- Density over decoration. Show information and controls compactly. Avoid whitespace-heavy layouts that waste screen real estate, but give elements enough room to breathe.
- Progressive disclosure. Start simple, reveal complexity on demand. Toggles expand panels, edit modes unlock options, right-click menus provide power-user actions.
- Dark and light. All custom colors must work in both macOS appearance modes. Use semantic colors (`.primary`, `.secondary`, `.tertiary`) for text. Fixed colors only for domain-specific elements (piano keys, LED indicators).

## Color Palette

### Semantic (adapts to dark/light)
- **Primary text**: `.primary` for labels, values, control names
- **Secondary text**: `.secondary` for less important info (CC numbers, hints)
- **Tertiary text**: `.tertiary` for disabled states, empty-state messages
- **Backgrounds**: `Color(nsColor: .controlBackgroundColor)` at varying opacity (0.3-0.5) for cards and panels
- **Window chrome**: `Color(nsColor: .windowBackgroundColor)` for toolbars, `Color(nsColor: .underPageBackgroundColor)` for the main content area

### Fixed (same in both modes)
- **Piano white keys**: `Color.white` always
- **Piano black keys**: `Color(white: 0.2)` always
- **Active/accent**: `Color.accentColor` (system blue by default)
- **Recording/learning**: `Color.red` or `Color.orange` for recording states
- **Success/sustain**: `Color.green` for active sustain, connected states

### Control State Colors
- **Inactive**: `Color(nsColor: .controlBackgroundColor).opacity(0.4)`
- **Active/pressed**: `Color.accentColor.opacity(0.7)` for white keys, full `Color.accentColor` for black keys
- **Highlighted (chord, scale)**: `Color.accentColor.opacity(0.25)`
- **Out-of-scale**: same key color, dimmed labels only (`Color.gray.opacity(0.2-0.3)`)

## Typography

- **System font (San Francisco)** for all UI elements. No monospaced fonts in the interface except piano key labels.
- **Caption2** (10pt) for control labels, CC numbers, small values
- **Caption** (11pt) for section headers, toolbar buttons, tool pill labels
- **Body** (13pt) for status displays (octave, velocity, sustain)
- **Title3** (15pt) for sheet/panel titles (device browser header)
- **Weight**: `.semibold` or `.bold` for active states and section headers, regular everywhere else
- Labels should be concise. Truncate with `...` rather than wrapping to 3+ lines. Allow up to 2 lines for CC control names.

## Layout

### Spacing Scale
- **2px**: between tightly coupled elements (label + value)
- **4px**: inside compact controls (pill buttons, gate steps)
- **6px**: between controls inside groups
- **8px**: standard padding inside panels, between ungrouped controls
- **12px**: outer margins, toolbar padding
- **16-24px**: between major sections (keyboard status items)

### Toolbar
- Single row, full width, `windowBackgroundColor` background
- Left: connection controls (MIDI output, channel, input)
- Center: action buttons (Devices, Auto Learn, Panic)
- Right: preset management (Presets dropdown, save, export, CSV export)
- Button style: plain text + icon, `.secondary` foreground, no borders
- Active states indicated by color change (accent or red), not borders

### Tool Bar (Musical Tools)
- Horizontal row of pill-shaped toggles below the keyboard
- Each pill: native macOS mini toggle switch + icon + label
- Single-click pill body to expand settings panel; toggle switch to enable/disable
- Only one panel expanded at a time
- Enabling a tool auto-expands its panel
- Background: subtle filled rounded rectangle with accent tint when active, border when expanded

### CC Control Surface
- **FlowLayout** wrapping at window width (using GeometryReader to capture actual width)
- Controls have fixed intrinsic sizes (76px knobs, 52px sliders, 84px selects, etc.)
- Group containers: subtle filled background + thin border, title above, internal FlowLayout
- Groups receive container width to wrap internally
- Edit mode: transparent overlay intercepts taps for selection; inner controls become non-interactive
- Inline editor: pinned below scroll area, split into rows (identity row + type-specific row + extended editors)

### Sidebar
- Fixed width (180px), right-aligned, shown/hidden with animation
- Light background tint to distinguish from main content
- Header with title + add button, scrollable content below
- Compact vertical card layout for each item

### Device Browser
- Full-width sheet, 3-column Finder-style layout
- Column 1 (200px): Manufacturer list with counts
- Column 2 (200px): Device list for selected manufacturer
- Column 3 (remaining): Parameter preview with stats, NRPN toggle, Load button
- Close button (xmark.circle.fill) in the top-right of the header bar

## Controls

### Knob
- 44px diameter arc (270 degrees, gap at bottom)
- Background arc in gray at 0.3 opacity, value arc in accent color
- Inner circle for the knob body, 2px indicator line
- Drag vertically to change: 400px = full range
- Value and CC number displayed below

### Slider
- 8px wide track, 80px tall
- Filled from bottom, 20x8px thumb
- Drag vertically, 1:1 mapping to track height

### Button (Momentary)
- 44x44px rounded rectangle
- Filled circle indicator, accent color when pressed
- DragGesture(minimumDistance: 0) for immediate response

### Toggle (Latching)
- 44x44px rounded rectangle
- Circle icon: filled = on, outline = off
- Accent color fill when on

### Select
- 5 or fewer options: vertical pill stack, full-width per pill
- More than 5: compact dropdown menu with checkmark on selected
- Pills: accent fill when selected, label left-aligned, value right-aligned

### ADSR
- Linear envelope visualization (4 equal-width zones: A, D, sustain hold, R)
- Stroke + subtle fill
- 4 mini-sliders below (6px track, 14x5px thumb)

### X/Y Pad
- 130x130px rounded rectangle
- Center grid lines, crosshair position lines in accent at 0.3 opacity
- Glowing cursor dot (8px normal, 12px while dragging)
- Sends two CCs simultaneously

### Macro Knob
- 50px diameter, same arc style as CC knobs
- Color-coded per macro (user selectable)
- A/B morph slider below
- Expandable mapping list

## Interaction Patterns

### Edit Mode
- Toggled by a labeled button ("Edit" / "Done")
- In edit mode: control interactions disabled, click to select, blue border on selected
- Multi-select supported, "Group (N)" button appears when 2+ selected
- Inline editor appears when exactly 1 control is selected

### MIDI Learn
- Right-click any control, select "MIDI Learn"
- Pulsing orange border + "Learning..." overlay
- Next incoming CC auto-assigns; learning state clears

### Auto Learn
- Toggle in toolbar, red recording indicator when active
- Every new CC from MIDI input creates a knob control
- Stop to finish, then manually rename/retype/group

### Snapshots
- Camera icon in CC Controls header
- Save: dialog for name, stores all current values
- Load: menu with saved snapshots, applies values to matching control IDs

### Tap Tempo
- Weighted average of last 12 taps, recent taps weighted more
- Shows running estimate in parentheses after 2 taps
- Commits BPM after 3 taps
- 2.5s timeout resets

### BPM Control
- Drag up/down to change (1 BPM per 3px)
- Double-click to type directly
- Visual highlight while dragging

### Keyboard Focus
- Clicking outside a text field (via mouseDown monitor) resigns first responder
- Keyboard input immediately available for playing after any UI interaction

## Animation

- **Panel expand/collapse**: `.easeInOut(duration: 0.15)` for tool panels, edit mode transitions
- **Sidebar show/hide**: `.easeInOut(duration: 0.2)` with `.move(edge: .trailing)` transition
- **Activity flash**: `.easeOut(duration: 0.3)` for MIDI activity border pulse
- **MIDI learn pulse**: continuous phase animation on border opacity
- No spring animations. No bouncing. Keep it tight and functional.

## Technical Notes

### Threading
- All `@Observable` classes are NOT `@MainActor` (CI compatibility with strict concurrency)
- Timing-critical code (arp, metronome, gate) uses `DispatchSourceTimer` on background queues
- MIDI send functions are `nonisolated` and called directly from timer queues
- UI updates hop to main via `DispatchQueue.main.async`

### Scaling
- Controls render at fixed intrinsic sizes (no scaleEffect)
- FlowLayout uses explicit `containerWidth` from GeometryReader
- Groups also receive container width for internal wrapping

### Persistence
- Presets: `~/Library/Application Support/MiniKeys/Presets/` (JSON)
- Snapshots: `~/Library/Application Support/MiniKeys/Snapshots/` (JSON)
- Device DB: `~/Library/Application Support/MiniKeys/DeviceDB/` (git clone)

### Build
- Swift Package Manager, swift-tools-version 5.10, macOS 14+
- Universal binary via `swift build --arch arm64 --arch x86_64`
- CI passes `-Xswiftc -strict-concurrency=minimal` for Xcode 15.4 compatibility
- App bundle created by `build.sh` with ad-hoc signing
