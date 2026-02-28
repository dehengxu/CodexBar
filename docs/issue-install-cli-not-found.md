# 问题修复：Install CLI 找不到 CodexBarCLI

## 问题描述
在设置界面的 Advanced 中选择 install cli 后，一旁小字显示 "CodexBarCLI not found in app bundle"

## 原因分析

1. **问题根源**：`build.sh` 脚本的 app 构建功能没有将 CodexBarCLI 复制到 app bundle 的 `Contents/Helpers/` 目录中

2. **相关代码**：
   - app 的 `PreferencesAdvancedPane.swift` 在第 105 行查找 CLI 路径：
     ```swift
     let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/CodexBarCLI")
     ```
   - 原始 `package_app.sh` 正确处理了 CLI 的复制（第 272-274 行），但 `build.sh` 没有这个功能

## 修复方案

### 1. 修改 `Scripts/build.sh`

#### 添加 CLI 构建步骤
在 `build_app()` 函数中，添加构建 CodexBarCLI 的步骤：
```bash
# 1.5 构建 CLI
echo ">> 构建 CodexBarCLI..."
if [[ "${conf}" == "release" ]]; then
    swift build -c release --product CodexBarCLI
else
    swift build --product CodexBarCLI
fi
```

#### 添加 CLI 复制步骤
在 `build_app()` 函数的末尾，添加将 CLI 复制到 `Contents/Helpers/` 目录的步骤：
```bash
# 9. 复制 CodexBarCLI 到 Helpers 目录
local cli_path="${ROOT_DIR}/.build/${conf}/CodexBarCLI"
if [[ -f "${cli_path}" ]]; then
    echo ">> 复制 CodexBarCLI 到 Helpers 目录..."
    mkdir -p "${app_bundle}/Contents/Helpers"
    cp "${cli_path}" "${app_bundle}/Contents/Helpers/CodexBarCLI"
    chmod +x "${app_bundle}/Contents/Helpers/CodexBarCLI"
    echo "   - CodexBarCLI 已复制"
else
    echo "   - 警告: 未找到 CodexBarCLI (在 ${cli_path})"
    echo "     请先运行 'swift build --product CodexBarCLI' 或 './Scripts/build.sh cli'"
fi
```

### 2. 新增单独 CLI 构建功能（可选）
为了方便用户单独构建 CLI，添加了 `cli` 命令：
- `./Scripts/build.sh cli` - Debug 模式构建 CLI
- `./Scripts/build.sh cli release` - Release 模式构建 CLI

## 验证步骤

1. **构建 app**：
   ```bash
   ./Scripts/build.sh app
   ```

2. **验证 CLI 在 app bundle 中**：
   ```bash
   ls -la CodexBar.app/Contents/Helpers/
   ```
   应看到：`CodexBarCLI`

3. **测试 CLI 是否能正常运行**：
   ```bash
   CodexBar.app/Contents/Helpers/CodexBarCLI --help
   ```

## 修复结果

- ✅ CodexBarCLI 现在被正确地复制到 app bundle 的 `Contents/Helpers/` 目录
- ✅ install CLI 功能现在应该能正常工作了
- ✅ app 可以找到 CodexBarCLI 并创建符号链接到系统路径

## 文件变更

- `Scripts/build.sh` - 修改了 `build_app()` 函数，添加 CLI 构建和复制步骤
