//
//  ConsolationApp.swift
//  Consolation
//
//  Created by James Ranson on 4/12/26.
//

import SwiftUI

#if os(macOS)
import AppKit

/// Single-window viewer: strip **Format**, disable window tabbing.
/// SwiftUI may rebuild `mainMenu`; observe and strip again.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hides **View ▸ Show Tab Bar** / **Show All Tabs** for the whole app (single-window viewer).
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
#endif

extension Notification.Name {
    static let audioMuteToggleCommand = Notification.Name("org.centennialoss.consolation.audioMuteToggleCommand")
    static let audioVolumeLevelCommand = Notification.Name("org.centennialoss.consolation.audioVolumeLevelCommand")
    static let audioBufferLengthCommand = Notification.Name("org.centennialoss.consolation.audioBufferLengthCommand")
}

@main
struct ConsolationApp: App {
    @StateObject private var captureSession = CaptureSessionManager()

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage(CaptureAudioUserDefaults.isMutedKey) private var isAudioMuted = false
    @AppStorage(CaptureAudioUserDefaults.volumeLevelKey) private var volumeLevel = 1.0
    @AppStorage(CaptureAudioUserDefaults.bufferLengthKey) private var audioBufferLength =
        CaptureAudioUserDefaults.defaultBufferLength
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppOrientationDelegate.self) var iosOrientationDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView(capture: captureSession)
        }
        #if os(iOS)
        .windowResizability(.contentMinSize)
        #endif
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Section("Playback Size") {
                    Button(".5x") {
                        NotificationCenter.default.post(name: .playbackSizeCommand, object: CGFloat(0.5))
                    }
                    Button("1x") {
                        NotificationCenter.default.post(name: .playbackSizeCommand, object: CGFloat(1))
                    }
                    Button("2x") {
                        NotificationCenter.default.post(name: .playbackSizeCommand, object: CGFloat(2))
                    }
                }
                .disabled(captureSession.state != .running)
            }
            CommandMenu("Audio") {
                Section("Volume Level") {
                    Button {
                        isAudioMuted.toggle()
                        NotificationCenter.default.post(name: .audioMuteToggleCommand, object: isAudioMuted)
                    } label: {
                        if isAudioMuted {
                            Label("Muted", systemImage: "checkmark")
                        } else {
                            Text("Muted")
                        }
                    }
                    audioVolumeOption(label: "10%", level: 0.10)
                    audioVolumeOption(label: "25%", level: 0.25)
                    audioVolumeOption(label: "50%", level: 0.50)
                    audioVolumeOption(label: "75%", level: 0.75)
                    audioVolumeOption(label: "100%", level: 1.0)
                }

                Divider()

                Section("Buffer Length") {
                    ForEach(CaptureAudioUserDefaults.bufferLengthOptions, id: \.self) { length in
                        audioBufferLengthOption(length)
                    }
                }
            }
        }
        #endif
    }

    #if os(macOS)
    @ViewBuilder
    private func audioVolumeOption(label: String, level: Double) -> some View {
        Button {
            volumeLevel = level
            NotificationCenter.default.post(name: .audioVolumeLevelCommand, object: level)
            if isAudioMuted {
                isAudioMuted = false
                NotificationCenter.default.post(name: .audioMuteToggleCommand, object: false)
            }
        } label: {
            Text(label)
        }
    }

    @ViewBuilder
    private func audioBufferLengthOption(_ length: Int) -> some View {
        let label = length == CaptureAudioUserDefaults.defaultBufferLength
            ? "\(length) (default)"
            : "\(length)"
        Button {
            audioBufferLength = length
            NotificationCenter.default.post(name: .audioBufferLengthCommand, object: length)
        } label: {
            if audioBufferLength == length {
                Label(label, systemImage: "checkmark")
            } else {
                Text(label)
            }
        }
    }
    #endif
}
