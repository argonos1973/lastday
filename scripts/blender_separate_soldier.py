import bpy
import bmesh
import os
import sys

INPUT = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/soldado.glb"
OUTPUT = "/home/sami/Documentos/lastday2/quiero-crear-un-prototipo-de-juego/quiero-crear-un-prototipo-de-juego/assets/adapted/soldado_parts.glb"

# Y thresholds in local mesh space (before armature scale 0.01)
# The mesh is in cm, so ~170cm tall body
# Torso: y > 100 (above waist)
# Legs: 30 < y <= 100 (below waist, above ankles)
# Feet: y <= 30 (ankles and below)
# Hands: separate by X distance from center + Y in arm range

# Actually, let's use bone weights to separate - assign vertices to bone groups
# Mixamo bone names: Spine, Spine1, Spine2, Hips, LeftUpLeg, RightUpLeg, 
# LeftLeg, RightLeg, LeftFoot, RightFoot, LeftHand, RightHand, etc.

# Map bone groups to body parts
P = "mixamorig:"
TORSO_BONES = [P+"Spine", P+"Spine1", P+"Spine2", P+"LeftArm", P+"RightArm", P+"LeftForeArm", P+"RightForeArm", P+"Neck", P+"Neck1", P+"Head", P+"LeftShoulder", P+"RightShoulder"]
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
    print("Imported objects:", [o.name for o in bpy.context.scene.objects])

def find_armature():
    for obj in bpy.context.scene.objects:
        if obj.type == 'ARMATURE':
            return obj
    return None

def find_body_mesh():
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and 'Soldier_body' in obj.name:
            return obj
    # Fallback: first mesh
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH':
            return obj
    return None

def get_vertex_bone_groups(obj):
    """Returns a dict: vertex_index -> set of bone names with weight > 0"""
    vg_names = {i: vg.name for i, vg in enumerate(obj.vertex_groups)}
    result = {}
    for v in obj.data.vertices:
        bones = set()
        for g in v.groups:
            if g.weight > 0.01:
                vg_name = vg_names.get(g.group, "")
                bones.add(vg_name)
        result[v.index] = bones
    return result

def separate_by_bone_groups(obj, armature, part_name, bone_names):
    """Create a new mesh object with only vertices whose primary bone group is in bone_names"""
    mesh = obj.data
    vg_names = {i: vg.name for i, vg in enumerate(obj.vertex_groups)}
    
    # Determine which vertices belong to this part
    vertex_mask = [False] * len(mesh.vertices)
    for v in mesh.vertices:
        max_weight = 0.0
        max_bone = ""
        for g in v.groups:
            if g.weight > max_weight:
                max_weight = g.weight
                vg_name = vg_names.get(g.group, "")
                max_bone = vg_name
        if max_bone in bone_names:
            vertex_mask[v.index] = True
    
    count = sum(1 for x in vertex_mask if x)
    print(f"  {part_name}: {count} vertices")
    
    if count == 0:
        return None
    
    # Duplicate the object
    obj_copy = obj.copy()
    obj_copy.data = obj.data.copy()
    obj_copy.name = part_name
    
    # Link to scene
    bpy.context.collection.objects.link(obj_copy)
    
    # Select only the copy and enter edit mode
    bpy.ops.object.select_all(action='DESELECT')
    obj_copy.select_set(True)
    bpy.context.view_layer.objects.active = obj_copy
    
    bpy.ops.object.mode_set(mode='EDIT')
    bm = bmesh.from_edit_mesh(obj_copy.data)
    
    # Select vertices NOT in mask and delete them
    for v in bm.verts:
        if not vertex_mask[v.index]:
            v.select = True
        else:
            v.select = False
    bmesh.update_edit_mesh(obj_copy.data)
    bpy.ops.mesh.delete(type='VERT')
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Parent to armature with armature deform
    obj_copy.parent = armature
    mod = obj_copy.modifiers.new(name="Armature", type='ARMATURE')
    mod.object = armature
    
    return obj_copy

def main():
    clear_scene()
    load_glb(INPUT)
    
    armature = find_armature()
    if armature is None:
        print("ERROR: No armature found")
        sys.exit(1)
    print(f"Armature: {armature.name}")
    
    # Normalize scale: the Armature and Geo have scale 0.01 (cm to m)
    # Apply scale so vertices are in meters and all scales are 1.0
    for obj in bpy.context.scene.objects:
        if obj.name in ["Geo", "Armature"] or obj.type == 'EMPTY':
            obj.scale = (1.0, 1.0, 1.0)
    
    body = find_body_mesh()
    if body is None:
        print("ERROR: No body mesh found")
        sys.exit(1)
    print(f"Body mesh: {body.name}, vertices: {len(body.data.vertices)}")
    
    # The mesh vertices are in cm (because original armature scale was 0.01)
    # We need to scale them by 0.01 to convert to meters
    # Apply transform to mesh data
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    body.scale = (0.01, 0.01, 0.01)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    
    # Print all vertex group names for debugging
    print("Vertex groups:", [vg.name for vg in body.vertex_groups])
    
    # Separate into 4 parts
    parts = {
        "soldier_torso": TORSO_BONES,
        "soldier_legs": LEGS_BONES,
        "soldier_feet": FEET_BONES,
        "soldier_hands": HANDS_BONES,
    }
    
    created = []
    for part_name, bones in parts.items():
        print(f"Separating {part_name} with bones: {bones}")
        result = separate_by_bone_groups(body, armature, part_name, bones)
        if result is not None:
            created.append(result)
    
    # Delete original body mesh
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.ops.object.delete()
    
    # Also delete Soldier_head if it exists (we don't need it)
    for obj in bpy.context.scene.objects:
        if obj.type == 'MESH' and 'head' in obj.name.lower():
            bpy.ops.object.select_all(action='DESELECT')
            obj.select_set(True)
            bpy.ops.object.delete()
    
    print(f"Created {len(created)} parts: {[o.name for o in created]}")
    
    # Select all for export
    bpy.ops.object.select_all(action='SELECT')
    
    # Export
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
