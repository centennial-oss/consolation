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
        .onHover { isHovering in
            isPlaybackControlsHoverActive = isHovering
            if isHovering {
                cancelHoverHideTask()
                revealTransientChromeIfNeeded()
            } else {
                resetHoverTimer()
            }
        }
        #endif
    }

    /// Shared toolbar contents; macOS may offset/drag the whole bar, iOS keeps it fixed bottom-center.
    private var playbackControlsBar: some View {
        HStack(spacing: 20) {
            PlaybackToolbarIconButton(
                systemName: "power",
                accessibilityLabel: "Stop Watching",
                iconColor: .red,
                hoverTint: .white,
                action: { capture.stopWatching() }
            )

            HStack(spacing: 4) {
                PlaybackToolbarIconButton(
                    systemName: capture.isAudioMuted ? "speaker.slash.fill" : "speaker.fill",
                    accessibilityLabel: capture.isAudioMuted ? "Unmute audio" : "Mute audio",
                    iconColor: capture.isAudioMuted ? .accentColor : .white,
                    action: { capture.setAudioMuted(!capture.isAudioMuted) }
                )
                ZStack {
                    if !capture.isAudioMuted {
                        VStack(spacing: 20) {
                            Color.black.opacity(0.35)
                        }
                        .cornerRadius(14)
                        .allowsHitTesting(false)
                    }
                    Slider(
                        value: Binding(
                            get: { capture.volumeLevel },
                            set: { capture.setVolumeLevel($0) }
                        ),
                        in: 0...1,
                        onEditingChanged: handleSliderEditingChanged(_:)
                    )
                    .labelsHidden()
                    .frame(width: 150)
                    .tint(.white)
                    .disabled(capture.isAudioMuted)

                    if capture.isAudioMuted {
                        VStack(spacing: 20) {
                            Color.black.opacity(0.35)
                        }
                        .cornerRadius(14)
                        .allowsHitTesting(false)
                    }
                }
                .frame(width: 170)
                .frame(maxHeight: 28)
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
                systemName: isFullscreenActive
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right",
                accessibilityLabel: "Full Screen",
                iconColor: isFullscreenActive ? .accentColor : .white,
                action: { window?.toggleFullScreen(nil) }
            )
            #endif
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 42, style: .continuous))
        .shadow(radius: 8)
        .panelLiquidGlass(cornerRadius: 42)
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

    func handleSliderEditingChanged(_ isEditing: Bool) {
        if isEditing {
            guard !isPlaybackControlsInteractionActive else { return }
            isPlaybackControlsInteractionActive = true
            cancelHoverHideTask()
            revealTransientChromeIfNeeded()
            return
        }

        isPlaybackControlsInteractionActive = false
        resetHoverTimer()
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

    #if os(macOS)
    var isFullscreenActive: Bool {
        window?.styleMask.contains(.fullScreen) ?? false
    }
    #endif

}

/// Hover is tracked on the circular container. The SF Symbol does not hit-test, so moving over the
/// glyph does not steal tracking from the background circle (plain `NSImageView` hover otherwise clears it).
struct PlaybackToolbarIconButton: View {
    let systemName: String
    let accessibilityLabel: String
    var iconColor: Color = .primary
    /// Hover fill uses `hoverTint.opacity(0.16)` so alpha matches other toolbar icons.
    var hoverTint: Color = Color.white
    /// Hit target and icon size; glyph uses half this point size (matches 36 → 18 on the playback bar).
    var dimension: CGFloat = 42
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
