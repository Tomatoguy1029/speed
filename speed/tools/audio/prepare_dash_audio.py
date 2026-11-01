"""Offline split of the authored dash sound. Requires ffmpeg."""
from pathlib import Path
import array,subprocess,sys,tempfile,wave
root=Path(__file__).resolve().parents[2]/'assets/audio/sfx'
with tempfile.TemporaryDirectory() as temp:
 decoded=Path(temp)/'decoded.wav'
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(root/'dash_whoosh.mp3'),'-ar','48000','-c:a','pcm_s16le',str(decoded)],check=True)
 with wave.open(str(decoded),'rb') as stream:
  rate=stream.getframerate();channels=stream.getnchannels()
  samples=array.array('h',stream.readframes(stream.getnframes()))
  if sys.byteorder!='little':samples.byteswap()
 def clip(a,b):return list(samples[round(a*rate)*channels:round(b*rate)*channels])
 pieces={'dash_start':clip(0,.35),'dash_loop':clip(.35,.85),'dash_end':clip(.85,1.60)}
 loop=pieces['dash_loop'];n=round(.02*rate)
 blend=[loop[-n*channels+i]*(1-(i//channels)/(n-1))+loop[i]*(i//channels)/(n-1) for i in range(n*channels)]
 pieces['dash_loop']=loop[n*channels:-n*channels]+blend
 for name,data in pieces.items():
  if name!='dash_loop':
   n=min(round(.003*rate),len(data)//channels//2)
   for i in range(n*channels):
    gain=(i//channels)/(n-1)
    data[i]*=gain
   fade_seconds=.03 if name=='dash_start' else .2
   n=min(round(fade_seconds*rate),round(len(data)/channels*.4))
   for i in range(n*channels):data[-1-i]*=(i//channels)/(n-1)
  with wave.open(str(root/(name+'.wav')),'wb') as stream:
   stream.setparams((channels,2,rate,0,'NONE','not compressed'))
   encoded=array.array('h',(max(-32768,min(32767,round(value))) for value in data))
   if sys.byteorder!='little':encoded.byteswap()
   stream.writeframes(encoded.tobytes())
print('Prepared dash attack, seamless sustain and release')
