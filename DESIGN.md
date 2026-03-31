# Datanoise Design System

Internal reference for visual and interaction patterns across Datanoise products. Not part of any public repository.

## Principles

- **Native first**. Use system controls and platform conventions. Users shouldn't have to learn a custom UI language.
- **Density over decoration**. Show information and controls compactly. Avoid whitespace-heavy layouts, but give elements enough room to breathe.
- **Progressive disclosure**. Start simple, reveal complexity on demand. Toggles expand panels, edit modes unlock options, right-click menus provide power-user actions.
- **Dark and light**. All custom colors must work in both appearance modes. Use semantic colors for text. Fixed colors only for domain-specific elements.

## Color Palette

### Semantic (adapts to dark/light automatically)
- **Primary text**: `.primary` for labels, values, control names
- **Secondary text**: `.secondary` for supporting info, hints
- **Tertiary text**: `.tertiary` for disabled states, empty-state messages
- **Card backgrounds**: `controlBackgroundColor` at 0.3-0.5 opacity
- **Toolbar backgrounds**: `windowBackgroundColor`
- **Content area**: `underPageBackgroundColor`

### Fixed (same in both modes)
- **Active/accent**: system accent color (`.accentColor`)
- **Recording/learning states**: red or orange
- **Success/active indicators**: green
- **Danger/destructive**: red at 0.6-0.7 opacity

### Control States
- **Inactive**: `controlBackgroundColor` at 0.4 opacity
- **Active/pressed**: accent color at 0.7 opacity
- **Highlighted**: accent color at 0.25 opacity
- **Disabled**: same color as inactive, dimmed labels only

## Typography

- **System font** for all UI elements. No monospaced fonts except where technical precision matters (code, fixed-width data).
- **Caption2** (10pt): control labels, small values, metadata
- **Caption** (11pt): section headers, toolbar buttons, compact labels
- **Body** (13pt): status displays, primary information
- **Title3** (15pt): panel/sheet titles
- **Weight**: `.semibold` or `.bold` for active states and section headers, `.regular` everywhere else
- Labels should be concise. Truncate with ellipsis rather than wrapping beyond 2 lines.

## Layout

### Spacing Scale
- **2px**: between tightly coupled elements (label + value)
- **4px**: inside compact controls (pill buttons, step cells)
- **6px**: between items inside grouped containers
- **8px**: standard padding inside panels, between sibling items
- **12px**: outer margins, toolbar padding
- **16-24px**: between major sections

### Toolbar
- Single row, full width, `windowBackgroundColor` background
- Left: primary controls and navigation
- Center: action buttons and mode toggles
- Right: settings, presets, secondary actions
- Button style: plain text + icon, `.secondary` foreground, no borders
- Active states shown by color change, not borders

### Tool Bar (Compact Controls Row)
- Horizontal row of pill-shaped toggles
- Each pill: native mini toggle switch + icon + label
- Click pill to expand settings panel; toggle switch to enable/disable
- Only one panel expanded at a time
- Enabling a tool auto-expands its panel
- Background: subtle filled rounded rectangle, accent tint when active, border when expanded

### Card/Widget Layout
- **FlowLayout** wrapping at container width (use GeometryReader to capture actual width)
- Fixed intrinsic sizes per widget type
- Group containers: subtle filled background + thin border, title above, internal flow wrapping
- Pass container width to nested layouts for proper wrapping

### Sidebar
- Fixed width (180-200px), left-aligned, shown/hidden with animation
- Light background tint to distinguish from main content
- Simple fold/unfold icon in the toolbar (no text label)
- Header with title + add button, scrollable content below
- Compact vertical card layout

### Sheet/Modal Browser
- Full-width sheet with multi-column layout (Finder-style)
- Close button (xmark.circle.fill) in the header
- Search bar at the top

## Controls

### Rotary Knob
- 44-56px diameter arc (270 degrees, gap at bottom)
- Background arc in gray at 0.2-0.3 opacity, value arc in accent color
- Inner circle body with shadow, 2px indicator line
- Drag vertically to change: 300-400px for full range
- Value and identifier displayed below

### Vertical Slider
- 6-8px wide track, 40-80px tall
- Filled from bottom, small thumb handle
- Drag vertically, 1:1 mapping to track height

### Momentary Button
- 44x44px rounded rectangle
- Visual indicator (filled circle or similar), accent color when pressed
- DragGesture(minimumDistance: 0) for zero-latency response

### Toggle (Latching)
- 44x44px rounded rectangle
- State indicator: filled = on, outline = off
- Accent color fill when on

### Select/Picker
- 5 or fewer options: vertical pill stack, each full-width
- More than 5: compact dropdown menu with checkmark on selected
- Pills: accent fill when selected, label left-aligned, value right-aligned

### X/Y Pad
- Square area (120-140px), rounded corners
- Center grid lines, crosshair position indicators at 0.3 opacity
- Cursor dot that grows while dragging
- Controls two parameters simultaneously

## Interaction Patterns

### Edit Mode
- Toggled by a labeled button ("Edit" / "Done")
- In edit mode: widget interactions disabled, click to select, accent border on selected
- Multi-select supported, batch action buttons appear contextually
- Inline editor appears for single selection

### Learn Mode
- Right-click any control to enter
- Pulsing border + "Learning..." indicator
- Next relevant input auto-assigns; learning state clears
- Click again or start another learn to cancel

### Auto-Learn Mode
- Toggle in toolbar, recording indicator when active
- Incoming data automatically creates new controls
- Stop to finish, then manually refine

### Snapshots
- Save icon in control header
- Save: dialog for name, stores all current values
- Load: menu with saved snapshots
- Values only — layout unchanged

### Tap Tempo
- Weighted average of recent taps (12 buffer, 2.5s timeout)
- Shows running estimate after 2 taps
- Commits after 3 taps for stability

### Draggable Value
- Drag up/down to change (1 unit per 3px)
- Double-click to type directly
- Visual highlight while dragging

### Focus Management
- Clicking outside text fields resigns first responder via mouseDown monitor
- Keyboard shortcuts immediately available after any UI interaction

## Animation

- **Panel expand/collapse**: `.easeInOut(duration: 0.12-0.15)`
- **Sidebar show/hide**: `.easeInOut(duration: 0.15-0.2)` with `.move(edge:)` transition
- **Activity flash**: `.easeOut(duration: 0.3)` for brief border pulse
- **Learn pulse**: continuous phase animation on border opacity
- No spring animations. No bouncing. Tight and functional.

## Technical Patterns

### Threading (macOS/SwiftUI)
- Observable classes should NOT use `@MainActor` (strict concurrency compatibility)
- Timing-critical code uses `DispatchSourceTimer` on background queues (`.userInteractive` QoS)
- Real-time output functions are `nonisolated` and thread-safe
- UI updates hop to main via `DispatchQueue.main.async`

### Layout Scaling
- Prefer fixed intrinsic sizes over `scaleEffect` (which breaks layout)
- FlowLayout with explicit `containerWidth` from GeometryReader
- Nested containers also receive container width for proper wrapping

### Persistence
- App-specific data in `~/Library/Application Support/<AppName>/`
- JSON for configuration, presets, snapshots
- Git clone for external databases
- File panels (NSOpenPanel/NSSavePanel) for user-facing import/export

### Build & CI
- Swift Package Manager, macOS 14+
- Universal binary via `--arch arm64 --arch x86_64`
- CI passes `-Xswiftc -strict-concurrency=minimal` for toolchain compatibility
- App bundle via shell script with ad-hoc signing
- Quarantine removal instructions in README for unsigned builds
