#!/usr/bin/env python3
"""Convert Swift 6 if/switch expressions to Swift 5.7 compatible syntax."""

import re
import sys
from pathlib import Path

def convert_if_expression(content):
    """Convert Swift 6 if expression to traditional if-else."""
    # Pattern: let var: Type? = if condition { ... } else { ... }
    # This is tricky because if expressions can be nested. We'll handle simple cases.

    lines = content.split('\n')
    result = []
    i = 0
    in_expression = False
    expression_lines = []
    var_name = ""
    var_type = ""
    brace_count = 0

    while i < len(lines):
        line = lines[i]

        # Check for if expression pattern: let xxx: Type? = if ...
        match = re.match(r'(\s*)let\s+(\w+):\s*([^\s=]+)\s*=\s*if\s+', line)
        if match and 'else' not in line:
            indent = match.group(1)
            var_name = match.group(2)
            var_type = match.group(3)

            # This is an if expression
            # Find the if and else parts
            rest_of_line = line[match.end():]

            # Check if the if is on the same line
            if '{' in rest_of_line:
                # if is on same line, need to find else
                in_expression = True
                expression_lines = [line]
                brace_count = line.count('{') - line.count('}')
                i += 1
                continue
            else:
                # if starts on next line
                in_expression = True
                expression_lines = [line]
                brace_count = 0
                i += 1
                continue

        if in_expression:
            expression_lines.append(line)
            brace_count += line.count('{') - line.count('}')

            # Check if we've found the else
            if 'else' in line:
                # Convert the if expression
                converted = convert_if_expression_block(expression_lines, var_name, var_type)
                result.append(converted)
                in_expression = False
                expression_lines = []
                var_name = ""
                var_type = ""
                i += 1
                continue
            elif brace_count <= 0 and line.strip():
                # Something went wrong, just add the line
                result.extend(expression_lines)
                in_expression = False
                expression_lines = []
                i += 1
                continue
            i += 1
            continue

        result.append(line)
        i += 1

    return '\n'.join(result)

def convert_if_expression_block(lines, var_name, var_type):
    """Convert a multi-line if expression to traditional syntax."""
    # Find the if and else blocks
    if_line_idx = None
    else_line_idx = None

    for idx, line in enumerate(lines):
        if ' = if ' in line or line.strip().startswith('if '):
            if_line_idx = idx
        if 'else' in line and if_line_idx is not None:
            else_line_idx = idx
            break

    if if_line_idx is None or else_line_idx is None:
        return '\n'.join(lines)

    # Get the indentation
    match = re.match(r'(\s*)', lines[0])
    base_indent = match.group(1) if match else ""

    # Build the converted code
    # Get the variable declaration
    first_line = lines[0]
    decl_match = re.match(r'(\s*let\s+\w+:\s*[^\s=]+)\s*=\s*if', first_line)
    if decl_match:
        var_decl = decl_match.group(1)
    else:
        var_decl = first_line.strip()

    # Extract condition from if line
    if_line = lines[if_line_idx]
    cond_match = re.search(r'if\s+(.+?)\s*\{', if_line)
    if not cond_match:
        return '\n'.join(lines)
    condition = cond_match.group(1)

    # Get if block content
    if_block = lines[if_line_idx + 1:else_line_idx]

    # Get else block content
    else_block = lines[else_line_idx + 1:]

    # Remove trailing empty lines and closing braces
    while if_block and not if_block[-1].strip():
        if_block.pop()
    if if_block and if_block[-1].strip() == '}':
        if_block.pop()

    while else_block and not else_block[-1].strip():
        else_block.pop()
    if else_block and else_block[-1].strip() == '}':
        else_block.pop()

    # Find the common indentation in if block
    if if_block:
        min_indent = min(len(line) - len(line.lstrip()) for line in if_block if line.strip())
    else:
        min_indent = len(base_indent) + 4

    # Remove base indentation from if block
    if_block = [line[min_indent:] if line.strip() else '' for line in if_block]

    # Find the common indentation in else block
    if else_block:
        min_indent = min(len(line) - len(line.lstrip()) for line in else_block if line.strip())
    else:
        min_indent = len(base_indent) + 4

    # Remove base indentation from else block
    else_block = [line[min_indent:] if line.strip() else '' for line in else_block]

    # Build the converted result
    parts = [f"{var_decl} = nil"]
    parts.append(f"{base_indent}if {condition} {{")
    for line in if_block:
        parts.append(f"{base_indent}    {line}")
    parts.append(f"{base_indent}}} else {{")
    for line in else_block:
        parts.append(f"{base_indent}    {line}")
    parts.append(f"{base_indent}}}")

    return '\n'.join(parts)

def convert_switch_expression(content):
    """Convert Swift 6 switch expression to traditional switch-case."""
    lines = content.split('\n')
    result = []
    i = 0

    while i < len(lines):
        line = lines[i]

        # Check for switch expression pattern: let xxx: Type? = switch ...
        match = re.match(r'(\s*)let\s+(\w+):\s*([^\s=]+)\s*=\s*switch\s+', line)
        if match:
            # Find the switch block
            indent = match.group(1)
            var_name = match.group(2)
            var_type = match.group(3)

            # Extract switch expression
            switch_match = re.search(r'switch\s+(.+)', line)
            if not switch_match:
                result.append(line)
                i += 1
                continue

            switch_expr = switch_match.group(1).rstrip('{').strip()

            # Collect all case lines until we find the closing brace
            case_lines = []
            brace_count = 0

            # Check if opening brace is on same line
            if '{' in line:
                brace_count = line.count('{') - line.count('}')
                i += 1
                while i < len(lines):
                    case_lines.append(lines[i])
                    brace_count += lines[i].count('{') - lines[i].count('}')
                    if brace_count <= 0:
                        break
                    i += 1
            else:
                i += 1
                while i < len(lines):
                    case_lines.append(lines[i])
                    brace_count += lines[i].count('{') - lines[i].count('}')
                    if brace_count <= 0:
                        break
                    i += 1

            # Convert switch expression
            converted = convert_switch_block(indent, var_name, var_type, switch_expr, case_lines)
            result.append(converted)
            i += 1
            continue

        result.append(line)
        i += 1

    return '\n'.join(result)

def convert_switch_block(indent, var_name, var_type, switch_expr, case_lines):
    """Convert a switch expression to traditional switch statement."""
    if not case_lines:
        return f"let {var_name}: {var_type}"

    # Find common indentation
    lines_with_content = [l for l in case_lines if l.strip() and not l.strip() == '}']
    if lines_with_content:
        min_indent = min(len(line) - len(line.lstrip()) for line in lines_with_content)
    else:
        min_indent = len(indent) + 4

    # Remove indentation
    case_lines = [line[min_indent:] if line.strip() else '' for line in case_lines]
    # Remove closing brace
    if case_lines and case_lines[-1].strip() == '}':
        case_lines.pop()

    # Build converted result
    parts = [f"let {var_name}: {var_type} = nil"]
    parts.append(f"{indent}switch {switch_expr} {{")
    for line in case_lines:
        parts.append(f"{indent}    {line}")
    parts.append(f"{indent}}}")

    return '\n'.join(parts)

def main():
    if len(sys.argv) < 2:
        print("Usage: convert_swift6.py <file_path>")
        sys.exit(1)

    file_path = Path(sys.argv[1])
    if not file_path.exists():
        print(f"File not found: {file_path}")
        sys.exit(1)

    content = file_path.read_text()

    # First convert if expressions
    content = convert_if_expression(content)

    # Then convert switch expressions
    content = convert_switch_expression(content)

    # Write back
    file_path.write_text(content)
    print(f"Converted: {file_path}")

if __name__ == "__main__":
    main()
