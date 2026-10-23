"""Inspect Drinking.glb: bones, action frame range, and hand trajectory.

Run:  Blender --background --factory-startup --python tools/blender/inspect_drinking_clip.py
"""
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets" / "animations" / "Drinking.glb"


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC))
    arms = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
    print("ARMATURES:", [a.name for a in arms])
    if not arms:
        return 2
    arm = arms[0]
    print("BONES:", [b.name for b in arm.data.bones][:60])
    act = arm.animation_data.action if arm.animation_data else None
    print("ACTION:", act.name if act else None)
    acts = list(bpy.data.actions)
    print("ALL_ACTIONS:", [a.name for a in acts])
    if acts:
        a = acts[0]
        print("RANGE:", a.frame_range)
        # Hand world pos at each 5th frame to find the reach apex.
        scn = bpy.context.scene
        hand = None
        for n in ("mixamorig:RightHand", "mixamorig5_RightHand", "RightHand", "mixamorigRightHand"):
            if n in arm.pose.bones:
                hand = arm.pose.bones[n]
                break
        head = None
        for n in ("mixamorig:Head", "mixamorig5_Head", "Head"):
            if n in arm.pose.bones:
                head = arm.pose.bones[n]
                break
        print("HAND_BONE:", hand.name if hand else None, "HEAD:", head.name if head else None)
        f0, f1 = int(a.frame_range[0]), int(a.frame_range[1])
        chest = None
        for n in ("mixamorig5_Spine2", "mixamorig:Spine2", "Spine2"):
            if n in arm.pose.bones:
                chest = arm.pose.bones[n]
                break
        if hand:
            deps = bpy.context.evaluated_depsgraph_get()
            for f in [0, 20, 40, 55, 65, 75, 85, 100, 120, 150, 200]:
                scn.frame_set(f)
                ev = arm.evaluated_get(deps)
                hw = ev.matrix_world @ ev.pose.bones[hand.name].head
                cw = ev.matrix_world @ ev.pose.bones[chest.name].head if chest else Vector()
                hd = ev.matrix_world @ ev.pose.bones[head.name].head if head else Vector()
                rel = hw - cw
                print("f=%d hand-chest=(%.3f %.3f %.3f) head-chest=(%.3f %.3f %.3f)" % (f, rel.x, rel.y, rel.z, hd.x - cw.x, hd.y - cw.y, hd.z - cw.z))
    return 0


if __name__ == "__main__":
    sys.exit(main())
