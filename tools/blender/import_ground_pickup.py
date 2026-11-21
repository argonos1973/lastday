"""Bake the Mixamo ground-fruit pickup as a short, mesh-free shared gesture.

python3 tools/download_mixamo.py --roles pickup_ground
blender --background --factory-startup --python tools/blender/import_ground_pickup.py
"""
import hashlib
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets_src/mixamo"
OUTPUT = ROOT / "assets/animations"
DURATION = 1.4
GRAB_TIME = 0.7
FPS = 30

receipt = json.loads((SOURCE / "downloads.json").read_text())["pickup_ground"]
path = SOURCE / receipt["file"]
assert hashlib.sha256(path.read_bytes()).hexdigest() == receipt["sha256"]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.fbx(filepath=str(path))
rigs = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
assert len(rigs) == 1 and not any(obj.type == "MESH" for obj in bpy.context.scene.objects)
rig = rigs[0]
source_action = rig.animation_data.action
first, last = source_action.frame_range
frames = round(DURATION * FPS)
contact_frame = round(GRAB_TIME * FPS)
poses = []
for frame in range(frames + 1):
    # First reach only. The original repeats the picking/inspection three
    # times; jump from its first contact to the final rise, without the idle
    # lead-in or the repeated hand gestures.
    source_frame = (18.0 + (55.0 - 18.0) * frame / contact_frame) if frame <= contact_frame else (
        162.0 + (last - 162.0) * (frame - contact_frame) / (frames - contact_frame))
    bpy.context.scene.frame_set(int(source_frame), subframe=source_frame % 1)
    poses.append({bone.name: bone.matrix_basis.to_quaternion().copy() for bone in rig.pose.bones})
# The source inspects the fruit near the face before standing. Keep its
# kneeling/contact pose, then return the right arm to its final carrying pose:
# large ground items (especially rifles) must not pass across the face.
return_frames = round(0.3 * FPS)
final_pose = poses[-1].copy()
contact_pose = poses[contact_frame].copy()
for frame in range(contact_frame + 1, frames + 1):
    u = min(1.0, (frame - contact_frame) / return_frames)
    u = u * u * (3.0 - 2.0 * u)
    for name in poses[frame]:
        if name.split(":")[-1] in {"RightShoulder", "RightArm", "RightForeArm", "RightHand"}:
            poses[frame][name] = contact_pose[name].slerp(final_pose[name], u)
        else:
            blend = min(1.0, (frame - contact_frame) / 6.0)
            blend = blend * blend * (3.0 - 2.0 * blend)
            poses[frame][name] = contact_pose[name].slerp(poses[frame][name], blend)
action = bpy.data.actions.new("pickup_ground")
rig.animation_data.action = action
for frame, pose in enumerate(poses, 1):
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.rotation_quaternion = pose[bone.name]
        bone.keyframe_insert("rotation_quaternion", frame=frame, group=bone.name)
for curve in action.fcurves:
    for key in curve.keyframe_points:
        key.interpolation = "LINEAR"
for other in list(bpy.data.actions):
    if other != action:
        bpy.data.actions.remove(other)
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = frames + 1
bpy.context.scene.frame_set(1)
rig.name = "Armature"
bpy.ops.export_scene.gltf(
    filepath=str(OUTPUT / "ground_pickup.glb"), export_format="GLB",
    export_animations=True, export_animation_mode="ACTIONS",
    export_frame_range=True, export_materials="NONE",
)
(OUTPUT / "ground_pickup.SOURCES.json").write_text(json.dumps({
    "source": "https://www.mixamo.com/",
    "motion_id": receipt["motion_id"], "name": receipt["mixamo_name"],
    "description": receipt["description"], "source_sha256": receipt["sha256"],
    "preferences": receipt["preferences"], "gms_hash": receipt["gms_hash"],
    "source_frames": [first, last], "duration": DURATION, "fps": FPS,
    "bones": len(rig.data.bones), "meshes": 0,
    "segments": [[18, 55], [162, last]], "grab_time": GRAB_TIME,
    "adaptation": "One kneel/reach/rise only. Remove idle lead-in and repeated picking/inspection. Blend the joined body pose and return the right arm to its carrying pose after 0.7s contact.",
    "regenerate": "tools/blender/import_ground_pickup.py",
}, ensure_ascii=False, indent=2) + "\n")
print("GROUND_PICKUP_BAKED", DURATION, "seconds", len(rig.data.bones), "bones")
