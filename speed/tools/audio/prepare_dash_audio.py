"""Offline split of the authored dash sound. Requires ffmpeg and numpy."""
from pathlib import Path
import subprocess,tempfile,wave
import numpy as np
root=Path(__file__).resolve().parents[2]/'assets/audio/sfx'
with tempfile.TemporaryDirectory() as temp:
 decoded=Path(temp)/'decoded.wav'
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'high_speed.mp3'),'-ar','48000','-c:a','pcm_s16le',str(decoded)],check=True)
 with wave.open(str(decoded),'rb') as stream:
  rate=stream.getframerate();channels=stream.getnchannels()
  samples=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').reshape(-1,channels).astype(float)
 def clip(a,b):return samples[round(a*rate):round(b*rate)].copy()
 pieces={'dash_start':clip(.12,.34),'dash_loop':clip(.34,.56),'dash_end':clip(.56,.84)}
 loop=pieces['dash_loop'];n=round(.02*rate);blend=np.linspace(0,1,n)[:,None]
 pieces['dash_loop']=np.concatenate([loop[n:-n],loop[-n:]*(1-blend)+loop[:n]*blend])
 for name,data in pieces.items():
  if name!='dash_loop':
   n=min(round(.003*rate),len(data)//2)
   data[:n]*=np.linspace(0,1,n)[:,None];data[-n:]*=np.linspace(1,0,n)[:,None]
  with wave.open(str(root/(name+'.wav')),'wb') as stream:
   stream.setparams((channels,2,rate,0,'NONE','not compressed'))
   stream.writeframes(np.rint(data).clip(-32768,32767).astype('<i2').tobytes())
print('Prepared dash attack, seamless sustain and release')
