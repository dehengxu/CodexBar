import Foundation

#if os(macOS)

public enum BrowserCookieAccessGate {
    private struct State {
        var loaded = false
        var deniedUntilByBrowser: [String: Date] = [:]
    }

    private static let lock = NSLock()
    private static var state = State()
    private static let defaultsKey = "browserCookieAccessDeniedUntil"
    private static let cooldownInterval: TimeInterval = 60 * 60 * 6
    private static let log = CodexBarLog.logger(LogCategories.browserCookieGate)

    public static func shouldAttempt(_ browser: Browser, now: Date = Date()) -> Bool {
        guard browser.usesKeychainForCookieDecryption else { return true }
        guard !KeychainAccessGate.isDisabled else { return false }
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        loadIfNeeded(&localState)
        if let blockedUntil = localState.deniedUntilByBrowser[browser.rawValue] {
            if blockedUntil > now {
                log.debug(
                    "Cookie access blocked",
                    metadata: ["browser": browser.displayName, "until": "\(blockedUntil.timeIntervalSince1970)"])
                return false
            }
            localState.deniedUntilByBrowser.removeValue(forKey: browser.rawValue)
            persist(localState)
        }
        if chromiumKeychainRequiresInteraction() {
            localState.deniedUntilByBrowser[browser.rawValue] = now.addingTimeInterval(cooldownInterval)
            persist(localState)
            log.info(
                "Cookie access requires keychain interaction; suppressing",
                metadata: ["browser": browser.displayName])
            return false
        }
        log.debug("Cookie access allowed", metadata: ["browser": browser.displayName])
        return true
    }

    public static func recordIfNeeded(_ error: Error, now: Date = Date()) {
        guard let error = error as? BrowserCookieError else { return }
        guard case .accessDenied = error else { return }
        guard let browser = error.browser else { return }
        recordDenied(for: browser, now: now)
    }

    public static func recordDenied(for browser: Browser, now: Date = Date()) {
        guard browser.usesKeychainForCookieDecryption else { return }
        let blockedUntil = now.addingTimeInterval(cooldownInterval)
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        loadIfNeeded(&localState)
        localState.deniedUntilByBrowser[browser.rawValue] = blockedUntil
        persist(localState)
        log
            .info(
                "Browser cookie access denied; suppressing prompts",
                metadata: [
                    "browser": browser.displayName,
                    "until": "\(blockedUntil.timeIntervalSince1970)",
                ])
    }

    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        localState.loaded = true
        localState.deniedUntilByBrowser.removeAll()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        state = localState
    }

    private static func chromiumKeychainRequiresInteraction() -> Bool {
        for label in safeStorageLabels {
            switch KeychainAccessPreflight.checkGenericPassword(service: label.service, account: label.account) {
            case .allowed:
                return false
            case .interactionRequired:
                return true
            case .notFound, .failure:
                continue
            }
        }
        return false
    }

    private static let safeStorageLabels: [(service: String, account: String)] = Browser.safeStorageLabels

    private static func loadIfNeeded(_ localState: inout State) {
        guard !localState.loaded else { return }
        localState.loaded = true
        guard let raw = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double] else {
            return
        }
        localState.deniedUntilByBrowser = raw.compactMapValues { Date(timeIntervalSince1970: $0) }
        state = localState
    }

    private static func persist(_ localState: State) {
        let raw = localState.deniedUntilByBrowser.mapValues { $0.timeIntervalSince1970 }
        UserDefaults.standard.set(raw, forKey: defaultsKey)
        state = localState
    }
}
#else
public enum BrowserCookieAccessGate {
    public static func shouldAttempt(_ browser: Browser, now: Date = Date()) -> Bool {
        true
    }

    public static func recordIfNeeded(_ error: Error, now: Date = Date()) {}
    public static func recordDenied(for browser: Browser, now: Date = Date()) {}
    public static func resetForTesting() {}
}
#endif
