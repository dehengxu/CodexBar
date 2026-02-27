import Foundation

#if os(macOS)

public enum ClaudeOAuthRefreshFailureGate {
    public enum BlockStatus: Equatable, Sendable {
        case terminal(reason: String?, failures: Int)
        case transient(until: Date, failures: Int)
    }

    struct AuthFingerprint: Codable, Equatable, Sendable {
        let keychain: ClaudeOAuthCredentialsStore.ClaudeKeychainFingerprint?
        let credentialsFile: String?
    }

    private struct State {
        var loaded = false
        var terminalFailureCount = 0
        var transientFailureCount = 0
        var isTerminalBlocked = false
        var transientBlockedUntil: Date?
        var fingerprintAtFailure: AuthFingerprint?
        var lastCredentialsRecheckAt: Date?
        var terminalReason: String?
    }

    private static let lock = NSLock()
    private static var state = State()
    private static let blockedUntilKey = "claudeOAuthRefreshBackoffBlockedUntilV1" // legacy (migration)
    private static let failureCountKey = "claudeOAuthRefreshBackoffFailureCountV1" // legacy + terminal count
    private static let fingerprintKey = "claudeOAuthRefreshBackoffFingerprintV2"
    private static let terminalBlockedKey = "claudeOAuthRefreshTerminalBlockedV1"
    private static let terminalReasonKey = "claudeOAuthRefreshTerminalReasonV1"
    private static let transientBlockedUntilKey = "claudeOAuthRefreshTransientBlockedUntilV1"
    private static let transientFailureCountKey = "claudeOAuthRefreshTransientFailureCountV1"

    private static let log = CodexBarLog.logger(LogCategories.claudeUsage)
    private static let minimumCredentialsRecheckInterval: TimeInterval = 15
    private static let unknownFingerprint = AuthFingerprint(keychain: nil, credentialsFile: nil)
    private static let transientBaseInterval: TimeInterval = 60 * 5
    private static let transientMaxInterval: TimeInterval = 60 * 60 * 6

    #if DEBUG
    @TaskLocal static var shouldAttemptOverride: Bool?
    private static var fingerprintProviderOverride: (() -> AuthFingerprint?)?

    static func setFingerprintProviderOverrideForTesting(_ provider: (() -> AuthFingerprint?)?) {
        fingerprintProviderOverride = provider
    }

    public static func resetInMemoryStateForTesting() {
        lock.lock()
        defer { lock.unlock() }
        state.loaded = false
        state.terminalFailureCount = 0
        state.transientFailureCount = 0
        state.isTerminalBlocked = false
        state.transientBlockedUntil = nil
        state.fingerprintAtFailure = nil
        state.lastCredentialsRecheckAt = nil
        state.terminalReason = nil
    }

    public static func resetForTesting() {
        lock.lock()
        defer { lock.unlock() }
        state.loaded = false
        state.terminalFailureCount = 0
        state.transientFailureCount = 0
        state.isTerminalBlocked = false
        state.transientBlockedUntil = nil
        state.fingerprintAtFailure = nil
        state.lastCredentialsRecheckAt = nil
        state.terminalReason = nil
        UserDefaults.standard.removeObject(forKey: blockedUntilKey)
        UserDefaults.standard.removeObject(forKey: failureCountKey)
        UserDefaults.standard.removeObject(forKey: fingerprintKey)
        UserDefaults.standard.removeObject(forKey: terminalBlockedKey)
        UserDefaults.standard.removeObject(forKey: terminalReasonKey)
        UserDefaults.standard.removeObject(forKey: transientBlockedUntilKey)
        UserDefaults.standard.removeObject(forKey: transientFailureCountKey)
    }
    #endif

    public static func shouldAttempt(now: Date = Date()) -> Bool {
        #if DEBUG
        if let override = shouldAttemptOverride { return override }
        #endif

        lock.lock()
        defer { lock.unlock() }
        var localState = state
        let didMigrate = loadIfNeeded(&localState, now: now)
        if didMigrate {
            persist(localState)
        }

        if localState.isTerminalBlocked {
            guard shouldRecheckCredentials(now: now, state: localState) else { return false }

            localState.lastCredentialsRecheckAt = now
            if hasCredentialsChangedSinceFailure(localState) {
                resetState(&localState)
                persist(localState)
                state = localState
                return true
            }

            log.debug(
                "Claude OAuth refresh blocked until auth changes",
                metadata: [
                    "terminalFailures": "\(localState.terminalFailureCount)",
                    "reason": localState.terminalReason ?? "nil",
                ])
            state = localState
            return false
        }

        if let blockedUntil = localState.transientBlockedUntil {
            if blockedUntil <= now {
                clearTransientState(&localState)
                // Once transient backoff expires, forget its auth baseline so future failures capture fresh
                // fingerprints and so we don't ratchet backoff across unrelated intermittent failures.
                localState.fingerprintAtFailure = nil
                localState.lastCredentialsRecheckAt = nil
                persist(localState)
                state = localState
                return true
            }

            if shouldRecheckCredentials(now: now, state: localState) {
                localState.lastCredentialsRecheckAt = now
                if hasCredentialsChangedSinceFailure(localState) {
                    resetState(&localState)
                    persist(localState)
                    state = localState
                    return true
                }
            }

            log.debug(
                "Claude OAuth refresh transient backoff active",
                metadata: [
                    "until": "\(blockedUntil.timeIntervalSince1970)",
                    "transientFailures": "\(localState.transientFailureCount)",
                ])
            state = localState
            return false
        }

        state = localState
        return true
    }

    public static func currentBlockStatus(now: Date = Date()) -> BlockStatus? {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        _ = loadIfNeeded(&localState, now: now)
        if localState.isTerminalBlocked {
            return .terminal(reason: localState.terminalReason, failures: localState.terminalFailureCount)
        }
        if let blockedUntil = localState.transientBlockedUntil, blockedUntil > now {
            return .transient(until: blockedUntil, failures: localState.transientFailureCount)
        }
        return nil
    }

    public static func recordTerminalAuthFailure(now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        _ = loadIfNeeded(&localState, now: now)
        localState.terminalFailureCount += 1
        localState.isTerminalBlocked = true
        localState.terminalReason = "invalid_grant"
        localState.fingerprintAtFailure = currentFingerprint() ?? unknownFingerprint
        localState.lastCredentialsRecheckAt = now
        clearTransientState(&localState)
        persist(localState)
        state = localState
    }

    public static func recordTransientFailure(now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        _ = loadIfNeeded(&localState, now: now)

        // Keep terminal blocking monotonic: once we know auth is rejected (e.g. invalid_grant),
        // do not downgrade it to time-based backoff unless auth changes (fingerprint) or we record success.
        guard !localState.isTerminalBlocked else { return }

        clearTerminalState(&localState)

        localState.transientFailureCount += 1
        let interval = transientCooldownInterval(failures: localState.transientFailureCount)
        localState.transientBlockedUntil = now.addingTimeInterval(interval)
        localState.fingerprintAtFailure = currentFingerprint() ?? unknownFingerprint
        localState.lastCredentialsRecheckAt = now
        persist(localState)
        state = localState
    }

    public static func recordAuthFailure(now: Date = Date()) {
        // Legacy shim: treat as terminal auth failure.
        recordTerminalAuthFailure(now: now)
    }

    public static func recordSuccess() {
        lock.lock()
        defer { lock.unlock() }
        var localState = state
        _ = loadIfNeeded(&localState, now: Date())
        resetState(&localState)
        persist(localState)
        state = localState
    }

    private static func shouldRecheckCredentials(now: Date, state: State) -> Bool {
        guard let last = state.lastCredentialsRecheckAt else { return true }
        return now.timeIntervalSince(last) >= minimumCredentialsRecheckInterval
    }

    private static func hasCredentialsChangedSinceFailure(_ state: State) -> Bool {
        guard let current = currentFingerprint() else { return false }
        guard let prior = state.fingerprintAtFailure else { return false }
        return current != prior
    }

    private static func currentFingerprint() -> AuthFingerprint? {
        #if DEBUG
        if let override = fingerprintProviderOverride { return override() }
        #endif
        return AuthFingerprint(
            keychain: ClaudeOAuthCredentialsStore.currentClaudeKeychainFingerprintWithoutPromptForAuthGate(),
            credentialsFile: ClaudeOAuthCredentialsStore.currentCredentialsFileFingerprintWithoutPromptForAuthGate())
    }

    private static func loadIfNeeded(_ localState: inout State, now: Date) -> Bool {
        localState.loaded = true
        var didMutate = false

        // Always refresh persisted fields from UserDefaults, even after first load.
        //
        // This avoids stale state when UserDefaults are modified while the app is running (or during tests),
        // while still keeping ephemeral throttling state (like lastCredentialsRecheckAt) in memory.
        localState.terminalFailureCount = UserDefaults.standard.integer(forKey: failureCountKey)
        localState.transientFailureCount = UserDefaults.standard.integer(forKey: transientFailureCountKey)

        if let raw = UserDefaults.standard.object(forKey: transientBlockedUntilKey) as? Double {
            localState.transientBlockedUntil = Date(timeIntervalSince1970: raw)
        }

        let legacyBlockedUntil = (UserDefaults.standard.object(forKey: blockedUntilKey) as? Double)
            .map { Date(timeIntervalSince1970: $0) }
        let legacyFailureCount = UserDefaults.standard.integer(forKey: failureCountKey)

        if let data = UserDefaults.standard.data(forKey: fingerprintKey) {
            localState.fingerprintAtFailure = (try? JSONDecoder().decode(AuthFingerprint.self, from: data))
        } else {
            localState.fingerprintAtFailure = nil
        }

        if UserDefaults.standard.object(forKey: terminalBlockedKey) != nil {
            localState.isTerminalBlocked = UserDefaults.standard.bool(forKey: terminalBlockedKey)
            localState.terminalReason = UserDefaults.standard.string(forKey: terminalReasonKey)
            if legacyBlockedUntil != nil {
                didMutate = true
            }
        } else {
            // Migration: legacy keys represented a time-based backoff. Migrate to transient backoff (never terminal)
            // unless we already have new transient keys persisted.
            if UserDefaults.standard.object(forKey: transientFailureCountKey) == nil,
               UserDefaults.standard.object(forKey: transientBlockedUntilKey) == nil,
               legacyBlockedUntil != nil || legacyFailureCount > 0
            {
                localState.isTerminalBlocked = false
                localState.terminalReason = nil
                localState.terminalFailureCount = 0

                if let legacyBlockedUntil, legacyBlockedUntil > now {
                    localState.transientFailureCount = max(legacyFailureCount, 0)
                    localState.transientBlockedUntil = legacyBlockedUntil
                } else {
                    localState.transientFailureCount = 0
                    localState.transientBlockedUntil = nil
                }
                didMutate = true
            }
        }

        if localState.isTerminalBlocked || localState.transientBlockedUntil != nil, localState.fingerprintAtFailure == nil {
            localState.fingerprintAtFailure = unknownFingerprint
            didMutate = true
        }

        if legacyBlockedUntil != nil {
            didMutate = true
        }

        return didMutate
    }

    private static func persist(_ localState: State) {
        UserDefaults.standard.set(localState.terminalFailureCount, forKey: failureCountKey)
        UserDefaults.standard.set(localState.isTerminalBlocked, forKey: terminalBlockedKey)
        if let reason = localState.terminalReason {
            UserDefaults.standard.set(reason, forKey: terminalReasonKey)
        } else {
            UserDefaults.standard.removeObject(forKey: terminalReasonKey)
        }

        UserDefaults.standard.set(localState.transientFailureCount, forKey: transientFailureCountKey)
        if let blockedUntil = localState.transientBlockedUntil {
            UserDefaults.standard.set(blockedUntil.timeIntervalSince1970, forKey: transientBlockedUntilKey)
        } else {
            UserDefaults.standard.removeObject(forKey: transientBlockedUntilKey)
        }

        UserDefaults.standard.removeObject(forKey: blockedUntilKey)

        if let fingerprint = localState.fingerprintAtFailure,
           let data = try? JSONEncoder().encode(fingerprint)
        {
            UserDefaults.standard.set(data, forKey: fingerprintKey)
        } else {
            UserDefaults.standard.removeObject(forKey: fingerprintKey)
        }
    }

    private static func transientCooldownInterval(failures: Int) -> TimeInterval {
        guard failures > 0 else { return 0 }
        let factor = pow(2.0, Double(failures - 1))
        return min(transientBaseInterval * factor, transientMaxInterval)
    }

    private static func clearTerminalState(_ localState: inout State) {
        localState.terminalFailureCount = 0
        localState.isTerminalBlocked = false
        localState.terminalReason = nil
    }

    private static func clearTransientState(_ localState: inout State) {
        localState.transientFailureCount = 0
        localState.transientBlockedUntil = nil
    }

    private static func resetState(_ localState: inout State) {
        clearTerminalState(&localState)
        clearTransientState(&localState)
        localState.fingerprintAtFailure = nil
        localState.lastCredentialsRecheckAt = nil
    }
}
#else
public enum ClaudeOAuthRefreshFailureGate {
    public enum BlockStatus: Equatable, Sendable {
        case terminal(reason: String?, failures: Int)
        case transient(until: Date, failures: Int)
    }

    public static func shouldAttempt(now _: Date = Date()) -> Bool {
        true
    }

    public static func currentBlockStatus(now _: Date = Date()) -> BlockStatus? {
        nil
    }

    public static func recordTerminalAuthFailure(now _: Date = Date()) {}

    public static func recordTransientFailure(now _: Date = Date()) {}

    public static func recordAuthFailure(now _: Date = Date()) {}

    public static func recordSuccess() {}

    #if DEBUG
    static func setFingerprintProviderOverrideForTesting(_: (() -> Any?)?) {}
    public static func resetInMemoryStateForTesting() {}
    public static func resetForTesting() {}
    #endif
}
#endif
