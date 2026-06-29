"""
blender_add_soldier_clothes.py
==============================
Extracts clothing from a Mixamo character GLB (Soldier) and integrates it
into the player_with_clothes.glb as new skinned cloth meshes, plus exports
static pickup GLBs for each piece.

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python clothing_pipeline/blender_add_soldier_clothes.py -- \
    --player assets/characters/adapted/player_with_clothes.glb \
    --soldier "Crouch Turn Right 90.glb" \
    --out-dir assets/characters/adapted
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
    soldier = "Crouch Turn Right 90.glb"
    out_dir = "assets/characters/adapted"
    i = 0
    while i < len(argv):
        if argv[i] == "--player":
            player = argv[i + 1]; i += 2
        elif argv[i] == "--soldier":
            soldier = argv[i + 1]; i += 2
        elif argv[i] == "--out-dir":
            out_dir = argv[i + 1]; i += 2
        else:
            i += 1
    return os.path.abspath(player), os.path.abspath(soldier), os.path.abspath(out_dir)


# Bone name sets for splitting
TORSO_BONES = {
    "mixamorig:Spine", "mixamorig:Spine1", "mixamorig:Spine2",
    "mixamorig:Neck", "mixamorig:Neck1", "mixamorig:Head",
    "mixamorig:HeadTop_End", "mixamorig:LeftEye", "mixamorig:RightEye",
    "mixamorig:Jaw",
    "mixamorig:LeftShoulder", "mixamorig:LeftArm",
    "mixamorig:LeftForeArm", "mixamorig:LeftHand",
    "mixamorig:LeftHandThumb1", "mixamorig:LeftHandThumb2",
    "mixamorig:LeftHandThumb3", "mixamorig:LeftHandThumb4",
    "mixamorig:LeftHandIndex1", "mixamorig:LeftHandIndex2",
    "mixamorig:LeftHandIndex3", "mixamorig:LeftHandIndex4",
    "mixamorig:LeftHandMiddle1", "mixamorig:LeftHandMiddle2",
    "mixamorig:LeftHandMiddle3", "mixamorig:LeftHandMiddle4",
    "mixamorig:LeftHandRing1", "mixamorig:LeftHandRing2",
    "mixamorig:LeftHandRing3", "mixamorig:LeftHandRing4",
    "mixamorig:LeftHandPinky1", "mixamorig:LeftHandPinky2",
    "mixamorig:LeftHandPinky3", "mixamorig:LeftHandPinky4",
    "mixamorig:RightShoulder", "mixamorig:RightArm",
    "mixamorig:RightForeArm", "mixamorig:RightHand",
    "mixamorig:RightHandThumb1", "mixamorig:RightHandThumb2",
    "mixamorig:RightHandThumb3", "mixamorig:RightHandThumb4",
    "mixamorig:RightHandIndex1", "mixamorig:RightHandIndex2",
    "mixamorig:RightHandIndex3", "mixamorig:RightHandIndex4",
    "mixamorig:RightHandMiddle1", "mixamorig:RightHandMiddle2",
    "mixamorig:RightHandMiddle3", "mixamorig:RightHandMiddle4",
    "mixamorig:RightHandRing1", "mixamorig:RightHandRing2",
    "mixamorig:RightHandRing3", "mixamorig:RightHandRing4",
    "mixamorig:RightHandPinky1", "mixamorig:RightHandPinky2",
    "mixamorig:RightHandPinky3", "mixamorig:RightHandPinky4",
}

LEG_BONES = {
    "mixamorig:Hips",
    "mixamorig:LeftUpLeg", "mixamorig:LeftLeg",
    "mixamorig:LeftFoot", "mixamorig:LeftToeBase", "mixamorig:LeftToe_End",
    "mixamorig:RightUpLeg", "mixamorig:RightLeg",
    "mixamorig:RightFoot", "mixamorig:RightToeBase", "mixamorig:RightToe_End",
}


def vertex_dominant_bone(obj, vindex):
    """Return the bone name with the highest weight for a vertex."""
    best_bone = None
    best_weight = 0.0
    for vg in obj.vertex_groups:
        if vindex not in range(len(obj.data.vertices)):
            continue
        try:
            w = vg.weight(vindex)
        except (RuntimeError, ReferenceError, ValueError):
            continue
        if w > best_weight:
            best_weight = w
            best_bone = vg.name
    return best_bone


def separate_by_bone_set(obj, bone_set, new_name):
    """In edit mode, select vertices whose dominant bone is in bone_set,
    then separate them into a new object."""
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')

    # Use bmesh in edit mode to select vertices
    bm = bmesh.from_edit_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    selected_count = 0
    for v in bm.verts:
        bone = vertex_dominant_bone(obj, v.index)
        if bone and bone in bone_set:
            v.select = True
            selected_count += 1
    bmesh.update_edit_mesh(obj.data)
    print(f"    selected {selected_count} verts for {new_name}")

    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')

    # Find the newly separated object (it will have a .001 suffix)
    new_obj = None
    for o in bpy.data.objects:
        if o.type == 'MESH' and o != obj:
            # Check if this object's vertices all have dominant bones in bone_set
            if len(o.data.vertices) > 0:
                bone = vertex_dominant_bone(o, 0)
                if bone and bone in bone_set:
                    new_obj = o
                    break
    if new_obj is None:
        # Fallback: take the most recently created mesh that isn't the original
        meshes = [o for o in bpy.data.objects if o.type == 'MESH' and o != obj]
        if meshes:
            new_obj = meshes[-1]

    if new_obj:
        new_obj.name = new_name
        print(f"  separated {new_name}: {len(new_obj.data.vertices)} verts")
    return new_obj


def export_static_pickup(obj, arm, path, scale=0.01, lay_flat=True):
    """Export a static (un-skinned) version of a mesh as a pickup GLB."""
    bpy.ops.object.select_all(action='DESELECT')
    copy = obj.copy()
    copy.data = obj.data.copy()
    bpy.context.collection.objects.link(copy)
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy

    # Remove all modifiers (armature)
    for m in list(copy.modifiers):
        copy.modifiers.remove(m)
    copy.parent = None

    # Scale from cm to metres
    copy.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Lay flat: rotate 90 on X so it lies on its back
    if lay_flat:
        copy.rotation_euler = (math.radians(90), 0, 0)
        bpy.context.view_layer.update()
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Center on origin
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
    print(f"  pickup exported -> {path}")
    # Clean up the copy
    bpy.data.objects.remove(copy, do_unlink=True)


def main():
    player_glb, soldier_glb, out_dir = parse_args()
    print(f"=== ADD SOLDIER CLOTHES ===")
    print(f"  player: {player_glb}")
    print(f"  soldier: {soldier_glb}")
    print(f"  out_dir: {out_dir}")

    # Step 1: Import player_with_clothes.glb
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=player_glb)
    player_arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()
    print(f"  player armature: {player_arm.name}, bones={len(player_arm.data.bones)}")

    # Step 2: Import soldier GLB
    bpy.ops.import_scene.gltf(filepath=soldier_glb)
    soldier_arm = None
    soldier_body = None
    for o in bpy.data.objects:
        if o.type == 'ARMATURE' and o != player_arm:
            soldier_arm = o
        if o.name == "Soldier_body":
            soldier_body = o
    if soldier_body is None:
        print("  [FATAL] Soldier_body not found")
        sys.exit(1)
    print(f"  soldier armature: {soldier_arm.name if soldier_arm else 'None'}")
    print(f"  soldier body: {soldier_body.name}, verts={len(soldier_body.data.vertices)}")

    # Step 3: Check if both armatures share the same bone structure
    player_bones = set(player_arm.data.bones.keys())
    soldier_bones = set(soldier_arm.data.bones.keys()) if soldier_arm else set()
    common = player_bones & soldier_bones
    print(f"  common bones: {len(common)} / player={len(player_bones)} / soldier={len(soldier_bones)}")

    # Step 4: Parent soldier_body to player_arm (same rig, so weights transfer directly)
    soldier_body.parent = player_arm
    # Add armature modifier pointing to player armature
    am = soldier_body.modifiers.new("Armature", 'ARMATURE')
    am.object = player_arm
    print(f"  re-parented Soldier_body to player armature")

    # Step 5: Separate into torso and legs
    print("\n=== SEPARATING ===")
    torso = separate_by_bone_set(soldier_body, TORSO_BONES, "cloth_soldier_torso")
    legs = separate_by_bone_set(soldier_body, LEG_BONES, "cloth_soldier_legs")

    # The remaining part of soldier_body (if any) is leftover
    # Rename the original to something we can delete
    soldier_body.name = "Soldier_body_remainder"

    # Delete the remainder if it has very few verts
    if torso and legs:
        remainder_verts = len(soldier_body.data.vertices)
        print(f"  remainder: {remainder_verts} verts")
        if remainder_verts < 50:
            bpy.data.objects.remove(soldier_body, do_unlink=True)
            print("  deleted remainder")

    # Delete Icosphere and Soldier_head first (children of soldier armature)
    to_delete = []
    for o in list(bpy.data.objects):
        if o.name in ("Icosphere", "Soldier_head"):
            to_delete.append(o.name)
    for name in to_delete:
        o = bpy.data.objects.get(name)
        if o:
            bpy.data.objects.remove(o, do_unlink=True)
            print(f"  deleted {name}")

    # Delete the soldier armature (we don't need it anymore)
    if soldier_arm and soldier_arm.name in bpy.data.objects:
        sarm_name = soldier_arm.name
        bpy.data.objects.remove(bpy.data.objects[sarm_name], do_unlink=True)
        print(f"  deleted {sarm_name}")

    # Step 6: Verify the new meshes have armature modifiers
    for name, obj in [("torso", torso), ("legs", legs)]:
        if obj:
            has_arm = any(m.type == 'ARMATURE' for m in obj.modifiers)
            if not has_arm:
                am = obj.modifiers.new("Armature", 'ARMATURE')
                am.object = player_arm
            print(f"  {name}: verts={len(obj.data.vertices)}, armature={has_arm}")

    # Step 7: Re-export player_with_clothes.glb with new meshes
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

    # Step 8: Export static pickups
    print("\n=== EXPORT PICKUPS ===")
    if torso:
        export_static_pickup(
            torso, player_arm,
            os.path.join(out_dir, "pickup_soldier_torso.glb"),
            scale=0.01, lay_flat=True
        )
    if legs:
        export_static_pickup(
            legs, player_arm,
            os.path.join(out_dir, "pickup_soldier_legs.glb"),
            scale=0.01, lay_flat=True
        )

    # Step 9: Render to verify
    print("\n=== RENDER ===")
    scene = bpy.context.scene
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except Exception:
        scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 600
    scene.render.resolution_y = 600
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.6, 1)
    scene.world = w
    ld = bpy.data.lights.new("Sun", 'SUN')
    ld.energy = 3
    lo = bpy.data.objects.new("Sun", ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(50), 0, math.radians(30))
    cd = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cd)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam

    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in {"Body", "cloth_soldier_torso", "cloth_soldier_legs"}

    # Color the new meshes
    for o in bpy.data.objects:
        if o.name == "cloth_soldier_torso":
            m = bpy.data.materials.new("ST")
            m.diffuse_color = (0.15, 0.18, 0.12, 1)
            o.data.materials.clear()
            o.data.materials.append(m)
        elif o.name == "cloth_soldier_legs":
            m = bpy.data.materials.new("SL")
            m.diffuse_color = (0.12, 0.14, 0.10, 1)
            o.data.materials.clear()
            o.data.materials.append(m)

    def bounds(obj):
        mn = mathutils.Vector((1e9, 1e9, 1e9))
        mx = mathutils.Vector((-1e9, -1e9, -1e9))
        for v in obj.bound_box:
            w = obj.matrix_world @ mathutils.Vector(v)
            for i in range(3):
                mn[i] = min(mn[i], w[i])
                mx[i] = max(mx[i], w[i])
        return mn, mx, (mn + mx) / 2

    def render(name, eye, look):
        cam.location = eye
        d = (mathutils.Vector(look) - mathutils.Vector(eye))
        cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
        scene.render.filepath = f"/tmp/{name}"
        bpy.ops.render.render(write_still=True)
        print(f"  RENDERED /tmp/{name}")

    if torso:
        mn, mx, c = bounds(torso)
        span = max((mx - mn).x, (mx - mn).y, (mx - mn).z)
        render("soldier_torso.png", (c.x + span, c.y - span, c.z + span * 0.5), c)
    if legs:
        mn, mx, c = bounds(legs)
        span = max((mx - mn).x, (mx - mn).y, (mx - mn).z)
        render("soldier_legs.png", (c.x + span, c.y - span, c.z + span * 0.5), c)

    print("\n=== ALL DONE ===")


if __name__ == "__main__":
    main()
