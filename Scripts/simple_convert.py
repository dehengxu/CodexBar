#!/usr/bin/env python3
"""Simple Swift 6 to Swift 5.7 converter for basic syntax changes."""

import re
import sys
from pathlib import Path

def process_file(filepath):
    content = filepath.read_text()
    modified = False

    # Replace @Bindable with @ObservedObject
    if '@Bindable' in content:
        content = content.replace('@Bindable var', '@ObservedObject var')
        modified = True

    # Replace onChange with old syntax
    # .onChange(of: x) { _, newValue in -> .onChange(of: x) { newValue in
    pattern = r'\.onChange\(of:\s*([^)]+)\)\s*\{\s*_\s*,\s*newValue\s+in'
    replacement = r'.onChange(of: \1) { newValue in'
    new_content, count = re.subn(pattern, replacement, content)
    if count > 0:
        content = new_content
        modified = True

    # Replace switch expressions (case .x: "value" -> case .x: return "value")
    # Pattern: case \.[a-zA-Z0-9]+:\s*"[^"]+"
    lines = content.split('\n')
    result = []
    in_switch = False
    for line in lines:
        stripped = line.strip()
        if 'switch ' in stripped and '{' in stripped:
            in_switch = True
            result.append(line)
        elif in_switch and stripped.startswith('case ') and ':' in stripped:
            # Check if it's a simple case without return
            if 'return ' not in stripped:
                # Check if there's a string or simple value after colon
                match = re.match(r'(case\s+[^:]+:)\s*(.+)$', stripped)
                if match:
                    indent = line[:len(line) - len(stripped)]
                    case_part = match.group(1)
                    value_part = match.group(2)
                    result.append(f'{indent}{case_part} return {value_part}')
                    modified = True
                else:
                    result.append(line)
            else:
                result.append(line)
        elif in_switch and stripped == '}':
            in_switch = False
            result.append(line)
        else:
            result.append(line)

    content = '\n'.join(result)

    # Remove .textSelection(.enabled)
    if '.textSelection(.enabled)' in content:
        content = content.replace('.textSelection(.enabled)', '')
        modified = True

    # Remove axis: .vertical from TextField
    pattern = r'TextField\(([^,]+),\s*text:\s*([^,]+),\s*axis:\s*\.vertical\)'
    replacement = r'TextField(\1, text: \2)'
    new_content, count = re.subn(pattern, replacement, content)
    if count > 0:
        content = new_content
        modified = True

    if modified:
        filepath.write_text(content)
        print(f'Modified: {filepath}')

    return modified

def main():
    if len(sys.argv) < 2:
        print("Usage: simple_convert.py <file_or_directory>")
        sys.exit(1)

    path = Path(sys.argv[1])
    if path.is_file():
        process_file(path)
    elif path.is_dir():
        for swift_file in path.rglob('*.swift'):
            process_file(swift_file)
    else:
        print(f"Path not found: {path}")
        sys.exit(1)

if __name__ == "__main__":
    main()
