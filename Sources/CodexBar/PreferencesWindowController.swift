import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private static let defaultSize = NSSize(width: PreferencesTab.defaultWidth, height: PreferencesTab.windowHeight)

    let settings: SettingsStore
    let store: UsageStore
    let updater: UpdaterProviding
    let selection: PreferencesSelection

    init(settings: SettingsStore, store: UsageStore, updater: UpdaterProviding, selection: PreferencesSelection) {
        self.settings = settings
        self.store = store
        self.updater = updater
        self.selection = selection

        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(tab: PreferencesTab) {
        self.selection.tab = tab

        if self.window == nil {
            self.buildWindow()
        }

        self.window?.center()
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildWindow() {
        let contentView = PreferencesView(
            settings: self.settings,
            store: self.store,
            updater: self.updater,
            selection: self.selection)

        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        window.title = "Preferences"
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.contentViewController = hostingController
        window.center()
        window.delegate = self

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        // Keep window controller alive for reuse
    }
}
