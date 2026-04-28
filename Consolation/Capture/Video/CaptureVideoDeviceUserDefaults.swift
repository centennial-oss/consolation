//
//  CaptureVideoDeviceUserDefaults.swift
//  Consolation
//

import Foundation

enum CaptureVideoDeviceUserDefaults {
    nonisolated static let selectedVideoDeviceUniqueIDKey = AppIdentifier.scoped("selectedVideoDeviceUniqueID")

    static func loadSelectedDeviceUniqueID() -> String? {
        let value = UserDefaults.standard.string(forKey: selectedVideoDeviceUniqueIDKey)
        return (value?.isEmpty == false) ? value : nil
    }

    static func saveSelectedDeviceUniqueID(_ uniqueID: String?) {
        if let uniqueID, !uniqueID.isEmpty {
            UserDefaults.standard.set(uniqueID, forKey: selectedVideoDeviceUniqueIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedVideoDeviceUniqueIDKey)
        }
    }
}
