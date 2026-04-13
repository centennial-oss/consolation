//
//  PlaybackControlsUserDefaults.swift
//  Consolation
//

import Foundation

enum PlaybackControlsUserDefaults {
    private static let positionXKey = "org.centennialoss.consolation.playbackControlsPositionX"
    private static let positionYKey = "org.centennialoss.consolation.playbackControlsPositionY"

    static func loadPosition() -> CGSize? {
        guard let positionX = UserDefaults.standard.object(forKey: positionXKey) as? Double,
              let positionY = UserDefaults.standard.object(forKey: positionYKey) as? Double,
              positionX.isFinite,
              positionY.isFinite
        else {
            return nil
        }

        return CGSize(width: positionX, height: positionY)
    }

    static func savePosition(_ position: CGSize) {
        guard position.width.isFinite,
              position.height.isFinite
        else {
            return
        }

        UserDefaults.standard.set(position.width, forKey: positionXKey)
        UserDefaults.standard.set(position.height, forKey: positionYKey)
    }
}
