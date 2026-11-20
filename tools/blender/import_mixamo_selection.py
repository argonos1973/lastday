"""Build a mesh-free GLB animation library from the verified Mixamo downloads.

blender --background --factory-startup --python tools/blender/import_mixamo_selection.py
Optional arguments after --: --roles walk_forward,walk_left,...
"""

import argparse
import hashlib
import json
from pathlib import Path
import sys

import bpy


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets_src/mixamo"
OUTPUT = ROOT / "assets/animations/mixamo"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--roles")
    args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    receipts = json.loads((SOURCE / "downloads.json").read_text())
    roles = args.roles.split(",") if args.roles else list(receipts)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    reference = None
    actions = []
    provenance = []
    for role in roles:
        receipt = receipts[role]
        path = SOURCE / receipt["file"]
        if hashlib.sha256(path.read_bytes()).hexdigest() != receipt["sha256"]:
            raise RuntimeError("Source checksum mismatch: " + role)
        before = set(bpy.data.objects)
        bpy.ops.import_scene.fbx(filepath=str(path))
        imported = set(bpy.data.objects) - before
        rigs = [obj for obj in imported if obj.type == "ARMATURE"]
        if len(rigs) != 1 or any(obj.type == "MESH" for obj in imported):
            raise RuntimeError("Expected one skeleton without meshes: " + role)
        rig = rigs[0]
        if reference is None:
            reference = rig
        else:
            if set(reference.data.bones.keys()) != set(rig.data.bones.keys()):
                raise RuntimeError("Incompatible bone names: " + role)
            for bone in rig.data.bones:
                original = reference.data.bones[bone.name]
                error = max(abs(a - b) for row_a, row_b in zip(original.matrix_local, bone.matrix_local)
                            for a, b in zip(row_a, row_b))
                if error > 0.0001 or (original.parent.name if original.parent else "") != (
                        bone.parent.name if bone.parent else ""):
                    raise RuntimeError("Incompatible bind pose: " + role + "/" + bone.name)
        action = rig.animation_data.action
        if action is None:
            raise RuntimeError("Missing motion: " + role)
        action.name = role
        action.use_fake_user = True
        actions.append(action)
        provenance.append({
            "role": role, "motion_id": receipt["motion_id"], "name": receipt["mixamo_name"],
            "description": receipt["description"], "source_sha256": receipt["sha256"],
            "preferences": receipt["preferences"], "gms_hash": receipt["gms_hash"],
            "frames": list(action.frame_range),
        })
        if rig != reference:
            for obj in imported:
                bpy.data.objects.remove(obj, do_unlink=True)
        print("MIXAMO_ACTION", role, list(action.frame_range), flush=True)
    reference.animation_data.action = actions[0]
    reference.name = "Armature"
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_set(1)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    properties = bpy.ops.export_scene.gltf.get_rna_type().properties
    modes = {item.identifier for item in properties["export_animation_mode"].enum_items}
    if "ACTIONS" not in modes:
        raise RuntimeError("This Blender exporter cannot export separate actions.")
    options = {
        "filepath": str(OUTPUT / "character_motions.glb"),
        "export_format": "GLB", "export_animations": True,
        "export_animation_mode": "ACTIONS", "export_frame_range": False,
        "export_materials": "NONE",
    }
    if "export_anim_single_armature" in properties:
        options["export_anim_single_armature"] = True
    bpy.ops.export_scene.gltf(**options)
    (OUTPUT / "SOURCES.json").write_text(json.dumps({
        "source": "https://www.mixamo.com/",
        "character_id": receipts[roles[0]]["character_id"],
        "bones": len(reference.data.bones), "meshes": 0, "motions": provenance,
    }, ensure_ascii=False, indent=2) + "\n")
    print("MIXAMO_BUNDLE", len(actions), "motions", len(reference.data.bones), "bones", flush=True)


if __name__ == "__main__":
    main()
