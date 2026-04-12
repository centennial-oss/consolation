//
//  CaptureAudioUserDefaults.swift
//  Consolation
//

import Foundation

/// Persisted separately from any future `volumeLevel` slider so mute/unmute does not clobber stored volume.
enum CaptureAudioUserDefaults {
    static let isMutedKey = "org.centennialoss.consolation.captureAudioMuted"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [isMutedKey: false])
    }

    static func loadIsMuted() -> Bool {
        UserDefaults.standard.bool(forKey: isMutedKey)
    }

    static func saveIsMuted(_ muted: Bool) {
        UserDefaults.standard.set(muted, forKey: isMutedKey)
    }
}
