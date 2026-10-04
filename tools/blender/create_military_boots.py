import argparse
import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

# Builds the "military_boots" skinned mesh inside player_with_clothes.glb,
# starting from the cloth_feet survival boots. Adds combat-boot detail —
# lugged welt sole, toe cap, heel counter, padded collar, tongue, eyelets,
# crisscross laces, pull loop — stiffens the shaft so it follows the shin,
# marks material zones (leather/cordura/sole/metal/cap/lace/webbing) in a
# "Zone" vertex-color layer, bakes garment_mboots_* textures and exports
# pickup_military_boots.glb for world drops/thumbnails.

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "assets/characters/adapted/player_with_clothes.glb"
PICKUP = ROOT / "assets/characters/adapted/pickup_military_boots.glb"
OUT = ROOT / "assets/textures/clothing"
OUT.mkdir(parents=True, exist_ok=True)

parser = argparse.ArgumentParser()
parser.add_argument("--size", type=int, default=2048)
parser.add_argument("--no-export", action="store_true")
parser.add_argument("--no-bake", action="store_true")
parser.add_argument("--render", default="")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])

ZONE_LEATHER = 0.0
ZONE_CORDURA = 0.20
ZONE_SOLE = 0.40
ZONE_METAL = 0.55
ZONE_CAP = 0.70
ZONE_LACE = 0.85
ZONE_WEBBING = 1.0

ANKLE_Z = 0.247          # LeftFoot/RightFoot bone head height (bind space)
SHAFT_STIFF_Z = 0.34     # above this the shaft fully follows the shin

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(GLB))

src = bpy.data.objects["cloth_feet"]
mil = src.copy()
mil.data = src.data.copy()
mil.name = "military_boots"
for coll in src.users_collection:
    coll.objects.link(mil)

mw = mil.matrix_world.copy()
inv = mw.inverted()

me = mil.data
me.color_attributes.new("Zone", type="FLOAT_COLOR", domain="CORNER")

bm = bmesh.new()
bm.from_mesh(me)
uv_l = bm.loops.layers.uv.verify()
dl = bm.verts.layers.deform.verify()

vindex = {g.name: g.index for g in mil.vertex_groups}
FOOT = {1: vindex["mixamorig:LeftFoot"], -1: vindex["mixamorig:RightFoot"]}
LEG = {1: vindex["mixamorig:LeftLeg"], -1: vindex["mixamorig:RightLeg"]}

authored = []            # (center_local, zone, group) per authored face


def w(v):
    return mw @ v.co


def side_of(p):
    return 1 if p.x >= 0.0 else -1


def add_face(verts_local, zone, group, weight_fn=None):
    vs = [bm.verts.new(p) for p in verts_local]
    f = bm.faces.new(vs)
    c = Vector((0.0, 0.0, 0.0))
    for p in verts_local:
        c += p
    c /= len(verts_local)
    authored.append((c, zone, group))
    if weight_fn is not None:
        for v in vs:
            weight_fn(v)
    return f


def weight_feet(v):
    """Shaft follows the shin, everything below the ankle follows the foot."""
    p = w(v)
    s = side_of(p)
    v[dl].clear()
    if p.z > SHAFT_STIFF_Z:
        v[dl][LEG[s]] = 1.0
    elif p.z > ANKLE_Z:
        v[dl][LEG[s]] = 0.75
        v[dl][FOOT[s]] = 0.25
    else:
        v[dl][FOOT[s]] = 1.0


def weight_foot(v):
    p = w(v)
    v[dl].clear()
    v[dl][FOOT[side_of(p)]] = 1.0


def weight_leg(v):
    p = w(v)
    v[dl].clear()
    v[dl][LEG[side_of(p)]] = 1.0


# ---------------------------------------------------------------- landmarks
foot_pts = {1: [], -1: []}
for v in bm.verts:
    p = w(v)
    foot_pts[side_of(p)].append(p)

LAND = {}
for s in (1, -1):
    pts = foot_pts[s]
    low = [p for p in pts if p.z < 0.05]
    LAND[s] = {
        "cx": sum(p.x for p in pts) / len(pts),
        "toe_y": min(p.y for p in low),
        "heel_y": max(p.y for p in low),
        "top_z": max(p.z for p in pts),
    }
    print("LAND", s, {k: round(vv, 3) for k, vv in LAND[s].items()}, flush=True)

BASE_VERTS = set(bm.verts)


def front_y(side, x, z, pad=0.0):
    """Front (min-y) surface height of the base boot near (x,z)."""
    best = None
    for v in BASE_VERTS:
        p = w(v)
        if side_of(p) != side:
            continue
        if abs(p.x - x) < 0.022 and abs(p.z - z) < 0.02:
            best = p.y if best is None else min(best, p.y)
    return (best if best is not None else LAND[side]["toe_y"]) - pad


# ------------------------------------------------- reshape + reweight shaft
for v in bm.verts:
    p = w(v)
    s = side_of(p)
    cx = LAND[s]["cx"]
    if p.z > 0.16:
        f = 0.955 if p.z < 0.40 else 0.97     # snug military shaft
        p.x = cx + (p.x - cx) * f
        if p.z > 0.30:
            cy = (LAND[s]["toe_y"] + LAND[s]["heel_y"]) * 0.5
            p.y = cy + (p.y - cy) * 0.97
        v.co = inv @ p
    if p.z > SHAFT_STIFF_Z:
        v[dl].clear()
        v[dl][LEG[s]] = 1.0
    elif p.z > ANKLE_Z + 0.03:
        keep = {}
        for gi, wt in v[dl].items():
            if gi == LEG[s]:
                keep[gi] = max(wt, 0.70)
            elif gi == FOOT[s]:
                keep[gi] = min(wt, 0.30)
            else:
                keep[gi] = wt
        total = sum(keep.values()) or 1.0
        v[dl].clear()
        for gi, wt in keep.items():
            v[dl][gi] = wt / total

bm.normal_update()


# ------------------------------------------------------------- primitives
def tube(p0, p1, r, sides=5):
    t = (p1 - p0).normalized()
    helper = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((0, 1, 0))
    u = t.cross(helper).normalized()
    vd = t.cross(u).normalized()
    rings = []
    for c in (p0, p1):
        ring = []
        for i in range(sides):
            a = 2 * math.pi * i / sides
            ring.append(c + r * (math.cos(a) * u + math.sin(a) * vd))
        rings.append(ring)
    return rings


def add_tube(pts, r, zone, group, weight_fn, sides=5):
    for i in range(len(pts) - 1):
        r0, r1 = tube(pts[i], pts[i + 1], r, sides)
        for j in range(sides):
            add_face([inv @ r0[j], inv @ r0[(j + 1) % sides],
                      inv @ r1[(j + 1) % sides], inv @ r1[j]], zone, group, weight_fn)


def add_annulus(center, normal, r_in, r_out, zone, group, weight_fn, n=10):
    helper = Vector((0, 0, 1)) if abs(normal.z) < 0.9 else Vector((0, 1, 0))
    u = normal.cross(helper).normalized()
    vd = normal.cross(u).normalized()
    for i in range(n):
        a0, a1 = 2 * math.pi * i / n, 2 * math.pi * (i + 1) / n
        o0 = center + r_out * (math.cos(a0) * u + math.sin(a0) * vd)
        o1 = center + r_out * (math.cos(a1) * u + math.sin(a1) * vd)
        i1 = center + r_in * (math.cos(a1) * u + math.sin(a1) * vd)
        i0 = center + r_in * (math.cos(a0) * u + math.sin(a0) * vd)
        add_face([inv @ o0, inv @ o1, inv @ i1, inv @ i0], zone, group, weight_fn)


def outline_ring(side, zmax=0.05, samples=44):
    """Angular outline of one boot's footprint (world 2D)."""
    c = Vector((LAND[side]["cx"], (LAND[side]["toe_y"] + LAND[side]["heel_y"]) * 0.5))
    pts = [Vector((p.x, p.y)) for p in foot_pts[side] if p.z < zmax]
    ring = []
    for i in range(samples):
        a = 2 * math.pi * i / samples
        d = Vector((math.cos(a), math.sin(a)))
        best, best_t = c + d * 0.01, 0.0
        for p in pts:
            rel = p - c
            t = rel.dot(d)
            if t > best_t and rel.length > 0.01 and (rel.normalized() - d).length < 0.35:
                best_t, best = t, p
        ring.append(best)
    n = len(ring)
    return [(ring[(i - 1) % n] + 2 * ring[i] + ring[(i + 1) % n]) * 0.25 for i in range(n)]


def _local_center(verts):
    c = Vector((0.0, 0.0, 0.0))
    for v in verts:
        c += v.co
    return c / len(verts)


def _author_face(verts_bmesh, zone, group):
    f = bm.faces.new(verts_bmesh)
    authored.append((_local_center(verts_bmesh), zone, group))
    return f


def shell_from_region(side, pred, offset, group):
    """Duplicate faces in region as a raised shell, with a skirt along the
    boundary. Vertex weights copied from the source verts."""
    faces_sel = [f for f in bm.faces
                 if side_of(w(f.verts[0])) == side
                 and all(pred(w(v)) for v in f.verts)]
    if not faces_sel:
        return
    sel_set = set(faces_sel)
    src_vs = list({v for f in faces_sel for v in f.verts})
    off = {}
    for v in src_vs:
        n = Vector((0.0, 0.0, 0.0))
        for f in v.link_faces:
            n += mw.to_3x3() @ f.normal
        n.normalize()
        nv = bm.verts.new(v.co + inv.to_3x3() @ (n * offset))
        for gi, wt in v[dl].items():
            nv[dl][gi] = wt
        off[v] = nv
    for f in faces_sel:
        _author_face([off[v] for v in f.verts], ZONE_CAP, group)
        for e in f.edges:
            if sum(1 for lf in e.link_faces if lf in sel_set) == 1:
                a, b = e.verts
                _author_face([a, b, off[b], off[a]], ZONE_CAP, group)


# --------------------------------------------------------------- sole+welt
for s in (1, -1):
    l = LAND[s]
    cx = l["cx"]
    grp = "soleL" if s > 0 else "soleR"
    ring = outline_ring(s)
    n = len(ring)
    outw_ring = []
    for i in range(n):
        p0, p1 = ring[i], ring[(i + 1) % n]
        seg = (p1 - p0).normalized()
        outw = Vector((-seg.y, seg.x))
        if outw.dot(p0 - Vector((cx, 0))) < 0:
            outw = -outw
        outw_ring.append(outw)
        b0, b1 = p0 + outw * 0.0045, p1 + outw * 0.0045
        t0, t1 = p0 + outw * 0.0025, p1 + outw * 0.0025
        add_face([inv @ Vector((b0.x, b0.y, 0.004)), inv @ Vector((b1.x, b1.y, 0.004)),
                  inv @ Vector((t1.x, t1.y, 0.030)), inv @ Vector((t0.x, t0.y, 0.030))],
                 ZONE_SOLE, grp, weight_foot)
        # inner lip closing the welt against the upper
        i0, i1 = p0 - outw * 0.002, p1 - outw * 0.002
        add_face([inv @ Vector((i0.x, i0.y, 0.004)), inv @ Vector((i1.x, i1.y, 0.004)),
                  inv @ Vector((b1.x, b1.y, 0.004)), inv @ Vector((b0.x, b0.y, 0.004))],
                 ZONE_SOLE, grp, weight_foot)
    # heel breast: taller stacked heel across the back arc
    back = [(ring[i], outw_ring[i]) for i in range(n) if ring[i].y > l["heel_y"] - 0.045]
    for i in range(len(back) - 1):
        p0, o0 = back[i]
        p1, _o1 = back[i + 1]
        add_face([inv @ Vector((p0.x + o0.x * 0.0025, p0.y + o0.y * 0.0025, 0.030)),
                  inv @ Vector((p1.x + o0.x * 0.0025, p1.y + o0.y * 0.0025, 0.030)),
                  inv @ Vector((p1.x + o0.x * 0.0008, p1.y + o0.y * 0.0008, 0.052)),
                  inv @ Vector((p0.x + o0.x * 0.0008, p0.y + o0.y * 0.0008, 0.052))],
                 ZONE_SOLE, grp, weight_foot)
    # lugs: chunky tread blocks around the perimeter
    step = 3
    for i in range(0, n - step, step):
        p0, p1 = ring[i], ring[(i + step) % n]
        seg = (p1 - p0).normalized()
        outw = Vector((-seg.y, seg.x))
        if outw.dot(p0 - Vector((cx, 0))) < 0:
            outw = -outw
        m = (p0 + p1) * 0.5 + outw * 0.002
        hw = seg * 0.0055
        bw = [m - hw + outw * 0.0015, m + hw + outw * 0.0015,
              m + hw + outw * 0.0075, m - hw + outw * 0.0075]
        vb = [Vector((p.x, p.y, 0.002)) for p in bw]
        vt = [Vector((bw[0].x, bw[0].y, 0.022)), Vector((bw[1].x, bw[1].y, 0.022)),
              Vector((m.x + hw.x + outw.x * 0.0025, m.y + hw.y + outw.y * 0.0025, 0.010)),
              Vector((m.x - hw.x + outw.x * 0.0025, m.y - hw.y + outw.y * 0.0025, 0.010))]
        vv = vb + vt
        for q in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2),
                  (2, 6, 7, 3), (3, 7, 4, 0)]:
            add_face([inv @ vv[k] for k in q], ZONE_SOLE, "lug", weight_foot)


# ----------------------------------------------------------- caps + collar
for s in (1, -1):
    l = LAND[s]
    capg = "capL" if s > 0 else "capR"
    toe_line = l["heel_y"] + (l["toe_y"] - l["heel_y"]) * 0.40
    shell_from_region(s, lambda p, tl=toe_line: p.z < 0.085 and p.y < tl, 0.0045, capg)
    # heel counter is only the low back cup — higher would step the silhouette
    shell_from_region(s, lambda p, hy=l["heel_y"]: 0.012 < p.z < 0.13 and p.y > hy - 0.05, 0.0035, capg)

    # padded collar roll around the shaft opening
    cy = (l["toe_y"] + l["heel_y"]) * 0.5
    top = [v for v in BASE_VERTS
           if side_of(w(v)) == s and w(v).z > l["top_z"] - 0.012]
    ring_pts = sorted((w(v) for v in top),
                      key=lambda p: math.atan2(p.y - cy, p.x - l["cx"]))
    m = len(ring_pts)
    for i in range(m):
        a0, a1 = ring_pts[i], ring_pts[(i + 1) % m]
        c = Vector((l["cx"], cy))
        o0 = (Vector((a0.x, a0.y)) - c).normalized()
        o1 = (Vector((a1.x, a1.y)) - c).normalized()
        lo0 = Vector((a0.x + o0.x * 0.006, a0.y + o0.y * 0.006, a0.z + 0.002))
        lo1 = Vector((a1.x + o1.x * 0.006, a1.y + o1.y * 0.006, a1.z + 0.002))
        hi0 = Vector((a0.x + o0.x * 0.002, a0.y + o0.y * 0.002, a0.z + 0.012))
        hi1 = Vector((a1.x + o1.x * 0.002, a1.y + o1.y * 0.002, a1.z + 0.012))
        add_face([inv @ lo0, inv @ lo1, inv @ hi1, inv @ hi0], ZONE_CORDURA, "collar", weight_leg)
    # pull loop at the back of the collar
    hy = l["heel_y"]
    lw = 0.007
    lz = l["top_z"]
    for k in range(2):
        x = l["cx"] - lw + 2 * lw * k
        x2 = x + lw
        add_face([inv @ Vector((x, hy + 0.001, lz - 0.006)),
                  inv @ Vector((x2, hy + 0.001, lz - 0.006)),
                  inv @ Vector((x2, hy + 0.008, lz + 0.012)),
                  inv @ Vector((x, hy + 0.008, lz + 0.012))], ZONE_WEBBING, "loop", weight_leg)
        add_face([inv @ Vector((x, hy + 0.008, lz + 0.012)),
                  inv @ Vector((x2, hy + 0.008, lz + 0.012)),
                  inv @ Vector((x2, hy + 0.002, lz + 0.022)),
                  inv @ Vector((x, hy + 0.002, lz + 0.022))], ZONE_WEBBING, "loop", weight_leg)


# ------------------------------------------------------ tongue/eyes/laces
for s in (1, -1):
    l = LAND[s]
    cx = l["cx"]
    top = l["top_z"]
    # narrow tongue ribbon — the laces cover most of it
    rows = 7
    for i in range(rows - 1):
        z0 = 0.10 + (top + 0.004 - 0.10) * i / (rows - 1)
        z1 = 0.10 + (top + 0.004 - 0.10) * (i + 1) / (rows - 1)
        wdt0 = 0.021 - 0.004 * (z0 / top)
        wdt1 = 0.021 - 0.004 * (z1 / top)
        y0 = front_y(s, cx, z0, 0.0006)
        y1 = front_y(s, cx, z1, 0.0006)
        add_face([inv @ Vector((cx - wdt0, y0, z0)), inv @ Vector((cx + wdt0, y0, z0)),
                  inv @ Vector((cx + wdt1, y1, z1)), inv @ Vector((cx - wdt1, y1, z1))],
                 ZONE_LEATHER, "tongue", weight_feet)
    # eyelet pairs flanking the tongue (8 rows like an 8-inch combat boot)
    eye = {-1: [], 1: []}
    n_eye = 8
    for i in range(n_eye):
        z_i = 0.155 + (top - 0.032 - 0.155) * i / (n_eye - 1)
        for sd in (-1, 1):
            x_i = cx + sd * 0.0195
            y_i = front_y(s, x_i, z_i, 0.0030)
            c = Vector((x_i, y_i, z_i))
            eye[sd].append(c)
            add_annulus(c, Vector((0, -1, 0)), 0.0016, 0.0033, ZONE_METAL, "eye", weight_feet, 10)
    # straight bar across the bottom pair, then crisscross laces
    pa, pb = eye[-1][0], eye[1][0]
    mid = (pa + pb) * 0.5 + Vector((0, -0.005, 0))
    add_tube([pa, mid, pb], 0.0017, ZONE_LACE, "lace", weight_feet, 5)
    for i in range(n_eye - 1):
        for a, b in ((-1, 1), (1, -1)):
            pa, pb = eye[a][i], eye[b][i + 1]
            mid = (pa + pb) * 0.5 + Vector((0, -0.0050, 0))
            add_tube([pa, mid, pb], 0.0017, ZONE_LACE, "lace", weight_feet, 5)
    # knot + bow loops + dangling tails at the top pair
    tl, tr = eye[-1][n_eye - 1], eye[1][n_eye - 1]
    knot = (tl + tr) * 0.5 + Vector((0, -0.006, 0.004))
    add_tube([tl, knot, tr], 0.0020, ZONE_LACE, "lace", weight_leg, 5)
    for sd in (-1, 1):
        add_tube([knot, knot + Vector((sd * 0.019, -0.009, 0.004)),
                  knot + Vector((sd * 0.017, -0.006, -0.010))], 0.0016, ZONE_LACE, "lace", weight_leg, 5)
        add_tube([knot, knot + Vector((sd * 0.008, -0.007, -0.015)),
                  knot + Vector((sd * 0.006, -0.004, -0.030))], 0.0016, ZONE_LACE, "lace", weight_leg, 5)

bm.normal_update()

# Weld coincident authored verts so tubes/lugs read smooth and pack as
# islands instead of per-face confetti (0.02 local units ≈ 0.25 mm).
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.02)
bm.to_mesh(me)
bm.free()

# --------------------------------------------------------- zone assignment
# Spatial hash of authored face centers -> (zone, group); a mesh face matches
# when its center lands within one grid cell of an authored mark.
_CELL = 0.08
_mark_grid = {}
for mc, zone, grp in authored:
    key = (round(mc.x / _CELL), round(mc.y / _CELL), round(mc.z / _CELL))
    _mark_grid.setdefault(key, []).append((mc, zone, grp))


zc_attr = me.color_attributes["Zone"]
face_info = {}      # poly.index -> (zone, group)
for poly in me.polygons:
    c = Vector((0.0, 0.0, 0.0))
    for vi in poly.vertices:
        c += me.vertices[vi].co
    c /= len(poly.vertices)
    key = (round(c.x / _CELL), round(c.y / _CELL), round(c.z / _CELL))
    best, bd = None, _CELL * 1.6
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            for dz in (-1, 0, 1):
                for mc, zone, grp in _mark_grid.get((key[0] + dx, key[1] + dy, key[2] + dz), []):
                    d = (c - mc).length
                    if d < bd:
                        best, bd = (zone, grp), d
    if best is not None:
        zone, grp = best
    else:
        pts = [mw @ me.vertices[vi].co for vi in poly.vertices]
        zc = sum(p.z for p in pts) / len(pts)
        yc = sum(p.y for p in pts) / len(pts)
        l = LAND[side_of(pts[0])]
        if zc > 0.30 and yc > (l["toe_y"] + l["heel_y"]) * 0.5 + 0.02:
            zone, grp = ZONE_CORDURA, "base"
        else:
            zone, grp = ZONE_LEATHER, "base"
    face_info[poly.index] = (zone, grp)
    for li in poly.loop_indices:
        zc_attr.data[li].color = (zone, zone, zone, 1.0)

# --------------------------------------------------------------- UV layout
# Project authored faces into per-group rects, then pack all islands so
# nothing overlaps the copied boot layout.
uv_attr = me.uv_layers.active
groups = {}
for poly in me.polygons:
    zone, grp = face_info[poly.index]
    if grp == "base":
        continue
    groups.setdefault(grp, []).append(poly)
# spread each group's faces over its own rect in the strip, then repack
rects = {
    "soleL": (0.02, 0.02, 0.20, 0.30), "soleR": (0.22, 0.02, 0.20, 0.30),
    "lug": (0.44, 0.02, 0.14, 0.20),
    "capL": (0.02, 0.34, 0.18, 0.24), "capR": (0.22, 0.34, 0.18, 0.24),
    "collar": (0.60, 0.02, 0.16, 0.16), "loop": (0.78, 0.02, 0.10, 0.10),
    "tongue": (0.42, 0.26, 0.14, 0.30), "eye": (0.78, 0.14, 0.10, 0.24),
    "lace": (0.60, 0.20, 0.16, 0.34),
}
for grp, faces in groups.items():
    rx, ry, rw, rh = rects.get(grp, (0.90, 0.60, 0.08, 0.30))
    for i, poly in enumerate(faces):
        # small per-face offset inside the rect keeps adjacent faces apart
        cols = max(1, int(math.sqrt(len(faces))))
        ox = (i % cols) * 0.004
        oy = (i // cols) * 0.004
        pts = [mw @ me.vertices[vi].co for vi in poly.vertices]
        us = [p.x for p in pts]
        vs = [p.z * 0.6 + p.y * 0.4 for p in pts]
        du = (max(us) - min(us)) or 1.0
        dv = (max(vs) - min(vs)) or 1.0
        for li, p in zip(poly.loop_indices, pts):
            uv_attr.data[li].uv = (
                rx + ox + (p.x - min(us)) / du * rw * 0.8,
                ry + oy + ((p.z * 0.6 + p.y * 0.4) - min(vs)) / dv * rh * 0.8)

mil.select_set(True)
bpy.context.view_layer.objects.active = mil
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.pack_islands(margin=0.006)
bpy.ops.object.mode_set(mode='OBJECT')
mil.select_set(False)
me.update()
print("MIL_VERTS", len(me.vertices), "FACES", len(me.polygons), flush=True)


# ------------------------------------------------------------------- bake
def node(tree, kind, **props):
    n_ = tree.nodes.new(kind)
    for k, v_ in props.items():
        setattr(n_, k, v_)
    return n_


def put(tree, socket, value):
    if isinstance(value, bpy.types.NodeSocket):
        tree.links.new(value, socket)
    else:
        socket.default_value = value


def calc(tree, op, a, b=0):
    n_ = node(tree, "ShaderNodeMath", operation=op)
    put(tree, n_.inputs[0], a)
    put(tree, n_.inputs[1], b)
    return n_.outputs[0]


def ramp(tree, value, stops):
    n_ = node(tree, "ShaderNodeValToRGB")
    n_.color_ramp.interpolation = "EASE"
    for i, (pos, col) in enumerate(stops):
        e = n_.color_ramp.elements[i] if i < 2 else n_.color_ramp.elements.new(pos)
        e.position = pos
        e.color = (*col, 1) if len(col) == 3 else col
    put(tree, n_.inputs[0], value)
    return n_.outputs[0]


def mixf(tree, fac, a, b, mode="MIX"):
    n_ = node(tree, "ShaderNodeMixRGB", blend_type=mode)
    put(tree, n_.inputs[0], fac)
    put(tree, n_.inputs[1], a)
    put(tree, n_.inputs[2], b)
    return n_.outputs[0]


def noise(tree, vec, scale, detail=4):
    n_ = node(tree, "ShaderNodeTexNoise")
    put(tree, n_.inputs["Vector"], vec)
    n_.inputs["Scale"].default_value = scale
    n_.inputs["Detail"].default_value = detail
    n_.inputs["Roughness"].default_value = 0.72
    return n_.outputs["Fac"]


def wave(tree, vec, scale, distortion=0.0, bands="X"):
    n_ = node(tree, "ShaderNodeTexWave", wave_type="BANDS", bands_direction=bands, wave_profile="SIN")
    put(tree, n_.inputs["Vector"], vec)
    n_.inputs["Scale"].default_value = scale
    n_.inputs["Distortion"].default_value = distortion
    if distortion > 0.0:
        n_.inputs["Detail"].default_value = 2.0
    return n_.outputs["Color"]


def bake_all():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
    scene.render.bake.margin = 24
    scene.view_settings.view_transform = "Standard"
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = False

    mat = bpy.data.materials.new("Bake_military_boots")
    mat.use_nodes = True
    mil.data.materials.clear()
    mil.data.materials.append(mat)
    tree = mat.node_tree
    tree.nodes.clear()
    output = node(tree, "ShaderNodeOutputMaterial")
    emission = node(tree, "ShaderNodeEmission")
    tree.links.new(emission.outputs[0], output.inputs["Surface"])
    uv = node(tree, "ShaderNodeTexCoord").outputs["UV"]
    gen = node(tree, "ShaderNodeTexCoord").outputs["Generated"]

    zattr = node(tree, "ShaderNodeVertexColor", layer_name="Zone")
    zone = zattr.outputs["Color"]

    def is_zone(zv):
        return calc(tree, "MULTIPLY",
                    calc(tree, "GREATER_THAN", zone, zv - 0.08),
                    calc(tree, "LESS_THAN", zone, zv + 0.08))
    m_cord = is_zone(ZONE_CORDURA)
    m_sole = is_zone(ZONE_SOLE)
    m_metal = is_zone(ZONE_METAL)
    m_cap = is_zone(ZONE_CAP)
    m_lace = is_zone(ZONE_LACE)
    m_web = is_zone(ZONE_WEBBING)

    fiber = noise(tree, uv, 260, 3)
    cells = node(tree, "ShaderNodeTexVoronoi", distance="EUCLIDEAN", feature="DISTANCE_TO_EDGE")
    put(tree, cells.inputs["Vector"], uv)
    cells.inputs["Scale"].default_value = 46.0
    pebble = ramp(tree, cells.outputs["Distance"], [(0.010, (1, 1, 1)), (0.045, (0.25, 0.25, 0.25))])
    warp = wave(tree, uv, 190, 3.0, "X")
    weft = wave(tree, uv, 190, 3.0, "Y")
    weave = calc(tree, "MAXIMUM", warp, weft)
    wear = noise(tree, uv, 2.8, 4)
    wear_mask = ramp(tree, wear, [(0.30, (0.80, 0.79, 0.77)), (0.62, (1, 1, 1))])
    scuff = ramp(tree, noise(tree, gen, 5.0, 3), [(0.45, (0.0,) * 3), (0.75, (1.0,) * 3)])

    # light garment-style albedo; the game tints it olive-black
    color = ramp(tree, noise(tree, uv, 3.2, 4), [(0.2, (0.80, 0.79, 0.76)), (0.8, (0.95, 0.94, 0.91))])
    color = mixf(tree, 0.20, color, ramp(tree, pebble, [(0.2, (0.82,) * 3), (0.8, (1, 1, 1))]), "MULTIPLY")
    color = mixf(tree, m_cord, color, mixf(tree, 0.35, (0.80, 0.79, 0.74, 1), weave, "MULTIPLY"))
    color = mixf(tree, m_sole, color, (0.42, 0.41, 0.38, 1))
    color = mixf(tree, m_metal, color, (0.58, 0.58, 0.62, 1))
    color = mixf(tree, m_cap, color, (0.80, 0.79, 0.76, 1))
    color = mixf(tree, m_lace, color, (0.38, 0.36, 0.33, 1))
    color = mixf(tree, m_web, color, (0.55, 0.52, 0.48, 1))
    color = mixf(tree, 0.45, color, wear_mask, "MULTIPLY")
    # toe-cap scuffing reads brighter on the raised shell
    color = mixf(tree, calc(tree, "MULTIPLY", m_cap, scuff), color, (0.98, 0.96, 0.90, 1))

    height = mixf(tree, 0.34, pebble, fiber)
    height = mixf(tree, m_cord, height, mixf(tree, 0.30, weave, fiber))
    tread = calc(tree, "MULTIPLY", wave(tree, gen, 30, 0, "X"), wave(tree, gen, 26, 0, "Z"))
    height = mixf(tree, m_sole, height, tread)
    height = mixf(tree, m_metal, height, (0.35, 0.35, 0.35, 1))

    roughness = ramp(tree, fiber, [(0.2, (0.55,) * 3), (0.8, (0.75,) * 3)])
    roughness = mixf(tree, m_cord, roughness, (0.90, 0.90, 0.90, 1))
    roughness = mixf(tree, m_sole, roughness, (0.94, 0.94, 0.94, 1))
    roughness = mixf(tree, m_metal, roughness, (0.32, 0.32, 0.32, 1))
    roughness = mixf(tree, m_lace, roughness, (0.88, 0.88, 0.88, 1))
    roughness = mixf(tree, m_web, roughness, (0.90, 0.90, 0.90, 1))

    target_node = node(tree, "ShaderNodeTexImage")
    size = args.size

    def emit(img, val, name):
        put(tree, emission.inputs["Color"], val)
        target_node.image = img
        tree.nodes.active = target_node
        bpy.ops.object.select_all(action="DESELECT")
        mil.select_set(True)
        bpy.context.view_layer.objects.active = mil
        bpy.ops.object.bake(type="EMIT")
        img.filepath_raw = str(OUT / name)
        img.file_format = "PNG"
        img.save()

    tgt = bpy.data.images.new("bake_mboots", width=size, height=size, alpha=False)
    emit(tgt, color, "garment_mboots_albedo.png")
    emit(tgt, height, "garment_mboots_height.png")
    emit(tgt, roughness, "garment_mboots_roughness.png")

    nrm = bpy.data.images.new("n_mboots", width=size, height=size, alpha=True)
    nrm.colorspace_settings.name = "Non-Color"
    bsdf = node(tree, "ShaderNodeBsdfPrincipled")
    put(tree, bsdf.inputs["Base Color"], color)
    put(tree, bsdf.inputs["Roughness"], roughness)
    bump = node(tree, "ShaderNodeBump")
    put(tree, bump.inputs["Height"], height)
    bump.inputs["Strength"].default_value = 0.30
    bump.inputs["Distance"].default_value = 0.025
    put(tree, bsdf.inputs["Normal"], bump.outputs[0])
    put(tree, output.inputs["Surface"], bsdf.outputs[0])
    target_node.image = nrm
    tree.nodes.active = target_node
    bpy.ops.object.select_all(action="DESELECT")
    mil.select_set(True)
    bpy.context.view_layer.objects.active = mil
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT")
    nrm.filepath_raw = str(OUT / "garment_mboots_normal.png")
    nrm.file_format = "PNG"
    nrm.save()

    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o is not mil
    ao = bpy.data.images.new("ao_mboots", width=size, height=size, alpha=False)
    ao.colorspace_settings.name = "Non-Color"
    target_node.image = ao
    bpy.ops.object.bake(type="AO", margin=scene.render.bake.margin)
    px = np.empty(size * size * 4, dtype=np.float32)
    ao.pixels.foreach_get(px)
    px = px.reshape(-1, 4)
    px[:, :3] = 0.62 + 0.38 * px[:, :3]
    ao.pixels.foreach_set(px.ravel())
    ao.filepath_raw = str(OUT / "garment_mboots_ao.png")
    ao.file_format = "PNG"
    ao.save()
    print("BAKED garment_mboots_*", flush=True)


if not args.no_bake:
    bake_all()

# -------------------------------------------------------------- export GLB
if not args.no_export:
    mil.data.materials.clear()
    if len(src.data.materials):
        mil.data.materials.append(src.data.materials[0])
    bpy.ops.export_scene.gltf(
        filepath=str(GLB),
        export_format="GLB",
        export_yup=True,
        export_apply=False,
        export_animations=True,
        export_skins=True,
        export_morph=True,
    )
    print("EXPORTED", GLB, flush=True)

    # pickup pair for world drops / inventory thumbnails (rigid copy)
    bpy.ops.object.select_all(action="DESELECT")
    pick = mil.copy()
    pick.data = mil.data.copy()
    pick.name = "boots_pickup"
    pick.parent = None
    pick.matrix_world = Matrix.Identity(4)
    # bake the pair to real meters so Godot reads the same ~0.45 m size
    pick.data.transform(mw)
    pick.vertex_groups.clear()
    pick.modifiers.clear()
    for coll in mil.users_collection:
        coll.objects.link(pick)
    pmat = bpy.data.materials.new("MilitaryBoots")
    pmat.use_nodes = True
    pbsdf = pmat.node_tree.nodes.get("Principled BSDF")
    tex = pmat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(str(OUT / "garment_mboots_albedo.png"))
    pmat.node_tree.links.new(tex.outputs["Color"], pbsdf.inputs["Base Color"])
    pbsdf.inputs["Roughness"].default_value = 0.8
    pick.data.materials.clear()
    pick.data.materials.append(pmat)
    pick.select_set(True)
    bpy.context.view_layer.objects.active = pick
    bpy.ops.export_scene.gltf(
        filepath=str(PICKUP),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_skins=False,
        export_animations=False,
    )
    bpy.data.objects.remove(pick)
    print("EXPORTED", PICKUP, flush=True)

# ------------------------------------------------------------------ render
if args.render:
    scene = bpy.context.scene
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o is not mil
    rmat = bpy.data.materials.new("RenderMil")
    rmat.use_nodes = True
    rbsdf = rmat.node_tree.nodes.get("Principled BSDF")
    rtex = rmat.node_tree.nodes.new("ShaderNodeTexImage")
    rtex.image = bpy.data.images.load(str(OUT / "garment_mboots_albedo.png"))
    rnt = rmat.node_tree.nodes.new("ShaderNodeTexImage")
    rnt.image = bpy.data.images.load(str(OUT / "garment_mboots_normal.png"))
    rnt.image.colorspace_settings.name = "Non-Color"
    rnmap = rmat.node_tree.nodes.new("ShaderNodeNormalMap")
    rmat.node_tree.links.new(rnt.outputs["Color"], rnmap.inputs["Color"])
    rmat.node_tree.links.new(rnmap.outputs["Normal"], rbsdf.inputs["Normal"])
    # same olive-black tint the game applies via SURVIVAL_CLOTHING
    rmix = rmat.node_tree.nodes.new("ShaderNodeMixRGB")
    rmix.blend_type = "MULTIPLY"
    rmix.inputs["Fac"].default_value = 1.0
    rmix.inputs[2].default_value = (0.10, 0.10, 0.075, 1.0)
    rmat.node_tree.links.new(rtex.outputs["Color"], rmix.inputs[1])
    rmat.node_tree.links.new(rmix.outputs[0], rbsdf.inputs["Base Color"])
    rrgh = rmat.node_tree.nodes.new("ShaderNodeTexImage")
    rrgh.image = bpy.data.images.load(str(OUT / "garment_mboots_roughness.png"))
    rrgh.image.colorspace_settings.name = "Non-Color"
    rmat.node_tree.links.new(rrgh.outputs["Color"], rbsdf.inputs["Roughness"])
    mil.data.materials.clear()
    mil.data.materials.append(rmat)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    cam.location = (0.80, -1.05, 0.52)
    cam.rotation_euler = (math.radians(72), 0, math.radians(36))
    scene.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("W")
    world.color = (0.05, 0.05, 0.06)
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 800
    scene.render.filepath = args.render
    bpy.ops.render.render(write_still=True)
    print("RENDERED", args.render, flush=True)

print("DONE", flush=True)
