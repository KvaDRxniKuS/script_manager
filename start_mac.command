#!/bin/bash
# ============================================================
#  App launcher (macOS) - thin wrapper that runs start.py
#  Double-click: runs python3 start.py (which starts server + browser)
# ============================================================

# Move to the folder of this script
cd "$(cd "$(dirname "$0")" && pwd)" || exit 1

# Find a python interpreter
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
else
  echo "[ERR] Python not found. Install from https://www.python.org/downloads/"
  read -r -p "Press Enter to close... "
  exit 1
fi

# Run the universal launcher (logic is in start.py)
exec "$PY" start.py
