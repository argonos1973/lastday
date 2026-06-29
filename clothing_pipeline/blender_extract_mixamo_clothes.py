"""
blender_extract_mixamo_clothes.py
=================================
Extracts clothing pieces from ANY Mixamo character GLB and integrates them
into player_with_clothes.glb as new skinned meshes + static pickup GLBs.

Works by splitting the source body mesh by dominant bone weights:
  - torso  = spine, arms, hands, head
  - legs   = hips, legs, feet
  - hands  = hand/finger bones only
  - feet   = foot/toe bones only

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python clothing_pipeline/blender_extract_mixamo_clothes.py -- \
    --player assets/characters/adapted/player_with_clothes.glb \
    --source "Crouch Turn Right 90.glb" \
    --out-dir assets/characters/adapted \
    --prefix soldier \
    --slots torso,legs
"""

import bpy
import sys
import os
import math
import mathutils
import bmesh


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    player = "assets/characters/adapted/player_with_clothes.glb"
    source = ""
    out_dir = "assets/characters/adapted"
    prefix = "cloth"
    slots = "torso,legs"
    i = 0
    while i < len(argv):
        if argv[i] == "--player":   player = argv[i+1]; i += 2
        elif argv[i] == "--source": source = argv[i+1]; i += 2
        elif argv[i] == "--out-dir": out_dir = argv[i+1]; i += 2
        elif argv[i] == "--prefix":  prefix = argv[i+1]; i += 2
        elif argv[i] == "--slots":   slots = argv[i+1]; i += 2
        else: i += 1
    return (os.path.abspath(player), os.path.abspath(source),
            os.path.abspath(out_dir), prefix, slots.split(","))


# Bone prefixes that define each clothing slot
SLOT_BONES = {
    "torso": [
        "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
        "mixamorig:Neck", "mixamorig:Neck1", "mixamorig:Head",
        "mixamorig:HeadTop_End", "mixamorig:LeftEye", "mixamorig:RightEye",
        "mixamorig:Jaw",
        "mixamorig:LeftShoulder", "mixamorig:LeftArm",
        "mixamorig:LeftForeArm", "mixamorig:LeftHand",
        "mixamorig:RightShoulder", "mixamorig:RightArm",
        "mixamorig:RightForeArm", "mixamorig:RightHand",
    ],
    "legs": [
        "mixamorig:Hips",
        "mixamorig:LeftUpLeg", "mixamorig:LeftLeg",
        "mixamorig:LeftFoot", "mixamorig:LeftToeBase", "mixamorig:LeftToe_End",
        "mixamorig:RightUpLeg", "mixamorig:RightLeg",
        "mixamorig:RightFoot", "mixamorig:RightToeBase", "mixamorig:RightToe_End",
    ],
    "hands": [
        "mixamorig:LeftHand", "mixamorig:RightHand",
    ],
    "feet": [
        "mixamorig:LeftFoot", "mixamorig:RightFoot",
        "mixamorig:LeftToeBase", "mixamorig:RightToeBase",
        "mixamorig:LeftToe_End", "mixamorig:RightToe_End",
    ],
}

# Include finger bones for hands slot
for s in ["Left", "Right"]:
    for f in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
        for n in ["1", "2", "3", "4"]:
            SLOT_BONES["hands"].append(f"mixamorig:{s}Hand{f}{n}")
            SLOT_BONES["torso"].append(f"mixamorig:{s}Hand{f}{n}")


def get_dominant_bone(obj, vindex):
    """Return the vertex group name with highest weight for a vertex."""
    best = None
    best_w = 0.0
    for vg in obj.vertex_groups:
        try:
            w = vg.weight(vindex)
        except (RuntimeError, ValueError, ReferenceError):
            continue
        if w > best_w:
            best_w = w
            best = vg.name
    return best


def bone_matches_slot(bone_name, slot):
    """Check if a bone name belongs to a slot (prefix match)."""
    patterns = SLOT_BONES.get(slot, [])
    for p in patterns:
        if bone_name == p or bone_name.startswith(p):
            return True
    return False


def split_mesh_by_slot(obj, slot, new_name):
    """Duplicate obj, then in edit mode delete all verts whose dominant bone
    is NOT in the slot's bone set. Return the new object."""
    # Duplicate the object
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.duplicate()
    new_obj = bpy.context.view_layer.objects.active
    new_obj.name = new_name

    # Enter edit mode and select verts to DELETE (those NOT in slot)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')

    bm = bmesh.from_edit_mesh(new_obj.data)
    bm.verts.ensure_lookup_table()

    delete_count = 0
    keep_count = 0
    for v in bm.verts:
        bone = get_dominant_bone(new_obj, v.index)
        if bone and bone_matches_slot(bone, slot):
            v.select = False
            keep_count += 1
        else:
            v.select = True
            delete_count += 1

    bmesh.update_edit_mesh(new_obj.data)
    print(f"    {new_name}: keeping {keep_count}, deleting {delete_count}")

    bpy.ops.mesh.delete(type='VERT')
    bpy.ops.object.mode_set(mode='OBJECT')

    print(f"    {new_name}: {len(new_obj.data.vertices)} verts after split")
    return new_obj


def export_static_pickup(obj, path, scale=0.01, lay_flat=True):
    """Export a static (un-skinned) pickup GLB from a mesh."""
    bpy.ops.object.select_all(action='DESELECT')
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy

    # Remove all modifiers
    for m in list(copy.modifiers):
        copy.modifiers.remove(m)
    copy.parent = None

    # Scale cm -> metres
    copy.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    if lay_flat:
        copy.rotation_euler = (math.radians(90), 0, 0)
        bpy.context.view_layer.update()
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    copy.location = (0, 0, 0)
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action='DESELECT')
    copy.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path, export_format='GLB', use_selection=True,
        export_yup=True, export_materials='EXPORT',
        export_skins=False, export_animations=False,
    )
    print(f"  pickup -> {path}")
    bpy.data.objects.remove(copy, do_unlink=True)


def main():
    player_glb, source_glb, out_dir, prefix, slots = parse_args()
    print(f"=== EXTRACT MIXAMO CLOTHES ===")
    print(f"  player: {player_glb}")
    print(f"  source: {source_glb}")
    print(f"  prefix: {prefix}")
    print(f"  slots: {slots}")

    # Step 1: Import player GLB
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=player_glb)
    player_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    print(f"  player armature: {player_arm.name}, bones={len(player_arm.data.bones)}")

    # Step 2: Import source GLB
    bpy.ops.import_scene.gltf(filepath=source_glb)
    source_arm = None
    source_meshes = []
    for o in list(bpy.data.objects):
        if o.type == 'ARMATURE' and o != player_arm:
            source_arm = o
        elif o.type == 'MESH' and o.name not in ("Body", "Tops", "Bottoms", "Shoes",
                "Hair", "Eyes", "cloth_torso", "cloth_legs", "cloth_hands", "cloth_feet",
                "Eyelashes", "Icosphere", "Icosphere.001", "Soldier_head"):
            # This is a mesh from the source file (clothing/body)
            source_meshes.append(o)

    if not source_meshes:
        print("  [FATAL] No source meshes found")
        sys.exit(1)

    print(f"  source armature: {source_arm.name if source_arm else 'None'}")
    print(f"  source meshes: {[m.name for m in source_meshes]}")

    # Step 3: Parent source meshes to player armature (same Mixamo rig)
    for m in source_meshes:
        m.parent = player_arm
        if not any(mod.type == 'ARMATURE' for mod in m.modifiers):
            am = m.modifiers.new("Armature", 'ARMATURE')
            am.object = player_arm
    print(f"  re-parented {len(source_meshes)} meshes to player armature")

    # Step 4: Split each source mesh by requested slots
    print("\n=== SPLITTING ===")
    new_cloth_meshes = []
    for src_mesh in source_meshes:
        for slot in slots:
            mesh_name = f"{prefix}_{slot}"
            new_obj = split_mesh_by_slot(src_mesh, slot, mesh_name)
            if new_obj and len(new_obj.data.vertices) > 0:
                # Ensure armature modifier
                if not any(mod.type == 'ARMATURE' for mod in new_obj.modifiers):
                    am = new_obj.modifiers.new("Armature", 'ARMATURE')
                    am.object = player_arm
                new_cloth_meshes.append(new_obj)
            elif new_obj:
                bpy.data.objects.remove(new_obj, do_unlink=True)
                print(f"    skipped empty {mesh_name}")

    # Step 5: Delete source meshes and source armature (keep only splits)
    print("\n=== CLEANUP ===")
    source_names = [m.name for m in source_meshes]
    for mname in source_names:
        o = bpy.data.objects.get(mname)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            print(f"  deleted source mesh {mname}")

    # Delete source-only helper meshes (Icosphere, heads, etc.)
    extra_names = []
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.name not in ("Body", "Tops", "Bottoms", "Shoes",
                "Hair", "Eyes", "cloth_torso", "cloth_legs", "cloth_hands", "cloth_feet"):
            if o not in new_cloth_meshes:
                extra_names.append(o.name)
    for ename in extra_names:
        o = bpy.data.objects.get(ename)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            print(f"  deleted extra mesh {ename}")

    if source_arm and source_arm.name in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[source_arm.name], do_unlink=True)
        print(f"  deleted source armature")

    # Step 6: Re-export player_with_clothes.glb
    print("\n=== EXPORT PLAYER GLB ===")
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in ([player_arm] + meshes):
        o.select_set(True)
    bpy.context.view_layer.objects.active = player_arm
    bpy.ops.export_scene.gltf(
        filepath=player_glb, export_format='GLB', use_selection=True,
        export_apply=False, export_yup=True, export_image_format='AUTO',
        export_materials='EXPORT', export_skins=True, export_animations=False,
        export_extras=True,
    )
    print(f"  re-exported -> {player_glb}")

    # Step 7: Export static pickups
    print("\n=== EXPORT PICKUPS ===")
    for m in new_cloth_meshes:
        pickup_path = os.path.join(out_dir, f"pickup_{m.name}.glb")
        export_static_pickup(m, pickup_path, scale=0.01, lay_flat=True)

    # Step 8: Render to verify
    print("\n=== RENDER ===")
    scene = bpy.context.scene
    try: scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except: scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 600; scene.render.resolution_y = 600
    w = bpy.data.worlds.new("W"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.6, 1)
    scene.world = w
    ld = bpy.data.lights.new("Sun", 'SUN'); ld.energy = 3
    lo = bpy.data.objects.new("Sun", ld); bpy.context.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(50), 0, math.radians(30))
    cd = bpy.data.cameras.new("C"); cam = bpy.data.objects.new("C", cd)
    bpy.context.collection.objects.link(cam); scene.camera = cam

    visible = {"Body"} | {m.name for m in new_cloth_meshes}
    for o in bpy.data.objects:
        if o.type == 'MESH': o.hide_render = o.name not in visible

    for m in new_cloth_meshes:
        mat = bpy.data.materials.new(f"R_{m.name}")
        mat.diffuse_color = (0.15, 0.18, 0.12, 1)
        m.data.materials.clear()
        m.data.materials.append(mat)

    def bounds(obj):
        mn = mathutils.Vector((1e9,1e9,1e9))
        mx = mathutils.Vector((-1e9,-1e9,-1e9))
        for v in obj.bound_box:
            wv = obj.matrix_world @ mathutils.Vector(v)
            for i in range(3): mn[i]=min(mn[i],wv[i]); mx[i]=max(mx[i],wv[i])
        return mn, mx, (mn+mx)/2

    def render(name, eye, look):
        cam.location = eye
        d = (mathutils.Vector(look) - mathutils.Vector(eye))
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = f"/tmp/{name}"
        bpy.ops.render.render(write_still=True)
        print(f"  RENDERED /tmp/{name}")

    for m in new_cloth_meshes:
        mn, mx, c = bounds(m)
        span = max((mx-mn).x, (mx-mn).y, (mx-mn).z)
        render(f"{m.name}.png", (c.x+span, c.y-span, c.z+span*0.5), c)

    print("\n=== ALL DONE ===")


if __name__ == "__main__":
    main()
