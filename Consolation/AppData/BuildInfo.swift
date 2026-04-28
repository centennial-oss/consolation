//
//  BuildInfo.swift
//  Consolation
//
//  Version and build metadata. BuildInfo.generated.swift is produced by the
//  "Generate Build Info" Run Script phase and supplies commit, date, and arch.
//

import Foundation

enum BuildInfo {
    /// Semantic version (from Info.plist / MARKETING_VERSION). Use TAGVER at build to override.
    nonisolated static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "local"
    }

    static var commit: String { BuildInfoGenerated.buildCommit }
    static var buildDate: String { BuildInfoGenerated.buildDate }
    static var buildType: String { BuildInfoGenerated.buildConfiguration }
    static var buildArch: String { BuildInfoGenerated.buildArch }
    nonisolated static var platform: String {
        #if os(macOS)
        "macOS"
        #else
        "iPad"
        #endif
    }

    /// Copyable blob for support/debug (e.g. paste into issues).
    static var copyableBlob: String {
        """
        Version: \(version) (\(platform), \(buildArch))
        Build Type: \(buildType)
        Date: \(buildDate)
        Commit: 4b79e271fe88b022ce0aa3b3e865ef954fe51ab
        """
    }
}
