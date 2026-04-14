//
//  CaptureVideoFormatModels.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Foundation

// MARK: - Resolution / frame rate menu (connect panel)

struct CaptureVideoFormatMenuResolution: Identifiable, Hashable, Sendable {
    let width: Int
    let height: Int
    /// Highest-first unique rates offered for this pixel size across all formats.
    let frameRatesDescending: [Double]

    var id: String { "\(width)×\(height)" }
}

enum CaptureVideoFormatDisplayStrings: Sendable {
    nonisolated static func resolutionAndFrameLabel(width: Int, height: Int, frameRate: Double) -> String {
        "\(width)×\(height) @ \(Int(round(frameRate)))p"
    }
}

/// Pixel dimensions and frame rate for connect-panel labels (avoids large tuples for SwiftLint).
struct CaptureVideoFormatEffectiveDisplay: Equatable, Sendable {
    let width: Int
    let height: Int
    let frameRate: Double
}

enum CaptureVideoFormatMenuRates: Sendable {
    nonisolated static func fromRange(_ range: AVFrameRateRange) -> Set<Double> {
        var rates: Set<Double> = [range.maxFrameRate]
        if range.minFrameRate > 0, abs(range.minFrameRate - range.maxFrameRate) > 0.5 {
            rates.insert(range.minFrameRate)
        }
        let commonRates: [Double] = [24, 25, 30, 50, 60, 120, 240]
        let epsilon = 0.5
        for fps in commonRates where fps >= range.minFrameRate - epsilon && fps <= range.maxFrameRate + epsilon {
            rates.insert(fps)
        }
        return rates
    }

    nonisolated static func deduplicatedDescending(_ rates: Set<Double>) -> [Double] {
        var bestByRoundedFPS: [Int: Double] = [:]
        for rate in rates {
            let roundedFPS = Int(rate.rounded())
            let currentDistance = abs((bestByRoundedFPS[roundedFPS] ?? rate) - Double(roundedFPS))
            if bestByRoundedFPS[roundedFPS] == nil || abs(rate - Double(roundedFPS)) < currentDistance {
                bestByRoundedFPS[roundedFPS] = rate
            }
        }
        return bestByRoundedFPS.keys.sorted(by: >).compactMap { bestByRoundedFPS[$0] }
    }
}
