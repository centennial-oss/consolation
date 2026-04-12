//
//  CaptureSessionManager.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Combine
import Foundation

// MARK: - USB UVC capture device identification

/// Returns `true` only for a USB video capture device (e.g. Elgato Game Capture HD60 X).
///
/// Three conditions must all be true:
///   1. `deviceType` is `.external` (or the legacy `.externalUnknown` for older hardware).
///   2. `isContinuityCamera` is `false` — excludes iPhones/iPads surfacing as `.external`.
///   3. The device name does not contain the word "camera" — real capture cards are named things
///      like "Game Capture HD60 X" or "Cam Link 4K", never "FaceTime HD Camera" / "Gold Pro Camera".
nonisolated fileprivate func deviceIsUSBVideoCapture(_ device: AVCaptureDevice) -> Bool {
    #if os(macOS)
    let externalUnknown = AVCaptureDevice.DeviceType.externalUnknown
    let isExternalType = device.deviceType == .external || device.deviceType == externalUnknown
    #else
    let isExternalType = device.deviceType == .external
    #endif
    guard isExternalType else { return false }

    if #available(macOS 13.0, iOS 16.0, macCatalyst 16.0, *) {
        if device.isContinuityCamera { return false }
    }

    if device.localizedName.localizedCaseInsensitiveContains("camera") { return false }

    return true
}

/// Serializes `AVCaptureSession` configuration and `startRunning` / `stopRunning`.
private actor CaptureSessionBackend {
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private var audioPlayback: CaptureAudioPlayback?

    func startWatching(with session: AVCaptureSession, formatPreferences: CaptureVideoFormatPreferences) throws -> String {
        session.beginConfiguration()

        tearDownAudio(session: session)
        if let existing = videoInput {
            session.removeInput(existing)
            videoInput = nil
        }

        guard let device = Self.pickPreferredVideoDevice() else {
            session.commitConfiguration()
            throw CaptureSessionError.noVideoDevice
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            throw error
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CaptureSessionError.cannotAddVideoInput
        }

        session.addInput(input)
        videoInput = input

        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            try CaptureFormatSelector.applyPreferredFormat(device: device, preferences: formatPreferences)
        } catch {
            session.removeInput(input)
            videoInput = nil
            session.commitConfiguration()
            throw error
        }

        if let audioDevice = CaptureAudioDeviceSelection.pickPreferredAudioDevice(matchingVideoDevice: device),
           let aInput = try? AVCaptureDeviceInput(device: audioDevice),
           session.canAddInput(aInput) {
            session.addInput(aInput)
            audioInput = aInput
            let output = AVCaptureAudioDataOutput()
            // Request standard 32-bit float non-interleaved PCM. This prevents AVAudioEngine
            // from garbling integer/interleaved capture formats (the "wind blowing" effect) and
            // avoids 'FormatNotSupported' by ensuring the mixer is fed Standard Float32.
            #if os(macOS)
            output.audioSettings = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: true,
                AVLinearPCMBitDepthKey: 32
            ]
            #endif
            
            let playback = CaptureAudioPlayback()
            if (try? playback.prepareSessionRouting()) != nil {
                output.setSampleBufferDelegate(playback, queue: playback.workQueue)
                if session.canAddOutput(output) {
                    session.addOutput(output)
                    audioDataOutput = output
                    audioPlayback = playback
                } else {
                    session.removeInput(aInput)
                    audioInput = nil
                }
            } else {
                session.removeInput(aInput)
                audioInput = nil
            }
        }

        #if os(iOS)
        if session.canSetSessionPreset(.inputPriority) {
            session.sessionPreset = .inputPriority
        }
        #elseif os(macOS)
        #endif

        session.commitConfiguration()
        session.startRunning()
        return device.localizedName
    }

    func stopWatching(with session: AVCaptureSession) {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        tearDownAudio(session: session)
        if let input = videoInput {
            session.removeInput(input)
            videoInput = nil
        }
        session.commitConfiguration()
    }

    func setAudioMuted(_ muted: Bool) {
        audioPlayback?.setMuted(muted)
    }

    private func tearDownAudio(session: AVCaptureSession) {
        if let output = audioDataOutput {
            output.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(output)
            audioDataOutput = nil
        }
        if let aIn = audioInput {
            session.removeInput(aIn)
            audioInput = nil
        }
        audioPlayback?.stop()
        audioPlayback = nil
    }

    /// Returns the first USB UVC capture device found, or `nil` when none is connected.
    private static func pickPreferredVideoDevice() -> AVCaptureDevice? {
        #if os(macOS)
        // Include the legacy .externalUnknown type: older capture cards (e.g. Elgato HD60 X) still
        // surface under this type on current macOS even though Apple deprecated it in macOS 14.
        let types: [AVCaptureDevice.DeviceType] = [.external, .externalUnknown]
        #else
        let types: [AVCaptureDevice.DeviceType] = [.external]
        #endif

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )
        let uvcDevices = discovery.devices.filter { deviceIsUSBVideoCapture($0) }
        if let chosen = uvcDevices.first { return chosen }

        #if targetEnvironment(simulator)
        return AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices.first
        #else
        return nil
        #endif
    }
}

private enum CaptureSessionError: LocalizedError {
    case noVideoDevice
    case cannotAddVideoInput

    var errorDescription: String? {
        switch self {
        case .noVideoDevice:
            return "No video capture device was found."
        case .cannotAddVideoInput:
            return "This capture device cannot be used as a video input."
        }
    }
}

/// Owns the shared `AVCaptureSession` for preview layers, delegates start/stop to `CaptureSessionBackend`, and publishes UI state on the main actor.
@MainActor
final class CaptureSessionManager: ObservableObject {
    @Published private(set) var state: CaptureState = .idle

    /// Device name while running, or auxiliary detail for failures.
    @Published private(set) var statusMessage: String?

    /// True when at least one non-Continuity external video device is present (USB capture path).
    @Published private(set) var isExternalCaptureDeviceConnected = false

    /// Live audio from the capture card is audible when `false`.
    @Published private(set) var isAudioMuted = false

    /// Shared with `AVCaptureVideoPreviewLayer`; mutations happen only on `CaptureSessionBackend`.
    nonisolated let session = AVCaptureSession()

    private let backend = CaptureSessionBackend()
    private var externalDeviceCancellables = Set<AnyCancellable>()

    /// Resolved before each `startWatching`; replace assignment from settings / `UserDefaults` when the preferences UI exists.
    var formatPreferences: CaptureVideoFormatPreferences = .loadFromStorage()

    /// Pass `nil` to load from `CaptureVideoFormatPreferences.loadFromStorage()` (today: built-in default; later: persisted values).
    init(formatPreferences: CaptureVideoFormatPreferences? = nil) {
        self.formatPreferences = formatPreferences ?? CaptureVideoFormatPreferences.loadFromStorage()
        beginObservingExternalCapturePresence()
    }

    func refreshExternalCapturePresence() {
        isExternalCaptureDeviceConnected = Self.hasConnectedExternalVideoDevice()
    }

    nonisolated static func hasConnectedExternalVideoDevice() -> Bool {
        #if os(macOS)
        let types: [AVCaptureDevice.DeviceType] = [.external, .externalUnknown]
        #else
        let types: [AVCaptureDevice.DeviceType] = [.external]
        #endif

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
        }
        .store(in: &externalDeviceCancellables)
    }

    func startWatching() async {
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
        do {
            let name = try await backend.startWatching(with: session, formatPreferences: prefs)
            state = .running
            statusMessage = name
            isAudioMuted = false
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
            self.isAudioMuted = false
        }
    }

    func setAudioMuted(_ muted: Bool) {
        isAudioMuted = muted
        Task {
            await backend.setAudioMuted(muted)
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
