"""Build district_fountain.glb from the original photogrammetry scan
(tools/blender/sources/fuente_scan.glb): a complete ground-standing stone
fountain — octagonal basin, column and finial — captured on a patch of paving.

Everything is measured in WORLD space (the Sketchfab root carries a rotation;
local mesh coordinates are meaningless). Steps: bake transforms, recentre the
basin on the origin with its base at z=0, drop the scanned paving patch
outside the basin footprint, decimate, and add a 'FountainWater' sheet whose
outline follows the real inner rim. Blender Z up = Godot Y."""
import bpy, bmesh, math
from mathutils import Matrix, Vector
from pathlib import Path
R=Path(__file__).resolve().parents[2]
SRC=R/'tools/blender/sources/fuente_scan.glb'
OUT=R/'assets/models/environment/city/district_fountain.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SRC))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
for o in meshes:
 o.data.transform(o.matrix_world);o.parent=None;o.matrix_world=Matrix.Identity(4)
for o in list(bpy.data.objects):
 if o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
# Column/finial axis: centroid of everything above the basin rim.
top=[v.co for o in meshes for v in o.data.vertices if v.co.z>1.3]
cx=sum(p.x for p in top)/len(top);cy=sum(p.y for p in top)/len(top)
base=min(v.co.z for o in meshes for v in o.data.vertices if math.hypot(v.co.x-cx,v.co.y-cy)<1.0)
for o in meshes:o.data.transform(Matrix.Translation(Vector((-cx,-cy,-base))))
# The basin's outer apothem is ~1.0 m; the scanned paving lies flat beyond it.
removed=0
for o in meshes:
 bm=bmesh.new();bm.from_mesh(o.data)
 doomed=[v for v in bm.verts if math.hypot(v.co.x,v.co.y)>1.06 or (v.co.z<0.035 and math.hypot(v.co.x,v.co.y)>1.0)]
 removed+=len(doomed);bmesh.ops.delete(bm,geom=doomed,context='VERTS')
 # Paving fringe between the octagon corners: flat, ground-level faces.
 bm.normal_update()
 skirt=[f for f in bm.faces if f.normal.z>.6 and max(v.co.z for v in f.verts)<.06 and math.hypot(*f.calc_center_median().xy)>.8]
 removed+=len(skirt);bmesh.ops.delete(bm,geom=skirt,context='FACES')
 loose=[v for v in bm.verts if not v.link_faces];bmesh.ops.delete(bm,geom=loose,context='VERTS')
 bm.to_mesh(o.data);bm.free()
 dec=o.modifiers.new('Decimate','DECIMATE');dec.ratio=0.3
 bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=dec.name)
# Water outline: nearest rim wall per angular sector, just below the coping.
WATER_Z=0.52;SECT=48
inner=[9.0]*SECT
for o in meshes:
 for v in o.data.vertices:
  r=math.hypot(v.co.x,v.co.y)
  if .44<v.co.z<.60 and r>.38:
   s=int(math.atan2(v.co.y,v.co.x)%math.tau/math.tau*SECT)%SECT
   inner[s]=min(inner[s],r)
for s in range(SECT):
 if inner[s]>2:inner[s]=min(x for x in inner if x<2)
verts=[(0,0,WATER_Z)]+[((inner[s]-.015)*math.cos((s+.5)*math.tau/SECT),(inner[s]-.015)*math.sin((s+.5)*math.tau/SECT),WATER_Z) for s in range(SECT)]
me=bpy.data.meshes.new('FountainWater');me.from_pydata(verts,[],[(0,s+1,(s+1)%SECT+1) for s in range(SECT)]);me.update()
water=bpy.data.objects.new('FountainWater',me);bpy.context.collection.objects.link(water)
water.data.materials.append(bpy.data.materials.new('FountainWater'))
tris=sum(len(o.data.polygons) for o in meshes)
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',export_animations=False)
print('FOUNTAIN_READY axis=(%.3f,%.3f) base=%.3f removed=%d tris=%d rim=%.2f..%.2f'%(cx,cy,base,removed,tris,min(inner),max(inner)))
