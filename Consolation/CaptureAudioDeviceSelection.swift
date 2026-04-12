//
//  CaptureAudioDeviceSelection.swift
//  Consolation
//

import AVFoundation
import Foundation

enum CaptureAudioDeviceSelection {
    /// Names that almost always mean the Mac / headset / Continuity — never use for HDMI capture audio.
    private static let excludedBuiltInOrAmbientTokens: [String] = [
        "macbook", "imac", "mac studio", "mac pro", "mac mini",
        "built-in", "internal microphone", "internal mic",
        "facetime", "studio display", "airpods", "headset", "headphones",
        "iphone", "ipad", "continuity"
    ]

    private static func isLikelyBuiltInOrAmbientMic(name: String) -> Bool {
        let n = name.lowercased()
        return excludedBuiltInOrAmbientTokens.contains { n.contains($0) }
    }

    /// Picks the **single** audio endpoint tied to the USB capture device (HDMI audio from the card).
    /// Returns `nil` when there is no confident match — avoids mixing in the Mac mic (feedback / garble).
    nonisolated static func pickPreferredAudioDevice(matchingVideoDevice videoDevice: AVCaptureDevice) -> AVCaptureDevice? {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        let devices = discovery.devices
        guard !devices.isEmpty else { return nil }

        let videoName = videoDevice.localizedName

        // 1. Exact name match (Elgato often uses the same string for video + audio endpoints).
        if let exact = devices.first(where: { $0.localizedName.caseInsensitiveCompare(videoName) == .orderedSame }) {
            return exact
        }

        // 2. Audio device name contained in video name (e.g. short audio label inside longer video name).
        let candidates = devices.filter { !isLikelyBuiltInOrAmbientMic(name: $0.localizedName) }
        if videoName.count >= 4 {
            if let sub = candidates.first(where: { videoName.localizedCaseInsensitiveContains($0.localizedName) && $0.localizedName.count >= 4 }) {
                return sub
            }
            if let sub = candidates.first(where: { $0.localizedName.localizedCaseInsensitiveContains(videoName) }) {
                return sub
            }
        }

        // 3. Shared product tokens from the video name — prefer **longest** matching audio name to avoid generic "HDMI" collisions.
        let tokens = significantTokens(from: videoName)
        var best: (device: AVCaptureDevice, score: Int)?
        for d in candidates {
            let audioName = d.localizedName
            guard !isLikelyBuiltInOrAmbientMic(name: audioName) else { continue }
            var score = 0
            for t in tokens where audioName.localizedCaseInsensitiveContains(t) {
                score += t.count + 10
            }
            if score > 0, best == nil || score > best!.score || (score == best!.score && audioName.count > best!.device.localizedName.count) {
                best = (d, score)
            }
        }
        if let best { return best.device }

        #if targetEnvironment(simulator)
        return devices.first
        #else
        return nil
        #endif
    }

    /// Words / fragments from the video device name useful for matching audio (drops tiny noise words).
    private static func significantTokens(from name: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return name
            .components(separatedBy: separators)
            .map { $0.lowercased() }
            .filter { $0.count >= 3 }
    }
}
