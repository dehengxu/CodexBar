# 构建脚本优化：图标修复与 DMG 内部 app 名称简化

## 问题描述

### 问题 1: 应用图标显示异常
- **现象**: 构建的 CodexBar.app 图标显示为白色方形，而非 macOS 标准的圆角透明图标
- **原因**:
  1. `build.sh` 只检查 `Icon.iconset` 目录，但项目实际使用 `Icon.icns` 文件
  2. `Info.plist` 中 `CFBundleIconFile` 为空，系统无法找到图标

### 问题 2: DMG 内部 app 名称冗余
- **现象**: DMG 中的 app 文件名包含版本和架构信息（如 `CodexBar-0.18.1-s5-macos-x86_64.app`）
- **期望**: DMG 中的 app 应使用简洁名称 `CodexBar.app`，仅 DMG 文件名保留版本信息

## 解决方案

### 1. 修复图标问题

#### Scripts/build.sh
```bash
# 第 304-310 行：添加对 Icon.icns 文件的支持
if [[ -f "${ROOT_DIR}/Icon.icns" ]]; then
    cp "${ROOT_DIR}/Icon.icns" "${app_bundle}/Contents/Resources/AppIcon.icns"
    echo "   - AppIcon.icns 已复制"
elif [[ -d "${ROOT_DIR}/Icon.iconset" ]]; then
    iconutil --convert icns --output "${app_bundle}/Contents/Resources/AppIcon.icns" "${ROOT_DIR}/Icon.iconset" 2>/dev/null || true
    echo "   - AppIcon.icns 已从 Icon.iconset 生成"
fi
```

#### Sources/CodexBar/Info.plist
```xml
<!-- 第 9-10 行：设置图标文件名 -->
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

### 2. 优化 DMG 内部 app 名称

#### Scripts/build.sh

**build_app 函数** (第 235-248 行)：
- 添加可选参数 `simple_name`
- 当 `simple_name=1` 时使用 `CodexBar.app` 作为名称

```bash
# 生成 .app 包
# 参数: conf, arch, [simple_name]
# simple_name: 如果为 1，则使用 CodexBar.app 作为名称（用于 DMG）
build_app() {
    local conf="$1"
    local arch="$2"
    local simple_name="${3:-0}"
    local config_upper=$(printf "%s" "$conf" | tr '[:lower:]' '[:upper:]')
    local app_name
    if [[ "$simple_name" == "1" ]]; then
        app_name="CodexBar.app"
    else
        app_name=$(generate_product_name "CodexBar" "app")
    fi
    # ...
}
```

**build_dmg 函数** (第 368-372 行)：
- 调用 `build_app` 时传递 `"1"` 使用简单名称
- 更新 app 路径为 `CodexBar.app`

```bash
# 1. 先构建 .app（使用简单名称 CodexBar.app）
build_app "${conf}" "${arch}" "1"

# 2. 创建 DMG
local app_bundle="${ROOT_DIR}/CodexBar.app"
```

## 效果对比

### 图标修复
| 项目 | 修复前 | 修复后 |
|------|--------|--------|
| 图标形状 | 白色方形 | 圆角矩形 |
| 背景 | 白色 | 透明 |
| 透明通道 | 无 (Icon-classic.icns) | 有 (Icon.icns) |

### DMG 内部 app 名称
| 构建命令 | 修复前 | 修复后 |
|----------|--------|--------|
| `./build.sh dmg release` | `CodexBar-0.18.1-s5-macos-x86_64.app` | `CodexBar.app` |
| `./build.sh app release` | `CodexBar-0.18.1-s5-macos-x86_64.app` | `CodexBar-0.18.1-s5-macos-x86_64.app` |

注意：DMG 文件名仍保留完整版本信息（如 `CodexBar-0.18.1-s5-macos-x86_64.dmg`）

## 相关文件

- `Scripts/build.sh`: 构建脚本
- `Sources/CodexBar/Info.plist`: 应用配置
- `Icon.icns`: 应用图标源文件（圆角透明）

## 提交信息

```
fix(build): 修复应用图标并优化 DMG 内部 app 名称

- 支持从 Icon.icns 复制图标（修复白底方形图标问题）
- 设置 CFBundleIconFile 为 AppIcon
- DMG 中的 app 使用简洁名称 CodexBar.app
```
