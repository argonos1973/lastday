"""Generate and apply a fabric-preserving woodland camouflage to the fishing hat."""
import bpy
import json
import math
import os
import random
import sys
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
MODEL = os.path.join(ROOT, "assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf")
SOURCE = os.path.join(ROOT, "assets/external/polyhaven/fishermans_hat/textures/fishermans_hat_diff_1k.jpg")
OUTPUT = os.path.join(ROOT, "assets/external/polyhaven/fishermans_hat/textures/fishermans_hat_camo_1k.png")
BLEND = os.path.join(ROOT, "outputs/fishermans_hat_camouflage.blend")
PREVIEW = os.path.join(ROOT, "outputs/fishermans_hat_camouflage.png")
SIZE = 1024
CELLS = 22

# Deterministic, seamless Voronoi woodland patches. The low-frequency warp
# bends cell edges into the irregular, broken shapes of printed field fabric.
rng = random.Random(9082026)
centers = {}
for y in range(-2, CELLS + 2):
    for x in range(-2, CELLS + 2):
        centers[(x, y)] = (x + rng.uniform(0.18, 0.82), y + rng.uniform(0.18, 0.82), rng.random())
warp_size = 28
warp_rng = random.Random(1947)
warp = [[(warp_rng.random() - 0.5) * 0.62 for _ in range(warp_size)] for _ in range(warp_size)]

def smooth_noise(u, v):
    x = u * warp_size
    y = v * warp_size
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx = fx * fx * (3.0 - 2.0 * fx)
    fy = fy * fy * (3.0 - 2.0 * fy)
    a = warp[iy % warp_size][ix % warp_size]
    b = warp[iy % warp_size][(ix + 1) % warp_size]
    c = warp[(iy + 1) % warp_size][ix % warp_size]
    d = warp[(iy + 1) % warp_size][(ix + 1) % warp_size]
    return (a * (1.0 - fx) + b * fx) * (1.0 - fy) + (c * (1.0 - fx) + d * fx) * fy

palette = [
    (0.14, 0.19, 0.085),  # olive green
    (0.075, 0.12, 0.065), # deep forest green
    (0.25, 0.24, 0.13),  # muted khaki
    (0.19, 0.12, 0.075),  # earth brown
    (0.31, 0.29, 0.18),  # faded field tan
]
source = bpy.data.images.load(SOURCE, check_existing=False)
source_pixels = list(source.pixels[:])
out = bpy.data.images.new("Sombrero pescador · camuflaje woodland", width=SIZE, height=SIZE, alpha=False, float_buffer=False)
pixels = [0.0] * (SIZE * SIZE * 4)
for py in range(SIZE):
    v = py / SIZE
    for px in range(SIZE):
        u = px / SIZE
        gx = (u + smooth_noise(u, v) * 0.047) * CELLS
        gy = (v + smooth_noise(v + 0.371, u + 0.619) * 0.047) * CELLS
        cx, cy = math.floor(gx), math.floor(gy)
        best = None
        for sy in range(cy - 1, cy + 2):
            for sx in range(cx - 1, cx + 2):
                seed = centers[(sx, sy)]
                dx, dy = gx - seed[0], gy - seed[1]
                dist = dx * dx + dy * dy
                if best is None or dist < best[0]:
                    best = (dist, seed[2])
        roll = best[1]
        color = palette[0] if roll < 0.37 else palette[1] if roll < 0.57 else palette[2] if roll < 0.78 else palette[3] if roll < 0.94 else palette[4]
        si = (py * SIZE + px) * 4
        sr = source_pixels[si]
        sg = source_pixels[si + 1]
        sb = source_pixels[si + 2]
        lum = 0.2126 * sr + 0.7152 * sg + 0.0722 * sb
        # Preserve subtle fabric shading, stitch lines, and wear from the original scan.
        shade = 0.91 + max(-0.13, min(0.13, (lum - 0.49) * 0.48))
        for channel in range(3):
            pixels[si + channel] = min(1.0, max(0.0, color[channel] * shade))
        pixels[si + 3] = 1.0
out.pixels[:] = pixels
out.file_format = "PNG"
out.filepath_raw = OUTPUT
out.save()

# Replace the diffuse texture through Blender's material datablock and save an
# editable project. The game's glTF references the same PNG in its base-color slot.
for obj in list(bpy.context.scene.objects):
    bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=MODEL)
for mat in bpy.data.materials:
    if mat.name.startswith("fishermans_hat"):
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        principled = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
        if principled is None:
            continue
        image_node = next((n for n in nodes if n.type == "TEX_IMAGE" and n.image and "diff" in n.image.name), None)
        if image_node is None:
            image_node = nodes.new("ShaderNodeTexImage")
        image_node.image = out
        image_node.label = "Woodland camouflage, baked in Blender"
        uv = next((n for n in nodes if n.type == "TEX_COORD"), None)
        if uv is None:
            uv = nodes.new("ShaderNodeTexCoord")
        links = mat.node_tree.links
        links.new(uv.outputs["UV"], image_node.inputs["Vector"])
        links.new(image_node.outputs["Color"], principled.inputs["Base Color"])
        mat.diffuse_color = (*palette[0], 1.0)

# Point the existing glTF baseColorTexture image at the generated Blender PNG.
with open(MODEL, "r", encoding="utf-8") as f:
    gltf = json.load(f)
gltf["images"][1]["uri"] = "textures/fishermans_hat_camo_1k.png"
with open(MODEL, "w", encoding="utf-8") as f:
    json.dump(gltf, f, ensure_ascii=False, indent=2)

# Simple studio preview with the actual imported hat mesh and material.
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = PREVIEW
scene.render.film_transparent = False
scene.world.color = (0.16, 0.18, 0.20)
for area in bpy.context.screen.areas if bpy.context.screen else []:
    if area.type == "VIEW_3D":
        area.spaces.active.region_3d.view_distance = 2.4
        area.spaces.active.region_3d.view_location = (0.0, 0.0, 0.0)
# Camera framing from mesh bounds.
meshes = [o for o in scene.objects if o.type == "MESH"]
if meshes:
    bpy.context.view_layer.update()
    corners = [o.matrix_world @ Vector(corner) for o in meshes for corner in o.bound_box]
    center = sum(corners, Vector()) / len(corners)
    radius = max((p - center).length for p in corners)
    camera_data = bpy.data.cameras.new("Hat Preview Camera")
    camera = bpy.data.objects.new("Hat Preview Camera", camera_data)
    scene.collection.objects.link(camera)
    camera.location = center + Vector((2.5, 2.2, 3.0)) * max(radius, 0.2)
    camera.rotation_euler = (center - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.lens = 52
    scene.camera = camera
    light_data = bpy.data.lights.new("Softbox", "AREA")
    light = bpy.data.objects.new("Softbox", light_data)
    scene.collection.objects.link(light)
    light.location = center + Vector((0.5, 3.0, 1.5)) * max(radius, 0.3)
    light_data.energy = 250
    light_data.shape = "DISK"
    light_data.size = 3.0
    light.rotation_euler = (center - light.location).to_track_quat("-Z", "Y").to_euler()
    bpy.ops.render.render(write_still=True)
os.makedirs(os.path.dirname(BLEND), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
print("CAMOUFLAGE_TEXTURE=" + OUTPUT)
print("CAMOUFLAGE_MODEL=" + MODEL)
print("CAMOUFLAGE_PREVIEW=" + PREVIEW)
print("BLENDER_PROJECT=" + BLEND)
