import AVFoundation
import Foundation
import SwiftUI

extension ContentView {
    var maxFPSWarningPollThreshold: Int { 3 }

    var shouldShowStatsOverlay: Bool {
        showVideoStats && capture.state == .running
    }

    var resolvedStatsLocation: CaptureVideoStatsOverlayLocation {
        CaptureVideoStatsOverlayLocation(rawValue: videoStatsLocationRawValue) ?? .bottomLeft
    }

    var statsFontSize: CGFloat { 13 }

    var isStatsOverlayFullscreenActive: Bool {
        #if os(macOS)
        isFullscreenActive
        #else
        false
        #endif
    }

    var videoStatsLabel: String? {
        guard let stats = latestVideoFrameRateStats else { return nil }
        let resolution = resolutionLabel
        let measured = Int(stats.presentationFPS.rounded())
        let configuredFPS = statsOverlayConfiguredFPS(fallbackMeasured: measured)
        let stutter = formatThreeDecimals(stats.maxPresentationGap)
        return "Res: \(resolution) @ \(configuredFPS) | " +
            "FPS: \(stats.frames) | Drops: \(stats.droppedFrames) | Stutter: \(stutter)"
    }

    var shouldShowMaxFPSWarning: Bool {
        capture.state == .running && lowMaxFPSWarningPollCount >= maxFPSWarningPollThreshold
    }

    var maxFPSWarningLabel: String? {
        guard let stats = latestVideoFrameRateStats else { return nil }
        return "FPS: \(stats.frames)"
    }

    var maxFPSWarningLocation: CaptureVideoStatsOverlayLocation {
        if shouldShowStatsOverlay && resolvedStatsLocation == .bottomLeft {
            return .bottomRight
        }
        return .bottomLeft
    }

    func updateMaxFPSWarningPollCount(with stats: CaptureVideoFrameRateStats) {
        let configuredFPS = statsOverlayConfiguredFPS(fallbackMeasured: stats.frames)
        if configuredFPS - stats.frames > 10 {
            lowMaxFPSWarningPollCount += 1
        } else {
            lowMaxFPSWarningPollCount = 0
        }
    }

    /// Prefer connect-panel selection; device-reported nominal can lag across stop/start.
    func statsOverlayConfiguredFPS(fallbackMeasured: Int) -> Int {
        if let id = capture.selectedVideoDeviceUniqueID,
           let device = AVCaptureDevice(uniqueID: id),
           let eff = CaptureFormatSelector.effectiveFormatForDisplay(
               device: device,
               preferences: capture.formatPreferences
           ) {
            return Int(eff.frameRate.rounded())
        }
        if let nominal = capture.nominalVideoFrameRate {
            return Int(nominal.rounded())
        }
        return fallbackMeasured
    }

    var resolutionLabel: String {
        guard let size = capture.videoSize else { return "—" }
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        return "\(width)x\(height)"
    }

    func formatThreeDecimals(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    @ViewBuilder
    func statsOverlay(_ label: String) -> some View {
        VStack {
            Text(label)
                .font(.system(size: statsFontSize, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .frame(maxHeight: 21)
                .background(Color(white: 0.2).opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
        }
        .padding(resolvedStatsLocation.edgePadding(isFullscreen: isStatsOverlayFullscreenActive))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: resolvedStatsLocation.alignment)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    func maxFPSWarningOverlay(_ label: String) -> some View {
        Button {
            isShowingMaxFPSInfo = true
        } label: {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: "info.circle")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
        .padding(.vertical, 0)
        .background(Color.red.opacity(0.92), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .padding(maxFPSWarningLocation.edgePadding(isFullscreen: isStatsOverlayFullscreenActive))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: maxFPSWarningLocation.alignment)
    }
}

struct MaxFPSWarningInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Low Frame Rate Detected")
                .font(.title2.weight(.semibold))

            Text(
                "The capture device is not delivering the full frame rate requested. This may be due to " +
                "device incompatibilities with iPad or bandwidth limitations."
            )

            Text(
                "If the capture device is connected through a USB hub, try a direct connection for better performance."
            )

            HStack {
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .font(.system(size: 15))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 340, maxWidth: 520, maxHeight: 360)
    }
}
