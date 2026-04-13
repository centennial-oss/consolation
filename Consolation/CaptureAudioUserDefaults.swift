//
//  CaptureAudioUserDefaults.swift
//  Consolation
//

import Foundation

/// Persisted separately from any future `volumeLevel` slider so mute/unmute does not clobber stored volume.
enum CaptureAudioUserDefaults {
    static let isMutedKey = "org.centennialoss.consolation.captureAudioMuted"
    static let volumeLevelKey = "org.centennialoss.consolation.captureAudioVolumeLevel"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            isMutedKey: false,
            volumeLevelKey: 1.0
        ])
    }

    static func loadIsMuted() -> Bool {
        UserDefaults.standard.bool(forKey: isMutedKey)
    }

    static func saveIsMuted(_ muted: Bool) {
        UserDefaults.standard.set(muted, forKey: isMutedKey)
    }

    static func loadVolumeLevel() -> Double {
        let level = UserDefaults.standard.double(forKey: volumeLevelKey)
        guard level.isFinite else { return 1.0 }
        return min(max(level, 0), 1)
    }

    static func saveVolumeLevel(_ level: Double) {
        guard level.isFinite else { return }
        UserDefaults.standard.set(min(max(level, 0), 1), forKey: volumeLevelKey)
    }
}
