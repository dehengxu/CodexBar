# Issue #1: Settings 窗口 + 启动时显示小窗口

## 问题描述

1. 点击 Settings... 后弹出的小窗口
2. 同时还打开了 macOS 系统偏好设置界面
3. 应用启动后显示小窗口
4. 点击 Settings 没有显示任何窗口
5. **修复后应用崩溃** - 启动时崩溃

## 根本原因

### 问题 1: 打开 macOS 系统偏好设置
在 `Sources/CodexBar/HiddenWindowView.swift` 中，代码监听 `codexbarOpenSettings` 通知后打开系统偏好设置。

### 问题 2: Settings 窗口尺寸过小
SwiftUI 的 `Settings` 场景在 macOS 12 上不会自动使用内容视图的 frame 大小。

### 问题 3: 应用启动时显示小窗口
HiddenWindowView 的 `.onAppear` 在 SwiftUI App 启动时没有正确隐藏窗口。

### 问题 4: 点击 Settings 没有显示窗口
`StatusItemController.openSettings` 方法发送通知但没有处理程序来打开 SwiftUI Settings 窗口。

### 问题 5: 修复后应用崩溃
`HiddenWindowView` 中的异步窗口隐藏导致崩溃。`hideWindow()` 方法内部使用 `DispatchQueue.main.async` 异步执行，导致在窗口视图还没完全初始化时就尝试修改其 styleMask。

## 解决方案

### 修复 1: 移除打开系统偏好设置的代码
修改 `Sources/CodexBar/HiddenWindowView.swift`

### 修复 2: 使用 frame 约束
修改 `Sources/CodexBar/PreferencesView.swift` 第 64 行

### 修复 3: 在 AppDelegate 中隐藏窗口
修改 `Sources/CodexBar/CodexbarApp.swift`

### 修复 4: 修复 Settings 窗口不显示
修改 `Sources/CodexBar/StatusItemController+Actions.swift`

### 修复 5: 修复应用崩溃
修改 `Sources/CodexBar/HiddenWindowView.swift` - 将异步调用改为同步执行：

```swift
// 之前 (崩溃)
.onAppear {
    hideWindow()  // 内部使用 DispatchQueue.main.async
}

// 之后 (修复)
.onAppear {
    if let window = NSApp.windows.first(where: { $0.title == "CodexBarLifecycleKeepalive" }) {
        // 直接同步执行所有窗口配置
        window.styleMask = [.borderless]
        window.collectionBehavior = [...]
        // ... 其他配置
        window.orderOut(nil)
    }
}
```

## 修改的文件

- `Sources/CodexBar/HiddenWindowView.swift`
- `Sources/CodexBar/PreferencesView.swift`
- `Sources/CodexBar/CodexbarApp.swift`
- `Sources/CodexBar/StatusItemController+Actions.swift`

## 验证方式

- 构建成功: `swift build` 编译通过
- 应用启动后不显示小窗口
- 状态栏图标正常显示
- 点击 Settings... 显示正确的设置窗口 (496x580)

## 提交记录

- `c7500ee` - Fix Settings window size for macOS 12 compatibility
- `1d1321e` - Fix Settings opening system preferences and window size
- `2b477d9` - Fix StatusItem visibility by using window title
- `d3948fd` - Improve HiddenWindowView to ensure window stays hidden
- `e1325d6` - Fix Settings window not opening
- 新提交 - Fix app crash by using synchronous window hide
