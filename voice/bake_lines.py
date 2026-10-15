"""Pre-render authored lines; game playback then needs neither Python nor TTS."""
from pathlib import Path
import base64, hashlib, json, time, wave
import server
ROOT=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'lines_manifest.json').read_text())
folder=ROOT.parent/'godot/assets/voice_lines'/manifest['revision']
folder.mkdir(parents=True,exist_ok=True)
started=time.monotonic()
server.load_models()
for i,(key,data) in enumerate(manifest['lines'].items(),1):
    expected=hashlib.sha256((manifest['revision']+'\n'+str(data['speaker'])+'\n'+data['text'].strip()[:2500]).encode()).hexdigest()
    assert expected==key, 'Game/Python cache key mismatch'
    output=folder/(key+'.wav')
    if output.exists():
        with wave.open(str(output),'rb') as saved:
            if saved.getnframes()>0:continue
    audio=server.synthesize(data)
    temporary=output.with_suffix('.tmp.wav')
    with wave.open(str(temporary),'wb') as target:
        target.setnchannels(1);target.setsampwidth(2);target.setframerate(audio['rate']);target.writeframes(base64.b64decode(audio['pcm']))
    temporary.replace(output)
    if i%10==0:print('BAKED',i,'/',len(manifest['lines']),flush=True)
print('BAKE_DONE',len(manifest['lines']),'lines',round(time.monotonic()-started,2),'seconds',flush=True)
