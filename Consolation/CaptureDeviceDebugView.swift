//
//  CaptureDeviceDebugView.swift
//  Consolation
//
//  DEBUG ONLY — shows a full dump of every AVCaptureDevice the system exposes so we can see
//  exactly how capture hardware presents itself (deviceType, modelID, position, etc.).
//  Remove or gate behind a build flag before shipping.
//

#if DEBUG

import AVFoundation
import SwiftUI

// MARK: - Device snapshot

struct CaptureDeviceSnapshot: Identifiable {
    let id: String          // uniqueID
    let name: String
    let deviceType: String
    let modelID: String
    let position: String
    let isContinuity: String
    let manufacturer: String

    static func snapshot(from device: AVCaptureDevice) -> CaptureDeviceSnapshot {
        let isContinuity: String
        if #available(macOS 13.0, iOS 16.0, *) {
            isContinuity = device.isContinuityCamera ? "YES" : "no"
        } else {
            isContinuity = "n/a"
        }

        return CaptureDeviceSnapshot(
            id: device.uniqueID,
            name: device.localizedName,
            deviceType: Self.typeName(device.deviceType),
            modelID: device.modelID,
            position: Self.positionName(device.position),
            isContinuity: isContinuity,
            manufacturer: device.manufacturer
        )
    }

    private static func typeName(_ deviceType: AVCaptureDevice.DeviceType) -> String {
        switch deviceType {
        case .external:                return ".external"
        case .builtInWideAngleCamera:  return ".builtInWideAngleCamera"
        case .continuityCamera:        return ".continuityCamera"
        case .microphone:              return ".microphone"
        #if os(macOS)
        case .deskViewCamera:          return ".deskViewCamera"
        #endif
        default:                       return deviceType.rawValue
        }
    }

    private static func positionName(_ position: AVCaptureDevice.Position) -> String {
        switch position {
        case .front:       return ".front"
        case .back:        return ".back"
        case .unspecified: return ".unspecified"
        @unknown default:  return "unknown(\(position.rawValue))"
        }
    }
}

// MARK: - Discovery helper

private func allVideoDeviceSnapshots() -> [CaptureDeviceSnapshot] {
    var types: [AVCaptureDevice.DeviceType] = [
        .external,
        .builtInWideAngleCamera,
        .continuityCamera
    ]
    #if os(macOS)
    types.append(.deskViewCamera)
    #endif

    let session = AVCaptureDevice.DiscoverySession(
        deviceTypes: types,
        mediaType: .video,
        position: .unspecified
    )
    // De-duplicate by uniqueID in case a device appears through multiple discovery paths.
    var seen = Set<String>()
    return session.devices.compactMap { device in
        guard seen.insert(device.uniqueID).inserted else { return nil }
        return CaptureDeviceSnapshot.snapshot(from: device)
    }
}

// MARK: - View

struct CaptureDeviceDebugView: View {
    @State private var snapshots: [CaptureDeviceSnapshot] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if snapshots.isEmpty {
                Text("No video capture devices found.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(snapshots) { snap in
                            deviceCard(snap)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 620, minHeight: 300)
        .onAppear { refresh() }
    }

    private var header: some View {
        HStack {
            Text("Capture Device Inspector")
                .font(.headline)
            Spacer()
            Text("\(snapshots.count) device(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Refresh") { refresh() }
                .buttonStyle(.borderless)
                .font(.caption)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func deviceCard(_ snap: CaptureDeviceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snap.name)
                .font(.system(.body, design: .monospaced).bold())
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 2) {
                row("deviceType", snap.deviceType)
                row("modelID", snap.modelID)
                row("manufacturer", snap.manufacturer)
                row("position", snap.position)
                row("isContinuity", snap.isContinuity)
                row("uniqueID", String(snap.id.prefix(24)) + "…")
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(minWidth: 100, alignment: .trailing)
            Text(value)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
    }

    private func refresh() {
        snapshots = allVideoDeviceSnapshots()
    }
}

#Preview {
    CaptureDeviceDebugView()
}

#endif
