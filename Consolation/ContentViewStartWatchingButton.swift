//
//  ContentViewStartWatchingButton.swift
//  Consolation
//

import SwiftUI

struct ContentViewStartWatchingButton: View {
    @ObservedObject var capture: CaptureSessionManager
    @State private var isHovered = false

    var body: some View {
        Button {
            Task { await capture.startWatching() }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.16))
                Image(systemName: "play.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(isHovered ? Color.accentColor : Color.white)
                    .allowsHitTesting(false)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .onHover { isHovered = $0 }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.defaultAction)
        .disabled(!capture.canStartWatching)
        .accessibilityLabel("Start Watching")
    }
}
