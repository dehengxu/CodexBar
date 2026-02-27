# Sources — CodexBarClaudeWebProbe

<think>
The user wants me to write documentation for the **CodexBarClaudeWebProbe** module. Let me analyze the code:

1. **Module Structure**: This is a Swift command-line tool with `@main` enum `CodexBarClaudeWebProbe`
2. **Purpose**: It's a probe that tests various Claude.ai API endpoints to see which ones are accessible and what they return
3. **Key Components**:
   - `defaultEndpoints` - array of URLs to probe
   - `main()` async function - entry point
   - `printResult()` - formats and prints probe results
4. **Dependencies** (inferred from imports):
   - `CodexBarCore` - likely contains `ClaudeWebAPIFetcher` and `BrowserDetection`
   - `Foundation`

5. **Functionality**:
   - Takes command-line arguments for custom endpoints (or uses defaults)
   - Uses `CLAUDE_WEB_PROBE_PREVIEW` env var to enable preview mode
   - Calls `ClaudeWebAPIFetcher.probeEndpoints()` to test each endpoint
   - Prints results including: URL, status code, content type, top-level keys, emails found, plan hints, notable fields, and body preview

Let me structure the documentation:

1. **Overview** - What this module does
2. **Usage** - How to run it
3. **Configuration** - Environment variables and arguments
4. **Output Format** - What the results look like
5. **Dependencies** - What it relies on (CodexBarCore)
6. **Integration** - How it connects to the rest of the codebase

Since this is a simple, single-file CLI tool, I don't think a Mermaid diagram would add much value. The call graph shows no connections, so it's fairly isolated.

Let me write clear, developer-focused documentation.
</think>

# CodexBarClaudeWebProbe Module

A command-line utility that probes Claude.ai web API endpoints to discover accessible routes and their response structures.

## Overview

`CodexBarClaudeWebProbe` is a diagnostic tool designed to explore the Claude.ai web application's API surface. It sends HTTP requests to various endpoints and inspects responses to identify:

- Which endpoints are accessible (return HTTP 200 or other valid status codes)
- What content types each endpoint returns
- The JSON structure of responses (top-level keys)
- Any email addresses or user identifiers exposed in responses
- Plan-related hints (Team, Pro, etc.)
- Other notable fields in the response body

This module is primarily used during development and research to understand how the Claude.ai web client communicates with its backend.

## Usage

### Basic Invocation

```bash
# Probe all default endpoints
swift run CodexBarClaudeWebProbe
```

### Custom Endpoints

```bash
# Probe specific endpoints
swift run CodexBarClaudeWebProbe https://claude.ai/api/user https://claude.ai/api/me
```

### Preview Mode

Enable preview mode to include raw body previews in output:

```bash
CLAUDE_WEB_PROBE_PREVIEW=1 swift run CodexBarClaudeWebProbe
```

## Command-Line Interface

### Arguments

| Argument | Description |
|----------|-------------|
| `endpoint[s]` | Zero or more URLs to probe. If omitted, the default endpoint list is used. |

### Environment Variables

| Variable | Description |
|----------|-------------|
| `CLAUDE_WEB_PROBE_PREVIEW` | Set to `1` to include raw response body previews in output. |

## Default Endpoints

The tool includes a predefined list of 13 endpoints to probe:

```
https://claude.ai/api/organizations
https://claude.ai/api/organizations/{orgId}/usage
https://claude.ai/api/organizations/{orgId}/overage_spend_limit
https://claude.ai/api/organizations/{orgId}/members
https://claude.ai/api/organizations/{orgId}/me
https://claude.ai/api/organizations/{orgId}/billing
https://claude.ai/api/me
https://claude.ai/api/user
https://claude.ai/api/session
https://claude.ai/api/account
https://claude.ai/settings/billing
https://claude.ai/settings/account
https://claude.ai/settings/usage
```

## Output Format

For each probed endpoint, the tool prints:

```
==> https://claude.ai/api/user
status: 200
content-type: application/json
keys: id, email, name, ...
emails: user@example.com
plan-hints: Team, Pro
fields: created_at, updated_at, ...
preview: {...}
```

### Output Fields

| Field | Description |
|-------|-------------|
| `status` | HTTP status code, or `error` if the request failed |
| `content-type` | Response Content-Type header (if present) |
| `keys` | Top-level JSON keys in the response body |
| `emails` | Email addresses found in the response |
| `plan-hints` | Strings suggesting subscription plans (e.g., "Team", "Pro") |
| `fields` | Notable fields identified in the response |
| `preview` | Truncated raw body (only when `CLAUDE_WEB_PROBE_PREVIEW=1`) |

## Architecture

### Entry Point

The `@main` enum `CodexBarClaudeWebProbe` serves as the application entry point. The `main()` async function coordinates the probing workflow:

1. Parses command-line arguments
2. Checks the `CLAUDE_WEB_PROBE_PREVIEW` environment variable
3. Calls `ClaudeWebAPIFetcher.probeEndpoints()` with the endpoint list
4. Formats and prints each result

### Key Dependencies

This module depends on types from **CodexBarCore**:

- **`ClaudeWebAPIFetcher`** — Performs the actual HTTP requests and response analysis. Provides the `probeEndpoints()` method that returns `ProbeResult` objects.
- **`BrowserDetection`** — Used for browser detection (passed with `cacheTTL: 0` to disable caching during probing).

### Relationship to CodexBarCore

```
CodexBarClaudeWebProbe
        │
        ├── imports ──► CodexBarCore
        │                    │
        │                    ├── ClaudeWebAPIFetcher
        │                    │       └── probeEndpoints()
        │                    │
        │                    └── BrowserDetection
        │
        └── @main enum (CLI entry point)
```

The module is a consumer of CodexBarCore's API probing functionality. It provides a command-line wrapper around the core probing logic, making it easy to run ad-hoc endpoint surveys without writing additional code.

## Exit Codes

| Code | Description |
|------|-------------|
| `0` | All endpoints probed successfully (regardless of their HTTP status) |
| `1` | An error occurred during probing (network failure, invalid URL, etc.) |

## Example Workflow

A typical use case is exploring API endpoints when developing integration with Claude.ai:

```bash
# Quick survey of accessible endpoints
$ swift run CodexBarClaudeWebProbe

==> https://claude.ai/api/user
status: 200
content-type: application/json
keys: id, email, name, avatar_url, created_at

==> https://claude.ai/api/organizations
status: 200
content-type: application/json
keys: organizations

...
```

The results help developers understand which endpoints require authentication, what data they return, and how to structure API calls in downstream modules.