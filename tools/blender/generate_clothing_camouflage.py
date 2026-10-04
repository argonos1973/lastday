"""Bake reusable woodland/desert fabric camouflage in Blender and render the uniform."""
import bpy, bmesh, math, os, random
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
CLOTH_DIR = os.path.join(ROOT, "assets/textures/clothing")
OUT_DIR = os.path.join(ROOT, "outputs")
os.makedirs(CLOTH_DIR, exist_ok=True)
os.makedirs(OUT_DIR, exist_ok=True)
SIZE, CELLS, WARP_SIZE = 2048, 22, 24

# Periodic low-frequency distortion bends the patches into irregular printed shapes.
wr = random.Random(4212)
warp = [[wr.uniform(-0.5, 0.5) for _ in range(WARP_SIZE)] for _ in range(WARP_SIZE)]
def noise(u, v):
    x, y = u * WARP_SIZE, v * WARP_SIZE
    ix, iy = math.floor(x), math.floor(y)
    fx, fy = x - ix, y - iy
    fx, fy = fx*fx*(3-2*fx), fy*fy*(3-2*fy)
    a, b = warp[iy % WARP_SIZE][ix % WARP_SIZE], warp[iy % WARP_SIZE][(ix+1) % WARP_SIZE]
    c, d = warp[(iy+1) % WARP_SIZE][ix % WARP_SIZE], warp[(iy+1) % WARP_SIZE][(ix+1) % WARP_SIZE]
    return (a*(1-fx)+b*fx)*(1-fy)+(c*(1-fx)+d*fx)*fy

variants = {
    "woodland": [(0.20,0.25,0.13), (0.105,0.15,0.085), (0.34,0.32,0.20), (0.24,0.17,0.105), (0.43,0.39,0.25)],
    "desert": [(0.37,0.32,0.19), (0.22,0.20,0.12), (0.53,0.44,0.27), (0.34,0.24,0.14), (0.61,0.53,0.35)],
}
seed_rng = random.Random(9082026)
cell_seeds = {}
for y in range(CELLS):
    for x in range(CELLS):
        cell_seeds[x,y] = (seed_rng.uniform(.2,.8), seed_rng.uniform(.2,.8), seed_rng.random())

def make_image(kind, palette):
    image = bpy.data.images.new("LastDay_%s_Camouflage" % kind, width=SIZE, height=SIZE, alpha=False)
    pixels = [0.0] * (SIZE*SIZE*4)
    for py in range(SIZE):
        v = py / SIZE
        for px in range(SIZE):
            u = px / SIZE
            gx = (u + noise(u,v)*.043) * CELLS
            gy = (v + noise(v+.371,u+.619)*.043) * CELLS
            cx, cy = math.floor(gx), math.floor(gy)
            best_dist, best_roll = 99.0, 0.0
            for sy in range(cy-1, cy+2):
                for sx in range(cx-1, cx+2):
                    ox, oy, roll = cell_seeds[sx % CELLS, sy % CELLS]
                    dx, dy = gx-(sx+ox), gy-(sy+oy)
                    dist = dx*dx + dy*dy
                    if dist < best_dist:
                        best_dist, best_roll = dist, roll
            col = palette[0] if best_roll < .34 else palette[1] if best_roll < .55 else palette[2] if best_roll < .77 else palette[3] if best_roll < .94 else palette[4]
            # Subtle matte-fabric variation; game materials add the woven normal map.
            grain = 0.965 + .035 * noise(u*2.3+.13, v*2.3+.29)
            i = (py*SIZE+px)*4
            pixels[i:i+4] = [min(1,max(0,c*grain)) for c in col] + [1.0]
    image.pixels[:] = pixels
    image.filepath_raw = os.path.join(CLOTH_DIR, "camouflage_%s.png" % kind)
    image.file_format = "PNG"
    image.save()
    return image

woodland = make_image("woodland", variants["woodland"])
desert = make_image("desert", variants["desert"])

# Build a reviewer-ready Blender project using the actual skinned character meshes.
for ob in list(bpy.context.scene.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/characters/adapted/player_with_clothes.glb"))
scene = bpy.context.scene
for obj in scene.objects:
    if obj.type != "MESH":
        continue
    name = obj.name.lower()
    # A complete outfit uses exactly one pair of hands/boots. The source
    # character contains mutually exclusive naked, civilian and military sets.
    visible_parts = {"soldier_torso", "soldier_legs", "soldier_hands", "soldier_feet",
                     "body_torso", "hair", "eyes", "eyelashes"}
    obj.hide_render = name not in visible_parts
    obj.hide_set(obj.hide_render)
    if name == "soldier_legs":
        # Undo the old T-shirt-only tuck (tuck_soldier_legs.py) in this Blender
        # uniform assembly. Its 55% waist was never meant for the field jacket.
        world = obj.matrix_world.copy()
        inverse = world.inverted()
        for vertex in obj.data.vertices:
            point = world @ vertex.co
            if point.z > 1.75:
                weight = min(1.0, (point.z - 1.75) / 0.30)
                factor = 1.0 - 0.45 * weight
                point.x /= factor
                point.y /= factor
                # Tuck the waistband slightly under the jacket around the back
                # and sides as well; only the upper band moves, not the crotch.
                band = max(0.0, min(1.0, (point.z - 1.95) / 0.28))
                point.z += 0.12 * band * band * (3.0 - 2.0 * band)
                vertex.co = inverse @ point
    if name in ("soldier_torso", "soldier_legs"):
        mat = bpy.data.materials.new("Woodland camouflage fabric")
        mat.diffuse_color = (.20,.25,.13,1)
        mat.use_nodes = True
        nodes = mat.node_tree.nodes
        bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Roughness"].default_value = .88
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = woodland
        uv = nodes.new("ShaderNodeTexCoord")
        mat.node_tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        obj.data.materials.clear()
        obj.data.materials.append(mat)

# The game builds HeadMesh from inicio.glb at runtime; the clothing GLB does
# not contain a face. Reproduce that assembly rather than showing floating eyes.
target_rig = next(o for o in scene.objects if o.type == "ARMATURE")
existing = set(bpy.data.objects)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "assets/animations/inicio.glb"))
imported = set(bpy.data.objects) - existing
head = next(o for o in imported if o.type == "MESH" and o.name == "Body")
bpy.context.view_layer.update()
world = head.matrix_world.copy()
bm = bmesh.new()
bm.from_mesh(head.data)
remove = [f for f in bm.faces if (world @ f.calc_center_median()).z < 3.0
          or abs((world @ f.calc_center_median()).x) >= 0.4]
bmesh.ops.delete(bm, geom=remove, context="FACES")
bm.to_mesh(head.data)
bm.free()
head.name = "HeadMesh"
head.parent = None
head.matrix_world = world
for modifier in head.modifiers:
    if modifier.type == "ARMATURE":
        modifier.object = target_rig
for obj in imported:
    if obj != head:
        bpy.data.objects.remove(obj, do_unlink=True)
# Use the original skin UV/material; the head and outfit keep their rig weights.

scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x, scene.render.resolution_y = 960, 960
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = os.path.join(OUT_DIR, "ropa_camuflaje_blender.png")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.28,.30,.27,1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .8
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"
scene.render.image_settings.color_mode = "RGBA"
# Frame visible character geometry while omitting import helper meshes.
meshes = [o for o in scene.objects if o.type == "MESH" and not o.hide_render]
bpy.context.view_layer.update()
points = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
center = sum(points, Vector()) / max(1,len(points))
radius = max((p-center).length for p in points) if points else 1.0
cam_data = bpy.data.cameras.new("Uniform Preview Camera")
cam = bpy.data.objects.new("Uniform Preview Camera", cam_data)
scene.collection.objects.link(cam)
cam.location = center + Vector((1.0,-4.0,1.3)) * max(radius, .5)
cam.rotation_euler = (center-cam.location).to_track_quat("-Z","Y").to_euler()
cam.data.type = "ORTHO"
cam.data.ortho_scale = max(radius * 2.05, 2.0)
scene.camera = cam
light_data = bpy.data.lights.new("Uniform Softbox", "AREA")
light = bpy.data.objects.new("Uniform Softbox", light_data)
scene.collection.objects.link(light)
light.location = center + Vector((-.7,-3.0,2.2)) * max(radius,.5)
light_data.energy = 3200
light_data.shape = "DISK"
light_data.size = 3
light.rotation_euler = (center-light.location).to_track_quat("-Z","Y").to_euler()
bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT_DIR,"ropa_camuflaje.blend"))
print("WOODLAND_TEXTURE=" + woodland.filepath_raw)
print("DESERT_TEXTURE=" + desert.filepath_raw)
print("PREVIEW=" + scene.render.filepath)
