//
//  CaptureAudioPlayback+IOS.swift
//  Consolation
//

#if os(iOS)
import AVFoundation
import Foundation

extension CaptureAudioPlayback {
    nonisolated func processIOS(sampleBuffer: CMSampleBuffer, frameCount: CMItemCount) {
        guard !isStopped else { return }
        guard !isMuted() else { return }

        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            logIOSAudioMissingFormatDescription()
            return
        }
        let sourceFormat = AVAudioFormat(cmAudioFormatDescription: formatDesc)
        guard sourceFormat.channelCount > 0, sourceFormat.sampleRate > 0 else {
            logIOSAudioInvalidSourceFormat(sourceFormat)
            return
        }

        let playFormat = CaptureAudioIOSPCMUtilities.normalizedFloatFormat(source: sourceFormat)

        engineWireLock.lock()
        if !didWireEngine ||
            !CaptureAudioIOSPCMUtilities.formatsArePlaybackCompatible(wiredIOSPlayFormat, playFormat) {
            do {
                if didWireEngine {
                    try synchronizeIOSMainThreadResetEngine()
                    resetScheduledBufferCount()
                    didWireEngine = false
                    wiredIOSPlayFormat = nil
                }
                try synchronizeIOSMainThreadWireEngine(with: playFormat)
                didWireEngine = true
                wiredIOSPlayFormat = playFormat
            } catch {
                logIOSAudioFailedToStartEngine(error)
                engineWireLock.unlock()
                return
            }
        }
        engineWireLock.unlock()

        guard let pcmBuffer = CaptureAudioIOSPCMUtilities.makePlaybackBuffer(
            sampleBuffer: sampleBuffer,
            frameCount: frameCount,
            sourceFormat: sourceFormat,
            playFormat: playFormat
        ) else {
            logIOSAudioFailedToConvert(sourceFormat: sourceFormat, playFormat: playFormat)
            return
        }

        schedulePCMBuffer(pcmBuffer)
    }

    nonisolated private func logIOSAudioMissingFormatDescription() {
        #if DEBUG
        print("\(BuildInfo.appName) iOS audio: sample buffer missing format description")
        #endif
    }

    nonisolated private func logIOSAudioInvalidSourceFormat(_ sourceFormat: AVAudioFormat) {
        #if DEBUG
        print("\(BuildInfo.appName) iOS audio: invalid source format \(sourceFormat)")
        #endif
    }

    nonisolated private func logIOSAudioFailedToStartEngine(_ error: Error) {
        #if DEBUG
        print("\(BuildInfo.appName) iOS audio: failed to start engine: \(error)")
        #endif
    }

    nonisolated private func logIOSAudioFailedToConvert(sourceFormat: AVAudioFormat, playFormat: AVAudioFormat) {
        #if DEBUG
        print(
            "\(BuildInfo.appName) iOS audio: failed to convert sample buffer " +
            "from \(sourceFormat) to \(playFormat)"
        )
        #endif
    }

    /// `AVAudioEngine` start/stop/attach must run on the main thread on iOS; capture callbacks do not.
    nonisolated func synchronizeIOSMainThreadResetEngine() throws {
        if Thread.isMainThread {
            resetEngineOnIOSMain()
            return
        }
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            self.resetEngineOnIOSMain()
            semaphore.signal()
        }
        semaphore.wait()
    }

    /// `AVAudioEngine` start/stop/attach must run on the main thread on iOS; capture callbacks do not.
    nonisolated func synchronizeIOSMainThreadWireEngine(with format: AVAudioFormat) throws {
        if Thread.isMainThread {
            try wireEngineOnIOSMain(with: format)
            return
        }
        var thrown: Error?
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            do {
                try self.wireEngineOnIOSMain(with: format)
            } catch {
                thrown = error
            }
            semaphore.signal()
        }
        semaphore.wait()
        if let thrown {
            throw thrown
        }
    }

    nonisolated func resetEngineOnIOSMain() {
        assert(Thread.isMainThread)
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        engine.disconnectNodeOutput(playerNode)
    }

    nonisolated func wireEngineOnIOSMain(with format: AVAudioFormat) throws {
        assert(Thread.isMainThread)
        guard !engine.isRunning else {
            return
        }
        if !engine.attachedNodes.contains(playerNode) {
            engine.attach(playerNode)
        }
        playerNode.volume = currentPlayerVolume()
        engine.mainMixerNode.volume = 1
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        playerNode.play()
    }
}
#endif
