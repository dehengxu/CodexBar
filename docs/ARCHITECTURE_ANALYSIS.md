# CodexBar CLI 架构分析

## 1. 设计目标与用途

### 1.1 核心定位
CodexBar CLI 是一个轻量级的命令行工具，设计用于：

- **无 UI 场景**：在脚本、CI/CD、仪表盘等自动化场景中获取 AI 用量数据
- **数据导出**：支持机器可读的 JSON 格式输出，方便集成到其他系统
- **跨平台支持**：同时支持 macOS 和 Linux 平台
- **配置复用**：与桌面应用共享配置文件 (`~/.codexbar/config.json`)

### 1.2 与桌面应用的关系
```
┌─────────────────┐     ┌─────────────────┐
│   CodexBar App  │     │  CodexBar CLI   │
│   (SwiftUI GUI) │     │  (Command Line) │
└────────┬────────┘     └────────┬────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │    CodexBarCore       │
         │  (Shared Core Logic)  │
         └───────────┬───────────┘
                     │
         ┌───────────▼───────────┐
         │   AI Provider APIs    │
         │ (Claude/Codex/etc.)   │
         └───────────────────────┘
```

## 2. 支持的 Providers

CLI 支持 20+ 个 AI Provider，按类型分类：

### 2.1 主要 Provider（默认启用）
| Provider | ID | 说明 |
|---------|-----|------|
| Codex | `codex` | OpenAI Codex CLI |
| Claude | `claude` | Anthropic Claude Code |

### 2.2 IDE/编辑器集成
| Provider | ID | 说明 |
|---------|-----|------|
| Cursor | `cursor` | Cursor IDE |
| GitHub Copilot | `copilot` | GitHub Copilot |
| JetBrains AI | `jetbrains` | JetBrains 系列 IDE |

### 2.3 独立 AI 服务
| Provider | ID | 说明 |
|---------|-----|------|
| Google Gemini | `gemini` | Google Gemini API |
| OpenCode | `opencode` | OpenCode |
| Factory | `factory` | Factory AI |
| Antigravity | `antigravity` | Antigravity |
| z.ai | `zai` | z.ai 平台 |
| MiniMax | `minimax` | MiniMax |
| Kimi | `kimi` | Moonshot Kimi |
| Kimi K2 | `kimik2` | Kimi K2 模型 |
| Kiro | `kiro` | Kiro |
| Vertex AI | `vertexai` | Google Vertex AI |
| Augment | `augment` | Augment Code |
| Amp | `amp` | Amp |
| Ollama | `ollama` | Ollama 本地模型 |
| Synthetic | `synthetic` | Synthetic |
| Warp | `warp` | Warp Terminal |
| OpenRouter | `openrouter` | OpenRouter |

## 3. 命令结构

### 3.1 命令体系
```
codexbar [command] [options]

Commands:
  usage (default)    获取用量信息
  cost               获取本地成本使用量
  config             配置相关操作
    ├─ validate      验证配置文件
    └─ dump          输出配置 JSON
```

### 3.2 全局选项
| 选项 | 简写 | 说明 |
|-----|------|------|
| `--verbose` | `-v` | 详细输出 |
| `--format` | `-f` | 输出格式 (text/json) |
| `--json` | `-j` | 简写为 `--format json` |
| `--json-only` | - | 仅输出 JSON |
| `--pretty` | - | 美化 JSON 输出 |
| `--no-color` | - | 禁用 ANSI 颜色 |
| `--log-level` | - | 日志级别设置 |
| `--help` | `-h` | 显示帮助 |
| `--version` | `-V` | 显示版本 |

### 3.3 Provider 选项
| 选项 | 说明 |
|-----|------|
| `--provider <id>` / `-p <id>` | 指定 provider (支持 both/all) |
| `--account <label>` | 指定账户标签 |
| `--account-index <n>` | 按索引选择账户 (1-based) |
| `--all-accounts` | 获取所有账户 |

### 3.4 数据源选项（macOS only）
| 选项 | 说明 |
|-----|------|
| `--source <mode>` | 数据源模式 (auto/web/cli/oauth/api) |
| `--web` | 简写为 `--source web` |
| `--web-timeout <seconds>` | Web 请求超时 |

## 4. 架构实现分析

### 4.1 当前实现（feat/5-cli 分支）

#### 文件结构
```
Sources/CodexBarCLI/
└── CLIEntry.swift          # 单一文件实现所有 CLI 功能
```

#### 参数解析方式
采用**手动参数解析**而非第三方框架：
```swift
// 手动解析参数
while i < argv.count {
    let arg = argv[i]
    switch arg {
    case "--provider", "-p":
        // 处理 provider 选项
    case "-f", "--format":
        // 处理 format 选项
    // ...
    }
}
```

**原因**：
- Commander 框架需要 Swift 6.2+
- swift-argument-parser 也有版本限制
- 为保持 Swift 5.7 兼容性，选择原生实现

#### 并发处理
使用 `DispatchSemaphore` 实现同步等待：
```swift
let semaphore = DispatchSemaphore(value: 0)
Task {
    let result = await runUsageAsync(...)
    semaphore.signal()
}
semaphore.wait()
```

### 4.2 数据流设计

```
CLI Entry
    │
    ├─→ parse arguments (手动解析)
    │
    ├─→ bootstrap logging
    │
    ├─→ UsageFetcher/CostUsageFetcher (CodexBarCore)
    │       │
    │       └─→ Provider-specific fetchers
    │               │
    │               └─→ External APIs
    │
    └─→ format output (text/json)
```

### 4.3 输出格式设计

#### 文本格式
适合终端查看，包含：
- 用量百分比条
- 重置时间
- 账户信息
- 计划类型

#### JSON 格式
适合机器处理，结构：
```json
{
  "provider": "claude",
  "usedPercent": 12.5,
  "resetsAt": "2026-02-28T18:00:00Z",
  "accountEmail": "user@example.com",
  "updatedAt": "2026-02-28T12:00:00Z"
}
```

## 5. 当前限制与问题

### 5.1 Provider 选择未完全实现
**问题**：虽然解析了 `--provider` 选项，但实际查询时未按 provider 过滤。

**当前行为**：
```bash
codexbar --provider claude
# 实际：仍然尝试查询所有 providers（包括 Codex）
```

**原因**：`runUsageAsync` 直接调用 `fetcher.loadLatestUsage()`，未使用 provider 参数。

### 5.2 错误处理
当某个 provider 失败时（如 Codex 未安装），会显示错误但仍继续执行。

### 5.3 功能对比
| 功能 | main 分支 (Commander) | feat/5-cli (手动实现) |
|-----|----------------------|----------------------|
| 参数解析 | 完整支持 | 基础支持 |
| Provider 过滤 | 完整支持 | 未实现 |
| 多账户支持 | 完整支持 | 解析但未使用 |
| 数据源选择 | 完整支持 | 解析但未使用 |
| Token 账户 | 完整支持 | 未实现 |
| 状态页面 | 支持 | 未实现 |
| Debug 选项 | 完整 | 部分 |

## 6. 改进建议

### 6.1 短期修复
1. **实现 Provider 过滤**
   ```swift
   func runUsageAsync(provider: ProviderSelection, ...) async -> Bool {
       let providers = provider.asList
       for p in providers {
           // 按 provider 查询
       }
   }
   ```

2. **错误隔离**
   - 单个 provider 失败不应影响其他 provider
   - 提供 `--continue-on-error` 选项

### 6.2 中期改进
1. **重构为多文件结构**
   ```
   Sources/CodexBarCLI/
   ├── CLIEntry.swift          # 入口点
   ├── Commands/
   │   ├── UsageCommand.swift  # usage 命令
   │   ├── CostCommand.swift   # cost 命令
   │   └── ConfigCommand.swift # config 命令
   ├── Options/
   │   ├── UsageOptions.swift
   │   └── GlobalOptions.swift
   └── Utils/
       ├── Renderer.swift      # 输出格式化
       └── Payloads.swift      # 数据结构
   ```

2. **统一错误处理**
   - 定义标准错误类型
   - 统一错误码（参考 main 分支）
   - 支持 `--json-only` 时的错误 JSON 输出

### 6.3 长期规划
1. **考虑迁移到 swift-argument-parser**
   - 当项目升级到 Swift 6.2+ 时
   - 获得更好的类型安全和文档生成

2. **插件化 Provider 支持**
   - 允许动态添加新的 provider
   - 统一的 provider 接口

## 7. 使用示例

### 7.1 基础用法
```bash
# 查看所有启用的 providers
codexbar

# 查看特定 provider
codexbar --provider claude
codexbar -p codex

# 查看主要 providers
codexbar --provider both

# 查看所有 providers
codexbar --provider all
```

### 7.2 输出格式
```bash
# JSON 输出
codexbar --json
codexbar --format json --pretty

# 仅 JSON（无错误文本）
codexbar --json-only --pretty
```

### 7.3 成本查询
```bash
# 本地成本统计
codexbar cost
codexbar cost --refresh  # 强制刷新缓存
```

### 7.4 配置管理
```bash
# 验证配置
codexbar config validate

# 查看配置
codexbar config dump --pretty
```

## 8. 相关文件

- `Sources/CodexBarCLI/CLIEntry.swift` - CLI 实现
- `Sources/CodexBarCore/UsageFetcher.swift` - 用量获取核心
- `Sources/CodexBarCore/CostUsageFetcher.swift` - 成本获取核心
- `Sources/CodexBarCore/Providers/` - Provider 实现
- `docs/cli.md` - CLI 完整文档
- `docs/configuration.md` - 配置文档

## 9. 结论

当前 feat/5-cli 分支的 CLI 是一个**功能简化但可用**的实现，主要限制在于：

1. **Provider 过滤未完全实现** - 需要修复以支持 `--provider` 选项
2. **手动参数解析** - 为了 Swift 5.7 兼容性而做的权衡
3. **单文件结构** - 适合当前规模，但随功能增加需要重构

建议优先级：
1. 🔴 高：实现 Provider 过滤功能
2. 🟡 中：完善错误处理和退出码
3. 🟢 低：代码结构重构
