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
    static let showAboutCommand = Notification.Name(AppIdentifier.scoped("showAboutCommand"))
    static let showHelpCommand = Notification.Name(AppIdentifier.scoped("showHelpCommand"))
    static let audioMuteToggleCommand = Notification.Name(AppIdentifier.scoped("audioMuteToggleCommand"))
    static let audioVolumeLevelCommand = Notification.Name(AppIdentifier.scoped("audioVolumeLevelCommand"))
    static let audioBufferLengthCommand = Notification.Name(AppIdentifier.scoped("audioBufferLengthCommand"))
}

@main
struct ConsolationApp: App {
    @StateObject private var captureSession = CaptureSessionManager()
    @AppStorage(CaptureAudioUserDefaults.isMutedKey) private var isAudioMuted = false
    @AppStorage(CaptureAudioUserDefaults.volumeLevelKey) private var volumeLevel = 1.0
    @AppStorage(CaptureAudioUserDefaults.bufferLengthKey) private var audioBufferLength =
        CaptureAudioUserDefaults.defaultBufferLength
    @AppStorage(CaptureVideoStatsUserDefaults.showStatsKey) private var showVideoStats = false
    @AppStorage(CaptureVideoStatsUserDefaults.statsLocationKey) private var videoStatsLocationRawValue =
        CaptureVideoStatsUserDefaults.defaultLocation
    @AppStorage(CaptureVideoStatsUserDefaults.disableLowFPSWarningKey) private var disableLowFPSWarningOverlay = false
    @State private var previewTransformMenuRefresh = 0
    #if os(macOS)
    @AppStorage(ViewerWindowUserDefaults.isAlwaysOnTopKey) private var isViewerWindowAlwaysOnTop = false
    #endif

    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppOrientationDelegate.self) var iosOrientationDelegate
    #endif

    init() {
        AppIdentifier.logBundleIdentifier()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(capture: captureSession)
        }
        #if os(iOS)
        .windowResizability(.contentMinSize)
        #endif
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        #endif
        .commands {
            #if os(macOS)
            CommandGroup(replacing: .newItem) {}
            #endif
            CommandGroup(replacing: .appInfo) {
                Button("About \(AppIdentifier.name)") {
                    NotificationCenter.default.post(name: .showAboutCommand, object: nil)
                }
            }
            CommandGroup(replacing: .help) {
                Button("\(AppIdentifier.name) Help") {
                    NotificationCenter.default.post(name: .showHelpCommand, object: nil)
                }
                .keyboardShortcut("?", modifiers: [.command])
            }
            CommandGroup(after: .toolbar) {
                #if os(macOS)
                if captureSession.state == .running {
                    Menu("Resize Window") {
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
                    Divider()
                }
                #endif

                Menu("Video Stats") {
                    videoStatsMenuOption(title: "Off", location: nil)
                    ForEach(CaptureVideoStatsOverlayLocation.menuLocations, id: \.rawValue) { location in
                        videoStatsMenuOption(title: location.menuTitle, location: location)
                    }
                }
                Menu("Rotation") {
                    ForEach(CaptureVideoPreviewRotation.allCases, id: \.rawValue) { rotation in
                        previewRotationOption(rotation)
                    }
                }
                Menu("Mirror Image") {
                    previewMirrorOption(title: "Horizontal", mirror: .horizontal)
                    previewMirrorOption(title: "Vertical", mirror: .vertical)
                }
                #if os(macOS)
                Divider()
                Button {
                    isViewerWindowAlwaysOnTop.toggle()
                } label: {
                    if isViewerWindowAlwaysOnTop {
                        Label("Always on Top", systemImage: "checkmark")
                    } else {
                        Text("Always on Top")
                    }
                }
                #endif
                Divider()
                Button(captureSession.state == .running ? "Stop Video" : "Start Video") {
                    if captureSession.state == .running {
                        captureSession.stopWatching()
                    } else {
                        Task { await captureSession.startWatching() }
                    }
                }
                .disabled(captureSession.state != .running && !captureSession.canStartWatching)
                Divider()
                Button {
                    disableLowFPSWarningOverlay.toggle()
                } label: {
                    if disableLowFPSWarningOverlay {
                        Label("Suppress Low FPS Warnings", systemImage: "checkmark")
                    } else {
                        Text("Suppress Low FPS Warnings")
                    }
                }
                Divider()
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

                Section("Buffer Size") {
                    ForEach(CaptureAudioUserDefaults.bufferLengthOptions, id: \.self) { length in
                        audioBufferLengthOption(length)
                    }
                }
            }
        }
    }

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
    private func videoStatsMenuOption(title: String, location: CaptureVideoStatsOverlayLocation?) -> some View {
        let isSelected = isVideoStatsOptionSelected(location: location)
        Button {
            if let location {
                showVideoStats = true
                videoStatsLocationRawValue = location.rawValue
            } else {
                showVideoStats = false
            }
        } label: {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func isVideoStatsOptionSelected(location: CaptureVideoStatsOverlayLocation?) -> Bool {
        switch (showVideoStats, location) {
        case (false, nil):
            return true
        case (true, let selected?):
            return videoStatsLocationRawValue == selected.rawValue
        default:
            return false
        }
    }

    private func previewRotationOption(_ rotation: CaptureVideoPreviewRotation) -> some View {
        _ = previewTransformMenuRefresh
        let transform = CaptureVideoPreviewTransformUserDefaults.load(
            forDeviceID: captureSession.selectedVideoDeviceUniqueID
        )
        return Button {
            CaptureVideoPreviewTransformUserDefaults.saveRotation(
                rotation,
                forDeviceID: captureSession.selectedVideoDeviceUniqueID
            )
            previewTransformMenuRefresh += 1
        } label: {
            if transform.rotation == rotation {
                Label(rotation.menuTitle, systemImage: "checkmark")
            } else {
                Text(rotation.menuTitle)
            }
        }
        .disabled(captureSession.selectedVideoDeviceUniqueID == nil)
    }

    private func previewMirrorOption(title: String, mirror: CaptureVideoPreviewMirrorOptions) -> some View {
        _ = previewTransformMenuRefresh
        let transform = CaptureVideoPreviewTransformUserDefaults.load(
            forDeviceID: captureSession.selectedVideoDeviceUniqueID
        )
        let isSelected = transform.mirrors.contains(mirror)
        return Button {
            var mirrors = transform.mirrors
            if isSelected {
                mirrors.remove(mirror)
            } else {
                mirrors.insert(mirror)
            }
            CaptureVideoPreviewTransformUserDefaults.saveMirrors(
                mirrors,
                forDeviceID: captureSession.selectedVideoDeviceUniqueID
            )
            previewTransformMenuRefresh += 1
        } label: {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
        .disabled(captureSession.selectedVideoDeviceUniqueID == nil)
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
}
