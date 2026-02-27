import Foundation

#if os(macOS)

public enum ClaudeOAuthKeychainAccessGate {
    private struct State {
        var loaded = false
        var deniedUntil: Date?
    }

    private static let lock = NSLock()
    private static var state = State()
    private static let defaultsKey = "claudeOAuthKeychainDeniedUntil"
    private static let cooldownInterval: TimeInterval = 60 * 60 * 6
    @TaskLocal private static var taskOverrideShouldAllowPromptForTesting: Bool?
    #if DEBUG
    final class DeniedUntilStore: @unchecked Sendable {
        var deniedUntil: Date?
    }

    @TaskLocal private static var taskDeniedUntilStoreOverrideForTesting: DeniedUntilStore?
    #endif

    public static func shouldAllowPrompt(now: Date = Date()) -> Bool {
        guard !KeychainAccessGate.isDisabled else { return false }
        if let override = taskOverrideShouldAllowPromptForTesting { return override }
        #if DEBUG
        if let store = taskDeniedUntilStoreOverrideForTesting {
            if let deniedUntil = store.deniedUntil, deniedUntil > now {
                return false
            }
            store.deniedUntil = nil
            return true
        }
        #endif
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        loadIfNeeded(&localState)
        if let deniedUntil = localState.deniedUntil {
            if deniedUntil > now {
                return false
            }
            localState.deniedUntil = nil
            persist(localState)
        }
        state = localState
        return true
    }

    public static func recordDenied(now: Date = Date()) {
        let deniedUntil = now.addingTimeInterval(cooldownInterval)
        #if DEBUG
        if let store = taskDeniedUntilStoreOverrideForTesting {
            store.deniedUntil = deniedUntil
            return
        }
        #endif
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        loadIfNeeded(&localState)
        localState.deniedUntil = deniedUntil
        persist(localState)
        state = localState
    }

    /// Clears the cooldown so the next attempt can proceed. Intended for user-initiated repairs.
    /// - Returns: true if a cooldown was present and cleared.
    public static func clearDenied(now: Date = Date()) -> Bool {
        #if DEBUG
        if let store = taskDeniedUntilStoreOverrideForTesting {
            guard let deniedUntil = store.deniedUntil, deniedUntil > now else {
                store.deniedUntil = nil
                return false
            }
            store.deniedUntil = nil
            return true
        }
        #endif
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        loadIfNeeded(&localState)
        guard let deniedUntil = localState.deniedUntil, deniedUntil > now else {
            localState.deniedUntil = nil
            persist(localState)
            state = localState
            return false
        }
        localState.deniedUntil = nil
        persist(localState)
        state = localState
        return true
    }

    #if DEBUG
    static func withShouldAllowPromptOverrideForTesting<T>(
        _ value: Bool?,
        operation: () throws -> T) rethrows -> T
    {
        try $taskOverrideShouldAllowPromptForTesting.withValue(value) {
            try operation()
        }
    }

    static func withShouldAllowPromptOverrideForTesting<T>(
        _ value: Bool?,
        operation: () async throws -> T) async rethrows -> T
    {
        try await $taskOverrideShouldAllowPromptForTesting.withValue(value) {
            try await operation()
        }
    }

    static func withDeniedUntilStoreOverrideForTesting<T>(
        _ store: DeniedUntilStore?,
        operation: () throws -> T) rethrows -> T
    {
        try $taskDeniedUntilStoreOverrideForTesting.withValue(store) {
            try operation()
        }
    }

    static func withDeniedUntilStoreOverrideForTesting<T>(
        _ store: DeniedUntilStore?,
        operation: () async throws -> T) async rethrows -> T
    {
        try await $taskDeniedUntilStoreOverrideForTesting.withValue(store) {
            try await operation()
        }
    }

    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        // Keep deterministic during tests: avoid re-loading UserDefaults written by unrelated code paths.
        localState.loaded = true
        localState.deniedUntil = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        state = localState
    }

    public static func resetInMemoryForTesting() {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        localState.loaded = false
        localState.deniedUntil = nil
        state = localState
    }
    #endif

    private static func loadIfNeeded(_ localState: inout State) {
        guard !localState.loaded else { return }
        localState.loaded = true
        if let raw = UserDefaults.standard.object(forKey: defaultsKey) as? Double {
            localState.deniedUntil = Date(timeIntervalSince1970: raw)
        }
    }

    private static func persist(_ localState: State) {
        if let deniedUntil = localState.deniedUntil {
            UserDefaults.standard.set(deniedUntil.timeIntervalSince1970, forKey: defaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }
}
#else
public enum ClaudeOAuthKeychainAccessGate {
    public static func shouldAllowPrompt(now _: Date = Date()) -> Bool {
        true
    }

    public static func recordDenied(now _: Date = Date()) {}

    public static func clearDenied(now _: Date = Date()) -> Bool {
        false
    }

    #if DEBUG
    public static func resetForTesting() {}

    public static func resetInMemoryForTesting() {}
    #endif
}
#endif
