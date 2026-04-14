//
//  CaptureVideoStatsUserDefaults.swift
//  Consolation
//

import SwiftUI

enum CaptureVideoStatsOverlayLocation: String, CaseIterable {
    case bottomLeft
    case bottomRight
    case bottomCenter
    case topLeft
    case topRight
    case topCenter

    static var menuLocations: [CaptureVideoStatsOverlayLocation] {
        #if os(iOS)
        [.bottomLeft, .bottomRight]
        #else
        allCases
        #endif
    }

    var menuTitle: String {
        switch self {
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .bottomCenter: "Bottom Center"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .topCenter: "Top Center"
        }
    }

    var alignment: Alignment {
        switch self {
        case .bottomLeft: .bottomLeading
        case .bottomRight: .bottomTrailing
        case .bottomCenter: .bottom
        case .topLeft: .topLeading
        case .topRight: .topTrailing
        case .topCenter: .top
        }
    }

    func edgePadding(isFullscreen: Bool) -> EdgeInsets {
        let topPadding: CGFloat = isFullscreen ? 2 : -30

        return switch self {
        case .topLeft:
            EdgeInsets(top: topPadding, leading: 2, bottom: 2, trailing: 0)
        case .topRight, .topCenter:
            EdgeInsets(top: topPadding, leading: 0, bottom: 2, trailing: 2)
        case .bottomLeft, .bottomRight, .bottomCenter:
            EdgeInsets(top: 0, leading: 2, bottom: 2, trailing: 2)
        }
    }
}

enum CaptureVideoStatsUserDefaults {
    nonisolated static let showStatsKey = "org.centennialoss.consolation.showVideoStatsOverlay"
    nonisolated static let statsLocationKey = "org.centennialoss.consolation.videoStatsOverlayLocation"
    nonisolated static let defaultLocation = CaptureVideoStatsOverlayLocation.bottomLeft.rawValue
}
