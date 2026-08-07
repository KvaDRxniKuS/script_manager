#!/bin/bash
# ============================================================
#  App launcher (macOS) - runs start.py
#  Smart Python handling:
#    1) if python3 exists                -> run
#    2) if no python3 but py launcher    -> "py install default", wait, run
#    3) if neither                       -> open download page
# ============================================================

cd "$(cd "$(dirname "$0")" && pwd)" || exit 1
echo ""
echo "App launcher"
echo "------------"
echo ""

PY=""

# 1) real python3
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
fi

# 2) not found, but py launcher present
if [ -z "$PY" ] && command -v py >/dev/null 2>&1; then
  echo "Python not found, but the 'py' launcher exists."
  echo "Installing default Python runtime..."
  py install default
  echo ""
  echo "Installation finished."
  if command -v python3 >/dev/null 2>&1; then PY=python3
  elif command -v python >/dev/null 2>&1; then PY=python
  else PY="py"
  fi
fi

# 3) neither
if [ -z "$PY" ]; then
  echo "[ERR] Python is not installed."
  echo ""
  echo "Please install Python (Python Install Manager) and re-run this launcher."
  echo "  https://www.python.org/downloads/"
  echo ""
  open "https://www.python.org/downloads/" 2>/dev/null
  echo ""
  read -r -p "Press Enter to close... "
  exit 1
fi

echo "Using Python: $PY"
echo ""
"$PY" start.py
EXITCODE=$?

if [ "$EXITCODE" -ne 0 ]; then
  echo ""
  echo "[ERR] start.py failed with code $EXITCODE. See messages above."
  read -r -p "Press Enter to close... "
fi
