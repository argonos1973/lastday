"""Create a four-storey, walkable post-apocalyptic city block for Last Day.

Coordinates and exports follow tools/blender/create_city_block.py: game Y is
up, the street-facing entrance is local +Z, and Godot exports the joined
Solid_/Collision_ meshes as collision surfaces.
"""
import bpy
import bmesh
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/environment/city"
SOURCE = ROOT / "outputs/city"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
FH = 3.9
FLOORS = 4
HALF = 6.0


def material(name, color, texture=None, uv_scale=2.5):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = .88
    if texture:
        image = bpy.data.images.load(str(ROOT / texture), check_existing=True)
        image = image.copy()
        image.scale(1024, 1024)
        image.pack()
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = image
        uv = nodes.new("ShaderNodeUVMap")
        mat.node_tree.links.new(uv.outputs["UV"], tex.inputs["Vector"])
        multiply = nodes.new("ShaderNodeMixRGB")
        multiply.blend_type = "MULTIPLY"
        multiply.inputs["Fac"].default_value = 1.0
        multiply.inputs["Color2"].default_value = (*color, 1)
        mat.node_tree.links.new(tex.outputs["Color"], multiply.inputs["Color1"])
        mat.node_tree.links.new(multiply.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


brick = material("Old red brick", (.58, .48, .38), "assets/external/textures/red_brick_03/red_brick_03_diff_4k.jpg")
plaster = material("Peeling grey lime", (.58, .57, .49), "assets/textures/city_interior/facade_lime_0.png")
concrete = material("Stained concrete", (.38, .37, .34), "assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg")
wood = material("Rotten timber", (.22, .15, .09), "assets/textures/overgrowth/village_wood_albedo.png")
iron = material("Oxidised iron", (.13, .12, .095))
glass = material("Smoky glass", (.16, .19, .18))


def cube(name, p, size, mat, prefix="Solid_"):
    # Game-space (x,y,z) to Blender Z-up with the same handedness as the
    # existing city generator. Keep real opening gaps in collision geometry.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(p[0], -p[2], p[1]))
    obj = bpy.context.object
    obj.name = prefix + name
    obj.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    layer = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    for poly in obj.data.polygons:
        axis = max(range(3), key=lambda a: abs(poly.normal[a]))
        axes = [a for a in range(3) if a != axis]
        for loop_index in poly.loop_indices:
            vertex_index = obj.data.loops[loop_index].vertex_index
            co = obj.data.vertices[vertex_index].co + obj.location
            # World x/z on horizontal surfaces, world y/z on the long side.
            if axis == 2:
                uv = (co.x, -co.y)
            elif axis == 1:
                uv = (co.x, co.z)
            else:
                uv = (-co.y, co.z)
            layer.data[loop_index].uv = (uv[0] / 2.5, uv[1] / 2.5)
    return obj


def wall_x(name, level, z, openings, mat):
    """Wall on front/back face; openings are (center_x, width, sill, head)."""
    y0 = .0
    y1 = FH
    wall_depth = .28
    intervals = sorted((cx - width / 2, cx + width / 2, sill, head) for cx, width, sill, head in openings)
    x = -HALF
    for left, right, sill, head in intervals:
        if left > x:
            cube(name + "Pier", ((x + left) / 2, level * FH + FH / 2, z), (left - x, FH, wall_depth), brick)
        if sill > 0:
            cube(name + "SillWall", ((left + right) / 2, level * FH + sill / 2, z), (right - left, sill, wall_depth), plaster)
        if head < FH:
            cube(name + "Lintel", ((left + right) / 2, level * FH + (head + FH) / 2, z), (right - left, FH - head, wall_depth), plaster)
        # Window jambs, sill and lintel accent remain outside the opening.
        if head - sill > .4:
            cube(name + "Jamb", (left, level * FH + (sill + head) / 2, z), (.08, head - sill, .38), plaster, "Detail_")
            cube(name + "Jamb", (right, level * FH + (sill + head) / 2, z), (.08, head - sill, .38), plaster, "Detail_")
            cube(name + "Sill", ((left + right) / 2, level * FH + sill, z), (right - left + .18, .10, .52), concrete, "Detail_")
            if (int(abs(left) * 10) + level) % 3 != 0:
                pane = cube(name + "BrokenPane", ((left + right) / 2, level * FH + (sill + head) / 2, z), (right - left - .12, head - sill - .12, .025), glass, "Detail_")
                pane.display_type = "TEXTURED"
        x = right
    if x < HALF:
        cube(name + "Pier", ((x + HALF) / 2, level * FH + FH / 2, z), (HALF - x, FH, wall_depth), brick)


def wall_z(name, level, x, openings, mat):
    """Wall on side face; openings are (center_z, width, sill, head)."""
    intervals = sorted((cz - width / 2, cz + width / 2, sill, head) for cz, width, sill, head in openings)
    z = -HALF
    for low, high, sill, head in intervals:
        if low > z:
            cube(name + "Pier", (x, level * FH + FH / 2, (z + low) / 2), (.28, FH, low - z), brick)
        if sill > 0:
            cube(name + "SillWall", (x, level * FH + sill / 2, (low + high) / 2), (.28, sill, high - low), plaster)
        if head < FH:
            cube(name + "Lintel", (x, level * FH + (head + FH) / 2, (low + high) / 2), (.28, FH - head, high - low), plaster)
        cube(name + "Jamb", (x, level * FH + (sill + head) / 2, low), (.38, head - sill, .08), plaster, "Detail_")
        cube(name + "Jamb", (x, level * FH + (sill + head) / 2, high), (.38, head - sill, .08), plaster, "Detail_")
        z = high
    if z < HALF:
        cube(name + "Pier", (x, level * FH + FH / 2, (z + HALF) / 2), (.28, FH, HALF - z), brick)


def stair_wedge(level, x0, x1):
    y0 = .12 + level * FH
    y1 = y0 + FH
    z0, z1 = 4.65, -4.65
    # Thin sloped slab (not a triangular prism): a wedge whose underside is
    # parallel to the tread surface keeps ~3.5 m of headroom over the flight
    # below. A prism drops its underside to nearly flat, so the back half of
    # the lower flight ends up buried inside this block — unclimbable.
    t = .4
    points = [(x0, y0, z0), (x1, y0, z0), (x0, y1, z1), (x1, y1, z1),
              (x0, y0 - t, z0), (x1, y0 - t, z0), (x0, y1 - t, z1), (x1, y1 - t, z1)]
    mesh = bpy.data.meshes.new("StairRampMesh")
    mesh.from_pydata([(x, -z, y) for x, y, z in points], [], [
        (0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)])
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Collision_StairRamp_%d" % level, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

# Four 3.9 m storeys. Ground floor gets a broad shop entrance; three apartment
# floors have broken windows and a real floor plate with a continuous stairwell.
cube("Foundation", (0, -.10, 0), (12.25, .30, 12.25), concrete)
for level in range(FLOORS):
    base_y = level * FH
    if level == 0:
        cube("GroundFloor", (0, .08, 0), (12, .16, 12), concrete)
    else:
        floor_y = base_y + .02
        # Stairwell is a 2.6 x 9.4 m opening on the west; the rest of each
        # floor is a continuous walkable slab. End strips create safe landings.
        cube("FloorWest", (-5.0, floor_y, 0), (2.0, .18, 12), concrete)
        cube("FloorEast", (2.05, floor_y, 0), (7.9, .18, 12), concrete)
        for end_z in [-5.25, 5.25]:
            cube("StairLanding", (-3.0, floor_y, end_z), (2.2, .18, 1.5), concrete)

    front_openings = [(-3.35, 1.75, .90, 2.85), (3.35, 1.75, .90, 2.85)]
    if level == 0:
        front_openings.append((0, 2.8, .02, 3.15))
    wall_x("Front", level, 6.0, front_openings, brick)
    wall_x("Rear", level, -6.0, [(-3.35, 1.75, .90, 2.85), (3.35, 1.75, .90, 2.85)], brick)
    wall_z("West", level, -6.0, [(-2.7, 1.8, .9, 2.75), (3.4, 1.5, 1.0, 2.6)], plaster)
    wall_z("East", level, 6.0, [(-3.0, 1.7, .9, 2.8), (3.1, 1.7, .9, 2.8)], plaster)

    # Ruined sill boards, drain pipes and ledge bands make each storey distinct.
    cube("StoreyBandFront", (0, base_y + FH - .08, 6.10), (12.12, .16, .18), concrete, "Detail_")
    cube("StoreyBandRear", (0, base_y + FH - .08, -6.10), (12.12, .16, .18), concrete, "Detail_")
    for x in [-5.82, 5.82]:
        cube("Drainpipe", (x, base_y + FH / 2, 6.25), (.12, FH, .12), iron, "Detail_")
    for wx in [-3.35, 3.35]:
        if (level + (0 if wx < 0 else 1)) % 2 == 0:
            cube("BoardedWindow", (wx, base_y + 1.75, 6.30), (1.95, .18, .10), wood, "Detail_")

    # Apartment separation on the upper floors. The 1.5 m opening by x=0.7
    # links both rooms to the stair corridor; no hidden wall blocks the route.
    if level > 0:
        cube("ApartmentPartitionB", (3.35, base_y + 1.9, .1), (5.3, 3.7, .16), plaster)
        cube("ApartmentLintel", (.55, base_y + 3.15, .1), (1.5, 1.2, .16), plaster)

    if level < FLOORS - 1:
        # Same internal flight direction on every storey; the back landing
        # returns through the open east side to the front of the next flight.
        lane0, lane1 = -4.05, -1.95
        count = 18
        for step in range(count):
            rise = (step + 1) * FH / count
            z = 4.65 - (step + .5) * 9.3 / count
            cube("StairTread", (-3.0, base_y + .12 + rise - .08, z), (2.05, .16, .58), wood, "Detail_")
        stair_wedge(level, lane0, lane1)
        # Knee-height rails/posts are solid collision geometry at the edge of
        # the stairwell; they leave the 2.1 m walking lane clear.
        for rx in [lane0, lane1]:
            for post in range(9):
                pz = 4.25 - post * 1.06
                cube("StairRailPost", (rx, base_y + .70 + post * FH / 9, pz), (.07, 1.05, .07), iron)

# Roof/cornice closes the top floor; it is not an inaccessible fake extra level.
cube("RoofSlab", (0, FLOORS * FH + .02, 0), (12.35, .24, 12.35), concrete)
for x in [-6.05, 6.05]:
    cube("RoofParapet", (x, FLOORS * FH + .65, 0), (.18, 1.0, 12.2), plaster)
for z in [-6.05, 6.05]:
    cube("RoofParapet", (0, FLOORS * FH + .65, z), (12.2, 1.0, .18), plaster)
# A cracked upper corner and exposed brick patches establish abandonment.
for i in range(8):
    x = -5.3 + i * 1.5
    if i % 3 != 1:
        cube("CrackedCornice", (x, FLOORS * FH + .88, -6.16), (.8, .18, .22), brick, "Detail_")

# Join by role: one render mesh/collision mesh per building, with each stair
# ramp separate so CityBlock can mark it as a stair surface for the player.
for prefix in ["Solid_", "Detail_"]:
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith(prefix)]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    objects[0].name = prefix + "Building"

bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / "building_5.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "building_highrise_1.glb"), export_format="GLB", export_animations=False)
print("CITY_HIGRISE_READY floors=%d height=%.2f" % (FLOORS, FLOORS * FH))
