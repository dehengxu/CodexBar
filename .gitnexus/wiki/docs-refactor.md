# docs — refactor

<think>
The user wants me to write comprehensive documentation for the **docs — refactor** module. Let me analyze what's provided:

1. **CLI Refactor Plan** (`cli.md`) - A detailed plan for refactoring the CodexBar CLI with specific goals around:
   - JSON-only error handling
   - Per-provider errors
   - Config validation
   - SettingsStore split into smaller files

2. **Macro Refactor Ideas** (`macros.md`) - Ideas for improving provider macro ergonomics and related refactoring

The call graph shows no internal calls or execution flows - this is a documentation-only module containing planning documents.

Let me structure the documentation to cover:
1. Module Overview - What this module is
2. The Two Planning Documents - detailed coverage of each
3. How they relate to the broader codebase
4. Implementation roadmap (since there's a step-by-step guide)

Since there's no execution flow and this is purely documentation, I'll organize it as:
- Overview/Purpose
- CLI Refactor Plan (detailed)
- Macro Refactor Ideas (detailed)
- Relationship between the two plans
- Implementation guidance
- Possibly a diagram showing how CLI components will be organized after refactor

Let me write this out in a clear, developer-focused way.
</think>

# CodexBar Refactor Planning Documentation

This module contains the architectural planning documents for two major refactoring efforts in the CodexBar codebase:

1. **CLI Refactor Plan** — Restructuring error handling, config validation, and SettingsStore
2. **Macro Refactor Ideas** — Improving provider descriptor ergonomics and pipeline design

These documents serve as the authoritative reference for contributors implementing these changes.

---

## Overview

The `docs/refactor/` module contains technical RFCs (Request for Comments) that guide large-scale refactoring work. Unlike implementation code, these documents describe:

- **Goals** — What the refactor should achieve
- **Constraints** — What existing behavior must be preserved
- **Implementation steps** — How to execute the plan incrementally
- **Validation criteria** — How to verify the work is correct

Both documents assume familiarity with CodexBar's core concepts: providers, fetch strategies, configuration, and the CLI entry point.

---

## CLI Refactor Plan

**File:** `docs/refactor/cli.md`

### Purpose

The CLI refactor addresses three related issues in the CodexBar command-line interface:

1. **Mixed output streams** — Errors currently may appear on stderr in various formats, making programmatic consumption difficult
2. **Config validation gaps** — Invalid configuration fields are not caught early, leading to runtime failures
3. **File size concerns** — `SettingsStore.swift` and `CLIEntry.swift` have grown beyond maintainable limits

### Key Architectural Changes

#### JSON-Only Error Output

All CLI output when `--json-only` is specified follows a consistent schema:

```json
{
  "provider": "cli",
  "source": "cli",
  "error": { "code": 1, "message": "...", "kind": "config" }
}
```

- **`provider`** — Set to `"cli"` for global errors, or the provider name for provider-scoped errors
- **`source`** — Indicates where the error originated (`"cli"`, provider name, etc.)
- **`error`** — Contains `code` (exit code), `message` (human-readable), and `kind` (error category)

This enables consumers to parse a single JSON stream and handle errors programmatically.

#### Config Validation Rules

The validator enforces these rules at config-load time:

| Rule | Condition |
|------|-----------|
| `source` validity | Must exist in the provider's `fetchPlan.sourceModes` |
| `apiKey` presence | Only valid for providers supporting `.api` mode |
| `cookieSource` | Only valid for providers supporting `.web` or `.auto` |
| `region` | Only for `zai` or `minimax`; must be a known value |
| `workspaceID` | Only for `opencode` provider |
| `tokenAccounts` | Only for providers in `TokenAccountSupportCatalog` |

#### SettingsStore Split

The refactor splits `SettingsStore.swift` into focused extension files:

```
SettingsStore.swift          # Core class definition
SettingsStore+Config.swift   # Config-backed computed properties
SettingsStore+Defaults.swift # Default-value computed properties  
SettingsStore+ProviderDetection.swift # Provider enable/disable logic
```

Each file target: under 500 LOC with clear separation of concerns.

### New CLI Commands

| Command | Purpose |
|---------|---------|
| `codexbar config validate` | Validates config, exits non-zero on errors |
| `codexbar config dump` | (Optional) Outputs normalized config JSON |

### Implementation Sequence

The plan specifies an eight-step sequence to minimize risk:

1. **Add validation types** — Create `CodexBarConfigIssue` and `CodexBarConfigValidator` in `CodexBarCore/Config`
2. **Hook validation into CLI** — New `config validate` command with `--json-only` flag
3. **Unify CLI error reporting** — Single exit path through JSON-aware reporter
4. **Split CLIEntry.swift** — Extract helpers and payload structs into dedicated files
5. **Split SettingsStore.swift** — Move computed properties to extension files
6. **Provider toggles cleanup** — Remove unused `ProviderToggleStore`, preserve migration path
7. **Add tests** — Cover JSON error payloads, config validation, order invariants
8. **Verification** — Run `swift test`, `swiftformat`, `swiftlint`, and compile scripts

---

## Macro Refactor Ideas

**File:** `docs/refactor/macros.md`

### Purpose

This document outlines improvements to the provider macro system. It addresses ergonomic issues and architectural concerns that have emerged as the provider system matured.

### Core Ideas

#### 1. Macro Ergonomics

Current state: Macros generate boilerplate but provide limited compile-time feedback.

Desired improvements:
- **Compile-time errors** when macros are attached to wrong targets or missing required implementations (`descriptor`, `init`)
- **Member macro** to generate `static let descriptor` from `makeDescriptor()`, reducing repetition

#### 2. Descriptor Refactoring

Split `ProviderDescriptor` into focused types:

```
ProviderDescriptor   # Core identity
ProviderFetchPlan    # Source modes, API requirements
ProviderBranding     # Display name, icon references
ProviderCLI          # CLI-specific configuration
```

This reduces circular dependencies and makes the descriptor easier to test in isolation.

#### 3. Fetch Pipeline Improvements

Return **all attempted strategies** (not just the successful one) for debugging:

```swift
struct FetchAttempt {
    let strategy: FetchStrategy
    let result: Result<FetchOutput, FetchError>
}

// In the fetch method:
return FetchResult(
    successful: FetchAttempt(...),
    attempts: [FetchAttempt(...), FetchAttempt(...)]  // All tries
)
```

Enables `--verbose` CLI output showing fallback behavior.

#### 4. Registry Order Stability

Current: Registry sorts providers by `rawValue`, which may change between versions.

Proposed:
- Use **registration order** for `all` provider list
- Add metadata flags (`isPrimaryProvider`) instead of hard-coding provider names
- Deterministic ordering enables stable snapshot tests

#### 5. Account/Identity Handling

Replace special-case logic in Codex UI with a descriptor flag:

```swift
// Instead of:
if provider == .codex { /* handle account fallback */ }

// Use:
struct ProviderDescriptor {
    let usesAccountFallback: Bool
}
```

#### 6. Settings + Token Resolution

Move token lookup into strategy-local resolvers:

```
ZaiTokenResolver   # Keychain → environment → failure
CopilotTokenResolver  # Keychain → environment → failure
```

Add optional per-provider settings to `ProviderSettingsSnapshot`.

### Follow-up Tasks

- Add a **minimal provider example** in `docs/provider.md`
- Add **registry completeness test** — all required providers present
- Add **deterministic-order test** — registry order stable across builds

---

## Relationship Between Plans

The two planning documents share several connection points:

| CLI Refactor | Macro Refactor | Connection |
|--------------|----------------|------------|
| Config validation | Descriptor splitting | Validation rules reference `fetchPlan.sourceModes`; descriptor split makes this cleaner |
| Provider errors | Registry order | Provider-scoped errors depend on stable provider ordering |
| SettingsStore | Token resolution | Macro plan moves token lookup to strategy layer; CLI plan cleans up settings |

Both plans also converge on testing:
- CLI refactor adds config validation tests
- Macro refactor calls out registry completeness tests

---

## Reading These Documents

**When to read `cli.md`:**
- Implementing the `config validate` command
- Splitting `SettingsStore.swift` or `CLIEntry.swift`
- Adding new config validation rules
- Working on JSON error output

**When to read `macros.md`:**
- Creating a new provider
- Refactoring provider descriptors
- Adding new fetch strategies
- Improving error reporting in the fetch pipeline

---

## Verification Checklist

After implementing changes per these plans, verify:

- [ ] `swift test` passes
- [ ] `swiftformat Sources Tests` passes
- [ ] `swiftlint --strict` passes  
- [ ] `./Scripts/compile_and_run.sh` succeeds
- [ ] CLI e2e: `codexbar --json-only ...` outputs valid JSON
- [ ] CLI e2e: `codexbar config validate` catches invalid config

---

## File Reference

| File | Purpose |
|------|---------|
| `docs/refactor/cli.md` | CLI error handling, config validation, SettingsStore split |
| `docs/refactor/macros.md` | Provider macro ergonomics, descriptor design, pipeline improvements |