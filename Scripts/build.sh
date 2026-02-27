#!/usr/bin/env bash
#===============================================================================
# 构建脚本 - CodexBar macOS 应用
#
# 用法:
#   ./scripts/build.sh              # Debug 构建 (默认)
#   ./scripts/build.sh release       # Release 构建
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

# 验证构建类型
case "${BUILD_TYPE}" in
    debug|release) ;;
    *) echo "错误: 无效的构建类型 '${BUILD_TYPE}'" >&2
       echo "用法: $0 [debug|release]" >&2
       exit 1
       ;;
esac

# 构建配置
if [[ "${BUILD_TYPE}" == "release" ]]; then
    BUILD_FLAG="-c release"
else
    BUILD_FLAG="-c debug"
fi

# 构建项目
build() {
    echo "=============================================="
    echo "  CodexBar 构建"
    echo "  类型: ${BUILD_TYPE}"
    echo "  构建工具: Swift Package Manager"
    echo "=============================================="

    cd "${ROOT_DIR}"

    # 使用 swift build
    if [[ "${BUILD_TYPE}" == "release" ]]; then
        swift build -c release
    else
        swift build
    fi

    echo "=============================================="
    echo "  构建成功!"
    echo "=============================================="

    # 显示产物路径
    echo "产物路径: ${ROOT_DIR}/.build/debug/CodexBar"
}

# 执行构建
build
