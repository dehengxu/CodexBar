# CodexBar CLI 需求文档

## 概述

CodexBar CLI 是一个跨平台的命令行工具，用于监控多个 AI Provider 的使用量。

## 功能需求

### 1. usage 命令

**描述**: 获取并显示各 Provider 的使用量

**参数**:
| 参数 | 简写 | 默认值 | 说明 |
|------|------|--------|------|
| `--format` | `-f` | text | 输出格式 (text, json) |
| `--json` | `-j` | false | 输出 JSON 格式 |
| `--verbose` | `-v` | false | 详细输出 |
| `--log-level` | - | error | 日志级别 (debug, info, warning, error) |

**示例**:
```bash
codexbar usage                    # 文本格式显示使用量
codexbar usage --json            # JSON 格式显示
codexbar usage -v --log-level debug  # 详细日志
```

### 2. cost 命令

**描述**: 获取并显示本地成本使用量（通过扫描日志文件）

**参数**:
| 参数 | 简写 | 默认值 | 说明 |
|------|------|--------|------|
| `--format` | `-f` | text | 输出格式 |
| `--json` | `-j` | false | 输出 JSON |
| `--verbose` | `-v` | false | 详细输出 |

**示例**:
```bash
codexbar cost                    # 文本格式显示成本
codexbar cost --json             # JSON 格式显示
```

### 3. config 命令

**描述**: 配置文件操作

**子命令**:

#### 3.1 config validate

**描述**: 验证配置文件

**示例**:
```bash
codexbar config validate         # 验证配置文件
```

#### 3.2 config dump

**描述**: 输出规范化的配置 JSON

**示例**:
```bash
codexbar config dump            # 输出配置 JSON
```

## 技术实现

### 依赖

- **CodexBarCore**: 核心逻辑库（跨平台）
- 无外部 CLI 框架依赖（使用手动解析）

### 平台支持

- macOS 12+
- Linux (已验证)
- Windows (理论上支持)

### Swift 版本

- Swift 5.7+

## 现有文件结构

```
Sources/CodexBarCLI/
└── CLIEntry.swift          # CLI 入口（单一文件实现）
```

## 实现状态

| 功能 | 状态 | 说明 |
|------|------|------|
| usage 命令 | TODO | 需集成 CodexBarCore 使用量获取逻辑 |
| cost 命令 | TODO | 需集成 CodexBarCore 成本计算逻辑 |
| config validate | TODO | 需实现配置文件验证 |
| config dump | TODO | 需实现配置导出 |
| --help/-h | DONE | 显示帮助信息 |
| --version/-V | TODO | 显示版本信息 |

## 未来扩展

- [ ] 添加更多 Provider 支持
- [ ] 添加交互式 TUI 界面
- [ ] 添加使用量告警功能
- [ ] 支持配置文件热重载
