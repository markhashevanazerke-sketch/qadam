import struct,json,numpy as np
from pathlib import Path
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
P=Path(__file__).resolve().parents[1]
b=(P/'godot/assets/polygon_mini_free.glb').read_bytes();jl=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+jl]);raw=b[28+jl:]
def read(i):
 a=d['accessors'][i];v=d['bufferViews'][a['bufferView']];typ={5126:'<f4',5125:'<u4',5123:'<u2'}[a['componentType']];n={'VEC3':3,'VEC2':2,'SCALAR':1}[a['type']];return np.ndarray((a['count'],n),dtype=typ,buffer=raw,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',np.dtype(typ).itemsize*n),np.dtype(typ).itemsize)).copy()
verts=[];tris=[];mats=[];uvs=[]
for mesh in d['meshes']:
 for pr in mesh['primitives']:
  v=read(pr['attributes']['POSITION']);v=np.column_stack([v[:,0]*3+6.3,v[:,2]*3+26.25,-v[:,1]*3+13.19]);t=read(pr['indices']).reshape(-1,3);uv=read(pr['attributes']['TEXCOORD_0']);tris.append(t+sum(len(x) for x in verts));verts.append(v);uvs.append(uv);mats.extend([pr['material']]*len(t))
v=np.concatenate(verts);t=np.concatenate(tris);uv=np.concatenate(uvs);mats=np.array(mats)
_,ids=np.unique(np.round(v,4),axis=0,return_inverse=True);edges=np.concatenate([ids[t[:,[0,1]]],ids[t[:,[1,2]]],ids[t[:,[2,0]]]])
graph=coo_matrix((np.ones(len(edges)),(edges[:,0],edges[:,1])),shape=(ids.max()+1,ids.max()+1));n,lab=connected_components(graph,directed=False);tl=lab[ids[t[:,0]]]
report=[]
for i in range(n):
 ti=np.where(tl==i)[0];p=v[t[ti]].reshape(-1,3)
 if len(ti)>=12:
  report.append({'id':i,'tris':len(ti),'min':p.min(0).round(3).tolist(),'max':p.max(0).round(3).tolist()})
(P/'previews/source_components.json').write_text(json.dumps(report,indent=2));np.savez('/tmp/nazerke-mesh.npz',v=v,t=t,uv=uv,mats=mats,labels=tl)
print('triangles',len(t),'components',n)
print('Large components',sorted(report,key=lambda x:x['tris'],reverse=True)[:15])
# A texture-coloured top view, with the same metre coordinates as the original project.
import matplotlib;matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection
from PIL import Image
import io
tex=[]
for im in d['images']:
 bv=d['bufferViews'][im['bufferView']];tex.append(np.asarray(Image.open(io.BytesIO(raw[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']])).convert('RGB')))
colors=np.zeros((len(t),3))
for mi,mat in enumerate(d['materials']):
 ti=np.where(mats==mi)[0];img=tex[d['textures'][mat['pbrMetallicRoughness']['baseColorTexture']['index']]['source']];u=uv[t[ti]].mean(1);x=np.clip((u[:,0]*img.shape[1]).astype(int),0,img.shape[1]-1);y=np.clip((u[:,1]*img.shape[0]).astype(int),0,img.shape[0]-1);colors[ti]=img[y,x]/255
order=np.argsort(v[t][:,:,1].mean(1));fig,ax=plt.subplots(figsize=(12,16));ax.add_collection(PolyCollection(v[t[order]][:,:,[0,2]],facecolors=colors[order],edgecolors='none'));ax.set(xlim=(-60,40),ylim=(100,-40),aspect='equal');ax.set_xticks(np.arange(-60,41,5));ax.set_yticks(np.arange(-40,101,5));ax.grid(alpha=.35);fig.savefig(P/'previews/source_top.png',dpi=130,bbox_inches='tight');print('top view saved')
