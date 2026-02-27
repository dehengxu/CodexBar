# TestsLinux

<think>
The user wants me to write documentation for the TestsLinux module. Let me analyze the source code to understand what this module does.

Looking at the two test files:

1. **JetBrainsParserLinuxTests.swift** - Tests for a regex-based XML parser used on Linux. The tests verify parsing of JetBrains AI Assistant quota files. Key observations:
   - Tests a class/function called `JetBrainsStatusProbe` with a `parseXMLData` method
   - Tests various XML parsing scenarios including:
     - Quota XML with both options (quotaInfo and nextRefill)
     - Quota XML with only quotaInfo
     - XML with reversed attribute order
     - HTML entities handling
     - Missing quotaInfo (throws error)
     - Missing component (throws error)
     - Empty quotaInfo (throws error)
     - XML with single quotes
   - Tests expect a `JetBrainsStatusProbeError.noQuotaInfo` error

2. **PlatformGatingTests.swift** - Tests for platform-specific behavior:
   - Tests that `ClaudeWebAPIFetcher` is not supported on Linux
   - Tests various methods of `ClaudeWebAPIFetcher` that should throw `.notSupportedOnThisPlatform` error on Linux

The module is about:
- Testing a Linux-specific XML parser (regex-based, not using libxml2)
- Testing platform gating for features not available on Linux

The call graph shows no internal calls or execution flows, which makes sense for test files.

Now I need to write documentation that:
1. Explains the purpose of this module
2. Describes how the components work
3. Explains the connection to the rest of the codebase
4. Uses appropriate structure

Let me think about the structure:
- Overview/Purpose
- Test Structure (the two test suites)
- Key Components (JetBrainsStatusProbe, ClaudeWebAPIFetcher platform gating)
- How it connects to the codebase
- Maybe a small diagram showing the relationship


- I'll write clear, developer-focused documentation that explains the purpose and functionality of these test suites.
</think>

# TestsLinux Module

## Overview

The **TestsLinux** module contains platform-specific tests for Linux environments. It validates two distinct concerns:

1. **Regex-based XML parsing** — A fallback parser for JetBrains IDE quota files that doesn't depend on libxml2
2. **Platform gating** — Tests verifying that macOS/Windows-only features properly reject Linux execution

These tests ensure that platform-specific code paths behave correctly when running on Linux build agents.

---

## JetBrainsParserLinuxTests

This test suite validates the `JetBrainsStatusProbe.parseXMLData()` function — a regex-based XML parser used exclusively on Linux. Unlike the macOS implementation (which uses libxml2), this parser uses pattern matching to extract quota information from JetBrains IDE configuration files.

### What It Tests

| Test | Purpose |
|------|---------|
| `parsesQuotaXMLWithBothOptions` | Verifies parsing of complete quota data including `quotaInfo` and `nextRefill` fields |
| `parsesQuotaXMLWithOnlyQuotaInfo` | Tests parsing when only `quotaInfo` is present |
| `parsesXMLWithReversedAttributeOrder` | Ensures the parser handles `value="..."` before `name="..."` attribute order |
| `handlesHTMLEntities` | Confirms proper decoding of `&quot;`, `&#10;`, etc. |
| `throwsOnMissingQuotaInfo` | Validates error handling when the `quotaInfo` option is absent |
| `throwsOnMissingComponent` | Validates error when the target component (`AIAssistantQuotaManager2`) doesn't exist |
| `throwsOnEmptyQuotaInfo` | Ensures empty `value` attributes produce an error |
| `parsesXMLWithSingleQuotes` | Tests that single-quoted attributes are handled correctly |

### Expected Errors

The parser throws `JetBrainsStatusProbeError.noQuotaInfo` when:
- The `<component name="AIAssistantQuotaManager2">` element is missing
- The `<option name="quotaInfo">` attribute is missing or empty

---

## PlatformGatingTests

This suite verifies that features requiring macOS or Windows are properly gated on Linux. It tests the `ClaudeWebAPIFetcher` class, which is not supported on Linux.

### What It Tests

| Test | Purpose |
|------|---------|
| `claudeWebFetcher_isNotSupportedOnLinux` | Confirms `fetchUsage()` throws `.notSupportedOnThisPlatform` |
| `claudeWebFetcher_hasSessionKey_isFalseOnLinux` | Validates that `hasSessionKey()` returns `false` when called with `nil` on Linux |
| `claudeWebFetcher_sessionKeyInfo_throwsOnLinux` | Ensures `sessionKeyInfo()` throws the platform error |

These tests use `#if os(Linux)` conditional compilation to verify Linux-specific behavior while remaining valid Swift on other platforms.

---

## Relationship to Core Module

The tests reference `CodexBarCore`, indicating they test types defined in the main codebase:

```
CodexBarCore (production code)
├── JetBrainsStatusProbe
│   └── parseXMLData()  ← tested by JetBrainsParserLinuxTests
├── JetBrainsStatusProbeError
│   └── .noQuotaInfo   ← expected error type
└── ClaudeWebAPIFetcher
    ├── fetchUsage()   ← tested by PlatformGatingTests
    ├── hasSessionKey()
    └── sessionKeyInfo()
```

The `JetBrainsStatusProbe` type has two implementations:
- **Linux**: Regex-based parsing via `parseXMLData()` (tested here)
- **macOS/Windows**: libxml2-based parsing (tested in platform-specific test suites)

---

## Architecture Notes

### Why Regex Instead of libxml2?

Linux environments in CI may lack the full libxml2 development headers. The regex-based parser provides a fallback that extracts the same data using Swift's `NSRegularExpression` and `NSString` APIs.

### Platform Gating Pattern

The `ClaudeWebAPIFetcher` uses a common pattern for cross-platform code:

```swift
#if os(Linux)
throw FetchError.notSupportedOnThisPlatform
#else
// Actual implementation
#endif
```

This ensures the codebase compiles on all platforms while explicitly rejecting unsupported operations at runtime.

---

## Running These Tests

Execute the Linux-specific tests with:

```bash
swift test --filter TestsLinux
```

Or run individual suites:

```swift
swift test --filter JetBrainsParserLinuxTests
swift test --filter PlatformGatingTests
```