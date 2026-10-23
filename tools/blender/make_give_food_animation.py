"""Build GiveFood.glb — a "hand food to someone" gesture derived from Drinking.glb.

The drinking clip raises the right hand to the mouth. For the cooperative
feed action we want the same reach, but the hand must travel FORWARD toward
the other survivor instead of up to the face. We bake a per-frame correction:
the forearm (and, when needed, the upper arm) is rotated so the hand moves to
an offering pose ~0.45 m in front of the chest, while Spine1 leans forward a
few degrees for body language.

Like RecibirDisparo.glb this file only donates its Animation — meshes are
dropped and PlayerController retargets the clip onto the player skeleton.

Run from the repo root:
  Blender --background --factory-startup --python tools/blender/make_give_food_animation.py
"""
import sys
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "animations" / "Drinking.glb"
TARGET = ROOT / "assets" / "animations" / "GiveFood.glb"

# Source window (frames @30fps): the arm leaves the side, reaches forward and
# comes back — a natural reach we redirect toward the receiver.
SRC_F0, SRC_F1 = 34, 92
OUT_FPS = 30.0

BONES = {
    "hand": "mixamorig5_RightHand",
    "forearm": "mixamorig5_RightForeArm",
    "upperarm": "mixamorig5_RightArm",
    "chest": "mixamorig5_Spine2",
    "lean": "mixamorig5_Spine1",
}

# Offering target relative to the chest (armature space): slightly right of
# centre, forward within real arm reach, at stomach height (offering pose).
OFFER_OFFSET = Vector((-0.07, 0.32, -0.20))
LEAN_RADIANS = 0.10  # ~6 deg forward pitch while the hand is out


def weight(local_f: int, total: int) -> float:
    """0 -> 1 -> 0 envelope: ease in ~14f, hold, ease out last ~14f."""
    ramp = 14.0
    w_in = min(1.0, local_f / ramp)
    w_out = min(1.0, max(0.0, (total - local_f)) / ramp)
    w = min(w_in, w_out)
    return w * w * (3.0 - 2.0 * w)  # smoothstep


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not SOURCE.exists():
        print(f"Missing source: {SOURCE}")
        return 2
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        print(f"Expected 1 armature, found {len(arms)}")
        return 3
    arm = arms[0]
    if arm.animation_data is None or arm.animation_data.action is None:
        print("Armature has no action")
        return 4
    for key, bone_name in BONES.items():
        if bone_name not in arm.pose.bones:
            print(f"Missing bone {bone_name} ({key})")
            return 5

    scn = bpy.context.scene
    deps = bpy.context.evaluated_depsgraph_get()

    # 1) Sample the source pose (armature-space matrices) for every frame.
    samples = {}
    for f in range(SRC_F0, SRC_F1 + 1):
        scn.frame_set(f)
        samples[f] = {pb.name: pb.matrix.copy() for pb in arm.pose.bones}

    arm_mat = arm.matrix_world.copy()
    arm_inv = arm_mat.inverted()

    # 2) Bake the corrected pose into a fresh action.
    new_act = bpy.data.actions.new("GiveFood")
    arm.animation_data.action = new_act
    src_frames = list(range(SRC_F0, SRC_F1 + 1))
    total = len(src_frames) - 1
    pb_fore = arm.pose.bones[BONES["forearm"]]
    pb_up = arm.pose.bones[BONES["upperarm"]]
    pb_hand = arm.pose.bones[BONES["hand"]]
    pb_chest = arm.pose.bones[BONES["chest"]]
    pb_lean = arm.pose.bones[BONES["lean"]]

    # Calibrate: find which local axis on the forearm pushes the hand forward
    # (+Y armature space) — the "extend the elbow to offer" rotation.
    def hand_world() -> Vector:
        return arm_mat @ pb_hand.matrix.translation

    def try_offset(pb_joint, axis: Vector, angle: float, base: dict) -> Vector:
        for pb in arm.pose.bones:
            pb.matrix = base[pb.name]
        bpy.context.view_layer.update()
        rot4 = Quaternion(axis, angle).to_matrix().to_4x4()
        pb_joint.matrix = pb_joint.matrix @ rot4
        bpy.context.view_layer.update()
        return hand_world()

    cal_frame = SRC_F0 + int((SRC_F1 - SRC_F0) * 0.55)
    cal_base = samples[cal_frame]
    for pb in arm.pose.bones:
        pb.matrix = cal_base[pb.name]
    bpy.context.view_layer.update()
    rest_hand = hand_world()
    best_fore = (None, 0.0)
    for axis_name, axis in (("X", Vector((1, 0, 0))), ("Y", Vector((0, 1, 0))), ("Z", Vector((0, 0, 1)))):
        for ang in (0.5, -0.5):
            hw = try_offset(pb_fore, axis, ang, cal_base)
            dy = hw.y - rest_hand.y
            if dy > best_fore[1]:
                best_fore = ((axis_name, axis, ang), dy)
    fore_axis = best_fore[0][1] * best_fore[0][2]  # axis * angle
    # Same for the upper arm — a bit of extra reach, smaller angle.
    best_up = (None, 0.0)
    for axis_name, axis in (("X", Vector((1, 0, 0))), ("Y", Vector((0, 1, 0))), ("Z", Vector((0, 0, 1)))):
        for ang in (0.35, -0.35):
            hw = try_offset(pb_up, axis, ang, cal_base)
            dy = hw.y - rest_hand.y
            if dy > best_up[1]:
                best_up = ((axis_name, axis, ang), dy)
    up_axis = best_up[0][1] * best_up[0][2]
    print(f"calibration: forearm {best_fore[0][0]}{best_fore[0][2]:+.2f} dy={best_fore[1]:.3f} | upperarm {best_up[0][0]}{best_up[0][2]:+.2f} dy={best_up[1]:.3f}")

    # Extra forward extension for the forearm until the reach feels right.
    FORE_ANGLE = 0.85
    UP_ANGLE = 0.30
    fore_q = Quaternion(fore_axis.normalized(), FORE_ANGLE)
    up_q = Quaternion(up_axis.normalized(), UP_ANGLE)

    for out_f, src_f in enumerate(src_frames):
        local = out_f
        w = weight(local, total)
        # Restore the sampled source pose.
        for pb in arm.pose.bones:
            pb.matrix = samples[src_f][pb.name]
        if w > 0.001:
            # Local-space offsets: straighten the elbow / swing the arm out —
            # preserves the clip's natural posture, no IK drift.
            pb_up.matrix = pb_up.matrix @ Quaternion().slerp(up_q, w).to_matrix().to_4x4()
            pb_fore.matrix = pb_fore.matrix @ Quaternion().slerp(fore_q, w).to_matrix().to_4x4()
            bpy.context.view_layer.update()
            # Slight forward lean on the spine while the offer is out.
            lean_q = Quaternion(Vector((1.0, 0.0, 0.0)), LEAN_RADIANS * w)
            pb_lean.matrix = arm_inv @ (lean_q.to_matrix().to_4x4() @ (arm_mat @ pb_lean.matrix))
            bpy.context.view_layer.update()
        # Keyframe the whole pose.
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=out_f + 1)
            pb.keyframe_insert("rotation_quaternion", frame=out_f + 1)
            pb.keyframe_insert("scale", frame=out_f + 1)

    # Report where the hand ended up at the hold.
    mid = int(total * 0.55)
    scn.frame_set(mid + 1)
    bpy.context.view_layer.update()
    hand_w = arm_mat @ pb_hand.matrix.translation
    chest_w = arm_mat @ pb_chest.matrix.translation
    rel = hand_w - chest_w
    print(f"hold hand-chest = ({rel.x:.3f}, {rel.y:.3f}, {rel.z:.3f}) target={tuple(OFFER_OFFSET)}")

    scn.frame_start = 1
    scn.frame_end = len(src_frames)
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(TARGET),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_animation_mode="ACTIVE_ACTIONS",
    )
    print(f"Exported {TARGET} ({len(src_frames)} frames)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
