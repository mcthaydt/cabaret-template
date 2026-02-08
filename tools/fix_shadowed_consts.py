#!/usr/bin/env python3
"""
Automatically fixes shadowed const preloads (v2 - excludes .tres files).

Usage:
    python3 tools/fix_shadowed_consts_v2.py --dry-run    # Preview changes
    python3 tools/fix_shadowed_consts_v2.py              # Apply changes

Improvements from v1:
    - Only removes const preloads for .gd script files
    - Preserves const preloads for .tres resource instances
    - More accurate pattern matching
"""

import os
import re
import argparse
from pathlib import Path

# Directories to scan
SCRIPT_DIRS = ["scripts/", "tests/"]

# Regex patterns
CONST_PRELOAD_PATTERN = re.compile(r'^const\s+(\w+)\s*:=\s*preload\("([^"]+)"\)')
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
                            break
            except Exception as e:
                print(f"Error reading {gd_file}: {e}")

    return class_names


def fix_file(file_path, global_classes, dry_run=True):
    """Remove shadowed const preloads from a single file (only .gd files)."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return None

    new_lines = []
    removed_lines = []

    for line_num, line in enumerate(lines, start=1):
        match = CONST_PRELOAD_PATTERN.match(line)

        if match:
            const_name = match.group(1)
            preload_path = match.group(2)

            # IMPORTANT: Only remove if:
            # 1. const_name matches a global class
            # 2. preload_path is a .gd file (NOT .tres, .tscn, etc.)
            if const_name in global_classes and preload_path.endswith('.gd'):
                # This is a shadowed const for a script - remove it
                removed_lines.append((line_num, line.rstrip()))
                continue

        new_lines.append(line)

    if not removed_lines:
        return None

    # Write changes if not dry run
    if not dry_run:
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.writelines(new_lines)
        except Exception as e:
            print(f"Error writing {file_path}: {e}")
            return None

    return {
        'removed_lines': removed_lines,
        'lines_removed_count': len(removed_lines)
    }


def main():
    parser = argparse.ArgumentParser(description='Fix shadowed const preloads (v2)')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be changed without applying')
    args = parser.parse_args()

    project_root = Path(__file__).parent.parent

    print("=== Shadowed Const Preload Fixer v2 ===")
    print(f"Project root: {project_root}")
    if args.dry_run:
        print("🔍 DRY RUN MODE - No files will be modified")
    else:
        print("⚠️  LIVE MODE - Files will be modified")
    print()
    print("✨ v2 improvements: Only removes .gd preloads, preserves .tres resource instances")
    print()

    # Find all global classes
    print("Scanning for global classes (class_name declarations)...")
    global_classes = find_all_class_names(project_root)
    print(f"Found {len(global_classes)} global classes")
    print()

    # Process all files
    print("Processing files...")
    print()

    files_modified = 0
    total_lines_removed = 0
    changes_by_file = {}

    for script_dir in SCRIPT_DIRS:
        dir_path = project_root / script_dir
        if not dir_path.exists():
            continue

        for gd_file in dir_path.rglob("*.gd"):
            rel_path = gd_file.relative_to(project_root)
            result = fix_file(gd_file, global_classes, dry_run=args.dry_run)

            if result:
                files_modified += 1
                total_lines_removed += result['lines_removed_count']
                changes_by_file[str(rel_path)] = result

    # Print summary
    print()
    print("=== Summary ===")
    print(f"Files modified: {files_modified}")
    print(f"Total const lines removed: {total_lines_removed}")
    print()

    if changes_by_file:
        print("=== Changes by File ===")
        print()

        # Show first 20 files as examples
        shown_files = 0
        max_show = 20

        for file_path in sorted(changes_by_file.keys()):
            if shown_files >= max_show and args.dry_run:
                remaining = len(changes_by_file) - shown_files
                print(f"... and {remaining} more files")
                print()
                break

            changes = changes_by_file[file_path]
            print(f"📄 {file_path} ({changes['lines_removed_count']} lines)")

            for line_num, line_text in changes['removed_lines']:
                print(f"   - Line {line_num:4d}: {line_text}")

            print()
            shown_files += 1

    if args.dry_run:
        print()
        print("💡 To apply these changes, run:")
        print("   python3 tools/fix_shadowed_consts_v2.py")
        print()
        print("⚠️  Recommendation: Commit your current changes first!")
    else:
        print()
        print("✅ Changes applied successfully!")
        print()
        print("📝 Next steps:")
        print("   1. Review the changes with: git diff")
        print("   2. Test that nothing broke")
        print("   3. Commit the changes")


if __name__ == "__main__":
    main()
