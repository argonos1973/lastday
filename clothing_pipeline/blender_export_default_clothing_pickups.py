"""
blender_export_default_clothing_pickups.py
==========================================

Extract the default character clothing meshes (Tops, Bottoms, Shoes) from
player_with_clothes.glb and export each as a static, laid-flat pickup .glb so
the dropped item on the ground matches what the character is actually wearing.

Run headless:

  /Applications/Blender.app/Contents/MacOS/Blender --background \
     --python clothing_pipeline/blender_export_default_clothing_pickups.py -- \
     --src assets/characters/adapted/player_with_clothes.glb \
     --out-dir assets/characters/adapted
"""

import bpy
import sys
import os
import math


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    src = "assets/characters/adapted/player_with_clothes.glb"
    out_dir = "assets/characters/adapted"
    i = 0
    while i < len(argv):
        if argv[i] == "--src":
            src = argv[i + 1]; i += 2
        elif argv[i] == "--out-dir":
            out_dir = argv[i + 1]; i += 2
        else:
            i += 1
    return os.path.abspath(src), os.path.abspath(out_dir)


def deselect_all():
    bpy.ops.object.select_all(action='DESELECT')


def export_static_mesh(obj, path, scale=1.0, auto_orient=True, fixed_rotation=None):
    """Bake current REST pose into a throwaway copy, keep it STANDING (the same
    orientation the survival cloth pickups have), optionally scale it down to
    metres, centre it on the origin and export as an un-skinned static glb pickup
    visual. The in-game `lay_flat` rotation (+90 on X) then tips it onto the
    ground consistently with every other garment pickup."""
    os.makedirs(os.path.dirname(path), exist_ok=True)

    deselect_all()
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    bpy.context.view_layer.objects.active = copy
    copy.select_set(True)

    for m in list(copy.modifiers):
        if m.type == 'ARMATURE':
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except RuntimeError:
                copy.modifiers.remove(m)
    copy.parent = None

    # Normalise the scale from centimetres to metres so it matches cloth pickups.
    copy.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    deselect_all()
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Auto lay-flat: rotate the garment so its SMALLEST bounding-box extent points
    # up (Blender Z), i.e. it lies on the ground like a real dropped garment. The
    # exporter writes Y-up, so the smallest extent ends up as the world height and
    # NO further rotation is needed in-game.
    # Skipped for shoes: their native (standing-character) orientation already has
    # the soles facing down, so auto-orienting would tip them onto their side.
    if fixed_rotation is not None:
        copy.rotation_euler = tuple(math.radians(a) for a in fixed_rotation)
    elif auto_orient:
        dx, dy, dz = copy.dimensions
        smallest = min(dx, dy, dz)
        if smallest == dx:
            # X is thinnest -> rotate about Y so X becomes vertical (Z)
            copy.rotation_euler = (0.0, math.radians(90.0), 0.0)
        elif smallest == dy:
            # Y is thinnest -> rotate about X so Y becomes vertical (Z)
            copy.rotation_euler = (math.radians(90.0), 0.0, 0.0)
        # else Z already thinnest -> already flat, no rotation
    bpy.context.view_layer.update()
    deselect_all()
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    copy.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()

    deselect_all()
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_image_format='AUTO',
        export_materials='EXPORT',
        export_skins=False,
        export_animations=False,
    )
    print(f"  pickup-visual -> {path}")
    bpy.data.objects.remove(copy, do_unlink=True)


def main():
    src, out_dir = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    print(f"=== EXPORT default clothing pickups from {src} -> {out_dir} ===")

    # clean scene
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)

    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    # Map mesh name -> output pickup filename
    wanted = {
        "Tops": "pickup_default_tops.glb",
        "Bottoms": "pickup_default_bottoms.glb",
        "Shoes": "pickup_default_shoes.glb",
    }

    by_name = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
    print("  meshes in scene:", sorted(by_name.keys()))

    for mesh_name, fname in wanted.items():
        obj = by_name.get(mesh_name)
        if obj is None:
            print(f"  [WARN] mesh '{mesh_name}' not found, skipping")
            continue
        # The mixamo character meshes are in centimetres (~140 units), the cloth
        # pickups are in metres (~3 units); scale down so both share the same
        # in-game drop scale. The rest pose has the feet plantar-flexed (toes
        # down), so auto-orienting tips the shoes onto their tips; flip them 180°
        # on X instead so the soles face the ground.
        if mesh_name == "Shoes":
            export_static_mesh(obj, os.path.join(out_dir, fname), scale=0.01, fixed_rotation=(180.0, 0.0, 0.0))
        else:
            export_static_mesh(obj, os.path.join(out_dir, fname), scale=0.01, auto_orient=True)

    print("=== EXPORT done ===")


if __name__ == "__main__":
    main()
