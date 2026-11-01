"""Generate clean planar normals for a single exported enemy armor layer, offline."""
import argparse,json
from pathlib import Path
import numpy as np
from PIL import Image
from generate_canis_major_normals import planar,encode

def generate(layers,source,output):
    meta=json.loads(layers.read_text(encoding='utf-8'))
    armor=next(i for i in meta['items'] if i['name']=='armor' and i['frame']==1)
    pixels=np.array(Image.open(armor['path']).convert('RGBA'))
    rgb=planar(pixels[:,:,3]>0)
    directions=np.stack([np.cos(np.arange(8)*np.pi/4),np.sin(np.arange(8)*np.pi/4)],axis=-1)
    palette=np.concatenate([encode(directions,np.full(8,45)),encode(directions,np.full(8,60)),np.array([[128,128,255]],dtype='uint8')])
    delta=rgb.astype('int32')[:,:,None,:]-palette.astype('int32')[None,None,:,:]
    rgba=np.zeros_like(pixels);rgba[:,:,:3]=palette[np.argmin(np.sum(delta*delta,axis=-1),axis=-1)];rgba[:,:,3]=pixels[:,:,3];rgba[rgba[:,:,3]==0]=0
    normal=layers.parent/'generated_normal.png';Image.fromarray(rgba).save(normal)
    assert np.array_equal(rgba[:,:,3],pixels[:,:,3])
    manifest={'source':source.as_posix(),'destination':output.as_posix(),'items':[{'name':'armor_normal','path':normal.as_posix(),'x':armor['x'],'y':armor['y']}]}
    (layers.parent/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False),encoding='utf-8')
    print(source.stem, 'normal colors:',len(np.unique(rgba[rgba[:,:,3]>0,:3],axis=0)))
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--layers',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();generate(a.layers,a.source,a.output)
