@echo off
cd /d C:\whisper\whisper-writer
set HF_HOME=C:\whisper\models
set HF_HUB_DISABLE_SYMLINKS_WARNING=1

start "" "C:\whisper\whisper-writer\venv\Scripts\pythonw.exe" "C:\whisper\whisper-writer\launcher.pyw"
