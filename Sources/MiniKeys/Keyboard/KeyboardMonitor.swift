import AppKit
import Foundation

@MainActor
final class KeyboardMonitor {
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var flagsMonitor: Any?
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

        // Modifier keys (Left Shift for sustain)
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else { return event }
            if self.isTextFieldFocused() { return event }
            // Only respond when left shift key itself changes (keyCode 0x38)
            guard event.keyCode == 0x38 else { return event }
            // Check the device-independent flag for left shift specifically
            let leftShiftDown = event.modifierFlags.rawValue & UInt(NX_DEVICELSHIFTKEYMASK) != 0
            if leftShiftDown {
                self.keyboardState.keyDown(keyCode: 0x38)
            } else {
                self.keyboardState.keyUp(keyCode: 0x38)
            }
            return event
        }

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
        if let monitor = flagsMonitor {
            NSEvent.removeMonitor(monitor)
            flagsMonitor = nil
        }
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
        keyboardState.allNotesOff()
    }
}
