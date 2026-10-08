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
# Real-size hoe (~1.25 m): handle along Z, standing on its butt. Collar +
# neck bend the blade forward at the top.
cyl(.0160, .0138, 1.16, (0, 0, .58), WOOD)
cyl(.0300, .0300, .075, (0, 0, 1.185), STEEL)                   # eye collar
# Neck: short box angled forward from the collar.
box(.022, .022, .095, (0, .042, 1.225), STEEL, rot=(math.radians(35), 0, 0))
# Blade: flat trapezoid hanging below the neck, edge down, leaning forward.
plate(.085, .060, .19, .30, (0, .080, 1.10), STEEL,
      rot=(math.radians(-14), 0, math.radians(45)))
finish('tool_hoe')

# ------------------------------------------------------------- shovel ----
# Real-size shovel (~1.44 m): blade point down at z=0 so it stands "stuck";
# T-grip on top.
# Blade: flattened 4-vert cone, point down, ~0.30 m long / 0.21 m wide.
blade = plate(.105, .070, .30, .30, (0, 0, .15), STEEL,
              rot=(math.radians(180), 0, math.radians(45)))
# Socket and slight shoulder where the handle meets the blade.
cyl(.0240, .0210, .115, (0, 0, .345), STEEL)
box(.095, .030, .018, (0, 0, .40), STEEL_EDGE)
# Handle.
cyl(.0200, .0175, .95, (0, 0, .875), WOOD)
# T-grip: crossbar + end knobs.
box(.24, .032, .032, (0, 0, 1.41), WOOD_DARK)
cyl(.0240, .0240, .045, (-.125, 0, 1.41), WOOD_DARK, rot=(0, math.radians(90), 0))
cyl(.0240, .0240, .045, (.125, 0, 1.41), WOOD_DARK, rot=(0, math.radians(90), 0))
cyl(.0210, .0210, .055, (0, 0, 1.375), WOOD_DARK)
finish('tool_shovel')

# ------------------------------------------------------------ pickaxe ----
# Real-size pickaxe (~0.93 m): tapered handle, eye block at the top, two
# down-curving picks.
cyl(.0220, .0178, .86, (0, 0, .43), WOOD)
box(.10, .056, .060, (0, 0, .885), STEEL)                       # eye
# Picks: tapered cones whose tips point outward and down.
cyl(.0, .042, .30, (-.135, 0, .845), STEEL,
   rot=(0, math.radians(58), 0), verts=9)
cyl(.0, .042, .30, (.135, 0, .845), STEEL,
   rot=(0, math.radians(-58), 0), verts=9)
# Slightly wider steel sleeves at the pick tips.
cyl(.0, .050, .09, (-.255, 0, .780), STEEL_EDGE,
   rot=(0, math.radians(58), 0), verts=9)
cyl(.0, .050, .09, (.255, 0, .780), STEEL_EDGE,
   rot=(0, math.radians(-58), 0), verts=9)
finish('tool_pickaxe')

print('FARM_TOOLS_DONE', sorted(p.name for p in OUT.glob('*.glb')))
