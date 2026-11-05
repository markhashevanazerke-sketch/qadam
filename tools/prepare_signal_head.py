"""Adapt the authored Kenney three-lens head into a two-lens auxiliary head.
No primitive/generated housing: keep end lenses, hoods and original body faces.
"""
from pathlib import Path
import struct,json,numpy as np
root=Path(__file__).resolve().parents[1]/'godot/assets/signals/kenney'
b=(root/'traffic-light-object-vertical.glb').read_bytes();n=struct.unpack_from('<I',b,12)[0];doc=json.loads(b[20:20+n]);raw=bytearray(b[28+n:])
def access(i):
 a=doc['accessors'][i];bv=doc['bufferViews'][a['bufferView']];dtype={5121:'u1',5126:'<f4',5123:'<u2',5125:'<u4'}[a['componentType']];size={'VEC3':3,'SCALAR':1}[a['type']]
 return np.frombuffer(raw,dtype=dtype,count=a['count']*size,offset=bv.get('byteOffset',0)+a.get('byteOffset',0)).reshape(-1,size)
for mesh in doc['meshes']:
 for primitive in mesh['primitives']:
  pi=primitive['attributes']['POSITION'];p=access(pi);indices=access(primitive['indices']);tris=indices.reshape(-1,3)
  # The middle lens and its hood are separate triangles in the authored mesh.
  middle=(np.abs(p[tris][:,:,1])<=.02054).all(1)
  keep=tris[~middle].copy().reshape(-1)
  p[:,1]-=np.clip(p[:,1],-.02053125,.02053125)
  a=doc['accessors'][pi];a['min']=p.min(0).tolist();a['max']=p.max(0).tolist()
  indices[:len(keep),0]=keep;doc['accessors'][primitive['indices']]['count']=len(keep)
doc['asset']['extras']={'source':'Kenney City Kit Roads 2.2, CC0','change':'two end lenses retained; middle lens removed; original housing shortened'}
j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4)
(root/'traffic-light-two.glb').write_bytes(struct.pack('<4sII',b'glTF',2,28+len(j)+len(raw))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(raw),b'BIN\0')+raw)
print('Authored two-lens signal head ready')
