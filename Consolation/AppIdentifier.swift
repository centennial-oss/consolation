//
//  AppIdentifier.swift
//  Consolation
//

import Foundation

enum AppIdentifier {
    nonisolated static let bundleID = Bundle.main.bundleIdentifier!
    nonisolated static let appStoreID = "1563856788"

    nonisolated static func scoped(_ suffix: String) -> String {
        "\(bundleID).\(suffix)"
    }

    nonisolated static func logBundleIdentifier() {
        #if DEBUG
        print("\(BuildInfo.appName) bundle identifier: \(bundleID) (source: Bundle.main)")
        #endif
    }
}
