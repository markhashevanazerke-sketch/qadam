"""Retarget ACCAD CC-BY-3.0 recorded walks; preserve authored cartoon meshes.
Source files and license are recorded in source/motion/README.txt.
"""
from pathlib import Path
import re, json, numpy as np
from scipy.spatial.transform import Rotation
from scipy.signal import find_peaks, savgol_filter
from character_glb import GLB, rotation, depth, sole_vertices
ROOT=Path(__file__).resolve().parents[1]

class BVH:
 def __init__(self,path):
  hierarchy,motion=path.read_text().split('MOTION');tokens=re.findall(r'[^\s{}]+|[{}]',hierarchy);self.nodes=[];self.channels=0;self.cursor=1
  def parse(parent=None):
   kind=tokens[self.cursor];self.cursor+=1
   name=tokens[self.cursor];self.cursor+=1
   if kind=='End':name=self.nodes[parent]['name']+'_end'
   node={'name':name,'parent':parent,'offset':np.zeros(3),'channels':[]};i=len(self.nodes);self.nodes.append(node)
   assert tokens[self.cursor]=='{';self.cursor+=1
   while tokens[self.cursor]!='}':
    key=tokens[self.cursor]
    if key=='OFFSET':
     node['offset']=np.array(tokens[self.cursor+1:self.cursor+4],float);self.cursor+=4
    elif key=='CHANNELS':
     n=int(tokens[self.cursor+1]);node['channels']=[(v,self.channels+k) for k,v in enumerate(tokens[self.cursor+2:self.cursor+2+n])];self.channels+=n;self.cursor+=2+n
    else:parse(i)
   self.cursor+=1
  parse();lines=motion.strip().splitlines();self.dt=float(lines[1].split(':')[1]);self.data=np.array([[float(v) for v in l.split()] for l in lines[2:] if l.strip()]);self.names={n['name']:i for i,n in enumerate(self.nodes)}
  self.world=[]
  for frame in self.data:
   poses=[]
   for i,n in enumerate(self.nodes):
    matrix=np.eye(4);matrix[:3,3]=n['offset'];rot=[];order=''
    for ch,k in n['channels']:
     if ch.endswith('position'):matrix['XYZ'.index(ch[0]),3]=frame[k] if n['parent'] is None else matrix['XYZ'.index(ch[0]),3]+frame[k]
     else:order+=ch[0];rot.append(frame[k])
    if rot:matrix[:3,:3]=Rotation.from_euler(order,rot,degrees=True).as_matrix()
    poses.append(poses[n['parent']]@matrix if n['parent'] is not None else matrix)
   self.world.append(poses)
  self.world=np.array(self.world);self.points=self.world[:,:,:3,3]*.01

def frame(primary,forward):
 y=primary/np.linalg.norm(primary);z=forward-y*np.dot(y,forward)
 if np.linalg.norm(z)<.05:z=np.array([1.,0,0])-y*y[0]
 z/=np.linalg.norm(z);x=np.cross(y,z)
 return Rotation.from_matrix(np.column_stack([x,y,z]))

def write_indices(g,indices):
 data=np.asarray(indices,dtype='<u4').ravel();g.blob.extend(b'\0'*(-len(g.blob)%4));offset=len(g.blob);g.blob.extend(data.tobytes());g.j['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':data.nbytes});g.j['accessors'].append({'bufferView':len(g.j['bufferViews'])-1,'componentType':5125,'count':len(data),'type':'SCALAR'});return len(g.j['accessors'])-1

def fix_clothing(g,id):
 report=[]
 for node in g.j['nodes']:
  if 'mesh' not in node:continue
  mesh=g.j['meshes'][node['mesh']]
  for p in mesh['primitives']:
   mat=g.j['materials'][p['material']].get('name','');attrs=p['attributes'];v=g.read(attrs['POSITION']);x,y,z=v.T;mask=np.zeros(len(v),bool)
   if id=='man':
    if mat=='Std_Skin_Body':mask=y<138
    if mat=='Std_Skin_Leg':mask[:]=True
    if mat=='Std_Skin_Arm':mask=np.abs(x)<57
    if mat=='Std_Nails':mask=y<25
   elif id=='girl':
    if mat=='Std_Skin_Body':mask=(y<103)|(y>120)
    if mat in ['lambert13','Default_OBJ.003']:mask[:]=True
    if mat=='Std_Skin_Leg':mask=(y>78)|(y<28)
    if mat=='Std_Skin_Arm':mask=(np.abs(x)<18.8)&(y>129)
    if mat=='Std_Nails':mask=y<32
   if mask.any():
    indices=g.read(p['indices']).astype(int).reshape(-1,3);kept=indices[~mask[indices].all(1)]
    report.append({'material':mat,'removed_triangles':len(indices)-len(kept)})
    if not len(kept):node.pop('mesh');node.pop('skin',None)
    else:p['indices']=write_indices(g,kept)
   clothing=(id=='man' and mat in ['lambert3SG','lambert4','lambert5']) or (id=='girl' and mat in ['lambert7','lambert12'])
   if clothing and 'NORMAL' in attrs:
    # 2.5 mm cloth clearance; no substitute body/garment geometry is generated.
    _,weld=np.unique(np.round(v,4),axis=0,return_inverse=True)
    normals=np.zeros((weld.max()+1,3));np.add.at(normals,weld,g.read(attrs['NORMAL']));normals/=np.maximum(np.linalg.norm(normals,axis=1,keepdims=True),1e-8)
    displaced=v+normals[weld]*.25
    attrs['POSITION']=g.add(displaced,'VEC3')
    g.j['accessors'][attrs['POSITION']].update(min=displaced.min(0).tolist(),max=displaced.max(0).tolist())
    g.j['materials'][p['material']]['doubleSided']=True
 return report

MAP={'Hip':'Hips','Spine01':'Spine','Spine02':'Spine1','NeckTwist01':'Neck','Head':'Head','L_Clavicle':'LeftShoulder','R_Clavicle':'RightShoulder','L_Upperarm':'LeftArm','R_Upperarm':'RightArm','L_Forearm':'LeftForeArm','R_Forearm':'RightForeArm','L_Hand':'LeftHand','R_Hand':'RightHand','L_Thigh':'LeftUpLeg','R_Thigh':'RightUpLeg','L_Calf':'LeftLeg','R_Calf':'RightLeg','L_Foot':'LeftFoot','R_Foot':'RightFoot'}
CHILD={'Spine01':'Spine02','Spine02':'NeckTwist01','NeckTwist01':'Head','L_Clavicle':'L_Upperarm','R_Clavicle':'R_Upperarm','L_Upperarm':'L_Forearm','R_Upperarm':'R_Forearm','L_Forearm':'L_Hand','R_Forearm':'R_Hand','L_Thigh':'L_Calf','R_Thigh':'R_Calf','L_Calf':'L_Foot','R_Calf':'R_Foot','L_Foot':'L_ToeBase','R_Foot':'R_ToeBase'}

def main():
 reports=[]
 for id,source in [('man','Male1_B3_Walk.bvh'),('girl','Female1_B03_Walk1.bvh')]:
  bvh=BVH(ROOT/'source/motion'/source);points=bvh.points;ns=bvh.names
  # Remove the capture-room heading while retaining sway, hip rotation and foot roll.
  travel=points[-20,ns['Hips']]-points[20,ns['Hips']];travel[1]=0;travel/=np.linalg.norm(travel)
  align=Rotation.from_euler('y',-np.arctan2(travel[0],travel[2]))
  points=align.apply(points.reshape(-1,3)).reshape(points.shape)
  gait=points[:,ns['LeftFoot'],2]-points[:,ns['RightFoot'],2]
  peaks,_=find_peaks(savgol_filter(gait,7,2),distance=20,prominence=.35)
  assert len(peaks)>=2,(id,peaks)
  start,end=peaks[len(peaks)//2-1:len(peaks)//2+1];duration=(end-start)*bvh.dt
  points=points[start:end+1];points=savgol_filter(points,5,2,axis=0)
  target=GLB(ROOT/'backups/before-natural-movement'/(id+'.glb'));clothes=fix_clothing(target,id)
  rest=target.locals();bind=target.worlds(rest);bykey={}
  for i in target.joints:
   match=re.fullmatch('CC_Base_(.+)_0[0-9]+',target.j['nodes'][i].get('name',''))
   if match:bykey[match[1]]=i
  mapping={bykey[k]:v for k,v in MAP.items()};keys={bykey[k]:k for k in MAP};ordered=sorted(mapping,key=lambda i:depth(target,i));hip=bykey['Hip'];parent=target.parents[hip];parentworld=target.worlds(rest)[parent]
  target_leg=np.linalg.norm(bind[hip][:3,3]-bind[bykey['L_Foot']][:3,3]);source_leg=np.mean(np.linalg.norm(points[:,ns['Hips']]-points[:,ns['LeftFoot']],axis=1));ratio=target_leg/source_leg
  times=np.linspace(0,duration,len(points));out={i:[] for i in mapping};positions=[];sole=sole_vertices(target);ibm=target.read(target.j['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
  up=np.array([0.,1.,0.]);forward=np.array([0.,0.,1.]);heights=points[:,ns['Hips'],1];heights-=heights.mean()
  for f,p in enumerate(points):
   loc=[m.copy() for m in rest]
   bob=np.array([0,heights[f]*ratio,0]);loc[hip][:3,3]+=np.linalg.solve(parentworld[:3,:3],bob)
   for i in ordered:
    key=keys[i];worlds=target.worlds(loc);parent_i=target.parents.get(i)
    if key=='Hip':
     capture_rotations=Rotation.from_matrix(bvh.world[start:end+1,ns['Hips'],:3,:3])
     capture_mean=capture_rotations.mean()
     # A BVH spine offset points behind the hip; it is not a pelvic up axis.
     # Transfer the captured pelvis variation around its neutral orientation.
     delta=align*capture_rotations[f]*capture_mean.inv()*align.inv()
     desired=delta*rotation(bind[i])
    elif key in CHILD:
     child=CHILD[key];ti=bykey[child];source_child=MAP.get(child,'LeftToeBase' if child.startswith('L') else 'RightToeBase')
     target_dir=bind[ti][:3,3]-bind[i][:3,3];wanted=p[ns[source_child]]-p[ns[mapping[i]]]
     reference=up if 'Foot' in key else forward
     desired=frame(wanted,reference)*frame(target_dir,reference).inv()*rotation(bind[i])
    else:
     # Hands and head retain the natural target bind orientation relative to parent.
     desired=rotation(worlds[i])
    localq=rotation(worlds[parent_i]).inv()*desired if parent_i is not None else desired
    loc[i][:3,:3]=localq.as_matrix()@np.diag(np.linalg.norm(rest[i][:3,:3],axis=0));out[i].append(localq.as_quat())
   skin=target.worlds(loc)[target.joints]@ibm
   floor=min(float(np.einsum('vki,vi,vk->v',skin[joints,1,:],vertices,weights).min()) for vertices,joints,weights in sole)
   positions.append(loc[hip][:3,3]+np.linalg.solve(parentworld[:3,:3],np.array([0,.006-floor,0])))
  # Smooth the loop seam without altering the captured middle of the stride.
  for i in out:
   q=np.array(out[i]);q[np.sum(q*q[0],axis=1)<0]*=-1
   delta=Rotation.from_quat(q[-1])*Rotation.from_quat(q[0]).inv()
   correction=Rotation.from_rotvec(-np.linspace(0,1,len(q))[:,None]*delta.as_rotvec())
   out[i]=(correction*Rotation.from_quat(q)).as_quat();out[i][-1]=out[i][0]
  positions=np.array(positions);positions-=np.linspace(0,1,len(positions))[:,None]*(positions[-1]-positions[0]);positions[-1]=positions[0]
  # Keep the existing credited idle; replace the walking clip with recorded ACCAD motion.
  target.j['animations']=[a for a in target.j['animations'] if a['name']!='walk']
  animation={'name':'walk','channels':[],'samplers':[]};ta=target.add(times,'SCALAR')
  for i,q in out.items():
   animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':i,'path':'rotation'}});animation['samplers'].append({'input':ta,'output':target.add(q,'VEC4'),'interpolation':'LINEAR'})
  animation['channels'].append({'sampler':len(animation['samplers']),'target':{'node':hip,'path':'translation'}});animation['samplers'].append({'input':ta,'output':target.add(positions,'VEC3'),'interpolation':'LINEAR'});target.j['animations'].append(animation)
  stride=float(np.linalg.norm(bvh.points[end,ns['Hips']]-bvh.points[start,ns['Hips']])*ratio)
  target.j['asset'].setdefault('extras',{})['Nazerke_walk']={'source':source,'license':'CC-BY-3.0','author':'ACCAD / The Ohio State University','cycle_frames':[int(start),int(end)],'duration':duration,'stride_m':stride}
  if id=='girl':
   from repair_garments import repair
   clothes=repair(target,GLB(ROOT/'backups/before-natural-movement/girl.glb'))
  target.write(ROOT/'godot/assets/characters'/(id+'_natural.glb'))
  report={'character':id,'source':source,'cycle_frames':[int(start),int(end)],'seconds':duration,'stride_m':stride,'speed_m_s':stride/duration,'clothing':clothes};reports.append(report);print(json.dumps(report),flush=True)
 (ROOT/'previews/natural_walk_report.json').write_text(json.dumps(reports,indent=2))
 (ROOT/'godot/assets/characters/natural_motion.json').write_text(json.dumps(reports,indent=2))
if __name__=='__main__':main()
