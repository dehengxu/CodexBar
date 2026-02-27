#!/usr/bin/env bash
#===============================================================================
# 构建脚本 - CodexBar macOS 应用
#
# 用法:
#   ./scripts/build.sh              # Debug 构建 (默认)
#   ./scripts/build.sh release      # Release 构建
#   ./scripts/build.sh app         # 生成 .app 包 (Debug)
#   ./scripts/build.sh app release # 生成 .app 包 (Release)
#
# 环境变量:
#   CODEXBAR_SIGNING_MODE: 签名模式 (adhoc, identity, none)
#   APP_IDENTITY:        代码签名身份
#===============================================================================

set -euo pipefail

# 配置
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 解析参数
BUILD_TYPE="${1:-debug}"
TARGET="${2:-}"

# 验证构建类型
case "${BUILD_TYPE}" in
    debug|release|app) ;;
    *) echo "错误: 无效的构建类型 '${BUILD_TYPE}'" >&2
       echo "用法: $0 [debug|release|app] [release]" >&2
       exit 1
       ;;
esac

# 构建配置
if [[ "${BUILD_TYPE}" == "app" ]]; then
    if [[ "${TARGET}" == "release" ]]; then
        BUILD_CONFIG="release"
    else
        BUILD_CONFIG="debug"
    fi
else
    if [[ "${BUILD_TYPE}" == "release" ]]; then
        BUILD_CONFIG="release"
    else
        BUILD_CONFIG="debug"
    fi
fi

# 生成 .app 包
build_app() {
    local conf="$1"
    local config_upper=$(printf "%s" "$conf" | tr '[:lower:]' '[:upper:]')

    echo "=============================================="
    echo "  构建 .app 包"
    echo "  配置: ${config_upper}"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 1. 构建可执行文件
    echo ">> 构建 Swift 包..."
    if [[ "${conf}" == "release" ]]; then
        swift build -c release
    else
        swift build -c debug
    fi

    # 2. 创建 .app 目录结构
    local app_bundle="${ROOT_DIR}/CodexBar.app"
    rm -rf "$app_bundle"
    mkdir -p "$app_bundle/Contents/MacOS"
    mkdir -p "$app_bundle/Contents/Resources"
    mkdir -p "$app_bundle/Contents/Frameworks"

    # 3. 复制可执行文件
    local exec_path="${ROOT_DIR}/.build/${conf}/CodexBar"
    cp "$exec_path" "${app_bundle}/Contents/MacOS/CodexBar"

    # 4. 复制 Info.plist
    if [[ -f "${ROOT_DIR}/Sources/CodexBar/Info.plist" ]]; then
        cp "${ROOT_DIR}/Sources/CodexBar/Info.plist" "${app_bundle}/Contents/Info.plist"
    fi

    # 5. 复制 entitlements
    if [[ -f "${ROOT_DIR}/Sources/CodexBar/CodexBar.entitlements" ]]; then
        cp "${ROOT_DIR}/Sources/CodexBar/CodexBar.entitlements" "${app_bundle}/Contents/CodexBar.entitlements"
    fi

    # 6. 复制资源文件
    if [[ -d "${ROOT_DIR}/Sources/CodexBar/Resources" ]]; then
        cp -R "${ROOT_DIR}/Sources/CodexBar/Resources/"* "${app_bundle}/Contents/Resources/" 2>/dev/null || true
    fi

    # 7. 复制 app icon
    if [[ -d "${ROOT_DIR}/Icon.iconset" ]]; then
        iconutil --convert icns --output "${app_bundle}/Contents/Resources/AppIcon.icns" "${ROOT_DIR}/Icon.iconset" 2>/dev/null || true
    fi

    # 8. 嵌入 Sparkle.framework
    echo ">> 嵌入 Sparkle.framework..."
    if [[ -d "${ROOT_DIR}/.build/${conf}/Sparkle.framework" ]]; then
        cp -R "${ROOT_DIR}/.build/${conf}/Sparkle.framework" "${app_bundle}/Contents/Frameworks/"
        chmod -R a+rX "${app_bundle}/Contents/Frameworks/Sparkle.framework"
        # 添加 rpath 以便找到框架
        install_name_tool -add_rpath "@executable_path/../Frameworks" "${app_bundle}/Contents/MacOS/CodexBar" 2>/dev/null || true
        echo "   - Sparkle.framework 已嵌入"
    else
        echo "   - 警告: 未找到 Sparkle.framework"
    fi

    # 9. 嵌入其他依赖框架 (KeyboardShortcuts)
    if [[ -d "${ROOT_DIR}/.build/${conf}/KeyboardShortcuts.framework" ]]; then
        cp -R "${ROOT_DIR}/.build/${conf}/KeyboardShortcuts.framework" "${app_bundle}/Contents/Frameworks/"
        chmod -R a+rX "${app_bundle}/Contents/Frameworks/KeyboardShortcuts.framework"
        echo "   - KeyboardShortcuts.framework 已嵌入"
    fi

    echo "=============================================="
    echo "  .app 包构建成功!"
    echo "=============================================="
    echo "产物路径: ${app_bundle}"
}

# 构建项目
build() {
    echo "=============================================="
    echo "  CodexBar 构建"
    echo "  类型: ${BUILD_CONFIG}"
    echo "  构建工具: Swift Package Manager"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 使用 swift build
    if [[ "${BUILD_CONFIG}" == "release" ]]; then
        swift build -c release
    else
        swift build
    fi

    echo "=============================================="
    echo "  构建成功!"
    echo "=============================================="

    # 显示产物路径
    if [[ "${BUILD_CONFIG}" == "release" ]]; then
        echo "产物路径: ${ROOT_DIR}/.build/release/CodexBar"
    else
        echo "产物路径: ${ROOT_DIR}/.build/debug/CodexBar"
    fi
}

# 主逻辑
if [[ "${BUILD_TYPE}" == "app" ]]; then
    build_app "${BUILD_CONFIG}"
else
    build
fi
