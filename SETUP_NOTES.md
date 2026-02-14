# WhisperWriter Setup Notes
*Created: 2026-02-02*

## What Is It
WhisperWriter is a speech-to-text app using OpenAI's Whisper model. Hold a key, speak, release - text is typed at your cursor.

## Installation Location
- App: `C:\whisper\whisper-writer`
- Models: `C:\whisper\models`
- Python: `C:\Program Files\Python311` (Python 3.11 required)

## How to Run
- **Desktop shortcut:** WhisperWriter
- **Or run:** `C:\whisper\whisper-writer\start.bat`
- **Auto-starts with Windows:** Yes (shortcut in Startup folder)

## Usage
- **Hold Insert key** → speak → **release** → text is typed
- A small "WhisperWriter" status window appears while recording

## Configuration
Edit `C:\whisper\whisper-writer\src\config.yaml`:

```yaml
model_options:
  local:
    model: base          # Options: base (fast), small, medium (slow but accurate)
    device: cpu
    compute_type: float32

recording_options:
  activation_key: INSERT  # Options: F1-F12, INSERT, PAUSE, SCROLL_LOCK, etc.
  recording_mode: hold_to_record
```

Restart app after changes.

## Available Models
| Model  | Memory | Speed  | Accuracy |
|--------|--------|--------|----------|
| base   | ~1GB   | Fast   | Good     |
| small  | ~2GB   | Medium | Better   |
| medium | ~3GB   | Slow   | Best     |

## Key Issues We Solved

### 1. Qt + Model Crash
Loading the Whisper model AFTER PyQt5 caused crashes. Fixed by creating `launcher.pyw` that loads the model BEFORE Qt.

### 2. Activation Key
- `]` and backtick (`) type characters while recording
- F-keys required Fn on external keyboard
- **Solution:** Use INSERT key - single key, no output

### 3. Config Path
App looks for config at `src/config.yaml` relative to working directory. Must run from `C:\whisper\whisper-writer`.

## Files Created
- `start.bat` - Main launcher
- `launcher.pyw` - Fixed Python launcher (loads model before Qt)
- `debug.bat` - For troubleshooting
- `test_app.py` - Debug version with console output
- `test_model.py` - Tests model loading without Qt

## Removing from Startup
Delete: `C:\Users\Shayne\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\WhisperWriter.lnk`

## Reinstalling/Updating
```batch
cd C:\whisper\whisper-writer
git pull
venv\Scripts\pip install -r requirements.txt
```

## File Count
~16,700 files / 1,600 folders - mostly Python dependencies (PyQt5, numpy, etc.). Normal for Python apps.
