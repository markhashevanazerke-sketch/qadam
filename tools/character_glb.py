"""Retarget credited Nathan walk/idle onto the selected Canino3d rigs.

Original artist meshes, skins and embedded textures are preserved. Bind-frame
conversion handles the different bone axes; only animation channels are added.
Old scanned character geometry remains exclusively in the reset backup.
"""
import json
import re
import struct
from pathlib import Path

import numpy as np
from scipy.spatial.transform import Rotation, Slerp

ROOT = Path(__file__).resolve().parents[1]


class GLB:
    def __init__(self, path):
        data = path.read_bytes()
        size = struct.unpack_from('<I', data, 12)[0]
        self.j = json.loads(data[20:20 + size])
        self.blob = bytearray(data[28 + size:])
        self.parents = {c: i for i, node in enumerate(self.j['nodes']) for c in node.get('children', [])}
        self.joints = self.j['skins'][0]['joints']

    def read(self, index):
        a = self.j['accessors'][index]; v = self.j['bufferViews'][a['bufferView']]
        dtype = {5126:'<f4', 5123:'<u2', 5121:'u1', 5125:'<u4'}[a['componentType']]
        width = {'MAT4':16, 'VEC4':4, 'VEC3':3, 'VEC2':2, 'SCALAR':1}[a['type']]
        itemsize = np.dtype(dtype).itemsize
        return np.ndarray((a['count'], width), dtype=dtype, buffer=self.blob,
            offset=v.get('byteOffset', 0) + a.get('byteOffset', 0),
            strides=(v.get('byteStride', itemsize*width), itemsize)).copy()

    def add(self, data, kind):
        data = np.asarray(data, dtype='<f4')
        self.blob.extend(b'\0' * (-len(self.blob) % 4)); offset = len(self.blob)
        self.blob.extend(data.tobytes())
        self.j['bufferViews'].append({'buffer':0, 'byteOffset':offset, 'byteLength':data.nbytes})
        a = {'bufferView':len(self.j['bufferViews'])-1, 'componentType':5126, 'count':len(data), 'type':kind}
        if kind == 'SCALAR': a.update(min=[float(data.min())], max=[float(data.max())])
        self.j['accessors'].append(a); return len(self.j['accessors'])-1

    def write(self, path):
        self.j['buffers'] = [{'byteLength':len(self.blob)}]
        header = json.dumps(self.j, separators=(',', ':')).encode(); header += b' ' * (-len(header)%4)
        blob = bytes(self.blob); blob += b'\0' * (-len(blob)%4)
        path.write_bytes(struct.pack('<III', 0x46546c67, 2, 28+len(header)+len(blob)) +
            struct.pack('<II', len(header), 0x4e4f534a) + header + struct.pack('<II', len(blob), 0x004e4942) + blob)

    def locals(self):
        result = []
        for node in self.j['nodes']:
            if 'matrix' in node: m = np.asarray(node['matrix']).reshape(4, 4).T
            else:
                m = np.eye(4); m[:3,:3] = Rotation.from_quat(node.get('rotation', [0,0,0,1])).as_matrix() @ np.diag(node.get('scale', [1,1,1]))
                m[:3,3] = node.get('translation', [0,0,0])
            result.append(m)
        return result

    def worlds(self, locals_):
        cache = {}
        def world(i):
            if i not in cache:
                parent = self.parents.get(i)
                cache[i] = world(parent) @ locals_[i] if parent is not None else locals_[i]
            return cache[i]
        return np.array([world(i) for i in range(len(locals_))])

    def binds(self):
        meshnode = next(i for i,n in enumerate(self.j['nodes']) if n.get('skin') == 0)
        meshworld = self.worlds(self.locals())[meshnode]
        ibm = self.read(self.j['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        return {joint:meshworld @ np.linalg.inv(inv) for joint,inv in zip(self.joints,ibm)}


def rotation(m):
    # Polar decomposition also removes scale-compensation helpers from rotations.
    u, _, vt = np.linalg.svd(m[:3,:3]); r = u @ vt
    if np.linalg.det(r)<0: u[:,-1]*=-1; r=u@vt
    return Rotation.from_matrix(r)


def clip_samples(g, name):
    clip = next(a for a in g.j['animations'] if a['name'] == name)
    duration = max(float(g.read(s['input'])[-1,0]) for s in clip['samplers'])
    times = np.linspace(0, duration, round(duration*30)+1)
    tracks = {}
    for channel in clip['channels']:
        s = clip['samplers'][channel['sampler']]; t=g.read(s['input']).ravel(); v=g.read(s['output'])
        path=channel['target']['path']; node=channel['target']['node']
        if path=='rotation': values=Slerp(t,Rotation.from_quat(v))(np.clip(times,t[0],t[-1])).as_quat()
        elif path in ['translation','scale']:values=np.column_stack([np.interp(times,t,col) for col in v.T])
        else:continue
        tracks[node,path]=values
    return times,tracks


def sole_vertices(g):
    world=g.worlds(g.locals());ibm=g.read(g.j['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    skin=world[g.joints]@ibm;all_samples=[];lowest=np.inf
    for node in g.j['nodes']:
        if node.get('skin')!=0 or 'mesh'not in node:continue
        for primitive in g.j['meshes'][node['mesh']]['primitives']:
            a=primitive['attributes'];pos=g.read(a['POSITION']);joints=g.read(a['JOINTS_0']).astype(int);weights=g.read(a['WEIGHTS_0']);vertices=np.c_[pos,np.ones(len(pos))]
            ys=np.einsum('vki,vi,vk->v',skin[joints,1,:],vertices,weights)
            all_samples.append((vertices,joints,weights,ys));lowest=min(lowest,float(ys.min()))
    result=[]
    for vertices,joints,weights,ys in all_samples:
        mask=ys<lowest+0.07
        if mask.any():result.append((vertices[mask],joints[mask],weights[mask]))
    return result


def between(a,b):
    a=a/np.linalg.norm(a);b=b/np.linalg.norm(b)
    cross=np.cross(a,b);dot=float(np.clip(np.dot(a,b),-1,1))
    if dot>0.999999:return Rotation.identity()
    if dot< -0.999999:
        axis=np.cross(a,[1,0,0] if abs(a[0])<0.8 else [0,1,0]);axis/=np.linalg.norm(axis)
        return Rotation.from_rotvec(axis*np.pi)
    q=np.r_[cross,1+dot];q/=np.linalg.norm(q);return Rotation.from_quat(q)


def depth(g,i):
    count=0
    while i in g.parents:i=g.parents[i];count+=1
    return count


