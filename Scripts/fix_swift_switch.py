#!/usr/bin/env python3
"""Batch fix Swift 6 switch expression syntax (add return statements)."""

import re
import sys
from pathlib import Path

def fix_file(filepath):
    content = filepath.read_text()
    modified = False

    # Fix pattern: switch expr { case X: value } -> switch expr { case X: return value }
    # For errorDescription getters

    # Pattern for simple switch in getter: case .xxx: "string"
    pattern = r'(case [^:]+):\s*(".*?")'

    lines = content.split('\n')
    result = []
    in_switch = False
    switch_indent = 0

    i = 0
    while i < len(lines):
        line = lines[i]

        # Check if we're entering a switch in a getter
        if re.search(r'switch\s+\w+\s*\{', line) or re.search(r'switch\s+\([^)]+\)\s*\{', line):
            in_switch = True

        if in_switch:
            # Check for case with string literal without return
            match = re.match(r'(\s+)(case [^:]+):\s*(".*?")\s*$', line)
            if match:
                indent = match.group(1)
                case_stmt = match.group(2)
                value = match.group(3)
                result.append(f'{indent}{case_stmt}: return {value}')
                modified = True
                i += 1
                continue

            # Check for closing brace
            if line.strip() == '}':
                in_switch = False

        result.append(line)
        i += 1

    if modified:
        filepath.write_text('\n'.join(result))
        print(f"Fixed: {filepath}")

    return modified

def main():
    if len(sys.argv) < 2:
        print("Usage: fix_swift_switch.py <file_path>")
        sys.exit(1)

    filepath = Path(sys.argv[1])
    if not filepath.exists():
        print(f"File not found: {filepath}")
        sys.exit(1)

    fix_file(filepath)

if __name__ == "__main__":
    main()
