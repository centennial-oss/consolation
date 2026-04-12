//
//  ContentView.swift
//  Consolation
//
//  Created by James Ranson on 4/12/26.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct ContentView: View {
    @StateObject var capture = CaptureSessionManager()
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    @State var window: NSWindow?
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
                            CaptureStatusLine(
                                state: capture.state,
                                isExternalCaptureDeviceConnected: capture.isExternalCaptureDeviceConnected,
                                statusMessage: capture.statusMessage
                            )

                            if capture.mediaPermissionNotice != .none,
                               capture.state != .requestingPermission {
                                CaptureMediaPermissionEducationNotice(notice: capture.mediaPermissionNotice)
                            }

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
            if state != .running {
                cancelAutoHideChrome()
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
        .onContinuousHover(coordinateSpace: .local) { _ in
            resetHoverTimer()
        }
        .onAppear {
            resetHoverTimer()
            capture.refreshMediaCaptureAuthorizationStatuses()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                capture.refreshMediaCaptureAuthorizationStatuses()
            }
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

    /// Auto-hide overlays and traffic-light dimming only apply while actively watching.
    private func resetHoverTimer() {
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

    private func cancelHoverHideTask() {
        hoverTask?.cancel()
        hoverTask = nil
    }

    private func revealTransientChromeIfNeeded() {
        guard isUIHidden else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            isUIHidden = false
        }
        #if os(macOS)
        window?.standardWindowButton(.closeButton)?.superview?.animator().alphaValue = 1.0
        #endif
    }

    private func cancelAutoHideChrome() {
        cancelHoverHideTask()
        revealTransientChromeIfNeeded()
    }
}

#Preview {
    ContentView()
}
