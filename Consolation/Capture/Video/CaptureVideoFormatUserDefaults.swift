//
//  CaptureVideoFormatUserDefaults.swift
//  Consolation
//

import Foundation

private enum CaptureVideoFormatDeviceUserDefaultsKeys {
    nonisolated static let preferredWidthPrefix = AppIdentifier.scoped("captureVideoPreferredWidth")
    nonisolated static let preferredHeightPrefix = AppIdentifier.scoped("captureVideoPreferredHeight")
    nonisolated static let preferredFrameRatePrefix = AppIdentifier.scoped("captureVideoPreferredFrameRate")
}

enum CaptureVideoFormatUserDefaults {
    static func loadPreferredFormat(
        forDeviceID deviceID: String,
        minimumFrameRate: Double
    ) -> CaptureVideoFormatPreferences? {
        let defaults = UserDefaults.standard
        let width = defaults.integer(forKey: key(
            prefix: CaptureVideoFormatDeviceUserDefaultsKeys.preferredWidthPrefix,
            deviceID: deviceID
        ))
        let height = defaults.integer(forKey: key(
            prefix: CaptureVideoFormatDeviceUserDefaultsKeys.preferredHeightPrefix,
            deviceID: deviceID
        ))
        let frameRate = defaults.double(forKey: key(
            prefix: CaptureVideoFormatDeviceUserDefaultsKeys.preferredFrameRatePrefix,
            deviceID: deviceID
        ))
        guard width > 0, height > 0, frameRate > 0, frameRate.isFinite else { return nil }
        return CaptureVideoFormatPreferences(
            minimumFrameRate: minimumFrameRate,
            preferredPixelWidth: width,
            preferredPixelHeight: height,
            preferredFrameRate: frameRate
        )
    }

    static func savePreferredFormat(
        width: Int,
        height: Int,
        frameRate: Double,
        forDeviceID deviceID: String
    ) {
        guard frameRate > 0, frameRate.isFinite else { return }
        UserDefaults.standard.set(width, forKey: key(
            prefix: CaptureVideoFormatDeviceUserDefaultsKeys.preferredWidthPrefix,
            deviceID: deviceID
        ))
        UserDefaults.standard.set(height, forKey: key(
            prefix: CaptureVideoFormatDeviceUserDefaultsKeys.preferredHeightPrefix,
            deviceID: deviceID
        ))
        UserDefaults.standard.set(frameRate, forKey: key(
            prefix: CaptureVideoFormatDeviceUserDefaultsKeys.preferredFrameRatePrefix,
            deviceID: deviceID
        ))
    }

    private static func key(prefix: String, deviceID: String) -> String {
        "\(prefix).\(deviceID)"
    }
}
