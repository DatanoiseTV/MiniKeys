import AppKit
import Foundation

@MainActor
final class KeyboardMonitor {
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var mouseMonitor: Any?
    private let keyboardState: KeyboardState

    init(keyboardState: KeyboardState) {
        self.keyboardState = keyboardState
    }

    private func isTextFieldFocused() -> Bool {
        guard let firstResponder = NSApp.keyWindow?.firstResponder else { return false }
        // NSText is the field editor used by NSTextField; NSTextView covers SwiftUI TextField
        return firstResponder is NSText || firstResponder is NSTextView
    }

    func start() {
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if self.isTextFieldFocused() { return event }
            if KeyboardMapping.actions[event.keyCode] != nil {
                self.keyboardState.keyDown(keyCode: event.keyCode)
                return nil
            }
            return event
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self else { return event }
            if self.isTextFieldFocused() { return event }
            if KeyboardMapping.actions[event.keyCode] != nil {
                self.keyboardState.keyUp(keyCode: event.keyCode)
                return nil
            }
            return event
        }

        // Ensure clean sustain state on start
        keyboardState.forceSustainOff()

        // Click outside a text field -> resign first responder so keyboard works
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
            guard let window = NSApp.keyWindow else { return event }
            // Check if the click target is a text field; if not, resign focus
            if let view = window.contentView?.hitTest(event.locationInWindow) {
                let isTextField = view is NSText || view is NSTextView
                    || view.superview is NSTextField || view.superview is NSSearchField
                if !isTextField {
                    window.makeFirstResponder(nil)
                }
            }
            return event
        }
    }

    func stop() {
        if let monitor = keyDownMonitor {
            NSEvent.removeMonitor(monitor)
            keyDownMonitor = nil
        }
        if let monitor = keyUpMonitor {
            NSEvent.removeMonitor(monitor)
            keyUpMonitor = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        keyboardState.allNotesOff()
    }
}
