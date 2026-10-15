"""Repair artist garment occlusion without replacing models or changing animations.
Restore the neckline discarded by the old whole-material mask; hide skin that is
actually covered by the shirt. Coordinates are in source centimetres.
"""
from pathlib import Path
import json
import numpy as np
from character_glb import GLB
ROOT=Path(__file__).resolve().parents[1]

def indices(g,value):
    value=np.asarray(value,dtype='<u4').ravel()
    g.blob.extend(b'\0'*(-len(g.blob)%4));offset=len(g.blob);g.blob.extend(value.tobytes())
    g.j['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':value.nbytes})
    g.j['accessors'].append({'bufferView':len(g.j['bufferViews'])-1,'componentType':5125,'count':len(value),'type':'SCALAR'})
    return len(g.j['accessors'])-1

def covered(points,normals,triangles):
    # Two-sided ray/triangle tests, allowing 12 mm of existing skin penetration.
    a=triangles[:,0];e1=triangles[:,1]-a;e2=triangles[:,2]-a
    result=np.zeros(len(points),bool)
    for start in range(0,len(points),64):
        direction=normals[start:start+64].astype(float)
        direction/=np.maximum(np.linalg.norm(direction,axis=1,keepdims=True),1e-8)
        origin=points[start:start+64]-direction*1.2
        h=np.cross(direction[:,None,:],e2)
        det=np.einsum('bti,ti->bt',h,e1)
        valid=np.abs(det)>1e-8
        inv=np.divide(1,det,out=np.zeros_like(det),where=valid)
        s=origin[:,None,:]-a
        u=np.einsum('bti,bti->bt',s,h)*inv
        q=np.cross(s,e1)
        v=np.einsum('bi,bti->bt',direction,q)*inv
        distance=np.einsum('ti,bti->bt',e2,q)*inv
        result[start:start+len(direction)]=(valid&(u>=0)&(v>=0)&(u+v<=1)&(distance>=0)&(distance<6)).any(1)
    return result

def repair(g,source):
    shirt=[]
    for mesh in g.j['meshes']:
        for p in mesh['primitives']:
            if g.j['materials'][p['material']].get('name')=='lambert7':
                v=g.read(p['attributes']['POSITION']);ix=g.read(p['indices']).astype(int).reshape(-1,3)
                shirt.extend(v[ix])
    shirt=np.asarray(shirt)
    report=[]
    for index,node in enumerate(source.j['nodes']):
        if 'mesh' not in node:continue
        mesh=source.j['meshes'][node['mesh']]
        for k,p in enumerate(mesh['primitives']):
            name=source.j['materials'][p['material']].get('name')
            if name not in ['lambert13','Std_Skin_Arm','Std_Skin_Body']:continue
            # The original accessors are retained verbatim in the natural-motion GLB.
            attrs=p['attributes'];verts=source.read(attrs['POSITION']);normals=source.read(attrs['NORMAL'])
            assert np.array_equal(verts,g.read(attrs['POSITION']))
            faces=source.read(p['indices']).astype(int).reshape(-1,3)
            centers=verts[faces].mean(1);cn=normals[faces].mean(1)
            hide=covered(centers,cn,shirt)
            if name=='Std_Skin_Body':hide|=(verts[faces][:,:,1]<103).all(1)
            # Preserve the neckline and bare arms, cull only covered shoulder skin.
            if name=='Std_Skin_Arm':hide|=((np.abs(verts[faces][:,:,0])<19.8)&(verts[faces][:,:,1]>128)).all(1)
            target=g.j['meshes'][node['mesh']]['primitives'][k]
            target['indices']=indices(g,faces[~hide]) if (~hide).any() else p['indices']
            g.j['nodes'][index]['mesh']=node['mesh'];g.j['nodes'][index]['skin']=node['skin']
            report.append({'material':name,'source_triangles':len(faces),'covered_triangles_removed':int(hide.sum()),'visible_triangles':int((~hide).sum())})
            if not (~hide).any():
                g.j['nodes'][index].pop('mesh',None);g.j['nodes'][index].pop('skin',None)
    g.j['asset'].setdefault('extras',{})['Nazerke_garment_repair']='Restore exposed neckline; garment-surface occlusion mask for covered skin.'
    return report

def main():
    g=GLB(ROOT/'backups/before-menu-ui/girl_natural.glb')
    original=GLB(ROOT/'backups/before-natural-movement/girl.glb')
    before=json.dumps(g.j['animations'],sort_keys=True)
    result=repair(g,original)
    assert before==json.dumps(g.j['animations'],sort_keys=True),'Animation tracks must remain untouched'
    g.write(ROOT/'godot/assets/characters/girl_natural.glb')
    (ROOT/'previews/garment_repair_report.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result))
if __name__=='__main__':main()
