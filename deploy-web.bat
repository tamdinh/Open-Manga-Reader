@echo off
setlocal
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy-web.ps1" %*
if %ERRORLEVEL% neq 0 (
    echo.
    echo Deployment encountered an error (Code: %ERRORLEVEL%).
    pause
    exit /b %ERRORLEVEL%
)
echo.
pause
