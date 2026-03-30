import Foundation
import Observation

enum QuantizeDivision: String, CaseIterable, Codable {
    case quarter, eighth, sixteenth, thirtysecond
    case dottedQuarter, dottedEighth, dottedSixteenth
    case tripletQuarter, tripletEighth, tripletSixteenth

    var displayName: String {
        switch self {
        case .quarter: "1/4"
        case .eighth: "1/8"
        case .sixteenth: "1/16"
        case .thirtysecond: "1/32"
        case .dottedQuarter: "1/4."
        case .dottedEighth: "1/8."
        case .dottedSixteenth: "1/16."
        case .tripletQuarter: "1/4T"
        case .tripletEighth: "1/8T"
        case .tripletSixteenth: "1/16T"
        }
    }

    var beatsPerStep: Double {
        switch self {
        case .quarter: 1.0
        case .eighth: 0.5
        case .sixteenth: 0.25
        case .thirtysecond: 0.125
        case .dottedQuarter: 1.5
        case .dottedEighth: 0.75
        case .dottedSixteenth: 0.375
        case .tripletQuarter: 2.0 / 3.0
        case .tripletEighth: 1.0 / 3.0
        case .tripletSixteenth: 1.0 / 6.0
        }
    }
}

@Observable
final class LiveQuantizer {
    var enabled = false
    var division: QuantizeDivision = .sixteenth
    var strength: Double = 100  // 0-100%
    var bpm: Double = 120
    var quantizeNoteOff: Bool = false

    // Use a high-precision reference time (mach_absolute_time based)
    private let clockStart: TimeInterval = ProcessInfo.processInfo.systemUptime

    /// Grid interval in seconds
    private var gridInterval: TimeInterval {
        let beatsPerSecond = bpm / 60.0
        return division.beatsPerStep / beatsPerSecond
    }

    /// Calculate delay to snap a note-on to the nearest grid point.
    func delayForNoteOn() -> TimeInterval {
        guard enabled, strength > 0, bpm > 0 else { return 0 }

        let grid = gridInterval
        guard grid > 0.001 else { return 0 } // safety: don't quantize at extreme speeds

        let now = ProcessInfo.processInfo.systemUptime - clockStart
        let phase = now.truncatingRemainder(dividingBy: grid)

        // Distance to the nearest grid boundary
        let distToNext = grid - phase
        let distToPrev = phase

        // Always delay forward to the next grid point, scaled by strength.
        // If we're very close to the previous grid point (within 10% of grid),
        // consider it "on beat" and don't delay.
        let threshold = grid * 0.1
        if distToPrev < threshold {
            // Close enough to previous beat — play now
            return 0
        }

        // Delay to next grid point, scaled by strength
        return distToNext * (strength / 100.0)
    }

    func delayForNoteOff() -> TimeInterval {
        guard enabled, quantizeNoteOff, strength > 0 else { return 0 }
        return delayForNoteOn()
    }
}
