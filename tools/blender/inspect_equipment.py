from pathlib import Path
import bpy
root = Path(__file__).resolve().parents[2]
bpy.ops.import_scene.gltf(filepath=str(root / 'assets/characters/adapted/player_with_clothes.glb'))
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj.name in ['Shoes', 'cloth_feet', 'cloth_hands', 'soldier_legs']:
        print('GEAR', obj.name, 'bounds', [tuple(v) for v in obj.bound_box], 'matrix', obj.matrix_world, flush=True)
        for mat in obj.data.materials:
            print('MAT', mat.name, [(n.name, n.image.name if n.image else None) for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE'], flush=True)
bpy.ops.import_scene.gltf(filepath=str(root / 'assets/external/realistic/root_glb/low_poly_game_ready_military_tactical_backpack.glb'))
for obj in bpy.context.selected_objects:
    if obj.type == 'MESH':
        print('PACK', obj.name, len(obj.data.uv_layers), flush=True)
        for mat in obj.data.materials:
            print('PACK_MAT', mat.name, [(n.name, n.image.name if n.image else None) for n in mat.node_tree.nodes if n.type == 'TEX_IMAGE'], flush=True)
