import argparse
import math
from pathlib import Path
import sys

import bpy
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--size", type=int, default=2048)
parser.add_argument("--only", default="")
parser.add_argument("--import-character", action="store_true")
parser.add_argument("--save-blend", default="")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
OUT = ROOT / "assets/textures/clothing"
OUT.mkdir(parents=True, exist_ok=True)
if args.import_character:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/characters/adapted/player_with_clothes.glb"))
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 8
scene.cycles.use_denoising = False
scene.render.bake.margin = 24
scene.view_settings.view_transform = "Standard"

GARMENTS = [
    {"obj": "Tops", "diffuse": "Remy_Top_Diffuse", "normal": "Remy_Top_Normal", "prefix": "garment_top", "kind": "jersey"},
    {"obj": "Bottoms", "diffuse": "Remy_Bottom_Diffuse", "normal": "Remy_Bottom_Normal", "prefix": "garment_bottom", "kind": "denim"},
    {"obj": "Shoes", "diffuse": "Remy_Shoes_Diffuse", "normal": "Remy_Shoes_Normal", "prefix": "garment_shoes", "kind": "leather"},
    # All soldier_* meshes share material Soldier_body1.001, hence one UV atlas:
    # bake them together so torso (jacket), hands and feet also get coverage.
    {"obj": "soldier_legs", "objs": ["soldier_legs", "soldier_torso", "soldier_hands", "soldier_feet"], "diffuse": "Soldier_Body_diffuse", "normal": "Soldier_Body_normal", "prefix": "garment_soldier", "kind": "denim"},
    {"obj": "cloth_hands", "diffuse": None, "normal": None, "prefix": "garment_gloves", "kind": "leather"},
    {"obj": "cloth_feet", "diffuse": None, "normal": None, "prefix": "garment_boots", "kind": "leather"},
]


def node(tree, kind, **properties):
    item = tree.nodes.new(kind)
    for key, value in properties.items():
        setattr(item, key, value)
    return item


def put(tree, socket, value):
    if isinstance(value, bpy.types.NodeSocket):
        tree.links.new(value, socket)
    else:
        socket.default_value = value


def calc(tree, operation, a, b=0):
    item = node(tree, "ShaderNodeMath", operation=operation)
    put(tree, item.inputs[0], a)
    put(tree, item.inputs[1], b)
    return item.outputs[0]


def ramp(tree, value, stops):
    item = node(tree, "ShaderNodeValToRGB")
    item.color_ramp.interpolation = "EASE"
    for i, (position, color) in enumerate(stops):
        entry = item.color_ramp.elements[i] if i < 2 else item.color_ramp.elements.new(position)
        entry.position = position
        entry.color = (*color, 1) if len(color) == 3 else color
    put(tree, item.inputs[0], value)
    return item.outputs[0]


def mix(tree, factor, a, b, mode="MIX"):
    item = node(tree, "ShaderNodeMixRGB", blend_type=mode)
    put(tree, item.inputs[0], factor)
    put(tree, item.inputs[1], a)
    put(tree, item.inputs[2], b)
    return item.outputs[0]


def noise(tree, vector, scale, detail=4):
    item = node(tree, "ShaderNodeTexNoise")
    put(tree, item.inputs["Vector"], vector)
    item.inputs["Scale"].default_value = scale
    item.inputs["Detail"].default_value = detail
    item.inputs["Roughness"].default_value = 0.72
    return item.outputs["Fac"]


def wave(tree, vector, scale, distortion=0.0, bands="X"):
    item = node(tree, "ShaderNodeTexWave", wave_type="BANDS", bands_direction=bands, wave_profile="SIN")
    put(tree, item.inputs["Vector"], vector)
    item.inputs["Scale"].default_value = scale
    item.inputs["Distortion"].default_value = distortion
    if distortion > 0.0:
        item.inputs["Detail"].default_value = 2.0
    return item.outputs["Color"]


def weave_height(tree, uv, kind):
    fiber = noise(tree, uv, 260, 3)
    if kind == "jersey":
        warp = wave(tree, uv, 150, 3.5, "X")
        weft = wave(tree, uv, 150, 3.5, "Y")
        thread = calc(tree, "MAXIMUM", warp, weft)
        return mix(tree, 0.30, thread, fiber), fiber
    if kind == "denim":
        diag = node(tree, "ShaderNodeMapping")
        put(tree, diag.inputs["Vector"], uv)
        diag.inputs["Rotation"].default_value = (0, 0, math.radians(45))
        warp = wave(tree, uv, 170, 3.0, "X")
        weft = wave(tree, uv, 170, 3.0, "Y")
        thread = calc(tree, "MAXIMUM", warp, weft)
        twill = wave(tree, diag.outputs["Vector"], 34, 2.0, "X")
        height = mix(tree, 0.30, thread, fiber)
        return mix(tree, 0.16, height, twill), fiber
    cells = node(tree, "ShaderNodeTexVoronoi", distance="EUCLIDEAN", feature="DISTANCE_TO_EDGE")
    put(tree, cells.inputs["Vector"], uv)
    cells.inputs["Scale"].default_value = 42.0
    pebble = ramp(tree, cells.outputs["Distance"], [(0.010, (1, 1, 1)), (0.045, (0.22, 0.22, 0.22))])
    return mix(tree, 0.38, pebble, fiber), fiber


def bake_emit(objs, mat, emission_socket, value, target, filename, save=True):
    put(mat.node_tree, emission_socket, value)
    target_node.image = target
    mat.node_tree.nodes.active = target_node
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type="EMIT")
    if save:
        target.filepath_raw = str(OUT / filename)
        target.file_format = "PNG"
        target.save()
    pixels = np.empty(args.size * args.size * 4, dtype=np.float32)
    target.pixels.foreach_get(pixels)
    return pixels.reshape(args.size, args.size, 4)


def high_pass_detail(pixels):
    # Remove the broad shading baked into the source diffuse (belly shadows,
    # knee patches, dark toe caps) while keeping high-frequency detail like
    # seams, pockets and laces. Black bake padding is excluded from the blur.
    h, w = args.size, args.size
    lum = pixels[:, :, :3].mean(axis=2)
    valid = (lum > 0.02).astype(np.float32)
    f = 32
    def coarse_mean(a):
        blocks = a.reshape(h // f, f, w // f, f).mean(axis=(1, 3))
        return np.kron(blocks, np.ones((f, f)))
    blurred = coarse_mean(lum * valid) / np.maximum(coarse_mean(valid), 1e-3)
    detail = np.clip(lum / np.maximum(blurred, 0.05), 0.55, 1.30)
    return np.stack([detail, detail, detail, np.ones_like(detail)], axis=-1).astype(np.float32).reshape(-1, 4)


def load_image_pixels(name):
    img = bpy.data.images.get(name)
    if img is None:
        return None
    img.colorspace_settings.name = "Non-Color"
    w, h = img.size
    pixels = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(pixels)
    return pixels.reshape(h, w, 4), w, h


for garment in GARMENTS:
    if args.only and garment["obj"] not in args.only.split(","):
        continue
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = False
    objs = [bpy.data.objects.get(n) for n in garment.get("objs", [garment["obj"]])]
    objs = [o for o in objs if o is not None and o.type == "MESH"]
    if not objs:
        print("GARMENT_MISSING", garment["obj"], flush=True)
        continue
    material = bpy.data.materials.new("Bake_" + garment["obj"])
    material.use_nodes = True
    for o in objs:
        o.data.materials.clear()
        o.data.materials.append(material)
    tree = material.node_tree
    tree.nodes.clear()
    output = node(tree, "ShaderNodeOutputMaterial")
    emission = node(tree, "ShaderNodeEmission")
    tree.links.new(emission.outputs[0], output.inputs["Surface"])
    uv = node(tree, "ShaderNodeTexCoord").outputs["UV"]
    weave, fiber = weave_height(tree, uv, garment["kind"])
    wear = noise(tree, uv, 2.6, 4)
    wear_mask = ramp(tree, wear, [(0.30, (0.86, 0.85, 0.83)), (0.60, (1, 1, 1))])
    target_node = node(tree, "ShaderNodeTexImage")
    detail_socket = None
    if garment["diffuse"]:
        diffuse_tex = node(tree, "ShaderNodeTexImage")
        diffuse_tex.image = bpy.data.images[garment["diffuse"]]
        lum = node(tree, "ShaderNodeRGBToBW")
        put(tree, lum.inputs[0], diffuse_tex.outputs["Color"])
        # Pre-bake the source luminance, then flatten its broad shading (dirt
        # and contact shadows tint as ugly blotches) and keep only the local
        # contrast of seams, pockets and laces.
        lum_tmp = bpy.data.images.new("lumtmp_" + garment["obj"], width=args.size, height=args.size, alpha=False)
        lum_pixels = bake_emit(objs, material, emission.inputs["Color"], lum.outputs[0], lum_tmp, "_lumtmp.png", save=False)
        bpy.data.images.remove(lum_tmp)
        lum_hp = bpy.data.images.new("lumhp_" + garment["obj"], width=args.size, height=args.size, alpha=False)
        lum_hp.colorspace_settings.name = "Non-Color"
        lum_hp.pixels.foreach_set(high_pass_detail(lum_pixels).ravel())
        detail_tex = node(tree, "ShaderNodeTexImage")
        detail_tex.image = lum_hp
        detail_socket = detail_tex.outputs["Color"]
        base = ramp(tree, detail_socket, [(0.72, (0.66, 0.66, 0.66)), (1.0, (0.88, 0.87, 0.85)), (1.12, (0.95, 0.94, 0.92))])
    else:
        base = ramp(tree, noise(tree, uv, 3.0, 4), [(0.2, (0.80, 0.79, 0.76)), (0.8, (0.93, 0.92, 0.90))])
    weave_shade = ramp(tree, weave, [(0.20, (0.80, 0.80, 0.80)), (0.80, (1, 1, 1))])
    color = mix(tree, 0.20, base, weave_shade, "MULTIPLY")
    color = mix(tree, 0.45, color, wear_mask, "MULTIPLY")
    if detail_socket is not None:
        height = mix(tree, 0.28, weave, detail_socket)
    else:
        height = weave
    height = mix(tree, 0.18, height, fiber)
    roughness = ramp(tree, fiber, [(0.2, (0.48,)*3), (0.8, (0.76,)*3)]) if garment["kind"] == "leather" else ramp(tree, wear, [(0.2, (0.77,)*3), (0.8, (0.96,)*3)])
    # Object-space panels bake into each garment's own UVs, so they follow the rig.
    generated = node(tree, "ShaderNodeTexCoord").outputs["Generated"]
    xyz = node(tree, "ShaderNodeSeparateXYZ")
    put(tree, xyz.inputs[0], generated)
    vertical = xyz.outputs["Y"]
    if garment["obj"] in ["Shoes", "cloth_feet"]:
        # Keep the dark sole only at the bottom strip — a higher threshold
        # swallowed the toe cap and rendered the toes black.
        sole = calc(tree, "LESS_THAN", vertical, 0.09 if garment["obj"] == "Shoes" else 0.08)
        welt = calc(tree, "LESS_THAN", calc(tree, "ABSOLUTE", calc(tree, "SUBTRACT", vertical, 0.11 if garment["obj"] == "Shoes" else 0.10)), 0.013)
        tread = wave(tree, generated, 25, 0, "Z")
        # Light rubber sole — near-black read as a dirt blob once tinted.
        sole_color = mix(tree, 0.52, (0.60, 0.58, 0.52, 1), tread)
        color = mix(tree, sole, color, sole_color)
        color = mix(tree, welt, color, (0.65, 0.62, 0.56, 1))
        roughness = mix(tree, sole, roughness, (0.94,)*3 + (1,))
        height = mix(tree, sole, height, tread)
        height = calc(tree, "ADD", height, calc(tree, "MULTIPLY", welt, 0.25))
    if garment["obj"] == "soldier_legs":
        # Subtle ripstop reinforcement rather than denim on military trousers.
        grid_x = calc(tree, "GREATER_THAN", wave(tree, uv, 38, 0, "X"), 0.93)
        grid_y = calc(tree, "GREATER_THAN", wave(tree, uv, 38, 0, "Y"), 0.93)
        grid = calc(tree, "MAXIMUM", grid_x, grid_y)
        color = mix(tree, calc(tree, "MULTIPLY", grid, 0.09), color, (0.28, 0.28, 0.26, 1))
        height = calc(tree, "ADD", height, calc(tree, "MULTIPLY", grid, 0.15))
    if garment["obj"] == "cloth_hands":
        # Reinforced wrist cuff, preserving individual finger geometry.
        horizontal = xyz.outputs["X"]
        cuff_l = calc(tree, "LESS_THAN", calc(tree, "ABSOLUTE", calc(tree, "SUBTRACT", horizontal, 0.075)), 0.025)
        cuff_r = calc(tree, "LESS_THAN", calc(tree, "ABSOLUTE", calc(tree, "SUBTRACT", horizontal, 0.925)), 0.025)
        cuff = calc(tree, "MAXIMUM", cuff_l, cuff_r)
        color = mix(tree, cuff, color, (0.20, 0.19, 0.17, 1))
        roughness = mix(tree, cuff, roughness, (0.85, 0.85, 0.85, 1))
    target = bpy.data.images.new("bake_" + garment["obj"], width=args.size, height=args.size, alpha=False)
    albedo_pixels = bake_emit(objs, material, emission.inputs["Color"], color, target, garment["prefix"] + "_albedo.png")
    height_pixels = bake_emit(objs, material, emission.inputs["Color"], height, target, garment["prefix"] + "_height.png")
    bake_emit(objs, material, emission.inputs["Color"], roughness, target, garment["prefix"] + "_roughness.png")
    normal_img = bpy.data.images.new("n_" + garment["obj"], width=args.size, height=args.size, alpha=True)
    normal_img.colorspace_settings.name = "Non-Color"
    normal_img.filepath_raw = str(OUT / (garment["prefix"] + "_normal.png"))
    normal_img.file_format = "PNG"
    # Cycles computes tangent normals with the actual UV orientation and margins.
    # This avoids embossed UV seams from differentiating a baked atlas as an image.
    bsdf = node(tree, "ShaderNodeBsdfPrincipled")
    put(tree, bsdf.inputs["Base Color"], color)
    put(tree, bsdf.inputs["Roughness"], roughness)
    bump = node(tree, "ShaderNodeBump")
    put(tree, bump.inputs["Height"], height)
    bump.inputs["Strength"].default_value = 0.25
    bump.inputs["Distance"].default_value = 0.025
    if garment["normal"] and bpy.data.images.get(garment["normal"]):
        original_normal = node(tree, "ShaderNodeTexImage")
        original_normal.image = bpy.data.images[garment["normal"]]
        original_normal.image.colorspace_settings.name = "Non-Color"
        normal_map = node(tree, "ShaderNodeNormalMap")
        put(tree, normal_map.inputs["Color"], original_normal.outputs["Color"])
        put(tree, bump.inputs["Normal"], normal_map.outputs[0])
    put(tree, bsdf.inputs["Normal"], bump.outputs[0])
    put(tree, output.inputs["Surface"], bsdf.outputs[0])
    target_node.image = normal_img
    tree.nodes.active = target_node
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    normal_img.save()
    # Crevice shadows inside pockets, seams and folds read as "real cloth".
    # Hide every other mesh: the skin/body meshes sitting under the garment
    # would otherwise occlude it and bake big dark blotches.
    for other in bpy.data.objects:
        if other.type == "MESH":
            other.hide_render = other not in objs
    ao_img = bpy.data.images.new("ao_" + garment["obj"], width=args.size, height=args.size, alpha=False)
    ao_img.colorspace_settings.name = "Non-Color"
    ao_img.filepath_raw = str(OUT / (garment["prefix"] + "_ao.png"))
    ao_img.file_format = "PNG"
    target_node.image = ao_img
    bpy.ops.object.bake(type="AO", margin=scene.render.bake.margin)
    # Keep crevice shading subtle on tintable clothing, especially dark variants.
    ao_pixels = np.empty(args.size * args.size * 4, dtype=np.float32)
    ao_img.pixels.foreach_get(ao_pixels)
    ao_pixels = ao_pixels.reshape(-1, 4)
    ao_pixels[:, :3] = 0.65 + 0.35 * ao_pixels[:, :3]
    ao_img.pixels.foreach_set(ao_pixels.ravel())
    ao_img.save()
    print("GARMENT_BAKED", garment["obj"], garment["prefix"], flush=True)

print("GARMENTS_COMPLETE", flush=True)
if args.save_blend:
    selected_names = args.only.split(",") if args.only else [g["obj"] for g in GARMENTS]
    for obj in bpy.data.objects:
        if obj.type == "MESH" and obj.name not in selected_names:
            obj.hide_render = True
            obj.hide_set(True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(Path(args.save_blend).resolve()))
