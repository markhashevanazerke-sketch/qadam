"""CC0 Fantozzi shoe recordings, softened and level-matched for Nazerke."""
from pathlib import Path
import subprocess
import numpy as np
from scipy import signal
ROOT=Path(__file__).resolve().parents[1]
RATE=44100
src=ROOT/'source/audio/footsteps/Fantozzi-footsteps/flac'
out=ROOT/'godot/audio'
for surface in ['concrete','wood']:
 for foot in range(2):
  for variant in range(3):
   path=src/f'Fantozzi-Stone{"L" if foot==0 else "R"}{variant+1}.flac'
   raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ac','1','-ar',str(RATE),'-'])
   data=np.frombuffer(raw,np.float32).copy()
   data-=data.mean()
   data=signal.sosfilt(signal.butter(2,[65,3800 if surface=='concrete' else 2100],btype='bandpass',fs=RATE,output='sos'),data)
   # Trim recording silence, retaining a little shoe contact before the transient.
   env=np.convolve(data*data,np.ones(220)/220,'same')
   active=np.flatnonzero(env>env.max()*.007)
   data=data[max(0,active[0]-220):min(len(data),active[-1]+550)]
   n=min(200,len(data)//8);data[:n]*=np.linspace(0,1,n);data[-n:]*=np.linspace(1,0,n)
   data*=min(.085/max(np.sqrt(np.mean(data*data)),1e-6),.58/max(abs(data).max(),1e-6))
   name=f'step_{surface}_{foot*3+variant}.ogg'
   subprocess.run(['ffmpeg','-v','error','-y','-f','f32le','-ar',str(RATE),'-ac','1','-i','-','-c:a','libvorbis','-q:a','5',str(out/name)],input=data.astype(np.float32).tobytes(),check=True)
   print(name,round(len(data)/RATE,3),'sec',round(float(abs(data).max()),3),'peak')
