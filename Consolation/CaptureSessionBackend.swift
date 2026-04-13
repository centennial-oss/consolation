//
//  CaptureSessionBackend.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Foundation

/// Serializes `AVCaptureSession` configuration and `startRunning` / `stopRunning`.
actor CaptureSessionBackend {
    private var videoInput: AVCaptureDeviceInput?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var videoFrameRateMonitor: CaptureVideoFrameRateMonitor?
    private var audioInput: AVCaptureDeviceInput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private var audioPlayback: CaptureAudioPlayback?
    private(set) var activeVideoSize: CGSize?

    func startWatching(
        with session: AVCaptureSession,
        formatPreferences: CaptureVideoFormatPreferences,
        initialAudioMuted: Bool,
        initialVolumeLevel: Double,
        initialBufferLength: Int
    ) throws -> String {
        session.beginConfiguration()

        tearDownSessionInputs(session: session)

        guard let device = Self.pickPreferredVideoDevice() else {
            session.commitConfiguration()
            throw CaptureSessionError.noVideoDevice
        }

        setPreferredSessionPresetIfAvailable(session)

        do {
            let input = try addVideoInput(for: device, to: session)
            try configureVideoDevice(device, input: input, session: session, formatPreferences: formatPreferences)
            addVideoFrameRateMonitor(to: session)
        } catch {
            session.commitConfiguration()
            throw error
        }

        addAudioInput(
            matchingVideoDevice: device,
            to: session,
            initialAudioMuted: initialAudioMuted,
            initialVolumeLevel: initialVolumeLevel,
            initialBufferLength: initialBufferLength
        )

        session.commitConfiguration()
        session.startRunning()
        #if os(macOS)
        reapplyFormatAfterStart(device: device, preferences: formatPreferences)
        #endif
        logActiveVideoFormat(for: device)
        return device.localizedName
    }

    func stopWatching(with session: AVCaptureSession) {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        tearDownAudio(session: session)
        tearDownVideoFrameRateMonitor(session: session)
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

    func setVolumeLevel(_ level: Double) {
        audioPlayback?.setVolumeLevel(level)
    }

    func setAudioBufferLength(_ length: Int) {
        audioPlayback?.setMaxPendingScheduledBuffers(length)
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
        tearDownVideoFrameRateMonitor(session: session)
        if let existing = videoInput {
            session.removeInput(existing)
            videoInput = nil
        }
    }

    private func tearDownVideoFrameRateMonitor(session: AVCaptureSession) {
        if let output = videoDataOutput {
            output.setSampleBufferDelegate(nil, queue: nil)
            session.removeOutput(output)
            videoDataOutput = nil
        }
        videoFrameRateMonitor = nil
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

    private func addVideoFrameRateMonitor(to session: AVCaptureSession) {
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true

        let monitor = CaptureVideoFrameRateMonitor()
        output.setSampleBufferDelegate(monitor, queue: monitor.queue)

        guard session.canAddOutput(output) else {
            output.setSampleBufferDelegate(nil, queue: nil)
            return
        }

        session.addOutput(output)
        videoDataOutput = output
        videoFrameRateMonitor = monitor
    }

    private func addAudioInput(
        matchingVideoDevice device: AVCaptureDevice,
        to session: AVCaptureSession,
        initialAudioMuted: Bool,
        initialVolumeLevel: Double,
        initialBufferLength: Int
    ) {
        guard let audioDevice = CaptureAudioDeviceSelection.pickPreferredAudioDevice(matchingVideoDevice: device),
              let input = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(input)
        else {
            return
        }

        session.addInput(input)
        audioInput = input
        attachAudioOutput(
            for: input,
            to: session,
            initialAudioMuted: initialAudioMuted,
            initialVolumeLevel: initialVolumeLevel,
            initialBufferLength: initialBufferLength
        )
    }

    private func attachAudioOutput(
        for input: AVCaptureDeviceInput,
        to session: AVCaptureSession,
        initialAudioMuted: Bool,
        initialVolumeLevel: Double,
        initialBufferLength: Int
    ) {
        // Low-latency AVAudioEngine path. (`AVCaptureAudioPreviewOutput` exists on macOS only, not iOS.)
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
        #if os(iOS)
        for connection in output.connections {
            connection.isEnabled = true
        }
        #endif
        audioDataOutput = output
        audioPlayback = playback
        playback.setAudioBeforeCaptureStarts(muted: initialAudioMuted, volumeLevel: initialVolumeLevel)
        playback.setMaxPendingScheduledBuffers(initialBufferLength)
    }

    private func configureAudioOutput(_ output: AVCaptureAudioDataOutput) {
        // Request standard 32-bit float non-interleaved PCM to avoid garbled integer/interleaved formats.
        // `audioSettings` is macOS-only; iOS always uses the capture device’s native PCM (see `CaptureAudioPlayback`).
        #if os(macOS)
        output.audioSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: true,
            AVLinearPCMBitDepthKey: 32
        ]
        #endif
    }

    #if os(macOS)
    /// macOS's UVC stack resets both the active format and frame duration when the session starts.
    /// Re-lock the device and re-apply both immediately after `startRunning()`.
    private func reapplyFormatAfterStart(device: AVCaptureDevice, preferences: CaptureVideoFormatPreferences) {
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            try CaptureFormatSelector.reapplyFormatAndFrameDuration(device: device, preferences: preferences)
        } catch {
            print("Consolation macOS video: failed to reapply format after startRunning: \(error)")
        }
    }
    #endif

}

private extension CaptureSessionBackend {
    func setPreferredSessionPresetIfAvailable(_ session: AVCaptureSession) {
        #if os(iOS)
        if session.canSetSessionPreset(.inputPriority) {
            session.sessionPreset = .inputPriority
        }
        #endif
    }

    func logActiveVideoFormat(for device: AVCaptureDevice) {
        #if os(macOS)
        let minDuration = device.activeVideoMinFrameDuration
        let maxDuration = device.activeVideoMaxFrameDuration
        let minFPS = minDuration.seconds > 0 ? 1 / minDuration.seconds : 0
        let maxFPS = maxDuration.seconds > 0 ? 1 / maxDuration.seconds : 0
        print(
            "Consolation macOS video active format: " +
            "\(CaptureFormatSelector.videoFormatDescription(device.activeFormat)), " +
            "minFPS=\(minFPS), maxFPS=\(maxFPS)"
        )
        #endif
    }

    /// Returns the first USB UVC capture device found, or `nil` when none is connected.
    static func pickPreferredVideoDevice() -> AVCaptureDevice? {
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
