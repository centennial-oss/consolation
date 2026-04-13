//
//  CaptureVideoFrameRateMonitor.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Foundation

nonisolated final class CaptureVideoFrameRateMonitor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let queue = DispatchQueue(label: "org.centennialoss.consolation.video-frame-rate-monitor")

    private var frameCount = 0
    private var droppedFrameCount = 0
    private var intervalStart = CACurrentMediaTime()
    private var firstPresentationTime: CMTime?
    private var lastPresentationTime: CMTime?
    private var maxPresentationGap = 0.0

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCount += 1
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if firstPresentationTime == nil {
            firstPresentationTime = presentationTime
        }
        if let lastPresentationTime {
            maxPresentationGap = max(maxPresentationGap, presentationTime.seconds - lastPresentationTime.seconds)
        }
        lastPresentationTime = presentationTime

        let now = CACurrentMediaTime()
        guard now - intervalStart >= 1 else { return }

        let elapsed = now - intervalStart
        let wallFPS = Double(frameCount) / elapsed
        let firstTime = firstPresentationTime?.seconds ?? presentationTime.seconds
        let presentationElapsed = presentationTime.seconds - firstTime
        let presentationFPS = presentationElapsed > 0 ? Double(max(frameCount - 1, 0)) / presentationElapsed : 0
        print(
            "Consolation video delivered fps: wall=\(wallFPS), presentation=\(presentationFPS), " +
            "frames=\(frameCount), dropped=\(droppedFrameCount), " +
            "maxPresentationGap=\(maxPresentationGap)"
        )

        frameCount = 0
        droppedFrameCount = 0
        intervalStart = now
        firstPresentationTime = nil
        lastPresentationTime = nil
        maxPresentationGap = 0
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didDrop sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        droppedFrameCount += 1
    }
}
