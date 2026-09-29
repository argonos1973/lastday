"""Strip embedded textures/materials from animation donor GLBs.

Usage:
  Blender --background --factory-startup --python strip_anim_glb_textures.py -- \
      [--keep-props] file1.glb file2.glb ...

Default mode removes every material/image (GLB only donates animations).
--keep-props clears materials only on skinned meshes (armature-modified) and
purges the orphaned images, so prop meshes like FishingRod keep their look.
"""
import bpy
import sys


def has_armature_modifier(obj):
    return obj.type == "MESH" and any(m.type == "ARMATURE" for m in obj.modifiers)


def strip_all():
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            obj.data.materials.clear()
    for mat in list(bpy.data.materials):
        bpy.data.materials.remove(mat)
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)


def strip_skinned_only():
    for obj in bpy.data.objects:
        if has_armature_modifier(obj):
            obj.data.materials.clear()
    for _ in range(8):
        bpy.data.orphans_purge(do_recursive=True)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    keep_props = "--keep-props" in argv
    files = [a for a in argv if a.endswith(".glb")]
    for path in files:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=path)
        if keep_props:
            strip_skinned_only()
        else:
            strip_all()
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            export_animations=True,
            export_animation_mode="ACTIONS",
            export_skins=True,
            export_def_bones=False,
            export_yup=True,
            export_apply=False,
        )
        print("STRIPPED", path)


main()
