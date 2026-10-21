"""Rebuild wearable cloth topology against the character's bind-space head.
Retains the two supplied fabric textures; root GLBs are never modified.
Export /tmp/balaclava_head.json using BalaclavaPreview.gd before running.
"""
from pathlib import Path
import json, math
import bpy,bmesh
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
data=json.loads(Path('/tmp/balaclava_head.json').read_text())
verts=[];faces=[]
for s in data:
    off=len(verts);verts.extend(s['vertices']);ids=s['indices'] or list(range(len(s['vertices'])))
    faces.extend(tuple(off+v for v in ids[i:i+3]) for i in range(0,len(ids),3))
bvh=BVHTree.FromPolygons(verts,faces)
N=128; ROWS=49
for source,target in [('balaclava_2.glb','balaclava'),('christmas_balaclava.glb','balaclava_navideno')]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/source))
    source_mat=next(o for o in bpy.data.objects if o.type=='MESH').data.materials[0]
    texture=next(n.image for n in source_mat.node_tree.nodes if n.type=='TEX_IMAGE' and any(link.to_socket.name=='Base Color' for link in n.outputs['Color'].links))
    pixels=np.array(texture.pixels[:],dtype=np.float32).reshape(texture.size[1],texture.size[0],4)
    patch=pixels[int(texture.size[1]*.545):int(texture.size[1]*.675),int(texture.size[0]*.405):int(texture.size[0]*.55)]
    tile=np.concatenate([patch,patch[:,::-1]],axis=1)
    tile=np.concatenate([tile,tile[::-1]],axis=0)
    tile=np.tile(tile,(2,3,1))
    cloth=bpy.data.images.new(target+'_fabric',width=tile.shape[1],height=tile.shape[0])
    cloth.pixels.foreach_set(tile.ravel());cloth.pack();texture=cloth
    for o in list(bpy.data.objects):bpy.data.objects.remove(o,do_unlink=True)
    vv=[];ff=[];uv=[]
    for row in range(ROWS):
        for i in range(N+1):
            angle=-math.pi+i/N*2*math.pi
            aperture=math.sqrt(max(0,1-(angle/1.02)**2))*.046
            lower=3.49-aperture;upper=3.49+aperture
            if row<=24:y=3.18+(lower-3.18)*row/24
            else:y=upper+(3.756-upper)*(row-25)/23
            direction=Vector((math.sin(angle),0,math.cos(angle)))
            center=Vector((-.008,y,.008))
            hit,_,_,_=bvh.ray_cast(center+direction*1.2,-direction,2.4)
            if hit is None:
                radius=.025*math.sqrt(max(0,(3.756-y)/.012))
            else:radius=(hit-center).dot(direction)+.040

            # A smooth cloth envelope spans the ears rather than outlining them.

            radius+=.0015*math.sin(angle*8+y*72)
            p=center+direction*radius
            vv.append((p.x,-p.z,p.y))
            # Sample the intact back fabric patch of the source atlas. It has
            # no baked black cavity or highlights from the scanned eye socket.
            u=i/N; v=row/(ROWS-1)
            uv.append((u,v))
    # Relax the fabric over the ears and jaw; keep the eye rim and hem pinned.
    positions=np.array(vv).reshape(ROWS,N+1,3)
    for _ in range(12):
        old=positions.copy()
        for row in range(1,ROWS-1):
            for i in range(N):
                if row in (24,25) and abs(-math.pi+i/N*2*math.pi)<1.06:continue
                average=(old[row,(i-1)%N]+old[row,(i+1)%N]+old[row-1,i]+old[row+1,i])*.25
                positions[row,i]=old[row,i]*.45+average*.55
        positions[:,-1]=positions[:,0]
    vv=[tuple(v) for v in positions.reshape(-1,3)]
    for row in range(ROWS-1):
        for i in range(N):
            angle=-math.pi+(i+.5)/N*2*math.pi
            if row==24 and abs(angle)<1.02:continue
            a=row*(N+1)+i;b=a+1;c=b+N+1;d=a+N+1
            ff.append((a,b,c,d))
    mesh=bpy.data.meshes.new('FittedCloth');mesh.from_pydata(vv,[],ff);mesh.update()
    obj=bpy.data.objects.new('FaceFittedBind',mesh);bpy.context.collection.objects.link(obj)
    layer=mesh.uv_layers.new()
    for polygon in mesh.polygons:
        polygon.use_smooth=True
        for li in polygon.loop_indices:layer.data[li].uv=uv[mesh.loops[li].vertex_index]
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    mat=bpy.data.materials.new('Matte woven fabric');mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Roughness'].default_value=.94
    tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=texture
    mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color']);mesh.materials.append(mat)
    # Thickness only at the neckline and eye rim, no inner membrane.
    bpy.context.view_layer.objects.active=obj;obj.select_set(True)
    solid=obj.modifiers.new('Sewn cloth edge','SOLIDIFY');solid.thickness=.003;solid.offset=0
    bpy.ops.object.modifier_apply(modifier=solid.name)
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/adapted/civil'/f'{target}.glb'),export_format='GLB')

    # Ground/held inventory copy has its origin at the hem, not at the body origin.
    for vertex in obj.data.vertices:vertex.co.z-=3.18
    obj.name='PickupBalaclava'
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/characters/adapted/civil'/f'pickup_{target}.glb'),export_format='GLB')
