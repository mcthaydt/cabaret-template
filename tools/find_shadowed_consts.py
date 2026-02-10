#!/usr/bin/env python3
"""
Scans GDScript files for shadowed const preloads.

Usage:
    python3 tools/find_shadowed_consts.py

Output:
    Prints all files with shadowed const preloads
"""

import os
import re
from pathlib import Path
from collections import defaultdict

# Known global classes (classes with class_name declarations)
KNOWN_GLOBAL_CLASSES = {
    "C_DamageZoneComponent",
    "U_InputRebindUtils",
    "RS_RebindSettings",
    "RS_InputProfile",
    "U_InputEventSerialization",
    "U_InputEventDisplay",
}

# Directories to scan
SCRIPT_DIRS = ["scripts/", "tests/"]

# Regex pattern to match: const ClassName := preload("...")
CONST_PRELOAD_PATTERN = re.compile(r'^const\s+(\w+)\s*:=\s*preload\(')

# Regex pattern to match: class_name ClassName
CLASS_NAME_PATTERN = re.compile(r'^\s*class_name\s+(\w+)')


def find_all_class_names(project_root):
    """Scan all .gd files to find classes with class_name declarations."""
    class_names = set()

    for script_dir in SCRIPT_DIRS:
        dir_path = project_root / script_dir
        if not dir_path.exists():
            continue

        for gd_file in dir_path.rglob("*.gd"):
            try:
                with open(gd_file, 'r', encoding='utf-8') as f:
                    for line in f:
                        match = CLASS_NAME_PATTERN.match(line)
                        if match:
                            class_names.add(match.group(1))
                            break  # class_name should be near the top
            except Exception as e:
                print(f"Error reading {gd_file}: {e}")

    return class_names


def scan_file_for_shadowed_consts(file_path, global_classes):
    """Scan a single file for shadowed const preloads."""
    errors = []

    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            for line_num, line in enumerate(f, start=1):
                match = CONST_PRELOAD_PATTERN.match(line)
                if match:
                    const_name = match.group(1)
                    if const_name in global_classes:
                        errors.append({
                            'line': line_num,
                            'const_name': const_name,
                            'line_text': line.strip()
                        })
    except Exception as e:
        print(f"Error reading {file_path}: {e}")

    return errors


def main():
    project_root = Path(__file__).parent.parent

    print("=== Shadowed Const Preload Scanner ===")
    print(f"Project root: {project_root}")
    print()

    # First, scan for all class_name declarations
    print("Scanning for global classes (class_name declarations)...")
    global_classes = find_all_class_names(project_root)
    print(f"Found {len(global_classes)} global classes")
    print()

    # Update with known classes
    global_classes.update(KNOWN_GLOBAL_CLASSES)

    # Now scan for shadowed const preloads
    print("Scanning for shadowed const preloads...")
    print()

    all_errors = defaultdict(list)
    files_scanned = 0

    for script_dir in SCRIPT_DIRS:
        dir_path = project_root / script_dir
        if not dir_path.exists():
            print(f"Warning: Directory not found: {dir_path}")
            continue

        for gd_file in dir_path.rglob("*.gd"):
            files_scanned += 1
            rel_path = gd_file.relative_to(project_root)
            errors = scan_file_for_shadowed_consts(gd_file, global_classes)

            if errors:
                all_errors[str(rel_path)] = errors

    # Print results
    print(f"Files scanned: {files_scanned}")
    print(f"Files with errors: {len(all_errors)}")
    print()

    if all_errors:
        print("=== Errors Found ===")
        print()

        total_errors = 0
        for file_path in sorted(all_errors.keys()):
            errors = all_errors[file_path]
            total_errors += len(errors)

            print(f"📄 {file_path}")
            for error in errors:
                print(f"   Line {error['line']:4d}: const {error['const_name']}")
                print(f"              {error['line_text']}")
            print()

        print(f"Total shadowed consts: {total_errors}")
        print()
        print("💡 Fix: Remove these const preloads - classes are globally available via class_name")
    else:
        print("✅ No shadowed const preloads found!")

    print()


if __name__ == "__main__":
    main()
