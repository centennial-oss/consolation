//
//  ContentView.swift
//  Consolation
//
//  Created by James Ranson on 4/12/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var capture = CaptureSessionManager()

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Color.black
                CaptureVideoPreview(session: capture.session)
            }
            .aspectRatio(16 / 9, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.quaternary, lineWidth: 1)
            }

            statusText

            HStack(spacing: 16) {
                switch capture.state {
                case .running:
                    Button("Stop Watching", role: .none) {
                        capture.stopWatching()
                    }
                    .keyboardShortcut(.cancelAction)
                default:
                    Button("Start Watching") {
                        Task { await capture.startWatching() }
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(capture.state == .requestingPermission)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(minWidth: 480, minHeight: 360)
    }

    @ViewBuilder
    private var statusText: some View {
        switch capture.state {
        case .idle:
            Text("Connect a capture card, then start watching.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .requestingPermission:
            Text("Requesting camera access…")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .noDevice:
            Text("No capture device found.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .ready:
            Text("Ready.")
                .font(.callout)
                .foregroundStyle(.secondary)
        case .running:
            if let name = capture.statusMessage {
                Text("Watching: \(name)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Text("Watching live input.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ContentView()
}
