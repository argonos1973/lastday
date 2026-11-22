"""Adapt assets_src/headlamp.glb into a lightweight two-part wearable/pickup GLB.

Source: assets_src/headlamp.glb (preserved outside the exported .pck via .gdignore).
Output: assets/characters/adapted/headlamp.glb
  - LampHousing: rigid front tactical multi-LED module; origin at backplate center,
    facing +Z in Godot bind space so lenses never distort when the band stretches.
  - HeadbandStrap: elastic headband + rear buckle; origin at the same backplate
    plane (z = 0) so scaling (X, 1, Z) conforms to bare skull, balaclava, cap,
    hat crown or military helmet while keeping the strap anchored inside the housing.
"""
from pathlib import Path
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "assets_src" / "headlamp.glb"
OUT = ROOT / "assets" / "characters" / "adapted" / "headlamp.glb"

BASE_SCALE = 0.225
BACKPLATE_Y_BL = -0.685  # Blender Y where flat backplate meets forehead (-Y -> +Z in Godot)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SRC))

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
if not meshes:
    raise RuntimeError("No mesh objects found in " + str(SRC))

bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = meshes[0]
for o in meshes:
    o.select_set(True)
bpy.ops.object.join()
joined = bpy.context.view_layer.objects.active
joined.name = "HeadlampJoined"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Weld the 16-bit chunk seams and drop tiny floating scan crumbs (< 20 verts).
bm = bmesh.new()
bm.from_mesh(joined.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.00025)
bm.verts.ensure_lookup_table()
visited = set()
to_delete = []
for v in bm.verts:
    if v.index in visited:
        continue
    comp = []
    stack = [v]
    visited.add(v.index)
    while stack:
        cur = stack.pop()
        comp.append(cur)
        for e in cur.link_edges:
            nb = e.other_vert(cur)
            if nb.index not in visited:
                visited.add(nb.index)
                stack.append(nb)
    if len(comp) < 20:
        to_delete.extend(comp)
if to_delete:
    bmesh.ops.delete(bm, geom=to_delete, context="VERTS")
bm.to_mesh(joined.data)
bm.free()
joined.data.update()

# Decimate ~328k scan faces down to ~5.2k crisp triangles while preserving UVs.
dec = joined.modifiers.new("DecimateScan", "DECIMATE")
dec.decimate_type = "COLLAPSE"
dec.ratio = 0.016
dec.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=dec.name)

# Shift origin to backplate center (0, BACKPLATE_Y_BL, 0) and apply BASE_SCALE.
# Reshape the rear two-thirds of the relaxed strap toward a fuller cranial
# superellipse so the band clears parietal/cap/hat rear-quarters all the way around.
for v in joined.data.vertices:
    raw_x = v.co.x
    raw_y = v.co.y
    if raw_y > BACKPLATE_Y_BL + 0.10:
        u = min(1.0, max(0.0, (raw_y - (BACKPLATE_Y_BL + 0.10)) / 1.55))
        # Peak widening around u ≈ 0.65 (parietal/rear-quarter), tapering smoothly at rear center.
        rear_fullness = 1.0 + 0.42 * (4.0 * u * (1.0 - 0.55 * u))
        if abs(raw_x) > 0.08:
            raw_x *= rear_fullness
        if raw_y > 0.25:
            raw_y += 0.08 * ((raw_y - 0.25) / 0.75)
    v.co.x = raw_x * BASE_SCALE
    v.co.y = (raw_y - BACKPLATE_Y_BL) * BASE_SCALE
    v.co.z = v.co.z * BASE_SCALE
joined.data.update()

# Give the material a matte military polymer finish while keeping all PBR textures.
for mat in joined.data.materials:
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                n.inputs["Roughness"].default_value = max(float(n.inputs["Roughness"].default_value), 0.62)

# Split into rigid LampHousing (front module) and flexible HeadbandStrap (band).
# Overlap zone: strap vertices near the side slots extend 6 mm inside the housing
# backplate so non-uniform X/Z strap fitting never opens a visible gap.
bm_full = bmesh.new()
bm_full.from_mesh(joined.data)

def extract_part(name: str, keep_housing: bool) -> bpy.types.Object:
    bm_part = bm_full.copy()
    drop_faces = []
    for f in bm_part.faces:
        c = f.calc_center_median()
        # In shifted+scaled Blender coords:
        # y < 0 is forward of backplate (toward lens at y ≈ -0.071);
        # housing width is |x| <= 0.086, backplate thickness reaches y <= +0.010.
        in_housing = (c.y <= 0.008 and abs(c.x) <= 0.098)
        if keep_housing and not in_housing:
            drop_faces.append(f)
        elif (not keep_housing) and (c.y < -0.003 and abs(c.x) < 0.092):
            drop_faces.append(f)
    if drop_faces:
        bmesh.ops.delete(bm_part, geom=drop_faces, context="FACES")
    loose_v = [v for v in bm_part.verts if not v.link_faces]
    if loose_v:
        bmesh.ops.delete(bm_part, geom=loose_v, context="VERTS")
    bmesh.ops.recalc_face_normals(bm_part, faces=list(bm_part.faces))
    me = bpy.data.meshes.new(name)
    for m in joined.data.materials:
        me.materials.append(m)
    bm_part.to_mesh(me)
    bm_part.free()
    for p in me.polygons:
        p.use_smooth = True
    me.update()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    return obj

housing = extract_part("LampHousing", True)
strap = extract_part("HeadbandStrap", False)
bm_full.free()

# Clean up all temporary empties/joined mesh before exporting.
for o in list(bpy.data.objects):
    if o not in (housing, strap):
        bpy.data.objects.remove(o, do_unlink=True)

OUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(
    filepath=str(OUT),
    export_format="GLB",
    export_yup=True,
    export_texcoords=True,
    export_normals=True,
    export_materials="EXPORT",
    export_image_format="JPEG",
    export_jpeg_quality=88,
)
print(f"Exported {OUT} | housing_faces={len(housing.data.polygons)} strap_faces={len(strap.data.polygons)}")
