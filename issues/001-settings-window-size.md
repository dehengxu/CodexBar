# Issue #1: Settings 窗口尺寸过小 + 打开系统偏好设置

## 问题描述

1. 点击 Settings... 后弹出的小窗口
2. 同时还打开了 macOS 系统偏好设置界面

## 根本原因

### 问题 1: 打开 macOS 系统偏好设置
在 `Sources/CodexBar/HiddenWindowView.swift` 中，代码监听 `codexbarOpenSettings` 通知后打开系统偏好设置：
```swift
.onReceive(NotificationCenter.default.publisher(for: .codexbarOpenSettings)) { _ in
    Task { @MainActor in
        // Open System Settings directly instead of using openSettings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

### 问题 2: Settings 窗口尺寸过小
- SwiftUI 的 `Settings` 场景在 macOS 12 上不会自动使用内容视图的 frame 大小
- 原代码使用 `.frame(width:height:)` 设置固定尺寸，但在 Settings 场景中此方式不生效
- macOS 13+ 可以使用 `.windowResizability(.contentSize)`，但项目目标是 macOS 12

## 解决方案

### 修复 1: 移除打开系统偏好设置的代码
修改 `Sources/CodexBar/HiddenWindowView.swift`，移除 `.onReceive` 监听器：
```swift
// 之前
.onReceive(NotificationCenter.default.publisher(for: .codexbarOpenSettings)) { _ in
    Task { @MainActor in
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
            NSWorkspace.shared.open(url)
        }
    }
}

// 之后 (已移除)
```

### 修复 2: 使用 frame 约束
修改 `Sources/CodexBar/PreferencesView.swift` 第 64 行:
```swift
// 之前 (不生效)
.frame(width: self.contentWidth, height: self.contentHeight)

// 之后 (使用 minWidth/idealWidth/maxWidth 约束)
.frame(
    minWidth: PreferencesTab.defaultWidth,
    idealWidth: PreferencesTab.defaultWidth,
    maxWidth: PreferencesTab.providersWidth,
    minHeight: PreferencesTab.windowHeight,
    idealHeight: PreferencesTab.windowHeight,
    maxHeight: PreferencesTab.windowHeight
)
```

## 修改的文件

- `Sources/CodexBar/HiddenWindowView.swift` - 移除打开系统偏好设置的代码
- `Sources/CodexBar/PreferencesView.swift` - 第 64 行，使用 frame 约束

## 验证方式

- 构建成功: `swift build` 编译通过
- 点击 Settings... 不再打开 macOS 系统偏好设置
- Settings 窗口尺寸应为 496x580 (默认) 或 720x580 (Providers 标签页)

## 提交记录

- `c7500ee` - Fix Settings window size for macOS 12 compatibility
- 新提交 - Remove system preferences opening from HiddenWindowView
