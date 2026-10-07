#!/usr/bin/env python3
"""Glaciated granite lake-shore modules for Un dia mas.

Reference: user-supplied photo — smooth glacier-polished granite slabs dipping
into a still forest lake, warm grey rock, rounded erratic boulders and a
craggy outcrop section. Photos guide geometry/palette; the licensed polyhaven
rock_07 texture supplies surface detail.

Convention (same as create_reference_riverbanks.py): X runs along the shore,
Z points toward land, Y up, and the object origin sits at the waterline so
the leading edge continues visibly underwater through the transparent surface.

Exports assets/models/props/lake/lake_{slab,boulder,outcrop}_{0,1,2}.glb
Run headless:
    Blender --background --factory-startup --python tools/blender/generate_lake_granite.py
"""
from pathlib import Path
import random, math, sys
import bpy
import bmesh
import numpy as np
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/props/lake'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = ROOT / 'work/lake_granite.blend'
bpy.ops.wm.read_factory_settings(use_empty=True)

# -- Granite textures -------------------------------------------------------
# Procedural speckled granite: warm grey base, low-frequency mottling and
# black/white mineral grains — closer to the reference than a cliff photo.
def granite_texture(name, base_rgb, seed):
    n = 2048
    img = bpy.data.images.new(name, n, n)
    rng = np.random.default_rng(seed)

    def field(cells):
        grid = rng.random((cells, cells)).astype(np.float32)
        coord = np.arange(n, dtype=np.float32) * cells / n
        ix = coord.astype(np.int32)
        t = coord - ix
        t = t * t * t * (t * (t * 6.0 - 15.0) + 10.0)
        rows = grid[:, ix] * (1.0 - t) + grid[:, (ix + 1) % cells] * t
        return rows[ix, :] * (1.0 - t[:, None]) + rows[(ix + 1) % cells, :] * t[:, None]

    low = field(5) * .55 + field(13) * .30 + field(31) * .15
    medium = field(91)
    fine = field(293)
    scan = bpy.data.images.load(str(ROOT / 'assets/external/polyhaven/rock_07/textures/rock_07_diff_4k.jpg'), check_existing=True)
    sw, sh = scan.size
    pixels = np.empty(sw * sh * 4, dtype=np.float32)
    scan.pixels.foreach_get(pixels)
    crop = pixels.reshape(sh, sw, 4)[int(sh * .27):int(sh * .62), int(sw * .04):int(sw * .27), :3]
    xs = np.linspace(0, crop.shape[1] - 2, n)
    ys = np.linspace(0, crop.shape[0] - 2, n)
    ix, iy = xs.astype(np.int32), ys.astype(np.int32)
    tx, ty = (xs - ix)[None, :, None], (ys - iy)[:, None, None]
    photo = (crop[iy[:, None], ix] * (1 - tx) + crop[iy[:, None], ix + 1] * tx) * (1 - ty)
    photo += (crop[iy[:, None] + 1, ix] * (1 - tx) + crop[iy[:, None] + 1, ix + 1] * tx) * ty
    t = np.arange(n, dtype=np.float32) / n
    edge = np.clip((np.minimum(t, 1 - t) - .04) / .22, 0, 1)
    edge = edge * edge * (3 - 2 * edge)
    photo = photo * edge[None, :, None] + np.roll(photo, n // 2, 1) * (1 - edge[None, :, None])
    photo = photo * edge[:, None, None] + np.roll(photo, n // 2, 0) * (1 - edge[:, None, None])
    photo = np.clip(photo / np.maximum(photo.mean(axis=(0, 1)), .001), .18, 3.5) ** .62
    # Mineral grains must read at gameplay distance: ~4 px blobs, not
    # single-pixel noise that blurs into flat sand.
    speckle = field(617)
    px = np.empty((n, n, 4), dtype=np.float32)
    g = np.array(base_rgb)[None, None, :] * (.78 + low[:, :, None] * .40) * photo
    px[:, :, :3] = g + (fine[:, :, None] - .5) * .045 + (speckle[:, :, None] - .5) * .035
    px[:, :, :3][speckle < 0.20] *= 0.50          # dark mineral grains
    px[:, :, :3][speckle > 0.83] = np.clip(px[:, :, :3][speckle > 0.83] * 1.35, 0, 1)
    grain = photo.mean(axis=-1)
    quartz = np.clip((grain - 1.20) * .75, 0, .35)
    cracks = np.clip((.52 - grain) * 1.5, 0, .4)
    px[:, :, :3] *= (1.0 - cracks[:, :, None] * .55)
    px[:, :, :3] += quartz[:, :, None] * .075
    lichen = (np.clip((field(17) - .60) * 3.5, 0.0, .45) * np.clip((medium - .3) * 2.0, 0, 1))[:, :, None]
    px[:, :, :3] = px[:, :, :3] * (1.0 - lichen) + np.array([.16, .17, .095]) * lichen
    px[:, :, 3] = 1.0
    img.pixels.foreach_set(np.clip(px, 0, 1).ravel())
    relief = low * .18 + medium * .10 + fine * .045 + grain * .20 + speckle * .018 - cracks * .045 + quartz * .02
    dy = (np.roll(relief, -1, 0) - np.roll(relief, 1, 0)) * 5.0
    dx = (np.roll(relief, -1, 1) - np.roll(relief, 1, 1)) * 5.0
    normal = np.stack((-dx, -dy, np.ones_like(dx)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    normal_img = bpy.data.images.new(name + '_normal', n, n)
    normal_img.colorspace_settings.name = 'Non-Color'
    px[:, :, :3] = normal * .5 + .5
    normal_img.pixels.foreach_set(px.ravel())
    rough_img = bpy.data.images.new(name + '_roughness', n, n)
    rough_img.colorspace_settings.name = 'Non-Color'
    px[:, :, :3] = np.clip(.63 + medium[:, :, None] * .3 + cracks[:, :, None] * .1 - quartz[:, :, None] * .15, .45, .98)
    rough_img.pixels.foreach_set(px.ravel())
    return img, normal_img, rough_img


granite_img = granite_texture('lake_granite', (0.18, 0.185, 0.17), 7)
# Submerged copy: darker and cooler — wet stone read through water.
wet_img = granite_texture('lake_granite_wet', (0.11, 0.125, 0.12), 7)


def material(name, image, roughness):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = roughness
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = image[0]
    m.node_tree.links.new(t.outputs['Color'], bs.inputs['Base Color'])
    normal_tex = m.node_tree.nodes.new('ShaderNodeTexImage')
    normal_tex.image = image[1]
    normal_map = m.node_tree.nodes.new('ShaderNodeNormalMap')
    normal_map.inputs['Strength'].default_value = .75
    m.node_tree.links.new(normal_tex.outputs['Color'], normal_map.inputs['Color'])
    m.node_tree.links.new(normal_map.outputs['Normal'], bs.inputs['Normal'])
    rough_tex = m.node_tree.nodes.new('ShaderNodeTexImage')
    rough_tex.image = image[2]
    m.node_tree.links.new(rough_tex.outputs['Color'], bs.inputs['Roughness'])
    return m


DRY = material('Glacial granite', granite_img, .85)
WET = material('Wet granite', wet_img, .55)
MATS = [DRY, WET]


def dominant_uvs(verts, faces, scale):
    """Planar top-down UV — continuous over the shallow domes; the narrow rim
    walls stretch vertically, which reads as natural rock strata."""
    out = []
    for f in faces:
        a, b, c = (np.asarray(verts[i]) for i in f[:3])
        axis = int(np.argmax(np.abs(np.cross(b - a, c - a))))
        for i in f:
            x, y, z = verts[i]
            u, v = (x, z) if axis == 1 else ((z, y) if axis == 0 else (x, y))
            out.append((u * scale, v * scale))
    return out


def new_mesh(name):
    data = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for m in MATS:
        data.materials.append(m)
    return data, obj


def finish(data, obj, verts, faces, mat_idx, uvs, smooth=True):
    # verts are authored in game space (X along shore, Y up, Z toward land);
    # Blender is Z-up with -Z forward, so map (x, y, z) -> (x, -z, y) as in
    # create_reference_riverbanks.py. The mirror flips winding — reverse it.
    data.from_pydata([(x, -z, y) for x, y, z in verts], [], [f[::-1] for f in faces])
    data.update()
    uv = data.uv_layers.new()
    offset = 0
    for poly, mi, face in zip(data.polygons, mat_idx, faces):
        poly.use_smooth = smooth
        poly.material_index = mi
        face_uvs = uvs[offset:offset + len(face)][::-1]
        for li, texcoord in zip(poly.loop_indices, face_uvs):
            uv.data[li].uv = texcoord
        offset += len(face)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    for edge in bm.edges:
        edge.smooth = edge.calc_face_angle() < math.radians(45)
    assert all(edge.is_manifold for edge in bm.edges), obj.name
    assert bm.calc_volume(signed=True) > 0.0, obj.name
    bm.to_mesh(data)
    bm.free()
    data.update()


def export(obj, filename):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(OUT / filename), export_format='GLB',
                              use_selection=True, export_image_format='JPEG', export_jpeg_quality=88)


# -- Slab -------------------------------------------------------------------
# Polar dome heightfield: gently domed, low-frequency undulation plus faint
# glacial striations along X. The -Z (water) rim tilts below the origin.
def build_slab(variant):
    rng = random.Random(4100 + variant * 271)
    rx = rng.uniform(3.8, 5.4)          # half-length along shore
    rz = rng.uniform(2.3, 3.5)          # half-depth shore->land
    height = rng.uniform(.38, .72)      # dome apex above waterline
    dip = rng.uniform(.4, .75)          # how far the water rim sinks
    thick = rng.uniform(.9, 1.3)        # base thickness — thin shelf
    rings, secs = 18, 64
    verts, faces, midx = [], [], []
    wob = rng.uniform(0, math.tau)

    def top_y(x, z, r):
        dome = height * max(0.0, 1.0 - r * r) ** .75
        und = .19 * noise.noise_vector(Vector((x * .62, z * .62, wob)))[0]
        und += .035 * noise.noise_vector(Vector((x * 2.8, z * 2.8, wob)))[1]
        fissure = x * .24 + z - .5 + .12 * math.sin(x * 1.6 + wob)
        striate = -.13 * math.exp(-(fissure / .10) ** 2)
        striate -= .085 * math.exp(-((x - z * .38 + 1.1) / .09) ** 2)
        # The plate floor stays above the waterline wherever the origin sits
        # on it (plate_min ~0.13 > 0); the surface only ducks under water in
        # the outermost water-edge band, so the lake laps onto the shelf edge
        # without trapping enclosed dark pools on the plate.
        plate = dome + und + striate + 0.22
        nose = dip * max(0.0, (-z / rz - 0.55) / 0.45)
        land_blend = max(0.0, min(1.0, (z / rz + .05 + und * 1.4) / .95))
        edge_blend = max(0.0, min(1.0, (r - .72) / .28)) * max(0.0, min(1.0, (z / rz + .55) * 2.0))
        land_blend = max(land_blend, edge_blend)
        land_blend = land_blend * land_blend * (3.0 - 2.0 * land_blend)
        return plate * (1.0 - land_blend) - .24 * land_blend - nose

    # Top surface: centre vertex + rings of quads/fans. The rim gets a slight
    # angular wobble so the outline reads as rock, not a perfect ellipse.
    verts.append((0.0, top_y(0.0, 0.0, 0.0), 0.0))
    for ri in range(1, rings + 1):
        r = ri / rings
        for s in range(secs):
            a = s / secs * math.tau
            rr = 1.0 + (.16 * math.sin(a * 3.0 + wob * 2.0) + .09 * math.sin(a * 5.0 + wob) + .035 * math.sin(a * 11.0 - wob)) * r
            ca, sa = math.cos(a), math.sin(a)
            x = rx * r * rr * math.copysign(abs(ca) ** .92, ca)
            z = rz * r * rr * math.copysign(abs(sa) ** .92, sa)
            verts.append((x, top_y(x, z, r), z))
    # Bottom surface (mirrored, pushed down by thickness)
    verts.append((0.0, top_y(0.0, 0.0, 0.0) - thick * 1.15, 0.0))
    for ri in range(1, rings + 1):
        r = ri / rings
        for s in range(secs):
            a = s / secs * math.tau
            rr = 1.0 + (.16 * math.sin(a * 3.0 + wob * 2.0) + .09 * math.sin(a * 5.0 + wob) + .035 * math.sin(a * 11.0 - wob)) * r
            ca, sa = math.cos(a), math.sin(a)
            x = rx * r * rr * math.copysign(abs(ca) ** .92, ca)
            z = rz * r * rr * math.copysign(abs(sa) ** .92, sa)
            verts.append((x, top_y(x, z, r) - thick * (0.55 + 0.45 * (1 - r * r)), z))

    top0, bot0 = 0, 1 + rings * secs
    def vid(base, ri, s):
        return base + (ri - 1) * secs + (s % secs) + 1

    for s in range(secs):  # centre fans
        faces.append((top0, vid(top0, 1, s), vid(top0, 1, s + 1)))
        faces.append((bot0, vid(bot0, 1, s + 1), vid(bot0, 1, s)))
    for ri in range(1, rings):  # ring quads
        for s in range(secs):
            a, b = vid(top0, ri, s), vid(top0, ri, s + 1)
            c, d = vid(top0, ri + 1, s + 1), vid(top0, ri + 1, s)
            faces.append((d, c, b, a))
            a2, b2 = vid(bot0, ri, s), vid(bot0, ri, s + 1)
            c2, d2 = vid(bot0, ri + 1, s + 1), vid(bot0, ri + 1, s)
            faces.append((c2, d2, a2, b2))
    for s in range(secs):  # rim walls
        a, b = vid(top0, rings, s), vid(top0, rings, s + 1)
        c, d = vid(bot0, rings, s + 1), vid(bot0, rings, s)
        faces.append((a, b, c, d))

    # Wet material only on the deeply submerged nose — a thin dark band right
    # at the waterline. Undulation valleys higher up must stay dry granite.
    for f in faces:
        cy = sum(verts[i][1] for i in f) / len(f)
        cz = sum(verts[i][2] for i in f) / len(f)
        midx.append(1 if (cz < -rz * .55 and cy < -.25) else 0)
    return verts, faces, midx, dominant_uvs(verts, faces, .9)


# -- Boulder -----------------------------------------------------------------
# Weathered erratic: jittered ellipsoid, lower half assigned the wet material.
def build_boulder(variant):
    rng = random.Random(5200 + variant * 173)
    sx = rng.uniform(.55, 1.15)
    sy = sx * rng.uniform(.55, .8)
    sz = sx * rng.uniform(.8, 1.2)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=1.0)
    tmp = bpy.context.object
    src_v = [v.co.copy() for v in tmp.data.vertices]
    src_f = [tuple(p.vertices) for p in tmp.data.polygons]
    bpy.data.objects.remove(tmp, do_unlink=True)
    jit = rng.uniform(.12, .22)
    verts = []
    for x, y, z in src_v:
        warp = noise.noise_vector(Vector((x * 1.8, y * 1.8, z * 1.8 + variant * 7.3)))
        xx = (x + warp.x * jit) * sx
        zz = (z + warp.z * jit) * sz
        yy = min(y + warp.y * jit, .79 + x * .13 - z * .17) * sy + sy * .32
        verts.append((xx, yy, zz))
    faces = src_f
    midx = []
    for f in faces:
        cy = sum(verts[i][1] for i in f) / len(f)
        midx.append(1 if cy < -.15 else 0)
    return verts, faces, midx, dominant_uvs(verts, faces, 1.2)


# -- Outcrop -----------------------------------------------------------------
# Craggy point cluster: several taller overlapping slabs leaning slightly
# different ways — the dark rocky headland of the reference.
def build_outcrop(variant):
    rng = random.Random(6300 + variant * 97)
    verts, faces, midx, uvs = [], [], [], []
    for piece in range(3):
        prx = rng.uniform(2.2, 3.4)
        prz = rng.uniform(2.0, 3.0)
        ph = rng.uniform(2.4, 3.8)
        pdip = rng.uniform(.25, .5)
        pth = rng.uniform(1.2, 1.8)
        cx = (piece - 1) * 1.8 + rng.uniform(-.4, .4)
        cz = rng.uniform(-.2, 1.0)
        lean = rng.uniform(-.06, .06)
        rings, secs = 12, 40
        base = len(verts)
        wob = rng.uniform(0, math.tau)

        def ty(x, z, r):
            dome = ph * max(0.0, 1.0 - r * r) ** .58
            dome = min(dome, ph * .82 + x * .16 - z * .20)
            und = .28 * noise.noise_vector(Vector((x * .9, z * .9, wob)))[0]
            slope = pdip * (0.5 - 0.5 * (z / prz))
            fracture = .28 * math.exp(-((x - z * .3 - .4) / .22) ** 2)
            return dome + und - slope * r + lean * x - fracture

        verts.append((cx, ty(0.0, 0.0, 0.0), cz))
        for ri in range(1, rings + 1):
            r = ri / rings
            for s in range(secs):
                a = s / secs * math.tau
                rr = r * (1.0 + .12 * math.sin(a * 3.0 + wob) + .055 * math.sin(a * 7.0))
                x, z = prx * rr * math.cos(a), prz * rr * math.sin(a)
                verts.append((cx + x, ty(x, z, r), cz + z))
        verts.append((cx, ty(0.0, 0.0, 0.0) - pth * 1.15, cz))
        for ri in range(1, rings + 1):
            r = ri / rings
            for s in range(secs):
                a = s / secs * math.tau
                rr = r * (1.0 + .12 * math.sin(a * 3.0 + wob) + .055 * math.sin(a * 7.0))
                x, z = prx * rr * math.cos(a), prz * rr * math.sin(a)
                verts.append((cx + x, ty(x, z, r) - pth * (0.55 + 0.45 * (1 - r * r)), cz + z))

        t0, b0 = base, base + 1 + rings * secs
        def vid(bb, ri, s):
            return bb + (ri - 1) * secs + (s % secs) + 1
        for s in range(secs):
            faces.append((t0, vid(t0, 1, s), vid(t0, 1, s + 1)))
            faces.append((b0, vid(b0, 1, s + 1), vid(b0, 1, s)))
        for ri in range(1, rings):
            for s in range(secs):
                a, b = vid(t0, ri, s), vid(t0, ri, s + 1)
                c, d = vid(t0, ri + 1, s + 1), vid(t0, ri + 1, s)
                faces.append((d, c, b, a))
                a2, b2 = vid(b0, ri, s), vid(b0, ri, s + 1)
                c2, d2 = vid(b0, ri + 1, s + 1), vid(b0, ri + 1, s)
                faces.append((c2, d2, a2, b2))
        for s in range(secs):
            a, b = vid(t0, rings, s), vid(t0, rings, s + 1)
            c, d = vid(b0, rings, s + 1), vid(b0, rings, s)
            faces.append((a, b, c, d))

    for f in faces:
        cy = sum(verts[i][1] for i in f) / len(f)
        midx.append(1 if cy < -.25 else 0)
    return verts, faces, midx, dominant_uvs(verts, faces, .8)


built = []
for v in range(3):
    for kind, fn in (('slab', build_slab), ('boulder', build_boulder), ('outcrop', build_outcrop)):
        verts, faces, midx, uvs = fn(v)
        data, obj = new_mesh('Lake%s_%d' % (kind.capitalize(), v))
        finish(data, obj, verts, faces, midx, uvs)
        export(obj, 'lake_%s_%d.glb' % (kind, v))
        obj.location.x = len(built) * 9.0
        built.append(obj)

if '--save-blend' in sys.argv:
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('LAKE_GRANITE_EXPORTED', OUT)
