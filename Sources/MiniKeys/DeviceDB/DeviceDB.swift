import Foundation

struct DeviceParameter: Identifiable {
    let id = UUID()
    let section: String
    let name: String
    let description: String
    let ccMSB: UInt8?
    let ccLSB: UInt8?
    let ccMin: UInt8
    let ccMax: UInt8
    let ccDefault: UInt8?
    let nrpnMSB: UInt8?
    let nrpnLSB: UInt8?
    let nrpnMin: UInt16
    let nrpnMax: UInt16
    let nrpnDefault: UInt16?
    let orientation: String
    let notes: String
    let usage: String

    var hasCC: Bool { ccMSB != nil }
    var hasNRPN: Bool { nrpnMSB != nil && nrpnLSB != nil }
    var is14BitNRPN: Bool { nrpnMax > 127 }
}

struct DeviceFile: Identifiable, Hashable {
    let id: String  // use relativePath as stable ID
    let manufacturer: String
    let device: String
    let relativePath: String
    var parameters: [DeviceParameter] = []

    static func == (lhs: DeviceFile, rhs: DeviceFile) -> Bool {
        lhs.relativePath == rhs.relativePath
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(relativePath)
    }

    var sections: [String] {
        var seen = Set<String>()
        return parameters.compactMap { p in
            if seen.contains(p.section) { return nil }
            seen.insert(p.section)
            return p.section
        }
    }
}

struct DeviceDBIndex {
    var manufacturers: [String] = []
    var devicesByManufacturer: [String: [DeviceFile]] = [:]
}
