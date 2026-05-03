#!/bin/bash
# Pre-commit hook: Validate core/demo import separation
# Usage: tools/pre-commit-hooks/validate-imports.sh

set -e

echo "🔍 Validating core/demo import separation..."

# Find all modified .gd files
MODIFIED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.gd$' || true)

if [ -z "$MODIFIED_FILES" ]; then
    echo "✅ No GDScript files staged for commit"
    exit 0
fi

VIOLATIONS=0

for file in $MODIFIED_FILES; do
    # Check if file is in core directory
    if [[ "$file" == scripts/core/* ]]; then
        # Check for demo imports
        if grep -q "res://scripts/demo/" "$file" || \
           grep -q "res://scenes/demo/" "$file" || \
           grep -q "res://resources/demo/" "$file"; then
            echo "❌ CORE_IMPORT_VIOLATION: $file imports from demo/"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi
done

if [ $VIOLATIONS -gt 0 ]; then
    echo ""
    echo "🚫 Found $VIOLATIONS core/demo import violation(s)."
    echo "   Core scripts (scripts/core/) must not import from demo/ paths."
    echo ""
    echo "   Fix the violations and try again, or use --no-verify to bypass (not recommended)."
    exit 1
fi

echo "✅ Core/demo import validation passed"
exit 0
