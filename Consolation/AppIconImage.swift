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
        Image(nsImage: NSApp.applicationIconImage)
        #else
        Image(uiImage: UIImage(named: "AppIcon") ?? UIImage())
        #endif
    }
}
