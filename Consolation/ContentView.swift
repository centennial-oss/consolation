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
                            .keyboardShortcut(.cancelAction)
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
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .background {
            #if os(macOS)
            WindowAccessor(window: $window)
            #endif
        }
        .onContinuousHover(coordinateSpace: .local) { _ in
            resetHoverTimer()
        }
        .onAppear {
            resetHoverTimer()
        }
        .onTapGesture(count: 2) {
            #if os(macOS)
            window?.zoom(nil)
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

#Preview {
    ContentView()
}
