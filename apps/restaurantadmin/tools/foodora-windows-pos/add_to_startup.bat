@echo off
setlocal
cd /d "%~dp0"

echo Adding Foodora Relay to Windows Startup...

set "SCRIPT_DIR=%~dp0"
set "TARGET=%SCRIPT_DIR%start_hidden.vbs"
set "SHORTCUT=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\FoodoraRelay.lnk"

powershell -Command "$ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('%SHORTCUT%'); $s.TargetPath = 'wscript.exe'; $s.Arguments = '\"%TARGET%\"'; $s.WorkingDirectory = '%SCRIPT_DIR%'; $s.Save()"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================================
    echo  [SUCCESS] Foodora Relay added to Windows Startup!
    echo  It will now start automatically whenever your PC boots.
    echo =========================================================
) else (
    echo.
    echo [ERROR] Could not create startup shortcut.
)

echo.
pause
