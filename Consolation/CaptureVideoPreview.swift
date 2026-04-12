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

    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = previewLayer
        previewLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        previewLayer.frame = bounds
    }
}

struct CaptureVideoPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> MacPreviewView {
        let view = MacPreviewView(frame: .zero)
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: MacPreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
    }
}

#elseif os(iOS)
import UIKit

final class IOSPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
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

    func makeUIView(context: Context) -> IOSPreviewView {
        let view = IOSPreviewView(frame: .zero)
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: IOSPreviewView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}
#endif
