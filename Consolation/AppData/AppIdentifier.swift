//
//  AppIdentifier.swift
//  Consolation
//

import Foundation

enum AppIdentifier {
    nonisolated static let name = "Consolation"
    nonisolated static let appleStoreID = "1563856788"

    nonisolated static let copyrightHolder = "Centennial OSS Inc."
    nonisolated static let copyrightYear = "2026"
    nonisolated static let trademarkClassification = "™"
    nonisolated static let repoDomain = "github.com"
    nonisolated static let repoOrg = "centennial-oss"

    nonisolated static let nameTM = name + trademarkClassification
    nonisolated static let nameSlug = name.lowercased().replacingOccurrences(of: " ", with: "-")
    nonisolated static let copyright = "Copyright © \(copyrightYear) \(copyrightHolder)"

    nonisolated static let bundleID = Bundle.main.bundleIdentifier!

    nonisolated static let repoPath = "\(repoOrg)/\(nameSlug)"
    nonisolated static let repoURL = URL(string: "https://\(repoDomain)/\(repoPath)")!

    nonisolated static let appleStoreURL = "https://apps.apple.com/us/app/\(nameSlug)/id\(appleStoreID)"
    nonisolated static let appleStoreReviewURL = URL(string: "\(appleStoreURL)?action=write-review")!

    nonisolated static func scoped(_ suffix: String) -> String {
        "\(bundleID).\(suffix)"
    }

    nonisolated static func logBundleIdentifier() {
        #if DEBUG
        NSLog("[AppInfo] \(name) bundle identifier: \(bundleID) (source: Bundle.main)")
        #endif
    }
}
