//
//  CaptureSessionManager.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Combine
import Foundation

/// Serializes `AVCaptureSession` configuration and `startRunning` / `stopRunning`.
private actor CaptureSessionBackend {
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private var audioPlayback: CaptureAudioPlayback?
    private(set) var activeVideoSize: CGSize?

    func startWatching(
        with session: AVCaptureSession,
        formatPreferences: CaptureVideoFormatPreferences
    ) throws -> String {
        session.beginConfiguration()

        tearDownSessionInputs(session: session)

        guard let device = Self.pickPreferredVideoDevice() else {
            session.commitConfiguration()
            throw CaptureSessionError.noVideoDevice
        }

        do {
            let input = try addVideoInput(for: device, to: session)
            try configureVideoDevice(device, input: input, session: session, formatPreferences: formatPreferences)
        } catch {
            session.commitConfiguration()
            throw error
        }

        addAudioInput(matchingVideoDevice: device, to: session)
        setPreferredSessionPresetIfAvailable(session)

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
        activeVideoSize = nil
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

    private func tearDownSessionInputs(session: AVCaptureSession) {
        tearDownAudio(session: session)
        if let existing = videoInput {
            session.removeInput(existing)
            videoInput = nil
        }
    }

    private func addVideoInput(
        for device: AVCaptureDevice,
        to session: AVCaptureSession
    ) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)

        guard session.canAddInput(input) else {
            throw CaptureSessionError.cannotAddVideoInput
        }

        session.addInput(input)
        videoInput = input
        return input
    }

    private func configureVideoDevice(
        _ device: AVCaptureDevice,
        input: AVCaptureDeviceInput,
        session: AVCaptureSession,
        formatPreferences: CaptureVideoFormatPreferences
    ) throws {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            try CaptureFormatSelector.applyPreferredFormat(device: device, preferences: formatPreferences)
        } catch {
            session.removeInput(input)
            videoInput = nil
            throw error
        }

        let format = device.activeFormat
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        activeVideoSize = CGSize(width: CGFloat(dims.width), height: CGFloat(dims.height))
    }

    private func addAudioInput(matchingVideoDevice device: AVCaptureDevice, to session: AVCaptureSession) {
        guard let audioDevice = CaptureAudioDeviceSelection.pickPreferredAudioDevice(matchingVideoDevice: device),
              let input = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(input)
        else {
            return
        }

        session.addInput(input)
        audioInput = input
        attachAudioOutput(for: input, to: session)
    }

    private func attachAudioOutput(for input: AVCaptureDeviceInput, to session: AVCaptureSession) {
        let output = AVCaptureAudioDataOutput()
        configureAudioOutput(output)

        let playback = CaptureAudioPlayback()
        guard (try? playback.prepareSessionRouting()) != nil else {
            session.removeInput(input)
            audioInput = nil
            return
        }

        output.setSampleBufferDelegate(playback, queue: playback.workQueue)
        guard session.canAddOutput(output) else {
            session.removeInput(input)
            audioInput = nil
            return
        }

        session.addOutput(output)
        audioDataOutput = output
        audioPlayback = playback
    }

    private func configureAudioOutput(_ output: AVCaptureAudioDataOutput) {
        // Request standard 32-bit float non-interleaved PCM to avoid garbled integer/interleaved formats.
        #if os(macOS)
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true,
            AVLinearPCMBitDepthKey: 32
        ]
        #endif
    }

    private func setPreferredSessionPresetIfAvailable(_ session: AVCaptureSession) {
        #if os(iOS)
        if session.canSetSessionPreset(.inputPriority) {
            session.sessionPreset = .inputPriority
        }
        #elseif os(macOS)
        #endif
    }

    /// Returns the first USB UVC capture device found, or `nil` when none is connected.
    private static func pickPreferredVideoDevice() -> AVCaptureDevice? {
        let types: [AVCaptureDevice.DeviceType] = [.external]

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

/// Owns the shared `AVCaptureSession` for preview layers and publishes UI state on the main actor.
@MainActor
final class CaptureSessionManager: ObservableObject {
    @Published private(set) var state: CaptureState = .idle

    /// Device name while running, or auxiliary detail for failures.
    @Published private(set) var statusMessage: String?

    /// True when at least one non-Continuity external video device is present (USB capture path).
    @Published private(set) var isExternalCaptureDeviceConnected = false

    /// Live audio from the capture card is audible when `false`.
    @Published private(set) var isAudioMuted = false

    /// Published dimensions of the currently active video feed to inform UI aspect ratio logic natively.
    @Published private(set) var videoSize: CGSize?

    /// Shared with `AVCaptureVideoPreviewLayer`; mutations happen only on `CaptureSessionBackend`.
    nonisolated let session = AVCaptureSession()

    private let backend = CaptureSessionBackend()
    private var externalDeviceCancellables = Set<AnyCancellable>()

    /// Resolved before each `startWatching`.
    /// Replace assignment from settings / `UserDefaults` when the preferences UI exists.
    var formatPreferences: CaptureVideoFormatPreferences = .loadFromStorage()

    /// Pass `nil` to load the built-in default today, and later persisted values.
    init(formatPreferences: CaptureVideoFormatPreferences? = nil) {
        self.formatPreferences = formatPreferences ?? CaptureVideoFormatPreferences.loadFromStorage()
        beginObservingExternalCapturePresence()
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
            self.isAudioMuted = false
            self.videoSize = nil
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
