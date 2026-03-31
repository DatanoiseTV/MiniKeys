import SwiftUI

@main
struct MiniKeysApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var midiEngine = MIDIEngine()
    @State private var keyboardState: KeyboardState

    init() {
        let engine = MIDIEngine()
        let state = KeyboardState(midiEngine: engine)
        _midiEngine = State(initialValue: engine)
        _keyboardState = State(initialValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(midiEngine)
                .environment(keyboardState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 660, height: 380)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var hasUnsavedChanges: (() -> Bool)?
    var onSaveRequested: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let hasChanges = hasUnsavedChanges, hasChanges() else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "Your preset has been modified. Save before quitting?"
        alert.addButton(withTitle: "Save & Quit")
        alert.addButton(withTitle: "Quit Without Saving")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            onSaveRequested?()
            return .terminateNow
        case .alertSecondButtonReturn:
            return .terminateNow
        default:
            return .terminateCancel
        }
    }
}
