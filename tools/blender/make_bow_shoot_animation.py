"""Build BowAimIdle.glb and BowShoot.glb from assets_src/Standing Aim Idle 01.fbx.

- BowAimIdle.glb: converts the Mixamo "Standing Aim Idle 01.fbx" clip directly
  into a lightweight animation-donor GLB (meshes stripped).
- BowShoot.glb: uses the same Mixamo archer rig/pose from "Standing Aim Idle 01.fbx"
  and animates the right arm reaching to the bowstring (nock), drawing the
  string back to the cheek anchor, releasing with recoil, and settling back
  into the aim hold.

Run from the repo root:
  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/blender/make_bow_shoot_animation.py
"""
import sys
from pathlib import Path
import bpy
from mathutils import Quaternion

ROOT = Path(__file__).resolve().parents[2]
SOURCE_FBX = ROOT / "assets_src" / "Standing Aim Idle 01.fbx"
OUT_AIM = ROOT / "assets" / "animations" / "BowAimIdle.glb"
OUT_SHOOT = ROOT / "assets" / "animations" / "BowShoot.glb"


def smoothstep(edge0: float, edge1: float, x: float) -> float:
    if edge1 <= edge0:
        return 1.0 if x >= edge1 else 0.0
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def load_clean_armature():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not SOURCE_FBX.exists():
        raise FileNotFoundError(f"Missing source FBX: {SOURCE_FBX}")
    bpy.ops.import_scene.fbx(filepath=str(SOURCE_FBX))
    for obj in list(bpy.data.objects):
        if obj.type != "ARMATURE":
            bpy.data.objects.remove(obj, do_unlink=True)
    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"Expected 1 armature, found {len(armatures)}")
    return armatures[0]


def export_aim_idle() -> None:
    arm = load_clean_armature()
    scn = bpy.context.scene
    act = arm.animation_data.action
    act.name = "BowAimIdle"
    f_start, f_end = int(round(act.frame_range[0])), int(round(act.frame_range[1]))
    scn.frame_start = f_start
    scn.frame_end = f_end
    OUT_AIM.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_AIM),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_animation_mode="ACTIVE_ACTIONS",
    )
    print(f"Exported {OUT_AIM} ({f_end - f_start + 1} frames)")


def export_bow_shoot() -> None:
    arm = load_clean_armature()
    scn = bpy.context.scene
    total_frames = 36

    # Sample the base archer stance from Standing Aim Idle 01
    base_samples = []
    for f in range(1, total_frames + 1):
        scn.frame_set(f)
        bpy.context.view_layer.update()
        base_samples.append({
            pb.name: (pb.location.copy(), pb.rotation_quaternion.copy(), pb.scale.copy())
            for pb in arm.pose.bones
        })

    new_act = bpy.data.actions.new("BowShoot")
    arm.animation_data.action = new_act

    # Calibrated on Standing Aim Idle 01.fbx:
    # - Nock pose: right hand forward near the bow grip (-Y direction)
    # - Anchor pose: the native Standing Aim Idle 01 cheek anchor
    # - Release pose: crisp backward follow-through after releasing the string
    q_ra_nock = Quaternion((0.2364, -0.5724, 0.1204, -0.7759)).normalized()
    q_rf_nock = Quaternion((0.9301, -0.0215, -0.3612, -0.0623)).normalized()
    q_ra_rel = Quaternion((0.9258, 0.1987, 0.1397, -0.2898)).normalized()
    q_rf_rel = Quaternion((0.3846, -0.0403, -0.0064, -0.9222)).normalized()

    pb_ra = arm.pose.bones["mixamorig:RightArm"]
    pb_rf = arm.pose.bones["mixamorig:RightForeArm"]

    for f_idx in range(total_frames):
        sample = base_samples[f_idx]
        for pb in arm.pose.bones:
            loc, rot_q, scl = sample[pb.name]
            pb.location = loc
            pb.rotation_quaternion = rot_q.copy()
            pb.scale = scl

        ra_anchor = sample["mixamorig:RightArm"][1]
        rf_anchor = sample["mixamorig:RightForeArm"][1]

        # Frame timeline (36 frames @ 30fps = 1.2s):
        #  0..3  : reach to nock at bowstring
        #  3..17 : draw bowstring steadily from bow to cheek anchor
        # 17..21 : hold full draw at anchor
        # 21..25 : release snap / follow-through
        # 25..35 : recover back to archer aim stance
        if f_idx <= 3:
            w_nock = smoothstep(0.0, 3.0, float(f_idx))
            pb_ra.rotation_quaternion = ra_anchor.slerp(q_ra_nock, w_nock)
            pb_rf.rotation_quaternion = rf_anchor.slerp(q_rf_nock, w_nock)
        elif f_idx <= 17:
            draw_t = smoothstep(3.0, 17.0, float(f_idx))
            pb_ra.rotation_quaternion = q_ra_nock.slerp(ra_anchor, draw_t)
            pb_rf.rotation_quaternion = q_rf_nock.slerp(rf_anchor, draw_t)
        elif f_idx <= 21:
            pb_ra.rotation_quaternion = ra_anchor
            pb_rf.rotation_quaternion = rf_anchor
        elif f_idx <= 25:
            rel_t = smoothstep(21.0, 24.0, float(f_idx))
            pb_ra.rotation_quaternion = ra_anchor.slerp(q_ra_rel, rel_t)
            pb_rf.rotation_quaternion = rf_anchor.slerp(q_rf_rel, rel_t)
        else:
            rec_t = smoothstep(25.0, 35.0, float(f_idx))
            pb_ra.rotation_quaternion = q_ra_rel.slerp(ra_anchor, rec_t)
            pb_rf.rotation_quaternion = q_rf_rel.slerp(rf_anchor, rec_t)

        bpy.context.view_layer.update()
        for pb in arm.pose.bones:
            pb.keyframe_insert("location", frame=f_idx + 1)
            pb.keyframe_insert("rotation_quaternion", frame=f_idx + 1)
            pb.keyframe_insert("scale", frame=f_idx + 1)

    scn.frame_start = 1
    scn.frame_end = total_frames
    OUT_SHOOT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT_SHOOT),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_animation_mode="ACTIVE_ACTIONS",
    )
    print(f"Exported {OUT_SHOOT} ({total_frames} frames)")


def main() -> int:
    export_aim_idle()
    export_bow_shoot()
    return 0


if __name__ == "__main__":
    sys.exit(main())
