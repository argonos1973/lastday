from pathlib import Path
import bpy, bmesh
from mathutils import Vector
root = Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'assets/characters/adapted/player_with_clothes.glb'))
obj = bpy.data.objects['Tops']
bm = bmesh.new()
bm.from_mesh(obj.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.02)
boundary = {v for e in bm.edges if e.is_boundary for v in e.verts}
while boundary:
    seed = boundary.pop()
    found, stack = {seed}, [seed]
    while stack:
        v = stack.pop()
        for e in v.link_edges:
            if not e.is_boundary:
                continue
            n = e.other_vert(v)
            if n in boundary:
                boundary.remove(n)
                found.add(n)
                stack.append(n)
    center = sum((v.co for v in found), Vector()) / len(found)
    print('LOOP', len(found), tuple(center), 'min', tuple(min(v.co[i] for v in found) for i in range(3)), 'max', tuple(max(v.co[i] for v in found) for i in range(3)), flush=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
print('ARM', arm.name, arm.matrix_world, flush=True)
for bone in arm.data.bones:
    if bone.name.endswith(('LeftArm','LeftForeArm','LeftHand','Spine2','Neck')):
        print('BONE', bone.name, tuple(bone.head_local), tuple(bone.tail_local), flush=True)
