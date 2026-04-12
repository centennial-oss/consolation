//
//  ContentView.swift
//  Consolation
//
//  Created by James Ranson on 4/12/26.
//

import SwiftUI
#if os(macOS)
import AppKit

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
            view.window?.isMovableByWindowBackground = true
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif

struct ContentView: View {
    @StateObject private var capture = CaptureSessionManager()
    #if os(macOS)
    @State private var window: NSWindow?
    #endif
    @State private var isUIHidden = false
    @State private var hoverTask: Task<Void, Never>?

    #if DEBUG
    @State private var showDeviceDebug = false
    #endif

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            CaptureVideoPreview(session: capture.session, isRunning: capture.state == .running)
                .ignoresSafeArea()

            if !isUIHidden {
                VStack {
                    Spacer()

                    if statusRequiresInteraction {
                        VStack(spacing: 16) {
                            statusText

                            if canStartWatching {
                                Button("Start Watching") {
                                    Task { await capture.startWatching() }
                                }
                                .keyboardShortcut(.defaultAction)
                                .buttonStyle(.borderedProminent)
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
                        .gesture(DragGesture())
                    }

                    Spacer()

                    if capture.state == .running {
                        HStack(spacing: 16) {
                            Toggle(isOn: Binding(
                                get: { capture.isAudioMuted },
                                set: { capture.setAudioMuted($0) }
                            )) {
                                Text("Mute audio")
                            }
                            .toggleStyle(.switch)

                            Button("Stop Watching", role: .none) {
                                capture.stopWatching()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        }
                        .shadow(radius: 8)
                        .padding(.bottom, 24)
                        .gesture(DragGesture())
                    }
                }
                .transition(.opacity)
            }
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
        .onChange(of: capture.state) { _, state in
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
        .onContinuousHover(coordinateSpace: .local) { _ in
            resetHoverTimer()
        }
        .onAppear {
            resetHoverTimer()
        }
        .onTapGesture(count: 2) {
            #if os(macOS)
            zoomWindowToVideoAspectIfPossible()
            #endif
        }
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

    @ViewBuilder
    private var statusText: some View {
        switch capture.state {
        case .idle:
            if capture.isExternalCaptureDeviceConnected {
                Text("Press Start Watching to view your capture device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect a USB video capture device. Consolation will detect it automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .requestingPermission:
            Text("Requesting camera access…")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .noDevice:
            Text("No capture device found.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .ready:
            Text("Ready.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .running:
            if let name = capture.statusMessage {
                Text("Watching: \(name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Watching live input.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var statusRequiresInteraction: Bool {
        switch capture.state {
        case .running: return false
        default: return true
        }
    }

    private var canStartWatching: Bool {
        capture.state == .ready || capture.state == .idle || capture.isExternalCaptureDeviceConnected
    }

    /// **Space** / **K**: stop while running; start when idle (same rules as the Start Watching button).
    private func handleSpaceOrKPlaybackShortcut() {
        if capture.state == .running {
            capture.stopWatching()
        } else if canStartWatching, capture.state != .requestingPermission {
            Task { await capture.startWatching() }
        }
    }

    private func resetHoverTimer() {
        hoverTask?.cancel()

        if isUIHidden {
            withAnimation(.easeInOut(duration: 0.3)) {
                isUIHidden = false
            }
            #if os(macOS)
            window?.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = 1.0
            #endif
        }

        hoverTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
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
}

#if os(macOS)
private extension ContentView {
    /// Double-click and **Z**: fit the window to the video aspect in the visible screen.
    /// When already fit, toggles native zoom (`NSWindow.zoom`).
    func zoomWindowToVideoAspectIfPossible() {
        guard let window else { return }
        guard let screen = window.screen else {
            window.zoom(nil)
            return
        }

        let visibleFrame = screen.visibleFrame
        let aspect = capture.videoSize ?? CGSize(width: 16, height: 9)
        let aspectWidth = aspect.width == 0 ? 16 : aspect.width
        let aspectHeight = aspect.height == 0 ? 9 : aspect.height
        let ratio = aspectWidth / aspectHeight

        var targetWidth = visibleFrame.width
        var targetHeight = targetWidth / ratio

        if targetHeight > visibleFrame.height {
            targetHeight = visibleFrame.height
            targetWidth = targetHeight * ratio
        }

        let targetX = visibleFrame.minX + (visibleFrame.width - targetWidth) / 2
        let targetY = visibleFrame.minY + (visibleFrame.height - targetHeight) / 2
        let targetRect = NSRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)

        if abs(window.frame.width - targetWidth) < 10 {
            window.zoom(nil)
        } else {
            window.setFrame(targetRect, display: true, animate: true)
        }
    }

    func updateWindowAspectRatio(for videoSize: CGSize?) {
        guard capture.state == .running else {
            resetWindowAspectRatio()
            return
        }
        guard let window,
              !window.styleMask.contains(.fullScreen),
              let videoSize,
              videoSize.width > 0,
              videoSize.height > 0
        else {
            return
        }

        window.contentAspectRatio = videoSize
        resizeWindowContentToMatchVideoAspect(window: window, videoSize: videoSize)
    }

    func resetWindowAspectRatio() {
        window?.contentResizeIncrements = NSSize(width: 1, height: 1)
    }

    func resizeWindowContentToMatchVideoAspect(window: NSWindow, videoSize: CGSize) {
        guard let contentView = window.contentView else { return }

        let contentSize = contentView.bounds.size
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let videoRatio = videoSize.width / videoSize.height
        let contentRatio = contentSize.width / contentSize.height
        let adjustedContentSize: CGSize

        if contentRatio > videoRatio {
            adjustedContentSize = CGSize(width: contentSize.height * videoRatio, height: contentSize.height)
        } else {
            adjustedContentSize = CGSize(width: contentSize.width, height: contentSize.width / videoRatio)
        }

        guard abs(adjustedContentSize.width - contentSize.width) > 1
            || abs(adjustedContentSize.height - contentSize.height) > 1
        else {
            return
        }

        let currentFrame = window.frame
        let frameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: adjustedContentSize)).size
        let origin = CGPoint(
            x: currentFrame.midX - frameSize.width / 2,
            y: currentFrame.midY - frameSize.height / 2
        )
        window.setFrame(CGRect(origin: origin, size: frameSize), display: true, animate: true)
    }
}
#endif

#Preview {
    ContentView()
}
