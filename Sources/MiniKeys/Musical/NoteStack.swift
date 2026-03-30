import Foundation

enum NoteStackMode {
    case pushTop       // newest note at index 0
    case pushBottom    // newest note at end
    case sorted        // ascending note order
    case pushTopHold   // pushTop + hold behavior
    case pushBottomHold
    case sortedHold    // sorted + hold (ideal for arpeggiator)

    var isHold: Bool {
        switch self {
        case .pushTopHold, .pushBottomHold, .sortedHold: true
        default: false
        }
    }
}

struct NoteStackItem: Equatable {
    var note: UInt8 = 0
    var velocity: UInt8 = 0
    var depressed: Bool = false  // true = key released but held in stack

    var isEmpty: Bool { note == 0 && velocity == 0 }

    static let empty = NoteStackItem()
}

/// Pop return values
enum NoteStackPopResult {
    case notFound       // note wasn't in the stack
    case removed        // removed (non-hold) or marked depressed with active notes remaining
    case allDepressed   // hold mode: all remaining notes are depressed (all keys released)
}

struct NoteStack {
    let mode: NoteStackMode
    let capacity: Int
    private(set) var items: [NoteStackItem]
    private(set) var count: Int = 0

    init(mode: NoteStackMode, capacity: Int = 16) {
        self.mode = mode
        self.capacity = capacity
        self.items = Array(repeating: .empty, count: capacity)
    }

    // MARK: - Push

    mutating func push(note: UInt8, velocity: UInt8) {
        // In HOLD mode, check for existing note and reactivate
        if mode.isHold {
            for i in 0..<count {
                if items[i].note == note {
                    items[i].depressed = false
                    items[i].velocity = velocity
                    return
                }
            }
        } else {
            // Non-hold: remove existing to prevent duplicates
            _ = pop(note: note)
        }

        // Determine insertion point
        let insertionPoint: Int

        switch mode {
        case .pushBottom, .pushBottomHold:
            if count >= capacity {
                // Overwrite last slot
                items[capacity - 1] = NoteStackItem(note: note, velocity: velocity)
                return
            }
            insertionPoint = count

        case .sorted, .sortedHold:
            var idx = count
            for i in 0..<count {
                if items[i].note > note {
                    idx = i
                    break
                }
            }
            if count >= capacity && idx >= capacity {
                items[capacity - 1] = NoteStackItem(note: note, velocity: velocity)
                return
            }
            insertionPoint = idx

        case .pushTop, .pushTopHold:
            insertionPoint = 0
        }

        // Make room: shift items right from insertion point
        let newCount = min(count + 1, capacity)
        var i = newCount - 1
        while i > insertionPoint {
            items[i] = items[i - 1]
            i -= 1
        }

        items[insertionPoint] = NoteStackItem(note: note, velocity: velocity)
        count = newCount
    }

    // MARK: - Pop

    @discardableResult
    mutating func pop(note: UInt8) -> NoteStackPopResult {
        guard let idx = (0..<count).first(where: { items[$0].note == note }) else {
            return .notFound
        }

        if mode.isHold {
            // Mark as depressed, don't remove
            items[idx].depressed = true

            // Check if any note is still actively pressed
            let hasActive = (0..<count).contains { !items[$0].depressed }
            return hasActive ? .removed : .allDepressed
        } else {
            // Shift items left to fill the gap
            for i in idx..<(count - 1) {
                items[i] = items[i + 1]
            }
            count -= 1
            items[count] = .empty
            return .removed
        }
    }

    // MARK: - Hold helpers

    /// Count of notes that are still actively pressed (not depressed)
    var activeCount: Int {
        (0..<count).filter { !items[$0].depressed }.count
    }

    /// All notes currently in the stack (including depressed in hold mode)
    var allNotes: [NoteStackItem] {
        Array(items[0..<count])
    }

    /// Only actively pressed notes
    var activeNotes: [NoteStackItem] {
        (0..<count).filter { !items[$0].depressed }.map { items[$0] }
    }

    /// Remove all depressed (released) notes from the stack
    mutating func removeNonActiveNotes() {
        var writeIdx = 0
        for readIdx in 0..<count {
            if !items[readIdx].depressed {
                if writeIdx != readIdx {
                    items[writeIdx] = items[readIdx]
                }
                writeIdx += 1
            }
        }
        // Clear vacated slots
        for i in writeIdx..<count {
            items[i] = .empty
        }
        count = writeIdx
    }

    /// Clear everything
    mutating func clear() {
        for i in 0..<count { items[i] = .empty }
        count = 0
    }

    /// Get the top (most recent or highest priority) note
    var top: NoteStackItem? {
        count > 0 ? items[0] : nil
    }
}
