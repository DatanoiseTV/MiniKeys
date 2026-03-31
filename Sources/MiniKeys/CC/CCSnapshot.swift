import Foundation
import Observation

/// A snapshot captures the current values of all controls without changing the layout.
struct CCSnapshot: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var values: [UUID: UInt8]         // controlID -> currentValue
    var toggleStates: [UUID: Bool]    // controlID -> isOn
    var selectStates: [UUID: UUID]    // controlID -> selectedOptionID
    var xyValues: [UUID: UInt8]       // controlID -> yValue
    var adsrValues: [UUID: [UInt8]]   // controlID -> adsrValues
    var timestamp: Date = Date()
}

/// Tracks undo/redo history for the control layout.
struct UndoStep: Equatable {
    let layout: ControlLayout
    let description: String
}

@Observable
final class CCHistoryManager {
    private(set) var undoStack: [UndoStep] = []
    private(set) var redoStack: [UndoStep] = []
    private var snapshots: [CCSnapshot] = []
    private let maxUndoSteps = 50

    private let snapshotDir: URL

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var savedSnapshots: [CCSnapshot] { snapshots }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        snapshotDir = appSupport.appendingPathComponent("MiniKeys/Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: snapshotDir, withIntermediateDirectories: true)
        loadSnapshots()
    }

    // MARK: - Undo/Redo

    func pushUndo(layout: ControlLayout, description: String) {
        undoStack.append(UndoStep(layout: layout, description: description))
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    func undo(current: ControlLayout) -> ControlLayout? {
        guard let step = undoStack.popLast() else { return nil }
        redoStack.append(UndoStep(layout: current, description: step.description))
        return step.layout
    }

    func redo(current: ControlLayout) -> ControlLayout? {
        guard let step = redoStack.popLast() else { return nil }
        undoStack.append(UndoStep(layout: current, description: step.description))
        return step.layout
    }

    // MARK: - Snapshots

    func takeSnapshot(name: String, from layout: ControlLayout) {
        var values: [UUID: UInt8] = [:]
        var toggles: [UUID: Bool] = [:]
        var selects: [UUID: UUID] = [:]
        var xys: [UUID: UInt8] = [:]
        var adsrs: [UUID: [UInt8]] = [:]

        for control in layout.controls {
            values[control.id] = control.currentValue
            if control.type == .toggle { toggles[control.id] = control.isOn }
            if control.type == .select, let sel = control.selectedOptionID { selects[control.id] = sel }
            if control.type == .xyPad { xys[control.id] = control.yValue }
            if control.type == .adsr { adsrs[control.id] = control.adsrValues }
        }

        let snapshot = CCSnapshot(
            name: name,
            values: values,
            toggleStates: toggles,
            selectStates: selects,
            xyValues: xys,
            adsrValues: adsrs
        )
        snapshots.append(snapshot)
        saveSnapshotToDisk(snapshot)
    }

    func applySnapshot(_ snapshot: CCSnapshot, to layout: inout ControlLayout) {
        for i in layout.controls.indices {
            let id = layout.controls[i].id
            if let val = snapshot.values[id] {
                layout.controls[i].currentValue = val
            }
            if let isOn = snapshot.toggleStates[id] {
                layout.controls[i].isOn = isOn
            }
            if let selID = snapshot.selectStates[id] {
                layout.controls[i].selectedOptionID = selID
            }
            if let yVal = snapshot.xyValues[id] {
                layout.controls[i].yValue = yVal
            }
            if let adsr = snapshot.adsrValues[id] {
                layout.controls[i].adsrValues = adsr
            }
        }
    }

    func deleteSnapshot(_ id: UUID) {
        if let idx = snapshots.firstIndex(where: { $0.id == id }) {
            let name = snapshots[idx].name
            snapshots.remove(at: idx)
            let url = snapshotDir.appendingPathComponent("\(name).json")
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Persistence

    private func saveSnapshotToDisk(_ snapshot: CCSnapshot) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(snapshot) else { return }
        let url = snapshotDir.appendingPathComponent("\(snapshot.name).json")
        try? data.write(to: url, options: .atomic)
    }

    private func loadSnapshots() {
        let files = (try? FileManager.default.contentsOfDirectory(at: snapshotDir, includingPropertiesForKeys: nil)) ?? []
        snapshots = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> CCSnapshot? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(CCSnapshot.self, from: data)
            }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
