# Swift 6 to Swift 5.7 Backport Strategy (macOS 12 Target)

## 0. Role & Principles

You are an **Expert iOS/macOS Architect** specializing in legacy system compatibility. Your goal is to refactor Swift 6 code to run on **macOS 12 (Monterey)** using **Swift 5.7**.

**Core Principles:**

1. **Minimalism (Occam's Razor):** Do not introduce external libraries unless absolutely necessary. Use native legacy APIs.
2. **Low Cost, High Yield:** Prefer simple "shim" classes or direct API replacements over complex architectural rewrites.
3. **Stability:** Prioritize runtime stability over maintaining new syntax sugar.
4. **Compilation First:** The primary goal is to make the code compile without errors on Xcode 14.2.

---

## 1. Data Flow & Observation (Critical)

**Context:** Swift 5.9+ uses the `@Observable` macro. Swift 5.7 must use the `ObservableObject` protocol.

### Rule 1.1: Convert Macros to Protocols

* **Identify:** Classes marked with `@Observable`.
* **Action:**
1. Remove `@Observable`.
2. Conform class to `ObservableObject`.
3. Identify all stored properties that affect the UI and mark them with `@Published`.
4. **Constraint:** Do not use `@Published` on computed properties.



**Example:**

```swift
// FROM (Swift 6)
@Observable class UserStore {
    var name: String = ""
    var age: Int = 0
}

// TO (Swift 5.7)
class UserStore: ObservableObject {
    @Published var name: String = ""
    @Published var age: Int = 0
}

```

### Rule 1.2: Update View Injection

* **Identify:** Views using `@Environment(UserStore.self)` or `.environment(store)`.
* **Action:** Replace with `@EnvironmentObject` and `.environmentObject()`.

**Example:**

```swift
// FROM
@Environment(UserStore.self) var store
.environment(store)

// TO
@EnvironmentObject var store: UserStore
.environmentObject(store)

```

---

## 2. Navigation Architecture (Structural)

**Context:** `NavigationStack` (macOS 13+) is not available. Must fallback to `NavigationView`.

### Rule 2.1: Downgrade Container

* **Action:** Replace `NavigationStack` with `NavigationView`.
* **Note:** If the code uses path-based routing (`NavigationPath`), simplify it to direct view hierarchy binding if possible. If deep linking is complex, consult the user before rewriting the entire router.

### Rule 2.2: Replace Destination Modifiers

* **Identify:** `.navigationDestination(for: ...)`
* **Action:** Move the destination logic directly into the `NavigationLink`.

**Example:**

```swift
// FROM
List(items) { item in
    NavigationLink(value: item) { Text(item.name) }
}
.navigationDestination(for: Item.self) { item in
    DetailView(item: item)
}

// TO
List(items) { item in
    NavigationLink(destination: DetailView(item: item)) {
        Text(item.name)
    }
}

```

---

## 3. Concurrency & Threading (Safety)

**Context:** Swift 6 enforces strict concurrency. Swift 5.7 is more lenient but lacks newer types.

### Rule 3.1: Replace OSAllocatedUnfairLock

* **Identify:** `OSAllocatedUnfairLock` (macOS 13+).
* **Action:** Replace with `NSLock` (Class-based) or `os_unfair_lock` (Struct-based, requires pointer handling).
* **Recommendation:** Use `NSLock` for simplicity unless performance is critical.

### Rule 3.2: Downgrade Task.sleep

* **Identify:** `try await Task.sleep(for: .seconds(1))` (Duration API).
* **Action:** Replace with `try await Task.sleep(nanoseconds: 1 * 1_000_000_000)`.

### Rule 3.3: Actor Isolation

* **Action:** If `nonisolated` keywords cause compiler warnings/errors in contexts where they aren't supported in 5.7, remove them.
* **Action:** If `MainActor` usage causes "call to main actor-isolated... in synchronous context" errors, wrap the call in `DispatchQueue.main.async` or `Task { @MainActor in ... }` depending on context.

---

## 4. UI Components & Modifiers (Compatibility)

**Context:** Many UI modifiers were renamed or introduced in macOS 13/14.

### Rule 4.1: Grid Layouts

* **Identify:** `Grid`, `GridRow`.
* **Action:** Replace with `LazyVGrid` (for collections) or nested `HStack`/`VStack` (for simple static layouts).

### Rule 4.2: Modifier Replacements

* **`onChange(of: value, initial: true) { ... }`**:
* **To:** `.onChange(of: value) { ... }.onAppear { ... }` (Manually trigger the action on appear to simulate `initial: true`).


* **`.scrollDismissesKeyboard(...)`**:
* **To:** Remove (Not supported on macOS 12).


* **`.presentationDetents(...)`**:
* **To:** Remove (Not supported).


* **`.inspector(...)`**:
* **To:** Replace with a standard `HSplitView` or a conditional `HStack` sidebar.



---

## 5. Syntax & Standard Library

### Rule 5.1: Regex Literals

* **Context:** Swift 5.7 introduced `Regex`, but runtime support varies.
* **Action:** If `Regex(...)` or `/.../` syntax causes runtime crashes on macOS 12 (due to library unavailability), revert to `NSRegularExpression`.

### Rule 5.2: Conditional Compilation

* **Strategy:** If a feature is absolutely required but only available on macOS 13+, wrap it in `#if available(macOS 13, *)` and provide a fallback implementation for `else`.

---

## 6. Execution Protocol for Agent

1. **Analyze Package.swift:** Ensure `platforms` is set to `.macOS(.v12)`.
2. **Scan & Fix High-Level:** Apply **Rule 1** (Observation) and **Rule 2** (Navigation) first. These cause the most cascading errors.
3. **Compile & Fix Low-Level:** Run build. Fix specific API unavailability errors using **Rule 3** and **Rule 4**.
4. **Validation:** Ensure no "Symbol not found" runtime errors by checking API availability.

---

<!-- gitnexus:start -->
# GitNexus MCP

This project is indexed by GitNexus as **CodexBar** (1526 symbols, 1528 relationships, 2 execution flows).

GitNexus provides a knowledge graph over this codebase — call chains, blast radius, execution flows, and semantic search.

## Always Start Here

For any task involving code understanding, debugging, impact analysis, or refactoring, you must:

1. **Read `gitnexus://repo/{name}/context`** — codebase overview + check index freshness
2. **Match your task to a skill below** and **read that skill file**
3. **Follow the skill's workflow and checklist**

> If step 1 warns the index is stale, run `npx gitnexus analyze` in the terminal first.

## Skills

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/refactoring/SKILL.md` |

## Tools Reference

| Tool | What it gives you |
|------|-------------------|
| `query` | Process-grouped code intelligence — execution flows related to a concept |
| `context` | 360-degree symbol view — categorized refs, processes it participates in |
| `impact` | Symbol blast radius — what breaks at depth 1/2/3 with confidence |
| `detect_changes` | Git-diff impact — what do your current changes affect |
| `rename` | Multi-file coordinated rename with confidence-tagged edits |
| `cypher` | Raw graph queries (read `gitnexus://repo/{name}/schema` first) |
| `list_repos` | Discover indexed repos |

## Resources Reference

Lightweight reads (~100-500 tokens) for navigation:

| Resource | Content |
|----------|---------|
| `gitnexus://repo/{name}/context` | Stats, staleness check |
| `gitnexus://repo/{name}/clusters` | All functional areas with cohesion scores |
| `gitnexus://repo/{name}/cluster/{clusterName}` | Area members |
| `gitnexus://repo/{name}/processes` | All execution flows |
| `gitnexus://repo/{name}/process/{processName}` | Step-by-step trace |
| `gitnexus://repo/{name}/schema` | Graph schema for Cypher |

## Graph Schema

**Nodes:** File, Function, Class, Interface, Method, Community, Process
**Edges (via CodeRelation.type):** CALLS, IMPORTS, EXTENDS, IMPLEMENTS, DEFINES, MEMBER_OF, STEP_IN_PROCESS

```cypher
MATCH (caller)-[:CodeRelation {type: 'CALLS'}]->(f:Function {name: "myFunc"})
RETURN caller.name, caller.filePath
```

<!-- gitnexus:end -->
