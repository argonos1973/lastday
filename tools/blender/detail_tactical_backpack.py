"""Bake fabric grain over the backpack's original seams and buckles in Blender."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(ROOT / 'assets/external/realistic/root_glb/low_poly_game_ready_military_tactical_backpack.glb'))
scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.samples = 4
scene.render.bake.margin = 16
out = ROOT / 'assets/textures/clothing'
for obj in list(bpy.context.selected_objects):
    if obj.type != 'MESH':
        continue
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    for mat in obj.data.materials:
        tree = mat.node_tree
        bsdf = next(n for n in tree.nodes if n.type == 'BSDF_PRINCIPLED')
        original_normal = bsdf.inputs['Normal'].links[0].from_socket if bsdf.inputs['Normal'].is_linked else None
        uv = tree.nodes.new('ShaderNodeTexCoord')
        noise = tree.nodes.new('ShaderNodeTexNoise')
        tree.links.new(uv.outputs['UV'], noise.inputs['Vector'])
        noise.inputs['Scale'].default_value = 240
        noise.inputs['Detail'].default_value = 2
        bump = tree.nodes.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value = 0.18
        bump.inputs['Distance'].default_value = 0.001
        tree.links.new(noise.outputs['Fac'], bump.inputs['Height'])
        if original_normal:
            tree.links.new(original_normal, bump.inputs['Normal'])
        tree.links.new(bump.outputs['Normal'], bsdf.inputs['Normal'])
        target = tree.nodes.new('ShaderNodeTexImage')
        target.image = bpy.data.images.new('backpack_' + mat.name + '_normal', width=2048, height=2048)
        target.image.colorspace_settings.name = 'Non-Color'
        tree.nodes.active = target
        bpy.ops.object.bake(type='NORMAL', normal_space='TANGENT')
        target.image.filepath_raw = str(out / (target.image.name + '.png'))
        target.image.file_format = 'PNG'
        target.image.save()
        normal = tree.nodes.new('ShaderNodeNormalMap')
        tree.links.new(target.outputs['Color'], normal.inputs['Color'])
        tree.links.new(normal.outputs['Normal'], bsdf.inputs['Normal'])
        print('BACKPACK_BAKED', mat.name, flush=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/characters/adapted/backpack_detailed.glb'), export_format='GLB', export_animations=False, use_selection=True)
print('BACKPACK_COMPLETE', flush=True)
