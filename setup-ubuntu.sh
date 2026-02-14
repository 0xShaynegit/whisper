#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# WhisperWriter - Ubuntu/Linux Setup Script
# Installs WhisperWriter to /opt/whisper for all users.
# No sudo required - just run: bash setup-ubuntu.sh
#
# Prerequisites (one-time, needs sudo):
#   sudo mkdir -p /opt/whisper && sudo chown $USER:$USER /opt/whisper
#   sudo apt install ffmpeg portaudio19-dev libxcb-xinerama0 \
#       libxcb-cursor0 libxkbcommon-x11-0 python3.12-venv python3.12-dev
# ============================================================

INSTALL_DIR="/opt/whisper"
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$INSTALL_DIR/whisper-writer"
MODEL_DIR="$INSTALL_DIR/models"

# --- Find a usable Python >= 3.11 ---
find_python() {
    for py in python3.12 python3.11 python3.13 python3; do
        if command -v "$py" &> /dev/null; then
            local ver
            ver="$("$py" --version 2>&1 | awk '{print $2}')"
            local major minor
            major="$(echo "$ver" | cut -d. -f1)"
            minor="$(echo "$ver" | cut -d. -f2)"
            if [ "$major" -ge 3 ] && [ "$minor" -ge 11 ]; then
                echo "$py"
                return 0
            fi
        fi
    done
    return 1
}

echo "========================================"
echo " WhisperWriter - Linux Setup"
echo "========================================"
echo ""
echo "Source directory:  $SOURCE_DIR"
echo "Install directory: $INSTALL_DIR"
echo ""

# --- Pre-flight checks ---
MISSING_PKGS=()
MISSING_CMDS=()

# Check Python
PYTHON_CMD=""
if ! PYTHON_CMD=$(find_python); then
    MISSING_PKGS+=("python3.12" "python3.12-venv" "python3.12-dev")
    MISSING_CMDS+=("python3.12")
fi

# Check if venv module works (need ensurepip, not just venv)
if [ -n "$PYTHON_CMD" ]; then
    if ! "$PYTHON_CMD" -c "import ensurepip" 2>/dev/null; then
        PY_VER="$($PYTHON_CMD --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)"
        MISSING_PKGS+=("python${PY_VER}-venv")
    fi
    PY_VER="$($PYTHON_CMD --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)"
    if ! dpkg -s "python${PY_VER}-dev" &>/dev/null 2>&1; then
        MISSING_PKGS+=("python${PY_VER}-dev")
    fi
fi

# Check for C compiler (needed to build evdev)
command -v gcc &>/dev/null || MISSING_PKGS+=("build-essential")

# Check system libraries
command -v ffmpeg &>/dev/null || { MISSING_PKGS+=("ffmpeg"); MISSING_CMDS+=("ffmpeg"); }
[ -f /usr/lib/x86_64-linux-gnu/libportaudio.so.2 ] || [ -f /usr/lib/x86_64-linux-gnu/libportaudio.so ] || \
    dpkg -s portaudio19-dev &>/dev/null 2>&1 || MISSING_PKGS+=("portaudio19-dev")
dpkg -s libxcb-xinerama0 &>/dev/null 2>&1 || MISSING_PKGS+=("libxcb-xinerama0")
dpkg -s libxcb-cursor0 &>/dev/null 2>&1 || MISSING_PKGS+=("libxcb-cursor0")
dpkg -s libxkbcommon-x11-0 &>/dev/null 2>&1 || MISSING_PKGS+=("libxkbcommon-x11-0")
dpkg -s python3-gi &>/dev/null 2>&1 || MISSING_PKGS+=("python3-gi")
dpkg -s gir1.2-gstreamer-1.0 &>/dev/null 2>&1 || MISSING_PKGS+=("gir1.2-gstreamer-1.0")

# Check if /opt/whisper exists and is writable
NEED_DIR=false
if [ ! -d "$INSTALL_DIR" ]; then
    NEED_DIR=true
elif [ ! -w "$INSTALL_DIR" ]; then
    NEED_DIR=true
fi

# Check if user is in 'input' group (needed for evdev on Wayland)
NEED_INPUT_GROUP=false
if ! id -nG "$USER" | grep -qw input; then
    NEED_INPUT_GROUP=true
fi

# Check if /dev/uinput is accessible (needed for ydotool on Wayland)
NEED_UINPUT_RULE=false
if [ ! -w /dev/uinput ] 2>/dev/null; then
    NEED_UINPUT_RULE=true
fi

# --- If anything is missing, print instructions and exit ---
if [ ${#MISSING_PKGS[@]} -gt 0 ] || [ "$NEED_DIR" = true ] || [ "$NEED_INPUT_GROUP" = true ] || [ "$NEED_UINPUT_RULE" = true ]; then
    echo "Some prerequisites are missing. Please run these commands first:"
    echo ""

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo "  sudo apt update && sudo apt install -y ${MISSING_PKGS[*]}"
        echo ""
    fi

    if [ "$NEED_DIR" = true ]; then
        echo "  sudo mkdir -p /opt/whisper && sudo chown \$USER:\$USER /opt/whisper"
        echo ""
    fi

    if [ "$NEED_INPUT_GROUP" = true ]; then
        echo "  sudo usermod -aG input \$USER"
        echo "  (then log out and back in for the group change to take effect)"
        echo ""
    fi

    if [ "$NEED_UINPUT_RULE" = true ]; then
        echo "  echo 'KERNEL==\"uinput\", GROUP=\"input\", MODE=\"0660\"' | sudo tee /etc/udev/rules.d/80-uinput.rules"
        echo "  sudo udevadm control --reload-rules && sudo udevadm trigger /dev/uinput"
        echo ""
    fi

    echo "Then re-run this script:"
    echo "  bash setup-ubuntu.sh"
    exit 1
fi

echo "[OK] All prerequisites met."
echo "  Python: $PYTHON_CMD ($($PYTHON_CMD --version 2>&1))"
echo ""

# --- Step 1: Detect display server ---
echo "[1/6] Detecting display server..."
DISPLAY_SERVER="${XDG_SESSION_TYPE:-unknown}"
echo "  Session type: $DISPLAY_SERVER"

if [ "$DISPLAY_SERVER" = "wayland" ]; then
    echo "  Wayland detected. Will configure evdev backend for key listening."
    if ! command -v ydotool &>/dev/null; then
        echo ""
        echo "  ERROR: ydotool is required on Wayland for text input."
        echo "  Please install it first:"
        echo "    sudo apt install -y ydotool"
        echo "    sudo systemctl enable --now ydotool"
        echo ""
        echo "  Then re-run this script."
        exit 1
    fi
fi

# --- Step 2: Copy files to /opt/whisper ---
echo ""
echo "[2/6] Installing to $INSTALL_DIR..."

if [ "$SOURCE_DIR" = "$INSTALL_DIR" ]; then
    echo "  Already running from install directory."
else
    mkdir -p "$INSTALL_DIR"
    # Copy source code, assets, models - skip the Windows venv and .git
    rsync -a --exclude='venv' --exclude='.git' \
        "$SOURCE_DIR/whisper-writer/" "$APP_DIR/"
    rsync -a "$SOURCE_DIR/models/" "$MODEL_DIR/"
    # Copy docs and this script
    cp "$SOURCE_DIR/README.md" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$SOURCE_DIR/SETUP_NOTES.md" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$SOURCE_DIR/UBUNTU_SETUP.md" "$INSTALL_DIR/" 2>/dev/null || true
    cp "$SOURCE_DIR/setup-ubuntu.sh" "$INSTALL_DIR/" 2>/dev/null || true
    echo "  Files copied to $INSTALL_DIR"
fi

# Make sure the install dir is readable by all users
chmod -R a+rX "$INSTALL_DIR"

# --- Step 3: Remove any old/Windows venv and create a fresh one ---
echo ""
echo "[3/6] Creating Python virtual environment..."
if [ -d "$APP_DIR/venv" ]; then
    rm -rf "$APP_DIR/venv"
    echo "  Removed old venv."
fi

$PYTHON_CMD -m venv --system-site-packages "$APP_DIR/venv"

echo ""
echo "[4/6] Installing Python dependencies (this may take a few minutes)..."
"$APP_DIR/venv/bin/pip" install --upgrade pip

PACKAGES=(
    faster-whisper
    PyQt5
    pynput
    sounddevice
    soundfile
    PyYAML
    python-dotenv
    openai
    httpx
    coloredlogs
    audioplayer
    webrtcvad-wheels
    tqdm
    pyperclip
    evdev
)

"$APP_DIR/venv/bin/pip" install "${PACKAGES[@]}"
echo "  Dependencies installed."

# --- Step 4: Create Linux launcher.pyw ---
echo ""
echo "[5/6] Creating Linux launcher and start script..."

cat > "$APP_DIR/launcher.pyw" << 'PYEOF'
import sys
import os

# Setup paths and environment FIRST
INSTALL_DIR = '/opt/whisper'
APP_DIR = os.path.join(INSTALL_DIR, 'whisper-writer')
MODEL_DIR = os.path.join(INSTALL_DIR, 'models')

sys.path.insert(0, os.path.join(APP_DIR, 'src'))
os.chdir(APP_DIR)
os.environ['HF_HOME'] = MODEL_DIR
os.environ['HF_HUB_DISABLE_SYMLINKS_WARNING'] = '1'

# Load config
from utils import ConfigManager
ConfigManager.initialize()

# Pre-load model before Qt to avoid crash
from faster_whisper import WhisperModel
model_size = ConfigManager.get_config_value('model_options', 'local', 'model')
compute_type = ConfigManager.get_config_value('model_options', 'local', 'compute_type')
device = ConfigManager.get_config_value('model_options', 'local', 'device') or 'cpu'
if device == 'auto':
    device = 'cpu'
_preloaded_model = WhisperModel(model_size, device=device, compute_type=compute_type)

# Patch the transcription module to use our pre-loaded model
import transcription
transcription.create_local_model = lambda: _preloaded_model

# Start the app
from main import WhisperWriterApp
app = WhisperWriterApp()
app.run()
PYEOF

# Create start.sh
cat > "$APP_DIR/start.sh" << 'SHEOF'
#!/usr/bin/env bash
INSTALL_DIR="/opt/whisper"
APP_DIR="$INSTALL_DIR/whisper-writer"
MODEL_DIR="$INSTALL_DIR/models"

# Prevent duplicate instances
PIDFILE="/tmp/whisper-writer-$USER.pid"
if [ -f "$PIDFILE" ]; then
    OLD_PID=$(cat "$PIDFILE")
    if kill -0 "$OLD_PID" 2>/dev/null; then
        echo "WhisperWriter is already running (PID $OLD_PID)."
        exit 0
    fi
    rm -f "$PIDFILE"
fi

cd "$APP_DIR"
export HF_HOME="$MODEL_DIR"
export HF_HUB_DISABLE_SYMLINKS_WARNING=1

# If running under Wayland, set Qt to use xcb (X11 compat) to avoid rendering issues
if [ "$XDG_SESSION_TYPE" = "wayland" ]; then
    export QT_QPA_PLATFORM=xcb
fi

"$APP_DIR/venv/bin/python" "$APP_DIR/launcher.pyw" "$@" &
echo $! > "$PIDFILE"
disown
SHEOF
chmod +x "$APP_DIR/start.sh"

# Create a convenience symlink in ~/.local/bin so the user can run it from anywhere
mkdir -p "$HOME/.local/bin"
ln -sf "$APP_DIR/start.sh" "$HOME/.local/bin/whisper-writer"

echo "  launcher.pyw and start.sh created."
echo "  Symlink: ~/.local/bin/whisper-writer"

# --- Configure for Wayland if needed ---
if [ "$DISPLAY_SERVER" = "wayland" ]; then
    echo ""
    echo "  Configuring for Wayland..."
    if [ -f "$APP_DIR/src/config.yaml" ]; then
        "$APP_DIR/venv/bin/python" -c "
import yaml
config_path = '$APP_DIR/src/config.yaml'
with open(config_path, 'r') as f:
    config = yaml.safe_load(f)
config.setdefault('recording_options', {})['input_backend'] = 'evdev'
config.setdefault('post_processing', {})['input_method'] = 'ydotool'
with open(config_path, 'w') as f:
    yaml.dump(config, f, default_flow_style=False)
print('  Config updated: input_backend=evdev, input_method=ydotool', end='')
"
        echo ""
    fi
fi

# --- Step 5: Desktop entry ---
echo ""
echo "[6/6] Creating desktop entry..."

DESKTOP_FILE="$HOME/.local/share/applications/whisper-writer.desktop"
mkdir -p "$(dirname "$DESKTOP_FILE")"

cat > "$DESKTOP_FILE" << DEOF
[Desktop Entry]
Name=WhisperWriter
Comment=Speech-to-text with Whisper - hold INSERT, speak, release
Exec=$APP_DIR/start.sh
Icon=$APP_DIR/assets/ww-logo.png
Terminal=false
Type=Application
Categories=Utility;Audio;
DEOF

echo "  Desktop entry created at: $DESKTOP_FILE"

read -p "  Add to startup (auto-run on login)? [y/N] " add_startup
if [[ "$add_startup" =~ ^[Yy]$ ]]; then
    AUTOSTART_DIR="$HOME/.config/autostart"
    mkdir -p "$AUTOSTART_DIR"
    cp "$DESKTOP_FILE" "$AUTOSTART_DIR/whisper-writer.desktop"
    echo "  Added to autostart."
fi

# --- Permissions: config needs to be writable for settings UI ---
chmod a+w "$APP_DIR/src/config.yaml" 2>/dev/null || true

# --- Done ---
echo ""
echo "========================================"
echo " Setup complete!"
echo "========================================"
echo ""
echo " To run WhisperWriter:"
echo "   whisper-writer                        (if ~/.local/bin is in PATH)"
echo "   $APP_DIR/start.sh   (full path)"
echo ""
echo " Or search for 'WhisperWriter' in your app launcher."
echo ""
echo " Usage: Hold INSERT key -> speak -> release -> text is typed"
echo ""
echo " Config: $APP_DIR/src/config.yaml"
echo " Models: $MODEL_DIR"
echo ""
if [ "$DISPLAY_SERVER" = "wayland" ]; then
    echo " NOTE: Wayland detected. The evdev backend is configured for"
    echo " key listening. If you have permission issues, you may need to"
    echo " add your user to the 'input' group:"
    echo "   sudo usermod -aG input \$USER"
    echo " Then log out and back in."
    echo ""
fi
