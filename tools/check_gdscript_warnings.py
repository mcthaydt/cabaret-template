#!/usr/bin/env python3
"""
GDScript Warnings Checker for Godot 4.6

This tool lists all available GDScript warnings and can generate
configuration sections for project.godot.

Usage:
    python tools/check_gdscript_warnings.py                    # Show all warnings
    python tools/check_gdscript_warnings.py --generate         # Generate config
    python tools/check_gdscript_warnings.py --recommended      # Recommended only
"""

import argparse
from typing import Dict, List, Tuple

# All GDScript warnings available in Godot 4.6
# Reference: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html
GDSCRIPT_WARNINGS = {
    # === Core Safety Warnings (Recommended) ===
    "unassigned_variable": {
        "description": "Variable used before being assigned a value",
        "default": True,
        "severity": "error",
        "recommended": True,
        "category": "Safety"
    },
    "unassigned_variable_op_assign": {
        "description": "Variable used in compound assignment before being assigned",
        "default": True,
        "severity": "error",
        "recommended": True,
        "category": "Safety"
    },
    "unused_variable": {
        "description": "Local variable is declared but never used",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "unused_local_constant": {
        "description": "Local constant is declared but never used",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "unused_parameter": {
        "description": "Function parameter is never used (prefix with _ to suppress)",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "unused_signal": {
        "description": "Signal is declared but never emitted",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "unreachable_code": {
        "description": "Code after return/break/continue that will never execute",
        "default": True,
        "severity": "error",
        "recommended": True,
        "category": "Safety"
    },
    "unreachable_pattern": {
        "description": "Match pattern that can never be reached",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "shadowed_variable": {
        "description": "Local variable shadows another local variable in the same scope",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "shadowed_variable_base_class": {
        "description": "Variable in derived class shadows variable in base class",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "shadowed_global_identifier": {
        "description": "Local identifier shadows a global class/function",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "standalone_expression": {
        "description": "Expression result is not used",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "narrowing_conversion": {
        "description": "Implicit conversion may lose precision (int to float, etc)",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },
    "incompatible_ternary": {
        "description": "Ternary branches have incompatible types",
        "default": True,
        "severity": "error",
        "recommended": True,
        "category": "Safety"
    },
    "static_called_on_instance": {
        "description": "Static method called on instance instead of class",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Safety"
    },

    # === Type Safety Warnings (Optional, for strict typing) ===
    "unsafe_property_access": {
        "description": "Property access on untyped object",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Type Safety"
    },
    "unsafe_method_access": {
        "description": "Method call on untyped object",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Type Safety"
    },
    "unsafe_cast": {
        "description": "Cast may fail at runtime",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Type Safety"
    },
    "unsafe_call_argument": {
        "description": "Argument type may not match parameter",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Type Safety"
    },
    "untyped_declaration": {
        "description": "Variable/parameter declared without explicit type",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Type Safety"
    },
    "inferred_declaration": {
        "description": "Variable type is inferred rather than explicit",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Type Safety"
    },

    # === Style & Naming Warnings ===
    "confusable_identifier": {
        "description": "Identifier name contains confusable Unicode characters",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Style"
    },
    "confusable_local_declaration": {
        "description": "Local variable name is very similar to existing variable",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Style"
    },
    "confusable_local_usage": {
        "description": "Using variable with name similar to another in scope",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Style"
    },

    # === Engine Integration Warnings ===
    "native_method_override": {
        "description": "Overriding built-in Godot method (use @warning_ignore if intentional)",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Engine"
    },
    "get_node_default_without_onready": {
        "description": "get_node() default value without @onready (will fail in _init)",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Engine"
    },
    "onready_with_export": {
        "description": "@onready with @export (redundant, use @export only)",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Engine"
    },

    # === GDScript 2.0 Compatibility ===
    "int_as_enum_without_cast": {
        "description": "Integer used as enum without explicit cast",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Compatibility"
    },
    "int_as_enum_without_match": {
        "description": "Integer compared to enum without type checking",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Compatibility"
    },

    # === Performance & Other ===
    "return_value_discarded": {
        "description": "Function return value is not used",
        "default": False,
        "severity": "warning",
        "recommended": False,
        "category": "Performance"
    },
    "redundant_await": {
        "description": "await used on non-coroutine expression",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Performance"
    },
    "deprecated_keyword": {
        "description": "Using deprecated GDScript keyword",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Deprecated"
    },
    "assert_always_true": {
        "description": "Assert condition is always true",
        "default": True,
        "severity": "warning",
        "recommended": True,
        "category": "Deprecated"
    },
    "assert_always_false": {
        "description": "Assert condition is always false",
        "default": True,
        "severity": "error",
        "recommended": True,
        "category": "Deprecated"
    },
}


def print_all_warnings() -> None:
    """Print all warnings organized by category."""
    print("\n" + "=" * 80)
    print("GDScript Warnings for Godot 4.6")
    print("=" * 80)

    # Group by category
    categories: Dict[str, List[Tuple[str, Dict]]] = {}
    for warning_name, info in GDSCRIPT_WARNINGS.items():
        category = info["category"]
        if category not in categories:
            categories[category] = []
        categories[category].append((warning_name, info))

    total_warnings = len(GDSCRIPT_WARNINGS)
    enabled_by_default = sum(1 for w in GDSCRIPT_WARNINGS.values() if w["default"])
    recommended = sum(1 for w in GDSCRIPT_WARNINGS.values() if w["recommended"])

    print(f"\nTotal warnings: {total_warnings}")
    print(f"Enabled by default: {enabled_by_default}")
    print(f"Recommended: {recommended}\n")

    # Print each category
    category_order = ["Safety", "Type Safety", "Style", "Engine", "Compatibility", "Performance", "Deprecated"]
    for category in category_order:
        if category not in categories:
            continue

        print("\n" + "-" * 80)
        print(f"{category} Warnings")
        print("-" * 80)

        for warning_name, info in sorted(categories[category]):
            status = "ON" if info["default"] else "OFF"
            rec = " [RECOMMENDED]" if info["recommended"] else ""
            severity_label = f" ({info['severity'].upper()})" if info['severity'] == 'error' else ""

            print(f"\n  {warning_name}")
            print(f"    Default: {status}{rec}{severity_label}")
            print(f"    {info['description']}")

    print("\n" + "=" * 80 + "\n")


def generate_project_godot_section(recommended_only: bool = False) -> str:
    """Generate [gdscript] section for project.godot."""
    lines = [
        "[gdscript]",
        "",
        "# GDScript warning configuration",
        "# Generated by tools/check_gdscript_warnings.py",
        ""
    ]

    if recommended_only:
        lines.append("# Only recommended warnings enabled (strict but practical)")
    else:
        lines.append("# All warnings with Godot defaults")

    lines.append("")

    for warning_name in sorted(GDSCRIPT_WARNINGS.keys()):
        info = GDSCRIPT_WARNINGS[warning_name]

        if recommended_only:
            value = "true" if info["recommended"] else "false"
        else:
            value = "true" if info["default"] else "false"

        # Add helpful comments
        comment = ""
        if info["default"] and info["recommended"]:
            comment = "  # Default ON, recommended"
        elif info["default"] and not info["recommended"]:
            comment = "  # Default ON"
        elif not info["default"] and info["recommended"]:
            comment = "  # Default OFF, but recommended"

        lines.append(f"warnings/{warning_name}={value}{comment}")

    lines.append("")
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Check GDScript warnings configuration for Godot 4.6"
    )
    parser.add_argument(
        "--generate",
        action="store_true",
        help="Generate [gdscript] section for project.godot"
    )
    parser.add_argument(
        "--recommended",
        action="store_true",
        help="Only enable recommended warnings (use with --generate)"
    )

    args = parser.parse_args()

    if args.generate:
        print("\n" + "=" * 80)
        print("project.godot [gdscript] Section")
        print("=" * 80 + "\n")
        print(generate_project_godot_section(args.recommended))
        print("\nCopy the above section and add it to your project.godot file.")
        print("Then restart the Godot editor to apply the changes.\n")
    else:
        print_all_warnings()


if __name__ == "__main__":
    main()
