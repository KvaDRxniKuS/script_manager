@echo off
rem ============================================================
rem  App launcher (Windows) - thin wrapper that runs start.py
rem  Double-click: runs python start.py (which starts server + browser)
rem
rem  If Python is not installed, it opens the download page.
rem ============================================================
setlocal

rem Move to the folder of this script
cd /d "%~dp0"

rem Find a python interpreter
set "PY="
where python >nul 2>nul && set "PY=python"
if not defined PY ( where py >nul 2>nul && set "PY=py -3" )

if not defined PY (
  echo.
  echo [ERR] Python is not installed.
  echo Opening the download page in your browser...
  start "" "https://www.python.org/downloads/"
  echo.
  echo After installing Python, run this file again.
  pause
  exit /b 1
)

rem Run the universal launcher (logic is in start.py)
%PY% start.py

endlocal
