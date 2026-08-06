#!/usr/bin/env python3
"""
Universal app launcher (Windows & macOS & Linux).

Usage:
    python start.py

Does:
  1. (if REPO_RAW set) downloads fresh index.html from the repo and, if newer
     (by version v0.XX), offers to update the local file (old kept as index.html.bak).
     If no local index.html exists, saves the downloaded one right away.
  2. Starts a local HTTP server.
  3. Opens the app in the browser.

Settings: edit REPO_RAW below. Leave empty to skip auto-update.
"""
import os
import sys
import re
import time
import webbrowser
import threading
import http.server
import socketserver
from urllib.request import urlopen, Request

# --- Settings ---
REPO_RAW = "https://raw.githubusercontent.com/KvaDRxniKuS/script_manager/main/index.html"
PORT = 8000
APP_FILE = "index.html"

HERE = os.path.dirname(os.path.abspath(__file__))


def get_version(text):
    m = re.search(r"v0\.\d+", text)
    return m.group(0) if m else ""


def download(url):
    req = Request(url, headers={"User-Agent": "script-manager-launcher"})
    with urlopen(req, timeout=20) as r:
        return r.read()


def main():
    os.chdir(HERE)
    print("App launcher")
    print("------------")
    print("Folder:", HERE)
    print()

    # --- Auto-update index.html ---
    if REPO_RAW:
        print("Checking for updates...")
        try:
            remote = download(REPO_RAW).decode("utf-8", "replace")
        except Exception as e:
            print(f"[WARN] Could not check for updates ({e}) - using current version")
            remote = None

        if remote:
            if not os.path.exists(APP_FILE):
                with open(APP_FILE, "w", encoding="utf-8") as f:
                    f.write(remote)
                print("[OK] Downloaded", APP_FILE)
            else:
                with open(APP_FILE, "r", encoding="utf-8", errors="replace") as f:
                    local = f.read()
                rv = get_version(remote)
                lv = get_version(local)
                print("  Local version :", lv or "n/a")
                print("  Repo version  :", rv or "n/a")
                if not rv:
                    print("  [WARN] Could not read version from repo - skipping update")
                elif rv == lv:
                    print("  [OK]", APP_FILE, "is up to date")
                else:
                    # автообновление без запроса
                    if os.path.exists(APP_FILE):
                        os.replace(APP_FILE, APP_FILE + ".bak")
                    with open(APP_FILE, "w", encoding="utf-8") as f:
                        f.write(remote)
                    print(f"  [OK] Updated to {rv} (old kept as", APP_FILE + ".bak)")
    else:
        print("Auto-update disabled (REPO_RAW empty)")

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
