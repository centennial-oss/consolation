//
//  AppIconImage.swift
//  Consolation
//

import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct AppIconImage: View {
    var body: some View {
        appIcon
            .resizable()
    }

    private var appIcon: Image {
        #if os(macOS)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            Image(nsImage: iconImage)
        } else {
            Image(nsImage: NSApp.applicationIconImage)
        }
        #else
        Image(uiImage: Self.uiAppIconImage())
        #endif
    }

    #if os(iOS)
    private static func uiAppIconImage() -> UIImage {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons~ipad")
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons")
        guard let icons = icons as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
              let iconName = iconFiles.last,
              let image = UIImage(named: iconName) else {
            return UIImage(named: "AppIcon_1024") ?? UIImage()
        }
        return image
    }
    #endif
}
