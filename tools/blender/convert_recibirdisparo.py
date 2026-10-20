"""Convert recibirdisparo.fbx into a shot-reaction animation donor GLB.

The Mixamo clip runs 61 frames @30fps: frames 1-14 are the hit + recoil
(hips stay at standing height), frames 15+ are the collapse to the ground.
Only the impact is wanted, so the action is trimmed to frames 1-14.

The GLB only donates its Animation (PlayerController retargets it onto the
player skeleton), so all meshes are dropped to keep the file small.

Run from the repo root:
  Blender --background --factory-startup --python tools/blender/convert_recibirdisparo.py
"""
import sys
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets_src" / "recibirdisparo.fbx"
TARGET = ROOT / "assets" / "animations" / "RecibirDisparo.glb"
FRAME_END = 14


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if not SOURCE.exists():
        print(f"Missing source: {SOURCE}")
        return 2
    bpy.ops.import_scene.fbx(filepath=str(SOURCE))

    # Drop every mesh: the file is only an animation donor.
    for obj in list(bpy.data.objects):
        if obj.type == "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)

    armatures = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    if len(armatures) != 1:
        print(f"Expected 1 armature, found {len(armatures)}")
        return 3

    scn = bpy.context.scene
    scn.frame_start = 1
    scn.frame_end = FRAME_END

    # Trim keyframes outside [1, FRAME_END] so the exported clip can never
    # regress to including the fall even if frame-range export is ignored.
    for act in bpy.data.actions:
        for fc in act.fcurves:
            for kp in reversed(fc.keyframe_points.values()):
                if kp.co.x > FRAME_END:
                    fc.keyframe_points.remove(kp, fast=True)

    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(TARGET),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_animation_mode="ACTIVE_ACTIONS",
    )
    print(f"Exported {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
