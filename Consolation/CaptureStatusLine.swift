//
//  CaptureStatusLine.swift
//  Consolation
//

import SwiftUI

/// Primary status copy in the idle / overlay card (not the permission education block).
struct CaptureStatusLine: View {
    let state: CaptureState
    let isExternalCaptureDeviceConnected: Bool
    let statusMessage: String?

    var body: some View {
        switch state {
        case .idle:
            if isExternalCaptureDeviceConnected {
                Text("Press the play button to view your capture device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect a USB video capture device. Consolation will detect it automatically.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        case .requestingPermission:
            Text("Requesting camera access…")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .noDevice:
            Text("No capture device found.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .ready:
            Text("Ready.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .running:
            if let name = statusMessage {
                Text("Watching: \(name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Watching live input.")
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
