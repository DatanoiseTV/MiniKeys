import SwiftUI

/// Shows a brief flash when a control's value changes from external MIDI input.
/// Wrap any control view with this to get activity feedback.
struct ActivityFlash: ViewModifier {
    let controlID: UUID
    let currentValue: UInt8

    @State private var isFlashing = false
    @State private var lastValue: UInt8 = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 2)
                    .opacity(isFlashing ? 0.6 : 0)
                    .animation(.easeOut(duration: 0.3), value: isFlashing)
            )
            .onChange(of: currentValue) { oldVal, newVal in
                if oldVal != newVal {
                    isFlashing = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isFlashing = false
                    }
                }
            }
    }
}

extension View {
    func activityFlash(controlID: UUID, value: UInt8) -> some View {
        modifier(ActivityFlash(controlID: controlID, currentValue: value))
    }
}
