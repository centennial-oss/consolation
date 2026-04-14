//
//  CaptureMediaPermissionEducation.swift
//  Consolation
//

import AVFoundation
import Foundation
import SwiftUI

/// Which idle-state media notice to show. Uses `authorizationStatus` only — never `requestAccess`.
enum CaptureMediaPermissionNotice: Equatable {
    case none
    case notDetermined
    case deniedOrRestricted

    static func current() -> Self {
        let video = AVCaptureDevice.authorizationStatus(for: .video)
        let audio = AVCaptureDevice.authorizationStatus(for: .audio)
        if isDeniedOrRestricted(video) || isDeniedOrRestricted(audio) {
            return .deniedOrRestricted
        }
        if video == .notDetermined || audio == .notDetermined {
            return .notDetermined
        }
        return .none
    }

    private static func isDeniedOrRestricted(_ status: AVAuthorizationStatus) -> Bool {
        status == .denied || status == .restricted
    }
}

struct CaptureMediaPermissionEducationNotice: View {
    let notice: CaptureMediaPermissionNotice

    var body: some View {
        Group {
            switch notice {
            case .none:
                EmptyView()
            case .notDetermined:
                Text(
                    """
                    When you press Play, you'll be asked to allow Camera and Microphone access.
                    These permissions are required because macOS treats Capture Cards as Webcams.
                    """
                )
                Divider()
            case .deniedOrRestricted:
                deniedOrRestrictedCopy
            }
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var deniedOrRestrictedCopy: some View {
        #if os(macOS)
        Text(
            "Camera or Microphone access for Consolation is off in System Settings. macOS treats USB "
                + "capture like a webcam: enable Camera and Microphone for Consolation under "
                + "Privacy & Security to use your device's picture and sound."
        )
        #else
        Text(
            "Camera or Microphone access for Consolation is off in Settings. Enable both under "
                + "Privacy so your capture device's video and audio can be used."
        )
        #endif
    }
}
