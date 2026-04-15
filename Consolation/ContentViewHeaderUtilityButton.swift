//
//  ContentViewHeaderUtilityButton.swift
//  Consolation
//-

import SwiftUI

struct ContentViewHeaderUtilityButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.white.opacity(0.88))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isHovered ? Color.accentColor : Color.white.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
