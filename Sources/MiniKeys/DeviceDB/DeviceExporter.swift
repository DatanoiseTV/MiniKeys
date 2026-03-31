import AppKit
import Foundation

struct DeviceExporter {
    /// Export a ControlLayout to pencilresearch/midi CSV format.
    static func exportCSV(layout: ControlLayout, manufacturer: String, device: String) -> String {
        let header = "manufacturer,device,section,parameter_name,parameter_description,cc_msb,cc_lsb,cc_min_value,cc_max_value,cc_default_value,nrpn_msb,nrpn_lsb,nrpn_min_value,nrpn_max_value,nrpn_default_value,orientation,notes,usage"

        var lines = [header]

        // Build a group name lookup
        let groupNames: [UUID: String] = Dictionary(
            uniqueKeysWithValues: layout.groups.map { ($0.id, $0.label) }
        )

        for control in layout.controls {
            let section = control.groupID.flatMap { groupNames[$0] } ?? "General"

            // Build usage string from select options
            let usage: String
            if control.type == .select && !control.options.isEmpty {
                usage = control.options.map { option in
                    "\(option.value): \(option.label)"
                }.joined(separator: "; ")
            } else if control.type == .toggle {
                usage = "\(control.minValue): Off; \(control.maxValue): On"
            } else if control.type == .button {
                usage = "\(control.minValue)~\(control.maxValue): \(control.label)"
            } else {
                usage = "\(control.minValue)~\(control.maxValue): \(control.label)"
            }

            // CC fields
            let ccMSB: String
            let ccLSB = ""
            let ccMin: String
            let ccMax: String
            let ccDefault: String

            if control.messageType == .cc || control.type == .adsr {
                ccMSB = "\(control.ccNumber)"
                ccMin = "\(control.minValue)"
                ccMax = "\(control.maxValue)"
                ccDefault = "\(control.currentValue)"
            } else {
                ccMSB = ""
                ccMin = ""
                ccMax = ""
                ccDefault = ""
            }

            // NRPN fields
            let nrpnMSB: String
            let nrpnLSB: String
            let nrpnMin: String
            let nrpnMax: String
            let nrpnDefault: String

            if control.messageType == .nrpn {
                nrpnMSB = "\(control.nrpnMSB)"
                nrpnLSB = "\(control.nrpnLSB)"
                nrpnMin = "\(control.minValue)"
                nrpnMax = "\(control.nrpnMaxValue)"
                nrpnDefault = "\(control.currentValue)"
            } else {
                nrpnMSB = ""
                nrpnLSB = ""
                nrpnMin = ""
                nrpnMax = ""
                nrpnDefault = ""
            }

            let orientation = "0-based"
            let notes = ""

            // Handle ADSR: export 4 separate rows
            if control.type == .adsr {
                let adsrNames = ["Attack", "Decay", "Sustain", "Release"]
                for i in 0..<4 {
                    let row = csvRow(
                        manufacturer: manufacturer,
                        device: device,
                        section: section,
                        name: "\(control.label) \(adsrNames[i])",
                        description: "",
                        ccMSB: "\(control.adsrCCs[i])",
                        ccLSB: "",
                        ccMin: "0",
                        ccMax: "127",
                        ccDefault: "\(control.adsrValues[i])",
                        nrpnMSB: "", nrpnLSB: "", nrpnMin: "", nrpnMax: "", nrpnDefault: "",
                        orientation: orientation,
                        notes: "",
                        usage: "0~127: \(adsrNames[i])"
                    )
                    lines.append(row)
                }
                continue
            }

            // Handle X/Y pad: export 2 rows
            if control.type == .xyPad {
                let rowX = csvRow(
                    manufacturer: manufacturer, device: device, section: section,
                    name: "\(control.label) X", description: "",
                    ccMSB: "\(control.ccNumber)", ccLSB: "",
                    ccMin: "0", ccMax: "127", ccDefault: "\(control.currentValue)",
                    nrpnMSB: "", nrpnLSB: "", nrpnMin: "", nrpnMax: "", nrpnDefault: "",
                    orientation: orientation, notes: "", usage: "0~127: X axis"
                )
                let rowY = csvRow(
                    manufacturer: manufacturer, device: device, section: section,
                    name: "\(control.label) Y", description: "",
                    ccMSB: "\(control.yCCNumber)", ccLSB: "",
                    ccMin: "0", ccMax: "127", ccDefault: "\(control.yValue)",
                    nrpnMSB: "", nrpnLSB: "", nrpnMin: "", nrpnMax: "", nrpnDefault: "",
                    orientation: orientation, notes: "", usage: "0~127: Y axis"
                )
                lines.append(rowX)
                lines.append(rowY)
                continue
            }

            let row = csvRow(
                manufacturer: manufacturer, device: device, section: section,
                name: control.label, description: "",
                ccMSB: ccMSB, ccLSB: ccLSB,
                ccMin: ccMin, ccMax: ccMax, ccDefault: ccDefault,
                nrpnMSB: nrpnMSB, nrpnLSB: nrpnLSB,
                nrpnMin: nrpnMin, nrpnMax: nrpnMax, nrpnDefault: nrpnDefault,
                orientation: orientation, notes: notes, usage: usage
            )
            lines.append(row)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvRow(
        manufacturer: String, device: String, section: String,
        name: String, description: String,
        ccMSB: String, ccLSB: String,
        ccMin: String, ccMax: String, ccDefault: String,
        nrpnMSB: String, nrpnLSB: String,
        nrpnMin: String, nrpnMax: String, nrpnDefault: String,
        orientation: String, notes: String, usage: String
    ) -> String {
        let fields = [
            escapeCSV(manufacturer), escapeCSV(device), escapeCSV(section),
            escapeCSV(name), escapeCSV(description),
            ccMSB, ccLSB, ccMin, ccMax, ccDefault,
            nrpnMSB, nrpnLSB, nrpnMin, nrpnMax, nrpnDefault,
            escapeCSV(orientation), escapeCSV(notes), escapeCSV(usage)
        ]
        return fields.joined(separator: ",")
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    /// Show a save panel and export the layout as CSV
    static func saveCSV(layout: ControlLayout, manufacturer: String, device: String) {
        let csv = exportCSV(layout: layout, manufacturer: manufacturer, device: device)

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(device).csv"
        panel.title = "Export MIDI Mapping"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}
