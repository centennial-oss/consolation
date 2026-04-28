//
//  ContentViewZoomPersistence.swift
//  Consolation
//

import SwiftUI

extension ContentView {
    @ViewBuilder
    var captureVideoPreview: some View {
        // IMPT: Keep this preview view mounted even while idle. On macOS, `CaptureVideoPreview`
        // owns the `AVCaptureVideoPreviewLayer`; creating/attaching that layer only after
        // the session starts caused UVC capture devices to fall back to ~25 FPS. The stable
        // sequence is: preview layer exists, layer has the session, then the session starts.
        CaptureVideoPreview(
            session: capture.session,
            isRunning: capture.state == .running,
            previewZoomLevel: previewZoomLevel,
            previewPanOffset: previewPanOffset,
            onDoubleClick: {
                #if os(macOS)
                zoomWindowToVideoAspectIfPossible()
                #endif
            },
            onPanDelta: { delta in
                guard previewZoomLevel > 0 else { return }
                previewPanOffset.width += delta.width
                previewPanOffset.height += delta.height
            }
        )
        .ignoresSafeArea()
        #if os(iOS)
        .simultaneousGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard previewZoomLevel > 0 else { return }
                    let delta = CGSize(
                        width: value.translation.width - previewPanDragLastTranslation.width,
                        height: value.translation.height - previewPanDragLastTranslation.height
                    )
                    previewPanDragLastTranslation = value.translation
                    previewPanOffset.width += delta.width
                    previewPanOffset.height += delta.height
                }
                .onEnded { _ in
                    previewPanDragLastTranslation = .zero
                }
        )
        #endif
    }

    func loadPreviewZoomLevelForSelectedDevice() {
        guard let deviceID = capture.selectedVideoDeviceUniqueID else {
            previewZoomLevel = 0
            return
        }
        previewZoomLevel = CaptureVideoZoomUserDefaults.loadPreviewZoomLevel(forDeviceID: deviceID)
    }

    func savePreviewZoomLevel(_ zoomLevel: Double) {
        guard let deviceID = capture.selectedVideoDeviceUniqueID else { return }
        CaptureVideoZoomUserDefaults.savePreviewZoomLevel(zoomLevel, forDeviceID: deviceID)
    }
}
