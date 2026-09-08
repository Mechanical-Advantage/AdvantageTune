#!/usr/bin/env bash
set -euo pipefail

# Directories to format
TARGET_DIRS=("AdvantageTune")

# Check if swift-format is available via Xcode
if ! xcrun --find swift-format >/dev/null 2>&1; then
  echo "Error: swift-format not found in active Xcode toolchain." >&2
  exit 1
fi

MODE="format"

# Parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check|-c)
      MODE="check"
      shift
      ;;
    --help|-h)
      echo "Usage: ./format.sh [--check|-c]"
      echo "  (no flags) : Automatically formats all Swift files in-place."
      echo "  --check    : Verifies formatting without modifying files (exits 1 if unformatted)."
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [ "$MODE" = "check" ]; then
  echo "Checking Swift code formatting..."
  xcrun swift-format lint --strict --recursive --parallel "${TARGET_DIRS[@]}"
  echo "✅ All Swift files are properly formatted."
else
  echo "Formatting Swift files in-place..."
  xcrun swift-format format --in-place --recursive --parallel "${TARGET_DIRS[@]}"
  echo "✅ Formatting complete."
fi
