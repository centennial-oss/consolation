//
//  CaptureState.swift
//  Consolation
//

import Foundation

enum CaptureState: Equatable, Sendable {
    case idle
    case requestingPermission
    case noDevice
    case ready
    case running
    case failed(String)

    static func == (lhs: CaptureState, rhs: CaptureState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
            (.requestingPermission, .requestingPermission),
            (.noDevice, .noDevice),
            (.ready, .ready),
            (.running, .running):
            return true
        case let (.failed(a), .failed(b)):
            return a == b
        default:
            return false
        }
    }
}
