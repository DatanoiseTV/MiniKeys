import Foundation
import Observation

@Observable
@MainActor
final class DeviceDBManager {
    var index = DeviceDBIndex()
    var isLoading = false
    var error: String? = nil
    var lastUpdated: Date? = nil
    var updateAvailable = false
    var localCommit: String? = nil

    private let repoURL = "https://github.com/pencilresearch/midi.git"
    private let dbDirectory: URL

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        dbDirectory = appSupport.appendingPathComponent("MiniKeys/DeviceDB", isDirectory: true)
        if FileManager.default.fileExists(atPath: dbDirectory.path) {
            buildIndex()
            localCommit = getLocalCommit()
            Task { await checkForUpdates() }
        }
    }

    func fetchOrUpdate() async {
        isLoading = true
        error = nil

        do {
            if FileManager.default.fileExists(atPath: dbDirectory.appendingPathComponent(".git").path) {
                try await runGit(["pull", "--ff-only"], in: dbDirectory)
            } else {
                try? FileManager.default.removeItem(at: dbDirectory)
                try FileManager.default.createDirectory(at: dbDirectory.deletingLastPathComponent(), withIntermediateDirectories: true)
                try await runGit(["clone", "--depth", "1", repoURL, dbDirectory.path], in: dbDirectory.deletingLastPathComponent())
            }
            buildIndex()
            localCommit = getLocalCommit()
            updateAvailable = false
            lastUpdated = Date()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func checkForUpdates() async {
        guard FileManager.default.fileExists(atPath: dbDirectory.appendingPathComponent(".git").path) else { return }
        do {
            let remote = try await runGitOutput(["ls-remote", "origin", "HEAD"], in: dbDirectory)
            let remoteCommit = String(remote.prefix(while: { !$0.isWhitespace }))
            if let local = localCommit, !local.isEmpty, !remoteCommit.isEmpty, local != remoteCommit {
                updateAvailable = true
            }
        } catch {
            // Silently fail — network might not be available
        }
    }

    private func getLocalCommit() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["rev-parse", "HEAD"]
        process.currentDirectoryURL = dbDirectory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }

    private func runGit(_ args: [String], in directory: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardError = pipe
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: data, encoding: .utf8) ?? "Unknown git error"
            throw NSError(domain: "DeviceDB", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: msg])
        }
    }

    private func runGitOutput(_ args: [String], in directory: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.currentDirectoryURL = directory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(domain: "DeviceDB", code: Int(process.terminationStatus))
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func buildIndex() {
        var idx = DeviceDBIndex()
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(at: dbDirectory, includingPropertiesForKeys: [.isDirectoryKey]) else { return }

        for item in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }

            let dirName = item.lastPathComponent
            if dirName.hasPrefix(".") { continue }

            guard let files = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil) else { continue }
            let csvFiles = files.filter { $0.pathExtension == "csv" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard !csvFiles.isEmpty else { continue }

            idx.manufacturers.append(dirName)
            idx.devicesByManufacturer[dirName] = csvFiles.map { csv in
                let path = "\(dirName)/\(csv.lastPathComponent)"
                return DeviceFile(
                    id: path,
                    manufacturer: dirName,
                    device: csv.deletingPathExtension().lastPathComponent,
                    relativePath: path
                )
            }
        }

        index = idx
    }

    func loadDevice(_ device: DeviceFile) -> DeviceFile {
        let csvURL = dbDirectory.appendingPathComponent(device.relativePath)
        guard let data = try? String(contentsOf: csvURL, encoding: .utf8) else { return device }

        var result = device
        let lines = data.components(separatedBy: .newlines)

        // Skip header line
        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let param = parseCSVLine(trimmed) {
                result.parameters.append(param)
            }
        }

        return result
    }

    private func parseCSVLine(_ line: String) -> DeviceParameter? {
        let fields = parseCSVFields(line)
        guard fields.count >= 16 else { return nil }

        return DeviceParameter(
            section: fields[2],
            name: fields[3],
            description: fields[4],
            ccMSB: UInt8(fields[5]),
            ccLSB: UInt8(fields[6]),
            ccMin: UInt8(fields[7]) ?? 0,
            ccMax: UInt8(fields[8]) ?? 127,
            ccDefault: UInt8(fields[9]),
            nrpnMSB: UInt8(fields[10]),
            nrpnLSB: UInt8(fields[11]),
            nrpnMin: UInt16(fields[12]) ?? 0,
            nrpnMax: UInt16(fields[13]) ?? 127,
            nrpnDefault: UInt16(fields[14]),
            orientation: fields.count > 15 ? fields[15] : "",
            notes: fields.count > 16 ? fields[16] : "",
            usage: fields.count > 17 ? fields[17] : ""
        )
    }

    /// Parse CSV fields handling quoted values with commas
    private func parseCSVFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false

        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    /// Convert device parameters to a ControlLayout
    func makeLayout(from device: DeviceFile, useNRPN: Bool = false) -> ControlLayout {
        var layout = ControlLayout()

        // Create groups from sections
        var sectionGroups: [String: UUID] = [:]
        for section in device.sections {
            guard !section.isEmpty else { continue }
            let group = CCGroup(label: section)
            layout.groups.append(group)
            sectionGroups[section] = group.id
        }

        for param in device.parameters {
            let wantNRPN = useNRPN && param.hasNRPN
            let hasSource = wantNRPN ? param.hasNRPN : param.hasCC
            guard hasSource else { continue }

            // Determine control type from usage string
            let controlType = inferControlType(from: param)

            var control = CCControl(
                type: controlType,
                label: param.name,
                groupID: sectionGroups[param.section]
            )

            if wantNRPN {
                control.messageType = .nrpn
                control.nrpnMSB = param.nrpnMSB ?? 0
                control.nrpnLSB = param.nrpnLSB ?? 0
                control.minValue = UInt8(min(param.nrpnMin, 127))
                control.maxValue = UInt8(min(param.nrpnMax, 127))
                control.nrpnMaxValue = param.nrpnMax
                control.currentValue = UInt8(min(param.nrpnDefault ?? param.nrpnMin, 127))
            } else {
                control.messageType = .cc
                control.ccNumber = param.ccMSB ?? 0
                control.minValue = param.ccMin
                control.maxValue = param.ccMax
                control.currentValue = param.ccDefault ?? param.ccMin
            }

            // For select type, parse usage into options
            if controlType == .select {
                control.options = parseUsageOptions(param.usage)
                control.selectedOptionID = control.options.first?.id
            }

            layout.controls.append(control)
        }

        return layout
    }

    private func inferControlType(from param: DeviceParameter) -> CCControlType {
        let usage = param.usage.lowercased()

        // Check for discrete options pattern: "0: X; 1: Y" or "0-63: Off; 64-127: On"
        if usage.contains(";") && usage.contains(":") {
            let parts = usage.components(separatedBy: ";")
            // If it's just on/off, use toggle
            if parts.count == 2 {
                let lower = parts.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
                if lower.contains(where: { $0.contains("off") }) && lower.contains(where: { $0.contains("on") }) {
                    return .toggle
                }
            }
            // More than 2 options -> select
            if parts.count >= 2 {
                return .select
            }
        }

        return .knob
    }

    private func parseUsageOptions(_ usage: String) -> [SelectOption] {
        let parts = usage.components(separatedBy: ";")
        var options: [SelectOption] = []

        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard let colonIdx = trimmed.firstIndex(of: ":") else { continue }
            let valueStr = trimmed[trimmed.startIndex..<colonIdx].trimmingCharacters(in: .whitespaces)
            let label = trimmed[trimmed.index(after: colonIdx)...].trimmingCharacters(in: .whitespaces)

            // Parse value: could be "0", "0-63", "0~127"
            if let val = UInt8(valueStr) {
                options.append(SelectOption(label: label, value: val))
            } else if valueStr.contains("-") {
                let range = valueStr.components(separatedBy: "-")
                if let start = UInt8(range.first ?? "") {
                    options.append(SelectOption(label: label, value: start))
                }
            } else if valueStr.contains("~") {
                let range = valueStr.components(separatedBy: "~")
                if let start = UInt8(range.first ?? "") {
                    options.append(SelectOption(label: label, value: start))
                }
            }
        }

        return options
    }
}
