#!/usr/bin/env python3
"""Simple script to convert Swift 6 if/switch expressions to Swift 5.7."""

import re
import sys
from pathlib import Path

def fix_file(filepath):
    content = filepath.read_text()
    modified = False

    # Fix if expressions: let x: T = if cond { val1 } else { val2 }
    # Pattern: let name: Type? = if condition { expr } else { expr }
    pattern = r'(let\s+(\w+):\s*([^\s=]+)\s*=\s*)if\s+(.+?)\s*\{\s*(.+?)\s*\}\s*else\s*\{\s*(.+?)\s*\}'

    def replace_if(m):
        nonlocal modified
        modified = True
        prefix = m.group(1)
        var_name = m.group(2)
        var_type = m.group(3)
        condition = m.group(4).strip()
        if_val = m.group(5).strip()
        else_val = m.group(6).strip()

        # Handle multiline condition
        cond_clean = condition.replace('\n', ' ').strip()

        return f'''{prefix}nil
        if {cond_clean} {{
            {var_name} = {if_val}
        }} else {{
            {var_name} = {else_val}
        }}'''

    content = re.sub(pattern, replace_if, content, flags=re.DOTALL)

    # Fix if expressions on single line: let x: T? = if cond { a } else { b }
    pattern2 = r'(let\s+(\w+):\s*([^\s=]+)\s*=\s*)if\s+(.+?)\s*\{\s*(.+?)\s*\}\s*else\s*\{\s*(.+?)\s*\}'
    content = re.sub(pattern2, replace_if, content)

    if modified:
        filepath.write_text(content)
        print(f"Fixed: {filepath}")
    return modified

def main():
    if len(sys.argv) < 2:
        print("Usage: fix_swift6.py <file_path>")
        sys.exit(1)

    filepath = Path(sys.argv[1])
    if not filepath.exists():
        print(f"File not found: {filepath}")
        sys.exit(1)

    fix_file(filepath)

if __name__ == "__main__":
    main()
