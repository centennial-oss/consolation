//
//  ContentViewPlaybackControls.swift
//  Consolation
//

import SwiftUI

extension ContentView {
    var playbackControls: some View {
        Group {
            #if os(iOS)
            HStack {
                Spacer(minLength: 0)
                playbackControlsBar
                Spacer(minLength: 0)
            }
            #else
            playbackControlsBar
            #endif
        }
        .padding(.bottom, playbackControlsBottomPadding)
        #if os(macOS)
        .offset(playbackControlsCurrentOffset)
        .simultaneousGesture(playbackControlsDragGesture)
        #endif
    }

    /// Shared toolbar contents; macOS may offset/drag the whole bar, iOS keeps it fixed bottom-center.
    private var playbackControlsBar: some View {
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

            #if os(iOS)
            if isIPad {
                PlaybackToolbarTextToggleButton(
                    title: "4:3",
                    accessibilityLabel: "Fill screen with 4:3 video",
                    isOn: isClassicAspectFillEnabled,
                    action: {
                        isClassicAspectFillEnabled.toggle()
                        resetHoverTimer()
                    }
                )
            }
            #endif

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

    var isIPadClassicAspectFillActive: Bool {
        #if os(iOS)
        isIPad && isClassicAspectFillEnabled
        #else
        false
        #endif
    }

    var isIPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        false
        #endif
    }

}

/// Hover is tracked on the circular container. The SF Symbol does not hit-test, so moving over the
/// glyph does not steal tracking from the background circle (plain `NSImageView` hover otherwise clears it).
struct PlaybackToolbarIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var iconColor: Color = .primary
    /// Hover fill uses `hoverTint.opacity(0.16)` so alpha matches other toolbar icons.
    var hoverTint: Color = Color.accentColor
    /// Hit target and icon size; glyph uses half this point size (matches 36 → 18 on the playback bar).
    var dimension: CGFloat = 36
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    private var iconPointSize: CGFloat { dimension * 0.5 }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isHovered && isEnabled ? hoverTint.opacity(0.16) : Color.clear)
                Image(systemName: systemName)
                    .font(.system(size: iconPointSize, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .allowsHitTesting(false)
            }
            .frame(width: dimension, height: dimension)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct PlaybackToolbarTextToggleButton: View {
    let title: String
    let accessibilityLabel: String
    let isOn: Bool
    var dimension: CGFloat = 36
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isOn ? Color.accentColor : Color.white)
                .frame(width: dimension, height: dimension)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn || isHovered ? Color.accentColor.opacity(0.16) : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
