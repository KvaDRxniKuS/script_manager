#!/usr/bin/env python3
"""
Universal app launcher (Windows & macOS & Linux).

Usage:
    python start.py

What it does:
  1. (if REPO set) checks the repository for a newer version of ALL app files
     (index.html, start.py, start_win.bat, start_mac.command, userscript, README...)
     and auto-updates any that changed. Old index.html is kept as index.html.bak.
     If a file is missing locally, it is downloaded.
  2. If start.py itself was updated, it re-runs itself so new logic applies.
  3. Starts a local HTTP server.
  4. Opens the app in the browser.

Settings: edit REPO_OWNER / REPO_NAME below. Leave REPO_NAME empty to skip auto-update.
"""
import os
import sys
import re
import time
import webbrowser
import threading
import http.server
import socketserver
import json
from urllib.request import urlopen, Request

# --- Settings ---
REPO_OWNER = "KvaDRxniKuS"   # GitHub username/org
REPO_NAME = "script_manager"  # repo name; empty = auto-update disabled
DEFAULT_BRANCH = "main"
PORT = 8000
APP_FILE = "index.html"

HERE = os.path.dirname(os.path.abspath(__file__))

# Files we manage from the repo (exclude this launcher's own source? no—we DO update it)
# We update every file listed in the repo root except .gitignore (not needed at runtime).


def get_version(text):
    m = re.search(r"v0\.\d+", text)
    return m.group(0) if m else ""


def http_get(url, timeout=20):
    req = Request(url, headers={"User-Agent": "script-manager-launcher"})
    with urlopen(req, timeout=timeout) as r:
        return r.read()


def repo_list_files():
    """Return {filename: download_url} for files in the repo root (branch DEFAULT_BRANCH)."""
    url = f"https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/?ref={DEFAULT_BRANCH}"
    data = json.loads(http_get(url).decode("utf-8"))
    out = {}
    for item in data:
        if item.get("type") == "file":
            out[item["name"]] = item.get("download_url") or (
                f"https://raw.githubusercontent.com/{REPO_OWNER}/{REPO_NAME}/{DEFAULT_BRANCH}/"
                + item["name"]
            )
    return out


def main():
    os.chdir(HERE)
    print("App launcher")
    print("------------")
    print("Folder:", HERE)
    print()

    updated_self = False

    if REPO_NAME:
        print("Checking for updates...")
        try:
            files = repo_list_files()
        except Exception as e:
            print(f"[WARN] Could not reach repo ({e}) - using current files")
            files = None

        if files:
            for fname, url in files.items():
                # Skip files we must not overwrite blindly
                if fname == ".gitignore":
                    continue
                try:
                    remote = http_get(url).decode("utf-8", "replace")
                except Exception as e:
                    print(f"  [WARN] Could not fetch {fname} ({e})")
                    continue

                local_path = os.path.join(HERE, fname)
                if not os.path.exists(local_path):
                    with open(local_path, "w", encoding="utf-8") as f:
                        f.write(remote)
                    print(f"  [OK] Downloaded {fname}")
                    if fname == "start.py":
                        updated_self = True
                    continue

                with open(local_path, "r", encoding="utf-8", errors="replace") as f:
                    local = f.read()

                # index.html: compare by version (repo may append CF beacon)
                if fname == APP_FILE:
                    rv = get_version(remote)
                    lv = get_version(local)
                    if rv and rv != lv:
                        os.replace(local_path, local_path + ".bak")
                        with open(local_path, "w", encoding="utf-8") as f:
                            f.write(remote)
                        print(f"  [OK] Updated {fname} to {rv} (old kept as .bak)")
                    elif not rv:
                        print(f"  [WARN] Could not read version in {fname} - skip")
                    # else: same version -> no action
                else:
                    # other files: compare by content
                    if remote != local:
                        with open(local_path, "w", encoding="utf-8") as f:
                            f.write(remote)
                        print(f"  [OK] Updated {fname}")
                        if fname == "start.py":
                            updated_self = True
        else:
            print("  (no repo access)")

    else:
        print("Auto-update disabled (REPO_NAME empty)")

    # If start.py itself changed, re-run with the new version
    if updated_self:
        print()
        print("start.py was updated - restarting with the new version...")
        os.execv(sys.executable, [sys.executable, os.path.join(HERE, "start.py")])

    # --- Start HTTP server in background thread ---
    os.chdir(HERE)
    handler = http.server.SimpleHTTPRequestHandler

    class Quiet(handler):
        def log_message(self, *a):
            pass

    try:
        httpd = socketserver.TCPServer(("127.0.0.1", PORT), Quiet)
    except OSError:
        print(f"  Port {PORT} already in use - assuming server is running")
        httpd = None

    if httpd:
        t = threading.Thread(target=httpd.serve_forever, daemon=True)
        t.start()
        time.sleep(1)
        print(f"  Server running on http://127.0.0.1:{PORT}")

    # --- Open browser ---
    url = f"http://127.0.0.1:{PORT}/{APP_FILE}"
    print("  Opening:", url)
    webbrowser.open(url)

    print()
    print("Done! Server runs in background.")
    print("Press Ctrl+C to stop.")
    print()
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        if httpd:
            httpd.shutdown()
        print("Stopped.")


if __name__ == "__main__":
    main()
