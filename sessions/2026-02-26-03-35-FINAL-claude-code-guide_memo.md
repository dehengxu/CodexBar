# Session Memo: Swift 5.7 Downgrade - Final Summary

## Date: 2026-02-26
## Agent: claude-code-guide

## Summary

继续将 CodexBar 项目从 Swift 6.x 降级到 Swift 5.7 以兼容 Xcode 14。

## Error Reduction Progress

| 阶段 | 总错误行数 | 唯一错误类型 |
|------|------------|--------------|
| 起始 | ~4300 | ~4300 |
| 中期 | ~637 | ~61 |
| 最终 | 113 | 28 |

## Fixed Issues

1. **@Observable -> ObservableObject**: 迁移了多个类
2. **@Bindable -> @ObservedObject**: 修复了 SwiftUI 绑定
3. **SweetCookieKit 兼容层**: 创建了完整的 stub 实现
4. **Swift 6 语法**: 修复了大量 switch/if 表达式
5. **onChange modifier**: 适配 Swift 5.7 API
6. **多个视图文件**: 修复了各种 Swift 6 语法残留

## Remaining Issues

### Actor 隔离错误 (27 个实例)

这是 Swift 6 严格并发模型与 Swift 5.7 的根本差异:

```swift
@MainActor
class UsageStore: ObservableObject {
    @Published var errors: [UsageProvider: String] = [:]
}

// 错误: actor-isolated property 'errors' cannot be passed 'inout' to 'async' function call
func refresh() async {
    self.errors[provider] = error  // 在 async 函数中访问
}
```

### 解决方案选项

1. **使用 Xcode 15+ (Swift 5.9+)**: 完全兼容
2. **大量重构**: 将 async 函数改为在 MainActor 上下文中运行
3. **移除 @MainActor**: 但会导致更多运行时问题

## 结论

项目已经进行了最大程度的 Swift 5.7 兼容性适配，但 Actor 隔离错误是 Swift 版本之间的根本性差异，无法通过简单修复解决。建议:

1. 使用 Xcode 15+ (Swift 5.9+) 编译此项目
2. 或者接受 Xcode 14.2 无法完全编译此项目的现状
