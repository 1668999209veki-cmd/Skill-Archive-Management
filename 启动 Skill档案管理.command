#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo
echo "Skill Archive Management"
echo "Generating and opening skill-archive.html..."
echo

if ! command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell 7+ is required on macOS."
  echo "Install it with Homebrew:"
  echo "  brew install --cask powershell"
  echo
  echo "After installation, double-click this launcher again."
  read -r -p "Press Enter to close..."
  exit 1
fi

pwsh -NoProfile -ExecutionPolicy Bypass -File "$SCRIPT_DIR/scripts/setup-dashboard.ps1"

echo
echo "Done. If the browser did not open, open skill-archive.html manually."
read -r -p "Press Enter to close..."
