//
//  CaptureVideoZoomUserDefaults.swift
//  Consolation
//

import Foundation

private enum CaptureVideoZoomDeviceUserDefaultsKeys {
    nonisolated static let previewZoomLevelPrefix = AppIdentifier.scoped("captureVideoPreviewZoomLevel")
}

enum CaptureVideoZoomUserDefaults {
    static func loadPreviewZoomLevel(forDeviceID deviceID: String) -> Double {
        let zoomLevel = UserDefaults.standard.double(forKey: key(
            prefix: CaptureVideoZoomDeviceUserDefaultsKeys.previewZoomLevelPrefix,
            deviceID: deviceID
        ))
        guard zoomLevel.isFinite else { return 0 }
        return min(max(zoomLevel, 0), 100)
    }

    static func savePreviewZoomLevel(_ zoomLevel: Double, forDeviceID deviceID: String) {
        guard zoomLevel.isFinite else { return }
        UserDefaults.standard.set(min(max(zoomLevel, 0), 100), forKey: key(
            prefix: CaptureVideoZoomDeviceUserDefaultsKeys.previewZoomLevelPrefix,
            deviceID: deviceID
        ))
    }

    private static func key(prefix: String, deviceID: String) -> String {
        "\(prefix).\(deviceID)"
    }
}
