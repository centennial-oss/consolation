//
//  AboutView.swift
//  Consolation
//

import SwiftUI

struct AboutConsolationView: View {
    let onClose: () -> Void

    private let githubURL = URL(string: "https://github.com/centennial-oss/consolation")!
    private let appStoreReviewURL = URL(string: "https://google.com")!

    @State private var isGitHubLinkHovered = false
    @State private var isAppStoreLinkHovered = false
    @State private var didCopyBuildInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Text(BuildInfo.copyright)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Label(
                "\(BuildInfo.appName) is a USB Capture Card utility for viewing gaming consoles, Raspberry Pis, " +
                    "and other HDMI devices on a Mac or iPad.",
                systemImage: "play.rectangle"
            )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "External USB Video Class (UVC) capture hardware is required.",
                systemImage: "exclamationmark.triangle"
            )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Label(
                "\(BuildInfo.appName) is 100% private. It does not collect analytics or snoop on your usage. " +
                    "Nothing ever leaves your device. Period.",
                systemImage: "shield"
            )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Label("This software is completely free and open source for you to enjoy.",
                systemImage: "heart"
            )
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            Link(destination: githubURL) {
                Label("GitHub: centennial-oss/consolation",
                systemImage: "arrow.up.right.square"
            )
                    .foregroundStyle(linkColor)
                    .underline(isGitHubLinkHovered, color: linkColor.opacity(0.8))
            }
            .font(.system(size: 15))
            #if os(macOS)
            .onHover { isGitHubLinkHovered = $0 }
            #endif

            buildInfoSection

            HStack(spacing: 12) {
                Link(destination: appStoreReviewURL) {
                    Label("Rate \(BuildInfo.appName) on the App Store",
                    systemImage: "star.leadinghalf.filled"
                )
                        .foregroundStyle(linkColor)
                        .underline(isAppStoreLinkHovered, color: linkColor.opacity(0.8))
                }
                .font(.system(size: 14))
                #if os(macOS)
                .onHover { isAppStoreLinkHovered = $0 }
                #endif

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
        .frame(width: 540)
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
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(BuildInfo.appName)
                    .font(.system(size: 30, weight: .semibold))

                Text("v" + BuildInfo.version)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var buildInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Build info (copy for support)", systemImage: "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            Text(BuildInfo.copyableBlob)
                .font(.system(size: 14, design: .monospaced))
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(didCopyBuildInfo ? "✓ Copied" : "Copy to Clipboard") {
                copyBuildInfo()
            }
            .font(.system(size: 15))
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
    }

    private var linkColor: Color {
        #if os(macOS)
        Color(nsColor: .linkColor)
        #else
        Color(uiColor: .link)
        #endif
    }

    private func copyBuildInfo() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(BuildInfo.copyableBlob, forType: .string)
        #elseif os(iOS)
        UIPasteboard.general.string = BuildInfo.copyableBlob
        #endif
        didCopyBuildInfo = true
    }
}

#Preview {
    AboutConsolationView {}
}
