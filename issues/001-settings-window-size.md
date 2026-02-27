# Issue #1: Settings 窗口尺寸过小

## 问题描述

应用运行后，点击 Settings... 弹出的窗口非常小。

## 根本原因

- SwiftUI 的 `Settings` 场景在 macOS 12 上不会自动使用内容视图的 frame 大小
- 原代码使用 `.frame(width:height:)` 设置固定尺寸，但在 Settings 场景中此方式不生效
- macOS 13+ 可以使用 `.windowResizability(.contentSize)`，但项目目标是 macOS 12

## 解决方案

修改 `Sources/CodexBar/PreferencesView.swift` 第 64 行:

```swift
// 之前 (不生效)
.frame(width: self.contentWidth, height: self.contentHeight)

// 之后 (正确)
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

- `Sources/CodexBar/PreferencesView.swift` (第 64 行)

## 验证方式

- 构建成功: `swift build` 编译通过
- 窗口尺寸: 默认 496x580，Providers 标签页 720x580

## 提交记录

- `c7500ee` - Fix Settings window size for macOS 12 compatibility
