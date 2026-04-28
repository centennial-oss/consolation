//
//  CaptureAudioUserDefaults.swift
//  Consolation
//

import Foundation

/// Persisted separately from any future `volumeLevel` slider so mute/unmute does not clobber stored volume.
enum CaptureAudioUserDefaults {
    nonisolated static let isMutedKey = AppIdentifier.scoped("captureAudioMuted")
    nonisolated static let volumeLevelKey = AppIdentifier.scoped("captureAudioVolumeLevel")
    nonisolated static let bufferLengthKey = AppIdentifier.scoped("captureAudioBufferLength")
    nonisolated static let bufferLengthOptions: [Int] = [1, 2, 4, 8, 16, 32, 64]
    nonisolated static let defaultBufferLength = 8

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            isMutedKey: false,
            volumeLevelKey: 1.0,
            bufferLengthKey: defaultBufferLength
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

    static func loadBufferLength() -> Int {
        let savedLength = UserDefaults.standard.integer(forKey: bufferLengthKey)
        guard bufferLengthOptions.contains(savedLength) else { return defaultBufferLength }
        return savedLength
    }

    static func saveBufferLength(_ length: Int) {
        guard bufferLengthOptions.contains(length) else { return }
        UserDefaults.standard.set(length, forKey: bufferLengthKey)
    }
}
