import argparse
import math
from pathlib import Path
import sys

import bpy
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--size", type=int, default=1024)
parser.add_argument("--only", default="")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
OUT = ROOT / "assets/textures/clothing"
OUT.mkdir(parents=True, exist_ok=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.use_denoising = False
scene.render.resolution_x = args.size
scene.render.resolution_y = args.size
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.image_settings.color_depth = "8"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"
scene.view_settings.exposure = 0
scene.view_settings.gamma = 1
for obj in scene.objects:
    obj.hide_render = True
bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.object
plane.name = "ClothTextureBakeSurface"
camera_data = bpy.data.cameras.new("ClothTextureCamera")
camera = bpy.data.objects.new("ClothTextureCamera", camera_data)
scene.collection.objects.link(camera)
camera.location = (0, 0, 3)
camera_data.type = "ORTHO"
camera_data.ortho_scale = 2
scene.camera = camera


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


def noise(scale, detail=4, offset=0):
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


def mapping(vector, rotation_z=0.0, scale=(1, 1, 1)):
    item = node("ShaderNodeMapping")
    put(item.inputs["Vector"], vector)
    item.inputs["Rotation"].default_value = (0, 0, rotation_z)
    item.inputs["Scale"].default_value = (*scale, 1) if len(scale) == 2 else scale
    return item.outputs["Vector"]


def render(value, filename, raw=False):
    put(emission.inputs["Color"], value)
    scene.view_settings.view_transform = "Raw" if raw else "Standard"
    scene.render.filepath = str(OUT / filename)
    bpy.ops.render.render(write_still=True)
    image = bpy.data.images.load(scene.render.filepath, check_existing=False)
    if raw:
        image.colorspace_settings.name = "Non-Color"
    pixels = np.empty(args.size * args.size * 4, dtype=np.float32)
    image.pixels.foreach_get(pixels)
    return image, pixels.reshape(args.size, args.size, 4)


def save_pixels(name, pixels, raw=False):
    image = bpy.data.images.new(name, width=args.size, height=args.size, alpha=True)
    if raw:
        image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(pixels.astype(np.float32).ravel())
    image.filepath_raw = str(OUT / name)
    image.file_format = "PNG"
    image.save()


for index, name in enumerate(["jersey", "denim", "leather"]):
    if args.only and name not in args.only.split(","):
        continue
    material = bpy.data.materials.new("Cloth_" + name)
    material.use_nodes = True
    tree = material.node_tree
    plane.data.materials.clear()
    plane.data.materials.append(material)
    output = tree.nodes.get("Material Output")
    emission = node("ShaderNodeEmission")
    tree.links.new(emission.outputs[0], output.inputs["Surface"])
    uv = node("ShaderNodeTexCoord").outputs["UV"]
    split = node("ShaderNodeSeparateXYZ")
    put(split.inputs[0], uv)
    u, v = split.outputs[0], split.outputs[1]
    combine = node("ShaderNodeCombineXYZ")
    put(combine.inputs[0], calc("COSINE", calc("MULTIPLY", u, math.tau)))
    put(combine.inputs[1], calc("SINE", calc("MULTIPLY", u, math.tau)))
    put(combine.inputs[2], calc("COSINE", calc("MULTIPLY", v, math.tau)))
    periodic = combine.outputs[0]
    fourth = calc("SINE", calc("MULTIPLY", v, math.tau))
    broad = noise(2.2, 4, index * 0.9)
    fiber = noise(95, 3)
    medium = noise(14, 4)
    if name == "jersey":
        # Plain-knit weave: two slightly distorted thread waves; whichever
        # thread rides on top dominates the height.
        warp = wave(uv, 110, 4.0, "X")
        weft = wave(uv, 110, 4.0, "Y")
        weave = calc("MAXIMUM", warp, weft)
        rows = wave(mapping(uv, scale=(1.0, 55.0)), 1.0, 2.0, "X", "SIN")
        height = mix(0.30, weave, fiber)
        height = mix(0.22, height, rows)
        color = ramp(height, [(0.25, (0.72, 0.71, 0.69)), (0.8, (0.96, 0.95, 0.93))])
        stains = ramp(broad, [(0.68, (0.78, 0.77, 0.74)), (1.0, (1, 1, 1))])
        color = mix(0.5, color, stains, "MULTIPLY")
        roughness = mix(0.25, (0.94, 0.94, 0.94, 1), fiber)
    elif name == "denim":
        # Twill: diagonal ribs over a finer weave.
        warp = wave(uv, 130, 3.0, "X")
        weft = wave(uv, 130, 3.0, "Y")
        weave = calc("MAXIMUM", warp, weft)
        twill = wave(mapping(uv, rotation_z=math.radians(45)), 26, 2.5, "X", "SIN")
        height = mix(0.35, weave, fiber)
        height = mix(0.18, height, twill)
        color = ramp(height, [(0.2, (0.70, 0.70, 0.72)), (0.8, (0.95, 0.95, 0.94))])
        wear = ramp(noise(0.9, 3, 4.4), [(0.30, (0.84, 0.84, 0.84)), (0.62, (1, 1, 1))])
        color = mix(0.55, color, wear, "MULTIPLY")
        roughness = mix(0.3, (0.88, 0.88, 0.88, 1), fiber)
    else:
        # Leather: pebbled grain cells with a few long creases.
        cells = node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", distance="EUCLIDEAN", feature="DISTANCE_TO_EDGE")
        put(cells.inputs["Vector"], periodic)
        put(cells.inputs["W"], calc("ADD", fourth, 7.7))
        cells.inputs["Scale"].default_value = 30.0
        pebble = ramp(cells.outputs["Distance"], [(0.012, (1, 1, 1)), (0.05, (0.25, 0.25, 0.25))])
        creases_src = node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", feature="DISTANCE_TO_EDGE")
        put(creases_src.inputs["Vector"], periodic)
        put(creases_src.inputs["W"], fourth)
        creases_src.inputs["Scale"].default_value = 5.0
        crease = ramp(creases_src.outputs["Distance"], [(0.004, (0, 0, 0)), (0.02, (1, 1, 1))])
        height = mix(0.4, pebble, fiber)
        height = calc("MULTIPLY", height, mix(0.75, (1, 1, 1, 1), crease))
        color = ramp(height, [(0.15, (0.62, 0.61, 0.59)), (0.85, (0.92, 0.91, 0.89))])
        color = mix(0.4, color, ramp(medium, [(0.3, (0.86, 0.85, 0.83)), (0.7, (1, 1, 1))]), "MULTIPLY")
        roughness = mix(0.45, (0.52, 0.52, 0.52, 1), (0.74, 0.74, 0.74, 1))
        roughness = calc("MULTIPLY", roughness, mix(0.3, (1, 1, 1, 1), crease))
    prefix = "cloth_" + name
    albedo_image, albedo = render(color, prefix + "_albedo.png")
    height_image, height_pixels = render(height, prefix + "_height.png", raw=True)
    render(roughness, prefix + "_roughness.png", raw=True)
    surface = height_pixels[:, :, 0]
    dx = (np.roll(surface, -1, axis=1) - np.roll(surface, 1, axis=1)) * 2.2
    dy = (np.roll(surface, -1, axis=0) - np.roll(surface, 1, axis=0)) * 2.2
    normals = np.stack([-dx, -dy, np.ones_like(dx)], axis=2)
    normals /= np.linalg.norm(normals, axis=2, keepdims=True)
    rgba = np.ones_like(height_pixels)
    rgba[:, :, :3] = normals * 0.5 + 0.5
    save_pixels(prefix + "_normal.png", rgba, raw=True)
    material["texture_prefix"] = prefix
    print("CLOTH_TEXTURE_READY", name, flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "work/cloth_materials.blend"))
print("CLOTH_TEXTURES_COMPLETE", flush=True)
