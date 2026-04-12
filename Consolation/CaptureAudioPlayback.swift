//
//  CaptureAudioPlayback.swift
//  Consolation
//

import AVFoundation
import AudioToolbox
import Foundation
#if os(iOS)
import AVFAudio
#endif

/// Plays PCM audio from `AVCaptureAudioDataOutput` through `AVAudioEngine` (no recording, no files).
nonisolated final class CaptureAudioPlayback: NSObject,
    AVCaptureAudioDataOutputSampleBufferDelegate,
    @unchecked Sendable {
    /// Queue passed to `AVCaptureAudioDataOutput.setSampleBufferDelegate`; all processing runs here.
    let workQueue = DispatchQueue(label: "org.centennialoss.consolation.audio.capture", qos: .userInitiated)

    /// Lets `stop()` use `sync` safely even if invoked from this queue (e.g. future refactors).
    private static let workQueueMarker = DispatchSpecificKey<UInt8>()
    private static let workQueueTag: UInt8 = 1

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    private let stateLock = NSLock()
    private var stoppedFlag = false

    private let muteLock = NSLock()
    private var mutedFlag = false

    private let scheduleLock = NSLock()
    private var pendingScheduledBuffers = 0
    /// Keep the player queue short so latency stays low, but large enough to avoid jitter/garble.
    private let maxPendingScheduledBuffers = 4

    private var didWireEngine = false

    var isStopped: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return stoppedFlag
        }
        set {
            stateLock.lock()
            stoppedFlag = newValue
            stateLock.unlock()
        }
    }

    override init() {
        super.init()
        workQueue.setSpecific(key: Self.workQueueMarker, value: Self.workQueueTag)
    }

    func prepareSessionRouting() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        // `.videoChat` enables voice processing that can distort line-level / HDMI capture audio.
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
        try session.setActive(true)
        #endif
    }

    /// Mute is enforced by **not scheduling** buffers; mixer `volume` alone is unreliable on some macOS routes.
    func setMuted(_ muted: Bool) {
        if DispatchQueue.getSpecific(key: Self.workQueueMarker) == Self.workQueueTag {
            applyMutedState(muted)
        } else {
            workQueue.async { [weak self] in
                self?.applyMutedState(muted)
            }
        }
    }

    /// Install persisted mute **before** `AVCaptureSession.startRunning()` so the first samples never schedule audio.
    func setMutedBeforeCaptureStarts(_ muted: Bool) {
        workQueue.sync { [weak self] in
            self?.applyMutedState(muted)
        }
    }

    private func applyMutedState(_ muted: Bool) {
        muteLock.lock()
        mutedFlag = muted
        muteLock.unlock()
        if muted {
            playerNode.volume = 0
        } else {
            playerNode.volume = 1
            if didWireEngine, engine.isRunning, !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }

    func stop() {
        isStopped = true
        let cleanup: () -> Void = { [weak self] in
            guard let self else { return }
            self.playerNode.stop()
            self.engine.stop()
            if self.engine.attachedNodes.contains(self.playerNode) {
                self.engine.detach(self.playerNode)
            }
            self.scheduleLock.lock()
            self.pendingScheduledBuffers = 0
            self.scheduleLock.unlock()
            self.didWireEngine = false
        }
        if DispatchQueue.getSpecific(key: Self.workQueueMarker) == Self.workQueueTag {
            cleanup()
        } else {
            workQueue.sync(execute: cleanup)
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isStopped else { return }
        let frames = CMSampleBufferGetNumSamples(sampleBuffer)
        guard frames > 0 else { return }
        process(sampleBuffer: sampleBuffer, frameCount: frames)
    }

    private func isMuted() -> Bool {
        muteLock.lock()
        defer { muteLock.unlock() }
        return mutedFlag
    }

    private func process(sampleBuffer: CMSampleBuffer, frameCount: CMItemCount) {
        guard !isStopped else { return }
        guard !isMuted() else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let avFormat = AVAudioFormat(cmAudioFormatDescription: formatDesc)

        guard let pcmBuffer = AVAudioPCMBuffer(pcmFormat: avFormat, frameCapacity: AVAudioFrameCount(frameCount))
        else { return }
        pcmBuffer.frameLength = AVAudioFrameCount(frameCount)

        let copyStatus = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcmBuffer.mutableAudioBufferList
        )
        guard copyStatus == noErr else { return }

        if !didWireEngine {
            do {
                try wireEngine(with: avFormat)
            } catch {
                return
            }
        }

        scheduleLock.lock()
        if pendingScheduledBuffers >= maxPendingScheduledBuffers {
            scheduleLock.unlock()
            return
        }
        pendingScheduledBuffers += 1
        scheduleLock.unlock()

        playerNode.scheduleBuffer(pcmBuffer) { [weak self] in
            guard let self else { return }
            self.scheduleLock.lock()
            self.pendingScheduledBuffers = max(0, self.pendingScheduledBuffers - 1)
            self.scheduleLock.unlock()
        }
    }

    private func wireEngine(with format: AVAudioFormat) throws {
        guard !engine.isRunning else {
            didWireEngine = true
            return
        }
        engine.attach(playerNode)
        playerNode.volume = isMuted() ? 0 : 1
        engine.mainMixerNode.volume = 1
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        playerNode.play()
        didWireEngine = true
    }
}
