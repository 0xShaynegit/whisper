@echo off
cd /d C:\whisper\whisper-writer

echo Testing with model loaded before Qt...
echo.

"C:\whisper\whisper-writer\venv\Scripts\python.exe" "C:\whisper\whisper-writer\test_app.py"

echo.
echo Exit code: %errorlevel%
pause
