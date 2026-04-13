//
//  CaptureVideoPreview.swift
//  Consolation
//

import AVFoundation
import SwiftUI

#if os(macOS)
import AppKit

final class MacPreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    var onDoubleClick: () -> Void = {}

    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(previewLayer)
        previewLayer.videoGravity = .resizeAspect
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        resizePreviewLayer()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        resizePreviewLayer()
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        resizePreviewLayer()
    }

    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        resizePreviewLayer()
    }

    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        resizePreviewLayer()
    }

    func resizePreviewLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick()
            return
        }

        guard let window else {
            super.mouseDown(with: event)
            return
        }

        window.performDrag(with: event)
    }
}

struct CaptureVideoPreview: NSViewRepresentable {
    let session: AVCaptureSession
    let isRunning: Bool
    let isClassicAspectFillEnabled: Bool
    let onDoubleClick: () -> Void

    init(
        session: AVCaptureSession,
        isRunning: Bool,
        isClassicAspectFillEnabled: Bool = false,
        onDoubleClick: @escaping () -> Void = {}
    ) {
        self.session = session
        self.isRunning = isRunning
        self.isClassicAspectFillEnabled = isClassicAspectFillEnabled
        self.onDoubleClick = onDoubleClick
    }

    func makeNSView(context: Context) -> MacPreviewView {
        let view = MacPreviewView(frame: .zero)
        view.previewLayer.session = session
        view.onDoubleClick = onDoubleClick
        return view
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateNSView(_ nsView: MacPreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        nsView.onDoubleClick = onDoubleClick

        // Force the layer to recalculate its internal projection matrix when the video starts.
        // AVCaptureVideoPreviewLayer has a known bug where it fails to naturally rescale
        // incoming video feeds to fill the view if the inputs attach while the view was statically sized.
        if isRunning, !context.coordinator.wasRunning {
            DispatchQueue.main.async {
                let rect = nsView.bounds
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                nsView.previewLayer.frame = .zero
                nsView.previewLayer.frame = rect
                CATransaction.commit()
            }
        }
        context.coordinator.wasRunning = isRunning
    }

    final class Coordinator {
        var wasRunning = false
    }
}

#elseif os(iOS)
import UIKit

final class IOSPreviewView: UIView {
    let previewLayer = AVCaptureVideoPreviewLayer()
    private var previewZoomScale: CGFloat = 1
    private var previewVerticalOffsetRatio: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        resizePreviewLayer()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        applyPreviewConnectionSettings()
    }

    func setPreviewActive(_ active: Bool, session: AVCaptureSession?) {
        isHidden = !active
        previewLayer.session = active ? session : nil
        if active {
            applyPreviewConnectionSettings()
        }
    }

    func setPreviewZoom(scale: CGFloat, verticalOffsetRatio: CGFloat) {
        let clampedScale = max(scale, 1)
        guard previewZoomScale != clampedScale ||
              previewVerticalOffsetRatio != verticalOffsetRatio
        else { return }
        previewZoomScale = clampedScale
        previewVerticalOffsetRatio = verticalOffsetRatio
        resizePreviewLayer()
    }

    func resizePreviewLayer() {
        let scaledWidth = bounds.width * previewZoomScale
        let scaledHeight = bounds.height * previewZoomScale
        let scaledFrame = CGRect(
            x: (bounds.width - scaledWidth) / 2,
            y: ((bounds.height - scaledHeight) / 2) + (bounds.height * previewVerticalOffsetRatio),
            width: scaledWidth,
            height: scaledHeight
        )

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = scaledFrame
        CATransaction.commit()
    }

    /// USB capture is not a selfie camera: disable mirroring and let the layer follow the app orientation.
    func applyPreviewConnectionSettings() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = false
        }
        #if os(iOS)
        let angle: CGFloat = 0
        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        } else {
            print("Consolation iOS video: preview rotation angle \(angle) is not supported")
        }
        #endif
    }
}

struct CaptureVideoPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isRunning: Bool
    let isClassicAspectFillEnabled: Bool
    let onDoubleClick: () -> Void

    init(
        session: AVCaptureSession,
        isRunning: Bool,
        isClassicAspectFillEnabled: Bool = false,
        onDoubleClick: @escaping () -> Void = {}
    ) {
        self.session = session
        self.isRunning = isRunning
        self.isClassicAspectFillEnabled = isClassicAspectFillEnabled
        self.onDoubleClick = onDoubleClick
    }

    func makeUIView(context: Context) -> IOSPreviewView {
        let view = IOSPreviewView(frame: .zero)
        view.previewLayer.videoGravity = isClassicAspectFillEnabled ? .resizeAspectFill : .resizeAspect
        view.setPreviewZoom(
            scale: classicAspectFillZoomScale,
            verticalOffsetRatio: classicAspectFillVerticalOffsetRatio
        )
        view.setPreviewActive(isRunning, session: session)
        return view
    }

    func updateUIView(_ uiView: IOSPreviewView, context: Context) {
        let videoGravity: AVLayerVideoGravity = isClassicAspectFillEnabled ? .resizeAspectFill : .resizeAspect
        if uiView.previewLayer.videoGravity != videoGravity {
            uiView.previewLayer.videoGravity = videoGravity
        }

        uiView.setPreviewZoom(
            scale: classicAspectFillZoomScale,
            verticalOffsetRatio: classicAspectFillVerticalOffsetRatio
        )
        uiView.setPreviewActive(isRunning, session: session)

        if isRunning {
            DispatchQueue.main.async {
                uiView.resizePreviewLayer()
                uiView.applyPreviewConnectionSettings()
            }
        } else {
            uiView.applyPreviewConnectionSettings()
        }
    }

    static func dismantleUIView(_ uiView: IOSPreviewView, coordinator: ()) {
        uiView.setPreviewActive(false, session: nil)
    }

    private var classicAspectFillZoomScale: CGFloat {
        isClassicAspectFillEnabled ? 1.175 : 1
    }

    private var classicAspectFillVerticalOffsetRatio: CGFloat {
        isClassicAspectFillEnabled ? 0.03 : 0
    }
}
#endif
