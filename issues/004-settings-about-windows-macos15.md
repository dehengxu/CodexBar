# Issue #4: Settings and About windows not opening on macOS 15

## 问题描述

在 macOS 15 上，点击 Settings 和 About 菜单时无法弹出窗口，但在 macOS 12 上工作正常。

## 根本原因

### 问题 1: About 菜单错误地打开了 Settings 窗口
在 `StatusItemController+Actions.swift` 中，`showSettingsAbout()` 方法调用了 `openSettings(tab: .about)`，而不是直接调用 `showAbout()` 函数。

### 问题 2: Settings 窗口在 macOS 15 上的兼容性问题
`NSApp.sendAction(Selector(("showPreferencesWindow:")))` 方法在 macOS 15 上可能存在兼容性问题。SwiftUI 的 `Settings` scene 在不同 macOS 版本上的行为可能有所不同。

## 解决方案

### 修复 1: About 菜单直接调用 showAbout()
修改 `Sources/CodexBar/StatusItemController+Actions.swift` 中的 `showSettingsAbout()` 方法：
```swift
// 之前
@objc func showSettingsAbout() {
    self.openSettings(tab: .about)
}

// 之后
@objc func showSettingsAbout() {
    showAbout()
}
```

### 修复 2: 使用 AppKit 窗口控制器实现最大兼容性
创建新文件 `Sources/CodexBar/PreferencesWindowController.swift`：
- 使用 `NSWindowController` 包装 SwiftUI 的 `PreferencesView`
- 提供稳定的 AppKit 窗口，在所有 macOS 版本上都能正常工作
- 支持窗口重用和状态保持

### 修复 3: 修改 AppDelegate 使用窗口控制器
修改 `Sources/CodexBar/CodexbarApp.swift`：
- 在 `AppDelegate` 中添加 `preferencesWindowController` 属性
- 在 `configure` 方法中初始化窗口控制器
- 修改 `handleOpenSettings` 方法优先使用 AppKit 窗口控制器

### 修复 4: 简化 openSettings 方法只使用通知
修改 `Sources/CodexBar/StatusItemController+Actions.swift` 中的 `openSettings(tab:)` 方法：
- 只使用通知方式，让 AppDelegate 统一处理
- 移除复杂的多方法尝试逻辑

## 修改的文件

- `Sources/CodexBar/StatusItemController+Actions.swift` - 修复 About 菜单调用和简化 openSettings
- `Sources/CodexBar/CodexbarApp.swift` - 添加 PreferencesWindowController 支持
- `Sources/CodexBar/PreferencesWindowController.swift` - 新文件，AppKit 窗口控制器

## 验证方式

- 构建成功: `swift build` 编译通过
- About 窗口: 点击 About 菜单应该直接显示标准 About 面板
- Settings 窗口: 点击 Settings 菜单应该在 macOS 12 和 macOS 15 上都能正常打开
- 窗口控制器: 使用 AppKit 的 NSWindowController，提供最大兼容性

## 技术细节

### PreferencesWindowController 的工作原理
1. 使用 `NSHostingController` 包装 SwiftUI 的 `PreferencesView`
2. 创建标准的 AppKit `NSWindow`，设置合适的样式和行为
3. 支持窗口重用，避免每次都创建新窗口
4. 设置 `collectionBehavior` 为 `.moveToActiveSpace` 和 `.fullScreenAuxiliary` 确保窗口行为正确

### 兼容性策略
- 优先使用 AppKit 窗口控制器（最稳定）
- 保留 SwiftUI Settings scene 作为备用方案
- 使用通知机制作为统一的通信方式
- 确保在所有 macOS 版本（12+）上都能正常工作
