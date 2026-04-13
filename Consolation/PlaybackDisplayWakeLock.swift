//
//  PlaybackDisplayWakeLock.swift
//  Consolation
//

import Foundation
#if os(iOS)
import UIKit
#endif

/// Keeps the display awake during playback (YouTube-style), without affecting other platforms.
enum PlaybackDisplayWakeLock {
    #if os(macOS)
    private static var activity: NSObjectProtocol?
    #endif

    @MainActor
    static func setActive(_ active: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = active
        #elseif os(macOS)
        if active {
            guard activity == nil else { return }
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .idleSystemSleepDisabled],
                reason: "org.centennialoss.consolation.playback"
            )
        } else if let current = activity {
            ProcessInfo.processInfo.endActivity(current)
            activity = nil
        }
        #endif
    }
}
