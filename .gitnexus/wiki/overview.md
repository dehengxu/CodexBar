# CodexBar — Wiki

<think>
The user wants me to write the top-level overview page for the CodexBar repository wiki. Let me analyze what's been provided:

1. **Project Info**: CodexBar is a macOS 14+ menu bar app that displays API usage/token limits for various AI providers (Claude, Cursor, Codex, etc.)

2. **Module Summaries**: There are several modules:
   - Root (config files)
   - Icon.icon (app icon)
   - Scripts (build/deploy scripts)
   - Sources (main code: CodexBar app, CLI, watchdog, web probe, core)
   - Tests (macOS tests)
   - TestsLinux (Linux tests)
   - docs (planning docs)

3. **Key Requirements**:
   - Be clear and welcoming
   - Reference actual module names so readers can navigate
   - Include Mermaid diagram (max 10 nodes)
   - No module index tables
   - Link to module pages naturally in text

Let me write a good overview that:
1. Introduces what CodexBar is
2. Shows the architecture with a Mermaid diagram
3. Explains key flows
4. Links to relevant modules naturally
5. Includes setup instructions

The diagram should show the main components:
- CodexBar (main app)
- CodexBarCLI (CLI)
- CodexBarCore (shared)
- Sources (fetchers, parsers, probes)
- Icon
- Scripts
- Tests

Let me write this out:
</think>

# CodexBar 🎚️

Welcome to the CodexBar codebase. This repository contains a tiny macOS 14+ menu bar application that keeps your AI provider usage limits visible — tracking session and weekly quotas for Claude, Cursor, Codex, Gemini, and many others. It lives entirely in your menu bar with no Dock icon.

## What It Does

CodexBar displays a status item per provider in your menu bar, showing current token usage and when each quota window resets. You can enable only the providers you use via Settings, or use "Merge Icons" mode with a provider switcher and optional Overview tab. The app monitors AI services like Claude.ai, Cursor, GitHub Copilot, Google Gemini, and others — pulling usage data from both web APIs and local CLI processes.

There's also a **Linux CLI** variant for headless environments, driven by the [Omarchy](https://omarchy.com) community project with Waybar module and TUI support.

## Architecture Overview

The codebase is organized into several key areas:

```
┌─────────────────────────────────────────────────────────────┐
│                      CodexBar                               │
│                  (macOS Menu Bar App)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ UsageFetchers │  │ StatusProbes  │  │  UI Components│
│ (API clients) │  │ (web checks)  │  │ (menu, icons) │
└───────────────┘  └───────────────┘  └───────────────┘
        │                  │
        ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    CodexBarCore                              │
│         (Shared: config, cookies, keychain, prefs)          │
└─────────────────────────────────────────────────────────────┘
```

- **[Sources](Sources.md)** — The main application code including the menu bar app, CLI, and shared core utilities. This is where you'll find the [fetchers](Sources.md#codexbar-sources-usagefetchers) that query each provider's API, the [probes](Sources.md#codexbar-sources-statusprobes) that check account status, and the [UI layer](Sources.md#codexbar-sources-app) that renders the menu bar interface.
- **[Scripts](Scripts.md)** — Build, release, and deployment automation. These handle packaging the app, generating icons, and publishing releases.
- **[Tests](Tests.md)** and **[TestsLinux](TestsLinux.md)** — Platform-specific test suites ensuring correctness across macOS and Linux.

## Key End-to-End Flows

### Menu Bar Display Flow

1. On launch, the [AppDelegate](Sources.md#codexbar-sources-app) initializes the menu bar status2. Each item
 enabled provider starts a [UsageFetcher](Sources.md#codexbar-sources-usagefetchers) that runs on a timer
3. Fetchers query their respective APIs (some via browser cookies, some via CLI wrappers) to get current quota info
4. The results flow into the [StatusItemController](Sources.md#codexbar-sources-statusitemcontroller) which updates the menu bar icon and text
5. [StatusProbes](Sources.md#codexbar-sources-statusprobes) periodically check if the user is logged in or if there are service issues

### CLI Query Flow

1. The [CodexBarCLI](Sources.md#codexbar-sources-codexbarcli) accepts command-line arguments specifying a provider
2. It loads configuration from [SettingsStore](Sources.md#codexbar-sources-settingsstore) to get stored credentials
3. Uses the same [UsageFetcher](Sources.md#codexbar-sources-usagefetchers) infrastructure to fetch quota data
4. Outputs JSON to stdout for consumption by external tools like Waybar

## Getting Started

### Requirements

- **macOS 14+ (Sonoma)** for the full menu bar app
- **macOS 13+** for CLI-only usage
- **Linux** for CLI with Omarchy integration

### Setup

```bash
# Install dependencies
brew install swiftlint swift-format

# Run the app in development
make start

# Run tests
make test        # macOS UI tests
make test:live   # interactive test mode

# Build for release
make build
```

For release deployment, see the [Scripts](Scripts.md) module which handles code signing, notarization, and publishing to GitHub Releases and Homebrew.

### Development Notes

- The app uses **no external dependencies** beyond Apple's frameworks — SwiftUI for UI, Foundation for networking
- Provider credentials are stored in the **Keychain** (see [Keychain](Sources.md#codexbar-sources-keychain))
- Browser cookies for web API access are managed through [BrowserCookieReader](Sources.md#codexbar-sources-browsercookiereader)
- Configuration lives in [SettingsStore](Sources.md#codexbar-sources-settingsstore) and persists via `UserDefaults`

## Project Structure

| Path | Purpose |
|------|---------|
| `Sources/CodexBar/` | Main macOS menu bar application |
| `Sources/CodexBarCLI/` | Command-line interface for Linux/macOS |
| `Sources/CodexBarCore/` | Shared utilities (config, keychain, cookies) |
| `Sources/CodexBarClaudeWatchdog/` | Process supervisor for Claude CLI |
| `Sources/CodexBarClaudeWebProbe/` | Network probe for Claude.ai endpoints |
| `Scripts/` | Build and release automation |
| `Tests/` | macOS test suite |
| `TestsLinux/` | Linux-compatible tests |

## Contributing

See [AGENTS.md](https://github.com/steipete/CodexBar/blob/main/AGENTS.md) for repository guidelines. The project follows standard Swift conventions and uses SwiftLint for style enforcement. When adding a new provider:

1. Create a new `*UsageFetcher` in [Sources](Sources.md)
2. Add it to the provider registry
3. Add Settings UI for enabling/disabling
4. Write tests in [Tests](Tests.md)