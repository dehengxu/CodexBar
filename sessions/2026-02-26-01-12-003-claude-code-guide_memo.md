# Session Memo: Swift 5.7 Downgrade Progress - Update 3

## Date: 2026-02-26
## Time: 01:12 UTC
## Agent: claude-code-guide

## Summary

继续将 CodexBar 项目从 Swift 6.x 降级到 Swift 5.7 以兼容 Xcode 14。

## Additional Fixes Made

1. **UsageStore.swift** - 修复 if/switch 表达式
2. **UsageBreakdownChartMenuView.swift** - 修复方法中的 Swift 6 语法
3. **UpdateChannel.swift** - 修复 switch 表达式
4. **ZaiTokenStore.swift** - 修复 switch 表达式
5. **UsageStore+Status.swift** - 修复 switch 表达式
6. **PreferencesDebugPane.swift** - 简化 VStack 替代 SettingsSection

## Error Reduction Progress

| 阶段 | 错误数量 |
|------|----------|
| 起始 | ~4300 |
| 中期 (strict-concurrency=minimal) | ~61 类型 |
| 当前 (strict-concurrency=minimal) | ~32 类型 |
| 无标志 | 637 |

## 剩余问题分析

### Actor 隔离错误 (约 28 个实例)

这是 Swift 6 严格并发模型与 Swift 5.7 的根本差异:

```swift
@MainActor
class UsageStore: ObservableObject {
    @Published var errors: [UsageProvider: String] = [:]
    // 这些属性在 async 函数中访问时...
}

// 使用处:
func refresh() async {
    // 错误: actor-isolated property 'errors' cannot be passed 'inout' to 'async' function call
    self.errors[provider] = error
}
```

**解决方案选项:**
1. 大规模重构 async/await 代码
2. 使用 Xcode 15+ (Swift 5.9+)
3. 移除 @MainActor (会导致更多问题)

### 其他错误

- PreferencesDebugPane.swift: SettingsSection 调用
- WebView delegate 方法签名

## 结论

代码已经进行了大量修复，但 Actor 隔离错误是 Swift 6 与 Swift 5.7 之间的根本性差异，需要显著重构代码才能完全解决。
