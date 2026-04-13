import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct ContentView: View {
    @StateObject var capture = CaptureSessionManager()
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @State var window: NSWindow?
    #endif
    @State private var isUIHidden = false
    @State private var hoverTask: Task<Void, Never>?
    @State var playbackControlsOffset = CGSize.zero
    @State var playbackControlsSize = CGSize.zero
    @State var previewSize = CGSize.zero
    @State var isPlaybackControlsInteractionActive = false
    @State var isPlaybackControlsHoverActive = false
    @GestureState private var playbackControlsDragOffset = CGSize.zero
    #if os(iOS)
    @State var isClassicAspectFillEnabled = false
    #endif

    #if DEBUG
    @State private var showDeviceDebug = false
    #endif

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                CaptureVideoPreview(
                    session: capture.session,
                    isRunning: capture.state == .running,
                    isClassicAspectFillEnabled: isIPadClassicAspectFillActive
                ) {
                    #if os(macOS)
                    zoomWindowToVideoAspectIfPossible()
                    #endif
                }
                    .ignoresSafeArea()

                if !isUIHidden {
                    viewerChrome
                        .transition(.opacity)
                }
            }
            .onAppear { setPreviewSize(proxy.size) }
            .onChange(of: proxy.size) { _, size in setPreviewSize(size) }
        }
        .frame(minWidth: 480, minHeight: 270)
        .background {
            #if os(macOS)
            WindowAccessor(window: $window)
            #endif
        }
        .onChange(of: capture.videoSize) { _, size in
            #if os(macOS)
            updateWindowAspectRatio(for: size)
            #endif
        }
        .onChange(of: capture.state) { oldState, state in
            PlaybackDisplayWakeLock.setActive(state == .running)
            if state != .running {
                cancelAutoHideChrome()
            }
            if oldState != .running, state == .running {
                #if os(macOS)
                loadSavedPlaybackControlsPosition()
                #endif
                resetHoverTimer()
            }
            #if os(macOS)
            if state == .running {
                updateWindowAspectRatio(for: capture.videoSize)
            } else {
                resetWindowAspectRatio()
            }
            #endif
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            guard let exited = notification.object as? NSWindow,
                  let window,
                  exited === window,
                  capture.state == .running
            else { return }
            // Defer until after AppKit restores the window frame from the pre-full-screen session.
            DispatchQueue.main.async {
                updateWindowAspectRatio(for: capture.videoSize)
            }
        }
        #endif
        #if os(macOS)
        .onContinuousHover(coordinateSpace: .local) { _ in
            resetHoverTimer()
        }
        #endif
        #if os(iOS)
        .simultaneousGesture(
            TapGesture().onEnded {
                guard capture.state == .running else { return }
                resetHoverTimer()
            }
        )
        #endif
        .onAppear {
            PlaybackDisplayWakeLock.setActive(false)
            resetHoverTimer()
            capture.refreshMediaCaptureAuthorizationStatuses()
        }
        .onDisappear {
            PlaybackDisplayWakeLock.setActive(false)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                capture.refreshMediaCaptureAuthorizationStatuses()
            }
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: .playbackSizeCommand)) { notification in
            guard let scale = notification.object as? CGFloat else { return }
            resizeWindowToPlaybackScale(scale)
        }
        #endif
        .background {
            Button("") {
                if capture.state == .running {
                    capture.setAudioMuted(!capture.isAudioMuted)
                }
            }
            .keyboardShortcut("m", modifiers: [])
            .hidden()
        }
        #if os(macOS)
        .background {
            Group {
                Button("") {
                    handleSpaceOrKPlaybackShortcut()
                }
                .keyboardShortcut(.space, modifiers: [])
                .hidden()

                Button("") {
                    handleSpaceOrKPlaybackShortcut()
                }
                .keyboardShortcut("k", modifiers: [])
                .hidden()

                Button("") {
                    guard let window else { return }
                    if window.styleMask.contains(.fullScreen) {
                        window.toggleFullScreen(nil)
                    }
                }
                .keyboardShortcut(.cancelAction)
                .hidden()

                Button("") {
                    window?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [])
                .hidden()

                Button("") {
                    zoomWindowToVideoAspectIfPossible()
                }
                .keyboardShortcut("z", modifiers: [])
                .hidden()
            }
        }
        #endif
        #if DEBUG
        .sheet(isPresented: $showDeviceDebug) {
            CaptureDeviceDebugView()
        }
        .background {
            Button("") { showDeviceDebug = true }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                .hidden()
        }       
        #endif
    }

}

extension ContentView {
    var viewerChrome: some View {
        VStack {
            Spacer()

            if statusRequiresInteraction {
                statusPanel
            }

            Spacer()

            if capture.state == .running {
                playbackControls
            }
        }
    }

    var statusPanel: some View {
        VStack(spacing: 16) {
            CaptureStatusLine(
                state: capture.state,
                isExternalCaptureDeviceConnected: capture.isExternalCaptureDeviceConnected,
                externalCaptureDeviceName: capture.externalCaptureDeviceName,
                statusMessage: capture.statusMessage
            )

            if capture.mediaPermissionNotice != .none,
               capture.state != .requestingPermission {
                CaptureMediaPermissionEducationNotice(notice: capture.mediaPermissionNotice)
            }

            if canStartWatching {
                PlaybackToolbarIconButton(
                    systemName: "play.fill",
                    accessibilityLabel: "Start Watching",
                    dimension: 72,
                    action: { Task { await capture.startWatching() } }
                )
                .keyboardShortcut(.defaultAction)
                .disabled(capture.state == .requestingPermission)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .shadow(radius: 10)
        .panelLiquidGlass(cornerRadius: 16)
    }

    var statusRequiresInteraction: Bool {
        switch capture.state {
        case .running: return false
        default: return true
        }
    }

    var canStartWatching: Bool {
        guard capture.isExternalCaptureDeviceConnected else { return false }

        switch capture.state {
        case .ready, .idle, .noDevice:
            return true
        case .requestingPermission, .running, .failed:
            return false
        }
    }

    var playbackControlsCurrentOffset: CGSize {
        clampedPlaybackControlsOffset(CGSize(
            width: playbackControlsOffset.width + playbackControlsDragOffset.width,
            height: playbackControlsOffset.height + playbackControlsDragOffset.height
        ))
    }

    var playbackControlsDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($playbackControlsDragOffset) { value, state, _ in
                state = value.translation
            }
            .onChanged { _ in
                guard !isPlaybackControlsInteractionActive else { return }
                isPlaybackControlsInteractionActive = true
                cancelHoverHideTask()
                revealTransientChromeIfNeeded()
            }
            .onEnded { value in
                playbackControlsOffset = clampedPlaybackControlsOffset(CGSize(
                    width: playbackControlsOffset.width + value.translation.width,
                    height: playbackControlsOffset.height + value.translation.height
                ))
                PlaybackControlsUserDefaults.savePosition(playbackControlsOffset)
                isPlaybackControlsInteractionActive = false
                resetHoverTimer()
            }
    }

    var playbackControlsBottomPadding: CGFloat { 24 }

    func setPreviewSize(_ size: CGSize) {
        guard previewSize != size else { return }
        previewSize = size
        clampPlaybackControlsToPreview()
    }

    func setPlaybackControlsSize(_ size: CGSize) {
        guard playbackControlsSize != size else { return }
        playbackControlsSize = size
        clampPlaybackControlsToPreview()
    }

    func clampPlaybackControlsToPreview() {
        playbackControlsOffset = clampedPlaybackControlsOffset(playbackControlsOffset)
    }

    func loadSavedPlaybackControlsPosition() {
        guard let position = PlaybackControlsUserDefaults.loadPosition() else {
            playbackControlsOffset = .zero
            return
        }

        playbackControlsOffset = clampedPlaybackControlsOffset(position)
    }

    func clampedPlaybackControlsOffset(_ offset: CGSize) -> CGSize {
        guard previewSize.width > 0,
              previewSize.height > 0,
              playbackControlsSize.width > 0,
              playbackControlsSize.height > 0
        else {
            return offset
        }

        let horizontalLimit = max(0, (previewSize.width - playbackControlsSize.width) / 2)
        let maximumY = playbackControlsBottomPadding
        let minimumY = min(0, playbackControlsSize.height + playbackControlsBottomPadding - previewSize.height)

        return CGSize(
            width: min(max(offset.width, -horizontalLimit), horizontalLimit),
            height: min(max(offset.height, minimumY), maximumY)
        )
    }

    /// **Space** / **K**: stop while running; start when idle (same rules as the Start Watching button).
    func handleSpaceOrKPlaybackShortcut() {
        if capture.state == .running {
            capture.stopWatching()
        } else if canStartWatching, capture.state != .requestingPermission {
            Task { await capture.startWatching() }
        }
    }

    /// Auto-hide overlays and traffic-light dimming only apply while actively watching.
    func resetHoverTimer() {
        guard !isPlaybackControlsInteractionActive, !isPlaybackControlsHoverActive else {
            cancelHoverHideTask()
            revealTransientChromeIfNeeded()
            return
        }

        guard capture.state == .running else {
            cancelAutoHideChrome()
            return
        }

        cancelHoverHideTask()
        revealTransientChromeIfNeeded()

        hoverTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard capture.state == .running else { return }
                withAnimation(.easeInOut(duration: 0.5)) {
                    isUIHidden = true
                }
                #if os(macOS)
                window?.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = 0.0
                NSCursor.setHiddenUntilMouseMoves(true)
                #endif
            }
        }
    }

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
    ContentView()
}
