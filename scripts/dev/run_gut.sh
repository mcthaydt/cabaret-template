#!/usr/bin/env bash
set -euo pipefail

# Simple wrapper to run GUT with project-local Godot user/config/data dirs.
# Places HOME, XDG_CONFIG_HOME, and XDG_DATA_HOME under .godot/ci/* so
# test runs do not touch your real Godot profile.

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
CI_DIR="$ROOT_DIR/.godot/ci"
HOME_DIR="$CI_DIR/home"
CFG_DIR="$CI_DIR/config"
DATA_DIR="$CI_DIR/data"

mkdir -p "$HOME_DIR" "$CFG_DIR" "$DATA_DIR"

# Pick a Godot binary: $GODOT_BIN overrides, else macOS app, else godot4
GODOT_BIN_DEFAULT="/Applications/Godot.app/Contents/MacOS/Godot"
if [[ -n "${GODOT_BIN:-}" ]]; then
  GODOT="$GODOT_BIN"
elif [[ -x "$GODOT_BIN_DEFAULT" ]]; then
  GODOT="$GODOT_BIN_DEFAULT"
else
  GODOT="godot4"
fi

TEST_DIR=""
SELECT_TEST=""

usage() {
  echo "Usage: bash scripts/dev/run_gut.sh [-d test_dir] [-s test_selector]"
  echo "  -d test_dir       GUT -gdir path (e.g., res://tests/integration)"
  echo "  -s test_selector  GUT -gselect (e.g., res://tests/unit/foo.gd::test_name)"
  exit 1
}

while getopts ":d:s:h" opt; do
  case $opt in
    d) TEST_DIR="$OPTARG" ;;
    s) SELECT_TEST="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

if [[ -z "$TEST_DIR" && -z "$SELECT_TEST" ]]; then
  echo "Must supply either -d test_dir or -s test_selector" >&2
  usage
fi

CMD=("$GODOT" "--headless" "--path" "$ROOT_DIR" "-s" "addons/gut/gut_cmdln.gd" "-gexit")

if [[ -n "$TEST_DIR" ]]; then
  CMD+=("-gdir=$TEST_DIR")
fi
if [[ -n "$SELECT_TEST" ]]; then
  CMD+=("-gselect=$SELECT_TEST")
fi

echo "[run_gut] GODOT=$GODOT"
echo "[run_gut] HOME=$HOME_DIR"
echo "[run_gut] XDG_CONFIG_HOME=$CFG_DIR"
echo "[run_gut] XDG_DATA_HOME=$DATA_DIR"
echo "[run_gut] CMD=${CMD[*]}"

HOME="$HOME_DIR" XDG_CONFIG_HOME="$CFG_DIR" XDG_DATA_HOME="$DATA_DIR" "${CMD[@]}"

