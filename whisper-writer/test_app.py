import sys
import os

# Setup paths and environment FIRST
sys.path.insert(0, 'src')
os.chdir('C:/whisper/whisper-writer')
os.environ['HF_HOME'] = 'C:/whisper/models'
os.environ['HF_HUB_DISABLE_SYMLINKS_WARNING'] = '1'

print('1. Loading config...')
from utils import ConfigManager
ConfigManager.initialize()

print('2. Pre-loading model before Qt...')
from faster_whisper import WhisperModel
model_size = ConfigManager.get_config_value('model_options', 'local', 'model')
compute_type = ConfigManager.get_config_value('model_options', 'local', 'compute_type')
print(f'   Loading {model_size}...')

# Pre-load the model
_preloaded_model = WhisperModel(model_size, device='cpu', compute_type=compute_type)
print('   Model ready!')

# Patch the transcription module to use our pre-loaded model
import transcription
original_create_local_model = transcription.create_local_model
def patched_create_local_model():
    print('   Using pre-loaded model')
    return _preloaded_model
transcription.create_local_model = patched_create_local_model

print('3. Starting WhisperWriter...')
from main import WhisperWriterApp
app = WhisperWriterApp()
app.run()
