@echo off
rem ============================================================
rem  App launcher (Windows) - runs start.py
rem  Double-click: finds Python, runs start.py (server + browser)
rem  Window stays open on error so you can read the message.
rem ============================================================
setlocal EnableExtensions

cd /d "%~dp0"
echo.
echo App launcher
echo ------------
echo.

rem --- Find a python interpreter (even if not in PATH) ---
set "PY="

rem 1) standard PATH lookup
where python >nul 2>nul && set "PY=python"
if not defined PY ( where py >nul 2>nul && set "PY=py -3" )

rem 2) common install locations (in case Python was installed without PATH)
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python39\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
if not defined PY if exist "%ProgramFiles%\Python313\python.exe" set "PY=%ProgramFiles%\Python313\python.exe"
if not defined PY if exist "%ProgramFiles%\Python312\python.exe" set "PY=%ProgramFiles%\Python312\python.exe"
if not defined PY if exist "%ProgramFiles%\Python311\python.exe" set "PY=%ProgramFiles%\Python311\python.exe"
if not defined PY if exist "%ProgramFiles%\Python310\python.exe" set "PY=%ProgramFiles%\Python310\python.exe"
if not defined PY if exist "%ProgramFiles%\Python39\python.exe" set "PY=%ProgramFiles%\Python39\python.exe"

if not defined PY (
  echo [ERR] Python was not found.
  echo.
  echo Please install Python and make sure to tick
  echo   "Add python.exe to PATH" during installation.
  echo   https://www.python.org/downloads/
  echo.
  start "" "https://www.python.org/downloads/"
  echo.
  pause
  exit /b 1
)

echo Using Python: %PY%
echo.

rem --- Run the launcher. Keep window open if it errors. ---
%PY% start.py
set "EXITCODE=%errorlevel%"

if not "%EXITCODE%"=="0" (
  echo.
  echo [ERR] start.py failed with code %EXITCODE%. See messages above.
  pause
)

endlocal
