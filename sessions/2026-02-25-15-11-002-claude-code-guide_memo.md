# Session Memo: Swift 5.7 Downgrade Progress - Update 2

## Date: 2026-02-25
## Time: 15:11 UTC
## Agent: claude-code-guide

## Summary

继续将 CodexBar 项目从 Swift 6.x 降级到 Swift 5.7 以兼容 Xcode 14。

## Additional Fixes Made

1. **UsageProgressBar.swift** - 修复 if 表达式在 ViewBuilder 中的使用
2. **StatusItemController+SwitcherViews.swift** - 修复 finalWidth 变量初始化
3. **CodexLoginRunner.swift** - 修复 merged 变量初始化
4. **CostHistoryChartMenuView.swift** - 简化 selectionBandRect 方法 (Swift Charts API 兼容)
5. **CreditsHistoryChartMenuView.swift** - 简化 selectionBandRect 方法
6. **UsageBreakdownChartMenuView.swift** - 简化 selectionBandRect 方法
7. **UpdateChannel.swift** - 修复多处 switch 表达式
8. **ZaiTokenStore.swift** - 修复 switch 表达式
9. **UsageStore+Status.swift** - 修复 switch 表达式

## Current Status

- **CodexBarCore**: 编译成功
- **CodexBar**: 仍有约 33 种唯一错误类型

### 错误分类:

1. **Actor 隔离错误 (主要)** - 约 25+ 个实例
   - 在 async 函数中访问 @MainActor 隔离的属性
   - 这是 Swift 6 严格并发模型与 Swift 5.7 的根本差异

2. **其他错误** - 约 8 种
   - PreferencesDebugPane.swift: SettingsSection 调用问题
   - UsageStore.swift: 一些类型推断问题

## 下一步建议

1. Actor 隔离错误需要大量重构 async/await 代码
2. 考虑使用 Xcode 15+ (Swift 5.9+) 以避免这些并发问题
3. 或者继续逐个修复剩余的语法问题
