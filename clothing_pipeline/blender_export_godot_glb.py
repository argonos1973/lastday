"""
blender_export_godot_glb.py
===========================

Take the adapted .blend produced by blender_adapt_survival_clothes_to_mixamo.py
and export Godot-4-ready .glb files:

  * <out_dir>/player_with_clothes.glb
        The Mixamo character (armature + body + Mixamo meshes) PLUS the adapted
        survival clothing (Jacket / Jeans / Gloves / Shoes), all sharing the one
        Mixamo armature. No survival armature is exported (it was removed during
        adapt). Each garment is exported as its own node so Godot can show/hide
        it per equipment slot.

  * <out_dir>/gear_<slot>.glb   (one per rigid item, e.g. gear_backpack.glb)
        Each rigid object (backpack, ...) on its own, at the origin, ready to be
        instanced under a BoneAttachment3D in Godot.

  * <out_dir>/gear_manifest.json
        slot -> {file, attach_bone} so the Godot equipment script knows where to
        attach each rigid item.

PBR materials/textures (albedo/normal/roughness/metallic) are preserved by the
glTF exporter (export_image_format='AUTO').

Run headless:

  /Applications/Blender.app/Contents/MacOS/Blender --background \
     outputs/adapted_player.blend \
     --python clothing_pipeline/blender_export_godot_glb.py -- \
     --out-dir assets/characters/adapted
"""

import bpy
import sys
import os
import json
import math


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    out_dir = "assets/characters/adapted"
    i = 0
    while i < len(argv):
        if argv[i] == "--out-dir":
            out_dir = argv[i + 1]; i += 2
        else:
            i += 1
    return out_dir


def deselect_all():
    bpy.ops.object.select_all(action='DESELECT')


def select(objs):
    deselect_all()
    last = None
    for o in objs:
        o.select_set(True)
        last = o
    if last is not None:
        bpy.context.view_layer.objects.active = last


def export_selected(path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=False,          # modifiers (Armature) kept live for Godot
        export_yup=True,
        export_image_format='AUTO',  # keep PBR textures
        export_materials='EXPORT',
        export_skins=True,
        export_animations=False,     # animations come from the Mixamo anim files
        export_extras=True,          # keep custom props (attach_bone, etc.)
    )
    print(f"  exported -> {path}")


def export_static_mesh(obj, path):
    """Export ONE garment as a static, un-skinned glb for the world 'pickup'
    visual. The garment is baked from the current REST/T-pose, then LAID FLAT and
    centred on the origin so it reads as a piece of clothing dropped on the ground
    (instead of a standing, vertically T-posed garment that looked like it was
    floating in the world)."""
    os.makedirs(os.path.dirname(path), exist_ok=True)

    # Work on a throwaway copy so the source scene (and player export) is intact.
    deselect_all()
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    bpy.context.view_layer.objects.active = copy
    copy.select_set(True)

    # Bake the live Armature modifier (current REST pose) into the copy mesh.
    for m in list(copy.modifiers):
        if m.type == 'ARMATURE':
            try:
                bpy.ops.object.modifier_apply(modifier=m.name)
            except RuntimeError:
                copy.modifiers.remove(m)
    copy.parent = None

    # Rotate the vertical garment down onto its back (spine axis Z -> horizontal),
    # apply it, then drop the origin to the geometry centre at the world origin.
    copy.rotation_euler = (math.radians(-90.0), 0.0, 0.0)
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
    out_dir = os.path.abspath(parse_args())
    os.makedirs(out_dir, exist_ok=True)
    print(f"=== EXPORT adapted player -> {out_dir} ===")

    armature = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    if armature is None:
        print("  [FATAL] no armature in the adapted scene")
        return

    # bake everything from the clean REST (T-pose) bind, not a stray anim frame,
    # so the static pickup visuals come out as tidy garments.
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    # drop leftover bounding-helper meshes (e.g. Icosphere) outright
    for o in [o for o in bpy.data.objects if o.type == 'MESH'
              and o.name.split(".")[0] == "Icosphere"]:
        bpy.data.objects.remove(o, do_unlink=True)

    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    rigid = [o for o in meshes if o.get("rigid_slot")]
    rigid_names = {o.name for o in rigid}
    # everything skinned to the armature (character + clothing) except rigid gear
    char_and_clothes = [armature] + [o for o in meshes if o.name not in rigid_names]

    # 1) player + clothes (shared Mixamo armature)
    print("\n[1] export player + adapted clothing")
    select(char_and_clothes)
    export_selected(os.path.join(out_dir, "player_with_clothes.glb"))

    # 2) each rigid gear item on its own + manifest
    print("\n[2] export rigid gear")
    manifest = {}
    for obj in rigid:
        slot = str(obj.get("rigid_slot"))
        attach = str(obj.get("attach_bone", "mixamorig:Spine2"))
        fname = f"gear_{slot}.glb"
        # move a copy to origin so it instances cleanly under a BoneAttachment3D
        select([obj])
        export_selected(os.path.join(out_dir, fname))
        manifest[slot] = {"file": fname, "attach_bone": attach}
        print(f"  gear '{obj.name}' slot={slot} attach_bone={attach}")

    with open(os.path.join(out_dir, "gear_manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(f"\nManifest -> {os.path.join(out_dir, 'gear_manifest.json')}")

    # 3) each clothing piece as a static pickup visual (lying on the ground)
    print("\n[3] export clothing pickup visuals")
    cloth = [o for o in bpy.data.objects
             if o.type == 'MESH' and o.name.startswith("cloth_")]
    for obj in cloth:
        export_static_mesh(obj, os.path.join(out_dir, "pickup_%s.glb" % obj.name))

    print("=== EXPORT done ===")


if __name__ == "__main__":
    main()
