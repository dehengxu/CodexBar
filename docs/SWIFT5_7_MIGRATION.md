# Swift 6 到 Swift 5.7 迁移记录

## 项目信息
- 迁移目标: macOS 12 (Monterey) + Swift 5.7
- 原目标: macOS 13 (Ventura) + Swift 6
- 迁移日期: 2026-02-26

## 主要修改类别

### 1. 平台版本设置
**文件**: `Package.swift`
```swift
// 修改前
platforms: [.macOS(.v13)]

// 修改后
platforms: [.macOS(.v12)]
```

### 2. 锁机制替换 (OSAllocatedUnfairLock → NSLock)
**原因**: `OSAllocatedUnfairLock` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBarCore/BrowserCookieAccessGate.swift`
- `Sources/CodexBarCore/Providers/Claude/ClaudeOAuth/ClaudeOAuthRefreshFailureGate.swift`

**修改示例**:
```swift
// 修改前
import os.lock
private static let lock = OSAllocatedUnfairLock<State>(initialState: State())

// 修改后
private static let lock = NSLock()
private static var state = State()
```

### 3. Task.sleep API 替换
**原因**: `Task.sleep(for: .seconds())` 和 `.milliseconds()` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBarCore/Providers/Augment/AugmentSessionKeepalive.swift`
- `Sources/CodexBarCore/OpenAIWeb/OpenAIDashboardFetcher.swift`
- `Sources/CodexBarCore/Host/Process/SubprocessRunner.swift`
- `Sources/CodexBar/Providers/Augment/AugmentProviderRuntime.swift`
- `Sources/CodexBar/MenuCardView.swift`
- `Sources/CodexBar/Providers/VertexAI/VertexAILoginFlow.swift`
- `Sources/CodexBar/StatusItemController+Animation.swift`
- `Sources/CodexBar/StatusItemController+Menu.swift`
- `Sources/CodexBar/UsageStore.swift`

**修改示例**:
```swift
// 修改前
try? await Task.sleep(for: .seconds(1))
try? await Task.sleep(for: .milliseconds(500))

// 修改后
try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
try? await Task.sleep(nanoseconds: 500 * 1_000_000)
```

### 4. Duration → TimeInterval
**原因**: `Duration` 类型仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBar/StatusItemController+Animation.swift`
- `Sources/CodexBar/StatusItemController+Menu.swift`

**修改示例**:
```swift
// 修改前
private static let blinkActiveTickInterval: Duration = .milliseconds(75)
private func blinkTickSleepDuration(now: Date) -> Duration { ... }

// 修改后
private static let blinkActiveTickInterval: TimeInterval = 0.075
private func blinkTickSleepDuration(now: Date) -> TimeInterval { ... }
```

### 5. URL API 替换
**原因**: `URL.appending(queryItems:)` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBarCore/Providers/Cursor/CursorStatusProbe.swift`

**修改示例**:
```swift
// 修改前
let url = self.baseURL.appendingPathComponent("/api/usage")
    .appending(queryItems: [URLQueryItem(name: "user", value: userId)])

// 修改后 (使用 URLComponents)
var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)
components?.path = "/api/usage"
components?.queryItems = [URLQueryItem(name: "user", value: userId)]
let url = components?.url ?? baseURL
```

### 6. ServiceManagement API 条件编译
**原因**: `SMAppService` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBar/LaunchAtLoginManager.swift`

**修改示例**:
```swift
// 使用条件编译
if #available(macOS 13.0, *) {
    let service = SMAppService.mainApp
    // ...
} else {
    // 使用旧版 SMLoginItemSetEnabled API
    SMLoginItemSetEnabled(helperBundleId as CFString, enabled)
}
```

### 7. Window API 修改
**原因**: `.defaultSize()` 和 `.windowResizability()` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBar/CodexbarApp.swift`
- `Sources/CodexBar/HiddenWindowView.swift`

**修改示例**:
```swift
// 修改前
WindowGroup { ... }
    .defaultSize(width: 20, height: 20)
    .windowStyle(.hiddenTitleBar)

// 修改后
WindowGroup { ... }
    .windowStyle(.hiddenTitleBar)

// auxiliary 属性也需要条件编译
if #available(macOS 13.0, *) {
    window.collectionBehavior = [.auxiliary, .ignoresCycle, .transient, .canJoinAllSpaces]
} else {
    window.collectionBehavior = [.ignoresCycle, .transient, .canJoinAllSpaces]
}
```

### 8. Swift Charts 条件编译
**原因**: Swift Charts 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBar/CostHistoryChartMenuView.swift`
- `Sources/CodexBar/CreditsHistoryChartMenuView.swift`
- `Sources/CodexBar/UsageBreakdownChartMenuView.swift`

**修改示例**:
```swift
// 添加可用性标记
@available(macOS 13, *)
@MainActor
struct CostHistoryChartMenuView: View { ... }
```

### 9. Grid 布局替换
**原因**: `Grid` 和 `GridRow` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBar/PreferencesProviderDetailView.swift`

**修改示例**:
```swift
// 修改前
Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
    GridRow { ... }
}

// 修改后
VStack(alignment: .leading, spacing: 6) {
    HStack(spacing: 12) { ... }
}
```

### 10. scrollContentBackground 移除
**原因**: `.scrollContentBackground()` 仅在 macOS 13+ 可用

**修改文件**:
- `Sources/CodexBar/PreferencesProviderSidebarView.swift`

### 11. @MainActor 类中的 MainActor.run 移除
**原因**: 在已标记为 @MainActor 的类中，不需要再使用 `MainActor.run`

**修改文件**:
- `Sources/CodexBar/UsageStore+Refresh.swift`
- `Sources/CodexBar/UsageStore+TokenAccounts.swift`
- `Sources/CodexBar/UsageStore.swift`

**修改示例**:
```swift
// 修改前
await MainActor.run {
    self.snapshots[provider] = scoped
    self.errors[provider] = nil
}

// 修改后 (直接在 @MainActor 类中)
self.snapshots[provider] = scoped
self.errors[provider] = nil
```

## 编译状态

### 已修复完成
- 所有 `OSAllocatedUnfairLock` 替换
- 大部分 `Task.sleep` API 替换
- `Duration` → `TimeInterval` 替换
- URL API 替换
- ServiceManagement 条件编译
- Window API 修改
- Swift Charts 可用性标记
- Grid → VStack/HStack 替换
- 大部分 MainActor.run 移除

### 剩余问题
1. **PreferencesDebugPane.swift**: VStack 调用存在语法问题
2. **StatusItemController+Menu.swift**: Charts 视图在 macOS 12 下需要完全禁用或提供替代方案
3. **UsageStore.swift**: 还有几处 `Task.sleep(for:)` 和 `MainActor.run` 需要修复

## 建议

对于 Charts 相关功能，建议：
1. 在 macOS 12 下完全禁用图表功能
2. 或者使用条件编译包装 Charts 调用

对于剩余的 actor 隔离问题，建议：
1. 确保所有 @MainActor 类中的属性访问不再使用 MainActor.run
2. 检查异步方法中的属性修改
