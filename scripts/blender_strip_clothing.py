"""
Blender script: strip clothing from Mixamo character GLBs and export each
garment as an individual GLB for use as loot pickups in Godot.

Usage:
    blender --background --python scripts/blender_strip_clothing.py -- <input_glb> <output_dir> [character_name]

If the character already has separate clothing meshes (e.g. Tops, Bottoms, Shoes),
they are exported directly. If the clothing is baked into a single body mesh
(e.g. Soldier_body), it is separated by bone weights into torso/legs/feet/hands parts.

The script also exports the naked body (with clothing meshes removed) as
<character_name>_naked.glb.
"""

import bpy
import sys
import os
import math

P = "mixamorig:"

# Bone groups for separating clothing from a single body mesh
TORSO_BONES = [P+"Hips", P+"Spine", P+"Spine1", P+"Spine2",
               P+"LeftShoulder", P+"RightShoulder",
               P+"LeftArm", P+"RightArm",
               P+"LeftForeArm", P+"RightForeArm",
               P+"Neck", P+"Neck1", P+"Head"]
LEGS_BONES = [P+"LeftUpLeg", P+"RightUpLeg", P+"LeftLeg", P+"RightLeg"]
FEET_BONES = [P+"LeftFoot", P+"RightFoot", P+"LeftToeBase", P+"RightToeBase",
              P+"LeftToe_End", P+"RightToe_End"]
HANDS_BONES = [P+"LeftHand", P+"RightHand",
               P+"LeftHandThumb1", P+"LeftHandThumb2", P+"LeftHandThumb3", P+"LeftHandThumb4",
               P+"RightHandThumb1", P+"RightHandThumb2", P+"RightHandThumb3", P+"RightHandThumb4",
               P+"LeftHandIndex1", P+"LeftHandIndex2", P+"LeftHandIndex3", P+"LeftHandIndex4",
               P+"RightHandIndex1", P+"RightHandIndex2", P+"RightHandIndex3", P+"RightHandIndex4",
               P+"LeftHandMiddle1", P+"LeftHandMiddle2", P+"LeftHandMiddle3", P+"LeftHandMiddle4",
               P+"RightHandMiddle1", P+"RightHandMiddle2", P+"RightHandMiddle3", P+"RightHandMiddle4",
               P+"LeftHandRing1", P+"LeftHandRing2", P+"LeftHandRing3", P+"LeftHandRing4",
               P+"RightHandRing1", P+"RightHandRing2", P+"RightHandRing3", P+"RightHandRing4",
               P+"LeftHandPinky1", P+"LeftHandPinky2", P+"LeftHandPinky3", P+"LeftHandPinky4",
               P+"RightHandPinky1", P+"RightHandPinky2", P+"RightHandPinky3", P+"RightHandPinky4"]

# Known clothing mesh names in Mixamo characters (case-insensitive)
CLOTHING_MESH_KEYWORDS = ["tops", "bottoms", "shoes", "shirt", "pants", "jacket",
                          "boots", "gloves", "vest", "armor", "helmet", "hat",
                          "scarf", "cape", "coat", "dress", "skirt"]
# Known body/skin mesh names (not clothing)
BODY_MESH_KEYWORDS = ["body", "skin", "head", "face", "hair", "eyes", "eyelashes",
                      "teeth", "nude", "desnudo"]


def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for mesh in bpy.data.meshes:
        bpy.data.meshes.remove(mesh)
    for arm in bpy.data.armatures:
        bpy.data.armatures.remove(arm)
    for mat in bpy.data.materials:
        bpy.data.materials.remove(mat)


def find_armature():
    for obj in bpy.context.scene.objects:
        if obj.type == 'ARMATURE':
            return obj
    return None


def is_clothing_mesh(name):
    lower = name.lower()
    for kw in CLOTHING_MESH_KEYWORDS:
        if kw in lower:
            return True
    return False


def is_body_mesh(name):
    lower = name.lower()
    for kw in BODY_MESH_KEYWORDS:
        if kw in lower:
            return True
    return False


def separate_by_bone_weights(obj, part_name, bone_names):
    """Split obj: vertices whose dominant bone is in bone_names go to a new object."""
    vg_names = {i: vg.name for i, vg in enumerate(obj.vertex_groups)}
    bone_set = set(bone_names)
    vertex_mask = [False] * len(obj.data.vertices)
    for v in obj.data.vertices:
        max_w = 0.0
        max_b = ""
        for g in v.groups:
            if g.weight > max_w:
                max_w = g.weight
                max_b = vg_names.get(g.group, "")
        vertex_mask[v.index] = max_b in bone_set

    count = sum(1 for x in vertex_mask if x)
    print(f"  {part_name}: {count} vertices")

    if count == 0:
        return None

    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')

    for v in obj.data.vertices:
        v.select = vertex_mask[v.index]

    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')

    new_obj = None
    for o in bpy.context.scene.objects:
        if o.type == 'MESH' and o != obj:
            if len(o.data.vertices) == count:
                new_obj = o
                break

    if new_obj is None:
        print(f"  WARNING: could not find separated object for {part_name}")
        return None

    new_obj.name = part_name
    new_obj.data.name = part_name
    return new_obj


def export_glb(objects, filepath):
    """Export only the specified objects (plus their armature parent) to a GLB."""
    # Deselect everything
    bpy.ops.object.select_all(action='DESELECT')
    # Select the armature and the target objects
    armature = find_armature()
    if armature:
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature
    for obj in objects:
        if obj is not None and obj.name in bpy.context.scene.objects:
            obj.select_set(True)

    # Temporarily hide other meshes so they don't get exported
    hidden = []
    for o in bpy.context.scene.objects:
        if o.type == 'MESH' and not o.select_get():
            hidden.append(o)
            o.hide_set(True)

    bpy.ops.export_scene.gltf(
        filepath=filepath,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )

    # Unhide
    for o in hidden:
        o.hide_set(False)

    print(f"  Exported: {filepath}")


def process_character(input_path, output_dir, char_name):
    """Process a single Mixamo character GLB."""
    print(f"\n{'='*60}")
    print(f"Processing: {input_path}")
    print(f"Character name: {char_name}")
    print(f"Output dir: {output_dir}")
    print(f"{'='*60}")

    clear_scene()
    bpy.ops.import_scene.gltf(filepath=input_path)

    armature = find_armature()
    if armature is None:
        print("ERROR: No armature found in GLB")
        return

    # List all meshes
    all_meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    print(f"\nFound {len(all_meshes)} meshes:")
    for m in all_meshes:
        print(f"  {m.name} ({len(m.data.vertices)} verts)")

    # Classify meshes
    clothing_meshes = []
    body_meshes = []
    other_meshes = []

    for m in all_meshes:
        lower = m.name.lower()
        # Skip helper meshes
        if lower in ["icosphere", "cube", "plane"] or "icosphere" in lower or "cube" in lower:
            other_meshes.append(m)
            continue
        if is_clothing_mesh(m.name):
            clothing_meshes.append(m)
            print(f"  -> {m.name}: CLOTHING")
        elif is_body_mesh(m.name):
            body_meshes.append(m)
            print(f"  -> {m.name}: BODY/SKIN")
        else:
            # Unknown mesh - check if it has clothing-like vertex distribution
            # Heuristic: if it has vertices in the torso/legs area and is not
            # clearly body, treat it as clothing
            print(f"  -> {m.name}: UNKNOWN (will check bone weights)")

    # If no clothing meshes found by name, try to separate from body meshes
    # using bone weights (e.g. Soldier_body has clothing baked in)
    if not clothing_meshes:
        print("\nNo clothing meshes found by name. Attempting bone-weight separation...")
        for body_obj in body_meshes:
            if "head" in body_obj.name.lower() or "face" in body_obj.name.lower():
                continue
            print(f"\nSeparating clothing from: {body_obj.name}")

            # Separate hands
            hands = separate_by_bone_weights(body_obj, f"{char_name}_hands", HANDS_BONES)
            if hands:
                clothing_meshes.append(hands)

            # Separate feet
            feet = separate_by_bone_weights(body_obj, f"{char_name}_feet", FEET_BONES)
            if feet:
                clothing_meshes.append(feet)

            # Separate legs
            legs = separate_by_bone_weights(body_obj, f"{char_name}_legs", LEGS_BONES)
            if legs:
                clothing_meshes.append(legs)

            # Separate torso (what remains weighted to spine/arms/shoulders)
            torso = separate_by_bone_weights(body_obj, f"{char_name}_torso", TORSO_BONES)
            if torso:
                clothing_meshes.append(torso)

    # Export each clothing piece as individual GLB
    print(f"\nExporting {len(clothing_meshes)} clothing pieces...")
    exported = []
    for cloth in clothing_meshes:
        safe_name = cloth.name.replace(" ", "_").lower()
        out_path = os.path.join(output_dir, f"pickup_{safe_name}.glb")
        export_glb([cloth], out_path)
        exported.append(f"pickup_{safe_name}.glb")

    # Export naked body (hide clothing, export rest)
    print("\nExporting naked body...")
    for cloth in clothing_meshes:
        cloth.hide_set(True)
    for other in other_meshes:
        other.hide_set(True)

    naked_path = os.path.join(output_dir, f"{char_name}_naked.glb")
    bpy.ops.object.select_all(action='DESELECT')
    armature = find_armature()
    if armature:
        armature.select_set(True)
        bpy.context.view_layer.objects.active = armature
    for body in body_meshes:
        if body.name in bpy.context.scene.objects:
            body.select_set(True)
    # Also select remaining body parts (after separation, the leftover mesh)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH' and not o.hide_get() and not o.select_get():
            # This is likely the remains of a separated body mesh
            o.select_set(True)

    bpy.ops.export_scene.gltf(
        filepath=naked_path,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_yup=True,
    )
    print(f"  Exported: {naked_path}")

    # Unhide everything
    for o in bpy.context.scene.objects:
        o.hide_set(False)

    # Print summary
    print(f"\n{'='*60}")
    print(f"SUMMARY for {char_name}:")
    print(f"  Clothing pieces exported: {len(exported)}")
    for name in exported:
        print(f"    - {name}")
    print(f"  Naked body: {char_name}_naked.glb")
    print(f"{'='*60}")

    return exported


def main():
    # Parse arguments after "--"
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []

    if len(argv) < 2:
        print("Usage: blender --background --python blender_strip_clothing.py -- <input_glb> <output_dir> [character_name]")
        print("")
        print("Arguments:")
        print("  input_glb       Path to the Mixamo character GLB file")
        print("  output_dir      Directory where pickup GLBs will be exported")
        print("  character_name  (optional) Name prefix for exported files")
        print("")
        print("Examples:")
        print("  blender --background --python blender_strip_clothing.py -- soldado.glb assets/adapted/ soldier")
        print("  blender --background --python blender_strip_clothing.py -- leftturn.glb assets/adapted/ leftturn")
        return

    input_path = argv[0]
    output_dir = argv[1]
    char_name = argv[2] if len(argv) > 2 else os.path.splitext(os.path.basename(input_path))[0]

    if not os.path.exists(input_path):
        print(f"ERROR: Input file not found: {input_path}")
        return

    os.makedirs(output_dir, exist_ok=True)

    process_character(input_path, output_dir, char_name)


if __name__ == "__main__":
    main()
