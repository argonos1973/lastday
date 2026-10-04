"""Composite a military ripstop weave + grime detail pass into the flat garment
albedos (soldier uniform shared by every military variant, both camo maps and
the gloves). The soldier meshes tint `albedo_texture * albedo_color`, so the
detail must stay multiply-friendly: mostly near-white luminance with darker
weave lines and grime patches. A matching micro-bump is blended into the
soldier height map so the cloth relief catches the parallax pass.

Usage:
    blender --background --factory-startup --python tools/blender/improve_military_textures.py -- --size 2048
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--size", type=int, default=2048)
parser.add_argument("--only", type=str, default="",
                    help="Comma-separated albedo basenames to composite; empty = all")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
ONLY = {s.strip() for s in args.only.split(",") if s.strip()}
OUT = ROOT / "assets/textures/clothing"
SIZE = args.size

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.use_denoising = False
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.view_settings.view_transform = "Raw"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
for obj in scene.objects:
    obj.hide_render = True
bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.object
camera_data = bpy.data.cameras.new("ClothTextureCamera")
camera = bpy.data.objects.new("ClothTextureCamera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0, 0, 3)
camera_data.type = "ORTHO"
camera_data.ortho_scale = 2
scene.camera = camera

material = bpy.data.materials.new("RipstopDetail")
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


def calc(operation, a, b=0):
    item = node("ShaderNodeMath", operation=operation)
    put(item.inputs[0], a)
    if not isinstance(b, bpy.types.NodeSocket):
        item.inputs[1].default_value = b
    else:
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
# Periodic coordinates so every noise sample tiles seamlessly.
combine = node("ShaderNodeCombineXYZ")
put(combine.inputs[0], calc("COSINE", calc("MULTIPLY", u, math.tau)))
put(combine.inputs[1], calc("SINE", calc("MULTIPLY", u, math.tau)))
put(combine.inputs[2], calc("COSINE", calc("MULTIPLY", v, math.tau)))
periodic = combine.outputs[0]
fourth = calc("SINE", calc("MULTIPLY", v, math.tau))


def noise(scale, detail=4, offset=0.0):
    item = node("ShaderNodeTexNoise", noise_dimensions="4D")
    put(item.inputs["Vector"], periodic)
    put(item.inputs["W"], calc("ADD", fourth, offset))
    item.inputs["Scale"].default_value = scale
    item.inputs["Detail"].default_value = detail
    item.inputs["Roughness"].default_value = 0.72
    return item.outputs["Fac"]


def wave(vector, scale, distortion=0.0, bands="X", profile="SIN"):
    item = node("ShaderNodeTexWave", wave_type="BANDS", bands_direction=bands, wave_profile=profile)
    put(item.inputs["Vector"], vector)
    item.inputs["Scale"].default_value = scale
    item.inputs["Distortion"].default_value = distortion
    if distortion > 0.0:
        item.inputs["Detail"].default_value = 2.0
        item.inputs["Detail Scale"].default_value = 1.5
    return item.outputs["Color"]


def render(value, name):
    put(emission.inputs["Color"], value)
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(scene.render.filepath, check_existing=False)
    image.colorspace_settings.name = "Non-Color"
    pixels = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return pixels.reshape(SIZE, SIZE, 4)


# --- Ripstop detail: fine cross-hatch grid + broad grime blotches + wear ----
# Ripstop = thin reinforcement threads every few mm over a plain weave: two
# tight square waves give the micro grid; a softer weave fills between.
warp = wave(uv, 240, 3.0, "X")
weft = wave(uv, 240, 3.0, "Y")
base_weave = calc("MAXIMUM", warp, weft)
grid_x = wave(uv, 34, 1.5, "X", "SIN")
grid_y = wave(uv, 34, 1.5, "Y", "SIN")
grid = calc("MINIMUM", calc("MULTIPLY", grid_x, grid_y), 1.0)
fiber = noise(120, 3, 11.3)
grime = noise(3.5, 5, 4.7)
wear = noise(7.0, 4, 8.9)

# Detail luminance: 1.0 neutral, darker inside weave grooves/grime.
# weave groove darkening ~0.88, ripstop squares slightly darker ~0.94,
# grime patches down to ~0.72, worn highlights up to ~1.06.
detail = ramp(base_weave, [(0.35, (0.88, 0.88, 0.88)), (0.75, (1.0, 1.0, 1.0))])
detail = mix(0.35, detail, ramp(grid, [(0.45, (0.93, 0.93, 0.93)), (0.8, (1.0, 1.0, 1.0))]), "MULTIPLY")
detail = mix(0.5, detail, ramp(fiber, [(0.3, (0.94, 0.94, 0.94)), (0.7, (1.02, 1.02, 1.02))]), "MULTIPLY")
detail = mix(0.55, detail, ramp(grime, [(0.55, (0.72, 0.72, 0.72)), (0.85, (1.0, 1.0, 1.0))]), "MULTIPLY")
detail = mix(0.30, detail, ramp(wear, [(0.35, (0.9, 0.9, 0.9)), (0.7, (1.06, 1.06, 1.06))]), "MULTIPLY")

detail_px = render(detail, "_military_detail_tmp.png")
lum = detail_px[..., :3].mean(axis=2)

def composite(name, strength):
    src_path = OUT / name
    src = bpy.data.images.load(str(src_path), check_existing=False)
    src.colorspace_settings.name = "sRGB"
    px = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    if src.size[0] != SIZE or src.size[1] != SIZE:
        tmp = np.empty(src.size[0] * src.size[1] * 4, dtype=np.float32)
        src.pixels.foreach_get(tmp)
        arr = tmp.reshape(src.size[1], src.size[0], 4)
        # Resize via image scale (numpy nearest is fine for a multiply map)
        yi = (np.arange(SIZE) * src.size[1] / SIZE).astype(int)
        xi = (np.arange(SIZE) * src.size[0] / SIZE).astype(int)
        arr = arr[np.ix_(yi, xi)]
        px = arr.reshape(SIZE * SIZE * 4)
    else:
        src.pixels.foreach_get(px)
    base = px.reshape(SIZE, SIZE, 4)
    factor = 1.0 + (lum - 1.0) * strength
    base[..., :3] = np.clip(base[..., :3] * factor[..., None], 0.0, 1.0)
    out = bpy.data.images.new(name, width=SIZE, height=SIZE, alpha=True)
    out.pixels.foreach_set(base.astype(np.float32).ravel())
    out.filepath_raw = str(src_path)
    out.file_format = "PNG"
    out.save()
    print("composited", name, "strength", strength)

# Soldier uniform: strongest weave (it carries every tinted variant).
if not ONLY or "garment_soldier_albedo.png" in ONLY:
    composite("garment_soldier_albedo.png", 1.0)
# Camo maps share the soldier mesh — same weave keeps the sets consistent.
if not ONLY or "camouflage_woodland.png" in ONLY:
    composite("camouflage_woodland.png", 0.9)
if not ONLY or "camouflage_desert.png" in ONLY:
    composite("camouflage_desert.png", 0.9)
# Gloves get a lighter pass; their leather grain already reads.
if not ONLY or "garment_gloves_albedo.png" in ONLY:
    composite("garment_gloves_albedo.png", 0.5)
# Micro height: add the weave into the soldier height map for parallax relief.
if ONLY and "garment_soldier_height.png" not in ONLY:
    pass
else:
    height_path = OUT / "garment_soldier_height.png"
    himg = bpy.data.images.load(str(height_path), check_existing=False)
    himg.colorspace_settings.name = "Non-Color"
    hpx = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    himg.pixels.foreach_get(hpx)
    harr = hpx.reshape(SIZE, SIZE, 4)
    harr[..., :3] = np.clip(harr[..., :3] + (lum[..., None] - 1.0) * 0.35, 0.0, 1.0)
    hout = bpy.data.images.new("garment_soldier_height", width=SIZE, height=SIZE, alpha=True)
    hout.colorspace_settings.name = "Non-Color"
    hout.pixels.foreach_set(harr.astype(np.float32).ravel())
    hout.filepath_raw = str(height_path)
    hout.file_format = "PNG"
    hout.save()
    print("composited garment_soldier_height.png micro-bump")

# Preview swatch for eyeballing the detail map.
swatch = bpy.data.images.new("military_detail_preview", width=SIZE, height=SIZE, alpha=True)
swatch.pixels.foreach_set(detail_px.astype(np.float32).ravel())
swatch.filepath_raw = "/tmp/military_detail_preview.png"
swatch.file_format = "PNG"
swatch.save()
(OUT / "_military_detail_tmp.png").unlink(missing_ok=True)
print("DONE")
