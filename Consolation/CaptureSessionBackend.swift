//
//  CaptureSessionBackend.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Foundation

/// Serializes `AVCaptureSession` configuration and `startRunning` / `stopRunning`.
actor CaptureSessionBackend {
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var audioDataOutput: AVCaptureAudioDataOutput?
    private var audioPlayback: CaptureAudioPlayback?
    private(set) var activeVideoSize: CGSize?

    func startWatching(
        with session: AVCaptureSession,
        formatPreferences: CaptureVideoFormatPreferences,
        initialAudioMuted: Bool
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

        addAudioInput(matchingVideoDevice: device, to: session, initialAudioMuted: initialAudioMuted)
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

    private func addAudioInput(
        matchingVideoDevice device: AVCaptureDevice,
        to session: AVCaptureSession,
        initialAudioMuted: Bool
    ) {
        guard let audioDevice = CaptureAudioDeviceSelection.pickPreferredAudioDevice(matchingVideoDevice: device),
              let input = try? AVCaptureDeviceInput(device: audioDevice),
              session.canAddInput(input)
        else {
            return
        }

        session.addInput(input)
        audioInput = input
        attachAudioOutput(for: input, to: session, initialAudioMuted: initialAudioMuted)
    }

    private func attachAudioOutput(
        for input: AVCaptureDeviceInput,
        to session: AVCaptureSession,
        initialAudioMuted: Bool
    ) {
        // Keep this low-latency AVAudioEngine path instead of AVCaptureAudioPreviewOutput.
        // Apple frameworks may log an AudioAnalytics sandbox fault for com.apple.audioanalyticsd;
        // that private daemon lookup is expected/unavoidable for sandboxed apps and should not be
        // "fixed" with private entitlements. The preview output path produced noticeable lag.
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
        playback.setMutedBeforeCaptureStarts(initialAudioMuted)
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
