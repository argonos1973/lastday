"""
blender_remove_orphan_meshes.py
================================

Removes cloth_torso and cloth_legs meshes from player_with_clothes.glb
and re-exports it without those nodes.

Run headless:

  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python clothing_pipeline/blender_remove_orphan_meshes.py -- \
    --input assets/characters/adapted/player_with_clothes.glb \
    --output assets/characters/adapted/player_with_clothes.glb
"""

import bpy
import sys
import os


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    input_path = "assets/characters/adapted/player_with_clothes.glb"
    output_path = "assets/characters/adapted/player_with_clothes.glb"
    i = 0
    while i < len(argv):
        if argv[i] == "--input":
            input_path = argv[i + 1]; i += 2
        elif argv[i] == "--output":
            output_path = argv[i + 1]; i += 2
        else:
            i += 1
    return input_path, output_path


def main():
    input_path, output_path = parse_args()
    input_path = os.path.abspath(input_path)
    output_path = os.path.abspath(output_path)
    print(f"=== REMOVE orphan meshes from {input_path} ===")

    # Import the GLB
    bpy.ops.import_scene.gltf(filepath=input_path)
    print("  imported GLB")

    # Collect all objects and remove cloth_torso / cloth_legs
    remove_names = {"cloth_torso", "cloth_legs"}
    removed = []
    for obj in list(bpy.data.objects):
        base_name = obj.name.split(".")[0]
        if obj.name in remove_names or base_name in remove_names:
            name = obj.name
            print(f"  removing: {name} (type={obj.type})")
            bpy.data.objects.remove(obj, do_unlink=True)
            removed.append(name)

    print(f"  removed {len(removed)} objects: {removed}")

    # Also purge orphan mesh data
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)

    # Select all remaining objects for export
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.data.objects:
        obj.select_set(True)

    # Export
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format='GLB',
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_image_format='AUTO',
        export_materials='EXPORT',
        export_skins=True,
        export_animations=False,
        export_extras=True,
    )
    print(f"  exported -> {output_path}")
    print("=== DONE ===")


if __name__ == "__main__":
    main()
