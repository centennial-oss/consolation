//
//  BuildInfo.swift
//  Consolation
//
//  Version and build metadata. BuildInfo.generated.swift is produced by the
//  "Generate Build Info" Run Script phase and supplies commit, date, and arch.
//

import Foundation

enum BuildInfo {
    /// App display name (single source of truth for UI text).
    static var appName: String {
        "Consolation"
    }

    /// Semantic version (from Info.plist / MARKETING_VERSION). Use TAGVER at build to override.
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "local"
    }

    /// Copyright
    static var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "Copyright © 2026 Centennial OSS"
    }

    static var commit: String { BuildInfoGenerated.buildCommit }
    static var buildDate: String { BuildInfoGenerated.buildDate }
    static var buildType: String { BuildInfoGenerated.buildConfiguration }
    static var buildArch: String { BuildInfoGenerated.buildArch }

    /// Copyable blob for support/debug (e.g. paste into issues).
    static var copyableBlob: String {
        """
        Version: \(version) (\(buildArch))
        Commit: \(commit)
        Date: \(buildDate)
        Build Type: \(buildType)
        """
    }
}
