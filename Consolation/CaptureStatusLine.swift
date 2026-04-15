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
        let status = statusLine
        statusText(status.message, color: status.color)
    }

    private var statusLine: (message: String, color: Color) {
        switch state {
        case .idle:
            return (idleMessage, Color.primary.opacity(0.65))
        case .requestingPermission:
            return ("Connecting...", Color.primary.opacity(0.65))
        case .noDevice:
            return (noDeviceMessage, Color.primary.opacity(0.65))
        case .ready:
            return ("Ready!", Color.primary.opacity(0.65))
        case .running:
            if let name = statusMessage {
                return ("Connected: \(name)", Color.primary.opacity(0.65))
            }
            return ("Connected", Color.primary.opacity(0.65))
        case .failed(let message):
            return (message, .red)
        }
    }

    private var idleMessage: String {
        if hasUSBVideoCaptureDevice {
            "Press Play to connect to the \(usbVideoCaptureDeviceName ?? "USB video capture device")."
        } else if hasAnyVideoDevice {
            "No USB capture card detected. Choose a camera below, then press Play."
        } else {
            "No video input found."
        }
    }

    private var noDeviceMessage: String {
        if hasAnyVideoDevice {
            "Video device unavailable. Choose another device below, then press Play."
        } else {
            "No video input found."
        }
    }

    private func statusText(_ message: String, color: Color) -> some View {
        Text(message)
            .font(.system(size: 20))
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
    }
}
