//
//  ContentViewWindowMac.swift
//  Consolation
//

import SwiftUI

#if os(macOS)
import AppKit

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
            view.window?.isMovableByWindowBackground = false
            view.window?.tabbingMode = .disallowed
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.tabbingMode = .disallowed
    }
}

extension ContentView {
    /// Double-click and **Z**: fit the window to the video aspect in the visible screen.
    /// When already fit, toggles native zoom (`NSWindow.zoom`).
    func zoomWindowToVideoAspectIfPossible() {
        guard let window else { return }
        guard let screen = window.screen else {
            window.zoom(nil)
            return
        }

        let visibleFrame = screen.visibleFrame
        let aspect = capture.videoSize ?? CGSize(width: 16, height: 9)
        let aspectWidth = aspect.width == 0 ? 16 : aspect.width
        let aspectHeight = aspect.height == 0 ? 9 : aspect.height
        let ratio = aspectWidth / aspectHeight

        var targetWidth = visibleFrame.width
        var targetHeight = targetWidth / ratio

        if targetHeight > visibleFrame.height {
            targetHeight = visibleFrame.height
            targetWidth = targetHeight * ratio
        }

        let targetX = visibleFrame.minX + (visibleFrame.width - targetWidth) / 2
        let targetY = visibleFrame.minY + (visibleFrame.height - targetHeight) / 2
        let targetRect = NSRect(x: targetX, y: targetY, width: targetWidth, height: targetHeight)

        if abs(window.frame.width - targetWidth) < 10 {
            window.zoom(nil)
        } else {
            window.setFrame(targetRect, display: true, animate: true)
        }
    }

    func resizeWindowToPlaybackScale(_ scale: CGFloat) {
        guard let window,
              let videoSize = capture.videoSize,
              videoSize.width > 0,
              videoSize.height > 0,
              scale > 0
        else {
            return
        }

        let contentSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        let currentFrame = window.frame
        let frameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: contentSize)).size
        let origin = CGPoint(
            x: currentFrame.midX - frameSize.width / 2,
            y: currentFrame.midY - frameSize.height / 2
        )
        let targetFrame = clampFrameTopLeftToVisibleScreen(
            CGRect(origin: origin, size: frameSize),
            for: window
        )
        window.setFrame(targetFrame, display: true, animate: true)
    }

    func updateWindowAspectRatio(for videoSize: CGSize?) {
        guard capture.state == .running else {
            resetWindowAspectRatio()
            return
        }
        guard let window,
              !window.styleMask.contains(.fullScreen),
              let videoSize,
              videoSize.width > 0,
              videoSize.height > 0
        else {
            return
        }

        window.contentAspectRatio = videoSize
        resizeWindowContentToMatchVideoAspect(window: window, videoSize: videoSize)
    }

    func resetWindowAspectRatio() {
        window?.contentResizeIncrements = NSSize(width: 1, height: 1)
    }

    func resizeWindowContentToMatchVideoAspect(window: NSWindow, videoSize: CGSize) {
        guard let contentView = window.contentView else { return }

        let contentSize = contentView.bounds.size
        guard contentSize.width > 0, contentSize.height > 0 else { return }

        let videoRatio = videoSize.width / videoSize.height
        let contentRatio = contentSize.width / contentSize.height
        let adjustedContentSize: CGSize

        if contentRatio > videoRatio {
            adjustedContentSize = CGSize(width: contentSize.height * videoRatio, height: contentSize.height)
        } else {
            adjustedContentSize = CGSize(width: contentSize.width, height: contentSize.width / videoRatio)
        }

        guard abs(adjustedContentSize.width - contentSize.width) > 1
            || abs(adjustedContentSize.height - contentSize.height) > 1
        else {
            return
        }

        let currentFrame = window.frame
        let frameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: adjustedContentSize)).size
        let origin = CGPoint(
            x: currentFrame.midX - frameSize.width / 2,
            y: currentFrame.midY - frameSize.height / 2
        )
        window.setFrame(CGRect(origin: origin, size: frameSize), display: true, animate: true)
    }

    func clampFrameTopLeftToVisibleScreen(_ frame: CGRect, for window: NSWindow) -> CGRect {
        guard let visibleFrame = window.screen?.visibleFrame else { return frame }

        var clampedFrame = frame
        if clampedFrame.minX < visibleFrame.minX {
            clampedFrame.origin.x = visibleFrame.minX
        }
        if clampedFrame.maxY > visibleFrame.maxY {
            clampedFrame.origin.y = visibleFrame.maxY - clampedFrame.height
        }
        return clampedFrame
    }
}
#endif
