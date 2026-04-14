//
//  CaptureSessionManagerVideoHardware.swift
//  Consolation
//

@preconcurrency import AVFoundation
import Combine
import Foundation

extension CaptureSessionManager {
    func beginObservingVideoHardwareChanges() {
        refreshExternalCapturePresence()

        let connected = NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)
        let disconnected = NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)

        Publishers.Merge(
            connected.map { _ in () },
            disconnected.map { _ in () }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
            self?.handleVideoHardwareChanged()
        }
        .store(in: &hardwareCancellables)
    }

    func handleVideoHardwareChanged() {
        if state == .running {
            // Keep the connect panel selection stable while a session is active; only refresh device lists.
            refreshVideoDeviceUniverse(reconcileSelection: false)
            refreshMediaCaptureAuthorizationStatuses()
            if let active = activeSessionVideoDeviceUniqueID,
               AVCaptureDevice(uniqueID: active) == nil {
                stopWatchingAfterDeviceDisconnect()
            }
            return
        }

        refreshVideoDeviceUniverse(reconcileSelection: true)
        refreshMediaCaptureAuthorizationStatuses()

        if !hasNoVideoDevices, state == .noDevice {
            state = .idle
            statusMessage = nil
        }
    }

    func refreshVideoDeviceUniverse(reconcileSelection: Bool) {
        let devices = CaptureVideoDeviceDiscovery.discoverSortedVideoDevices()
        let noVideoDevices = devices.isEmpty
        if hasNoVideoDevices != noVideoDevices {
            hasNoVideoDevices = noVideoDevices
        }

        var usb: [CaptureDeviceSummary] = []
        var cameras: [CaptureDeviceSummary] = []
        for device in devices {
            let row = CaptureDeviceSummary(id: device.uniqueID, localizedName: device.localizedName)
            if deviceIsUSBVideoCapture(device) {
                usb.append(row)
            } else {
                cameras.append(row)
            }
        }
        if usbCaptureDeviceEntries != usb {
            usbCaptureDeviceEntries = usb
        }
        if cameraDeviceEntries != cameras {
            cameraDeviceEntries = cameras
        }
        refreshExternalCapturePresence()
        if reconcileSelection {
            reconcileSelectedVideoDevice(with: devices)
        }
        logRawVideoCapabilitiesIfChanged(devices: devices)
    }

    func reconcileSelectedVideoDevice(with devices: [AVCaptureDevice]) {
        let ids = Set(devices.map(\.uniqueID))

        if let current = selectedVideoDeviceUniqueID, ids.contains(current) {
            return
        }

        if let saved = CaptureVideoDeviceUserDefaults.loadSelectedDeviceUniqueID(), ids.contains(saved) {
            selectedVideoDeviceUniqueID = saved
            return
        }

        let usbDevices = devices.filter { deviceIsUSBVideoCapture($0) }
        let cameraOnly = devices.filter { !deviceIsUSBVideoCapture($0) }
        let pick = usbDevices.first ?? cameraOnly.first
        selectedVideoDeviceUniqueID = pick?.uniqueID
        CaptureVideoDeviceUserDefaults.saveSelectedDeviceUniqueID(pick?.uniqueID)
    }

    func stopWatchingAfterDeviceDisconnect() {
        state = .noDevice
        statusMessage = "Video device disconnected."
        Task { @MainActor in
            await backend.stopWatching(with: session)
            self.refreshVideoDeviceUniverse(reconcileSelection: true)
            self.activeSessionVideoDeviceUniqueID = nil
            if self.hasNoVideoDevices {
                self.state = .noDevice
                self.statusMessage = "Video device disconnected."
            } else {
                self.state = .idle
                self.statusMessage = nil
            }
            self.isAudioMuted = CaptureAudioUserDefaults.loadIsMuted()
            self.volumeLevel = CaptureAudioUserDefaults.loadVolumeLevel()
            self.audioBufferLength = CaptureAudioUserDefaults.loadBufferLength()
            self.videoSize = nil
            self.refreshMediaCaptureAuthorizationStatuses()
        }
    }

    private func logRawVideoCapabilitiesIfChanged(devices: [AVCaptureDevice]) {
        let signature = rawVideoCapabilitiesSignature(devices: devices)
        guard signature != lastLoggedVideoCapabilitiesSignature else { return }
        lastLoggedVideoCapabilitiesSignature = signature
        print(signature)
    }

    private func rawVideoCapabilitiesSignature(devices: [AVCaptureDevice]) -> String {
        guard !devices.isEmpty else {
            return "Consolation video capabilities changed:\n  (no video devices found)"
        }

        var lines: [String] = ["Consolation video capabilities changed:"]
        for device in devices {
            lines.append("Device: \(device.localizedName) [\(device.uniqueID)]")

            struct PixelKey: Hashable {
                let width: Int
                let height: Int
            }

            var ratesByPixel: [PixelKey: Set<Double>] = [:]
            for format in device.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let key = PixelKey(width: Int(dims.width), height: Int(dims.height))
                var rates = ratesByPixel[key, default: []]
                for range in format.videoSupportedFrameRateRanges {
                    rates.insert(range.minFrameRate)
                    rates.insert(range.maxFrameRate)
                }
                ratesByPixel[key] = rates
            }

            let sortedPixels = ratesByPixel.keys.sorted { lhs, rhs in
                let leftPixels = lhs.width * lhs.height
                let rightPixels = rhs.width * rhs.height
                if leftPixels != rightPixels { return leftPixels > rightPixels }
                if lhs.width != rhs.width { return lhs.width > rhs.width }
                return lhs.height > rhs.height
            }

            for pixel in sortedPixels {
                let fpsValues = (ratesByPixel[pixel] ?? []).sorted(by: >)
                let fpsList = fpsValues.map { String(format: "%.6f", $0) }.joined(separator: ", ")
                lines.append("  \(pixel.width)x\(pixel.height): \(fpsList)")
            }

            lines.append("  Raw format ranges:")
            for format in device.formats {
                let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let rawRanges = format.videoSupportedFrameRateRanges
                    .map { "\(String(format: "%.6f", $0.minFrameRate))-\(String(format: "%.6f", $0.maxFrameRate))" }
                    .joined(separator: ", ")
                lines.append("    \(dims.width)x\(dims.height): \(rawRanges)")
            }
        }
        return lines.joined(separator: "\n")
    }
}
