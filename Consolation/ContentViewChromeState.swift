import SwiftUI

extension ContentView {
    func cancelHoverHideTask() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    func revealTransientChromeIfNeeded() {
        guard isUIHidden else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            isUIHidden = false
        }
        #if os(macOS)
        window?.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = 1.0
        #endif
    }

    func cancelAutoHideChrome() {
        cancelHoverHideTask()
        revealTransientChromeIfNeeded()
    }
}

#Preview {
    ContentView(capture: CaptureSessionManager())
}
