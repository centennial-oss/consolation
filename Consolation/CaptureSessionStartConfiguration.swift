//
//  CaptureSessionStartConfiguration.swift
//  Consolation
//

import Foundation

/// Bundles parameters for `CaptureSessionBackend.startWatching` so the call stays within SwiftLint limits.
struct CaptureSessionStartConfiguration: Sendable {
    let videoDeviceUniqueID: String
    let formatPreferences: CaptureVideoFormatPreferences
    let initialAudioMuted: Bool
    let initialVolumeLevel: Double
    let initialBufferLength: Int
}
