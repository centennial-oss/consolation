//
//  ContentViewConnectPanel.swift
//  Consolation
//

import AVFoundation
import SwiftUI

struct ContentViewConnectPanel: View {
    @ObservedObject var capture: CaptureSessionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            deviceMenuPill
            resolutionMenuPill
        }
        .frame(maxWidth: 320)
    }

    private var deviceMenuPill: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Device")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Menu {
                Section("Capture devices") {
                    if capture.usbCaptureDeviceEntries.isEmpty {
                        Text("Capture Card Not Detected")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(capture.usbCaptureDeviceEntries) { entry in
                            deviceMenuButton(entry: entry)
                        }
                    }
                }
            if !capture.cameraDeviceEntries.isEmpty {
                Section("Cameras") {
                    ForEach(capture.cameraDeviceEntries) { entry in
                        deviceMenuButton(entry: entry)
                    }
                }
            }
            } label: {
                ConnectPanelPillLabel(value: capture.connectPanelDevicePrimaryLabel())
            }
            .disabled(capture.hasNoVideoDevices)
            .buttonStyle(.plain)
        }
    }

    private func deviceMenuButton(entry: CaptureDeviceSummary) -> some View {
        Button {
            capture.selectVideoDevice(uniqueID: entry.id)
        } label: {
            if entry.id == capture.selectedVideoDeviceUniqueID {
                Label(entry.localizedName, systemImage: "checkmark")
            } else {
                Text(entry.localizedName)
            }
        }
    }

    @ViewBuilder
    private var resolutionMenuPill: some View {
        if let id = capture.selectedVideoDeviceUniqueID,
           let device = AVCaptureDevice(uniqueID: id) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                resolutionMenu(for: device)
                    .disabled(capture.hasNoVideoDevices)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Resolution")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                ConnectPanelPillLabel(value: "—")
                    .opacity(0.45)
                    .allowsHitTesting(false)
            }
        }
    }

    private func resolutionMenu(for device: AVCaptureDevice) -> some View {
        let options = CaptureFormatSelector.resolutionMenuOptions(device: device)
        return Menu {
            ForEach(options) { resolution in
                Menu {
                    ForEach(resolution.frameRatesDescending, id: \.self) { fps in
                        formatMenuButton(
                            device: device,
                            resolution: resolution,
                            fps: fps
                        )
                    }
                } label: {
                    Text("\(resolution.width)×\(resolution.height)")
                }
            }
        } label: {
            ConnectPanelPillLabel(value: capture.connectPanelResolutionLabel())
        }
        .buttonStyle(.plain)
    }

    private func formatMenuButton(
        device: AVCaptureDevice,
        resolution: CaptureVideoFormatMenuResolution,
        fps: Double
    ) -> some View {
        Button {
            capture.selectVideoFormat(
                width: resolution.width,
                height: resolution.height,
                frameRate: fps
            )
        } label: {
            if isFormatMenuSelectionActive(
                device: device,
                width: resolution.width,
                height: resolution.height,
                fps: fps
            ) {
                Label(formatMenuRowTitle(fps: fps), systemImage: "checkmark")
            } else {
                Text(formatMenuRowTitle(fps: fps))
            }
        }
    }

    private func isFormatMenuSelectionActive(
        device: AVCaptureDevice,
        width: Int,
        height: Int,
        fps: Double
    ) -> Bool {
        guard let eff = CaptureFormatSelector.effectiveFormatForDisplay(
            device: device,
            preferences: capture.formatPreferences
        ) else {
            return false
        }
        return eff.width == width
            && eff.height == height
            && abs(eff.frameRate - fps) < 0.51
    }

    private func formatMenuRowTitle(fps: Double) -> String {
        "\(Int(round(fps))) fps"
    }
}

// MARK: - Pill chrome

private struct ConnectPanelPillLabel: View {
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Capsule())
    }
}
