# CLI 重构文档

## 概述

本文档记录了 CodexBarCLI 的重构过程，包括模块化改造、错误处理优化以及与 config.json 的集成。

## 重构历史

### 2024-xx-xx: 初始 CLI 实现

- 使用手动参数解析（因 Commander 需要 Swift 6.2+）
- 单文件实现 CLIEntry.swift
- 支持 usage、cost、config 命令

### 2024-xx-xx: Task #1 - Provider 过滤功能

- 实现 `--provider` / `-p` 选项
- 支持 `claude` / `codex` / `both` / `all` 参数
- 使用 `ProviderDescriptorRegistry` 正确过滤 providers
- 添加标准退出码 (0-5)

### 2024-xx-xx: Task #2 - 代码结构重构

将 915 行的单文件拆分为模块化结构：

```
Sources/CodexBarCLI/
├── CLIEntry.swift           # 主入口 (~60 行)
├── Options/                  # 选项解析
│   ├── GlobalOptions.swift  # 全局选项、退出码、ProviderSelection
│   ├── UsageOptions.swift   # Usage 命令选项解析
│   └── CostOptions.swift    # Cost 命令选项解析
├── Commands/                 # 命令实现
│   ├── UsageCommand.swift   # Usage 命令实现
│   ├── CostCommand.swift    # Cost 命令实现
│   └── ConfigCommand.swift  # Config 命令实现
└── Utils/                    # 工具模块
    ├── Help.swift           # 帮助和版本输出
    ├── Payloads.swift       # 数据载荷结构
    ├── Renderer.swift       # 输出渲染 (text/json)
    └── CLIError.swift       # 错误处理
```

### 2024-xx-xx: Task #3 - 错误处理和退出码

- 添加 `CLIError` 枚举：providerNotFound、configError、parseError、timeout、generalError
- 退出码定义：
  - 0 = 成功
  - 1 = 通用错误
  - 2 = Provider 未找到
  - 3 = 解析错误
  - 4 = 超时
  - 5 = 配置错误
- 添加辅助函数：`handleError()`、`exitWithError()`
- 无效参数警告提示

### 2024-xx-xx: Task #4 - Config 集成

#### 背景

用户指出原有逻辑存在问题：CLI 应当读取 config.json 中 `enabled: true` 的 providers 进行查询，而非硬编码的默认逻辑。

#### 解决方案

1. **Provider 选择优先级**：
   - 用户通过 `--provider` 指定 → 使用指定值
   - 用户指定但被 disabled → 显示警告
   - 未指定 `--provider` → 使用 `config.enabledProviders()`
   - 无配置或配置为空 → 回退到默认逻辑（`.both`）

2. **新增 `list` 子命令**：
   ```
   codexbar list [--format text|json]
   ```
   - 输出所有支持的 provider id
   - 显示每个 provider 的 enabled 状态
   - 支持 text 和 JSON 输出格式

#### 修改文件

| 文件 | 修改内容 |
|------|----------|
| `UsageCommand.swift` | 加载 config，检查 provider enabled 状态 |
| `CostCommand.swift` | 加载 config，检查 provider enabled 状态 |
| `ListCommand.swift` | **新增** - 列举所有 providers |
| `CLIEntry.swift` | 添加 list 命令路由 |
| `Help.swift` | 添加 list 命令帮助 |

## 使用示例

```bash
# 列出所有 providers 及状态
codexbar list
codexbar list --json

# 查询 usage（使用 config 中 enabled 的 providers）
codexbar usage

# 指定 provider 查询
codexbar usage --provider claude
codexbar cost --provider codex

# 查看帮助
codexbar --help
codexbar --help list
codexbar usage --help
```

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     CLIEntry.swift                          │
│                  (命令路由入口)                              │
└─────────────────┬───────────────────────────────────────────┘
                  │
      ┌───────────┼───────────┬─────────────┐
      ▼           ▼           ▼             ▼
┌─────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐
│ Usage   │ │ Cost    │ │ Config   │ │ List     │
│Command  │ │Command  │ │Command   │ │Command   │
└────┬────┘ └────┬────┘ └────┬─────┘ └────┬─────┘
     │           │            │            │
     └───────────┴─────┬──────┴────────────┘
                       │
                       ▼
          ┌────────────────────────┐
          │   CodexBarConfigStore │
          │  (读取 config.json)    │
          └──────────┬───────────┘
                     │
                     ▼
          ┌────────────────────────┐
          │  CodexBarConfig       │
          │  .enabledProviders()  │
          └────────────────────────┘
```

## 测试

```bash
# 基本功能测试
bash scripts/test_cli.sh

# 错误处理测试
bash scripts/test_cli_errors.sh

# 手动验证
.build/debug/CodexBarCLI list
.build/debug/CodexBarCLI list --json
.build/debug/CodexBarCLI usage --provider claude
```

## 未来改进

- [ ] 添加配置文件生成命令
- [ ] 支持 `--account` 和 `--account-index` 从 config 读取
- [ ] 添加 config 编辑命令
- [ ] 完善单元测试覆盖
