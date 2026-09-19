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
OUT = ROOT / "assets/textures/overgrowth"
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
plane.name = "VillageTextureBakeSurface"
camera_data = bpy.data.cameras.new("VillageTextureCamera")
camera = bpy.data.objects.new("VillageTextureCamera", camera_data)
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


def brick(vector, colors, width=0.5, row=0.22, scale=6):
    item = node("ShaderNodeTexBrick")
    put(item.inputs["Vector"], vector)
    item.inputs["Scale"].default_value = scale
    item.inputs["Brick Width"].default_value = width
    item.inputs["Row Height"].default_value = row
    item.inputs["Mortar Size"].default_value = 0.018
    item.inputs["Mortar Smooth"].default_value = 0.012
    for key, value in zip(["Color1", "Color2", "Mortar"], colors):
        item.inputs[key].default_value = (*value, 1)
    return item.outputs["Color"], item.outputs["Fac"]


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


palettes = {
    "lime": ((0.39, 0.38, 0.34), (0.61, 0.59, 0.53), 0.43),
    "ochre": ((0.36, 0.31, 0.24), (0.57, 0.50, 0.38), 0.45),
    "stone": ((0.33, 0.32, 0.29), (0.51, 0.49, 0.43), 0.58),
    "brick": ((0.38, 0.36, 0.31), (0.58, 0.55, 0.48), 0.49),
}
for index, name in enumerate([*palettes, "slate", "clay", "wood", "base_moss"]):
    if args.only and name not in args.only.split(","):
        continue
    material = bpy.data.materials.new("Village_" + name)
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
    broad = noise(1.4, 5, index * 0.37)
    grain = noise(72, 3)
    medium = noise(9, 5)
    roughness = mix(0.22, (0.86, 0.86, 0.86, 1), grain)
    if name in palettes:
        dark, light, exposed = palettes[name]
        weather = noise(0.38, 2, index * 1.17)
        erosion = calc("ADD", calc("MULTIPLY", noise(0.72, 2, 3.1 + index), 0.93), calc("MULTIPLY", medium, 0.07))
        plaster = ramp(weather, [(0.20, dark), (0.75, light)])
        photo = node("ShaderNodeTexImage")
        photo_path = "concrete_floor_02/concrete_floor_02_diff_4k.jpg" if name in ["lime", "ochre"] else "plaster_brick_01/plaster_brick_01_diff_4k.jpg"
        photo.image = bpy.data.images.load(str(ROOT / "assets/external/textures" / photo_path), check_existing=True)
        put(photo.inputs["Vector"], uv)
        luminance = node("ShaderNodeRGBToBW")
        put(luminance.inputs[0], photo.outputs["Color"])
        photo_finish = ramp(luminance.outputs[0], [(0.07, tuple(c * 0.64 for c in dark)), (0.58, light)])
        plaster = mix(0.82, plaster, photo_finish)
        stone_colors = [(0.24, 0.22, 0.18), (0.34, 0.32, 0.27), (0.19, 0.18, 0.155)]
        if name == "brick":
            stone_colors = [(0.24, 0.135, 0.085), (0.35, 0.235, 0.16), (0.22, 0.21, 0.18)]
        masonry, joints = brick(uv, stone_colors, row=0.25 if name != "brick" else 0.125, scale=4)
        mortar = ramp(medium, [(0.22, (0.20, 0.19, 0.16)), (0.78, (0.34, 0.32, 0.28))])
        concrete = node("ShaderNodeTexImage")
        concrete.image = bpy.data.images.load(str(ROOT / "assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg"), check_existing=True)
        put(concrete.inputs["Vector"], uv)
        mortar = mix(0.72, mortar, concrete.outputs["Color"])
        substrate = mix(0.55 if name in ["stone", "brick"] else 0.10, mortar, masonry)
        chipped = ramp(erosion, [(exposed - 0.006, (1, 1, 1)), (exposed + 0.012, (0, 0, 0))])
        rim = ramp(erosion, [(exposed + 0.012, (0.65, 0.65, 0.65)), (exposed + 0.029, (1, 1, 1))])
        color = mix(chipped, mix(0.28, plaster, rim, "MULTIPLY"), substrate)
        cracks = node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", feature="DISTANCE_TO_EDGE")
        warp = node("ShaderNodeTexNoise", noise_dimensions="4D")
        put(warp.inputs["Vector"], periodic)
        put(warp.inputs["W"], fourth)
        warp.inputs["Scale"].default_value = 4.0
        warp.inputs["Detail"].default_value = 3.0
        amplitude = node("ShaderNodeVectorMath", operation="SCALE")
        put(amplitude.inputs[0], warp.outputs["Color"])
        amplitude.inputs["Scale"].default_value = 0.23
        distorted = node("ShaderNodeVectorMath", operation="ADD")
        put(distorted.inputs[0], periodic)
        put(distorted.inputs[1], amplitude.outputs[0])
        put(cracks.inputs["Vector"], distorted.outputs[0])
        put(cracks.inputs["W"], fourth)
        cracks.inputs["Scale"].default_value = 1.15
        crack_mask = ramp(cracks.outputs["Distance"], [(0.0015, (0.30, 0.30, 0.30)), (0.005, (1, 1, 1))])
        broken_cracks = mix(ramp(noise(1.1, 2, 5.4), [(0.35, (0, 0, 0)), (0.6, (1, 1, 1))]), (1, 1, 1, 1), crack_mask)
        color = mix(0.32, color, broken_cracks, "MULTIPLY")
        color = mix(0.065, color, grain, "MULTIPLY")
        plaster_height = mix(0.12, mix(0.025, (0.66, 0.66, 0.66, 1), grain), luminance.outputs[0])
        height = mix(chipped, plaster_height, mix(0.16, (0.40, 0.40, 0.40, 1), calc("SUBTRACT", 1, joints)))
        height = mix(0.1, height, broken_cracks, "MULTIPLY")
        roughness = mix(chipped, (0.89, 0.89, 0.89, 1), (0.97, 0.97, 0.97, 1))
    elif name in ["slate", "clay"]:
        colors = [(0.085, 0.095, 0.10), (0.22, 0.23, 0.22), (0.027, 0.030, 0.033)] if name == "slate" else [(0.22, 0.095, 0.048), (0.39, 0.20, 0.095), (0.05, 0.03, 0.02)]
        color, joints = brick(uv, colors, width=0.5, row=0.25, scale=4)
        color = mix(0.28, color, medium, "MULTIPLY")
        height = mix(0.12, calc("SUBTRACT", 1, joints), grain)
    elif name == "wood":
        mapping = node("ShaderNodeVectorMath", operation="MULTIPLY")
        put(mapping.inputs[0], uv)
        mapping.inputs[1].default_value = (35, 1.5, 1)
        timber = node("ShaderNodeTexNoise")
        put(timber.inputs["Vector"], mapping.outputs[0])
        timber.inputs["Scale"].default_value = 3
        timber.inputs["Detail"].default_value = 5
        color = ramp(timber.outputs["Fac"], [(0.25, (0.12, 0.105, 0.075)), (0.7, (0.52, 0.49, 0.40))])
        height = mix(0.2, timber.outputs["Fac"], grain)
    else:
        color = ramp(medium, [(0.22, (0.025, 0.038, 0.008)), (0.75, (0.16, 0.19, 0.045))])
        color = mix(0.35, color, grain, "MULTIPLY")
        edge = calc("ADD", 0.12, calc("MULTIPLY", broad, 0.65))
        height = calc("MULTIPLY", calc("SUBTRACT", edge, v), 8)
        height = calc("MINIMUM", calc("MAXIMUM", height, 0), 1)
    prefix = "village_" + name
    albedo_image, albedo = render(color, prefix + "_albedo.png")
    height_image, height_pixels = render(height, prefix + "_height.png", raw=True)
    render(roughness, prefix + "_roughness.png", raw=True)
    surface = height_pixels[:, :, 0]
    dx = (np.roll(surface, -1, axis=1) - np.roll(surface, 1, axis=1)) * 3.0
    dy = (np.roll(surface, -1, axis=0) - np.roll(surface, 1, axis=0)) * 3.0
    normals = np.stack([-dx, -dy, np.ones_like(dx)], axis=2)
    normals /= np.linalg.norm(normals, axis=2, keepdims=True)
    rgba = np.ones_like(height_pixels)
    rgba[:, :, :3] = normals * 0.5 + 0.5
    save_pixels(prefix + "_normal.png", rgba, raw=True)
    if name == "base_moss":
        albedo[:, :, 3] = surface
        albedo_image.pixels.foreach_set(albedo.ravel())
        albedo_image.save()
    material["texture_prefix"] = prefix
    material["moss_free_wall"] = name in palettes
    print("VILLAGE_TEXTURE_READY", name, flush=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "work/village_materials.blend"))
print("VILLAGE_TEXTURES_COMPLETE", flush=True)
