# Session Memo: Swift 5.7 Downgrade Progress

## Date: 2026-02-25
## Time: 15:02 UTC
## Agent: claude-code-guide

## Summary

继续将 CodexBar 项目从 Swift 6.x 降级到 Swift 5.7 以兼容 Xcode 14。

## Progress Made

### Fixed Issues (相对于之前的 ~4300 错误):

1. **SettingsStore.swift** - 修复 switch 表达式中的隐式返回问题
2. **SettingsStore+ConfigPersistence.swift** - 修复 shouldBroadcast getter
3. **PreferencesDebugPane.swift** - 修复 SettingsSection 调用语法
4. **UsageStore.swift** - 修复 SessionQuotaNotifier 懒加载问题
5. **CostHistoryChartMenuView.swift** - 修复 if 表达式返回问题
6. **CreditsHistoryChartMenuView.swift** - 修复 if 表达式返回问题
7. **IconView.swift** - 修复 onChange modifier (Swift 6 -> 5.7)
8. **MenuDescriptor.swift** - 修复多处 switch 表达式
9. **StatusItemController+Actions.swift** - 修复多处 switch 表达式和 actor 隔离
10. **StatusItemController+Menu.swift** - 修复可选类型解包
11. **StatusItemController+SwitcherViews.swift** - 修复 if 表达式
12. **IconRenderer.swift** - 修复 switch 表达式
13. **MenuCardView.swift** - 修复 switch 表达式
14. **MiniMaxAPITokenStore.swift** - 修复 switch 表达式
15. **MiniMaxCookieStore.swift** - 修复 switch 表达式
16. **SyntheticTokenStore.swift** - 修复 switch 表达式
17. **UsageBreakdownChartMenuView.swift** - 修复 if 表达式
18. **UsageProgressBar.swift** - 修复 if 表达式

### 创建的兼容层:

- **SweetCookieKitCompat.swift** - 为 Swift 5.7 创建了 SweetCookieKit 的 stub 实现

## Current Status

- **CodexBarCore**: 编译成功
- **CodexBar**: 使用 `-strict-concurrency=minimal` 标志后仍有约 61 种唯一错误类型

### 剩余错误分类:

1. **Actor 隔离错误 (主要)** - 在 async 函数中访问 @MainActor 隔离的属性
   - 位置: UsageStore.swift, UsageStore+Refresh.swift, UsageStore+TokenAccounts.swift
   - 这是 Swift 6 严格并发检查与 Swift 5.7 的根本差异

2. **Swift 6 语法残留** - 一些 if/switch 表达式
   - 位置: Chart 相关视图

3. **未初始化常量** - 一些 Swift 6 的变量声明语法

## 使用的编译标志

```bash
swift build -Xswiftc -strict-concurrency=minimal
```

## 下一步建议

1. 要完全解决 actor 隔离错误，需要大量重构 async/await 代码
2. 考虑使用 Xcode 15+ (Swift 5.9+) 以避免这些并发问题
3. 或者继续逐个修复剩余的语法问题
