#!/usr/bin/env python3
"""Generates the river/lake shore assets for Un dia mas.

Bakes a cross-shore texture strip (shore_band_{albedo,normal,roughness}.png)
where V=0 sits under the waterline and V=1 fades into the terrain, and
exports weathered shore props (driftwood, flat stones, pebble patch) as GLB.

Run headless:
    Blender --background --factory-startup --python tools/blender/generate_shore_assets.py
"""
import bpy
import math
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent.parent
TEX_OUT = ROOT / "assets" / "textures" / "shore"
PROP_OUT = ROOT / "assets" / "models" / "props" / "shore"
TEX_OUT.mkdir(parents=True, exist_ok=True)
PROP_OUT.mkdir(parents=True, exist_ok=True)

TEX_W = 1024
TEX_H = 256

scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = TEX_W
scene.render.resolution_y = TEX_H
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1

for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.object
plane.name = "ShoreBakeSurface"
# The render is TEX_W x TEX_H; the 2x2 plane must be stretched to fill the
# whole ortho frame or the texture bakes into only the centre columns.
plane.scale = (float(TEX_W) / float(TEX_H), 1.0, 1.0)
camera_data = bpy.data.cameras.new("ShoreTextureCamera")
camera = bpy.data.objects.new("ShoreTextureCamera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0, 0, 3)
camera_data.type = "ORTHO"
# ortho_scale sizes the horizontal frame; with a wide strip the vertical
# extent is ortho_scale/aspect, so scale it by the render aspect to see
# exactly the 8x2 m bake plane.
camera_data.ortho_scale = 2.0 * (float(TEX_W) / float(TEX_H))
scene.camera = camera


# ---------------------------------------------------------------------------
# Shore band texture
# ---------------------------------------------------------------------------
material = bpy.data.materials.new("ShoreBand")
material.use_nodes = True
tree = material.node_tree
plane.data.materials.clear()
plane.data.materials.append(material)
output = tree.nodes.get("Material Output")
emission = tree.nodes.new("ShaderNodeEmission")
tree.links.new(emission.outputs[0], output.inputs["Surface"])


def node(kind, **properties):
    item = tree.nodes.new(kind)
    for key, value in properties.items():
        setattr(item, key, value)
    return item


def put(socket, value):
    if isinstance(value, bpy.types.NodeSocket):
        tree.links.new(value, socket)
    else:
        socket.default_value = value


def calc(operation, a, b=0.0):
    item = node("ShaderNodeMath", operation=operation)
    put(item.inputs[0], a)
    put(item.inputs[1], b)
    return item.outputs[0]


def ramp(value, stops):
    item = node("ShaderNodeValToRGB")
    item.color_ramp.interpolation = "EASE"
    for i, (position, color) in enumerate(stops):
        entry = item.color_ramp.elements[i] if i < 2 else item.color_ramp.elements.new(position)
        entry.position = position
        entry.color = (*color, 1) if len(color) == 3 else color
    put(item.inputs[0], value)
    return item.outputs[0]


def mix(factor, a, b, mode="MIX"):
    item = node("ShaderNodeMixRGB", blend_type=mode)
    put(item.inputs[0], factor)
    put(item.inputs[1], a)
    put(item.inputs[2], b)
    return item.outputs[0]


uv = node("ShaderNodeTexCoord").outputs["UV"]
split = node("ShaderNodeSeparateXYZ")
put(split.inputs[0], uv)
u, v = split.outputs[0], split.outputs[1]

# Periodic coordinates in U only: the strip tiles along the shore but the
# cross-shore gradient (V) must stay anchored, so V stays a plain UV channel.
combine = node("ShaderNodeCombineXYZ")
put(combine.inputs[0], calc("COSINE", calc("MULTIPLY", u, math.tau)))
put(combine.inputs[1], calc("SINE", calc("MULTIPLY", u, math.tau)))
put(combine.inputs[2], calc("MULTIPLY", v, 4.0))
periodic = combine.outputs[0]


def noise(scale, detail=4, offset=0.0, vector=None):
    item = node("ShaderNodeTexNoise", noise_dimensions="4D")
    put(item.inputs["Vector"], periodic if vector is None else vector)
    put(item.inputs["W"], offset)
    item.inputs["Scale"].default_value = scale
    item.inputs["Detail"].default_value = detail
    item.inputs["Roughness"].default_value = 0.72
    return item.outputs["Fac"]


grain = noise(90, 3)
medium = noise(11, 5)
broad = noise(1.6, 4, 0.31)
flecks = noise(60, 2, 7.7)

# Cross-shore position with organic wobble so the wet edge meanders.
wobbled_v = calc("ADD", v, calc("MULTIPLY", calc("SUBTRACT", medium, 0.5), 0.14))

# Base substrate gradient: silt -> wet mud -> wet sand -> damp sand -> dry dirt.
substrate = ramp(wobbled_v, [
    (0.00, (0.070, 0.066, 0.042)),   # submerged silt, olive-dark
    (0.12, (0.125, 0.105, 0.068)),   # saturated mud at the waterline
    (0.32, (0.225, 0.180, 0.118)),   # wet sand
    (0.55, (0.345, 0.290, 0.198)),   # damp sand
    (0.78, (0.420, 0.362, 0.256)),   # drying sand/dirt
    (1.00, (0.435, 0.388, 0.272)),   # dry dirt blending toward terrain
])

# Algae / waterline stain: a thin, subtle olive tint just above the silt.
algae_band = ramp(wobbled_v, [(0.05, (0, 0, 0, 0)), (0.11, (0.38, 0.38, 0.38, 1)), (0.20, (0, 0, 0, 0))])
substrate = mix(algae_band, substrate, (0.125, 0.145, 0.062, 1))

# Pebbles: voronoi cell dots confined to the dry half of the strip.
vor = node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", distance="EUCLIDEAN", feature="F1")
put(vor.inputs["Vector"], periodic)
put(vor.inputs["W"], 2.9)
vor.inputs["Scale"].default_value = 11.0
pebble_mask = ramp(vor.outputs["Distance"], [(0.022, (1, 1, 1, 1)), (0.042, (0, 0, 0, 0))])
pebble_zone = ramp(wobbled_v, [(0.30, (0, 0, 0, 0)), (0.48, (1, 1, 1, 1)), (0.97, (1, 1, 1, 1))])
pebble_id = noise(140, 1, 4.4)
pebble_color = ramp(pebble_id, [
    (0.15, (0.13, 0.12, 0.105)),
    (0.45, (0.28, 0.25, 0.20)),
    (0.75, (0.47, 0.42, 0.33)),
    (1.00, (0.20, 0.17, 0.14)),
])
pebbles = mix(calc("MULTIPLY", pebble_mask, pebble_zone), substrate, pebble_color)

# Dark organic flecks / debris on the dry side.
debris_mask = ramp(flecks, [(0.56, (0, 0, 0, 0)), (0.62, (0.65, 0.65, 0.65, 1)), (0.70, (0, 0, 0, 0))])
debris_zone = ramp(wobbled_v, [(0.45, (0, 0, 0, 0)), (0.75, (1, 1, 1, 1))])
debris = mix(calc("MULTIPLY", debris_mask, debris_zone), (1, 1, 1, 1), (0.10, 0.085, 0.055, 1))

color = mix(0.25, pebbles, grain, "MULTIPLY")
color = mix(1.0, color, debris, "MULTIPLY")

# Height: pebble bumps + sand ripples running along the shore + fine grain.
ripples = calc("SINE", calc("ADD", calc("MULTIPLY", wobbled_v, 90.0), calc("MULTIPLY", broad, 22.0)))
ripple_zone = ramp(wobbled_v, [(0.02, (0.35, 0.35, 0.35, 1)), (0.30, (1, 1, 1, 1)), (0.70, (0.35, 0.35, 0.35, 1))])
height = calc("ADD", 0.5, calc("MULTIPLY", calc("MULTIPLY", ripples, ripple_zone), 0.10))
height = mix(0.30, height, grain)
height = mix(calc("MULTIPLY", pebble_mask, pebble_zone), height, (0.85, 0.85, 0.85, 1))

# Roughness: the wet band stays dark/glossy, dry sand stays rough.
wetness = ramp(wobbled_v, [(0.00, (0.30, 0.30, 0.30, 1)), (0.30, (0.38, 0.38, 0.38, 1)), (0.60, (0.85, 0.85, 0.85, 1)), (1.00, (0.95, 0.95, 0.95, 1))])
roughness = mix(0.10, wetness, grain)


def render(value, filename, raw=False):
    put(emission.inputs["Color"], value)
    scene.view_settings.view_transform = "Raw" if raw else "Standard"
    scene.render.filepath = str(TEX_OUT / filename)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(scene.render.filepath, check_existing=False)
    if raw:
        image.colorspace_settings.name = "Non-Color"
    pixels = np.empty(TEX_W * TEX_H * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return image, pixels.reshape(TEX_H, TEX_W, 4)


def save_pixels(name, pixels, raw=False):
    image = bpy.data.images.new(name, width=TEX_W, height=TEX_H, alpha=True)
    if raw:
        image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw = str(TEX_OUT / name)
    image.file_format = "PNG"
    image.save()


albedo_image, albedo = render(color, "shore_band_albedo.png")
height_image, height_pixels = render(height, "shore_band_height.png", raw=True)
render(roughness, "shore_band_roughness.png", raw=True)

surface = height_pixels[:, :, 0]
dx = (np.roll(surface, -1, axis=1) - np.roll(surface, 1, axis=1)) * 2.4
dy = (np.roll(surface, -1, axis=0) - np.roll(surface, 1, axis=0)) * 2.4
# Non-periodic in V: keep edge rows flat so the strip border does not wrap.
dx[0, :] = 0.0
dx[-1, :] = 0.0
dy[0, :] = 0.0
dy[-1, :] = 0.0
normals = np.stack([-dx, -dy, np.ones_like(dx)], axis=2)
normals /= np.linalg.norm(normals, axis=2, keepdims=True)
rgba = np.ones_like(height_pixels)
rgba[:, :, :3] = normals * 0.5 + 0.5
save_pixels("shore_band_normal.png", rgba, raw=True)

# Alpha: opaque through the wet band, feather out over the last ~12% on the
# land side so the strip dissolves into the terrain instead of a hard edge.
rows = np.linspace(0.0, 1.0, TEX_H, dtype=np.float32)[:, None]
alpha = np.clip((1.0 - rows) / 0.14, 0.0, 1.0)
alpha = np.broadcast_to(alpha, (TEX_H, TEX_W)).copy()
# Keep it fully opaque through most of the strip.
alpha[rows.ravel() < 0.86, :] = 1.0
albedo[:, :, 3] = alpha
albedo_image.pixels.foreach_set(albedo.astype(np.float32).ravel())
albedo_image.save()
print("SHORE_TEXTURES_COMPLETE", flush=True)


# ---------------------------------------------------------------------------
# Shore props -> GLB
# ---------------------------------------------------------------------------
for obj in list(scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for mat in list(bpy.data.materials):
    bpy.data.materials.remove(mat)


def prop_material(name, color, rough=0.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


WOOD = prop_material("ShoreWood", (0.10, 0.085, 0.065), 0.92)
WOOD_LIGHT = prop_material("ShoreWoodPale", (0.16, 0.14, 0.115), 0.95)
STONE_GRAY = prop_material("ShoreStoneGray", (0.085, 0.082, 0.075), 0.88)
STONE_TAN = prop_material("ShoreStoneTan", (0.115, 0.10, 0.078), 0.90)
STONE_DARK = prop_material("ShoreStoneDark", (0.055, 0.052, 0.048), 0.85)


def tapered_log(name, length, r0, r1, bend, stubs, material, seed):
    """A weathered log lying on its side: bent tapered cylinder + stubs."""
    rng = np.random.default_rng(seed)
    rings = 14
    sides = 10
    verts = []
    faces = []
    for i in range(rings + 1):
        t = i / rings
        cx = (t - 0.5) * length
        radius = r0 + (r1 - r0) * t
        # Gentle S-bend + droop so it reads as driftwood, not lumber.
        cy = bend * math.sin(t * math.pi) + rng.uniform(-0.008, 0.008)
        cz = bend * 0.6 * math.sin(t * math.tau * 0.5 + 0.6)
        for j in range(sides):
            a = j / sides * math.tau
            wobble = 1.0 + rng.uniform(-0.10, 0.10)
            verts.append((cx, cy + math.cos(a) * radius * wobble,
                          cz + math.sin(a) * radius * wobble))
    for i in range(rings):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = (i + 1) * sides + (j + 1) % sides
            d = (i + 1) * sides + j
            faces.append((a, b, c, d))
    faces.append(tuple(reversed(range(sides))))
    base = rings * sides
    faces.append(tuple(base + j for j in range(sides)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    obj.data.materials.append(material)
    # Broken branch stubs.
    for k in range(stubs):
        t = rng.uniform(0.25, 0.75)
        a = rng.uniform(0.4, math.pi - 0.4)
        stub_len = rng.uniform(0.06, 0.16)
        stub_r = rng.uniform(0.015, 0.035)
        cx = (t - 0.5) * length
        cy = bend * math.sin(t * math.pi)
        bpy.ops.mesh.primitive_cone_add(radius1=stub_r, radius2=stub_r * 0.4,
                                        depth=stub_len, vertices=6)
        stub = bpy.context.object
        stub.name = "%s_stub%d" % (name, k)
        stub.location = (cx, cy + math.cos(a) * 0.05, math.sin(a) * 0.05)
        stub.rotation_euler = (a - math.pi * 0.5, rng.uniform(-0.4, 0.4), math.pi * 0.5)
        stub.data.materials.append(material)
        bpy.ops.object.select_all(action="DESELECT")
        stub.select_set(True)
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.join()
    bpy.ops.object.shade_smooth()
    return obj


def flat_stone(name, radius, squash, material, seed):
    rng = np.random.default_rng(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=radius)
    obj = bpy.context.object
    obj.name = name
    for vert in obj.data.vertices:
        vert.co.z *= squash
        n = 1.0 + rng.uniform(-0.14, 0.14)
        vert.co.x *= n
        vert.co.y *= 1.0 + rng.uniform(-0.14, 0.14)
    obj.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    # Auto-smooth keeps the silhouette round but the broad faces slightly
    # faceted — real water-worn stones are not perfect spheres.
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def pebble_patch(name, count, spread, seed):
    rng = np.random.default_rng(seed)
    parts = []
    mats = [STONE_GRAY, STONE_TAN, STONE_DARK]
    for i in range(count):
        r = rng.uniform(0.03, 0.09)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r)
        p = bpy.context.object
        p.scale = (rng.uniform(0.8, 1.4), rng.uniform(0.8, 1.4), rng.uniform(0.3, 0.55))
        p.location = (rng.uniform(-spread, spread), rng.uniform(-spread, spread), r * 0.22)
        p.rotation_euler = (rng.uniform(0, math.pi), rng.uniform(0, math.pi), 0)
        p.data.materials.append(mats[i % len(mats)])
        parts.append(p)
    # Bake each pebble's transform into its mesh first — join() re-expresses
    # everything in the active object's frame, so a rotated active part would
    # tilt the whole patch (it exported standing upright).
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    parts[0].name = name
    bpy.ops.object.shade_smooth()
    return parts[0]


def export_glb(obj, filename):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(PROP_OUT / filename),
        use_selection=True,
        export_yup=True,
        export_apply=True,
    )
    print("SHORE_PROP_EXPORTED", filename, flush=True)


# Blender is Z-up; props are modeled lying on Z and export converts to Y-up.
log_a = tapered_log("DriftwoodA", 1.7, 0.10, 0.045, 0.10, 2, WOOD, 11)
log_a.location.z = 0.07
export_glb(log_a, "shore_driftwood_a.glb")
bpy.data.objects.remove(log_a, do_unlink=True)

log_b = tapered_log("DriftwoodB", 1.1, 0.13, 0.07, -0.12, 3, WOOD_LIGHT, 23)
log_b.location.z = 0.09
export_glb(log_b, "shore_driftwood_b.glb")
bpy.data.objects.remove(log_b, do_unlink=True)

stone_a = flat_stone("FlatStoneA", 0.20, 0.26, STONE_GRAY, 5)
export_glb(stone_a, "shore_flatstone_a.glb")
bpy.data.objects.remove(stone_a, do_unlink=True)

stone_b = flat_stone("FlatStoneB", 0.14, 0.34, STONE_TAN, 7)
export_glb(stone_b, "shore_flatstone_b.glb")
bpy.data.objects.remove(stone_b, do_unlink=True)

stone_c = flat_stone("FlatStoneC", 0.28, 0.18, STONE_DARK, 9)
export_glb(stone_c, "shore_flatstone_c.glb")
bpy.data.objects.remove(stone_c, do_unlink=True)

patch = pebble_patch("PebblePatch", 14, 0.55, 13)
export_glb(patch, "shore_pebbles_a.glb")
bpy.data.objects.remove(patch, do_unlink=True)

bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "work" / "shore_assets.blend"))
print("SHORE_ASSETS_COMPLETE", flush=True)
