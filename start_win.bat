@echo off
rem ============================================================
rem  App launcher (Windows) - thin wrapper that runs start.py
rem  Double-click: runs python start.py (which starts server + browser)
rem ============================================================
setlocal

rem Move to the folder of this script
cd /d "%~dp0"

rem Find a python interpreter
set "PY="
where python >nul 2>nul && set "PY=python"
if not defined PY ( where py >nul 2>nul && set "PY=py -3" )

if not defined PY (
  echo [ERR] Python not found. Install from https://www.python.org/downloads/
  pause
  exit /b 1
)

rem Run the universal launcher (logic is in start.py)
%PY% start.py

endlocal
