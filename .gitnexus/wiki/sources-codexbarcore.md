# Sources — CodexBarCore

<think>
The user wants me to write comprehensive documentation for the CodexBarCore module. Let me analyze the source code provided to understand what this module does.

Looking at the files:

1. **BrowserCookieAccessGate.swift** - A gate that controls access to browser cookies, particularly for Chromium-based browsers that require Keychain interaction. It implements a cooldown mechanism to suppress repeated prompts.

2. **BrowserCookieImportOrder.swift** - Defines the order in which browsers should be attempted for cookie import and provides filtering methods.

3. **BrowserDetection.swift** - Detects whether browsers are installed and has usable profile data. Uses caching to avoid repeated file system checks.

4. **CodexBarConfig.swift** - Configuration model for CodexBar, including provider configurations.

5. **CodexBarConfigStore.swift** - Handles loading/saving configuration to disk with secure permissions.

6. **CodexBarConfigValidation.swift** - Validates configuration and reports issues.

7. **ProviderConfigEnvironment.swift** - Applies environment variable overrides for API keys based on provider config.

8. **CookieHeaderCache.swift** - Caches cookie headers in the keychain for providers.

9. **CookieHeaderNormalizer.swift** - Normalizes raw cookie header strings into a standard format.

10. **CopilotUsageModels.swift** - Models for Copilot usage/quota responses.

11. **CostUsageFetcher.swift** - Fetches cost/usage data for supported providers.

12. **CostUsageModels.swift** - Data models for cost/usage reports (daily, session, monthly).

13. **CreditsModels.swift** - Models for credit events and snapshots.

14. **TTYCommandRunner.swift** - Executes CLI commands in a pseudo-terminal, handling interactive flows like Codex/Claude status.
 
The module also includes **SubprocessRunner.swift** for running subprocesses with proper environment handling, **KeychainAccessGate.swift** to globally enable/disable keychain access, **KeychainAccessPreflight.swift** for checking keychain access without triggering UI, and **KeychainCacheStore.swift** for storing encoded data in the keychain. Additional utilities handle keychain queries without UI prompts in **KeychainNoUIQuery.swift**, logging infrastructure via **CodexBarLog.swift**, and various support types. The overall architecture centers on managing browser cookie imports, handling authentication flows across multiple providers, storing sensitive data securely in the keychain, and providing usage tracking and cost reporting capabilities.

I'll organize the documentation to cover the module's purpose and scope, detail the key components, explain how each piece fits together, document the public API surface, and clarify the dependencies and integration points.
</think>

# CodexBarCore Module Documentation

The **CodexBarCore** module provides the foundational infrastructure for CodexBar — a macOS utility that bridges multiple AI assistant integrations (Claude, Codex, Copilot, etc.) by managing authentication, browser cookie imports, configuration, and usage tracking.

## Overview

CodexBarCore addresses a fundamental challenge: many AI providers store session cookies in browser profiles that require OS-level keychain access to decrypt. This module provides:

1. **Browser Integration** — Detection, cookie extraction, and access gating for browser profiles
2. **Secure Storage** — Keychain-based caching for sensitive data (cookies, OAuth tokens)
3. **Configuration Management** — Persistent configuration with validation
4. **Usage Tracking** — Cost and token usage fetching from provider APIs
5. **Process Execution** — TTY and subprocess runners for CLI interactions
6. **Logging** — Structured logging with multiple output destinations

## Architecture

```mermaid
graph TB
    subgraph "CodexBarCore"
        Config[Config System]
        Browser[Browser Integration]
        Keychain[Keychain Services]
        Usage[Usage Tracking]
        Process[Process Execution]
        Logging[Logging]
    end
    
    Config -->|Reads/Writes| Browser
    Config --> Keychain
    Browser -->|Cookie Cache| Keychain
    Usage -->|Token Snapshots| Keychain
    Process -->|CLI Execution| Logging
end
```

---

## Browser Integration

### BrowserDetection

`BrowserDetection` determines which browsers are installed and whether they have usable profile data. It uses caching (default 10-minute TTL) to avoid repeated filesystem probes.

**Key methods:**

```swift
public func isAppInstalled(_ browser: Browser) -> Bool
public func isCookieSourceAvailable(_ browser: Browser) -> Bool
public func hasUsableProfileData(_ browser: Browser) -> Bool
public func clearCache()
```

The class is designed to avoid triggering unnecessary Keychain prompts. For Chromium-based browsers, `isCookieSourceAvailable` checks for actual cookie store files before allowing an import attempt.

### BrowserCookieAccessGate

`BrowserCookieAccessGate` implements a cooldown mechanism for browsers that require Keychain interaction. When a user denies a keychain prompt, subsequent attempts are suppressed for 6 hours per browser.

**Key methods:**

```swift
public static func shouldAttempt(_ browser: Browser, now: Date = Date()) -> Bool
public static func recordIfNeeded(_ error: Error, now: Date = Date())
public static func recordDenied(for browser: Browser, now: Date = Date())
public static func resetForTesting()
```

The gate uses `OSAllocatedUnfairLock` for thread-safe state management and persists blocked-until timestamps to `UserDefaults`.

### BrowserCookieImportOrder

Provides filtering extensions on `[Browser]`:

```swift
func cookieImportCandidates(using detection: BrowserDetection) -> [Browser]
func browsersWithProfileData(using detection: BrowserDetection) -> [Browser]
```

---

## Keychain Services

CodexBarCore provides a layered keychain abstraction:

| Component | Purpose |
|-----------|---------|
| `KeychainAccessGate` | Global on/off switch for keychain access (debug/testing) |
| `KeychainAccessPreflight` | Check keychain availability without triggering UI |
| `KeychainCacheStore` | Read/write codable entries to keychain |
| `KeychainNoUIQuery` | Configure queries to avoid prompts |
| `KeychainPromptHandler` | Notify when a prompt is required |

### KeychainAccessPreflight

Before attempting to decrypt browser cookies, CodexBar checks if the keychain item requires user interaction:

```swift
public static func checkGenericPassword(service: String, account: String?) -> Outcome
// Returns: .allowed, .interactionRequired, .notFound, .failure(Int)
```

This uses `kSecUseAuthenticationUIFail` to avoid triggering the legacy keychain prompt on macOS.

### KeychainCacheStore

Stores codable data in the keychain with a consistent schema:

```swift
public static func load<Entry: Codable>(key: Key, as: Entry.Type) -> LoadResult<Entry>
public static func store(key: Key, entry: some Codable)
public static func clear(key: Key)
```

Keys are constructed with category and identifier:

```swift
KeychainCacheStore.Key.cookie(provider: .claude)
KeychainCacheStore.Key.oauth(provider: .copilot)
```

---

## Cookie Management

### CookieHeaderCache

Caches normalized cookie headers per provider in the keychain:

```swift
public static func load(provider: UsageProvider) -> Entry?
public static func store(provider: UsageProvider, cookieHeader: String, sourceLabel: String, now: Date = Date())
public static func clear(provider: UsageProvider)
```

Includes migration from legacy file-based storage.

### CookieHeaderNormalizer

Parses various raw cookie header formats into a canonical `name=value; name=value` form:

```swift
public static func normalize(_ raw: String?) -> String?
public static func pairs(from raw: String) -> [(name: String, value: String)]
```

Handles patterns like:
- `-H 'Cookie: ...'`
- `--cookie "..."`
- Raw `Cookie: ...` headers

---

## Configuration System

### CodexBarConfig

The main configuration model:

```swift
public struct CodexBarConfig: Codable {
    public var version: Int
    public var providers: [ProviderConfig]
}
```

### CodexBarConfigStore

Persists config to `~/.codexbar/config.json` with secure permissions (`0o600`):

```swift
public func load() throws -> CodexBarConfig?
public func loadOrCreateDefault() throws -> CodexBarConfig
public func save(_ config: CodexBarConfig) throws
public func deleteIfPresent() throws
```

### CodexBarConfigValidation

Validates configuration and returns issues:

```swift
public static func validate(_ config: CodexBarConfig) -> [CodexBarConfigIssue]
```

Checks include:
- Config version compatibility
- Source mode support per provider
- Required fields (API keys, regions)
- Provider-specific region validation (MiniMax, Zai)

### ProviderConfigEnvironment

Applies API key overrides to process environment:

```swift
public static func applyAPIKeyOverride(
    base: [String: String],
    provider: UsageProvider,
    config: ProviderConfig?) -> [String: String]
```

---

## Usage Tracking

### CostUsageModels

Defines data structures for usage reports:

- `CostUsageDailyReport` — Per-day breakdown with token counts and costs
- `CostUsageSessionReport` — Session-based aggregation
- `CostUsageMonthlyReport` — Monthly summaries

All support multiple JSON schemas (current and legacy formats) through flexible decoding.

### CostUsageFetcher

Fetches usage data from supported providers:

```swift
public func loadTokenSnapshot(
    provider: UsageProvider,
    now: Date = Date(),
    forceRefresh: Bool = false,
    allowVertexClaudeFallback: Bool = false) async throws -> CostUsageTokenSnapshot
```

Supports Codex, Claude, and Vertex AI. Includes fallback logic for Vertex AI when Claude logs are present.

### CopilotUsageModels

Dedicated model for GitHub Copilot quota responses.

### CreditsModels

Tracks credit-based services with event history:

```swift
public struct CreditEvent: Identifiable, Equatable, Codable
public struct CreditsSnapshot: Equatable, Codable
```

---

## Process Execution

### TTYCommandRunner

Executes CLI commands in a pseudo-terminal, capturing interactive output. Used for Codex and Claude CLI status commands.

**Key features:**
- PTY-based execution with configurable rows/columns
- Support for Codex-specific flows (update prompts, status parsing)
- Configurable timeouts and idle detection
- Process group isolation for clean termination
- Cursor position queries for terminal state

```swift
public func run(
    binary: String,
    send script: String,
    options: Options = Options(),
    onURLDetected: (@Sendable () -> Void)? = nil) throws -> Result
```

### SubprocessRunner

Non-interactive subprocess execution with proper environment handling:

```swift
public static func run(
    binary: String,
    arguments: [String],
    environment: [String: String],
    timeout: TimeInterval,
    label: String) async throws -> SubprocessResult
```

---

## Logging

### CodexBarLog

Structured logging with multiple destinations:

```swift
public enum Level: String {
    case trace, verbose, debug, info, warning, error, critical
}

public static func bootstrapIfNeeded(_ config: Configuration)
public static func logger(_ category: String) -> CodexBarLogger
```

Features:
- Composite handlers (stderr/oslog + file)
- JSON output option
- Automatic redaction of sensitive data
- Per-category loggers with consistent metadata

---

## Platform Support

Several components have conditional compilation:

- **macOS**: Full functionality including keychain, browser detection, PTY execution
- **Other platforms**: Stub implementations that return empty results or pass-through values

Example from `BrowserCookieAccessGate`:
```swift
#if os(macOS)
import os.lock
import SweetCookieKit
// Full implementation
#else
// Stub that always returns true/empty
#endif
```

---

## Testing Infrastructure

The module includes testing hooks:

- `@TaskLocal` overrides for keychain access (`KeychainAccessGate`)
- Test store overrides (`KeychainCacheStore`)
- Handler injection for keychain prompts (`KeychainPromptHandler`)
- Preflight overrides (`KeychainAccessPreflight`)

These enable isolated unit tests without requiring actual keychain access.

---

## Integration Points

CodexBarCore integrates with:

- **SweetCookieKit** — Browser cookie extraction (macOS)
- **Swift Logging** — Log handler infrastructure
- **LocalAuthentication** — Keychain context configuration
- **Foundation** — FileManager, Process, UserDefaults