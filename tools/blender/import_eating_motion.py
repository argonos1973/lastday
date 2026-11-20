"""Bake a CMU eating take onto the existing Mixamo animation skeleton.

Blender --background --factory-startup --python tools/blender/import_eating_motion.py
"""
from pathlib import Path
import math
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
FPS = 30
START = 2.45
DURATION = 2.0
MAPPING = {
    "Hips": "hip", "Spine": "abdomen", "Spine2": "chest",
    "Neck": "neck", "Head": "head",
    "LeftShoulder": "lCollar", "LeftArm": "lShldr",
    "LeftForeArm": "lForeArm", "LeftHand": "lHand",
    "RightShoulder": "rCollar", "RightArm": "rShldr",
    "RightForeArm": "rForeArm", "RightHand": "rHand",
    "LeftUpLeg": "lThigh", "LeftLeg": "lShin", "LeftFoot": "lFoot",
    "RightUpLeg": "rThigh", "RightLeg": "rShin", "RightFoot": "rFoot",
}
for side, prefix in [("Left", "l"), ("Right", "r")]:
    for finger, donor in [("Thumb", "Thumb"), ("Index", "Index"), ("Middle", "Mid"),
                          ("Ring", "Ring"), ("Pinky", "Pinky")]:
        for joint in [1, 2]:
            MAPPING[f"{side}Hand{finger}{joint}"] = f"{prefix}{donor}{joint}"


def short_name(name):
    return name.split("mixamorig")[-1].lstrip(":_0123456789")


def positions(ordered, rest_positions, rest_rotations, rotations):
    result = {}
    for bone in ordered:
        if bone.parent:
            parent = bone.parent.name
            offset = rest_rotations[parent].inverted() @ (rest_positions[bone.name] - rest_positions[parent])
            result[bone.name] = result[parent] + rotations[parent] @ offset
        else:
            result[bone.name] = rest_positions[bone.name]
    return result


def fit_bite(ordered, names, rest_positions, rest_rotations, rotations, goal, weight):
    """Adapt the captured hand/head relationship to this character's limb lengths."""
    pose = positions(ordered, rest_positions, rest_rotations, rotations)
    arm, forearm, hand = (names[name] for name in ["RightArm", "RightForeArm", "RightHand"])
    shoulder, elbow, wrist = (pose[name] for name in [arm, forearm, hand])
    goal = wrist.lerp(goal, weight)
    first, second = (elbow - shoulder).length, (wrist - elbow).length
    direction = (goal - shoulder).normalized()
    distance = min(max((goal - shoulder).length, abs(first - second) + 0.001), first + second - 0.001)
    along = (first * first - second * second + distance * distance) / (2 * distance)
    pole = elbow - shoulder
    pole -= direction * pole.dot(direction)
    if pole.length < 0.001:
        return
    fitted_elbow = shoulder + direction * along + pole.normalized() * math.sqrt(max(0, first * first - along * along))
    upper_swing = (elbow - shoulder).rotation_difference(fitted_elbow - shoulder)
    lower_swing = (upper_swing @ (wrist - elbow)).rotation_difference(goal - fitted_elbow)
    rotations[arm] = upper_swing @ rotations[arm]
    rotations[forearm] = lower_swing @ upper_swing @ rotations[forearm]


def forward(rig, left, right, posed=False):
    bones = rig.pose.bones if posed else rig.data.bones
    a = bones[left].head if posed else bones[left].head_local
    b = bones[right].head if posed else bones[right].head_local
    across = rig.matrix_world.to_3x3() @ (b - a)
    direction = Vector((0, 0, 1)).cross(across)
    direction.z = 0
    return direction.normalized()


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.render.fps = FPS
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/characters/adapted/player_with_clothes.glb"))
    target = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    target.animation_data_clear()
    for bone in target.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    names = {short_name(bone.name): bone.name for bone in target.data.bones}
    bpy.ops.import_anim.bvh(
        filepath=str(ROOT / "assets_src/consumption/cmu_80_24.bvh"),
        global_scale=0.01, use_fps_scale=True, update_scene_fps=False)
    source = bpy.context.object
    target_world = target.matrix_world.to_quaternion()
    source_world = source.matrix_world.to_quaternion()
    target_rest = {bone.name: target_world @ bone.matrix_local.to_quaternion()
                   for bone in target.data.bones}
    target_positions = {bone.name: target.matrix_world @ bone.head_local for bone in target.data.bones}
    source_rest = {bone.name: source_world @ bone.matrix_local.to_quaternion()
                   for bone in source.data.bones}
    source_height = (source.matrix_world.to_3x3() @ (source.data.bones["head"].head_local - source.data.bones["hip"].head_local)).length
    height_ratio = (target_positions[names["Head"]] - target_positions[names["Hips"]]).length / source_height
    rest_forward = forward(source, "lShldr", "rShldr")
    alignment = rest_forward.rotation_difference(
        forward(target, names["LeftArm"], names["RightArm"]))
    first = 1 + START * FPS
    bpy.context.scene.frame_set(int(first), subframe=first % 1)
    heading = rest_forward.rotation_difference(forward(source, "lShldr", "rShldr", True))
    heading_cancel = (alignment @ heading @ alignment.inverted()).inverted()
    action = bpy.data.actions.new("eat_fruit")
    target.animation_data_create()
    target.animation_data.action = action
    ordered = sorted(target.data.bones, key=lambda bone: len(bone.parent_recursive))
    for sample in range(round(DURATION * FPS) + 1):
        frame = first + sample
        bpy.context.scene.frame_set(int(frame), subframe=frame % 1)
        desired = {}
        for bone in ordered:
            short = short_name(bone.name)
            donor = MAPPING.get(short)
            if donor:
                delta = (source_world @ source.pose.bones[donor].matrix.to_quaternion()) @ source_rest[donor].inverted()
                rotation = heading_cancel @ alignment @ delta @ alignment.inverted() @ target_rest[bone.name]
            elif bone.parent:
                rotation = desired[bone.parent.name] @ target_rest[bone.parent.name].inverted() @ target_rest[bone.name]
            else:
                rotation = target_rest[bone.name]
            desired[bone.name] = rotation.normalized()
        pose_positions = positions(ordered, target_positions, target_rest, desired)
        relative_hand = source.matrix_world.to_3x3() @ (source.pose.bones["rHand"].head - source.pose.bones["head"].head)
        contact = min(1.0, max(0.0, (0.36 - relative_hand.length) / 0.18))
        contact = contact * contact * (3.0 - 2.0 * contact)
        goal = pose_positions[names["Head"]] + heading_cancel @ alignment @ relative_hand * height_ratio
        fit_bite(ordered, names, target_positions, target_rest, desired, goal, contact)
        for bone in ordered:
            parent = desired[bone.parent.name] if bone.parent else target_world
            local_rest = (bone.parent.matrix_local.inverted() @ bone.matrix_local
                          if bone.parent else bone.matrix_local).to_quaternion()
            pose = target.pose.bones[bone.name]
            pose.rotation_mode = "QUATERNION"
            pose.rotation_quaternion = (local_rest.inverted() @ parent.inverted() @ desired[bone.name]).normalized()
            pose.keyframe_insert("rotation_quaternion", frame=sample + 1, group=bone.name)
    for curve in action.fcurves:
        for key in curve.keyframe_points:
            key.interpolation = "LINEAR"
    bpy.data.objects.remove(source, do_unlink=True)
    for other in list(bpy.data.actions):
        if other != action:
            bpy.data.actions.remove(other)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = round(DURATION * FPS) + 1
    scene.frame_set(1)
    target.name = "Armature"
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    modes = {item.identifier for item in bpy.ops.export_scene.gltf.get_rna_type().properties["export_animation_mode"].enum_items}
    assert "ACTIONS" in modes
    bpy.ops.export_scene.gltf(
        filepath=str(ROOT / "assets/animations/eat_fruit.glb"),
        export_format="GLB", use_selection=True, export_animations=True,
        export_animation_mode="ACTIONS", export_frame_range=True,
        export_materials="NONE")
    print("EATING_EXPORTED", len(target.data.bones), "bones", DURATION, "seconds")


if __name__ == "__main__":
    main()
