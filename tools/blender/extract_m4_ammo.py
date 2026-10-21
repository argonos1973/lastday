import bpy
import sys
from pathlib import Path

# Extract the M4's magazine and cartridge meshes into standalone pickup GLBs.
# Run: Blender --background --python tools/blender/extract_m4_ammo.py
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'assets' / 'models' / 'weapons' / 'm4_carbine_rifle.glb'
OUT = ROOT / 'assets' / 'models' / 'weapons'

def clean_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def import_rifle():
    bpy.ops.import_scene.gltf(filepath=str(SRC))

def export_part(prefix: str, out_name: str) -> None:
    clean_scene()
    import_rifle()
    keep = []
    for obj in bpy.data.objects:
        if obj.type == 'MESH' and obj.name.startswith(prefix):
            keep.append(obj)
    if not keep:
        print('MISSING', prefix, [o.name for o in bpy.data.objects])
        return
    for obj in list(bpy.data.objects):
        if obj not in keep and obj.type == 'MESH':
            bpy.data.objects.remove(obj, do_unlink=True)
    # Unparent (importer hangs meshes under rotated empties) so local == world.
    for obj in keep:
        mw = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = mw
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)
    # Recenter: XY center, bottom on Z=0 so the pickup sits on the floor.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in keep:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = keep[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()
    import mathutils
    mins = [1e9] * 3
    maxs = [-1e9] * 3
    for obj in keep:
        for corner in obj.bound_box:
            w = obj.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
                maxs[i] = max(maxs[i], w[i])
    cx, cy = (mins[0] + maxs[0]) / 2.0, (mins[1] + maxs[1]) / 2.0
    for obj in keep:
        obj.location.x -= cx
        obj.location.y -= cy
        obj.location.z -= mins[2]
    # The M4 model is ~9x underscale; bring the pickup parts to real size.
    for obj in keep:
        obj.scale = (obj.scale[0] * 9.0, obj.scale[1] * 9.0, obj.scale[2] * 9.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.context.view_layer.update()
    # Second pass: bound_box is stale until here — drop the base to Z=0.
    mins = [1e9] * 3
    for obj in keep:
        for corner in obj.bound_box:
            w = obj.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                mins[i] = min(mins[i], w[i])
    for obj in keep:
        obj.location.z -= mins[2]
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / out_name), export_format='GLB', export_yup=True,
        use_selection=False)
    print('WROTE', OUT / out_name)

export_part('Magazine', 'm4_magazine.glb')
export_part('Bullets', 'm4_bullets.glb')
