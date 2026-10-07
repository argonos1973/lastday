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
import random, math
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/props/lake'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = Path('/Users/sami/Documents/Codex/2026-09-08/rev/outputs/lago_granito_referencia.blend')
bpy.ops.wm.read_factory_settings(use_empty=True)

# -- Granite textures -------------------------------------------------------
# Procedural speckled granite: warm grey base, low-frequency mottling and
# black/white mineral grains — closer to the reference than a cliff photo.
def granite_texture(name, base_rgb, seed):
    n = 1024
    img = bpy.data.images.new(name, n, n)
    rng = np.random.default_rng(seed)
    low = rng.random((32, 32)).repeat(32, 0).repeat(32, 1)
    for _ in range(6):
        low = (low + np.roll(low, 1, 0) + np.roll(low, -1, 0)
               + np.roll(low, 1, 1) + np.roll(low, -1, 1)) / 5.0
    # Mineral grains must read at gameplay distance: ~4 px blobs, not
    # single-pixel noise that blurs into flat sand.
    speckle = rng.random((256, 256)).repeat(4, 0).repeat(4, 1)
    px = np.empty((n, n, 4), dtype=np.float32)
    g = np.array(base_rgb)[None, None, :] * (0.82 + low[:, :, None] * 0.34)
    px[:, :, :3] = g + (speckle[:, :, None] - 0.5) * 0.14
    px[:, :, :3][speckle < 0.12] *= 0.50          # dark mineral grains
    px[:, :, :3][speckle > 0.88] = np.clip(px[:, :, :3][speckle > 0.88] * 1.45, 0, 1)
    px[:, :, 3] = 1.0
    img.pixels.foreach_set(px.ravel())
    return img


granite_img = granite_texture('lake_granite', (0.21, 0.20, 0.18), 7)
# Submerged copy: darker and cooler — wet stone read through water.
wet_img = granite_texture('lake_granite_wet', (0.16, 0.17, 0.16), 8)


def material(name, image, roughness):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Roughness'].default_value = roughness
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = image
    m.node_tree.links.new(t.outputs['Color'], bs.inputs['Base Color'])
    return m


DRY = material('Glacial granite', granite_img, .85)
WET = material('Wet granite', wet_img, .55)
MATS = [DRY, WET]


def dominant_uvs(verts, faces, scale):
    """Planar top-down UV — continuous over the shallow domes; the narrow rim
    walls stretch vertically, which reads as natural rock strata."""
    out = []
    for f in faces:
        for i in f:
            x, y, z = verts[i]
            out.append((x * scale, z * scale))
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
    for poly, mi in zip(data.polygons, mat_idx):
        poly.use_smooth = smooth
        poly.material_index = mi
        for li in poly.loop_indices:
            uv.data[li].uv = uvs[li]
    for p in data.polygons:
        p.use_smooth = True


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
    rx = rng.uniform(5.0, 7.0)          # half-length along shore
    rz = rng.uniform(2.6, 3.4)          # half-depth shore->land
    height = rng.uniform(.30, .55)      # dome apex above waterline
    dip = rng.uniform(.4, .75)          # how far the water rim sinks
    thick = rng.uniform(.9, 1.3)        # base thickness — thin shelf
    rings, secs = 9, 40
    verts, faces, midx = [], [], []
    wob = rng.uniform(0, math.tau)

    def top_y(x, z, r):
        dome = height * max(0.0, 1.0 - r * r) ** .45
        und = .07 * math.sin(x * 1.15 + wob) * math.cos(z * 1.7 - wob) * (0.3 + 0.7 * (1 - r))
        striate = .018 * math.sin(z * 9.0 + math.sin(x * .8) * 1.5)
        # The plate floor stays above the waterline wherever the origin sits
        # on it (plate_min ~0.13 > 0); the surface only ducks under water in
        # the outermost water-edge band, so the lake laps onto the shelf edge
        # without trapping enclosed dark pools on the plate.
        plate = dome + und + striate + 0.22
        nose = dip * max(0.0, (-z / rz - 0.55) / 0.45)
        return plate - nose

    # Top surface: centre vertex + rings of quads/fans. The rim gets a slight
    # angular wobble so the outline reads as rock, not a perfect ellipse.
    verts.append((0.0, top_y(0.0, 0.0, 0.0), 0.0))
    for ri in range(1, rings + 1):
        r = ri / rings
        for s in range(secs):
            a = s / secs * math.tau
            rr = 1.0 + 0.07 * math.sin(a * 3.0 + wob * 2.0) * r
            x, z = rx * r * rr * math.cos(a), rz * r * rr * math.sin(a)
            verts.append((x, top_y(x, z, r), z))
    # Bottom surface (mirrored, pushed down by thickness)
    verts.append((0.0, top_y(0.0, 0.0, 0.0) - thick * 1.15, 0.0))
    for ri in range(1, rings + 1):
        r = ri / rings
        for s in range(secs):
            a = s / secs * math.tau
            rr = 1.0 + 0.07 * math.sin(a * 3.0 + wob * 2.0) * r
            x, z = rx * r * rr * math.cos(a), rz * r * rr * math.sin(a)
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
    jit = rng.uniform(.05, .11)
    verts = [(x * sx + rng.uniform(-jit, jit) * sx,
              (y * sy + rng.uniform(-jit, jit) * sy) + sy * .42,
              z * sz + rng.uniform(-jit, jit) * sz) for x, y, z in src_v]
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
        ph = rng.uniform(.5, 1.0)
        pdip = rng.uniform(.5, .9)
        pth = rng.uniform(.7, 1.2)
        cx = rng.uniform(-1.0, 1.0)
        cz = rng.uniform(-.5, .7)
        lean = rng.uniform(-.06, .06)
        rings, secs = 7, 26
        base = len(verts)
        wob = rng.uniform(0, math.tau)

        def ty(x, z, r):
            dome = ph * max(0.0, 1.0 - r * r) ** .55
            und = .20 * math.sin(x * 1.9 + wob) * math.cos(z * 2.3) * (0.3 + 0.7 * (1 - r))
            slope = pdip * (0.5 - 0.5 * (z / prz))
            return dome + und - slope * r + lean * x

        verts.append((cx, ty(0.0, 0.0, 0.0), cz))
        for ri in range(1, rings + 1):
            r = ri / rings
            for s in range(secs):
                a = s / secs * math.tau
                x, z = prx * r * math.cos(a), prz * r * math.sin(a)
                verts.append((cx + x, ty(x, z, r), cz + z))
        verts.append((cx, ty(0.0, 0.0, 0.0) - pth * 1.15, cz))
        for ri in range(1, rings + 1):
            r = ri / rings
            for s in range(secs):
                a = s / secs * math.tau
                x, z = prx * r * math.cos(a), prz * r * math.sin(a)
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

SOURCE.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('LAKE_GRANITE_EXPORTED', OUT)
