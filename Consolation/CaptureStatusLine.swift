//
//  CaptureStatusLine.swift
//  Consolation
//

import SwiftUI

/// Primary status copy in the idle / overlay card (not the permission education block).
struct CaptureStatusLine: View {
    let state: CaptureState
    let hasUSBVideoCaptureDevice: Bool
    let usbVideoCaptureDeviceName: String?
    let hasAnyVideoDevice: Bool
    let statusMessage: String?

    var body: some View {
        switch state {
        case .idle:
            idleMessage
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .requestingPermission:
            Text("Connecting...")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .noDevice:
            noDeviceMessage
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .ready:
            Text("Ready!")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .running:
            if let name = statusMessage {
                Text("Connected: \(name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Connected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }

    private var idleMessage: Text {
        if hasUSBVideoCaptureDevice {
            Text("Press Play to connect to the \(usbVideoCaptureDeviceName ?? "USB video capture device").")
        } else if hasAnyVideoDevice {
            Text("No USB capture card detected. Choose a camera below, then press Play.")
        } else {
            Text("No video input found.")
        }
    }

    private var noDeviceMessage: Text {
        if hasAnyVideoDevice {
            Text("Video device unavailable. Choose another device below, then press Play.")
        } else {
            Text("No video input found.")
        }
    }
}
