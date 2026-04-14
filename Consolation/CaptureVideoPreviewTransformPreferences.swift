//
//  CaptureVideoPreviewTransformPreferences.swift
//  Consolation
//

import Foundation

enum CaptureVideoPreviewRotation: Int, CaseIterable, Sendable {
    case none = 0
    case degrees90 = 90
    case degrees180 = 180
    case degrees270 = 270

    var menuTitle: String {
        switch self {
        case .none:
            return "None"
        case .degrees90:
            return "90 Degrees"
        case .degrees180:
            return "180 Degrees"
        case .degrees270:
            return "270 Degrees"
        }
    }
}

struct CaptureVideoPreviewMirrorOptions: OptionSet, Sendable {
    let rawValue: Int

    nonisolated static let horizontal = CaptureVideoPreviewMirrorOptions(rawValue: 1 << 0)
    nonisolated static let vertical = CaptureVideoPreviewMirrorOptions(rawValue: 1 << 1)
}

struct CaptureVideoPreviewTransform: Equatable, Sendable {
    var rotation: CaptureVideoPreviewRotation
    var mirrors: CaptureVideoPreviewMirrorOptions

    nonisolated static let `default` = CaptureVideoPreviewTransform(rotation: .none, mirrors: [])
}

enum CaptureVideoPreviewTransformUserDefaults {
    nonisolated static let changedNotification =
        Notification.Name("org.centennialoss.consolation.videoPreviewTransformChanged")

    private nonisolated static let rotationPrefix =
        "org.centennialoss.consolation.videoPreviewRotation"
    private nonisolated static let mirrorPrefix =
        "org.centennialoss.consolation.videoPreviewMirror"

    static func load(forDeviceID deviceID: String?) -> CaptureVideoPreviewTransform {
        guard let deviceID else { return .default }
        let defaults = UserDefaults.standard
        let rotationValue = defaults.integer(forKey: key(prefix: rotationPrefix, deviceID: deviceID))
        let rotation = CaptureVideoPreviewRotation(rawValue: rotationValue) ?? .none
        let mirrorRawValue = defaults.string(forKey: key(prefix: mirrorPrefix, deviceID: deviceID)) ?? "none"
        return CaptureVideoPreviewTransform(
            rotation: rotation,
            mirrors: mirrorOptions(from: mirrorRawValue)
        )
    }

    static func saveRotation(_ rotation: CaptureVideoPreviewRotation, forDeviceID deviceID: String?) {
        guard let deviceID else { return }
        UserDefaults.standard.set(rotation.rawValue, forKey: key(prefix: rotationPrefix, deviceID: deviceID))
        postChangedNotification()
    }

    static func saveMirrors(_ mirrors: CaptureVideoPreviewMirrorOptions, forDeviceID deviceID: String?) {
        guard let deviceID else { return }
        UserDefaults.standard.set(mirrorRawValue(from: mirrors), forKey: key(prefix: mirrorPrefix, deviceID: deviceID))
        postChangedNotification()
    }

    private static func key(prefix: String, deviceID: String) -> String {
        "\(prefix).\(deviceID)"
    }

    private static func mirrorOptions(from rawValue: String) -> CaptureVideoPreviewMirrorOptions {
        switch rawValue {
        case "h":
            return [.horizontal]
        case "v":
            return [.vertical]
        case "b":
            return [.horizontal, .vertical]
        default:
            return []
        }
    }

    private static func mirrorRawValue(from mirrors: CaptureVideoPreviewMirrorOptions) -> String {
        switch (mirrors.contains(.horizontal), mirrors.contains(.vertical)) {
        case (true, true):
            return "b"
        case (true, false):
            return "h"
        case (false, true):
            return "v"
        case (false, false):
            return "none"
        }
    }

    private static func postChangedNotification() {
        NotificationCenter.default.post(name: changedNotification, object: nil)
    }
}
