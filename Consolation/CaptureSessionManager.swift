//
//  CaptureSessionManager.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Combine
import Foundation

/// Serializes `AVCaptureSession` configuration and `startRunning` / `stopRunning`.
private actor CaptureSessionBackend {
    private var videoInput: AVCaptureDeviceInput?

    func startWatching(with session: AVCaptureSession) throws -> String {
        session.beginConfiguration()

        if let existing = videoInput {
            session.removeInput(existing)
            videoInput = nil
        }

        guard let device = Self.pickPreferredVideoDevice() else {
            session.commitConfiguration()
            throw CaptureSessionError.noVideoDevice
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            throw error
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CaptureSessionError.cannotAddVideoInput
        }

        session.addInput(input)
        videoInput = input

        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
        }

        session.commitConfiguration()
        session.startRunning()
        return device.localizedName
    }

    func stopWatching(with session: AVCaptureSession) {
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        if let input = videoInput {
            session.removeInput(input)
            videoInput = nil
        }
        session.commitConfiguration()
    }

    /// Prefers external / UVC-style capture devices; falls back to other cameras (useful for Simulator).
    private static func pickPreferredVideoDevice() -> AVCaptureDevice? {
        var types: [AVCaptureDevice.DeviceType] = [.external]

        #if os(iOS)
        types.append(.builtInWideAngleCamera)
        types.append(.continuityCamera)
        #elseif os(macOS)
        types.append(.builtInWideAngleCamera)
        #endif

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: types,
            mediaType: .video,
            position: .unspecified
        )

        let devices = discovery.devices

        if let external = devices.first(where: { $0.deviceType == .external }) {
            return external
        }

        #if os(iOS)
        if let continuity = devices.first(where: { $0.deviceType == .continuityCamera }) {
            return continuity
        }
        #endif

        return devices.first
    }
}

private enum CaptureSessionError: LocalizedError {
    case noVideoDevice
    case cannotAddVideoInput

    var errorDescription: String? {
        switch self {
        case .noVideoDevice:
            return "No video capture device was found."
        case .cannotAddVideoInput:
            return "This capture device cannot be used as a video input."
        }
    }
}

/// Owns the shared `AVCaptureSession` for preview layers, delegates start/stop to `CaptureSessionBackend`, and publishes UI state on the main actor.
@MainActor
final class CaptureSessionManager: ObservableObject {
    @Published private(set) var state: CaptureState = .idle

    /// Device name while running, or auxiliary detail for failures.
    @Published private(set) var statusMessage: String?

    /// Shared with `AVCaptureVideoPreviewLayer`; mutations happen only on `CaptureSessionBackend`.
    nonisolated let session = AVCaptureSession()

    private let backend = CaptureSessionBackend()

    init() {}

    func startWatching() async {
        statusMessage = nil
        state = .requestingPermission

        let granted = await Self.requestCameraAccessIfNeeded()
        guard granted else {
            state = .failed("Camera access is required to show the capture feed.")
            statusMessage = "Allow camera access in Settings to continue."
            return
        }

        do {
            let name = try await backend.startWatching(with: session)
            state = .running
            statusMessage = name
        } catch let error as CaptureSessionError {
            switch error {
            case .noVideoDevice:
                state = .noDevice
                statusMessage = error.localizedDescription
            case .cannotAddVideoInput:
                state = .failed(error.localizedDescription)
                statusMessage = error.localizedDescription
            }
        } catch {
            state = .failed(error.localizedDescription)
            statusMessage = error.localizedDescription
        }
    }

    func stopWatching() {
        Task { @MainActor in
            await backend.stopWatching(with: session)
            self.state = .idle
            self.statusMessage = nil
        }
    }

    private static func requestCameraAccessIfNeeded() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
