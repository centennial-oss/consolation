//
//  ContentViewPlaybackControls.swift
//  Consolation
//

import SwiftUI

extension ContentView {
    var playbackControls: some View {
        HStack(spacing: 20) {
            PlaybackToolbarIconButton(
                systemName: "power",
                accessibilityLabel: "Stop Watching",
                iconColor: .red,
                hoverTint: .red,
                action: { capture.stopWatching() }
            )

            HStack(spacing: 6) {
                PlaybackToolbarIconButton(
                    systemName: capture.isAudioMuted ? "speaker.slash.fill" : "speaker.fill",
                    accessibilityLabel: capture.isAudioMuted ? "Unmute audio" : "Mute audio",
                    action: { capture.setAudioMuted(!capture.isAudioMuted) }
                )

                Slider(
                    value: Binding(
                        get: { capture.volumeLevel },
                        set: { capture.setVolumeLevel($0) }
                    ),
                    in: 0...1
                )
                .labelsHidden()
                .frame(width: 150)
                .disabled(capture.isAudioMuted)
                .gesture(playbackControlsInteractionGesture)
            }

            #if os(macOS)
            PlaybackToolbarIconButton(
                systemName: "arrow.up.left.and.arrow.down.right",
                accessibilityLabel: "Full Screen",
                action: { window?.toggleFullScreen(nil) }
            )
            #endif
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
        .shadow(radius: 8)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { setPlaybackControlsSize(proxy.size) }
                    .onChange(of: proxy.size) { _, size in setPlaybackControlsSize(size) }
            }
        }
        .padding(.bottom, playbackControlsBottomPadding)
        .offset(playbackControlsCurrentOffset)
        .simultaneousGesture(playbackControlsDragGesture)
    }

    var playbackControlsInteractionGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard !isPlaybackControlsInteractionActive else { return }
                isPlaybackControlsInteractionActive = true
                cancelHoverHideTask()
                revealTransientChromeIfNeeded()
            }
            .onEnded { _ in
                isPlaybackControlsInteractionActive = false
                resetHoverTimer()
            }
    }

}

/// Hover is tracked on the circular container. The SF Symbol does not hit-test, so moving over the
/// glyph does not steal tracking from the background circle (plain `NSImageView` hover otherwise clears it).
private struct PlaybackToolbarIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var iconColor: Color = .primary
    /// Hover fill uses `hoverTint.opacity(0.16)` so alpha matches other toolbar icons.
    var hoverTint: Color = Color.accentColor
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered && isEnabled ? hoverTint.opacity(0.16) : Color.clear)
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .allowsHitTesting(false)
            }
            .frame(width: 36, height: 36)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}
