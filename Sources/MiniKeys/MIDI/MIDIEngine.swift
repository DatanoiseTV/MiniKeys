import CoreMIDI
import Foundation
import Observation

struct MIDIOutput: Identifiable, Hashable {
    let id: MIDIEndpointRef
    let name: String
    let isVirtual: Bool
}

struct MIDIInput: Identifiable, Hashable {
    let id: MIDIEndpointRef
    let name: String
}

@Observable
final class MIDIEngine {
    @ObservationIgnored private nonisolated(unsafe) var _client: MIDIClientRef = 0
    @ObservationIgnored private nonisolated(unsafe) var _virtualSource: MIDIEndpointRef = 0
    @ObservationIgnored private nonisolated(unsafe) var _outputPort: MIDIPortRef = 0
    @ObservationIgnored private nonisolated(unsafe) var _inputPort: MIDIPortRef = 0
    @ObservationIgnored nonisolated(unsafe) var _selectedDest: MIDIEndpointRef = 0

    var destinations: [MIDIOutput] = []
    var sources: [MIDIInput] = []
    var selectedDestinationID: MIDIEndpointRef? = nil {
        didSet { _selectedDest = selectedDestinationID ?? 0 }
    }
    var selectedSourceID: MIDIEndpointRef? = nil {
        didSet { updateInputConnection(old: oldValue, new: selectedSourceID) }
    }
    var channel: UInt8 = 0

    /// Callback for incoming MIDI note-on/off from external input
    var onExternalNoteOn: ((UInt8, UInt8) -> Void)?   // (note, velocity)
    var onExternalNoteOff: ((UInt8) -> Void)?          // (note)
    var onExternalCC: ((UInt8, UInt8) -> Void)?         // (cc, value)

    init() {
        setupMIDI()
    }

    private func setupMIDI() {
        let status = MIDIClientCreateWithBlock("MiniKeys" as CFString, &_client) { [weak self] notification in
            if notification.pointee.messageID == .msgSetupChanged {
                Task { @MainActor in
                    self?.refreshDestinations()
                    self?.refreshSources()
                }
            }
        }
        guard status == noErr else {
            print("Failed to create MIDI client: \(status)")
            return
        }

        MIDISourceCreateWithProtocol(_client, "MiniKeys" as CFString, ._1_0, &_virtualSource)
        MIDIOutputPortCreate(_client, "MiniKeys Output" as CFString, &_outputPort)

        // Input port for receiving from external devices
        MIDIInputPortCreateWithProtocol(_client, "MiniKeys Input" as CFString, ._1_0, &_inputPort) { [weak self] eventList, _ in
            self?.handleIncomingMIDI(eventList)
        }

        refreshDestinations()
        refreshSources()
    }

    func refreshDestinations() {
        var newDests: [MIDIOutput] = []
        let count = MIDIGetNumberOfDestinations()
        for i in 0..<count {
            let endpoint = MIDIGetDestination(i)
            var cfName: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfName)
            let name = (cfName?.takeRetainedValue() as String?) ?? "Unknown"
            if name != "MiniKeys" {
                newDests.append(MIDIOutput(id: endpoint, name: name, isVirtual: false))
            }
        }
        destinations = newDests
    }

    func refreshSources() {
        var newSources: [MIDIInput] = []
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let endpoint = MIDIGetSource(i)
            var cfName: Unmanaged<CFString>?
            MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &cfName)
            let name = (cfName?.takeRetainedValue() as String?) ?? "Unknown"
            if name != "MiniKeys" {
                newSources.append(MIDIInput(id: endpoint, name: name))
            }
        }
        sources = newSources
    }

    private func updateInputConnection(old: MIDIEndpointRef?, new: MIDIEndpointRef?) {
        if let old, old != 0 {
            MIDIPortDisconnectSource(_inputPort, old)
        }
        if let new, new != 0 {
            MIDIPortConnectSource(_inputPort, new, nil)
        }
    }

    private nonisolated func handleIncomingMIDI(_ eventListPtr: UnsafePointer<MIDIEventList>) {
        let eventList = eventListPtr.pointee
        var packet = eventList.packet

        for _ in 0..<eventList.numPackets {
            let wordCount = packet.wordCount
            if wordCount >= 1 {
                let word = packet.words.0
                let messageType = (word >> 28) & 0x0F
                if messageType == 0x2 { // MIDI 1.0 channel voice
                    let status = UInt8((word >> 16) & 0xF0)
                    let data1 = UInt8((word >> 8) & 0x7F)
                    let data2 = UInt8(word & 0x7F)

                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        switch status {
                        case 0x90: // Note On
                            if data2 > 0 {
                                self.onExternalNoteOn?(data1, data2)
                            } else {
                                self.onExternalNoteOff?(data1)
                            }
                        case 0x80: // Note Off
                            self.onExternalNoteOff?(data1)
                        case 0xB0: // CC
                            self.onExternalCC?(data1, data2)
                        default:
                            break
                        }
                    }
                }
            }
            let current = packet
            withUnsafePointer(to: current) { ptr in
                packet = MIDIEventPacketNext(ptr).pointee
            }
        }
    }

    nonisolated func sendNoteOn(note: UInt8, velocity: UInt8, channel: UInt8) {
        let message: UInt32 = UInt32(0x20900000)
            | (UInt32(channel & 0x0F) << 16)
            | (UInt32(note) << 8)
            | UInt32(velocity)
        sendMessage(message)
    }

    nonisolated func sendNoteOff(note: UInt8, channel: UInt8) {
        let message: UInt32 = UInt32(0x20800000)
            | (UInt32(channel & 0x0F) << 16)
            | (UInt32(note) << 8)
        sendMessage(message)
    }

    nonisolated func sendCC(controller: UInt8, value: UInt8, channel: UInt8) {
        let message: UInt32 = UInt32(0x20B00000)
            | (UInt32(channel & 0x0F) << 16)
            | (UInt32(controller) << 8)
            | UInt32(value)
        sendMessage(message)
    }

    /// Send NRPN message: CC99=msb, CC98=lsb, CC6=valueMSB, CC38=valueLSB
    nonisolated func sendNRPN(msb: UInt8, lsb: UInt8, value: UInt16, channel: UInt8) {
        let valueMSB = UInt8((value >> 7) & 0x7F)
        let valueLSB = UInt8(value & 0x7F)
        sendCC(controller: 99, value: msb, channel: channel)
        sendCC(controller: 98, value: lsb, channel: channel)
        sendCC(controller: 6, value: valueMSB, channel: channel)
        sendCC(controller: 38, value: valueLSB, channel: channel)
    }

    /// Send 7-bit NRPN (value 0-127, sent as MSB only with LSB=0)
    nonisolated func sendNRPN7(msb: UInt8, lsb: UInt8, value: UInt8, channel: UInt8) {
        sendCC(controller: 99, value: msb, channel: channel)
        sendCC(controller: 98, value: lsb, channel: channel)
        sendCC(controller: 6, value: value, channel: channel)
    }

    private nonisolated func sendMessage(_ word: UInt32) {
        var word = word
        let src = _virtualSource
        let port = _outputPort
        let dest = _selectedDest

        withUnsafePointer(to: &word) { wordPtr in
            wordPtr.withMemoryRebound(to: UInt32.self, capacity: 1) { ptr in
                var eventList = MIDIEventList()
                var packet = MIDIEventListInit(&eventList, ._1_0)
                packet = MIDIEventListAdd(&eventList, MemoryLayout<MIDIEventList>.size, packet, 0, 1, ptr)

                if src != 0 {
                    MIDIReceivedEventList(src, &eventList)
                }

                if dest != 0 && port != 0 {
                    MIDISendEventList(port, dest, &eventList)
                }
            }
        }
    }

    deinit {
        if _virtualSource != 0 {
            MIDIEndpointDispose(_virtualSource)
        }
        if _client != 0 {
            MIDIClientDispose(_client)
        }
    }
}
