# WhisperWriter -- Ubuntu/Linux Setup Guide

## Prerequisites

- Ubuntu 22.04+ (or any Debian-based distro with systemd)
- A desktop environment (GNOME, KDE, etc.)
- A working microphone
- Python 3.11+ (the setup script auto-detects 3.11/3.12/3.13)

### One-time system setup

The setup script will check for these and tell you exactly what commands to run if anything is missing. You can also do them in advance:

```bash
# 1. Install system packages
sudo apt update && sudo apt install -y \
    python3.12 python3.12-venv python3.12-dev \
    build-essential ffmpeg portaudio19-dev \
    libxcb-xinerama0 libxcb-cursor0 libxkbcommon-x11-0 \
    python3-gi gir1.2-gstreamer-1.0

# 2. Create install directory (writable by your user)
sudo mkdir -p /opt/whisper && sudo chown $USER:$USER /opt/whisper

# 3. Add yourself to the input group (needed for evdev key listening on Wayland)
sudo usermod -aG input $USER

# 4. Allow ydotool to access /dev/uinput (needed for Wayland text injection)
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/80-uinput.rules
sudo udevadm control --reload-rules && sudo udevadm trigger /dev/uinput

# 5. Install and start ydotool (Wayland only)
sudo apt install -y ydotool
sudo systemctl enable --now ydotool

# 6. Log out and back in (for the input group change to take effect)
```

Steps 3-5 are only needed on Wayland (Ubuntu 22.10+ default). On X11 you can skip them.

## Quick Setup (Automated)

```bash
# Copy the entire whisper/ directory to your machine, then:
cd /path/to/whisper
bash setup-ubuntu.sh
```

## What the Setup Script Does

Here is exactly what `setup-ubuntu.sh` does, in order:

1. **Pre-flight checks** -- verifies Python 3.11+, venv module, gcc, ffmpeg, portaudio, Qt libs, python3-gi, `/opt/whisper` writable, input group, uinput rule. If anything is missing, prints the exact `sudo` commands needed and exits.
2. **Detects display server** -- reads `$XDG_SESSION_TYPE`. If Wayland, verifies `ydotool` is installed.
3. **Copies files** -- `rsync`s `whisper-writer/` (excluding `venv/` and `.git/`) and `models/` to `/opt/whisper`. Also copies docs and the setup script itself.
4. **Creates venv** -- removes any old venv, runs `python3.X -m venv --system-site-packages /opt/whisper/whisper-writer/venv` (`--system-site-packages` gives access to the system `gi` module).
5. **Installs Python packages** -- `pip install` of all dependencies listed in the script (faster-whisper, PyQt5, pynput, evdev, etc.).
6. **Writes `launcher.pyw`** -- generates a Linux-patched launcher that sets `INSTALL_DIR=/opt/whisper`, pre-loads the Whisper model, then starts the app.
7. **Writes `start.sh`** -- generates a launch script with PID-file duplicate detection and `QT_QPA_PLATFORM=xcb` for Wayland.
8. **Creates symlink** -- `~/.local/bin/whisper-writer` -> `/opt/whisper/whisper-writer/start.sh`.
9. **Configures Wayland** -- if Wayland, patches `config.yaml` to set `input_backend: evdev` and `input_method: ydotool`.
10. **Desktop entry** -- writes `~/.local/share/applications/whisper-writer.desktop`. Optionally copies to `~/.config/autostart/` for auto-start on login.

## After Setup

```bash
# Run from anywhere:
whisper-writer

# Or from app launcher: search "WhisperWriter"

# Or directly:
/opt/whisper/whisper-writer/start.sh
```

## Install Layout

```
/opt/whisper/
├── whisper-writer/
│   ├── src/
│   │   ├── config.yaml          # App configuration (edit this)
│   │   ├── config_schema.yaml   # Config schema and defaults
│   │   ├── main.py              # Main app entry point
│   │   ├── transcription.py     # Whisper transcription
│   │   ├── key_listener.py      # Keyboard handling (evdev + pynput)
│   │   ├── input_simulation.py  # Text injection (pynput/ydotool/dotool)
│   │   ├── utils.py             # ConfigManager
│   │   └── ui/                  # PyQt5 UI components
│   ├── assets/                  # Icons and sounds
│   ├── launcher.pyw             # Launcher (loads model before Qt)
│   ├── start.sh                 # Linux start script
│   ├── venv/                    # Python virtual environment
│   └── requirements.txt         # Python dependencies
├── models/                      # Cached Whisper model weights
├── README.md
├── UBUNTU_SETUP.md
└── setup-ubuntu.sh
```

## Manual Setup

If the script doesn't work or you prefer doing it yourself:

### 1. Install system dependencies

```bash
sudo apt update
sudo apt install -y python3.12 python3.12-venv python3.12-dev \
    build-essential ffmpeg portaudio19-dev \
    libxcb-xinerama0 libxcb-cursor0 libxkbcommon-x11-0 \
    python3-gi gir1.2-gstreamer-1.0
```

### 2. Create install directory and copy files

```bash
sudo mkdir -p /opt/whisper && sudo chown $USER:$USER /opt/whisper
rsync -a --exclude='venv' --exclude='.git' whisper-writer/ /opt/whisper/whisper-writer/
rsync -a models/ /opt/whisper/models/
```

### 3. Create Python virtual environment

**Important:** Use `--system-site-packages` so the venv can access the system `python3-gi` (PyGObject) package. Without this, imports of `gi` will fail.

```bash
python3.12 -m venv --system-site-packages /opt/whisper/whisper-writer/venv
/opt/whisper/whisper-writer/venv/bin/pip install --upgrade pip
/opt/whisper/whisper-writer/venv/bin/pip install \
    faster-whisper PyQt5 pynput sounddevice soundfile \
    PyYAML python-dotenv openai httpx coloredlogs audioplayer \
    webrtcvad-wheels tqdm pyperclip evdev numpy ctranslate2 \
    huggingface-hub tokenizers
```

### 4. Update launcher.pyw paths

Edit `/opt/whisper/whisper-writer/launcher.pyw` and set:

```python
INSTALL_DIR = '/opt/whisper'
APP_DIR = os.path.join(INSTALL_DIR, 'whisper-writer')
MODEL_DIR = os.path.join(INSTALL_DIR, 'models')
```

### 5. Create start script and symlink

```bash
# Create ~/.local/bin if it doesn't exist
mkdir -p ~/.local/bin
ln -sf /opt/whisper/whisper-writer/start.sh ~/.local/bin/whisper-writer
```

### 6. Create desktop entry

```bash
mkdir -p ~/.local/share/applications
cat > ~/.local/share/applications/whisper-writer.desktop << 'EOF'
[Desktop Entry]
Name=WhisperWriter
Comment=Speech-to-text with Whisper - hold INSERT, speak, release
Exec=/opt/whisper/whisper-writer/start.sh
Icon=/opt/whisper/whisper-writer/assets/ww-logo.png
Terminal=false
Type=Application
Categories=Utility;Audio;
EOF
```

### 7. Run it

```bash
whisper-writer
# or
/opt/whisper/whisper-writer/start.sh
```

## What Gets Reused from Windows

| Component | Portable? | Notes |
|-----------|-----------|-------|
| Source code (`whisper-writer/src/`) | Yes | Pure Python, cross-platform |
| Config (`src/config.yaml`) | Yes | Works as-is (defaults are cross-platform) |
| Whisper models (`models/`) | Yes | Platform-independent weights |
| `launcher.pyw` | Needs path edit | Setup script regenerates it |
| `venv/` | No | Must recreate on Linux |
| `.bat` / `.ps1` files | No | Replaced by `.sh` scripts |

## Wayland vs X11

The app supports both display servers:

- **X11**: Everything works out of the box with `pynput` for both key listening and text injection.
- **Wayland**: The setup script auto-configures:
  - `evdev` backend for key listening (reads `/dev/input/event*` directly)
  - `ydotool` for text injection (writes to `/dev/uinput` via the ydotool daemon)
  - `QT_QPA_PLATFORM=xcb` for PyQt5 rendering (uses XWayland)

### Required for Wayland

1. **`input` group** -- your user must be in the `input` group to read keyboard events via evdev
2. **uinput rule** -- `/dev/uinput` must be group-writable by `input` so ydotool can inject keystrokes
3. **ydotool daemon** -- `sudo systemctl enable --now ydotool` must be running

## Configuration

Edit `/opt/whisper/whisper-writer/src/config.yaml`:

```yaml
model_options:
  local:
    model: base          # base (fast), small (better), medium (best but slow)
    device: cpu
    compute_type: float32

recording_options:
  activation_key: INSERT  # INSERT, PAUSE, SCROLL_LOCK, F1-F12
  input_backend: auto     # auto, evdev (Wayland), pynput (X11)
  recording_mode: hold_to_record

post_processing:
  input_method: pynput    # pynput (X11), ydotool (Wayland), dotool
```

Restart the app after changing config.

## Autostart on Login

The setup script can add WhisperWriter to autostart. To do it manually:

```bash
cp ~/.local/share/applications/whisper-writer.desktop ~/.config/autostart/
```

To remove from autostart:

```bash
rm ~/.config/autostart/whisper-writer.desktop
```

## Troubleshooting

### ydotool: "Failed to open /dev/uinput" or no text output

```bash
# Check the daemon is running
sudo systemctl status ydotool

# Start it if not
sudo systemctl enable --now ydotool

# Check /dev/uinput permissions
ls -la /dev/uinput
# Should show: crw-rw---- 1 root input ...

# If not, add the udev rule:
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/80-uinput.rules
sudo udevadm control --reload-rules && sudo udevadm trigger /dev/uinput

# Verify your user is in the input group
id -nG | grep input
# If not: sudo usermod -aG input $USER && log out/in
```

### evdev: "PermissionError" or "No such device"

```bash
# Your user must be in the input group
sudo usermod -aG input $USER
# Log out and back in for the group change to take effect

# Verify:
id -nG | grep input
```

### gi module: "No module named 'gi'"

This means the venv was created without `--system-site-packages`. Recreate it:

```bash
rm -rf /opt/whisper/whisper-writer/venv
python3.12 -m venv --system-site-packages /opt/whisper/whisper-writer/venv
/opt/whisper/whisper-writer/venv/bin/pip install --upgrade pip
/opt/whisper/whisper-writer/venv/bin/pip install \
    faster-whisper PyQt5 pynput sounddevice soundfile \
    PyYAML python-dotenv openai httpx coloredlogs audioplayer \
    webrtcvad-wheels tqdm pyperclip evdev
```

Also ensure the system package is installed: `sudo apt install python3-gi`

### Stale PID file: "WhisperWriter is already running" but it isn't

```bash
rm /tmp/whisper-writer-$USER.pid
whisper-writer
```

### No audio input

```bash
# Check if your mic is detected
/opt/whisper/whisper-writer/venv/bin/python -c "import sounddevice; print(sounddevice.query_devices())"
```

### PyQt5 display errors on Wayland

```bash
# The start.sh script sets this automatically, but if running manually:
export QT_QPA_PLATFORM=xcb
/opt/whisper/whisper-writer/venv/bin/python /opt/whisper/whisper-writer/launcher.pyw
```

### Model download hangs

The `models/` directory from Windows should already have cached models. If not, the first run will download them (~150 MB for the base model). Check your internet connection.

## Updating

To update after pulling new source code:

```bash
cd /path/to/whisper
bash setup-ubuntu.sh
```

The script will re-copy files and recreate the venv. Your `config.yaml` in `/opt/whisper` will be preserved (rsync overwrites only changed files, and the Wayland config step re-applies settings).
