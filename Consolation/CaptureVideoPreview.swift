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
    let onDoubleClick: () -> Void

    init(
        session: AVCaptureSession,
        isRunning: Bool,
        onDoubleClick: @escaping () -> Void = {}
    ) {
        self.session = session
        self.isRunning = isRunning
        self.onDoubleClick = onDoubleClick
    }

    func makeNSView(context: Context) -> MacPreviewView {
        let view = MacPreviewView(frame: .zero)
        view.previewLayer.session = session
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: MacPreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        nsView.onDoubleClick = onDoubleClick

        // Force the layer to recalculate its internal projection matrix when the video starts.
        // AVCaptureVideoPreviewLayer has a known bug where it fails to naturally rescale
        // incoming video feeds to fill the view if the inputs attach while the view was statically sized.
        if isRunning {
            DispatchQueue.main.async {
                let rect = nsView.bounds
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                nsView.previewLayer.frame = .zero
                nsView.previewLayer.frame = rect
                CATransaction.commit()
            }
        }
    }
}

#elseif os(iOS)
import UIKit

final class IOSPreviewView: UIView {
    override static var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("IOSPreviewView must be backed by AVCaptureVideoPreviewLayer")
        }
        return previewLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        previewLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

struct CaptureVideoPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isRunning: Bool
    let onDoubleClick: () -> Void

    init(
        session: AVCaptureSession,
        isRunning: Bool,
        onDoubleClick: @escaping () -> Void = {}
    ) {
        self.session = session
        self.isRunning = isRunning
        self.onDoubleClick = onDoubleClick
    }

    func makeUIView(context: Context) -> IOSPreviewView {
        let view = IOSPreviewView(frame: .zero)
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: IOSPreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }

        if isRunning {
            DispatchQueue.main.async {
                let rect = uiView.bounds
                uiView.previewLayer.frame = .zero
                uiView.previewLayer.frame = rect
            }
        }
    }
}
#endif
