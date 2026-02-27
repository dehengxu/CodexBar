# Tests

<think>
Looking at the test files, I can see this is a test suite for the CodexBar application. Let me analyze the structure:

1. **AmpUsageFetcherTests** - Tests for AMP usage fetching logic
2. **AmpUsageParserTests** - Tests for parsing AMP usage data
3. **AntigravityStatusProbeTests** - Tests for user status parsing
4. **AppDelegateTests** - Tests for app lifecycle
5. **AugmentStatusProbeTests** - Tests for Augment status probing

I need to write documentation for the "Tests — CodexBarTests" module that synthesizes these child modules without repeating their individual content.

Let me structure this as:
- Brief overview of what this test module covers
- How the sub-modules work together
- A diagram showing relationships (if useful)
- Links to child pages

The tests appear to cover:
- App lifecycle (AppDelegateTests)
- External service integration (AntigravityStatusProbeTests, AugmentStatusProbeTests)
- AMP usage tracking (AmpUsageFetcherTests, AmpUsageParserTests)

These relate to the main application which monitors AMP usage and user status across different services.
</think>

# Tests — CodexBarTests

This module contains the test suite for CodexBar, covering app lifecycle, external service integration, and AMP usage tracking. The tests verify the application's core functionality through isolated unit tests.

## Scope

The test module validates three main functional areas:

- **App Initialization** — Ensures the application bootstraps correctly and initializes its status controllers
- **Status Probing** — Verifies integration with external services (Antigravity and Augment) for user status detection
- **Usage Tracking** — Tests fetching and parsing of AMP usage data from the external service

## Sub-modules

| Test Module | Purpose |
|-------------|---------|
| [AmpUsageFetcherTests](tests-codexbar-tests-ampusagefetcher.md) | Validates HTTP requests for AMP usage data, including cookie handling and redirect detection |
| [AmpUsageParserTests](tests-codexbar-tests-ampusageparser.md) | Tests HTML parsing logic for extracting free tier usage metrics |
| [AntigravityStatusProbeTests](tests-codexbar-tests-antigravitystatusprobe.md) | Verifies parsing of user status responses from the Antigravity API |
| [AppDelegateTests](tests-codexbar-tests-appdelegate.md) | Tests app lifecycle events and status controller initialization |
| [AugmentStatusProbeTests](tests-codexbar-tests-augmentstatusprobe.md) | Validates Augment service status probing logic |

## Test Organization

Each sub-module tests a specific component in isolation, using mocked dependencies to avoid network calls. This approach enables fast test execution and deterministic validation of component behavior.

The tests follow a layered pattern: lower-level parsers (like `AmpUsageParser`) are tested independently, then the fetchers that use them are validated with mock responses, and finally the integration points (status probes) are verified against expected response formats.