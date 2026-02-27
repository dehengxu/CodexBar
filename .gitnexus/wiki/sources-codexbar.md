# Sources — CodexBar

<think>
The user wants me to write comprehensive documentation for the **Sources — CodexBar** module. Let me analyze the code provided to understand what this module does.

Looking at the files provided:
1. `About.swift` - Shows the About panel for the app
2. `AppNotifications.swift` - Handles notification permissions and posting
3. `ClaudeLoginRunner.swift` - Handles Claude CLI login flow
4. `CodexLoginRunner.swift` - Handles Codex CLI login flow
5. `CodexbarApp.swift` - Main app entry point and AppDelegate
6. `CodexBarConfigMigrator.swift` - Migrates legacy config to new format
7. `CookieHeaderStore.swift` - Stores cookies in keychain
8. `CopilotTokenStore.swift` - Stores Copilot tokens in keychain
9. `CostHistoryChartMenuView.swift` - SwiftUI chart for cost history
10. `CreditsHistoryChartMenuView.swift` - SwiftUI chart for credits history
11. `CursorLoginRunner.swift` - Handles Cursor login via WebKit
12. `Date+RelativeDescription.swift` - Date formatting utilities
13. `DisplayLink.swift` - Display link driver for UI updates
14. `GeminiLoginRunner.swift` - Handles Gemini CLI login
15. `HiddenWindowView.swift` - Hidden window for SwiftUI lifecycle
16. `IconRenderer.swift` - Renders menu bar icons

This is a macOS menu bar application called CodexBar that tracks usage/costs for various AI providers (Codex, Claude, Cursor, etc.).

The source code was truncated, but I have enough to understand the module. Let me write comprehensive documentation.

Key aspects to cover:
1. Module overview/purpose
2. App lifecycle (CodexbarApp.swift, AppDelegate)


3. Authentication flows (ClaudeLoginRunner, CodexLoginRunner, CursorLoginRunner, GeminiLoginRunner)
4. Storage layer (CookieHeaderStore, CopilotTokenStore)
5. UI components (CostHistoryChartMenuView, CreditsHistoryChartMenuView, IconRenderer)
6. Configuration management (CodexBarConfigMigrator)
7. Notifications (AppNotifications)
8. Utilities (Date+RelativeDescription, DisplayLink, HiddenWindowView)

I'll organize this with clear sections and include a Mermaid diagram to show how the components interact.
</think>

# CodexBar Module Documentation

The **CodexBar** module is the main macOS application target for CodexBar — a menu bar application that tracks usage, costs, and credits across multiple AI provider services (Codex, Claude, Cursor, Gemini, Copilot, etc.). It provides a status bar interface, authentication flows for each provider, persistent credential storage, and visual cost/credits history charts.

---

## Architecture Overview

CodexBar runs as a menu bar (status bar) application on macOS. The app presents usage information directly in the system menu bar, with a dropdown showing cost breakdowns, historical charts, and provider management.

```mermaid
flowchart TB
    subgraph App["CodexBar App"]
        A["CodexbarApp<br>@main entry"]
        AD["AppDelegate"]
        SC["StatusItemController"]
    end
    
    subgraph Auth["Authentication"]
        CL["ClaudeLoginRunner"]
        CoL["CodexLoginRunner"]
        CuL["CursorLoginRunner"]
        GL["GeminiLoginRunner"]
    end
    
    subgraph Storage["Credential Storage"]
        CHS["CookieHeaderStore"]
        CTS["CopilotTokenStore"]
    end
    
    subgraph UI["UI Components"]
        IR["IconRenderer"]
        CH["CostHistoryChartMenuView"]
        CR["CreditsHistoryChartMenuView"]
    end
    
    subgraph Config["Configuration"]
        CCM["CodexBarConfigMigrator"]
    end
    
    A --> AD
    AD --> SC
    AD --> Auth
    Auth --> Storage
    SC --> UI
    UI --> Config
```

---

## App Lifecycle

### Main Entry Point

**`CodexbarApp.swift`** — The SwiftUI-based main entry point.

```swift
@main
struct CodexBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: SettingsStore
    @State private var store: UsageStore
    // ...
}
```

Key responsibilities:
- Initializes logging via `CodexBarLog.bootstrapIfNeeded()`
- Creates the `SettingsStore` and `UsageStore` (core data stores)
- Configures the `AppDelegate` with dependencies
- Sets up two SwiftUI scenes:
  - **Lifecycle keepalive window** — A hidden 1×1 window that keeps SwiftUI's lifecycle active so the Settings scene can use native toolbar tabs
  - **Settings scene** — Opens the preferences window using SwiftUI's `Settings` scene

### App Delegate

The **`AppDelegate`** manages the app's lifecycle and coordinates core components:

```swift
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController: UpdaterProviding
    private var statusController: StatusItemControlling?
    private var store: UsageStore?
    private var settings: SettingsStore?
}
```

**Key behaviors:**
- `applicationDidFinishLaunching()` — Requests notification permissions, ensures the status item controller exists, registers keyboard shortcuts
- `configureAppIconForMacOSVersion()` — Uses classic app icon on macOS versions before 26 (applies non-Liquid Glass appearance)
- `ensureStatusController()` — Creates the `StatusItemController` that manages the menu bar item

### Hidden Window for Lifecycle

**`HiddenWindowView.swift`** — Provides a workaround for SwiftUI's Settings scene. The Settings scene requires at least one window to function, but CodexBar is primarily an AppKit menu bar app. The hidden window keeps SwiftUI's lifecycle alive.

```swift
struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 20, height: 20)
            .onAppear {
                // Make the window truly invisible and non-interactive
                window.styleMask = [.borderless]
                window.isOpaque = false
                window.alphaValue = 0
                window.ignoresMouseEvents = true
            }
    }
}
```

---

## Authentication Flows

CodexBar supports multiple AI providers, each with its own authentication mechanism. Login runners handle the OAuth/token acquisition flow for each provider.

### Claude Login

**`ClaudeLoginRunner.swift`** — Runs the `claude` CLI with `/login` subcommand in a pseudo-terminal (PTY).

```swift
struct ClaudeLoginRunner {
    static func run(timeout: TimeInterval = 120, onPhaseChange: @escaping @Sendable (Phase) -> Void) async -> Result
}
```

**Flow:**
1. Spawns a PTY with `TTYCommandRunner` running `claude /login`
2. Monitors for success strings (`"Successfully logged in"`, `"Login successful"`)
3. Extracts the OAuth URL from terminal output using regex
4. Opens browser for user authentication
5. Waits for CLI to confirm successful login

### Codex Login

**`CodexLoginRunner.swift`** — Runs the Codex CLI `login` subcommand directly.

```swift
struct CodexLoginRunner {
    static func run(timeout: TimeInterval = 120) async -> Result
}
```

**Flow:**
1. Resolves the `codex` binary using `BinaryLocator`
2. Runs the process with `Process`, capturing stdout/stderr
3. Attaches to the process group for proper termination
4. Waits with timeout, terminates gracefully on timeout

### Cursor Login

**`CursorLoginRunner.swift`** — Uses WebKit to perform OAuth login in an embedded browser window.

```swift
@MainActor
final class CursorLoginRunner: NSObject {
    func run(onPhaseChange: @escaping @Sendable (Phase) -> Void) async -> Result
}
```

**Flow:**
1. Creates a `WKWebView` in a dedicated window
2. Navigates to `https://cursor.com/dashboard`
3. Detects navigation to authenticator URL (login page)
4. Monitors for redirect back to dashboard after auth
5. Extracts session cookies from `WKWebsiteDataStore`
6. Stores cookies in `CursorSessionStore`

### Gemini Login

**`GeminiLoginRunner.swift`** — Launches the Gemini CLI which prompts for OAuth authentication.

```swift
enum GeminiLoginRunner {
    static func run(onCredentialsCreated: (@Sendable () -> Void)? = nil) async -> Result
}
```

**Flow:**
1. Clears existing credentials (enables account switching)
2. Creates a temporary `.command` script that runs `gemini`
3. Opens the script in Terminal (which triggers the OAuth prompt)
4. Watches for `~/.gemini/oauth_creds.json` to appear
5. Calls callback when credentials are created

---

## Credential Storage

Credentials are stored securely in the macOS Keychain.

### Cookie Header Store

**`CookieHeaderStore.swift`** — Stores session cookies for web-based providers (Codex, Claude, Cursor, etc.).

```swift
struct KeychainCookieHeaderStore: CookieHeaderStoring {
    func loadCookieHeader() throws -> String?
    func storeCookieHeader(_ header: String?) throws
}
```

**Features:**
- 30-minute in-memory cache to reduce keychain access frequency
- Normalizes cookies before storage
- Handles keychain interaction prompts via `KeychainPromptHandler`
- Respects `KeychainAccessGate` (can be disabled for debugging)

### Copilot Token Store

**`CopilotTokenStore.swift`** — Stores GitHub Copilot API tokens.

```swift
struct KeychainCopilotTokenStore: CopilotTokenStoring {
    func loadToken() throws -> String?
    func storeToken(_ token: String?) throws
}
```

**Features:**
- Uses `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` for security
- Trims whitespace from stored tokens
- Provides `CopilotTokenStoreError` for error handling

---

## Configuration Migration

**`CodexBarConfigMigrator.swift`** — Migrates legacy user defaults and keychain items to the new `CodexBarConfig` format.

```swift
struct CodexBarConfigMigrator {
    static func loadOrMigrate(
        configStore: CodexBarConfigStore,
        userDefaults: UserDefaults,
        stores: LegacyStores) -> CodexBarConfig
}
```

**Migrates:**
- Provider order and toggle states from `UserDefaults`
- Cookie sources from legacy keys
- Token providers (ZAI, Synthetic, Copilot, KimiK2)
- Cookie providers (Codex, Claude, Cursor, Factory, Augment, Amp)
- MiniMax (token + region + cookie)
- Kimi (token or manual cookie header)
- OpenCode (cookie + workspace ID)
- Legacy token accounts

After migration, clears legacy stores to prevent duplicate credentials.

---

## UI Components

### Icon Renderer

**`IconRenderer.swift`** — Renders the menu bar icon dynamically based on usage remaining.

```swift
enum IconRenderer {
    static func makeIcon(
        primaryRemaining: Double?,
        weeklyRemaining: Double?,
        creditsRemaining: Double?,
        stale: Bool,
        style: IconStyle,
        blink: CGFloat = 0,
        wiggle: CGFloat = 0,
        tilt: CGFloat = 0,
        statusIndicator: ProviderStatusIndicator = .none) -> NSImage
}
```

**Features:**
- Renders at 18×18pt (36×36px at 2×) for menu bar
- Provider-specific visual twists:
  - **Codex** — Face with eyes and hat
  - **Claude** — Blocky crab-style with arms, legs, vertical eyes
  - **Gemini** — Sparkle eyes (4-pointed stars), decorative points
  - **Cursor** — Notches (similar to Claude but simpler)
  - **Factory** — 8-pointed asterisk eyes with cog teeth
- Animation support: blink, wiggle, tilt
- Caching with `IconCacheStore` (64 icons) and `MorphCache` (512 morph frames)

### Cost History Chart

**`CostHistoryChartMenuView.swift`** — SwiftUI chart showing daily costs over the past 30 days.

- Interactive: hover to see per-day details (cost, token count, top models)
- Highlights peak day with yellow cap
- Uses `Charts` framework with custom overlay for mouse tracking

### Credits History Chart

**`CreditsHistoryChartMenuView.swift`** — SwiftUI chart showing OpenAI credits usage.

- Similar interaction to Cost History
- Groups by service (ChatGPT, API, etc.)
- Shows total 30-day credits used

### Display Link Driver

**`DisplayLink.swift`** — Minimal display link driver for UI updates.

```swift
@MainActor
@Observable
final class DisplayLinkDriver {
    var tick: Int = 0
    func start(fps: Double = 12)
    func stop()
}
```

- Uses `NSScreen.displayLink` on macOS 15+
- Falls back to `CVDisplayLink` on macOS 14
- Publishes ticks at configurable frame rate (default 12 fps)
- Drives SwiftUI updates without blocking the main thread

---

## Notifications

**`AppNotifications.swift`** — Handles local notification permissions and posting.

```swift
@MainActor
final class AppNotifications {
    static let shared = AppNotifications()
    
    func requestAuthorizationOnStartup()
    func post(idPrefix: String, title: String, body: String, badge: NSNumber? = nil)
}
```

**Features:**
- Requests notification authorization on app startup
- Posts notifications with unique IDs (`codexbar-{prefix}-{UUID}`)
- Skips posting when running under tests (detects XCTest, Swift Testing, non-bundle runs)
- Uses `UNUserNotificationCenter.current()`

---

## Utilities

### Date Relative Description

**`Date+RelativeDescription.swift`** — Human-readable relative time formatting.

```swift
extension Date {
    @MainActor
    func relativeDescription(now: Date = .now) -> String
}
```

Returns strings like "just now", "5 minutes ago", "2 days ago".

### About Panel

**`About.swift`** — Customizes the standard macOS About panel.

- Sets app name, version, build number
- Adds clickable links (GitHub, Website, Twitter, Email)
- Shows build timestamp and git commit (with "DEBUG BUILD" tag in debug builds)
- Removes focus ring around app icon for cleaner appearance

---

## Integration Points

The CodexBar module depends on:

| Module/Package | Purpose |
|---------------|---------|
| `CodexBarCore` | Core types (`UsageProvider`, `ProviderConfig`, `SettingsStore`, `UsageStore`, logging) |
| `AppKit` | Menu bar, windows, NSApplication |
| `SwiftUI` | Preferences UI, Charts |
| `KeyboardShortcuts` | Global keyboard shortcut handling |
| `UserNotifications` | Local notifications |
| `Security` | Keychain access |
| `Sparkle` (optional) | Auto-update support |

---

## Key Design Decisions

1. **Menu bar app with hidden window** — Uses a 1×1 hidden window to keep SwiftUI's Settings scene functional while remaining primarily an AppKit menu bar app

2. **Multiple auth flows** — Each provider uses a different auth mechanism (CLI PTY, direct process, WebKit browser, or external CLI prompt)

3. **Keychain with caching** — Cookie/token stores use keychain for security but cache in memory (30 min TTL) to reduce latency

4. **Provider-specific icons** — Each AI provider has a distinct visual style in the menu bar (face, crab, sparkle, etc.)

5. **Legacy migration** — Config migrator ensures users upgrading from older versions don't lose their settings

6. **Test-safe** — Authentication runners and notifications detect test environments and skip operations that would fail in headless/test contexts