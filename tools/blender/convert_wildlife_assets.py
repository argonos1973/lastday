"""Convert the supplied animated wildlife FBX models into compact Godot GLBs.

Run from the project root with:
  Blender --background --factory-startup --python tools/blender/convert_wildlife_assets.py

Only the idle, walk, trot and run cycles used by WildlifeController are retained.
The original source folders at the project root are left untouched.
"""

import bpy
import os
import sys


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
OUTPUT_DIR = os.path.join(ROOT, "assets", "models", "wildlife")

ANIMALS = {
    "deer": {
        "source": os.path.join(ROOT, "Deer 2.0", "Deer.fbx"),
        "actions": {
            "idle": ("a_standstraight_breathing", "a_a_deer_idle"),
            "walk": ("a_walkmedium_f",),
            "trot": ("a_trotfast_f",),
            "run": ("a_runfast_f",),
        },
    },
    "fox": {
        "source": os.path.join(ROOT, "Fox 2.0", "Fox.fbx"),
        "actions": {
            "idle": ("a_a_standstraight", "a_grazingonspota_1"),
            "walk": ("a_walkmedium_f",),
            "trot": ("a_trotfast_f",),
            "run": ("a_runfast_f",),
        },
    },
    "bear": {
        "source": os.path.join(ROOT, "Bear 2.0", "Bear.fbx"),
        "actions": {
            "idle": ("blackbear_idle", "a_standstraight_breathing"),
            "walk": ("a_walkmedium_f",),
            "trot": ("a_trotfast_f",),
            "run": ("a_runfast_f",),
        },
    },
}


def import_and_export(kind: str) -> None:
    spec = ANIMALS[kind]
    if not os.path.isfile(spec["source"]):
        raise FileNotFoundError(spec["source"])
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=spec["source"], automatic_bone_orientation=False)

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError(f"{kind}: expected one armature, found {len(armatures)}")
    armature = armatures[0]

    selected = {}
    all_actions = list(bpy.data.actions)
    for exported_name, suffixes in spec["actions"].items():
        matches = [
            action for action in all_actions
            if any(suffix in action.name.lower() for suffix in suffixes)
        ]
        if not matches:
            if exported_name == "idle":
                # A static bind/rest pose is a safe fallback for packs without
                # an explicit idle cycle. These supplied models have one.
                continue
            raise RuntimeError(f"{kind}: no source action found for {exported_name}: {suffixes}")
        # Prefer the specifically named first variant and keep one cycle only.
        selected[exported_name] = matches[0]

    for action in all_actions:
        if action not in selected.values():
            bpy.data.actions.remove(action)
    for exported_name, action in selected.items():
        action.name = exported_name
        # FBX import leaves id_root unset; the glTF exporter then skips every
        # non-active action. Mark the armature target explicitly and expose
        # each cycle as its own NLA strip for reliable Godot clip import.
        action.id_root = "ARMATURE"
        action.use_fake_user = True

    armature.animation_data_create()
    armature.animation_data.action = None
    for track in list(armature.animation_data.nla_tracks):
        armature.animation_data.nla_tracks.remove(track)
    for clip_name, action in selected.items():
        track = armature.animation_data.nla_tracks.new()
        track.name = clip_name
        track.mute = False
        strip = track.strips.new(clip_name, int(action.frame_range[0]), action)
        strip.name = clip_name
        strip.action_frame_start = action.frame_range[0]
        strip.action_frame_end = action.frame_range[1]
        strip.blend_type = "REPLACE"

    if "idle" not in selected:
        print(f"{kind}: no idle clip; using the model rest pose")
    print(f"{kind}: exporting clips {sorted(selected.keys())}")

    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = max(
        (int(action.frame_range[1]) for action in selected.values()), default=1
    )
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type in {"ARMATURE", "MESH"}:
            obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, f"{kind}.glb")
    bpy.ops.export_scene.gltf(
        filepath=output_path,
        export_format="GLB",
        use_selection=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_image_format="AUTO",
        export_image_quality=82,
        export_optimize_animation_size=True,
        export_skins=True,
        export_morph=False,
        export_apply=False,
        export_yup=True,
    )
    print(f"{kind}: wrote {output_path} ({os.path.getsize(output_path) / 1024 / 1024:.1f} MiB)")


args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
kinds = args or list(ANIMALS.keys())
for kind in kinds:
    if kind not in ANIMALS:
        raise ValueError(f"Unknown wildlife kind: {kind}")
    import_and_export(kind)
