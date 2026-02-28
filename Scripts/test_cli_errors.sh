#!/usr/bin/env bash
# CLI 错误处理和退出码测试脚本

echo "CLI 错误处理和退出码测试"
echo "======================="
echo ""

CLI_BIN=".build/debug/CodexBarCLI"

function test_exit_code {
    local test_name="$1"
    local command="$2"
    local expected_code="$3"

    echo -n "测试: $test_name... "
    eval "$command" >/dev/null 2>&1
    local exit_code=$?

    if [ $exit_code -eq $expected_code ]; then
        echo "✓ 通过 (退出码: $exit_code)"
        return 0
    else
        echo "✗ 失败 (期望: $expected_code, 实际: $exit_code)"
        return 1
    fi
}

# 测试用例
test_exit_code "成功 (help)" "$CLI_BIN --help" 0
test_exit_code "成功 (version)" "$CLI_BIN --version" 0
test_exit_code "成功 (config validate)" "$CLI_BIN config validate" 0
test_exit_code "成功 (config dump)" "$CLI_BIN config dump" 0

echo ""
echo "测试未知命令..."
echo -n "测试: 未知命令... "
$CLI_BIN invalid_command 2>&1 | grep -q "Unknown command" && echo "✓ 通过" || echo "✗ 失败"

echo ""
echo "测试无效 Provider..."
echo -n "测试: 无效 Provider 警告... "
$CLI_BIN usage --provider invalid 2>&1 | grep -q "Warning: Unknown provider" && echo "✓ 通过" || echo "✗ 失败"

echo ""
echo "所有错误处理测试完成！"
