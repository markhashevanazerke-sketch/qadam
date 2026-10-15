"""Download the pinned open models; existing complete installations are reused."""
from pathlib import Path
import hashlib, json, tarfile, urllib.request, zipfile
ROOT=Path(__file__).resolve().parent
MODELS=ROOT/'models';MODELS.mkdir(exist_ok=True)
HASHES=json.loads((ROOT/'download-sha256.json').read_text())
FILES=[('vosk.zip','vosk-model-small-kz-0.42','https://alphacephei.com/vosk/models/vosk-model-small-kz-0.42.zip'),
       ('tts-complete.tar.bz2','vits-piper-kk_KZ-issai-high','https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/vits-piper-kk_KZ-issai-high.tar.bz2')]
for filename,folder,url in FILES:
    if (MODELS/folder).is_dir():continue
    archive=MODELS/filename
    if not archive.exists() or hashlib.sha256(archive.read_bytes()).hexdigest()!=HASHES[filename]:
        temporary=archive.with_suffix('.download');urllib.request.urlretrieve(url,temporary)
        if hashlib.sha256(temporary.read_bytes()).hexdigest()!=HASHES[filename]:raise RuntimeError('Model checksum mismatch: '+filename)
        temporary.replace(archive)
    if filename.endswith('.zip'):
        with zipfile.ZipFile(archive) as z:z.extractall(MODELS)
    else:
        with tarfile.open(archive) as t:t.extractall(MODELS,filter='data')
print('Kazakh voice models ready.')
