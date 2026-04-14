//
//  CaptureVideoPreview+IOSOrientation.swift
//  Consolation
//

#if os(iOS)
import AVFoundation
import SwiftUI
import UIKit

extension IOSPreviewView {
    var activeVideoDeviceContext: CaptureVideoPreviewDeviceContext {
        CaptureVideoPreviewDeviceContext(session: previewLayer.session)
    }

    func applyLayerMirrorTransform(horizontal: Bool, vertical: Bool) {
        previewLayer.setAffineTransform(
            CGAffineTransform(
                scaleX: horizontal ? -1 : 1,
                y: vertical ? -1 : 1
            )
        )
    }

    func previewRotationAngleForCurrentInterfaceOrientation() -> CGFloat {
        switch currentInterfaceOrientation {
        case .portrait:
            return 270
        case .portraitUpsideDown:
            return 90
        case .landscapeLeft:
            return 0
        case .landscapeRight:
            return 180
        case .unknown:
            return 0
        @unknown default:
            return 0
        }
    }

    var currentInterfaceOrientation: UIInterfaceOrientation {
        guard let windowScene = window?.windowScene else { return .landscapeLeft }
        if #available(iOS 26.0, *) {
            return windowScene.effectiveGeometry.interfaceOrientation
        } else {
            return windowScene.interfaceOrientation
        }
    }

    func defaultMirrorOptions(
        for context: CaptureVideoPreviewDeviceContext
    ) -> CaptureVideoPreviewMirrorOptions {
        guard context.isCamera else { return [] }
        if currentInterfaceOrientation.isPortrait {
            return [.vertical]
        }
        return [.horizontal]
    }

    func schedulePreviewConnectionSettingsRefresh() {
        applyPreviewConnectionSettings()
        DispatchQueue.main.async { [weak self] in
            self?.applyPreviewConnectionSettings()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.applyPreviewConnectionSettings()
        }
    }

    func normalizedRotationAngle(_ angle: CGFloat) -> CGFloat {
        let normalized = Int(angle.rounded()) % 360
        return CGFloat(normalized >= 0 ? normalized : normalized + 360)
    }
}
#endif
