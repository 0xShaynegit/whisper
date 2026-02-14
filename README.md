# WhisperWriter

Speech-to-text using OpenAI's Whisper model. Hold a key, speak, release -- text is typed at your cursor. Runs entirely offline using [faster-whisper](https://github.com/SYSTRAN/faster-whisper).

## Quick Start

### Ubuntu / Linux

```bash
cd /path/to/whisper
bash setup-ubuntu.sh
```

The script checks prerequisites, tells you exactly what to install if anything is missing, then copies everything to `/opt/whisper` and creates a venv. After setup:

```bash
whisper-writer          # from anywhere (if ~/.local/bin is in PATH)
# or
/opt/whisper/whisper-writer/start.sh
```

See [UBUNTU_SETUP.md](UBUNTU_SETUP.md) for the full guide.

### Windows

Already configured at `C:\whisper`. See [SETUP_NOTES.md](SETUP_NOTES.md) for details.

- Run: `whisper-writer\start.bat` or desktop shortcut
- Auto-starts with Windows via Startup folder shortcut

## How It Works

1. App loads the Whisper model into memory (base model ~1 GB RAM)
2. Listens for the activation key (INSERT by default)
3. While held, records audio from your microphone
4. On release, transcribes audio locally with faster-whisper
5. Types the transcribed text at your current cursor position

**Important:** The Whisper model must be loaded *before* PyQt5 initializes, otherwise the app crashes. `launcher.pyw` handles this by pre-loading the model and monkey-patching it into the transcription module.

## Directory Structure

### Source (this directory)

```
whisper/
├── README.md              # This file
├── SETUP_NOTES.md         # Windows setup notes and history
├── UBUNTU_SETUP.md        # Ubuntu/Linux setup guide
├── setup-ubuntu.sh        # Automated Ubuntu setup script
├── models/                # Cached Whisper model weights (cross-platform)
└── whisper-writer/        # Application source
    ├── src/               # Python source code
    │   ├── main.py        # App entry point (WhisperWriterApp)
    │   ├── transcription.py
    │   ├── key_listener.py        # evdev (Wayland) + pynput (X11)
    │   ├── input_simulation.py    # pynput / ydotool / dotool
    │   ├── utils.py               # ConfigManager
    │   ├── config.yaml            # User configuration
    │   ├── config_schema.yaml     # Schema and defaults
    │   └── ui/                    # PyQt5 UI components
    ├── assets/            # Icons and sounds
    ├── launcher.pyw       # Launcher (pre-loads model before Qt)
    ├── requirements.txt   # Python dependencies
    ├── run.py             # Original entry point (bypassed by launcher)
    ├── start.bat          # Windows launcher
    └── debug.bat          # Windows debug launcher
```

### Linux install (`/opt/whisper`)

```
/opt/whisper/
├── whisper-writer/
│   ├── src/config.yaml    # Edit this to configure
│   ├── start.sh           # Launch script (created by setup)
│   ├── launcher.pyw       # Python launcher (patched paths)
│   └── venv/              # Linux Python environment
├── models/                # Whisper model weights
└── setup-ubuntu.sh        # Re-run to update
```

## Configuration

Edit the config file:
- **Linux:** `/opt/whisper/whisper-writer/src/config.yaml`
- **Windows:** `C:\whisper\whisper-writer\src\config.yaml`

Restart the app after any changes.

### Key settings

```yaml
model_options:
  local:
    model: base            # base, small, or medium
    device: cpu
    compute_type: float32

recording_options:
  activation_key: INSERT   # INSERT, PAUSE, SCROLL_LOCK, F1-F12
  input_backend: auto      # auto, evdev (Wayland), pynput (X11)
  recording_mode: hold_to_record

post_processing:
  input_method: pynput     # pynput (X11), ydotool (Wayland), dotool
```

### `input_backend` vs `input_method`

| Setting         | What it does                | Wayland            | X11     |
|-----------------|-----------------------------|--------------------|---------|
| `input_backend` | Listens for activation key  | `evdev`            | `pynput`|
| `input_method`  | Types the transcribed text  | `ydotool`/`dotool` | `pynput`|

The setup script auto-configures these based on your display server. Use `auto` for `input_backend` to let the app decide at runtime.

## Model Options

| Model  | RAM   | Speed  | Accuracy | Download |
|--------|-------|--------|----------|----------|
| base   | ~1 GB | Fast   | Good     | ~150 MB  |
| small  | ~2 GB | Medium | Better   | ~500 MB  |
| medium | ~3 GB | Slow   | Best     | ~1.5 GB  |

Models are cached in `models/` and are platform-independent (copy them between Windows and Linux).

## Wayland vs X11

| Feature          | X11 (pynput)         | Wayland (evdev + ydotool)     |
|------------------|----------------------|-------------------------------|
| Key listening    | Works out of the box | Needs `input` group membership|
| Text injection   | Works out of the box | Needs `ydotool` daemon        |
| Qt rendering     | Native               | Uses XWayland (`QT_QPA_PLATFORM=xcb`) |

The setup script detects Wayland and configures everything automatically.

## Dependencies

**System:** `ffmpeg`, `portaudio19-dev`, `libxcb-xinerama0`, `libxcb-cursor0`, `libxkbcommon-x11-0`, `python3-gi`, `build-essential`

**Python:** `faster-whisper`, `PyQt5`, `pynput`, `evdev`, `sounddevice`, `soundfile`, `PyYAML`, `python-dotenv`, `openai`, `httpx`, `coloredlogs`, `audioplayer`, `webrtcvad-wheels`, `tqdm`, `pyperclip`, `numpy`, `ctranslate2`, `huggingface-hub`, `tokenizers`

The `venv/` directory is **not portable** between operating systems. The setup script creates a fresh one on the target platform with `--system-site-packages` (needed for PyGObject/gi access).
