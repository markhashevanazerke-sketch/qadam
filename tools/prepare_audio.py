"""Build small, level-matched runtime assets from the credited CC0 recordings."""
from pathlib import Path
import io
import subprocess
import zipfile
import numpy as np
from scipy import signal

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'source/audio'
OUT = ROOT / 'godot/audio'
OUT.mkdir(exist_ok=True)
RATE = 44100

def decode(path, channels=1):
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path),
        '-f', 'f32le', '-ar', str(RATE), '-ac', str(channels), '-'])
    return np.frombuffer(raw, np.float32).reshape(-1, channels).copy()

def save(name, data, rms, loop=False, lowpass=None):
    data -= data.mean(axis=0)
    if lowpass:
        data = signal.sosfilt(signal.butter(2, lowpass, fs=RATE, output='sos'), data, axis=0)
    if loop:
        n = min(int(RATE * (.05 if len(data) < RATE else 1.5)), len(data) // 8)
        t = np.linspace(0, 1, n)[:, None]
        # Overlap the end and beginning; the resulting wrap is continuous.
        data = np.concatenate([data[n:-n], data[-n:] * (1-t) + data[:n] * t])
    else:
        n = min(220, len(data)//4)
        data[:n] *= np.linspace(0, 1, n)[:, None]
        data[-n:] *= np.linspace(1, 0, n)[:, None]
    gain = min(rms / max(np.sqrt(np.mean(data**2)), .00001), .82 / max(abs(data).max(), .00001))
    data = (data * gain).astype(np.float32)
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'f32le', '-ar', str(RATE),
        '-ac', str(data.shape[1]), '-i', '-', '-c:a', 'libvorbis', '-q:a', '4', str(OUT/name)],
        input=data.tobytes(), check=True)
    print(name, 'seconds', round(len(data)/RATE, 2), 'peak', round(float(abs(data).max()), 3))

save('street.ogg', decode(SOURCE/'traffic_original.ogg'), .14, loop=True, lowpass=5500)
save('engine.ogg', decode(SOURCE/'engine_original.wav'), .20, loop=True, lowpass=3500)
# Music was authored as a loop. Preserve its timing; normalize without a long crossfade.
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-i', str(SOURCE/'shop_original.ogg'),
    '-af', 'loudnorm=I=-23:TP=-3:LRA=9', '-ar', str(RATE), '-c:a', 'libvorbis', '-q:a', '4',
    str(OUT/'shop_music.ogg')], check=True)

with zipfile.ZipFile(SOURCE/'kenney_impact-sounds.zip') as pack:
    (SOURCE/'Kenney_Impact_License.txt').write_bytes(pack.read('License.txt'))
    for surface in ['concrete', 'wood']:
        for i in range(4):
            raw = pack.read(f'Audio/footstep_{surface}_{i:03}.ogg')
            tmp = SOURCE/f'footstep_{surface}_{i}.ogg'
            tmp.write_bytes(raw)
            save(f'step_{surface}_{i}.ogg', decode(tmp), .14)
    tmp = SOURCE/'bell_original.ogg'
    tmp.write_bytes(pack.read('Audio/impactBell_heavy_000.ogg'))
    save('shop_bell.ogg', decode(tmp), .12, lowpass=4500)

with zipfile.ZipFile(SOURCE/'kenney_rpg-audio.zip') as pack:
    print('Door candidates:', [n for n in pack.namelist() if 'door' in n.lower()])
    (SOURCE/'Kenney_RPG_License.txt').write_bytes(pack.read('License.txt'))
    for action in ['Open', 'Close']:
        name = next(n for n in pack.namelist() if n.endswith('door'+action+'_1.ogg'))
        tmp = SOURCE/f'door_{action.lower()}_original.ogg'
        tmp.write_bytes(pack.read(name))
        save(f'door_{action.lower()}.ogg', decode(tmp), .12)

# The newer shoe recordings supersede the initial impact-style footsteps.
import runpy
runpy.run_path(str(ROOT / "tools/prepare_footsteps.py"))
