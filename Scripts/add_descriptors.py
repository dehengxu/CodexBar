#!/usr/bin/env python3
"""Add descriptor static property to all provider descriptor files."""

import os
import re
from pathlib import Path

base = Path("/Users/dehengxu/Projects/3rd/vibecoding/CodexBar/Sources/CodexBarCore/Providers")

descriptors = [
    "Cursor", "Copilot", "OpenCode", "Factory", "Gemini", "Antigravity",
    "MiniMax", "Ollama", "Warp", "KimiK2", "Amp", "Augment", "VertexAI",
    "Zai", "Synthetic", "JetBrains", "Kimi"
]

for name in descriptors:
    file_path = base / name / f"{name}ProviderDescriptor.swift"
    if not file_path.exists():
        print(f"File not found: {file_path}")
        continue

    content = file_path.read_text()

    # Check if already has descriptor
    if "static let descriptor" in content:
        print(f"Already has descriptor: {file_path}")
        continue

    # Add descriptor after enum declaration
    pattern = rf"^public enum {name}ProviderDescriptor \{{$"
    replacement = rf"public enum {name}ProviderDescriptor {{\n    static let descriptor = {name}ProviderDescriptor.makeDescriptor()"

    new_content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

    if new_content == content:
        print(f"Pattern not matched: {file_path}")
        continue

    file_path.write_text(new_content)
    print(f"Fixed: {file_path}")
