# Issue #5: ARK / Bailian resets 时间计算

## 问题描述

当 ARK / Bailian API 返回的 reset timestamp 是过去的时间（比如已经过了刷新时间），UI 显示的是 "Resets now"，而不是下一个重置时间。

## 根本原因

在 `UsageFormatter.resetCountdownDescription` 中：
```swift
let seconds = max(0, date.timeIntervalSince(now))
if seconds < 1 { return "now" }
```

当 API 返回的 reset timestamp 是过去的时间时，会返回 "now"。

## 解决方案

修改 `ArkUsageStats.swift` 和 `BailianUsageStats.swift`，添加 `resolveResetTime` 方法：
1. 如果 API 提供的时间在未来，使用它
2. 如果 API 提供的时间是过去的或为 nil，计算下一个重置时间

### 计算逻辑
- **Session**: 当前时间 + 5 小时
- **Weekly**: 当前/下周周日 23:59:59
- **Monthly**: 当前/下月最后一天 23:59:59

## 修改的文件

- `Sources/CodexBarCore/Providers/Ark/ArkUsageStats.swift`
- `Sources/CodexBarCore/Providers/Bailian/BailianUsageStats.swift`

## 验证方式

- 构建成功: `swift build` 编译通过
- 当 API 返回的 reset timestamp 是过去的时间时，应显示下一个重置时间
- Session 应显示 "Resets in 5h" 或具体时间
- Weekly 应显示本周/下周剩余时间
- Monthly 应显示本月/下月剩余时间
