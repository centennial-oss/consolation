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
                    "Apple treats USB capture hardware like a webcam. While Camera or Microphone access is "
                        + "still \"not set,\" starting playback will show the system prompts for Camera "
                        + "(your capture device's video) and Microphone (audio from that device)."
                )
            case .deniedOrRestricted:
                deniedOrRestrictedCopy
            }
        }
        .font(.footnote)
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
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
