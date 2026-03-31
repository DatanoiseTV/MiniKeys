import SwiftUI

struct DeviceBrowserView: View {
    @Bindable var dbManager: DeviceDBManager
    let onLoadDevice: (ControlLayout, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedManufacturer: String? = nil
    @State private var selectedDevice: DeviceFile? = nil
    @State private var loadedDevice: DeviceFile? = nil
    @State private var useNRPN = false
    @State private var searchText = ""

    private var filteredManufacturers: [String] {
        if searchText.isEmpty { return dbManager.index.manufacturers }
        let q = searchText.lowercased()
        return dbManager.index.manufacturers.filter { mfr in
            if mfr.lowercased().contains(q) { return true }
            return dbManager.index.devicesByManufacturer[mfr]?.contains { $0.device.lowercased().contains(q) } ?? false
        }
    }

    private var devicesForSelectedMfr: [DeviceFile] {
        guard let mfr = selectedManufacturer else { return [] }
        let devices = dbManager.index.devicesByManufacturer[mfr] ?? []
        if searchText.isEmpty || mfr.lowercased().contains(searchText.lowercased()) { return devices }
        let q = searchText.lowercased()
        return devices.filter { $0.device.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                // Search
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary)
                        .font(.system(size: 11))
                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(.caption))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.3))
                .cornerRadius(5)

                Spacer()

                // Status
                if dbManager.isLoading {
                    ProgressView().scaleEffect(0.6)
                    Text("Fetching...")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                } else if !dbManager.index.manufacturers.isEmpty {
                    let total = dbManager.index.devicesByManufacturer.values.reduce(0) { $0 + $1.count }
                    Text("\(total) devices")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }

                if dbManager.updateAvailable {
                    Text("Update available")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Button(action: { Task { await dbManager.fetchOrUpdate() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(dbManager.isLoading)
                .help(dbManager.index.manufacturers.isEmpty ? "Download database" : "Update")

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))

            if let err = dbManager.error {
                Text(err).font(.system(size: 10)).foregroundStyle(.red)
                    .padding(.horizontal, 12).padding(.bottom, 4)
            }

            Divider()

            if dbManager.index.manufacturers.isEmpty && !dbManager.isLoading {
                emptyState
            } else {
                // 3-column Finder-style layout
                HStack(spacing: 0) {
                    // Column 1: Manufacturers
                    VStack(spacing: 0) {
                        Text("Manufacturer")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                        List(filteredManufacturers, id: \.self, selection: $selectedManufacturer) { mfr in
                            HStack {
                                Text(mfr)
                                    .font(.system(.caption))
                                Spacer()
                                Text("\(dbManager.index.devicesByManufacturer[mfr]?.count ?? 0)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.tertiary)
                            }
                            .tag(mfr)
                        }
                        .listStyle(.plain)
                    }
                    .frame(width: 200)

                    Divider()

                    // Column 2: Devices
                    VStack(spacing: 0) {
                        Text("Device")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                        if selectedManufacturer != nil {
                            List(devicesForSelectedMfr, id: \.id) { device in
                                DeviceListRow(
                                    device: device,
                                    isSelected: selectedDevice?.id == device.id,
                                    onSelect: { selectDevice(device) }
                                )
                            }
                            .listStyle(.plain)
                        } else {
                            Spacer()
                            Text("Select a manufacturer")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                            Spacer()
                        }
                    }
                    .frame(width: 200)

                    Divider()

                    // Column 3: Preview
                    if let device = loadedDevice {
                        DevicePreviewPane(
                            device: device,
                            useNRPN: $useNRPN,
                            onLoad: {
                                let layout = dbManager.makeLayout(from: device, useNRPN: useNRPN)
                                let name = "\(device.manufacturer) - \(device.device)"
                                onLoadDevice(layout, name)
                                dismiss()
                            }
                        )
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "pianokeys")
                                .font(.system(size: 30))
                                .foregroundStyle(.quaternary)
                            Text("Select a device to preview")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(minWidth: 860, minHeight: 480)
        .onChange(of: selectedManufacturer) { _, _ in
            selectedDevice = nil
            loadedDevice = nil
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "externaldrive.badge.wifi")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Click the refresh button to download\nMIDI mappings for 300+ devices")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func selectDevice(_ device: DeviceFile) {
        selectedDevice = device
        loadedDevice = dbManager.loadDevice(device)
    }
}

// MARK: - Preview Pane

struct DevicePreviewPane: View {
    let device: DeviceFile
    @Binding var useNRPN: Bool
    let onLoad: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(device.manufacturer)
                    .font(.system(.caption))
                    .foregroundStyle(.secondary)
                Text(device.device)
                    .font(.system(.title3).bold())

                HStack(spacing: 10) {
                    let ccCount = device.parameters.filter(\.hasCC).count
                    let nrpnCount = device.parameters.filter(\.hasNRPN).count

                    Label("\(device.parameters.count)", systemImage: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if ccCount > 0 { CCBadge(text: "\(ccCount) CC", color: .blue) }
                    if nrpnCount > 0 { CCBadge(text: "\(nrpnCount) NRPN", color: .orange) }

                    Spacer()

                    if device.parameters.contains(where: \.hasNRPN) {
                        Toggle("NRPN", isOn: $useNRPN)
                            .toggleStyle(.checkbox)
                            .font(.system(.caption))
                    }

                    Button(action: onLoad) {
                        Label("Load", systemImage: "square.and.arrow.down")
                            .font(.system(.caption).bold())
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(12)

            Divider()

            // Parameter list
            List {
                ForEach(device.sections, id: \.self) { section in
                    Section {
                        ForEach(device.parameters.filter({ $0.section == section })) { param in
                            DeviceParamRow(param: param)
                        }
                    } header: {
                        Text(section.isEmpty ? "General" : section)
                            .font(.system(.caption2).bold())
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .frame(minWidth: 400)
    }
}

// MARK: - Rows & Badges

struct DeviceParamRow: View {
    let param: DeviceParameter

    var body: some View {
        HStack(spacing: 10) {
            Text(param.name)
                .font(.system(.caption))
                .lineLimit(1)
                .frame(minWidth: 100, alignment: .leading)

            if !param.description.isEmpty {
                Text(param.description)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if param.hasCC { CCBadge(text: "CC \(param.ccMSB ?? 0)", color: .blue) }
            if param.hasNRPN { CCBadge(text: "NRPN \(param.nrpnMSB ?? 0):\(param.nrpnLSB ?? 0)", color: .orange) }

            if !param.usage.isEmpty {
                Text(param.usage)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 140, alignment: .trailing)
            }
        }
    }
}

struct CCBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .cornerRadius(3)
    }
}

struct DeviceListRow: View {
    let device: DeviceFile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(device.device)
                    .font(.system(.caption))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                Spacer()
                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
