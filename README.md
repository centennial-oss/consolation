# Consolation

A no-frills video capture viewer for macOS, iPadOS, and iOS.

Consolation is coming soon to the App Store. Release downloads will also be available from [this project's releases](https://github.com/centennial-oss/consolation/releases).

## About

Consolation lets you connect a standard capture card and use your Mac, iPad, or iPhone as a temporary screen for live audio and video. It is built for gaming console users who need a larger display when they are away from their TV, such as using a MacBook Pro screen instead of a handheld console screen.

The app is intentionally simple: watch the live feed in a window or full screen. No recording, no streaming, no saving, no analysis, no tracking, and no analytics. Just like a barebones TV.

## Features

- **Live capture-card viewing** - Watch real-time video from a standard capture device.
- **Live audio playback** - Play audio from the selected capture device or companion audio input.
- **Windowed or full screen** - Use the app as a temporary TV on macOS, iPadOS, or iOS.
- **Capture-device focused** - Built around AVFoundation capture device discovery for external/UVC devices.
- **No recording or streaming** - Consolation is only for transient live viewing.
- **No data collected** - Free, open source, no in-app purchases, no tracking, and no analytics.

## Screenshots

Coming soon.

## Privacy

Consolation does not collect, send, or share your data. Audio and video stay local and transient while you are watching a connected capture device. The app is open source, contains no trackers or analytics, makes no network calls, and does not record, stream, save, or analyze audio or video.

## Supported Capture Devices

Any capture device that appears to the system through AVFoundation as a camera and microphone input should work with Consolation. This typically includes standard USB Video Class (UVC) capture devices supported by macOS, iPadOS, or iOS.

Consolation is confirmed to work with these specific devices:

- Elgato HD60 X

## Requirements

### Running

- macOS 26.4 or higher
- iOS 26.4 or higher
- iPadOS 26.4 or higher
- A compatible standard video capture card

### Developer

- Xcode 26.4 or higher, including Command Line Tools

## Building

1. Open `Consolation.xcodeproj` in Xcode.
2. Build and run.

## Tech Stack

- SwiftUI
- AVFoundation
- AppKit
- UIKit

## Contributor Disclosure

Humans write this software with AI assistance. All contributions are well-tested and merged only after being reviewed and approved by humans who fully understand and take responsibility for the contribution.

While we welcome pull requests and other contributions from other humans, including AI-generated code, we do not accept contributions from AI bots. A human must review, understand, and sign off on all commits. Please file an issue to discuss any proposed feature before working on it.