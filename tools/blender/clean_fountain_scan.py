"""Trim scan garbage off district_fountain.glb: flat plates past the octagon
radius and stray capture under the bowl. In-place; Godot Y up -> Blender Z."""
import bpy, bmesh, math
from pathlib import Path
GLB=Path(__file__).resolve().parents[2]/'assets/models/environment/city/district_fountain.glb'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(GLB))
CX,CY=-0.11,-1.15  # fountain axis in Blender XY (Godot x=-0.11, z=1.15)
RADIAL_CUT=1.22    # octagon outer apothem ~1.15-1.2; wings sit past this
# The scan was captured on a tall museum display stand (thin pole through the
# bowl) and the decorative urn is a detached floating shell. Slicing below
# the bowl base drops the stand; slicing above the rim drops the urn — what
# remains is a clean octagonal stone bowl a generated pedestal can carry.
STAND_CUT=0.30
URN_CUT=0.87
removed=0
for o in bpy.data.objects:
 if o.type!='MESH':continue
 bm=bmesh.new();bm.from_mesh(o.data)
 doomed=[v for v in bm.verts if math.hypot(v.co.x-CX,v.co.y-CY)>RADIAL_CUT or v.co.z<STAND_CUT or v.co.z>URN_CUT]
 removed+=len(doomed)
 bmesh.ops.delete(bm,geom=doomed,context='VERTS')
 bm.to_mesh(o.data);bm.free()
bpy.ops.export_scene.gltf(filepath=str(GLB),export_format='GLB',export_animations=False)
print('FOUNTAIN_CLEANED removed=%d'%removed)
