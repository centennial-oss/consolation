//
//  ContentViewWindowMac.swift
//  Consolation
//

import SwiftUI

#if os(macOS)
import AppKit

private let mainViewerMinimumContentSize = NSSize(width: 640, height: 480)

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            self.window = view.window
            view.window?.isMovableByWindowBackground = false
            view.window?.contentMinSize = mainViewerMinimumContentSize
            view.window?.tabbingMode = .disallowed
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.contentMinSize = mainViewerMinimumContentSize
        nsView.window?.tabbingMode = .disallowed
    }
}

extension ContentView {
    @ViewBuilder
    var macOSHiddenPlaybackShortcuts: some View {
        Group {
            Button("") {
                handleSpaceOrKPlaybackShortcut()
            }
            .keyboardShortcut(.space, modifiers: [])
            .hidden()

            Button("") {
                handleSpaceOrKPlaybackShortcut()
            }
            .keyboardShortcut("k", modifiers: [])
            .hidden()

            Button("") {
                guard let window else { return }
                if window.styleMask.contains(.fullScreen) {
                    window.toggleFullScreen(nil)
                }
            }
            .keyboardShortcut(.cancelAction)
            .hidden()

            Button("") {
                window?.toggleFullScreen(nil)
            }
            .keyboardShortcut("f", modifiers: [])
            .hidden()

            Button("") {
                zoomWindowToVideoAspectIfPossible()
            }
            .keyboardShortcut("z", modifiers: [])
            .hidden()
        }
    }

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

        let requestedSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        let contentSize = contentSizeRespectingMinimum(requestedSize, aspectRatio: videoSize.width / videoSize.height)
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
        window.contentMinSize = minimumContentSizePreservingAspectRatio(videoSize.width / videoSize.height)
        resizeWindowContentToMatchVideoAspect(window: window, videoSize: videoSize)
    }

    func resetWindowAspectRatio() {
        window?.contentMinSize = mainViewerMinimumContentSize
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
        let clampedContentSize = contentSizeRespectingMinimum(adjustedContentSize, aspectRatio: videoRatio)

        guard abs(clampedContentSize.width - contentSize.width) > 1
            || abs(clampedContentSize.height - contentSize.height) > 1
        else {
            return
        }

        let currentFrame = window.frame
        let frameSize = window.frameRect(forContentRect: CGRect(origin: .zero, size: clampedContentSize)).size
        let origin = CGPoint(
            x: currentFrame.midX - frameSize.width / 2,
            y: currentFrame.midY - frameSize.height / 2
        )
        window.setFrame(CGRect(origin: origin, size: frameSize), display: true, animate: true)
    }

    func contentSizeRespectingMinimum(_ size: CGSize, aspectRatio: CGFloat) -> CGSize {
        let minimum = minimumContentSizePreservingAspectRatio(aspectRatio)
        return CGSize(
            width: max(size.width, minimum.width),
            height: max(size.height, minimum.height)
        )
    }

    func minimumContentSizePreservingAspectRatio(_ aspectRatio: CGFloat) -> CGSize {
        guard aspectRatio > 0, aspectRatio.isFinite else {
            return mainViewerMinimumContentSize
        }
        let widthFromMinimumHeight = mainViewerMinimumContentSize.height * aspectRatio
        if widthFromMinimumHeight >= mainViewerMinimumContentSize.width {
            return CGSize(width: widthFromMinimumHeight, height: mainViewerMinimumContentSize.height)
        }
        return CGSize(
            width: mainViewerMinimumContentSize.width,
            height: mainViewerMinimumContentSize.width / aspectRatio
        )
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
