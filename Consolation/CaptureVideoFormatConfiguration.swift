//
//  CaptureVideoFormatConfiguration.swift
//  Consolation
//
//  User-tunable capture format goals.
//
    //  Auto-selection strategy:
    //    1. Keep only formats whose max frame rate meets `minimumFrameRate` (default 60 Hz).
    //    2. Among those, pick the highest max frame rate.
    //    3. Among formats with that frame rate, pick the highest pixel count (resolution).
    //
    //  This means 1080p@120 beats 1440p@60, but 1440p@60 beats 1080p@60.
//  Later: expose `minimumFrameRate` (and an explicit override) via Settings / UserDefaults
//  without changing call sites — keep `CaptureSessionManager.formatPreferences` as the
//  single injection point.
//

@preconcurrency import AVFoundation
import Foundation

// MARK: - Preferences (future UserDefaults / settings)

/// Goals for automatic video format selection.
/// Replace `defaultForLaunch` sourcing with persisted values when settings UI ships.
struct CaptureVideoFormatPreferences: Sendable, Equatable {
    /// The minimum frame rate a format must support to be considered for auto-selection.
    /// Formats whose max frame rate falls below this threshold are ignored entirely,
    /// even if they offer a higher resolution (e.g. 4K@30 is excluded when this is 60).
    var minimumFrameRate: Double

    /// Built-in default until a settings store provides overrides.
    nonisolated static let defaultForLaunch = CaptureVideoFormatPreferences(
        minimumFrameRate: 60
    )

    /// Future: decode from `UserDefaults` / app storage; today returns `defaultForLaunch`.
    nonisolated static func loadFromStorage() -> CaptureVideoFormatPreferences {
        // Example later: guard let data = UserDefaults.standard.data(forKey: ...) else { return .defaultForLaunch }
        .defaultForLaunch
    }
}

// MARK: - Selection + apply

enum CaptureFormatSelector: Sendable {
    /// Selects the best format and locks the frame duration to its highest supported rate.
    /// Caller must hold `device.lockForConfiguration()` before calling.
    nonisolated static func applyPreferredFormat(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) throws {
        logAllFormats(device: device, preferences: preferences)
        try applyFormatAndFrameDuration(device: device, preferences: preferences)
    }

    /// Re-selects and re-applies both the active format and frame duration.
    /// On macOS the UVC driver resets both when the session starts; call this
    /// (under `lockForConfiguration`) after `session.startRunning()`.
    /// Caller must hold `device.lockForConfiguration()` before calling.
    nonisolated static func reapplyFormatAndFrameDuration(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) throws {
        try applyFormatAndFrameDuration(device: device, preferences: preferences)
    }

    /// Shared core used by both initial apply and post-start re-apply (no logging).
    private nonisolated static func applyFormatAndFrameDuration(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) throws {
        guard let format = bestFormat(device: device, preferences: preferences) else {
            throw CaptureFormatError.noSupportedFormat
        }

        let maxFPS = format.maxFrameRate
        logSelectedFormat(format, targetFPS: maxFPS)
        device.activeFormat = format
        applyFrameDuration(to: device, format: format, targetFPS: maxFPS)
    }

    /// Returns the best format for the given preferences, or `nil` if none qualify.
    nonisolated static func bestFormat(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) -> AVCaptureDevice.Format? {
        let minFPS = preferences.minimumFrameRate

        // Step 1: only formats whose max fps meets the minimum threshold.
        let qualifying = device.formats.filter { $0.maxFrameRate >= minFPS - 0.5 }
        guard !qualifying.isEmpty else { return nil }

        // Step 2: highest max frame rate among qualifying formats.
        let maxFPS = qualifying.map(\.maxFrameRate).max() ?? 0
        let atMaxFPS = qualifying.filter { $0.maxFrameRate >= maxFPS - 0.5 }

        // Step 3: among formats at that frame rate, pick the highest pixel count (resolution).
        return atMaxFPS.max { $0.pixelCount < $1.pixelCount }
    }

    private nonisolated static func applyFrameDuration(
        to device: AVCaptureDevice,
        format: AVCaptureDevice.Format,
        targetFPS: Double
    ) {
        let maxAvailable = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
        let desiredFPS = min(targetFPS, maxAvailable)

        guard let range = format.bestFrameRateRange(for: desiredFPS) else { return }

        // Use the range's own `CMTime`s — computed `CMTime(seconds: 1/fps, …)` often does not match
        // discrete hardware rates and can throw (e.g. "60.024" when only 1–60.00 is supported).
        let targetCap = min(desiredFPS, range.maxFrameRate)
        let epsilon = 0.5
        if targetCap >= range.maxFrameRate - epsilon {
            device.activeVideoMinFrameDuration = range.minFrameDuration
            device.activeVideoMaxFrameDuration = range.minFrameDuration
        } else if targetCap <= range.minFrameRate + epsilon {
            device.activeVideoMinFrameDuration = range.maxFrameDuration
            device.activeVideoMaxFrameDuration = range.maxFrameDuration
        }
        // Otherwise leave min/max unset so AVFoundation picks a valid default within the format.
    }

    private nonisolated static func logAllFormats(
        device: AVCaptureDevice,
        preferences: CaptureVideoFormatPreferences
    ) {
        #if os(macOS)
        let minFPS = preferences.minimumFrameRate
        let best = bestFormat(device: device, preferences: preferences)

        let sorted = device.formats.sorted {
            if $0.maxFrameRate != $1.maxFrameRate { return $0.maxFrameRate > $1.maxFrameRate }
            return $0.pixelCount > $1.pixelCount
        }

        print("Consolation macOS video available formats (minimum \(minFPS) fps):")
        for format in sorted {
            let qualifies = format.maxFrameRate >= minFPS - 0.5
            let marker = !qualifies ? "✗" : (format === best ? "→" : "✓")
            print("  \(marker) \(videoFormatDescription(format))")
        }
        #endif
    }

    private nonisolated static func logSelectedFormat(
        _ format: AVCaptureDevice.Format,
        targetFPS: Double
    ) {
        #if os(macOS)
        print("Consolation macOS video selected format: \(videoFormatDescription(format)), targetFPS=\(targetFPS)")
        #endif
    }

    nonisolated static func videoFormatDescription(_ format: AVCaptureDevice.Format) -> String {
        let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let ranges = format.videoSupportedFrameRateRanges.map { range in
            "\(range.minFrameRate)-\(range.maxFrameRate)fps"
        }
        return "\(dims.width)x\(dims.height) \(ranges)"
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
    nonisolated var maxFrameRate: Double {
        videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 0
    }

    nonisolated var pixelCount: Int {
        let dims = CMVideoFormatDescriptionGetDimensions(formatDescription)
        return Int(dims.width) * Int(dims.height)
    }

    nonisolated func bestFrameRateRange(for fps: Double) -> AVFrameRateRange? {
        let epsilon = 0.5
        let compatibleRanges = videoSupportedFrameRateRanges.filter { range in
            range.minFrameRate <= fps + epsilon && range.maxFrameRate >= fps - epsilon
        }
        if let nearestCompatible = compatibleRanges.min(by: {
            abs($0.maxFrameRate - fps) < abs($1.maxFrameRate - fps)
        }) {
            return nearestCompatible
        }

        return videoSupportedFrameRateRanges.min(by: {
            abs($0.maxFrameRate - fps) < abs($1.maxFrameRate - fps)
        })
    }
}
