#!/usr/bin/env python3
"""
Restores const preloads for .tres resource files that were incorrectly removed.

Our fix script removed ALL const preloads matching global class names, but some
were actually loading .tres resource instances, not .gd scripts. This script
restores those.
"""

import subprocess
from pathlib import Path


def main():
    project_root = Path(__file__).parent.parent

    print("=== Restoring .tres Resource Preloads ===")
    print()

    # Get the diff from the last commit
    result = subprocess.run(
        ['git', 'show', 'HEAD'],
        capture_output=True,
        text=True,
        cwd=project_root
    )

    if result.returncode != 0:
        print("Error getting git diff")
        return

    diff_lines = result.stdout.split('\n')

    # Find removed lines that preload .tres files
    tres_preloads = []
    current_file = None

    for line in diff_lines:
        if line.startswith('---'):
            # Track which file we're in
            parts = line.split()
            if len(parts) > 1:
                file_path = parts[1].replace('a/', '')
                current_file = file_path
        elif line.startswith('-const ') and '.tres' in line:
            # This is a removed const that loads a .tres file
            const_line = line[1:]  # Remove the '-' prefix
            tres_preloads.append({
                'file': current_file,
                'line': const_line
            })

    print(f"Found {len(tres_preloads)} .tres preloads that were incorrectly removed")
    print()

    if tres_preloads:
        print("Files affected:")
        files_affected = set(item['file'] for item in tres_preloads)
        for file_path in sorted(files_affected):
            count = sum(1 for item in tres_preloads if item['file'] == file_path)
            print(f"  {file_path} ({count} preloads)")
        print()
        print("To restore these, we need to revert the last commit and re-run")
        print("the fix script with .tres files excluded.")
        print()
        print("Run: git reset --soft HEAD~1")
        print("Then: python3 tools/fix_shadowed_consts_v2.py")
    else:
        print("✅ No .tres preloads found in removed lines")


if __name__ == "__main__":
    main()
