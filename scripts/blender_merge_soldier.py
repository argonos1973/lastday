import bpy
import bmesh
import os
import sys

PLAYER_MODEL = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/leftturn.glb"
DESNUDO_MODEL = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/desnudo.glb"
SOLDADO_MODEL = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/soldado.glb"
CLOTH_MODEL = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/assets/adapted/player_with_clothes.glb.bak3"
OUTPUT = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/assets/adapted/player_with_clothes.glb"

P = "mixamorig:"
TORSO_BONES = [P+"Spine", P+"Spine1", P+"Spine2", P+"LeftArm", P+"RightArm", P+"LeftForeArm", P+"RightForeArm", P+"Neck", P+"Neck1", P+"Head", P+"LeftShoulder", P+"RightShoulder"]
# For separating the player's Body mesh: torso+arms+hips but NOT neck/head/legs
BODY_TORSO_BONES = [P+"Hips", P+"Spine", P+"Spine1", P+"Spine2", P+"LeftArm", P+"RightArm", P+"LeftForeArm", P+"RightForeArm", P+"LeftShoulder", P+"RightShoulder"]
LEGS_BONES = [P+"Hips", P+"LeftUpLeg", P+"RightUpLeg", P+"LeftLeg", P+"RightLeg", P+"LeftToeBase", P+"RightToeBase", P+"LeftToe_End", P+"RightToe_End"]
FEET_BONES = [P+"LeftFoot", P+"RightFoot"]
HANDS_BONES = [P+"LeftHand", P+"RightHand", P+"LeftHandThumb1", P+"LeftHandThumb2", P+"LeftHandThumb3", P+"RightHandThumb1", P+"RightHandThumb2", P+"RightHandThumb3", P+"LeftHandIndex1", P+"LeftHandIndex2", P+"LeftHandIndex3", P+"RightHandIndex1", P+"RightHandIndex2", P+"RightHandIndex3", P+"LeftHandMiddle1", P+"LeftHandMiddle2", P+"LeftHandMiddle3", P+"RightHandMiddle1", P+"RightHandMiddle2", P+"RightHandMiddle3", P+"LeftHandRing1", P+"LeftHandRing2", P+"LeftHandRing3", P+"RightHandRing1", P+"RightHandRing2", P+"RightHandRing3", P+"LeftHandPinky1", P+"LeftHandPinky2", P+"LeftHandPinky3", P+"RightHandPinky1", P+"RightHandPinky2", P+"RightHandPinky3"]

def clear_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for mesh in bpy.data.meshes:
        bpy.data.meshes.remove(mesh)
    for arm in bpy.data.armatures:
        bpy.data.armatures.remove(arm)

def load_glb(path):
    bpy.ops.import_scene.gltf(filepath=path)

def find_armature():
    for obj in bpy.context.scene.objects:
        if obj.type == 'ARMATURE':
            return obj
    return None

def find_mesh_by_name(name_part):
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and name_part in obj.name:
            return obj
    return None

def separate_by_bone_groups(obj, armature, part_name, bone_names):
    return _separate_by_bone_mask(obj, armature, part_name, bone_names, keep_matching=True)

def separate_complement(obj, armature, part_name, bone_names):
    """Create a copy of obj with vertices whose primary bone is NOT in bone_names."""
    return _separate_by_bone_mask(obj, armature, part_name, bone_names, keep_matching=False)

def separate_by_y_range(obj, part_name, y_min, y_max, complement_high=None, x_limit=None, exclude_bones=None, exclude_bone_y_min=None, invert=False):
    """Split obj into two meshes using bpy.ops.object.separate to preserve skinning.
    Returns the new object (part_name) with matching vertices."""
    vg_names = {i: vg.name for i, vg in enumerate(obj.vertex_groups)}
    vertex_mask = [False] * len(obj.data.vertices)
    for v in obj.data.vertices:
        y = v.co.y
        x_ok = True
        if x_limit is not None and abs(v.co.x) >= x_limit:
            x_ok = False
        bone_ok = True
        if exclude_bones is not None:
            max_w = 0.0
            max_b = ""
            for g in v.groups:
                if g.weight > max_w:
                    max_w = g.weight
                    max_b = vg_names.get(g.group, "")
            if max_b in exclude_bones:
                if exclude_bone_y_min is None or y >= exclude_bone_y_min:
                    bone_ok = False
        matches = (y_min <= y < y_max) and x_ok and bone_ok
        if complement_high is not None and y >= complement_high:
            matches = True
        vertex_mask[v.index] = (not matches) if invert else matches
    
    count = sum(1 for x in vertex_mask if x)
    print(f"  {part_name}: {count} vertices")
    
    if count == 0:
        return None
    
    # Use edit mode selection + separate to preserve all skin data
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    
    bpy.ops.object.mode_set(mode='EDIT')
    # Deselect all first
    bpy.ops.mesh.select_all(action='DESELECT')
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Set selection on vertices directly
    for v in obj.data.vertices:
        v.select = vertex_mask[v.index]
    
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Find the newly created object (the separated part)
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

def separate_by_bone_weights(obj, part_name, bone_names):
    """Split obj: vertices whose dominant bone is in bone_names go to a new object.
    Uses bpy.ops.mesh.separate to preserve skinning."""
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

def _separate_by_bone_mask(obj, armature, part_name, bone_names, keep_matching):
    vg_names = {i: vg.name for i, vg in enumerate(obj.vertex_groups)}
    
    vertex_mask = [False] * len(obj.data.vertices)
    for v in obj.data.vertices:
        max_weight = 0.0
        max_bone = ""
        for g in v.groups:
            if g.weight > max_weight:
                max_weight = g.weight
                vg_name = vg_names.get(g.group, "")
                max_bone = vg_name
        is_match = max_bone in bone_names
        # keep_matching=True: keep vertices that match (delete non-matching)
        # keep_matching=False: keep vertices that don't match (delete matching)
        vertex_mask[v.index] = is_match if keep_matching else (not is_match)
    
    count = sum(1 for x in vertex_mask if x)
    print(f"  {part_name}: {count} vertices")
    
    if count == 0:
        return None
    
    obj_copy = obj.copy()
    obj_copy.data = obj.data.copy()
    obj_copy.name = part_name
    
    bpy.context.collection.objects.link(obj_copy)
    
    bpy.ops.object.select_all(action='DESELECT')
    obj_copy.select_set(True)
    bpy.context.view_layer.objects.active = obj_copy
    
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj_copy.data)
    
    for v in bm.verts:
        if not vertex_mask[v.index]:
            v.select = True
        else:
            v.select = False
    bmesh.update_edit_mesh(obj_copy.data)
    bpy.ops.mesh.delete(type='VERT')
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Parent to player armature
    obj_copy.parent = armature
    mod = obj_copy.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = armature
    
    return obj_copy

def main():
    clear_scene()
    
    # 1. Import leftturn.glb as base (armature + clothing + hair)
    load_glb(PLAYER_MODEL)
    player_arm = find_armature()
    if player_arm is None:
        print("ERROR: No player armature found")
        sys.exit(1)
    print(f"Player armature: {player_arm.name}")
    
    # 1b. Import desnudo.glb body mesh, scale and skin to leftturn armature
    pre_desnudo = set(o.name for o in bpy.context.scene.objects)
    load_glb(DESNUDO_MODEL)
    desnudo_body = None
    for obj in list(bpy.context.scene.objects):
        if obj.name in pre_desnudo:
            continue
        if obj.type == 'MESH' and obj.name == "Ch36":
            desnudo_body = obj
    
    if desnudo_body is not None:
        DESNUDO_SCALE = 2.0967
        desnudo_body.scale = (DESNUDO_SCALE, DESNUDO_SCALE, DESNUDO_SCALE)
        bpy.ops.object.select_all(action='DESELECT')
        desnudo_body.select_set(True)
        bpy.context.view_layer.objects.active = desnudo_body
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        
        P1 = "mixamorig1:"
        for vg in desnudo_body.vertex_groups:
            if vg.name.startswith(P1):
                vg.name = P + vg.name[len(P1):]
        
        desnudo_body.parent = player_arm
        arm_mod = None
        for m in desnudo_body.modifiers:
            if m.type == 'ARMATURE':
                arm_mod = m
                break
        if arm_mod is None:
            arm_mod = desnudo_body.modifiers.new(name="Armature", type='ARMATURE')
        arm_mod.object = player_arm
        
        for obj in list(bpy.context.scene.objects):
            if obj.type == 'MESH' and obj.name == 'Body' and obj != desnudo_body:
                bpy.ops.object.select_all(action='DESELECT')
                obj.select_set(True)
                bpy.ops.object.delete()
                break
        
        desnudo_body.name = "Body"
        desnudo_body.data.name = "Body"
        print(f"Body mesh (desnudo): {len(desnudo_body.data.vertices)} verts")
    else:
        print("WARNING: Ch36 mesh not found in desnudo.glb")
    
    # Delete desnudo armature and extra objects
    for obj in list(bpy.context.scene.objects):
        if obj.name in pre_desnudo:
            continue
        if obj == desnudo_body:
            continue
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.delete()
    
    # 2. Import soldado model
    load_glb(SOLDADO_MODEL)
    soldado_arm = None
    for obj in bpy.context.scene.objects:
        if obj.type == 'ARMATURE' and obj != player_arm:
            soldado_arm = obj
            break
    if soldado_arm is None:
        print("ERROR: No soldado armature found")
        sys.exit(1)
    print(f"Soldado armature: {soldado_arm.name}")
    
    # 2b. Import cloth_* meshes from backup GLB (survival clothing)
    # Track existing objects before import so we can delete duplicates
    pre_import_objs = set(o.name for o in bpy.context.scene.objects)
    load_glb(CLOTH_MODEL)
    cloth_meshes = []
    objs_to_delete = []
    for obj in list(bpy.context.scene.objects):
        if obj.name in pre_import_objs:
            continue  # Already existed before import
        if obj.type == 'MESH' and obj.name.startswith('cloth_'):
            # Parent to player armature and ensure ARMATURE modifier points to it
            obj.parent = player_arm
            arm_mod = None
            for m in obj.modifiers:
                if m.type == 'ARMATURE':
                    arm_mod = m
                    break
            if arm_mod is None:
                arm_mod = obj.modifiers.new(name="Armature", type='ARMATURE')
            arm_mod.object = player_arm
            cloth_meshes.append(obj.name)
            print(f"  Imported cloth mesh: {obj.name} ({len(obj.data.vertices)} verts)")
        else:
            objs_to_delete.append(obj)
    # Delete all non-cloth objects from the cloth GLB import
    for obj in objs_to_delete:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.delete()
    
    # 3. Find soldado body mesh
    soldado_body = None
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and 'Soldier_body' in obj.name:
            soldado_body = obj
            break
    if soldado_body is None:
        print("ERROR: No Soldier_body mesh found")
        sys.exit(1)
    print(f"Soldado body: {soldado_body.name}, vertices: {len(soldado_body.data.vertices)}")
    
    # 4. The soldado mesh is authored at ~half the scale of the player skeleton.
    # Scale it 2x around world origin (feet at Y=0) and APPLY the scale so the
    # vertices are baked at the correct size BEFORE binding to the player
    # armature. This makes the inverse bind matrices correct and the mesh
    # deforms properly at the right scale, with NO runtime scaling needed.
    soldado_body.parent = None

    # Remove any existing armature modifiers first (so scale apply is clean)
    for mod in list(soldado_body.modifiers):
        if mod.type == 'ARMATURE':
            soldado_body.modifiers.remove(mod)

    # Ensure object origin is at world origin so scaling pivots around the feet
    bpy.ops.object.select_all(action='DESELECT')
    soldado_body.select_set(True)
    bpy.context.view_layer.objects.active = soldado_body
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')

    # Apply 2.1x scale around the world-origin object pivot
    soldado_body.scale = (2.1, 2.1, 2.1)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    print(f"Scaled soldado_body 2x and applied. New vert0={soldado_body.data.vertices[0].co}")

    # Now bind to the player armature at the corrected scale
    soldado_body.parent = player_arm
    mod = soldado_body.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = player_arm
    
    # 6. Now the soldado_body is skinned to the player's armature
    # The vertex groups use mixamorig: names which match the player's bones
    # Blender will use the player armature's rest pose for binding
    
    # 7. Separate soldado into 4 parts
    parts = {
        "soldier_torso": TORSO_BONES,
        "soldier_legs": LEGS_BONES,
        "soldier_feet": FEET_BONES,
        "soldier_hands": HANDS_BONES,
    }
    
    created = []
    created_names = []
    for part_name, bones in parts.items():
        print(f"Separating {part_name}")
        result = separate_by_bone_groups(soldado_body, player_arm, part_name, bones)
        if result is not None:
            created.append(result)
            created_names.append(result.name)
    
    # 7b. Separate player Body into parts by bone weights.
    #     Uses bpy.ops.mesh.separate which preserves all skinning data.
    player_body = None
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and obj.name == 'Body':
            player_body = obj
            break
    if player_body is not None:
        print(f"Separating Body parts from Body ({len(player_body.data.vertices)} verts)")
        hand_bones = [P+"LeftHand", P+"RightHand",
                      P+"LeftHandThumb1", P+"LeftHandThumb2", P+"LeftHandThumb3",
                      P+"RightHandThumb1", P+"RightHandThumb2", P+"RightHandThumb3",
                      P+"LeftHandIndex1", P+"LeftHandIndex2", P+"LeftHandIndex3",
                      P+"RightHandIndex1", P+"RightHandIndex2", P+"RightHandIndex3",
                      P+"LeftHandMiddle1", P+"LeftHandMiddle2", P+"LeftHandMiddle3",
                      P+"RightHandMiddle1", P+"RightHandMiddle2", P+"RightHandMiddle3",
                      P+"LeftHandRing1", P+"LeftHandRing2", P+"LeftHandRing3",
                      P+"RightHandRing1", P+"RightHandRing2", P+"RightHandRing3",
                      P+"LeftHandPinky1", P+"LeftHandPinky2", P+"LeftHandPinky3",
                      P+"RightHandPinky1", P+"RightHandPinky2", P+"RightHandPinky3"]
        
        # Body_torso: torso only (no arms, no hands)
        torso_bones = [P+"Hips", P+"Spine", P+"Spine1", P+"Spine2",
                       P+"LeftShoulder", P+"RightShoulder"]
        body_torso = separate_by_bone_weights(player_body, "Body_torso", torso_bones)
        if body_torso is not None:
            created.append(body_torso)
            created_names.append(body_torso.name)
        
        # Body_arms: arms (excluding hands)
        arm_bones = [P+"LeftArm", P+"RightArm", P+"LeftForeArm", P+"RightForeArm"]
        body_arms = separate_by_bone_weights(player_body, "Body_arms", arm_bones)
        if body_arms is not None:
            created.append(body_arms)
            created_names.append(body_arms.name)
        
        # Body_legs: legs (excluding feet)
        leg_bones = [P+"LeftUpLeg", P+"RightUpLeg", P+"LeftLeg", P+"RightLeg"]
        body_legs = separate_by_bone_weights(player_body, "Body_legs", leg_bones)
        if body_legs is not None:
            created.append(body_legs)
            created_names.append(body_legs.name)
        
        # Body_hands: hands
        body_hands = separate_by_bone_weights(player_body, "Body_hands", hand_bones)
        if body_hands is not None:
            created.append(body_hands)
            created_names.append(body_hands.name)
        
        # Body_feet: feet + toes
        foot_bones = [P+"LeftFoot", P+"RightFoot",
                      P+"LeftToeBase", P+"RightToeBase",
                      P+"LeftToe_End", P+"RightToe_End"]
        body_feet = separate_by_bone_weights(player_body, "Body_feet", foot_bones)
        if body_feet is not None:
            created.append(body_feet)
            created_names.append(body_feet.name)
    else:
        print("WARNING: Player Body mesh not found")
    
    # 8. Delete original soldado body and head, and soldado armature.
    #    (leftturn.glb doesn't have old soldier_* meshes, so no need to delete those)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and ('Soldier_body' in obj.name or 'head' in obj.name.lower()):
            obj.select_set(True)
        if obj.type == 'ARMATURE' and obj == soldado_arm:
            obj.select_set(True)
    bpy.ops.object.delete()
    
    print(f"Created {len(created_names)} parts: {created_names}")
    
    # 9. Rebuild created list by finding objects by name (originals may have been deleted)
    created = []
    for name in created_names:
        for obj in bpy.context.scene.objects:
            if obj.type == 'MESH' and obj.name == name:
                created.append(obj)
                break
    
    # Rename created parts to remove the .001 suffix Blender adds
    for o in created:
        if o.name.endswith('.001'):
            o.name = o.name[:-4]
    created_names = [o.name for o in created]
    print(f"Renamed parts: {created_names}")
    
    # 10. Export EVERYTHING (all player meshes + new soldier parts) back to
    #     player_with_clothes.glb so soldier parts use the identical import pipeline.
    os.makedirs(os.path.dirname(OUTPUT), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT,
        use_selection=False,
        export_apply=True,
        export_yup=True,
        export_format='GLB',
    )
    print(f"Exported to {OUTPUT}")

main()
