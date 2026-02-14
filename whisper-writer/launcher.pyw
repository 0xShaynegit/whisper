import sys
import os

# Setup paths and environment FIRST
sys.path.insert(0, 'src')
os.chdir('C:/whisper/whisper-writer')
os.environ['HF_HOME'] = 'C:/whisper/models'
os.environ['HF_HUB_DISABLE_SYMLINKS_WARNING'] = '1'

# Load config
from utils import ConfigManager
ConfigManager.initialize()

# Pre-load model before Qt to avoid crash
from faster_whisper import WhisperModel
model_size = ConfigManager.get_config_value('model_options', 'local', 'model')
compute_type = ConfigManager.get_config_value('model_options', 'local', 'compute_type')
_preloaded_model = WhisperModel(model_size, device='cpu', compute_type=compute_type)

# Patch the transcription module to use our pre-loaded model
import transcription
transcription.create_local_model = lambda: _preloaded_model

# Start the app
from main import WhisperWriterApp
app = WhisperWriterApp()
app.run()
