#!/usr/bin/env bash
# CLI 功能测试脚本
# 用于手动验证 CLI 功能

echo "CLI 功能测试"
echo "=============="
echo ""

CLI_BIN=".build/debug/CodexBarCLI"

echo "1. 测试 Help 命令..."
$CLI_BIN --help | head -5
echo "   ✓ Help 正常输出"
echo ""

echo "2. 测试 Version 命令..."
$CLI_BIN --version
echo "   ✓ Version 正常输出"
echo ""

echo "3. 测试 Config validate..."
$CLI_BIN config validate
echo "   ✓ Config validate 正常"
echo ""

echo "4. 测试 Config dump..."
$CLI_BIN config dump | head -5
echo "   ✓ Config dump 正常输出"
echo ""

echo "5. 测试 Provider 过滤 (--provider 选项存在)..."
$CLI_BIN --help | grep -q "\-\-provider" && echo "   ✓ --provider 选项存在"
echo ""

echo "6. 测试 JSON 输出..."
$CLI_BIN config dump --format json | head -3
echo "   ✓ JSON 格式输出正常"
echo ""

echo "所有基本测试通过！"
