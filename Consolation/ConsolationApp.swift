//
//  ConsolationApp.swift
//  Consolation
//
//  Created by James Ranson on 4/12/26.
//

import SwiftUI

#if os(macOS)
import AppKit

/// Single-window viewer: strip **Edit** / **Format**, disable window tabbing.
/// SwiftUI may rebuild `mainMenu`; observe and strip again.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainMenuObservation: NSKeyValueObservation?

    /// `item(withTitle:)` is not localized; cover common macOS menu titles for **Edit**.
    private static let editMenuBarTitles: [String] = [
        "Edit",
        "Bearbeiten",
        "Édition",
        "Éditer",
        "Edición",
        "Modifica",
        "Redigera",
        "Rediger",
        "Bewerken",
        "Edytuj",
        "Edycja",
        "Редактирование",
        "Правка",
        "编辑",
        "編輯",
        "編集",
        "편집",
        "Upravit",
        "Muokkaa"
    ]

    /// Common macOS menu titles for **Format** (rich text / font menus SwiftUI can add).
    private static let formatMenuBarTitles: [String] = [
        "Format",
        "Formato",
        "Formát",
        "Formaat",
        "Opmaak",
        "Muotoilu",
        "格式",
        "フォーマット",
        "형식",
        "Формат",
        "Formátovanie",
        "Formattazione"
    ]

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Hides **View ▸ Show Tab Bar** / **Show All Tabs** for the whole app (single-window viewer).
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        stripUnwantedMenusIfNeeded()
        mainMenuObservation = NSApp.observe(\.mainMenu, options: [.new]) { [weak self] _, _ in
            self?.stripUnwantedMenusIfNeeded()
        }
    }

    private func stripUnwantedMenusIfNeeded() {
        guard let mainMenu = NSApp.mainMenu else { return }
        Self.removeFirstMenuItem(matchingAnyTitleIn: Self.editMenuBarTitles, from: mainMenu)
        Self.removeFirstMenuItem(matchingAnyTitleIn: Self.formatMenuBarTitles, from: mainMenu)
    }

    /// Removes at most one top-level item whose title matches any string in `titles` (localized alternates).
    private static func removeFirstMenuItem(matchingAnyTitleIn titles: [String], from mainMenu: NSMenu) {
        for title in titles {
            guard let item = mainMenu.item(withTitle: title) else { continue }
            mainMenu.removeItem(item)
            return
        }
    }
}
#endif

@main
struct ConsolationApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(iOS)
    @UIApplicationDelegateAdaptor(IOSAppOrientationDelegate.self) var iosOrientationDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(iOS)
        .windowResizability(.contentMinSize)
        #endif
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .undoRedo) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .textEditing) {}
            CommandGroup(replacing: .textFormatting) {}
            CommandGroup(after: .toolbar) {
                Section("Playback Size") {
                    Button(".5x") {
                        NotificationCenter.default.post(name: .playbackSizeCommand, object: CGFloat(0.5))
                    }
                    Button("1x") {
                        NotificationCenter.default.post(name: .playbackSizeCommand, object: CGFloat(1))
                    }
                    Button("2x") {
                        NotificationCenter.default.post(name: .playbackSizeCommand, object: CGFloat(2))
                    }
                }
            }
        }
        #endif
    }
}
