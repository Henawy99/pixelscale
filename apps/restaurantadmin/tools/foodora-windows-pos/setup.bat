@echo off
setlocal
cd /d "%~dp0"

echo ===================================================
echo   Foodora Relay Setup for Windows POS
echo ===================================================
echo.

where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [!] Node.js is not detected on this system.
    echo [*] Installing Node.js LTS via winget...
    winget install OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo [X] Automatic install failed. Please download and install Node.js from:
        echo     https://nodejs.org
        echo     After installing, please run setup.bat again.
        pause
        exit /b 1
    )
    echo [*] Node.js installed successfully! Please close and re-open this window if needed.
) else (
    echo [OK] Node.js is installed.
)

echo.
echo [*] Installing required lightweight dependencies...
call npm install --no-audit --no-fund

echo.
echo ===================================================
echo   [OK] Setup complete!
echo ===================================================
echo.
echo Next steps:
echo 1. Run start.bat once to open Chrome and log in to Foodora.
echo 2. Run add_to_startup.bat to make it start automatically with Windows.
echo.
pause
