"""Reference-inspired six metre riverbank modules: wet cobbles to grassy soil.

References: view-riverbed-rocks.jpg, narrow-river-green-land-with-lot-trees.jpg,
forest-near-river-landscape.jpg (user supplied). Photos guide geometry/palette;
the existing licensed gravel texture supplies surface detail.
Game axes: X along shore, Z toward land, Y up. Origin is the waterline.
"""
from pathlib import Path
import random, math
import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/props/shore'
SOURCE = Path('/Users/sami/Documents/Codex/2026-09-08/rev/outputs/margenes_rio_referencia.blend')
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT.mkdir(parents=True,exist_ok=True)
texture = bpy.data.images.load(str(ROOT/'assets/external/polyhaven/rock_07/textures/rock_07_diff_4k.jpg'))
texture.scale(1024,1024)
pixels=np.empty(1024*1024*4,dtype=np.float32);texture.pixels.foreach_get(pixels)
pixels=pixels.reshape((-1,4));pixels[:,:3]*=.58;texture.pixels.foreach_set(pixels.ravel())
texture.name='riverbank_weathered_stone'

# A continuous fine-gravel bed under the 3D stones, darker at the wet edge.
gravel=bpy.data.images.load(str(ROOT/'assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_diff_4k.jpg'))
gravel.scale(1024,1024)
raw=np.empty(1024*1024*4,dtype=np.float32);gravel.pixels.foreach_get(raw)
band=raw.reshape((1024,1024,4))[320:576].copy()
v=np.linspace(0,1,256)[:,None,None]
band[:,:,:3]*=(.62-.32*v)*np.array([.92,.90,.80])[None,None,:]
# Band array index 0 = PNG bottom = mesh v=1 (land edge); index 255 = mesh
# v=0 (deep underwater). Alpha must die below the waterline (~mesh v 0.62,
# script v ~0.4) so the bank dissolves into the riverbed through the water
# instead of showing as a straight textured shelf.
fade=np.clip((0.52-v[:,:,0])/.12,0,1)*np.clip(v[:,:,0]/.35,0,1)
band[:,:,3]=fade*fade*(3-2*fade)
image=bpy.data.images.new('Reference wet gravel',width=1024,height=256,alpha=True)
image.pixels.foreach_set(band.ravel());image.file_format='PNG'
image.filepath_raw=str(ROOT/'assets/textures/shore/shore_reference_albedo.png');image.save()

# Matching normal map derived from the real pebble displacement map — same
# crop as the albedo band so bumps align with the visible stones.
disp=bpy.data.images.load(str(ROOT/'assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_disp_4k.png'))
disp.scale(1024,1024)
dpx=np.empty(1024*1024*4,dtype=np.float32);disp.pixels.foreach_get(dpx)
hmap=dpx.reshape((1024,1024,4))[320:576,:,0]
ndx=(np.roll(hmap,-1,axis=1)-np.roll(hmap,1,axis=1))*3.0
ndy=(np.roll(hmap,-1,axis=0)-np.roll(hmap,1,axis=0))*3.0
ndx[0,:]=0;ndx[-1,:]=0;ndy[0,:]=0;ndy[-1,:]=0
nrm=np.stack([-ndx,-ndy,np.ones_like(ndx)],axis=2)
nrm/=np.linalg.norm(nrm,axis=2,keepdims=True)
nrgba=np.ones((256,1024,4),dtype=np.float32)
nrgba[:,:,:3]=nrm*.5+.5
nimg=bpy.data.images.new('Reference wet gravel normal',width=1024,height=256,alpha=True)
nimg.pixels.foreach_set(nrgba.ravel());nimg.file_format='PNG'
nimg.filepath_raw=str(ROOT/'assets/textures/shore/shore_reference_normal.png');nimg.save()

def material(name,color,roughness,photo=False):
    m=bpy.data.materials.new(name)
    m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Roughness'].default_value=roughness
    if photo:
        t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=texture
        m.node_tree.links.new(t.outputs['Color'],bs.inputs['Base Color'])
    return m

stone=material('Rounded grey beige cobbles',(.24,.23,.20),.84,True)
wet=material('Wet dark cobbles',(.115,.12,.095),.65,True)
soil=material('Damp alluvial soil',(.12,.105,.068),.95,True)
grass=material('Riparian olive grass',(.08,.145,.027),.93)
straw=material('Dry grass tips',(.23,.23,.10),.98)

# One small source polyhedron, perturbed separately for every rounded stone.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
template=bpy.context.object
tv=[v.co.copy() for v in template.data.vertices]
tf=[tuple(p.vertices) for p in template.data.polygons]
bpy.data.objects.remove(template,do_unlink=True)

def build(variant):
    rng=random.Random(827+variant*137)
    batches={m:([],[],[]) for m in [stone,wet,soil,grass,straw]}
    def add(mat,verts,faces,smooth=True):
        vv,ff,ss=batches[mat];base=len(vv)
        vv.extend(verts);ff.extend([tuple(base+i for i in f) for f in faces]);ss.extend([smooth]*len(faces))
    # Mixed cobble sizes in clustered deposits with bare gaps between them;
    # the wet edge has darker stones. A natural bank is patchy gravel, never
    # a continuous riprap wall — stones stay pebble-sized, boulders are rare.
    centers=[rng.uniform(-2.7,2.7) for _ in range(4)]
    for i in range(190 if variant!=1 else 130):
        c=rng.choice(centers)
        x=c+rng.gauss(0,.9)
        x=max(-2.9,min(2.9,x))
        z=rng.uniform(-.6,1.7)
        density=.60+.35*math.sin(x*1.8+variant)
        if z>1 and rng.random()>density: continue
        r=rng.uniform(.02,.075) if i>26 else rng.uniform(.07,.13)
        sx,sy,sz=r*rng.uniform(.8,1.4),r*rng.uniform(.35,.65),r*rng.uniform(.75,1.2)
        angle=rng.random()*math.tau
        base=-.075 if z<0 else .014
        points=[]
        for p in tv:
            jitter=rng.uniform(.92,1.08)
            a,b=p.x*sx*jitter,p.y*sz*jitter
            points.append((x+a*math.cos(angle)-b*math.sin(angle),base+sy+p.z*sy*jitter,z+a*math.sin(angle)+b*math.cos(angle)))
        add(wet if z<.22 else stone,points,tf)
    # Clumped curved grass, bare gravel gaps, a few taller riverside rushes.
    for clump in range(65 if variant!=0 else 35):
        x=rng.uniform(-2.85,2.85);z=rng.uniform(.65,2.15)
        h=rng.uniform(.12,.32)
        if clump%13==0: h=.55
        for blade in range(rng.randint(7,12)):
            a=rng.random()*math.tau;length=h*rng.uniform(.6,1.2)
            xx=x+rng.uniform(-.14,.14);zz=z+rng.uniform(-.14,.14)
            width=rng.uniform(.007,.018);bend=length*.35
            side=Vector((math.cos(a)*width,0,math.sin(a)*width))
            base=Vector((xx,.023,zz));mid=base+Vector((math.sin(a)*bend*.3,length*.58,math.cos(a)*bend*.3))
            tip=base+Vector((math.sin(a)*bend,length,math.cos(a)*bend))
            add(straw if rng.random()<.14 else grass,[base-side,base+side,mid-side*.6,mid+side*.6,tip],[(0,1,2),(1,3,2),(2,3,4)],False)
    objects=[]
    for mat,(verts,faces,smooth) in batches.items():
        if not verts: continue
        data=bpy.data.meshes.new(mat.name)
        data.from_pydata([(x,-z,y) for x,y,z in verts],[],faces);data.update()
        uv=data.uv_layers.new()
        for poly,is_smooth in zip(data.polygons,smooth):
            poly.use_smooth=is_smooth
            for loop in poly.loop_indices:
                p=data.vertices[data.loops[loop].vertex_index].co
                uv.data[loop].uv=(p.x*1.7,p.y*1.7+p.z)
        obj=bpy.data.objects.new(mat.name,data);bpy.context.collection.objects.link(obj)
        data.materials.append(mat);objects.append(obj)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects: obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name='Riverbank_%d'%variant
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT/('riverbank_reference_%d.glb'%variant)),export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=88)
    # Gallery layout is only in the editable Blender source; exports stay centred.
    obj.location.x=variant*7
    return obj

for variant in range(3): build(variant)
SOURCE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('REFERENCE_RIVERBANKS_EXPORTED',OUT)
