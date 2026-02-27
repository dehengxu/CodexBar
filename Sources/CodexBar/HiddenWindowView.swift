import SwiftUI
import AppKit

struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onAppear {
                hideWindow()
            }
            .task {
                // Migrate keychain items to reduce permission prompts during development (runs off main thread)
                await Task.detached(priority: .userInitiated) {
                    KeychainMigration.migrateIfNeeded()
                }.value
            }
    }

    private func hideWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.title == "CodexBarLifecycleKeepalive" }) {
                window.styleMask = [.borderless]
                if #available(macOS 13.0, *) {
                    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
                } else {
                    window.collectionBehavior = [.ignoresCycle, .transient, .canJoinAllSpaces]
                }
                window.isExcludedFromWindowsMenu = true
                window.level = .floating
                window.isOpaque = false
                window.alphaValue = 0
                window.backgroundColor = .clear
                window.hasShadow = false
                window.ignoresMouseEvents = true
                window.canHide = false
                window.setContentSize(NSSize(width: 1, height: 1))
                window.setFrameOrigin(NSPoint(x: -5000, y: -5000))
                window.orderOut(nil)
            }
        }
    }
}
