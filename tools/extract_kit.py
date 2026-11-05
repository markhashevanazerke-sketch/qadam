"""Extract existing artist geometry from POLYGON Mini; never synthesize prop geometry."""
from pathlib import Path
import numpy as np,json,struct,copy,sys
P=Path(__file__).resolve().parents[1];out=P/'godot/assets/nazerke_kit';out.mkdir(exist_ok=True)
b=(P/'godot/assets/polygon_mini_free.glb').read_bytes();jl=struct.unpack_from('<I',b,12)[0];src=json.loads(b[20:20+jl]);raw=b[28+jl:]
data=np.load('/tmp/nazerke-mesh.npz');v=data['v'];t=data['t'];uv=data['uv'];mats=data['mats'];labels=data['labels'];pts=v[t]
# Reuse original embedded images as shared, unmodified textures.
for i,im in enumerate(src['images']):
 bv=src['bufferViews'][im['bufferView']];(out/f'original_{i}.png').write_bytes(raw[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']])
report=[]
previous={r['name']:r for r in json.loads((out/'manifest.json').read_text())}
component_min=np.array([pts[labels==i].min((0,1)) for i in range(labels.max()+1)])
component_max=np.array([pts[labels==i].max((0,1)) for i in range(labels.max()+1)])
def save(name,selection,target=0,angle=0,flatten=False,building_floor=None):
 tri=t[selection];mi=mats[selection];inds=np.unique(tri);p=v[inds];lo=p.min(0);hi=p.max(0);center=(lo+hi)/2;center[1]=lo[1]
 factor=target/(hi[1]-lo[1]) if target else 1
 # Keep reviewed placements/scales stable when repairing a building's mesh.
 if building_floor is not None:
  old=previous[name];old_bounds=np.array(old['source_bounds']);center=(old_bounds[0]+old_bounds[1])/2;center[1]=building_floor;factor=old['scale']
 rot=np.array([[np.cos(angle),0,np.sin(angle)],[0,1,0],[-np.sin(angle),0,np.cos(angle)]])
 doc={'asset':{'version':'2.0','generator':'Nazerke source mesh extraction'},'scene':0,'scenes':[{'nodes':[0]}],'nodes':[{'mesh':0,'name':name}], 'meshes':[{'primitives':[]}], 'materials':copy.deepcopy(src['materials']),'textures':copy.deepcopy(src['textures']),'samplers':copy.deepcopy(src.get('samplers',[])), 'images':[{'uri':f'original_{i}.png'} for i in range(len(src['images']))],'bufferViews':[],'accessors':[]}
 blob=bytearray()
 def acc(arr,typ,component):
  while len(blob)%4:blob.append(0)
  offset=len(blob);blob.extend(arr.tobytes());bv=len(doc['bufferViews']);doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':arr.nbytes});a={'bufferView':bv,'componentType':component,'count':len(arr),'type':typ}
  if typ=='VEC3':a.update(min=arr.min(0).tolist(),max=arr.max(0).tolist())
  doc['accessors'].append(a);return len(doc['accessors'])-1
 for material in np.unique(mi):
  tr=tri[mi==material];used,idx=np.unique(tr,return_inverse=True);pos=((v[used]-center)@rot.T*factor).astype('<f4')
  if flatten:pos[:,1]=0
  if building_floor is not None:pos[:,1]=np.maximum(pos[:,1],0)
  # Normals from source faces; vertex averaging keeps original low-poly facets split by UV seams.
  normals=np.zeros_like(pos);ind=idx.reshape(-1,3)
  if building_floor is not None:
   area=np.linalg.norm(np.cross(pos[ind[:,1]]-pos[ind[:,0]],pos[ind[:,2]]-pos[ind[:,0]]),axis=1)
   ind=ind[area>1e-8];idx=ind.reshape(-1)
  norm=np.cross(pos[ind[:,1]]-pos[ind[:,0]],pos[ind[:,2]]-pos[ind[:,0]])
  for k in range(3):np.add.at(normals,ind[:,k],norm)
  normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-9)
  doc['meshes'][0]['primitives'].append({'attributes':{'POSITION':acc(pos,'VEC3',5126),'NORMAL':acc(normals.astype('<f4'),'VEC3',5126),'TEXCOORD_0':acc(uv[used].astype('<f4'),'VEC2',5126)},'indices':acc(idx.reshape(-1).astype('<u4'),'SCALAR',5125),'material':int(material)})
 doc['buffers']=[{'byteLength':len(blob)}];j=json.dumps(doc,separators=(',',':')).encode();j+=b' '*((-len(j))%4);blob+=b'\0'*((-len(blob))%4)
 glb=struct.pack('<4sII',b'glTF',2,12+8+len(j)+8+len(blob))+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(blob),b'BIN\0')+blob
 (out/(name+'.glb')).write_bytes(glb);record={'name':name,'triangles':len(tri),'source_bounds':[lo.tolist(),hi.tolist()],'scale':float(factor),'source':'polygon_mini_free.glb','yaw':angle};report.append(record);print(name,len(tri),'size',np.round((hi-lo)*factor,2))
def region(name,lo,hi,target=0,angle=0):
 mask=(pts.min(1)>=np.array(lo)-.001).all(1)&(pts.max(1)<=np.array(hi)+.001).all(1)
 save(name,mask,target,angle)
def building(name,components,floor):
 selection=np.isin(labels,components)
 save(name,selection,building_floor=floor)
 report[-1].update(connected_components=[int(i) for i in components],extraction="whole authored components; no bounding-box triangle cuts",ground_plane=float(floor),placement_reference=previous[name].get('placement_reference',{'source_bounds':previous[name]['source_bounds'],'scale':previous[name]['scale']}))
 # On rebuild, use the stable placement reference rather than repaired bounds.
 report[-1]['extracted_source_bounds']=report[-1]['source_bounds']
 report[-1]['source_bounds']=previous[name].get('placement_reference',previous[name])['source_bounds']
 report[-1]['scale']=previous[name]['scale']
def contained(lo,hi):
 return np.where((component_min>=np.array(lo)-.001).all(1)&(component_max<=np.array(hi)+.001).all(1))[0]
building('round_tower',[1896],26.313003540039062)
building('square_tower',[177,184,242,243,361],29.70965576171875)
building('apartment',contained([-51.6,30.2,64.3],[-32.7,43,78]),30.293954849243164)
# The source house sits on an elevated island. Discard island/fence/mailbox
# fragments and lower its authored foundation to the street-level doorstep.
town_parts=[451,463,464,579,594,604,610,612,617,667,689,709,711,713,715,736,740,771,773,781,788,789,843,884,885]
building('townhouse',town_parts,26.09)
building('solar_house',contained([-25.5,25.35,52.8],[-12.5,38,62.9]),27.30)
building('shops',np.setdiff1d(contained([-12.3,26.15,66.7],[4.4,38.8,76.5]),[1606]),26.219972610473633)
if '--buildings-only' in sys.argv:
 updated={r['name']:r for r in report}
 (out/'manifest.json').write_text(json.dumps([updated.get(name,record) for name,record in previous.items()],indent=2))
 raise SystemExit(0)
region('blue_car',[5.45,21.9,-8.6],[9.1,25,-3.75],0,-.32)
region('bus',[-7.8,24.3,35.6],[-4.5,27.2,41.2],0)
save('tree',labels==613,5.0)
save('small_tree',labels==489,3.5)
save('lamp',labels==411,4.8)
save('signal_pole',labels==631)
save('road_tile',np.isin(np.arange(len(t)),[80738,80739,80742,80743]),flatten=True)
# Pavement is extracted from the existing horizontal apron, then levelled.
save('paving_tile',np.isin(np.arange(len(t)),[78890,78891,79182,79183]),flatten=True)
(out/'manifest.json').write_text(json.dumps(report,indent=2))
