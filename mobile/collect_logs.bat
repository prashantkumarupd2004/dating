@echo off
echo ========================================
echo MILAN DATING APP - LOG COLLECTOR
echo ========================================
echo.

REM Check if ADB is available
where adb >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] ADB not found in PATH
    echo Please run this script from platform-tools folder
    echo OR add platform-tools to your PATH
    pause
    exit /b 1
)

echo [1/5] Checking connected devices...
adb devices
echo.

echo [2/5] Clearing old logs...
adb logcat -c
echo Logs cleared!
echo.

echo [3/5] Starting log collection...
echo Logs will be saved to: milan_app_logs.txt
echo.
echo NOW USE THE APP FOR 5 MINUTES:
echo - Login
echo - Navigate between tabs
echo - Make a call
echo - Recharge coins
echo - Background/Resume app
echo.
echo Press Ctrl+C to stop logging when done
echo.

REM Collect all logs to file
adb logcat > milan_app_logs.txt

echo.
echo [4/5] Logs saved to milan_app_logs.txt
echo.

echo [5/5] Searching for 429 errors...
findstr /C:"429" /C:"DioException" /C:"bad response" milan_app_logs.txt > 429_errors.txt

echo.
echo ========================================
echo DONE! Check these files:
echo - milan_app_logs.txt (all logs)
echo - 429_errors.txt (only 429 errors)
echo ========================================
pause
