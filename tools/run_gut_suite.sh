#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"

# Force Godot to keep user:// writes inside the repository sandbox.
export HOME="${ROOT_DIR}/.godot_user"
mkdir -p "${HOME}"

ARGS=("$@")
if [ "${#ARGS[@]}" -eq 0 ]; then
	ARGS=(-gdir=res://tests -ginclude_subdirs=true)
fi

"${GODOT_BIN}" --headless --path "${ROOT_DIR}" -s addons/gut/gut_cmdln.gd "${ARGS[@]}" -gexit
