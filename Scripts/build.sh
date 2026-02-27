#!/usr/bin/env bash
#===============================================================================
# 构建脚本 - CodexBar macOS 应用
#
# 用法:
#   ./scripts/build.sh              # Debug 构建 (默认)
#   ./scripts/build.sh release       # Release 构建
#   ./scripts/build.sh release arm64 # Release 构建，仅 arm64 架构
#   ./scripts/build.sh debug x86_64  # Debug 构建，仅 x86_64 架构
#
# 环境变量:
#   CODEXBAR_SIGNING_MODE: 签名模式 (adhoc, identity, none)
#   APP_IDENTITY:        代码签名身份
#===============================================================================

set -euo pipefail

# 配置
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="${ROOT_DIR}/project.yml"
XCODEPROJ="${ROOT_DIR}/CodexBar.xcodeproj"
SCHEME="CodexBar"

# 解析参数
BUILD_TYPE="${1:-debug}"
ARCH="${2:-}"

# 验证构建类型
case "${BUILD_TYPE}" in
    debug|release) ;;
    *) echo "错误: 无效的构建类型 '${BUILD_TYPE}'" >&2
       echo "用法: $0 [debug|release] [arm64|x86_64]" >&2
       exit 1
       ;;
esac

# 构建配置
if [[ "${BUILD_TYPE}" == "release" ]]; then
    CONFIGURATION="Release"
else
    CONFIGURATION="Debug"
fi

# 解析架构
if [[ -n "${ARCH}" ]]; then
    case "${ARCH}" in
        arm64|x86_64) ;;
        *) echo "错误: 无效的架构 '${ARCH}'" >&2
           echo "用法: $0 [debug|release] [arm64|x86_64]" >&2
           exit 1
           ;;
    esac
    ARCHS="-arch ${ARCH}"
else
    ARCHS=""
fi

# 查找 xcodegen
find_xcodegen() {
    if command -v xcodegen &>/dev/null; then
        echo "xcodegen"
        return
    fi

    # 尝试从项目依赖中查找
    if [[ -x "${ROOT_DIR}/.build/debug/xcodegen" ]]; then
        echo "${ROOT_DIR}/.build/debug/xcodegen"
        return
    fi

    echo ""
}

# 检查并生成 xcodeproj
ensure_xcodeproj() {
    local need_regenerate=0

    if [[ ! -d "${XCODEPROJ}" ]]; then
        echo ">> xcodeproj 不存在，需要生成..."
        need_regenerate=1
    elif [[ "${PROJECT_YML}" -nt "${XCODEPROJ}" ]]; then
        echo ">> project.yml 已更新，需要重新生成..."
        need_regenerate=1
    fi

    if [[ ${need_regenerate} -eq 1 ]]; then
        local XCODEGEN
        XCODEGEN=$(find_xcodegen)

        if [[ -z "${XCODEGEN}" ]]; then
            echo "错误: 未找到 xcodegen，请先安装: brew install xcodegen" >&2
            exit 1
        fi

        echo ">> 运行 xcodegen 生成项目..."
        cd "${ROOT_DIR}"
        "${XCODEGEN}" generate
    fi
}

# 构建项目
build() {
    echo "=============================================="
    echo "  CodexBar 构建"
    echo "  类型: ${CONFIGURATION}"
    echo "  架构: ${ARCH:-默认 (universal)}"
    echo "=============================================="

    # 确保 xcodeproj 存在
    ensure_xcodeproj

    # 构建命令
    local build_cmd=(
        xcodebuild
        -project "${XCODEPROJ}"
        -scheme "${SCHEME}"
        -configuration "${CONFIGURATION}"
    )

    if [[ -n "${ARCHS}" ]]; then
        build_cmd+=(${ARCHS})
    fi

    build_cmd+=(-derivedDataPath "${ROOT_DIR}/.build")
    build_cmd+=(build)

    echo ">> 执行构建命令: ${build_cmd[*]}"

    cd "${ROOT_DIR}"
    "${build_cmd[@]}"

    echo "=============================================="
    echo "  构建成功!"
    echo "=============================================="

    # 显示产物路径
    local build_dir="${ROOT_DIR}/.build"
    if [[ "${CONFIGURATION}" == "Release" ]]; then
        echo "产物路径: ${build_dir}/Release/CodexBar.app"
    else
        echo "产物路径: ${build_dir}/Debug/CodexBar.app"
    fi
}

# 执行构建
build
