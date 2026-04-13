//
//  CaptureStatusLine.swift
//  Consolation
//

import SwiftUI

/// Primary status copy in the idle / overlay card (not the permission education block).
struct CaptureStatusLine: View {
    let state: CaptureState
    let isExternalCaptureDeviceConnected: Bool
    let externalCaptureDeviceName: String?
    let statusMessage: String?

    var body: some View {
        switch state {
        case .idle:
            if isExternalCaptureDeviceConnected {
                Text("Press Play to connect to the \(externalCaptureDeviceName ?? "USB Video Capture Device")")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("USB Video Capture Device not detected")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .requestingPermission:
            Text("Connecting...")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .noDevice:
            Text("USB Video Capture Device not detected")
                .font(.callout)
                .foregroundStyle(.secondary)
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
}
