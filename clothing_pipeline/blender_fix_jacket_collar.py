"""
blender_fix_jacket_collar.py
============================

Repair the survival jacket (cloth_torso) collar/neckline: the A->T retarget shot
a few neck vertices up into jagged spikes that expose the chest skin. We import
player_with_clothes.glb, build a vertex group covering the top neckline band of
the jacket, run a limited Smooth pass over just that band (in REST pose, above
the Armature modifier so weights are preserved), then re-export the whole
character+clothing GLB so Godot picks up the cleaned jacket.

Run headless:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
     --python clothing_pipeline/blender_fix_jacket_collar.py -- \
     --glb assets/characters/adapted/player_with_clothes.glb
"""

import bpy
import sys
import os


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    glb = "assets/characters/adapted/player_with_clothes.glb"
    i = 0
    while i < len(argv):
        if argv[i] == "--glb":
            glb = argv[i + 1]; i += 2
        else:
            i += 1
    return os.path.abspath(glb)


def main():
    glb = parse_args()
    print(f"=== FIX jacket collar in {glb} ===")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)

    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    jacket = bpy.data.objects.get("cloth_torso")
    if jacket is None:
        print("  [FATAL] cloth_torso not found")
        return

    # bbox of the jacket (local mesh space, rest pose baked into mesh data)
    zs = [v.co.z for v in jacket.data.vertices]
    z_min, z_max = min(zs), max(zs)
    z_span = z_max - z_min
    # neckline band = top 22% of the jacket
    band_lo = z_max - 0.22 * z_span
    print(f"  jacket z range [{z_min:.3f}, {z_max:.3f}] band_lo={band_lo:.3f}")

    # Build a vertex group weighted by how far into the band each vertex is, so
    # the very top (spikiest) verts get smoothed most and it tapers off smoothly.
    vg = jacket.vertex_groups.get("collar_fix")
    if vg is None:
        vg = jacket.vertex_groups.new(name="collar_fix")
    count = 0
    for v in jacket.data.vertices:
        if v.co.z >= band_lo:
            t = (v.co.z - band_lo) / max(1e-6, (z_max - band_lo))
            vg.add([v.index], min(1.0, t), 'REPLACE')
            count += 1
    print(f"  collar_fix group: {count} verts")

    # Smooth modifier limited to the collar group, applied above the armature.
    bpy.ops.object.select_all(action='DESELECT')
    jacket.select_set(True)
    bpy.context.view_layer.objects.active = jacket

    smooth = jacket.modifiers.new("CollarSmooth", 'SMOOTH')
    smooth.vertex_group = "collar_fix"
    smooth.factor = 0.8
    smooth.iterations = 25
    # move above the Armature modifier so it acts on rest geometry
    while jacket.modifiers[0].name != smooth.name:
        bpy.ops.object.modifier_move_up(modifier=smooth.name)
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    print("  applied CollarSmooth")

    # ensure armature modifier still present
    if not any(m.type == 'ARMATURE' for m in jacket.modifiers):
        am = jacket.modifiers.new("Armature", 'ARMATURE')
        am.object = arm

    # Re-export the full character + clothing (single Mixamo armature)
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in ([arm] + meshes):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm

    bpy.ops.export_scene.gltf(
        filepath=glb,
        export_format='GLB',
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_image_format='AUTO',
        export_materials='EXPORT',
        export_skins=True,
        export_animations=False,
        export_extras=True,
    )
    print(f"  re-exported -> {glb}")
    print("=== FIX done ===")


if __name__ == "__main__":
    main()
