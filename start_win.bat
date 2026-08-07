@echo off
rem ============================================================
rem  App launcher (Windows) - runs start.py
rem  Smart Python handling:
rem    1) if python.exe exists            -> run
rem    2) if no python but py launcher exists -> auto "py install default",
rem       wait, add to PATH, then run
rem    3) if neither                       -> open download page
rem ============================================================
setlocal EnableExtensions

cd /d "%~dp0"
echo.
echo App launcher
echo ------------
echo.

rem ---------- Locate Python ----------
set "PY="

rem 1) real python.exe on PATH
where python >nul 2>nul && set "PY=python"

rem 2) common install locations (installed without PATH)
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
if not defined PY if exist "%LOCALAPPDATA%\Programs\Python\Python39\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
if not defined PY if exist "%ProgramFiles%\Python313\python.exe" set "PY=%ProgramFiles%\Python313\python.exe"
if not defined PY if exist "%ProgramFiles%\Python312\python.exe" set "PY=%ProgramFiles%\Python312\python.exe"
if not defined PY if exist "%ProgramFiles%\Python311\python.exe" set "PY=%ProgramFiles%\Python311\python.exe"
if not defined PY if exist "%ProgramFiles%\Python310\python.exe" set "PY=%ProgramFiles%\Python310\python.exe"
if not defined PY if exist "%ProgramFiles%\Python39\python.exe" set "PY=%ProgramFiles%\Python39\python.exe"

rem ---------- If Python not found ----------
if defined PY goto :found_python

rem Does the py launcher exist?
where py >nul 2>nul
if %errorlevel%==0 (
  echo Python interpreter not found, but the 'py' launcher exists.
  echo Installing default Python runtime...
  py install default
  echo.
  echo Installation finished. Adding Python to PATH...
  rem Find the python.exe that py just installed
  set "PY="
  if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
  if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
  if exist "%LOCALAPPDATA%\Programs\Python\Python311\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python311\python.exe"
  if exist "%LOCALAPPDATA%\Programs\Python\Python310\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python310\python.exe"
  if exist "%LOCALAPPDATA%\Programs\Python\Python39\python.exe" set "PY=%LOCALAPPDATA%\Programs\Python\Python39\python.exe"
  if exist "%ProgramFiles%\Python313\python.exe" set "PY=%ProgramFiles%\Python313\python.exe"
  if exist "%ProgramFiles%\Python312\python.exe" set "PY=%ProgramFiles%\Python312\python.exe"
  if exist "%ProgramFiles%\Python311\python.exe" set "PY=%ProgramFiles%\Python311\python.exe"
  if exist "%ProgramFiles%\Python310\python.exe" set "PY=%ProgramFiles%\Python310\python.exe"
  if exist "%ProgramFiles%\Python39\python.exe" set "PY=%ProgramFiles%\Python39\python.exe"
  rem fall back to launcher
  if not defined PY set "PY=py -3"
  goto :found_python
)

rem ---------- Neither python nor py ----------
echo [ERR] Python is not installed.
echo.
echo Please install Python (Python Install Manager) and re-run this launcher.
echo   https://www.python.org/downloads/
echo.
start "" "https://www.python.org/downloads/"
echo.
pause
exit /b 1

:found_python
echo Using Python: %PY%
echo.
%PY% start.py
set "EXITCODE=%errorlevel%"

if not "%EXITCODE%"=="0" (
  echo.
  echo [ERR] start.py failed with code %EXITCODE%. See messages above.
  pause
)

endlocal
