"""Build BowShoot.glb and BowAimIdle.glb — archery draw, aim and release animations.

Derived from Drinking.glb's Mixamo rig so PlayerController can retarget the
tracks directly onto the player skeleton (same pipeline as GiveFood.glb).

Pose design:
- Left arm (bow hand) extends forward (-Y in Blender world, -Z in Godot) at
  shoulder height, holding the bow stave steady.
- Right arm (string hand) reaches forward to the bowstring, draws it back to
  the right cheek/jaw anchor with elbow high, holds at full draw, then snaps
  cleanly on release before returning.
- Spine1/Spine2 counter-twist slightly into the archer stance while the head
  stays turned toward the target.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/make_bow_shoot_animation.py
"""
import math
import sys
from pathlib import Path
import bpy
from mathutils import Quaternion, Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets" / "animations" / "Drinking.glb"
OUT_SHOOT = ROOT / "assets" / "animations" / "BowShoot.glb"
OUT_AIM = ROOT / "assets" / "animations" / "BowAimIdle.glb"


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    if edge1 <= edge0:
        return 1.0 if x >= edge1 else 0.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def aim_bone_TO_target(arm, pb_joint, pb_end, target_world: Vector, blend: float = 1.0):
    """Rotate pb_joint around its head so pb_end.head moves toward target_world."""
    if blend <= 0.0001:
        return
    arm_mat = arm.matrix_world
    arm_inv = arm_mat.inverted()
    joint_w = arm_mat @ pb_joint.head
    cur_end_w = arm_mat @ pb_end.head
    v_cur = cur_end_w - joint_w
    v_tgt = target_world - joint_w
    if v_cur.length < 1e-4 or v_tgt.length < 1e-4:
        return
    q_world = v_cur.normalized().rotation_difference(v_tgt.normalized())
    q_world = Quaternion().slerp(q_world, blend)
    # Apply world-space rotation around joint_w
    mat_w = arm_mat @ pb_joint.matrix
    loc_w = mat_w.translation.copy()
    rot_w = q_world.to_matrix().to_4x4() @ mat_w
    rot_w.translation = joint_w + (q_world @ (loc_w - joint_w))
    pb_joint.matrix = arm_inv @ rot_w
    bpy.context.view_layer.update()


def solve_two_bone_chain(arm, pb_upper, pb_fore, pb_hand, target_world: Vector, pole_world: Vector, blend: float = 1.0):
    """Two-step geometric solver: bend elbow to match target distance, then aim."""
    if blend <= 0.0001:
        return
    arm_mat = arm.matrix_world
    arm_inv = arm_mat.inverted()
    # First swing upper arm toward the pole/target hint so the elbow lifts naturally
    mid_hint = target_world.lerp(pole_world, 0.42)
    aim_bone_TO_target(arm, pb_upper, pb_fore, mid_hint, blend)
    # Then aim forearm so the hand reaches target_world
    aim_bone_TO_target(arm, pb_fore, pb_hand, target_world, blend)
    # Fine pass: bring upper arm + forearm closer to exact target_world
    aim_bone_TO_target(arm, pb_upper, pb_hand, target_world, blend * 0.65)
    aim_bone_TO_target(arm, pb_fore, pb_hand, target_world, blend)


def build_clip(mode: str, out_path: Path) -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    arm = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"][0]
    scn = bpy.context.scene

    # Sample calm standing frames from Drinking.glb (frames 1..40 have both hands low)
    base_samples = []
    for f in range(1, 41):
        scn.frame_set(f)
        bpy.context.view_layer.update()
        base_samples.append({pb.name: pb.matrix.copy() for pb in arm.pose.bones})

    new_act = bpy.data.actions.new("BowShoot" if mode == "shoot" else "BowAimIdle")
    arm.animation_data.action = new_act

    pb_spine1 = arm.pose.bones["mixamorig5_Spine1"]
    pb_spine2 = arm.pose.bones["mixamorig5_Spine2"]
    pb_neck = arm.pose.bones["mixamorig5_Neck"]
    pb_head = arm.pose.bones["mixamorig5_Head"]
    pb_l_up = arm.pose.bones["mixamorig5_LeftArm"]
    pb_l_fore = arm.pose.bones["mixamorig5_LeftForeArm"]
    pb_l_hand = arm.pose.bones["mixamorig5_LeftHand"]
    pb_r_up = arm.pose.bones["mixamorig5_RightArm"]
    pb_r_fore = arm.pose.bones["mixamorig5_RightForeArm"]
    pb_r_hand = arm.pose.bones["mixamorig5_RightHand"]

    arm_mat = arm.matrix_world.copy()
    arm_inv = arm_mat.inverted()

    total_frames = 36 if mode == "shoot" else 40

    for f_idx in range(total_frames):
        sample = base_samples[f_idx % len(base_samples)]
        for pb in arm.pose.bones:
            pb.matrix = sample[pb.name]
        bpy.context.view_layer.update()

        chest_w = arm_mat @ pb_spine2.head
        head_w = arm_mat @ pb_head.head

        if mode == "aim_idle":
            # Full archer draw hold with subtle breathing motion
            breath = math.sin(2.0 * math.pi * f_idx / total_frames)
            w_bow = 1.0
            draw_t = 1.0
            release_recoil = 0.0
        else:
            # Shoot cycle (36 frames @ 30fps = 1.2s):
            #   0..7: raise bow & reach string
            #   7..19: draw string back to cheek anchor
            #  19..23: hold full draw
            #  23..27: release snap!
            #  27..35: recover
            breath = 0.0
            if f_idx <= 27:
                w_bow = smoothstep(0.0, 6.0, float(f_idx))
            else:
                w_bow = 1.0 - smoothstep(27.0, 35.0, float(f_idx))
            if f_idx < 7:
                draw_t = 0.0
            elif f_idx <= 20:
                draw_t = smoothstep(7.0, 19.0, float(f_idx))
            elif f_idx <= 23:
                draw_t = 1.0
            else:
                draw_t = 1.0 - smoothstep(23.0, 26.0, float(f_idx))
            release_recoil = smoothstep(22.0, 24.0, float(f_idx)) * (1.0 - smoothstep(25.0, 32.0, float(f_idx)))

        if w_bow > 0.001:
            # Slight archer torso twist (left shoulder forward toward -Y)
            twist_angle = 0.32 * w_bow
            q_twist = Quaternion(Vector((0.0, 0.0, 1.0)), -twist_angle)
            for sp_bone, mult in ((pb_spine1, 0.45), (pb_spine2, 0.55)):
                q_s = Quaternion().slerp(q_twist, mult)
                mw = arm_mat @ sp_bone.matrix
                lw = mw.translation.copy()
                rw = q_s.to_matrix().to_4x4() @ mw
                rw.translation = lw
                sp_bone.matrix = arm_inv @ rw
                bpy.context.view_layer.update()

            # Counter-rotate neck/head so face keeps looking straight ahead (-Y)
            q_head = Quaternion(Vector((0.0, 0.0, 1.0)), twist_angle * 0.85)
            mw_h = arm_mat @ pb_head.matrix
            lw_h = mw_h.translation.copy()
            rw_h = q_head.to_matrix().to_4x4() @ mw_h
            rw_h.translation = lw_h
            pb_head.matrix = arm_inv @ rw_h
            bpy.context.view_layer.update()

            # Left arm: extended straight forward holding the bow riser
            bow_hand_target = chest_w + Vector((0.06, -0.56, 0.08 + 0.006 * breath))
            bow_elbow_pole = chest_w + Vector((0.32, -0.22, 0.04))
            solve_two_bone_chain(arm, pb_l_up, pb_l_fore, pb_l_hand, bow_hand_target, bow_elbow_pole, w_bow)

            # Right arm: nock at bow -> draw back to right cheek -> release snap back
            nock_pos = bow_hand_target + Vector((-0.04, 0.10, 0.02))
            cheek_anchor = head_w + Vector((-0.11, -0.06, -0.06 + 0.004 * breath))
            recoil_anchor = cheek_anchor + Vector((-0.06, 0.11, 0.03))
            r_target = nock_pos.lerp(cheek_anchor, draw_t)
            if release_recoil > 0.001:
                r_target = r_target.lerp(recoil_anchor, release_recoil)
            r_elbow_pole = chest_w + Vector((-0.42, 0.24, 0.22))
            solve_two_bone_chain(arm, pb_r_up, pb_r_fore, pb_r_hand, r_target, r_elbow_pole, w_bow)

        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f_idx + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f_idx + 1)
            pb.keyframe_insert("scale", frame=f_idx + 1)

    scn.frame_start = 1
    scn.frame_end = total_frames
    out_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out_path),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_animation_mode="ACTIVE_ACTIONS",
    )
    print(f"Exported {out_path} ({total_frames} frames)")
    return 0


if __name__ == "__main__":
    build_clip("shoot", OUT_SHOOT)
    build_clip("aim_idle", OUT_AIM)
