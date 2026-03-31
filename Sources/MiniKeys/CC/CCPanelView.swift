import SwiftUI

struct CCPanelView: View {
    @Binding var layout: ControlLayout
    let onValueChange: (CCControl, UInt8) -> Void
    @Bindable var historyManager: CCHistoryManager
    @Binding var learningControlID: UUID?

    @State private var editMode = false
    @State private var selectedControlIDs: Set<UUID> = []
    @State private var showSnapshotSave = false
    @State private var snapshotName = ""

    // For inline editor: show editor for the last-selected control
    private var primarySelectedID: UUID? {
        selectedControlIDs.count == 1 ? selectedControlIDs.first : nil
    }

    private var primarySelectedIndex: Int? {
        guard editMode, let id = primarySelectedID else { return nil }
        return layout.controls.firstIndex(where: { $0.id == id })
    }

    private var ungroupedControls: [CCControl] {
        layout.controls.filter { $0.groupID == nil }
    }

    private func controlsIn(group: CCGroup) -> [CCControl] {
        layout.controls.filter { $0.groupID == group.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header — pinned outside the scroll
            HStack(spacing: 8) {
                Text("CC Controls")
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)

                // Undo/Redo
                if editMode {
                    HStack(spacing: 2) {
                        Button(action: {
                            if let prev = historyManager.undo(current: layout) {
                                layout = prev
                            }
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(!historyManager.canUndo)

                        Button(action: {
                            if let next = historyManager.redo(current: layout) {
                                layout = next
                            }
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(!historyManager.canRedo)
                    }
                    .foregroundStyle(.secondary)
                }

                // Snapshots
                Menu {
                    Button("Save Snapshot...") { showSnapshotSave = true }
                    if !historyManager.savedSnapshots.isEmpty {
                        Divider()
                        ForEach(historyManager.savedSnapshots) { snap in
                            Button(snap.name) {
                                historyManager.pushUndo(layout: layout, description: "Load snapshot")
                                historyManager.applySnapshot(snap, to: &layout)
                            }
                        }
                        Divider()
                        Menu("Delete") {
                            ForEach(historyManager.savedSnapshots) { snap in
                                Button(snap.name, role: .destructive) {
                                    historyManager.deleteSnapshot(snap.id)
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 10))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(.secondary)
                .help("Snapshots — save and recall control values")

                Spacer()

                if editMode {
                    if selectedControlIDs.count >= 2 {
                        Button {
                            groupSelected()
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "rectangle.3.group")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Group (\(selectedControlIDs.count))")
                                    .font(.system(.caption))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(Color.orange.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Group selected controls")
                    }

                    Menu {
                        Section("Add Control") {
                            ForEach(CCControlType.allCases, id: \.self) { type in
                                Button {
                                    addControl(type: type)
                                } label: {
                                    Label(type.displayName, systemImage: type.icon)
                                }
                            }
                        }
                        Section {
                            Button {
                                addGroup()
                            } label: {
                                Label("New Group", systemImage: "rectangle.3.group")
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add")
                                .font(.system(.caption))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        editMode.toggle()
                        if !editMode { selectedControlIDs.removeAll() }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: editMode ? "pencil.slash" : "pencil")
                            .font(.system(size: 10, weight: .semibold))
                        Text(editMode ? "Done" : "Edit")
                            .font(.system(.caption))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(editMode ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)

            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))

            // Controls — wrapping flow layout
            GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                FlowLayout(spacing: 8, containerWidth: geo.size.width - 16) {
                    // Groups
                    ForEach(layout.groups) { group in
                        GroupView(
                            group: group,
                            controls: controlsIn(group: group),
                            editMode: editMode,
                            containerWidth: geo.size.width - 16,
                            selectedControlIDs: $selectedControlIDs,
                            layout: $layout,
                            learningControlID: $learningControlID,
                            onValueChange: onValueChange,
                            onDeleteGroup: { deleteGroup(group) }
                        )
                    }

                    // Ungrouped controls
                    ForEach(ungroupedControls) { control in
                        if let idx = layout.controls.firstIndex(where: { $0.id == control.id }) {
                            CCControlView(
                                control: $layout.controls[idx],
                                isSelected: editMode && selectedControlIDs.contains(control.id),
                                editMode: editMode,
                                isLearning: learningControlID == control.id,
                                onValueChange: onValueChange,
                                onSelect: { shift in toggleSelect(control.id, extending: shift) },
                                onDelete: { deleteControl(control.id) },
                                onLearn: {
                                    learningControlID = learningControlID == control.id ? nil : control.id
                                }
                            )
                        }
                    }

                    if layout.controls.isEmpty && editMode {
                        Text("Click + Add to add controls")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal)
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 80)
            .contextMenu {
                Menu("Add Control") {
                    ForEach(CCControlType.allCases, id: \.self) { type in
                        Button {
                            addControl(type: type)
                        } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                }
                Button {
                    addGroup()
                } label: {
                    Label("New Group", systemImage: "rectangle.3.group")
                }
                if !selectedControlIDs.isEmpty {
                    Divider()
                    if selectedControlIDs.count >= 2 {
                        Button("Group Selected (\(selectedControlIDs.count))") {
                            groupSelected()
                        }
                    }
                    Button("Delete Selected", role: .destructive) {
                        for id in selectedControlIDs {
                            deleteControl(id)
                        }
                    }
                }
            }
            } // GeometryReader

            // Inline editor inside the VStack, pinned at bottom of panel
            if let idx = primarySelectedIndex {
                CCInlineEditor(
                    control: $layout.controls[idx],
                    groups: layout.groups,
                    onDelete: { deleteControl(layout.controls[idx].id) }
                )
            }
        } // VStack
        .alert("Save Snapshot", isPresented: $showSnapshotSave) {
            TextField("Name", text: $snapshotName)
            Button("Save") {
                guard !snapshotName.isEmpty else { return }
                historyManager.takeSnapshot(name: snapshotName, from: layout)
                snapshotName = ""
            }
            Button("Cancel", role: .cancel) { snapshotName = "" }
        } message: {
            Text("Save current control values as a snapshot")
        }
    } // body

    private func toggleSelect(_ id: UUID, extending: Bool = false) {
        guard editMode else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            if extending {
                // Shift-click: toggle this item in the selection
                if selectedControlIDs.contains(id) {
                    selectedControlIDs.remove(id)
                } else {
                    selectedControlIDs.insert(id)
                }
            } else {
                // Plain click: select only this item (or deselect if already the only one)
                if selectedControlIDs == [id] {
                    selectedControlIDs.removeAll()
                } else {
                    selectedControlIDs = [id]
                }
            }
        }
    }

    private func addControl(type: CCControlType) {
        historyManager.pushUndo(layout: layout, description: "Add \(type.displayName)")
        let nextCC = UInt8(layout.controls.count + 1)
        var control = CCControl(
            type: type,
            label: "\(type.displayName) \(layout.controls.count + 1)",
            ccNumber: min(nextCC, 127),
            currentValue: type == .knob || type == .slider ? 64 : 0
        )
        if type == .select {
            control.options = [
                SelectOption(label: "Option 1", value: 0),
                SelectOption(label: "Option 2", value: 64),
                SelectOption(label: "Option 3", value: 127),
            ]
            control.selectedOptionID = control.options.first?.id
            control.currentValue = 0
        } else if type == .adsr {
            control.label = "Envelope \(layout.controls.count + 1)"
        } else if type == .xyPad {
            control.label = "X/Y Pad \(layout.controls.count + 1)"
            control.currentValue = 64
            control.yValue = 64
            control.yCCNumber = min(nextCC + 1, 127)
        }
        layout.controls.append(control)
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedControlIDs = [control.id]
        }
    }

    private func addGroup() {
        let group = CCGroup(label: "Group \(layout.groups.count + 1)")
        layout.groups.append(group)
    }

    private func groupSelected() {
        let group = CCGroup(label: "Group \(layout.groups.count + 1)")
        layout.groups.append(group)
        for i in layout.controls.indices {
            if selectedControlIDs.contains(layout.controls[i].id) {
                layout.controls[i].groupID = group.id
            }
        }
        selectedControlIDs.removeAll()
    }

    private func deleteControl(_ id: UUID) {
        historyManager.pushUndo(layout: layout, description: "Delete control")
        selectedControlIDs.remove(id)
        layout.controls.removeAll { $0.id == id }
    }

    private func deleteGroup(_ group: CCGroup) {
        historyManager.pushUndo(layout: layout, description: "Delete group")
        for i in layout.controls.indices {
            if layout.controls[i].groupID == group.id {
                layout.controls[i].groupID = nil
            }
        }
        layout.groups.removeAll { $0.id == group.id }
    }
}

// MARK: - Group View

struct GroupView: View {
    let group: CCGroup
    let controls: [CCControl]
    let editMode: Bool
    var containerWidth: CGFloat? = nil
    @Binding var selectedControlIDs: Set<UUID>
    @Binding var layout: ControlLayout
    @Binding var learningControlID: UUID?
    let onValueChange: (CCControl, UInt8) -> Void
    let onDeleteGroup: () -> Void

    @State private var isRenaming = false
    @State private var renameText = ""

    private var groupIndex: Int? {
        layout.groups.firstIndex(where: { $0.id == group.id })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if isRenaming, let idx = groupIndex {
                    TextField("Name", text: $renameText, onCommit: {
                        layout.groups[idx].label = renameText
                        isRenaming = false
                    })
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10))
                    .frame(width: 100)
                    .onExitCommand { isRenaming = false }
                } else {
                    Text(group.label)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .onTapGesture(count: editMode ? 1 : 2) {
                            guard editMode else { return }
                            renameText = group.label
                            isRenaming = true
                        }
                }

                if editMode && !isRenaming {
                    Button(action: onDeleteGroup) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete group (ungroups controls)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            if controls.isEmpty {
                Text("Empty")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 50, height: 40)
                    .padding(8)
            } else {
                FlowLayout(spacing: 6, containerWidth: containerWidth.map { $0 - 28 }) {
                    ForEach(controls) { control in
                        if let idx = layout.controls.firstIndex(where: { $0.id == control.id }) {
                            CCControlView(
                                control: $layout.controls[idx],
                                isSelected: editMode && selectedControlIDs.contains(control.id),
                                editMode: editMode,
                                isLearning: learningControlID == control.id,
                                onValueChange: onValueChange,
                                onSelect: { shift in
                                    guard editMode else { return }
                                    let id = control.id
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        if shift {
                                            if selectedControlIDs.contains(id) {
                                                selectedControlIDs.remove(id)
                                            } else {
                                                selectedControlIDs.insert(id)
                                            }
                                        } else {
                                            selectedControlIDs = selectedControlIDs == [id] ? [] : [id]
                                        }
                                    }
                                },
                                onDelete: {
                                    selectedControlIDs.remove(control.id)
                                    layout.controls.removeAll { $0.id == control.id }
                                },
                                onLearn: {
                                    learningControlID = learningControlID == control.id ? nil : control.id
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Inline Editor

struct CCInlineEditor: View {
    @Binding var control: CCControl
    let groups: [CCGroup]
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Type, Label, Mode/CC, Delete
            HStack(spacing: 10) {
                LabeledField("Type") {
                    Picker("", selection: $control.type) {
                        ForEach(CCControlType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .fixedSize()
                }

                LabeledField("Label") {
                    TextField("Label", text: $control.label)
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 80, maxWidth: 150)
                }

                LabeledField("Group") {
                    Picker("", selection: $control.groupID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(groups) { group in
                            Text(group.label).tag(group.id as UUID?)
                        }
                    }
                    .fixedSize()
                }

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red.opacity(0.7))
            }

            // Row 2: Type-specific fields
            HStack(spacing: 10) {
                if control.type != .adsr && control.type != .xyPad {
                    LabeledField("Mode") {
                        Picker("", selection: $control.messageType) {
                            Text("CC").tag(CCMessageType.cc)
                            Text("NRPN").tag(CCMessageType.nrpn)
                        }
                        .fixedSize()
                    }

                    if control.messageType == .cc {
                        LabeledField("CC #") {
                            TextField("", value: $control.ccNumber, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                        }
                    } else {
                        LabeledField("MSB") {
                            TextField("", value: $control.nrpnMSB, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                        }
                        LabeledField("LSB") {
                            TextField("", value: $control.nrpnLSB, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                        }
                    }
                }

                if control.type == .knob || control.type == .slider {
                    LabeledField("Min") {
                        TextField("", value: $control.minValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                            .onChange(of: control.minValue) { _, _ in enforceMinMax(); clampCurrent() }
                    }
                    LabeledField("Max") {
                        TextField("", value: $control.maxValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                            .onChange(of: control.maxValue) { _, _ in enforceMinMax(); clampCurrent() }
                    }
                    LabeledField("Step") {
                        TextField("", value: $control.step, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                            .onChange(of: control.step) { _, newVal in
                                if newVal < 1 { control.step = 1 }
                            }
                    }
                }

                if control.type == .button || control.type == .toggle {
                    LabeledField("Off") {
                        TextField("", value: $control.minValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                    }
                    LabeledField("On") {
                        TextField("", value: $control.maxValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                    }
                }

                if control.type == .xyPad {
                    LabeledField("X CC") {
                        TextField("", value: $control.ccNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                    }
                    LabeledField("Y CC") {
                        TextField("", value: $control.yCCNumber, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 44)
                    }
                }
            }

            // Row 3: Extended editors
            if control.type == .select {
                SelectOptionsEditor(options: $control.options)
            }
            if control.type == .adsr {
                ADSRCCEditor(adsrCCs: $control.adsrCCs)
            }
        }
        .font(.system(.caption))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .padding(.horizontal, 4)
    }

    private func enforceMinMax() {
        if control.minValue > control.maxValue {
            let oldMin = control.minValue
            control.minValue = control.maxValue
            control.maxValue = oldMin
        }
    }

    private func clampCurrent() {
        control.currentValue = max(control.minValue, min(control.maxValue, control.currentValue))
    }
}

struct SelectOptionsEditor: View {
    @Binding var options: [SelectOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Options")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    options.append(SelectOption(
                        label: "Option \(options.count + 1)",
                        value: options.isEmpty ? 0 : min(options.last!.value &+ 32, 127)
                    ))
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9))
                }
                .buttonStyle(.plain)
            }

            ForEach($options) { $option in
                HStack(spacing: 8) {
                    TextField("Label", text: $option.label)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)

                    Text("=")
                        .foregroundStyle(.tertiary)

                    TextField("Value", value: $option.value, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 44)

                    Button {
                        options.removeAll { $0.id == option.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.leading, 4)
    }
}

struct ADSRCCEditor: View {
    @Binding var adsrCCs: [UInt8]
    private let labels = ["Attack CC", "Decay CC", "Sustain CC", "Release CC"]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { i in
                LabeledField(labels[i]) {
                    TextField("", value: $adsrCCs[i], format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 44)
                }
            }
        }
        .padding(.leading, 4)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var containerWidth: CGFloat? = nil

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            if index < result.positions.count {
                let pos = result.positions[index]
                subview.place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
            }
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = containerWidth ?? proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalWidth = max(totalWidth, x)
        }

        return (positions, CGSize(width: totalWidth, height: y + rowHeight))
    }
}

// MARK: - Helper

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            content
        }
    }
}
