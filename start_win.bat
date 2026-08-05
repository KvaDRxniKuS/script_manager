@echo off
setlocal EnableExtensions EnableDelayedExpansion
rem ============================================================
rem  App launcher (Windows)
rem  Double-click: update index.html + start server + open browser
rem
rem  SETTINGS:
rem  Set REPO_RAW to your public repo index.html raw URL.
rem  Leave empty to skip auto-update.
rem ============================================================

set "REPO_RAW=https://raw.githubusercontent.com/KvaDRxniKuS/script_manager/main/index.html"

rem Move to the folder of this script
cd /d "%~dp0"

echo.
echo App launcher
echo ------------
echo Folder: %CD%
echo.

rem --- Download fresh index.html (if network available) ---
set "TMP=%TEMP%\script_manager_index.html"
if exist "%TMP%" del "%TMP%" >nul 2>nul

if not "%REPO_RAW%"=="" (
  echo Checking for updates...
  where curl >nul 2>nul
  if !errorlevel!==0 (
    curl -sL "%REPO_RAW%" -o "%TMP%"
  ) else (
    powershell -NoProfile -Command "try { Invoke-WebRequest -Uri '%REPO_RAW%' -OutFile '%TMP%' } catch { }" >nul 2>nul
  )
) else (
  echo Auto-update disabled (REPO_RAW empty)
)

rem --- If repo has a file, compare versions and maybe replace ---
if not exist "%TMP%" goto :no_update
if not exist "index.html" (
  rem No local file yet - just save the downloaded one
  call :strip_cf "%TMP%" "index.html"
  echo [OK] Downloaded index.html
  goto :after_update
)

set "REMOTE_VER="
for /f "delims=" %%l in ('findstr /r "v0\.[0-9][0-9]*" "%TMP%"') do if not defined REMOTE_VER set "REMOTE_VER=%%l"
set "LOCAL_VER="
for /f "delims=" %%l in ('findstr /r "v0\.[0-9][0-9]*" "index.html"') do if not defined LOCAL_VER set "LOCAL_VER=%%l"

echo    Local version : !LOCAL_VER!
echo    Repo version  : !REMOTE_VER!

if "!REMOTE_VER!"=="" (
  echo    [WARN] Could not read version from repo - skipping update
  del "%TMP%" >nul 2>nul
  goto :after_update
)
if "!REMOTE_VER!"=="!LOCAL_VER!" (
  echo    [OK] index.html is up to date
  del "%TMP%" >nul 2>nul
  goto :after_update
)

echo    A newer version is available.
set /p ANS="   Update local file? (y/N): "
if /I "!ANS!"=="y" (
  copy /y "index.html" "index.html.bak" >nul 2>nul
  call :strip_cf "%TMP%" "index.html"
  echo    [OK] Updated. Old version kept as index.html.bak
) else (
  echo    Skipping update (keeping current version)
  del "%TMP%" >nul 2>nul
)
goto :after_update

:strip_cf
rem %1 = source (downloaded, may contain CF beacon), %2 = destination
powershell -NoProfile -Command "$c = Get-Content -Raw '%1'; $i = $c.IndexOf('<script>(function(){function c(){'); if ($i -ge 0) { $c = $c.Substring(0,$i) }; Set-Content -Path '%2' -Value $c -NoNewline -Encoding UTF8"
exit /b

:after_update
if exist "%TMP%" del "%TMP%" >nul 2>nul

:no_update

rem --- Python check ---
where python >nul 2>nul
if %errorlevel%==0 ( set "PY=python" ) else (
  where py >nul 2>nul
  if %errorlevel%==0 ( set "PY=py -3" ) else (
    echo [ERR] Python not found. Install from https://www.python.org/downloads/
    pause
    exit /b 1
  )
)

rem --- Start server in background (same window, no extra console) ---
set "PORT=8000"
echo Starting server on http://127.0.0.1:%PORT% ...
start "" /b cmd /c "%PY% -m http.server %PORT% >nul 2>&1"
timeout /t 2 /nobreak >nul

rem --- Open browser ---
start "" "http://127.0.0.1:%PORT%/index.html"
echo.
echo Done! Server runs in background.
echo To stop it, close this window or run: taskkill /f /im python.exe
echo.
pause
endlocal
