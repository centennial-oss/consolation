import AVFoundation
import Foundation
import SwiftUI

extension ContentView {
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

    /// Prefer connect-panel selection; device-reported nominal can lag across stop/start.
    private func statsOverlayConfiguredFPS(fallbackMeasured: Int) -> Int {
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
                .background(Color.gray.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
        }
        .padding(resolvedStatsLocation.edgePadding(isFullscreen: isStatsOverlayFullscreenActive))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: resolvedStatsLocation.alignment)
        .allowsHitTesting(false)
    }
}
