"""Farm/mining hand tools: hoe, shovel and pickaxe for world loot.

Authored directly in Blender space (Z up, metres). The gltf exporter writes
them Y-up for Godot. Tools stand on the handle end like the Kenney kit they
replace so drop/loot transforms stay valid.
"""
from pathlib import Path
import math
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/props/tools'
bpy.ops.wm.read_factory_settings(use_empty=True)
OUT.mkdir(parents=True, exist_ok=True)


def material(name, color, roughness=.85, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return m


WOOD = material('tool_wood', (.34, .23, .12), .8)
WOOD_DARK = material('tool_wood_worn', (.22, .14, .07), .9)
STEEL = material('tool_steel', (.30, .32, .34), .55, .7)
STEEL_EDGE = material('tool_steel_edge', (.48, .50, .52), .4, .85)


def finish(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT / f'{name}.glb'), export_format='GLB',
        use_selection=False, export_yup=True,
    )
    ob.select_set(False)
    bpy.data.objects.remove(ob)


def cyl(r1, r2, depth, loc, mat, rot=(0, 0, 0), verts=10):
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=depth, vertices=verts,
        location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.data.materials.append(mat)
    return ob


def box(sx, sy, sz, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    ob = bpy.context.active_object
    ob.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(scale=True)
    ob.data.materials.append(mat)
    return ob


def plate(r1, r2, depth, thin, loc, mat, rot=(0, 0, 0)):
    """Flattened 4-sided cone -> trapezoidal blade plate."""
    bpy.ops.mesh.primitive_cone_add(
        radius1=r1, radius2=r2, depth=depth, vertices=4,
        location=loc)
    ob = bpy.context.active_object
    ob.scale.y = thin
    ob.rotation_euler = rot
    bpy.context.view_layer.objects.active = ob
    ob.data.materials.append(mat)
    return ob


# ---------------------------------------------------------------- hoe ----
# Handle along Z, standing on its butt. Collar + neck bend the blade forward.
cyl(.0155, .0130, .40, (0, 0, .20), WOOD)
cyl(.0190, .0190, .05, (0, 0, .415), STEEL)                      # eye collar
# Neck: short box angled forward from the collar.
box(.014, .014, .055, (0, .022, .435), STEEL, rot=(math.radians(35), 0, 0))
# Blade: flat trapezoid hanging below the neck, edge down, leaning forward.
plate(.052, .038, .085, .30, (0, .050, .365), STEEL,
      rot=(math.radians(-14), 0, math.radians(45)))
finish('tool_hoe')

# ------------------------------------------------------------- shovel ----
# Blade point down at z=0 so it stands "stuck"; T-grip on top.
# Blade: flattened 4-vert cone, point down.
blade = plate(.085, .052, .13, .30, (0, 0, .065), STEEL,
              rot=(math.radians(180), 0, math.radians(45)))
# Socket and slight shoulder.
cyl(.0170, .0150, .075, (0, 0, .155), STEEL)
box(.050, .018, .010, (0, 0, .195), STEEL_EDGE)
# Handle.
cyl(.0155, .0135, .31, (0, 0, .35), WOOD)
# T-grip: crossbar + end knobs.
box(.13, .018, .018, (0, 0, .515), WOOD_DARK)
cyl(.0190, .0190, .026, (-.068, 0, .515), WOOD_DARK, rot=(0, math.radians(90), 0))
cyl(.0190, .0190, .026, (.068, 0, .515), WOOD_DARK, rot=(0, math.radians(90), 0))
cyl(.0165, .0165, .028, (0, 0, .50), WOOD_DARK)
finish('tool_shovel')

# ------------------------------------------------------------ pickaxe ----
# Slightly tapered handle, eye block at the top, two down-curving picks.
cyl(.0170, .0140, .40, (0, 0, .20), WOOD)
box(.052, .030, .034, (0, 0, .415), STEEL)                      # eye
# Picks: tapered cones whose tips point outward and down.
cyl(.0, .030, .155, (-.085, 0, .385), STEEL,
   rot=(0, math.radians(62), 0), verts=9)
cyl(.0, .030, .155, (.085, 0, .385), STEEL,
   rot=(0, math.radians(-62), 0), verts=9)
# Slightly wider steel sleeves at the pick tips.
cyl(.0, .038, .045, (-.148, 0, .350), STEEL_EDGE,
   rot=(0, math.radians(62), 0), verts=9)
cyl(.0, .038, .045, (.148, 0, .350), STEEL_EDGE,
   rot=(0, math.radians(-62), 0), verts=9)
finish('tool_pickaxe')

print('FARM_TOOLS_DONE', sorted(p.name for p in OUT.glob('*.glb')))
