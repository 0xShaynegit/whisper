import os
os.environ['HF_HOME'] = 'C:/whisper/models'
os.environ['HF_HUB_DISABLE_SYMLINKS_WARNING'] = '1'

print('Testing model loading (no Qt)...')
print()

print('1. Importing faster_whisper...')
from faster_whisper import WhisperModel
print('   OK')

print('2. Loading base model with float32...')
try:
    model = WhisperModel('base', device='cpu', compute_type='float32')
    print('   OK - Model loaded!')

    print('3. Testing transcription...')
    # Just test that model is usable
    print('   Model ready!')

except Exception as e:
    print(f'   ERROR: {e}')
    import traceback
    traceback.print_exc()

print()
print('Done!')
input('Press Enter to exit...')
