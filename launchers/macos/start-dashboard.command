#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

echo
echo "Skill Archive Management"
echo "Opening skill-archive.html..."
echo

ARCHIVE_PATH="$REPO_ROOT/skill-archive.html"

if command -v pwsh >/dev/null 2>&1; then
  echo "PowerShell found. Refreshing the local dashboard first..."
  pwsh -NoProfile -ExecutionPolicy Bypass -File "$REPO_ROOT/scripts/setup-dashboard.ps1" -NoOpen
else
  echo "PowerShell 7+ was not found."
  echo "Opening the bundled dashboard without refreshing local Skill data."
  echo "To refresh from this Mac later, install PowerShell:"
  echo "  brew install --cask powershell"
  echo
fi

if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "Missing skill-archive.html. Please download the full repository archive."
  read -r -p "Press Enter to close..."
  exit 1
fi

open "$ARCHIVE_PATH"

echo
echo "Done. If the browser did not open, open skill-archive.html manually."
read -r -p "Press Enter to close..."
