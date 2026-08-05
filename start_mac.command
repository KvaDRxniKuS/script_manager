#!/bin/bash
# ============================================================
#  App launcher (macOS)
#  Double-click: update index.html + start server + open browser
#
#  SETTINGS:
#  Set REPO_RAW to your public repo index.html raw URL.
#  Leave empty to skip auto-update.
# ============================================================

REPO_RAW="https://raw.githubusercontent.com/KvaDRxniKuS/script_manager/main/index.html"

# Move to the folder of this script
cd "$(cd "$(dirname "$0")" && pwd)" || exit 1

echo ""
echo "App launcher"
echo "------------"
echo "Folder: $PWD"
echo ""

# --- Download fresh index.html (if network available) ---
TMP="/tmp/script_manager_index.html"
rm -f "$TMP"

if [ -n "$REPO_RAW" ]; then
  echo "Checking for updates..."
  if command -v curl >/dev/null 2>&1; then
    curl -sL "$REPO_RAW" -o "$TMP"
  else
    wget -q -O "$TMP" "$REPO_RAW" 2>/dev/null
  fi
else
  echo "Auto-update disabled (REPO_RAW empty)"
fi

# --- If repo file exists, compare versions and maybe replace ---
if [ ! -s "$TMP" ]; then
  echo "[WARN] Could not check for updates (no network?) - using current version"
else
  if [ ! -f "index.html" ]; then
    # No local file yet - just save the downloaded one (strip CF beacon)
    awk '/<script>\(function\(\)\{function c\(\)\{/{exit} {print}' "$TMP" > "index.html"
    rm -f "$TMP"
    echo "[OK] Downloaded index.html"
  else
    REMOTE_VER=$(grep -o 'v0\.[0-9]*' "$TMP" | head -1)
    LOCAL_VER=$(grep -o 'v0\.[0-9]*' "index.html" | head -1)
    echo "  Local version : ${LOCAL_VER:-n/a}"
    echo "  Repo version  : ${REMOTE_VER:-n/a}"

    if [ -z "$REMOTE_VER" ]; then
      echo "  [WARN] Could not read version from repo - skipping update"
      rm -f "$TMP"
    elif [ "$REMOTE_VER" = "$LOCAL_VER" ]; then
      echo "  [OK] index.html is up to date"
      rm -f "$TMP"
    else
      echo "  A newer version is available."
      read -r -p "  Update local file? (y/N): " ANS
      if [ "$ANS" = "y" ] || [ "$ANS" = "Y" ]; then
        cp -f "index.html" "index.html.bak" 2>/dev/null
        awk '/<script>\(function\(\)\{function c\(\)\{/{exit} {print}' "$TMP" > "index.html"
        echo "  [OK] Updated. Old version kept as index.html.bak"
      else
        echo "  Skipping update (keeping current version)"
      fi
      rm -f "$TMP"
    fi
  fi
fi

# --- Python check ---
if command -v python3 >/dev/null 2>&1; then PY=python3
elif command -v python >/dev/null 2>&1; then PY=python
else
  echo "[ERR] Python not found. Install from https://www.python.org/downloads/"
  read -r -p "Press Enter to close... "
  exit 1
fi

# --- Start server ---
PORT=8000
if curl -s -o /dev/null "http://127.0.0.1:$PORT" ; then
  echo "  Server already running on port $PORT"
else
  echo "Starting server on http://127.0.0.1:$PORT ..."
  "$PY" -m http.server "$PORT" >/dev/null 2>&1 &
  sleep 1.5
fi

# --- Open browser ---
URL="http://127.0.0.1:$PORT/index.html"
if [ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]; then
  open -a "Google Chrome" "$URL"
elif [ -x "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" ]; then
  open -a "Microsoft Edge" "$URL"
else
  open "$URL"
fi

echo ""
echo "Done! Server runs in background."
echo "To stop it later, find 'http.server' in Activity Monitor."
echo ""
read -r -p "Press Enter to close this window (server keeps running)... "
