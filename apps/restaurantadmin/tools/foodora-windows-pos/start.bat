@echo off
setlocal
cd /d "%~dp0"
title Foodora Live Order Relay
echo Starting Foodora Live Order Relay...
node relay.mjs
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Relay stopped unexpectedly.
    pause
)
