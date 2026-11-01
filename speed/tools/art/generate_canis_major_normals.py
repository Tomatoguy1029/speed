"""Generate broad planar normal faces from authored armor islands, offline only."""
from pathlib import Path
from collections import deque
import argparse, json, struct, zlib
import numpy as np
from PIL import Image

def components(mask):
 seen=np.zeros_like(mask);result=[]
 for sy,sx in np.argwhere(mask):
  if seen[sy,sx]:continue
  q=deque([(int(sy),int(sx))]);seen[sy,sx]=True;points=[]
  while q:
   y,x=q.popleft();points.append((y,x))
   for dy,dx in [(0,1),(0,-1),(1,0),(-1,0)]:
    yy,xx=y+dy,x+dx
    if 0<=yy<mask.shape[0] and 0<=xx<mask.shape[1] and mask[yy,xx] and not seen[yy,xx]:
     seen[yy,xx]=True;q.append((yy,xx))
  result.append(np.array(points))
 return result

def encode(direction,tilt):
 angle=np.round(np.arctan2(-direction[:,1],direction[:,0])/(np.pi/4))*(np.pi/4)
 theta=np.radians(tilt)
 vectors=np.stack([np.cos(angle)*np.sin(theta),np.sin(angle)*np.sin(theta),np.cos(theta)],axis=-1)
 return np.rint((vectors*.5+.5)*255).astype('uint8')

def planar(mask):
 colors=np.zeros((*mask.shape,3),dtype=np.uint8);small=[];large=[]
 for coords in components(mask):
  if len(coords)<6:small.append(coords);continue
  ys,xs=coords.T;xy=coords[:,::-1].astype(float)
  center=(xy.min(axis=0)+xy.max(axis=0))*.5
  centered=xy-center
  _,axes=np.linalg.eigh(np.cov(xy.T))
  major=axes[:,-1]
  if major[1]>0 or (abs(major[1])<1e-6 and major[0]<0):major=-major
  minor=np.array([-major[1],major[0]])
  along=centered@major;across=centered@minor
  # Recenter the oriented bounding rectangle. All boundaries below are straight cuts.
  along-=.5*(along.min()+along.max());across-=.5*(across.min()+across.max())
  half_long=max(.5,.5*np.ptp(along));half_short=max(.5,.5*np.ptp(across))
  u=across/half_short;v=along/half_long
  tilt=np.full(len(coords),45.0)
  flat=np.zeros(len(coords),dtype=bool)
  if half_long/half_short>=1.55:
   # Long armor plates are a simple prism: two wide side faces and two end caps.
   direction=np.sign(u)[:,None]*minor[None,:]
   direction[np.abs(u)<1e-8]=minor
   caps=(np.abs(v)>.78)&(np.abs(v)>.50+np.abs(u)*.30)
   direction[caps]=np.sign(v[caps])[:,None]*major[None,:]
   tilt[caps]=60.0
   flat=(np.abs(u)<=.20)&(~caps)&(half_short>=4)
  else:
   # Broad/curved plates become a low polygonal cap, never a smoothly varying dome.
   side=np.abs(u)>=np.abs(v)
   direction=np.where(side[:,None],np.sign(u)[:,None]*minor,np.sign(v)[:,None]*major)
   corners=(np.minimum(np.abs(u),np.abs(v))>np.maximum(np.abs(u),np.abs(v))*.78)
   direction[corners]=np.sign(u[corners])[:,None]*minor+np.sign(v[corners])[:,None]*major
   flat=(np.maximum(np.abs(u),np.abs(v))<.22)&(half_short>=4)
  rgb=encode(direction,tilt);rgb[flat]=[128,128,255]
  colors[ys,xs]=rgb;large.append(coords)
 # Tiny contour dots inherit their neighboring face instead of receiving random facets.
 if large:
  reference=np.concatenate(large)
  for coords in small:
   for y,x in coords:
    delta=reference-np.array([y,x]);nearest=reference[np.argmin(np.sum(delta*delta,axis=1))]
    colors[y,x]=colors[nearest[0],nearest[1]]
 else:colors[mask]=[128,128,255]
 return colors

def generate(project, output):
 source=project/'assets/pixel/canis_major/wolf_source.aseprite'
 output.mkdir(parents=True,exist_ok=True)
 data=source.read_bytes()
 assert struct.unpack_from('<H',data,6)[0]==1 and struct.unpack_from('<H',data,12)[0]==32
 width,height=struct.unpack_from('<HH',data,8)
 layers=[];cels=[];cursor=144
 while cursor<len(data):
  length,kind=struct.unpack_from('<IH',data,cursor);chunk=data[cursor+6:cursor+length]
  if kind==0x2004:
   size=struct.unpack_from('<H',chunk,16)[0];layers.append(chunk[18:18+size].decode('utf-8'))
  elif kind==0x2005:
   index,x,y,opacity,cel_type=struct.unpack_from('<HhhBH',chunk)
   assert cel_type==2
   w,h=struct.unpack_from('<HH',chunk,16)
   image=Image.frombytes('RGBA',(w,h),zlib.decompress(chunk[20:]))
   cels.append((layers[index],x,y,opacity,image))
  cursor+=length
 regions={'body':(17,63,75,149),'head':(22,140,70,211),'leg_back':(99,46,134,128),'leg_front':(140,137,171,212),'tail':(130,3,181,102)}
 targets=[cel for cel in cels if 'armor' in cel[0] or 'gold_frame' in cel[0]]
 assert len(targets)==9
 fields={};items=[]
 for name,x,y,opacity,image in targets:
  alpha=np.array(image)[:,:,3]
  normal=np.zeros((image.height,image.width,4),dtype='uint8')
  normal[:,:,:3]=planar(alpha>0);normal[:,:,3]=alpha
  normal[alpha==0]=0
  assert np.array_equal(normal[:,:,3],alpha)
  file=output/(name+'_normal.png');Image.fromarray(normal).save(file)
  fields[name]=Image.fromarray(normal)
  items.append(dict(name=name+'_normal',path=file.as_posix(),x=x,y=y,opacity=opacity))
 for part,region in regions.items():
  normal=Image.new('RGBA',(width,height),(128,128,255,255))
  for name,x,y,opacity,image in targets:
   if part in name:normal.alpha_composite(fields[name],(x,y))
  normal=normal.crop(region)
  diffuse=Image.open(project/f'assets/pixel/canis_major/{part}.png').convert('RGBA')
  assert normal.size==diffuse.size
  a=np.array(normal)
  directions=np.stack([np.cos(np.arange(8)*np.pi/4),np.sin(np.arange(8)*np.pi/4)],axis=-1)
  palette=np.concatenate([encode(directions,np.full(8,45)),encode(directions,np.full(8,60)),np.array([[128,128,255]],dtype='uint8')])
  delta=a[:,:,:3].astype('int32')[:,:,None,:]-palette.astype('int32')[None,None,:,:]
  a[:,:,:3]=palette[np.argmin(np.sum(delta*delta,axis=-1),axis=-1)]
  a[:,:,3]=np.array(diffuse)[:,:,3];a[a[:,:,3]==0]=0
  Image.fromarray(a).save(project/f'assets/pixel/canis_major/{part}_normal.png')
 manifest=dict(source=source.as_posix(),destination=(project/'assets/pixel/canis_major/wolf_with_normals_planar.aseprite').as_posix(),items=items)
 (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False),encoding='utf-8')
 print('Generated 9 planar layers and 5 part normal maps; alpha/size checked')

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--project',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
 args=parser.parse_args();generate(args.project,args.output)
