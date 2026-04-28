//
//  HelpView.swift
//  Consolation
//

import SwiftUI

struct HelpConsolationView: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            Divider()

            helpSection(
                title: "Getting Started",
                systemImage: "play.rectangle",
                body: "Connect a USB capture device, select it from the list, and press the Play button."
            )

            helpSection(
                title: "Frame Rate",
                systemImage: "lightbulb",
                body: "For best results, select a frame rate that is equal to or higher than the frame rate " +
                    "of the source input. If playback frame rate is lower than expected, avoid USB hubs and " +
                    "replace low-quality cables."
            )

            #if os(macOS)
            helpSection(
                title: "Video Controls",
                systemImage: "rectangle.and.arrow.up.right.and.arrow.down.left",
                body: "Use the View menu to resize the playback window, rotate the picture, mirror the image, " +
                    "and show frame rate stats."
            )
            #else
            helpSection(
                title: "Video Controls",
                systemImage: "rectangle.and.arrow.up.right.and.arrow.down.left",
                body: "Use the View menu to rotate the picture, mirror the image, " +
                    "and show frame rate stats."
            )
            #endif

            helpSection(
                title: "Audio Controls",
                systemImage: "speaker.wave.2",
                body: "Use the Audio menu to mute playback, set the volume, or adjust the audio buffer " +
                    "if you hear dropouts or stuttering. A larger buffer may improve audio performance " +
                    "while causing audio to lag further behind the video."
            )

            helpSection(
                title: "Device Support",
                systemImage: "externaldrive.connected.to.line.below",
                body: "While any USB Video Class (UVC) device should work with \(BuildInfo.appName), video " +
                    "quality ultimately depends on the capture device hardware. Some devices " +
                    " may advertise resolutions and frame rates beyond their actual capabilities."
            )

            Divider()

            HStack {
                Spacer()

                Button("Close") {
                    onClose()
                }
                .font(.system(size: 15))
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 640)
        #if os(macOS)
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
        #endif
    }

    private var header: some View {
        HStack(spacing: 12) {
            AppIconImage()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(BuildInfo.appName) Help")
                    .font(.system(size: 26, weight: .semibold))
            }
        }
    }

    private func helpSection(title: String, systemImage: String, body: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                Text(body)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 18))
                .frame(width: 24)
        }
    }
}

#Preview {
    HelpConsolationView {}
}
