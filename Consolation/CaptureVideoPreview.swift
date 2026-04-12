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
        layer?.addSublayer(previewLayer)
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
    let isRunning: Bool

    func makeNSView(context: Context) -> MacPreviewView {
        let view = MacPreviewView(frame: .zero)
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: MacPreviewView, context: Context) {
        if nsView.previewLayer.session !== session {
            nsView.previewLayer.session = session
        }
        
        // Force the layer to recalculate its internal projection matrix when the video starts.
        // AVCaptureVideoPreviewLayer has a known bug where it fails to naturally rescale
        // incoming video feeds to fill the view if the inputs attach while the view was statically sized.
        if isRunning {
            DispatchQueue.main.async {
                let rect = nsView.bounds
                nsView.previewLayer.frame = .zero
                nsView.previewLayer.frame = rect
            }
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
    let isRunning: Bool

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
