import SwiftUI

@main
struct MiniKeysApp: App {
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
