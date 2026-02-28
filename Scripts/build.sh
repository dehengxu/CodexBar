#!/usr/bin/env bash
#===============================================================================
# 构建脚本 - CodexBar macOS 应用
#
# 用法:
#   ./scripts/build.sh                              # Debug 构建 (默认 arm64)
#   ./scripts/build.sh release                      # Release 构建 (默认 arm64)
#   ./scripts/build.sh cli                          # 单独构建 CLI (Debug)
#   ./scripts/build.sh cli release                  # 单独构建 CLI (Release)
#   ./scripts/build.sh app                          # 生成 .app 包 (Debug, arm64)
#   ./scripts/build.sh app release                  # 生成 .app 包 (Release, arm64)
#   ./scripts/build.sh app release x86_64          # 生成 .app 包 (Release, x86_64)
#   ./scripts/build.sh app release universal       # 生成 .app 包 (Release, 通用二进制)
#   ./scripts/build.sh dmg                         # 生成 .dmg 包 (Debug, arm64)
#   ./scripts/build.sh dmg release universal       # 生成 .dmg 包 (Release, 通用二进制)
#
# 环境变量:
#   CODEXBAR_SIGNING_MODE: 签名模式 (adhoc, identity, none)
#   APP_IDENTITY:        代码签名身份
#   CODEXBAR_VERSION:    指定版本号 (默认从 git tag 获取)
#
# 架构选项:
#   arm64      - Apple Silicon (默认)
#   x86_64     - Intel
#   universal - 通用二进制 (arm64 + x86_64)
#===============================================================================

set -euo pipefail

# 配置
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 获取版本号 (从 git tag 或环境变量)
get_version() {
    if [[ -n "${CODEXBAR_VERSION:-}" ]]; then
        echo "$CODEXBAR_VERSION"
    else
        # 尝试从 git tag 获取版本
        local version
        version=$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//') || true
        if [[ -z "$version" ]]; then
            version="0.0.0"
        fi
        echo "$version"
    fi
}

# 获取当前系统架构
get_current_arch() {
    case "$(uname -m)" in
        arm64) echo "arm64" ;;
        x86_64) echo "x86_64" ;;
        *) echo "arm64" ;;
    esac
}

# 打印帮助信息
print_help() {
    local version
    version=$(get_version)
    local current_arch
    current_arch=$(get_current_arch)

    cat << EOF
CodexBar 构建脚本

用法:
  ./scripts/build.sh [命令] [选项] [架构]

命令:
  (无参数)        默认 Debug 构建 (arm64)
  release         Release 构建 (默认 arm64)
  cli             单独构建 CLI (Debug, arm64)
  cli release     单独构建 CLI (Release, arm64)
  app             生成 .app 包 (Debug, arm64)
  app release     生成 .app 包 (Release, arm64)
  dmg             生成 .dmg 包 (Debug, arm64)
  dmg release     生成 .dmg 包 (Release, arm64)
  help            显示此帮助信息

架构选项:
  arm64      - Apple Silicon (M系列芯片, 默认)
  x86_64     - Intel Mac
  universal  - 通用二进制 (arm64 + x86_64)

版本: ${version} (当前系统: ${current_arch})

环境变量:
  CODEXBAR_VERSION    指定版本号 (默认从 git tag 获取)
  CODEXBAR_SIGNING_MODE 签名模式 (adhoc, identity, none)
  APP_IDENTITY        代码签名身份

示例:
  ./scripts/build.sh                           # Debug 构建 (arm64)
  ./scripts/build.sh release                  # Release 构建 (arm64)
  ./scripts/build.sh release x86_64          # Release 构建 (x86_64)
  ./scripts/build.sh app release universal   # Release 通用二进制
  CODEXBAR_VERSION=1.2.3 ./scripts/build.sh app release  # 指定版本号
EOF
}

# 解析参数
BUILD_TYPE="${1:-help}"
TARGET="${2:-}"
ARCH="${3:-}"

# 验证架构
validate_arch() {
    case "$1" in
        arm64|x86_64|universal) return 0 ;;
        "") return 0 ;;  # 空值使用默认值
        *) echo "错误: 无效的架构 '${1}'" >&2
           echo "有效选项: arm64, x86_64, universal" >&2
           return 1 ;;
    esac
}

# 解析架构参数
parse_arch() {
    local arch="${1:-}"
    if [[ -z "$arch" ]]; then
        # 默认使用当前系统架构
        get_current_arch
    else
        echo "$arch"
    fi
}

# 如果没有参数或请求帮助，显示帮助信息
if [[ "${BUILD_TYPE}" == "help" || "${BUILD_TYPE}" == "-h" || "${BUILD_TYPE}" == "--help" ]]; then
    print_help
    exit 0
fi

# 验证构建类型
case "${BUILD_TYPE}" in
    debug|release|app|dmg|cli) ;;
    *) echo "错误: 无效的构建类型 '${BUILD_TYPE}'" >&2
       echo "" >&2
       print_help >&2
       exit 1
       ;;
esac

# 验证架构
if ! validate_arch "$ARCH"; then
    print_help >&2
    exit 1
fi

# 解析版本号和架构
VERSION=$(get_version)
ARCH=$(parse_arch "$ARCH")

# 构建配置
if [[ "${BUILD_TYPE}" == "app" || "${BUILD_TYPE}" == "dmg" || "${BUILD_TYPE}" == "cli" ]]; then
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

# 生成产物名称 (带版本号、系统和架构)
generate_product_name() {
    local name="$1"
    local ext="$2"
    echo "${name}-${VERSION}-macos-${ARCH}.${ext}"
}

# 单独构建 CLI
build_cli() {
    local conf="$1"
    local arch="$2"
    local config_upper=$(printf "%s" "$conf" | tr '[:lower:]' '[:upper:]')

    echo "=============================================="
    echo "  构建 CodexBarCLI"
    echo "  配置: ${config_upper}"
    echo "  架构: ${arch}"
    echo "  版本: ${VERSION}"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 构建 CLI (支持交叉编译)
    echo ">> 构建 CodexBarCLI (${arch})..."
    local build_args=()
    if [[ "${conf}" == "release" ]]; then
        build_args+=(-c release)
    fi

    # 处理交叉编译
    if [[ "$arch" != "$(get_current_arch)" ]]; then
        if [[ "$arch" == "universal" ]]; then
            build_args+=(--arch arm64 --arch x86_64)
        else
            build_args+=(--arch "$arch")
        fi
    fi
    build_args+=(--product CodexBarCLI)

    swift build "${build_args[@]}"

    # 创建输出目录
    local cli_output="${ROOT_DIR}/.build/${conf}"
    local cli_bin="${cli_output}/codexbar"
    local product_name
    product_name=$(generate_product_name "CodexBarCLI" "")

    # 复制可执行文件
    cp "${ROOT_DIR}/.build/${conf}/codexbar" "${cli_bin}" 2>/dev/null || \
    cp "${cli_output}/CodexBarCLI" "${cli_bin}" 2>/dev/null || true

    # 检查是否存在
    if [[ -f "${cli_output}/CodexBarCLI" ]]; then
        echo "=============================================="
        echo "  CLI 构建成功!"
        echo "=============================================="
        echo "产物路径: ${cli_output}/CodexBarCLI"
        echo "重命名产物: ${product_name}"
        # 重命名产物
        mv "${cli_output}/CodexBarCLI" "${cli_output}/${product_name}" 2>/dev/null || true
        echo ""
        echo "安装到系统 (需要 sudo):"
        echo "  sudo cp ${cli_output}/${product_name} /usr/local/bin/codexbar"
        echo "  或者:"
        echo "  sudo ln -s ${cli_output}/${product_name} /usr/local/bin/codexbar"
    else
        echo "错误: CLI 构建失败" >&2
        exit 1
    fi
}

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

    echo "=============================================="
    echo "  构建 .app 包"
    echo "  配置: ${config_upper}"
    echo "  架构: ${arch}"
    echo "  版本: ${VERSION}"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 1. 构建可执行文件 (支持交叉编译)
    echo ">> 构建 Swift 包 (${arch})..."
    local build_args=()
    if [[ "${conf}" == "release" ]]; then
        build_args+=(-c release)
    fi

    # 处理交叉编译：使用 --arch 参数 (Swift 5.7+)
    if [[ "$arch" != "$(get_current_arch)" ]]; then
        if [[ "$arch" == "universal" ]]; then
            # universal 需要分别构建然后合并
            echo "   - 构建 universal 二进制..."
            build_args+=(--arch arm64 --arch x86_64)
        else
            echo "   - 交叉编译到 ${arch}..."
            build_args+=(--arch "$arch")
        fi
    fi

    swift build "${build_args[@]}"

    # 1.5 构建 CLI
    echo ">> 构建 CodexBarCLI (${arch})..."
    local cli_build_args=("${build_args[@]}")
    cli_build_args+=(--product CodexBarCLI)
    swift build "${cli_build_args[@]}"

    # 2. 创建 .app 目录结构
    local app_bundle="${ROOT_DIR}/${app_name}"
    rm -rf "$app_bundle"
    mkdir -p "$app_bundle/Contents/MacOS"
    mkdir -p "$app_bundle/Contents/Resources"
    mkdir -p "$app_bundle/Contents/Frameworks"

    # 3. 复制可执行文件
    local exec_path="${ROOT_DIR}/.build/${conf}/CodexBar"
    cp "$exec_path" "${app_bundle}/Contents/MacOS/CodexBar"

    # 4. 复制并修复 Info.plist
    if [[ -f "${ROOT_DIR}/Sources/CodexBar/Info.plist" ]]; then
        # 复制 Info.plist
        cp "${ROOT_DIR}/Sources/CodexBar/Info.plist" "${app_bundle}/Contents/Info.plist"

        # 替换变量占位符
        sed -i '' 's|\$(EXECUTABLE_NAME)|CodexBar|g' "${app_bundle}/Contents/Info.plist"
        sed -i '' 's|\$(PRODUCT_BUNDLE_IDENTIFIER)|com.codexbar.app|g' "${app_bundle}/Contents/Info.plist"
        sed -i '' 's|\$(PRODUCT_NAME)|CodexBar|g' "${app_bundle}/Contents/Info.plist"
        sed -i '' 's|\$(DEVELOPMENT_LANGUAGE)|en|g' "${app_bundle}/Contents/Info.plist"
        sed -i '' 's|\$(MACOSX_DEPLOYMENT_TARGET)|12.0|g' "${app_bundle}/Contents/Info.plist"
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
    if [[ -f "${ROOT_DIR}/Icon.icns" ]]; then
        cp "${ROOT_DIR}/Icon.icns" "${app_bundle}/Contents/Resources/AppIcon.icns"
        echo "   - AppIcon.icns 已复制"
    elif [[ -d "${ROOT_DIR}/Icon.iconset" ]]; then
        iconutil --convert icns --output "${app_bundle}/Contents/Resources/AppIcon.icns" "${ROOT_DIR}/Icon.iconset" 2>/dev/null || true
        echo "   - AppIcon.icns 已从 Icon.iconset 生成"
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

    # 8. 嵌入其他依赖框架 (KeyboardShortcuts)
    if [[ -d "${ROOT_DIR}/.build/${conf}/KeyboardShortcuts.framework" ]]; then
        cp -R "${ROOT_DIR}/.build/${conf}/KeyboardShortcuts.framework" "${app_bundle}/Contents/Frameworks/"
        chmod -R a+rX "${app_bundle}/Contents/Frameworks/KeyboardShortcuts.framework"
        echo "   - KeyboardShortcuts.framework 已嵌入"
    fi

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

    echo "=============================================="
    echo "  .app 包构建成功!"
    echo "=============================================="
    echo "产物路径: ${app_bundle}"
}

# 生成 .dmg 包
build_dmg() {
    local conf="$1"
    local arch="$2"
    local config_upper=$(printf "%s" "$conf" | tr '[:lower:]' '[:upper:]')
    local dmg_name
    dmg_name=$(generate_product_name "CodexBar" "dmg")

    echo "=============================================="
    echo "  构建 .dmg 包"
    echo "  配置: ${config_upper}"
    echo "  架构: ${arch}"
    echo "  版本: ${VERSION}"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 1. 先构建 .app（使用简单名称 CodexBar.app）
    build_app "${conf}" "${arch}" "1"

    # 2. 创建 DMG
    local app_bundle="${ROOT_DIR}/CodexBar.app"
    local dmg_path="${ROOT_DIR}/${dmg_name}"

    # 如果已存在 DMG，先删除
    if [[ -f "${dmg_path}" ]]; then
        rm -f "${dmg_path}"
    fi

    echo ">> 创建 DMG 文件..."

    # 使用 hdiutil 直接创建 DMG，不自动挂载
    hdiutil create \
        -volname "CodexBar" \
        -srcfolder "${app_bundle}" \
        -format UDZO \
        -quiet \
        "${dmg_path}"

    echo "=============================================="
    echo "  .dmg 包构建成功!"
    echo "=============================================="
    echo "产物路径: ${dmg_path}"
}

# 构建项目
build() {
    echo "=============================================="
    echo "  CodexBar 构建"
    echo "  类型: ${BUILD_CONFIG}"
    echo "  架构: ${ARCH}"
    echo "  版本: ${VERSION}"
    echo "  构建工具: Swift Package Manager"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 使用 swift build (支持交叉编译)
    local build_args=()
    if [[ "${BUILD_CONFIG}" == "release" ]]; then
        build_args+=(-c release)
    fi

    # 处理交叉编译
    if [[ "$ARCH" != "$(get_current_arch)" ]]; then
        if [[ "$ARCH" == "universal" ]]; then
            build_args+=(--arch arm64 --arch x86_64)
        else
            build_args+=(--arch "$ARCH")
        fi
    fi

    echo ">> 构建 (${ARCH})..."
    swift build "${build_args[@]}"

    echo "=============================================="
    echo "  构建成功!"
    echo "=============================================="

    # 显示产物路径 (带架构标识)
    local product_name
    product_name=$(generate_product_name "CodexBar" "")
    if [[ "${BUILD_CONFIG}" == "release" ]]; then
        echo "产物路径: ${ROOT_DIR}/.build/release/${product_name}"
    else
        echo "产物路径: ${ROOT_DIR}/.build/debug/${product_name}"
    fi
}

# 主逻辑
if [[ "${BUILD_TYPE}" == "cli" ]]; then
    build_cli "${BUILD_CONFIG}" "${ARCH}"
elif [[ "${BUILD_TYPE}" == "app" ]]; then
    build_app "${BUILD_CONFIG}" "${ARCH}"
elif [[ "${BUILD_TYPE}" == "dmg" ]]; then
    build_dmg "${BUILD_CONFIG}" "${ARCH}"
else
    build
fi
