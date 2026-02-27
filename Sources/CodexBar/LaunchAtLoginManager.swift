import CodexBarCore
import Foundation
import ServiceManagement

enum LaunchAtLoginManager {
    private static let isRunningTests: Bool = {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if env["TESTING_LIBRARY_VERSION"] != nil { return true }
        if env["SWIFT_TESTING"] != nil { return true }
        return NSClassFromString("XCTestCase") != nil
    }()

    static func setEnabled(_ enabled: Bool) {
        if self.isRunningTests { return }

        // Use SMAppService on macOS 13+, fallback to legacy API on macOS 12
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enabled {
                    try service.register()
                } else {
                    try service.unregister()
                }
            } catch {
                CodexBarLog.logger(LogCategories.launchAtLogin).error("Failed to update login item: \(error)")
            }
        } else {
            // Legacy API for macOS 12
            let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.codexbar.app"
            let helperBundleId = bundleIdentifier + ".LaunchAtLoginHelper"
            if SMLoginItemSetEnabled(helperBundleId as CFString, enabled) {
                CodexBarLog.logger(LogCategories.launchAtLogin).debug("Launch at login \(enabled ? "enabled" : "disabled")")
            } else {
                CodexBarLog.logger(LogCategories.launchAtLogin).error("Failed to update login item")
            }
        }
    }
}
