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
        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
        #endif
    }
}
