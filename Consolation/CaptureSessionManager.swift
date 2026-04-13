//
//  CaptureSessionManager.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Combine
import Foundation

/// Owns the shared `AVCaptureSession` for preview layers and publishes UI state on the main actor.
@MainActor
final class CaptureSessionManager: ObservableObject {
    @Published private(set) var state: CaptureState = .idle

    /// Device name while running, or auxiliary detail for failures.
    @Published private(set) var statusMessage: String?

    /// True when at least one non-Continuity external video device is present (USB capture path).
    @Published private(set) var isExternalCaptureDeviceConnected = false

    /// Live audio from the capture card is audible when `false`.
    /// Persisted across launches; see `CaptureAudioUserDefaults`.
    @Published private(set) var isAudioMuted: Bool

    /// Live audio output level, separate from mute so unmuting restores the prior level.
    @Published private(set) var volumeLevel: Double

    /// Published dimensions of the currently active video feed to inform UI aspect ratio logic natively.
    @Published private(set) var videoSize: CGSize?

    /// Idle-card notice for camera/mic: undecided, denied in Settings, or `none` when both allowed.
    @Published private(set) var mediaPermissionNotice: CaptureMediaPermissionNotice = .none

    /// Shared with `AVCaptureVideoPreviewLayer`; mutations happen only on `CaptureSessionBackend`.
    nonisolated let session = AVCaptureSession()

    private let backend = CaptureSessionBackend()
    private var externalDeviceCancellables = Set<AnyCancellable>()

    /// Resolved before each `startWatching`.
    /// Replace assignment from settings / `UserDefaults` when the preferences UI exists.
    var formatPreferences: CaptureVideoFormatPreferences = .loadFromStorage()

    /// Pass `nil` to load the built-in default today, and later persisted values.
    init(formatPreferences: CaptureVideoFormatPreferences? = nil) {
        CaptureAudioUserDefaults.registerDefaults()
        isAudioMuted = CaptureAudioUserDefaults.loadIsMuted()
        volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
        self.formatPreferences = formatPreferences ?? CaptureVideoFormatPreferences.loadFromStorage()
        beginObservingExternalCapturePresence()
        refreshMediaCaptureAuthorizationStatuses()
    }

    func refreshMediaCaptureAuthorizationStatuses() {
        mediaPermissionNotice = CaptureMediaPermissionNotice.current()
    }

    func refreshExternalCapturePresence() {
        isExternalCaptureDeviceConnected = Self.hasConnectedExternalVideoDevice()
    }

    nonisolated static func hasConnectedExternalVideoDevice() -> Bool {
        let types: [AVCaptureDevice.DeviceType] = [.external]

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        if discovery.devices.contains(where: deviceIsUSBVideoCapture) { return true }

        #if targetEnvironment(simulator)
        return !AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.isEmpty
        #else
        return false
        #endif
    }

    private func beginObservingExternalCapturePresence() {
        refreshExternalCapturePresence()

        let connected = NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)
        let disconnected = NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)
        let timerSignal = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect().map { _ in () }

        Publishers.Merge3(
            connected.map { _ in () },
            disconnected.map { _ in () },
            timerSignal
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.refreshExternalCapturePresence()
            self?.refreshMediaCaptureAuthorizationStatuses()
        }
        .store(in: &externalDeviceCancellables)
    }

    func startWatching() async {
        defer { refreshMediaCaptureAuthorizationStatuses() }

        guard isExternalCaptureDeviceConnected else {
            state = .noDevice
            statusMessage = "Connect a USB video capture device, then try again."
            return
        }

        statusMessage = nil
        state = .requestingPermission

        let granted = await Self.requestCameraAccessIfNeeded()
        guard granted else {
            state = .failed("Camera access is required to show the capture feed.")
            statusMessage = "Allow camera access in Settings to continue."
            return
        }

        _ = await Self.requestMicrophoneAccessIfNeeded()

        let prefs = formatPreferences
        let muted = CaptureAudioUserDefaults.loadIsMuted()
        let volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
        do {
            let name = try await backend.startWatching(
                with: session,
                formatPreferences: prefs,
                initialAudioMuted: muted,
                initialVolumeLevel: volumeLevel
            )
            state = .running
            statusMessage = name
            isAudioMuted = muted
            self.volumeLevel = volumeLevel
            await backend.setAudioMuted(muted)
            await backend.setVolumeLevel(volumeLevel)
            videoSize = await backend.activeVideoSize
        } catch let error as CaptureSessionError {
            switch error {
            case .noVideoDevice:
                state = .noDevice
                statusMessage = error.localizedDescription
            case .cannotAddVideoInput:
                state = .failed(error.localizedDescription)
                statusMessage = error.localizedDescription
            }
        } catch {
            state = .failed(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }

    func stopWatching() {
        Task { @MainActor in
            await backend.stopWatching(with: session)
            self.state = .idle
            self.statusMessage = nil
            self.isAudioMuted = CaptureAudioUserDefaults.loadIsMuted()
            self.volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
            self.videoSize = nil
            self.refreshMediaCaptureAuthorizationStatuses()
        }
    }

    func setAudioMuted(_ muted: Bool) {
        isAudioMuted = muted
        CaptureAudioUserDefaults.saveIsMuted(muted)
        Task {
            await backend.setAudioMuted(muted)
        }
    }

    func setVolumeLevel(_ level: Double) {
        let clamped = min(max(level, 0), 1)
        volumeLevel = clamped
        CaptureAudioUserDefaults.saveVolumeLevel(clamped)
        Task {
            await backend.setVolumeLevel(clamped)
        }
    }

    private static func requestCameraAccessIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    private static func requestMicrophoneAccessIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
