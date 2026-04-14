//
//  CaptureSessionManager.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Combine
import Foundation

struct CaptureDeviceSummary: Identifiable, Hashable, Sendable {
    let id: String
    let localizedName: String
}

/// Owns the shared `AVCaptureSession` for preview layers and publishes UI state on the main actor.
@MainActor
final class CaptureSessionManager: ObservableObject {
    @Published var state: CaptureState = .idle

    /// Device name while running, or auxiliary detail for failures.
    @Published var statusMessage: String?

    /// True when at least one non-Continuity external video device is present (USB capture path).
    @Published private(set) var isExternalCaptureDeviceConnected = false

    /// Localized name of the currently detected USB video capture device, when present.
    @Published private(set) var externalCaptureDeviceName: String?

    /// USB capture cards (UVC) vs built-in / Continuity / other cameras, for the connect panel.
    @Published var usbCaptureDeviceEntries: [CaptureDeviceSummary] = []
    @Published var cameraDeviceEntries: [CaptureDeviceSummary] = []

    /// `true` when discovery finds no video devices at all.
    @Published var hasNoVideoDevices = true

    /// Persisted choice for the connect panel; `nil` only before the first successful refresh.
    @Published var selectedVideoDeviceUniqueID: String?

    /// Live audio from the capture card is audible when `false`.
    /// Persisted across launches; see `CaptureAudioUserDefaults`.
    @Published var isAudioMuted: Bool

    /// Live audio output level, separate from mute so unmuting restores the prior level.
    @Published var volumeLevel: Double

    /// Max number of queued PCM buffers kept pending in `CaptureAudioPlayback`.
    @Published var audioBufferLength: Int

    /// Published dimensions of the currently active video feed to inform UI aspect ratio logic natively.
    @Published var videoSize: CGSize?

    /// Locked nominal capture rate after session start (from device min/max frame duration); stats overlay uses this.
    @Published var nominalVideoFrameRate: Double?
    let videoFrameRateStatsPublisher = PassthroughSubject<CaptureVideoFrameRateStats, Never>()

    /// Idle-card notice for camera/mic: undecided, denied in Settings, or `none` when both allowed.
    @Published private(set) var mediaPermissionNotice: CaptureMediaPermissionNotice = .none

    /// Shared with `AVCaptureVideoPreviewLayer`; mutations happen only on `CaptureSessionBackend`.
    nonisolated let session = AVCaptureSession()

    let backend = CaptureSessionBackend()
    var hardwareCancellables = Set<AnyCancellable>()
    var activeSessionVideoDeviceUniqueID: String?
    var lastLoggedVideoCapabilitiesSignature: String?

    /// Resolved before each `startWatching`; published so the connect panel updates labels and checkmarks.
    @Published private(set) var formatPreferences: CaptureVideoFormatPreferences

    /// Pass `nil` to load the built-in default today, and later persisted values.
    init(formatPreferences: CaptureVideoFormatPreferences? = nil) {
        CaptureAudioUserDefaults.registerDefaults()
        isAudioMuted = CaptureAudioUserDefaults.loadIsMuted()
        volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
        audioBufferLength = CaptureAudioUserDefaults.loadBufferLength()
        self.formatPreferences = formatPreferences ?? CaptureVideoFormatPreferences.loadFromStorage()
        Task { [weak self] in
            guard let self else { return }
            await self.backend.setVideoStatsUpdateHandler { [weak self] stats in
                guard let self else { return }
                guard UserDefaults.standard.bool(forKey: CaptureVideoStatsUserDefaults.showStatsKey) else { return }
                Task { @MainActor in
                    self.videoFrameRateStatsPublisher.send(stats)
                }
            }
        }
        beginObservingVideoHardwareChanges()
        refreshVideoDeviceUniverse(reconcileSelection: true)
        refreshMediaCaptureAuthorizationStatuses()
    }

    func refreshMediaCaptureAuthorizationStatuses() {
        mediaPermissionNotice = CaptureMediaPermissionNotice.current()
    }

    func refreshExternalCapturePresence() {
        let name = Self.connectedExternalVideoDeviceName()
        if externalCaptureDeviceName != name {
            externalCaptureDeviceName = name
        }
        let isConnected = name != nil
        if isExternalCaptureDeviceConnected != isConnected {
            isExternalCaptureDeviceConnected = isConnected
        }
    }

    func selectVideoDevice(uniqueID: String) {
        selectedVideoDeviceUniqueID = uniqueID
        CaptureVideoDeviceUserDefaults.saveSelectedDeviceUniqueID(uniqueID)
        exitFailedConnectStateAfterUserChangedSelection()
    }

    func selectVideoFormat(width: Int, height: Int, frameRate: Double) {
        formatPreferences = CaptureVideoFormatPreferences(
            minimumFrameRate: formatPreferences.minimumFrameRate,
            preferredPixelWidth: width,
            preferredPixelHeight: height,
            preferredFrameRate: frameRate
        )
        formatPreferences.saveToStorage()
        exitFailedConnectStateAfterUserChangedSelection()
    }

    /// After a failed start (e.g. no supported format), `canStartWatching` stays false until the user changes setup.
    private func exitFailedConnectStateAfterUserChangedSelection() {
        guard case .failed = state else { return }
        state = .idle
        statusMessage = nil
    }

    /// Primary line for the connect panel when a USB capture card is available (status copy).
    var primaryUSBVideoCaptureDisplayName: String? {
        usbCaptureDeviceEntries.first?.localizedName ?? externalCaptureDeviceName
    }

    /// Device button label: main title (device name or prompt).
    func connectPanelDevicePrimaryLabel() -> String {
        guard let id = selectedVideoDeviceUniqueID,
              let device = AVCaptureDevice(uniqueID: id)
        else {
            return hasNoVideoDevices ? "No devices found" : "Choose a device"
        }
        return device.localizedName
    }

    /// Resolution / frame rate line for the connect panel (explicit if valid, else automatic pick).
    func connectPanelResolutionLabel() -> String {
        guard let id = selectedVideoDeviceUniqueID,
              let device = AVCaptureDevice(uniqueID: id)
        else {
            return "—"
        }
        if let dims = CaptureFormatSelector.effectiveFormatForDisplay(device: device, preferences: formatPreferences) {
            return CaptureVideoFormatDisplayStrings.resolutionAndFrameLabel(
                width: dims.width,
                height: dims.height,
                frameRate: dims.frameRate
            )
        }
        return "Default"
    }

    /// Same rules as the in-app Start Watching control; used by menu commands and shortcuts.
    var canStartWatching: Bool {
        guard !hasNoVideoDevices else { return false }
        switch state {
        case .ready, .idle, .noDevice:
            return true
        case .requestingPermission, .running, .failed:
            return false
        }
    }

    nonisolated static func hasConnectedExternalVideoDevice() -> Bool {
        connectedExternalVideoDeviceName() != nil
    }

    nonisolated static func connectedExternalVideoDeviceName() -> String? {
        CaptureVideoDeviceDiscovery.connectedUSBVideoCaptureDisplayName()
    }

    func startWatching() async {
        defer { refreshMediaCaptureAuthorizationStatuses() }

        guard let deviceID = selectedVideoDeviceUniqueID,
              AVCaptureDevice(uniqueID: deviceID) != nil
        else {
            state = .noDevice
            statusMessage = "No video devices are available."
            return
        }

        statusMessage = nil
        state = .requestingPermission

        let granted = await CaptureSessionMediaAccess.requestCameraAccessIfNeeded()
        guard granted else {
            state = .failed("Camera access is required to show the capture feed.")
            statusMessage = "Allow camera access in Settings to continue."
            return
        }

        _ = await CaptureSessionMediaAccess.requestMicrophoneAccessIfNeeded()

        let muted = CaptureAudioUserDefaults.loadIsMuted()
        let volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
        let bufferLength = CaptureAudioUserDefaults.loadBufferLength()
        let configuration = makeStartConfiguration(
            deviceID: deviceID,
            muted: muted,
            volumeLevel: volumeLevel,
            bufferLength: bufferLength
        )
        do {
            let name = try await backend.startWatching(with: session, configuration: configuration)
            await applySuccessfulStartWatching(
                deviceID: deviceID,
                displayName: name,
                muted: muted,
                volumeLevel: volumeLevel,
                bufferLength: bufferLength
            )
        } catch {
            handleStartWatchingError(error)
        }
    }

    func stopWatching() {
        nominalVideoFrameRate = nil
        Task { @MainActor in
            await backend.stopWatching(with: session)
            self.state = .idle
            self.statusMessage = nil
            self.activeSessionVideoDeviceUniqueID = nil
            self.isAudioMuted = CaptureAudioUserDefaults.loadIsMuted()
            self.volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
            self.audioBufferLength = CaptureAudioUserDefaults.loadBufferLength()
            self.videoSize = nil
            self.nominalVideoFrameRate = nil
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

    func setAudioBufferLength(_ length: Int) {
        let normalizedLength = CaptureAudioUserDefaults.bufferLengthOptions.contains(length)
            ? length
            : CaptureAudioUserDefaults.defaultBufferLength
        audioBufferLength = normalizedLength
        CaptureAudioUserDefaults.saveBufferLength(normalizedLength)
        Task {
            await backend.setAudioBufferLength(normalizedLength)
        }
    }

    private func makeStartConfiguration(
        deviceID: String,
        muted: Bool,
        volumeLevel: Double,
        bufferLength: Int
    ) -> CaptureSessionStartConfiguration {
        CaptureSessionStartConfiguration(
            videoDeviceUniqueID: deviceID,
            formatPreferences: formatPreferences,
            initialAudioMuted: muted,
            initialVolumeLevel: volumeLevel,
            initialBufferLength: bufferLength
        )
    }

    private func handleStartWatchingError(_ error: Error) {
        activeSessionVideoDeviceUniqueID = nil
        nominalVideoFrameRate = nil
        if let captureError = error as? CaptureSessionError {
            switch captureError {
            case .noVideoDevice:
                state = .noDevice
                statusMessage = captureError.localizedDescription
            case .cannotAddVideoInput:
                state = .failed(captureError.localizedDescription)
                statusMessage = captureError.localizedDescription
            }
            return
        }
        state = .failed(error.localizedDescription)
        statusMessage = error.localizedDescription
    }

    private func applySuccessfulStartWatching(
        deviceID: String,
        displayName: String,
        muted: Bool,
        volumeLevel: Double,
        bufferLength: Int
    ) async {
        state = .running
        statusMessage = displayName
        activeSessionVideoDeviceUniqueID = deviceID
        isAudioMuted = muted
        self.volumeLevel = volumeLevel
        audioBufferLength = bufferLength
        await backend.setAudioMuted(muted)
        await backend.setVolumeLevel(volumeLevel)
        await backend.setAudioBufferLength(bufferLength)
        videoSize = await backend.activeVideoSize
        nominalVideoFrameRate = await backend.activeNominalFrameRate
    }
}
