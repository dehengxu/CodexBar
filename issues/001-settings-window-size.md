# Issue #1: Settings 窗口 + 启动时显示小窗口

## 问题描述

1. 点击 Settings... 后弹出的小窗口
2. 同时还打开了 macOS 系统偏好设置界面
3. **应用启动后显示小窗口** (新发现)

## 根本原因

### 问题 1: 打开 macOS 系统偏好设置
在 `Sources/CodexBar/HiddenWindowView.swift` 中，代码监听 `codexbarOpenSettings` 通知后打开系统偏好设置：
```swift
.onReceive(NotificationCenter.default.publisher(for: .codexbarOpenSettings)) { _ in
    // 打开系统偏好设置
}
```

### 问题 2: Settings 窗口尺寸过小
- SwiftUI 的 `Settings` 场景在 macOS 12 上不会自动使用内容视图的 frame 大小
- macOS 13+ 可以使用 `.windowResizability(.contentSize)`，但项目目标是 macOS 12

### 问题 3: 应用启动时显示小窗口
- HiddenWindowView 的 `.onAppear` 在 SwiftUI App 启动时没有正确执行来隐藏窗口
- 需要在 AppDelegate 中可靠地隐藏这个窗口

## 解决方案

### 修复 1: 移除打开系统偏好设置的代码
修改 `Sources/CodexBar/HiddenWindowView.swift`，移除 `.onReceive` 监听器

### 修复 2: 使用 frame 约束
修改 `Sources/CodexBar/PreferencesView.swift` 第 64 行

### 修复 3: 在 AppDelegate 中隐藏窗口
修改 `Sources/CodexBar/CodexbarApp.swift`，在 `applicationDidFinishLaunching` 中添加 `hideLifecycleWindow` 方法：

```swift
private func hideLifecycleWindow() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        // 通过窗口标题精确识别 Keepalive 窗口
        if let window = NSApp.windows.first(where: { $0.title == "CodexBarLifecycleKeepalive" }) {
            window.orderOut(nil)
            window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
            window.level = .floating
            window.isOpaque = false
            window.alphaValue = 0
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
        }
    }
}
```

**注意**: 初始版本通过 styleMask 判断窗口，可能误隐藏 StatusItem 窗口。后改为通过窗口标题 `"CodexBarLifecycleKeepalive"` 精确识别。

## 修改的文件

- `Sources/CodexBar/HiddenWindowView.swift` - 移除打开系统偏好设置的代码
- `Sources/CodexBar/PreferencesView.swift` - 使用 frame 约束
- `Sources/CodexBar/CodexbarApp.swift` - 在 AppDelegate 中添加隐藏窗口代码

## 验证方式

- 构建成功: `swift build` 编译通过
- 应用启动后不应显示小窗口
- 点击 Settings... 不再打开 macOS 系统偏好设置
- Settings 窗口尺寸应为 496x580 (默认) 或 720x580 (Providers 标签页)

## 提交记录

- `c7500ee` - Fix Settings window size for macOS 12 compatibility
- `1d1321e` - Fix Settings opening system preferences and window size
- 新提交 - Hide lifecycle window on app launch in AppDelegate
