//
//  CaptureVideoFormatConfiguration.swift
//  Consolation
//
//  User-tunable capture resolution / frame-rate goals. Defaults match MVP (1080p @ 60 Hz).
//  Later: read/write via Settings (e.g. `UserDefaults`) without changing call sites — keep
//  `CaptureSessionManager.formatPreferences` as the single injection point.
//

@preconcurrency import AVFoundation
import Foundation

// MARK: - Preferences (future UserDefaults / settings)

/// Goals for automatic video format selection. Replace `defaultForLaunch` sourcing with persisted values when settings UI ships.
struct CaptureVideoFormatPreferences: Sendable, Equatable {
    /// Target width in landscape orientation (e.g. 1920 for “1080p”).
    var preferredWidth: Int32
    /// Target height in landscape orientation (e.g. 1080).
    var preferredHeight: Int32
    /// Upper bound on frame rate to request from hardware (e.g. 60). Selection never exceeds this.
    var preferredMaxFrameRate: Double

    /// Built-in default until a settings store provides overrides.
    static let defaultForLaunch = CaptureVideoFormatPreferences(
        preferredWidth: 1920,
        preferredHeight: 1080,
        preferredMaxFrameRate: 60
    )

    /// Future: decode from `UserDefaults` / app storage; today returns `defaultForLaunch`.
    nonisolated static func loadFromStorage() -> CaptureVideoFormatPreferences {
        // Example later: guard let data = UserDefaults.standard.data(forKey: ...) else { return .defaultForLaunch }
        .defaultForLaunch
    }
}

// MARK: - Selection + apply

enum CaptureFormatSelector: Sendable {
    /// Chooses a format, assigns `device.activeFormat`, and locks min/max frame duration to the best rate ≤ `preferences.preferredMaxFrameRate`.
    /// Caller must not hold the session configuration lock across `startRunning` (handled by caller).
    nonisolated static func applyPreferredFormat(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) throws {
        guard let format = bestFormat(device: device, preferences: preferences) else {
            throw CaptureFormatError.noSupportedFormat
        }

        device.activeFormat = format

        let targetFPS = preferences.preferredMaxFrameRate
        let maxAvailable = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
        let desiredFPS = min(targetFPS, maxAvailable)

        guard let range = format.videoSupportedFrameRateRanges.first(where: { $0.minFrameRate <= desiredFPS && $0.maxFrameRate >= desiredFPS })
            ?? format.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate })
        else {
            return
        }

        // Use the range’s own `CMTime`s — computed `CMTime(seconds: 1/fps, …)` often does not match
        // discrete hardware rates and can throw (e.g. “60.024” when only 1–60.00 is supported).
        let targetCap = min(desiredFPS, range.maxFrameRate)
        let epsilon = 0.1
        if targetCap >= range.maxFrameRate - epsilon {
            device.activeVideoMinFrameDuration = range.minFrameDuration
            device.activeVideoMaxFrameDuration = range.minFrameDuration
        } else if targetCap <= range.minFrameRate + epsilon {
            device.activeVideoMinFrameDuration = range.maxFrameDuration
            device.activeVideoMaxFrameDuration = range.maxFrameDuration
        }
        // Otherwise leave min/max unset so AVFoundation picks a valid default within the format.
    }

    nonisolated static func bestFormat(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) -> AVCaptureDevice.Format? {
        let targetW = preferences.preferredWidth
        let targetH = preferences.preferredHeight
        let targetFPS = preferences.preferredMaxFrameRate

        let scored = device.formats.compactMap { format -> (format: AVCaptureDevice.Format, score: Int)? in
            let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let lw = max(dims.width, dims.height)
            let lh = min(dims.width, dims.height)
            let maxFps = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
            let supportsTarget = format.supports(frameRate: min(targetFPS, maxFps))
            let matchesTargetSize = lw == targetW && lh == targetH
            let pixels = Int(lw) * Int(lh)

            // Tiered score: exact size + target FPS > exact size + high FPS > supports target FPS > pixels * fps
            var score = 0
            if matchesTargetSize, supportsTarget, maxFps >= targetFPS - 0.01 {
                score = 4_000_000_000 + Int(maxFps * 1_000)
            } else if matchesTargetSize {
                score = 3_000_000_000 + Int(maxFps * 1_000) + pixels / 10_000
            } else if supportsTarget {
                let sizeCloseness = 2_000_000_000 - abs(Int(lw) - Int(targetW)) * 1_000 - abs(Int(lh) - Int(targetH)) * 1_000
                score = sizeCloseness + Int(maxFps)
            } else {
                score = pixels + Int(maxFps * 10)
            }
            return (format, score)
        }

        return scored.max(by: { $0.score < $1.score })?.format
    }
}

private enum CaptureFormatError: LocalizedError {
    case noSupportedFormat

    var errorDescription: String? {
        switch self {
        case .noSupportedFormat:
            return "No supported video format was found for this device."
        }
    }
}

private extension AVCaptureDevice.Format {
    nonisolated func supports(frameRate fps: Double) -> Bool {
        videoSupportedFrameRateRanges.contains { range in
            range.minFrameRate <= fps && range.maxFrameRate >= fps
        }
    }
}
