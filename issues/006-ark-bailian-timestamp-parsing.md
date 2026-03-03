# Issue #6: ARK / Bailian ResetTimestamp 显示1970年时间

## 问题描述

当ARK或Bailian API返回的ResetTimestamp时间戳显示为1970年时，说明时间戳解析逻辑存在问题。

## 根本原因

时间戳解析逻辑不够健壮，只处理了秒和毫秒两种格式，缺少对以下情况的处理：
1. **微秒级时间戳**（16位数字）
2. **无效值检查**（0或负数）
3. **边界条件**（过小的值）

原有代码（`ArkUsageStats.swift` 和 `BailianUsageStats.swift`）：

```swift
if let ts = self.ResetTimestamp {
    if ts > 1_000_000_000_000 {
        // Millisecond timestamp
        resetTime = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
    } else if ts > 1_000_000_000 {
        // Second timestamp
        resetTime = Date(timeIntervalSince1970: TimeInterval(ts))
    } else {
        resetTime = nil
    }
}
```

### 问题分析

| 时间戳类型 | 位数 | 示例值 | 原逻辑处理 | 结果 |
|-----------|------|--------|-----------|------|
| 微秒 | 16位 | 1772523397876000 | 当作毫秒 | 除以1000后仍是毫秒，错误 |
| 毫秒 | 13位 | 1772523397876 | 正确 | 正确 |
| 秒 | 10位 | 1772523397 | 正确 | 正确 |
| 无效 | < 10位 | 0, 123 | nil | 正确 |

如果API返回微秒时间戳，会被错误当作毫秒处理，导致除以1000后得到一个很大的毫秒值，Date会将其当作秒来处理，最终得到错误的日期。

## 解决方案

改进时间戳解析逻辑，添加微秒支持和更健壮的边界检查：

```swift
if let ts = self.ResetTimestamp, ts > 0 {
    if ts > 1_000_000_000_000_000 {
        // Microsecond timestamp (16 digits)
        resetTime = Date(timeIntervalSince1970: TimeInterval(ts) / 1_000_000)
    } else if ts > 1_000_000_000_000 {
        // Millisecond timestamp (13 digits)
        resetTime = Date(timeIntervalSince1970: TimeInterval(ts) / 1000)
    } else if ts > 1_000_000_000 {
        // Second timestamp (10 digits)
        resetTime = Date(timeIntervalSince1970: TimeInterval(ts))
    } else {
        // Timestamp too small, likely invalid data
        resetTime = nil
    }
} else {
    resetTime = nil
}
```

### 改进点

1. **添加微秒检测**：`ts > 1_000_000_000_000_000`，除以1_000_000
2. **明确排除无效值**：`ts > 0` 确保不处理0和负数
3. **更清晰的注释**：标注每种格式的位数

## 修改的文件

- `Sources/CodexBarCore/Providers/Ark/ArkUsageStats.swift`
  - `ArkQuotaUsageItem.toLimitEntry()` 方法

- `Sources/CodexBarCore/Providers/Bailian/BailianUsageStats.swift`
  - `BailianQuotaInfo.toLimitEntry()` 方法

## 验证方式

```bash
# 编译验证
swift build

# 或使用项目脚本
./Scripts/compile_and_run.sh
```

编译成功，无新增错误或警告。

## 预期效果

- 微秒级时间戳（16位）能正确解析
- 毫秒级时间戳（13位）继续正常工作
- 秒级时间戳（10位）继续正常工作
- 无效值（0、负数、过小值）返回nil，触发fallback计算逻辑
