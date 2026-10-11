"""Post-apocalyptic interior kit for the city block houses.

Run: Blender --background --python tools/blender/create_city_interior_kit.py

1. Procedural textures (numpy) -> assets/textures/city_interior/
   ruined wallpaper (4 variants), dirty floorboards, stained ceiling, floor
   litter (RGBA), curtain fabric, cardboard.
2. Furniture kit -> assets/models/environment/city/interior_kit/*.glb
   Village house props normalised to real size, tinylivingpack pieces aged
   (desaturated, grime, stains, dust baked into their textures), plus torn
   curtains, garbage bags and cardboard boxes.
Every kit GLB: one mesh, origin at floor centre, front facing Blender -Y
(Godot +Z), transforms applied.
"""
import bpy, bmesh, math, random
import numpy as np
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TEX = ROOT / 'assets/textures/city_interior'
KIT = ROOT / 'assets/models/environment/city/interior_kit'
TEX.mkdir(parents=True, exist_ok=True)
KIT.mkdir(parents=True, exist_ok=True)
PROPS = ROOT / 'assets/models/props'
ROOT_GLB = ROOT / 'assets/external/realistic/root_glb'

# ---------------------------------------------------------------- noise ----
def vnoise(n, cells, rng):
	g = rng.random((cells, cells))
	t = np.arange(n) * cells / n
	i0 = t.astype(int); f = t - i0; f = f * f * (3 - 2 * f); i1 = (i0 + 1) % cells
	a = g[np.ix_(i0, i0)]; b = g[np.ix_(i0, i1)]; c = g[np.ix_(i1, i0)]; d = g[np.ix_(i1, i1)]
	fx = f[None, :]; fy = f[:, None]
	return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def fbm(n, cells, rng, octaves=5):
	out = np.zeros((n, n)); amp = 1.0; tot = 0.0
	for o in range(octaves):
		if cells * 2 ** o > n: break
		out += vnoise(n, cells * 2 ** o, rng) * amp; tot += amp; amp *= .5
	out /= tot
	# Stretch to 0..1 so thresholds mean the same thing at every scale.
	return (out - out.min()) / max(out.max() - out.min(), 1e-6)

def save_png(name, rgb, alpha=None):
	n = rgb.shape[0]
	img = bpy.data.images.new(name, rgb.shape[1], n, alpha=True)
	a = np.ones((n, rgb.shape[1], 1)) if alpha is None else alpha[..., None]
	px = np.concatenate([np.clip(rgb, 0, 1), np.clip(a, 0, 1)], axis=2)[::-1].astype(np.float32)
	img.pixels.foreach_set(px.ravel())
	img.filepath_raw = str(TEX / (name + '.png')); img.file_format = 'PNG'; img.save()
	return img

def grid(n):
	v, u = np.mgrid[0:n, 0:n] / n
	return u, v  # v = 0 at the TOP row (image space)

# -------------------------------------------------------------- textures ---
def wallpaper(k, base, ink):
	n = 1024; rng = np.random.default_rng(100 + k); u, v = grid(n)
	base = np.array(base); ink = np.array(ink)
	cols = 10
	du = np.abs((u * cols) % 1 - .5)
	dv = np.abs((v * 7 + (np.floor(u * cols) % 2) * .5) % 1 - .5)
	if k % 2 == 0:
		motif = np.clip(1 - (du * 2.0 + dv * 1.5) / .5, 0, 1)            # diamonds
	else:
		motif = np.clip(1 - np.hypot(du * 2.2, dv * 1.5) / .3, 0, 1)      # rosettes
	stripe = ((np.sin(u * 2 * np.pi * cols) > .93) * .8)
	pat = np.clip(motif + stripe, 0, 1)[..., None]
	rgb = base * (1 - pat * .85) + ink * pat * .85
	g = fbm(n, 4, rng)
	rgb = rgb * (.80 + .26 * g)[..., None]                                  # uneven fading
	edge = fbm(n, 8, rng)
	# Rising damp from the floor (image bottom = floor) with a dark tide rim.
	line = .60 + (edge - .5) * .22
	damp = np.clip((v - line) / .06, 0, 1)
	stain = np.array([.36, .27, .15])
	rgb = rgb * (1 - damp[..., None] * .55) + rgb * stain * 1.4 * damp[..., None] * .55
	rgb *= (1 - np.exp(-((v - line) / .012) ** 2) * .25)[..., None]
	# Leak streaks running down from the ceiling.
	streak = np.clip((fbm(n, 16, rng, 2) - .62) * 6, 0, 1) * np.clip((.55 - v) * 2, 0, 1) * (vnoise(n, 32, rng) > .55)
	rgb *= (1 - streak[..., None] * .35)
	# Peeled sheets revealing grey plaster, with shadowed curled edges.
	p = fbm(n, 5, rng)
	peel = p > .80; curl = (p > .785) & ~peel
	plaster = np.array([.52, .49, .42]) * (.85 + .25 * fbm(n, 64, rng, 2))[..., None]
	rgb = np.where(peel[..., None], plaster, rgb)
	rgb = np.where(curl[..., None], rgb * .78, rgb)
	# Black mould speckles in the damp zones.
	mould = (fbm(n, 64, rng, 3) > .80) & (damp > .5) & (fbm(n, 6, rng) > .55)
	rgb = np.where(mould[..., None], rgb * np.array([.45, .50, .40]), rgb)
	save_png('wallpaper_ruin_%d' % k, rgb)

def floorboards():
	n = 1024; rng = np.random.default_rng(7); u, v = grid(n)
	planks = 14
	row = np.floor(v * planks).astype(int)
	offs = rng.random(planks)
	seg = np.floor(u * 2.5 + offs[row]).astype(int)
	pid = (row * 7 + seg) % 256
	tone = rng.random(256)[pid]; phase = rng.random(256)[pid]
	low = fbm(n, 4, rng)
	grain = .5 + .5 * np.sin(2 * np.pi * (v * planks * 5 + low * 4 + phase * 3))
	c0 = np.array([.40, .27, .16]); c1 = np.array([.26, .17, .10])
	rgb = c0 * (1 - tone[..., None]) + c1 * tone[..., None]
	rgb *= (.86 + .2 * grain)[..., None]
	fv = (v * planks) % 1; fu = (u * 2.5 + offs[row]) % 1
	seam = (fv < .045) | (fv > .955) | (fu < .006)
	rgb = np.where(seam[..., None], rgb * .3, rgb)
	rgb *= (.55 + .55 * fbm(n, 6, rng))[..., None]                          # grime
	dust = np.clip((fbm(n, 8, rng) - .45) * 2.2, 0, 1)[..., None] * .55
	rgb = rgb * (1 - dust) + np.array([.40, .38, .34]) * dust
	stain = fbm(n, 24, rng, 3) > .82
	rgb = np.where(stain[..., None], rgb * .6, rgb)
	save_png('floor_ruin', rgb)

def ceiling():
	n = 1024; rng = np.random.default_rng(11); u, v = grid(n)
	rgb = np.array([.70, .68, .62]) * (.82 + .25 * fbm(n, 32, rng, 3))[..., None]
	# Soft yellow-brown water marks (gradual, not flat blobs) and hairline cracks.
	s = fbm(n, 5, rng)
	wet = np.clip((s - .62) / .2, 0, 1)[..., None]
	rgb = rgb * (1 - wet * .35) + rgb * np.array([.85, .74, .55]) * wet * .35
	rgb *= (1 - np.exp(-((s - .66) / .006) ** 2) * .18)[..., None]
	crack = np.abs(fbm(n, 6, rng, 4) - .5) < .0025
	rgb = np.where(crack[..., None], rgb * .55, rgb)
	fallen = fbm(n, 8, rng) > .9
	rgb = np.where(fallen[..., None], rgb * .72, rgb)
	save_png('ceiling_ruin', rgb)

def facade(k, base):
	# Clean lime plaster: fine grain and a gentle fade, no peeled/blob patches —
	# the decay on the facades comes from geometry (breaches, boards) and the
	# moss/ivy meshes, not from the albedo.
	n = 1024; rng = np.random.default_rng(50 + k); u, v = grid(n)
	rgb = np.array(base) * (.93 + .10 * fbm(n, 64, rng, 3))[..., None]
	rgb *= (.95 + .08 * fbm(n, 4, rng))[..., None]
	# Faint vertical weathering so large walls are not perfectly flat.
	streak = np.clip((fbm(n, 96, rng, 2) - .72) * 8, 0, 1) * (vnoise(n, 24, rng) > .6)
	rgb *= (1 - streak[..., None] * .10)
	save_png('facade_lime_%d' % k, rgb)

def stamp_rect(rgb, alpha, cx, cy, w, h, ang, col, a=1.0, lines=False):
	n = rgb.shape[0]
	r = int(max(w, h) * n * .75) + 2
	x0, x1 = max(int(cx * n) - r, 0), min(int(cx * n) + r, n)
	y0, y1 = max(int(cy * n) - r, 0), min(int(cy * n) + r, n)
	if x1 <= x0 or y1 <= y0: return
	yy, xx = np.mgrid[y0:y1, x0:x1] / n
	dx = xx - cx; dy = yy - cy
	lx = dx * math.cos(ang) + dy * math.sin(ang); ly = -dx * math.sin(ang) + dy * math.cos(ang)
	m = (np.abs(lx) < w / 2) & (np.abs(ly) < h / 2)
	c = np.broadcast_to(np.array(col), m.shape + (3,)).copy()
	if lines:
		txt = ((ly / h * 22) % 1 < .32) & (np.abs(lx) < w * .38) & (np.abs(ly) < h * .4)
		c[txt] *= .62
	rgb[y0:y1, x0:x1][m] = c[m]
	alpha[y0:y1, x0:x1][m] = a

def litter():
	n = 1024; rng = np.random.default_rng(23); pr = random.Random(23)
	rgb = np.zeros((n, n, 3)); alpha = np.zeros((n, n))
	# Dirt film + small grit with soft-ish (dithered) edges.
	d = fbm(n, 6, rng); grit = vnoise(n, 256, rng)
	film = (d > .78) & (grit > .55)
	rgb[film] = np.array([.16, .13, .10]); alpha[film] = 1
	# Plaster flakes.
	for _ in range(260):
		col = pr.choice([(.66, .63, .56), (.55, .52, .46), (.72, .69, .60)])
		stamp_rect(rgb, alpha, pr.random(), pr.random(), pr.uniform(.006, .025), pr.uniform(.005, .02), pr.uniform(0, 3.14), col)
	# Dead leaves blown in.
	for _ in range(70):
		col = pr.choice([(.33, .22, .10), (.42, .30, .14), (.26, .19, .09)])
		stamp_rect(rgb, alpha, pr.random(), pr.random(), pr.uniform(.012, .022), pr.uniform(.006, .01), pr.uniform(0, 3.14), col)
	# Paper sheets, newspaper and wrappers.
	for _ in range(14):
		col = pr.choice([(.62, .60, .52), (.55, .53, .46), (.50, .46, .38), (.40, .32, .27)])
		w = pr.uniform(.045, .08)
		stamp_rect(rgb, alpha, pr.random(), pr.random(), w, w * pr.uniform(1.2, 1.45), pr.uniform(0, 3.14), col, lines=col[0] > .6)
	rgb *= (.75 + .35 * fbm(n, 16, rng, 3))[..., None]
	save_png('floor_litter', rgb, alpha)

def fabric():
	n = 512; rng = np.random.default_rng(31); u, v = grid(n)
	base = np.array([.66, .58, .40])
	flower = np.clip(1 - np.hypot(np.abs((u * 6) % 1 - .5), np.abs((v * 6 + (np.floor(u * 6) % 2) * .5) % 1 - .5)) / .18, 0, 1)
	rgb = base * (1 - flower[..., None] * .35) + np.array([.45, .30, .25]) * flower[..., None] * .35
	rgb *= (.7 + .4 * fbm(n, 4, rng))[..., None]
	rgb *= (1 - np.clip((v - .6) * 1.4, 0, 1) * .45)[..., None]   # dirt rising at the hem
	stain = fbm(n, 8, rng) > .7
	rgb = np.where(stain[..., None], rgb * np.array([.75, .65, .45]), rgb)
	save_png('curtain_fabric', rgb)

def cardboard():
	n = 512; rng = np.random.default_rng(37); u, v = grid(n)
	rgb = np.array([.50, .37, .22]) * (.8 + .3 * fbm(n, 8, rng))[..., None]
	rgb *= (.9 + .1 * np.sin(u * 2 * np.pi * 90))[..., None]
	tape = np.abs(v - .5) < .04
	rgb = np.where(tape[..., None], np.array([.62, .55, .38]), rgb)
	wet = fbm(n, 4, rng) > .68
	rgb = np.where(wet[..., None], rgb * .6, rgb)
	save_png('cardboard', rgb)

# ------------------------------------------------------------ kit helpers --
def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)

def import_glb(path):
	reset()
	bpy.ops.import_scene.gltf(filepath=str(path))
	return [o for o in bpy.context.scene.objects if o.type == 'MESH']

def material_images(objs):
	imgs = {}
	for o in objs:
		for slot in o.material_slots:
			m = slot.material
			if m is None or not m.use_nodes: continue
			for nd in m.node_tree.nodes:
				if nd.type == 'TEX_IMAGE' and nd.image is not None:
					imgs.setdefault(nd.image.name, []).append(nd)
	return imgs

def age_materials(objs, seed, strength=1.0, size=512):
	"""Bake neglect into every texture: desaturate, grime, stains, dust."""
	rng = np.random.default_rng(seed)
	for name, nodes in material_images(objs).items():
		src = nodes[0].image
		if src.size[0] == 0: continue
		im = src.copy(); im.name = 'aged_' + name
		im.scale(size, size)
		px = np.array(im.pixels[:], dtype=np.float32).reshape(size, size, 4)
		rgb = px[..., :3]
		lum = (rgb @ np.array([.3, .59, .11]))[..., None]
		rgb = rgb * (1 - .8 * strength) + lum * .8 * strength
		rgb = rgb * (.5 + .3 * fbm(size, 4, rng))[..., None] * np.array([1.0, .92, .78])
		rgb = rgb * (.85 + .2 * fbm(size, 64, rng, 2))[..., None]   # fine grime
		stain = fbm(size, 32, rng, 3) > .80
		rgb = np.where(stain[..., None], rgb * .78, rgb)
		dust = np.clip((fbm(size, 8, rng) - .5) * 2, 0, 1)[..., None] * .3 * strength
		rgb = rgb * (1 - dust) + np.array([.40, .38, .34]) * dust
		px[..., :3] = rgb
		im.pixels.foreach_set(px.ravel()); im.pack()
		for nd in nodes: nd.image = im
	for o in objs:
		for slot in o.material_slots:
			m = slot.material
			if m is None or not m.use_nodes: continue
			p = m.node_tree.nodes.get('Principled BSDF')
			if p is None: continue
			p.inputs['Roughness'].default_value = .92
			bc = p.inputs['Base Color']
			if not bc.is_linked:
				c = bc.default_value; l = c[0] * .3 + c[1] * .59 + c[2] * .11
				bc.default_value = (*(((c[i] * .35 + l * .65) * .62) for i in range(3)), 1)

def finalize(objs, name, axis, target, rot_z=0.0, extra=None):
	"""Join, bake transforms, rotate to face Godot +Z, scale so dimension
	`axis` (0 x width, 1 y depth, 2 z height) equals `target`, floor-centre
	origin, export."""
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs: o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.make_single_user(object=True, obdata=True)
	bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	if len(objs) > 1: bpy.ops.object.join()
	ob = bpy.context.view_layer.objects.active
	if rot_z:
		ob.data.transform(Matrix.Rotation(math.radians(rot_z), 4, 'Z'))
	if extra: extra(ob)
	co = [v.co for v in ob.data.vertices]
	mn = Vector([min(c[i] for c in co) for i in range(3)]); mx = Vector([max(c[i] for c in co) for i in range(3)])
	s = target / max(mx[axis] - mn[axis], 1e-6)
	pivot = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
	ob.data.transform(Matrix.Scale(s, 4) @ Matrix.Translation(-pivot))
	ob.data.update()
	ob.name = name; ob.matrix_world = Matrix.Identity(4)
	bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
	bpy.context.view_layer.objects.active = ob
	bpy.ops.export_scene.gltf(filepath=str(KIT / (name + '.glb')), export_format='GLB', use_selection=True, export_animations=False)
	size = (mx - mn) * s
	print('KIT %s size %.2f x %.2f x %.2f' % (name, size.x, size.y, size.z))

def keep_named(objs, names):
	keep = [o for o in objs if o.name in names]
	for o in objs:
		if o not in keep: bpy.data.objects.remove(o)
	return keep

def tex_material(name, png, rough=.9):
	m = bpy.data.materials.new(name); m.use_nodes = True
	p = m.node_tree.nodes.get('Principled BSDF')
	t = m.node_tree.nodes.new('ShaderNodeTexImage')
	t.image = bpy.data.images.load(str(TEX / png))
	m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
	p.inputs['Roughness'].default_value = rough
	return m

def box_uv(ob, metres=1.0):
	me = ob.data
	uv = me.uv_layers.new() if not me.uv_layers else me.uv_layers.active
	for poly in me.polygons:
		ax = max(range(3), key=lambda a: abs(poly.normal[a])); axes = [a for a in range(3) if a != ax]
		for li in poly.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			uv.data[li].uv = (co[axes[0]] / metres, co[axes[1]] / metres)

# --------------------------------------------------------------- the kit ---
def village_props():
	# name, file, axis, target, rot_z (deg, Blender) so the front faces -Y
	for name, f, axis, target, rz in [
		('bed', PROPS / 'post_apocalyptic_bed.glb', 0, 2.0, 0),
		('dresser_hutch', PROPS / 'post_apocalyptic_furniture.glb', 2, 1.95, 0),
		('fridge', PROPS / 'post_apocalyptic_fridge.glb', 2, 1.6, 0),
		('stove', PROPS / 'old_rusty_kitchen_stove__dirty_damaged.glb', 2, .9, 0),
		('gas_stove', ROOT_GLB / 'old_russian_gasstove.glb', 2, .9, 0),
		('sink_cabinet', PROPS / 'clogged_old_sink_cabinet.glb', 2, .9, 0),
		('toilet', PROPS / 'souce_toilet_dirty_2.glb', 2, .8, 0),
		('bath_sink', PROPS / 'source_bathroom_sink.glb', 2, .9, 0),
	]:
		objs = import_glb(f)
		finalize(objs, name, axis, target, rz)
	# Backyard sofa pack: keep only the wrecked sofa (tyFlow003).
	objs = import_glb(ROOT_GLB / 'trashy_backyard_sofa.glb')
	objs = [o for o in objs if o.name.startswith('tyFlow003')] or objs
	finalize(objs, 'sofa_wrecked', 0, 2.1, -90)

PACK = ROOT_GLB / 'tinylivingpack.glb'
def pack_props():
	for i, (name, objects, axis, target, rz) in enumerate([
		('tv_stand', ['Object_20'], 2, 1.25, 0),
		('sofa_old', ['Object_26'], 0, 2.0, 0),
		('armchair', ['Object_68'], 2, .95, 0),
		('chair_a', ['Object_84'], 2, .95, 0),
		('chair_b', ['Object_86'], 2, .92, 0),
		('side_table', ['Object_88'], 2, .5, 0),
		('desk_table', ['Object_90'], 2, .78, 90),
		('tall_dresser', ['Object_50'], 2, 1.45, -90),
		('cabinet', ['Object_78'], 2, 1.05, -90),
		('bookshelf', ['Object_94'], 2, 1.9, 0),
		('floor_lamp', ['Object_42'], 2, 1.6, 0),
		('picture', ['Object_80'], 2, .7, -90),
		('rug', ['Object_82'], 0, 2.4, 0),
	]):
		objs = keep_named(import_glb(PACK), objects)
		age_materials(objs, 500 + i)
		finalize(objs, name, axis, target, rz)

def curtain():
	"""Torn, sagging curtain leaf: origin at the top centre (rod height)."""
	reset()
	w, h, nx, ny = .8, 1.9, 28, 40
	bm = bmesh.new()
	rng = random.Random(5)
	verts = [[bm.verts.new(((ix / nx - .5) * w, .045 * math.sin(ix / nx * math.pi * 7) + .012 * math.sin(iy * .7), -iy / ny * h)) for ix in range(nx + 1)] for iy in range(ny + 1)]
	hem = [h * (.72 + .28 * rng.random()) for _ in range(nx)]
	for iy in range(ny):
		for ix in range(nx):
			if iy / ny * h > hem[ix] or ((ix * 7 + iy * 3) % 23 == 0 and iy > 8):
				continue  # ragged hem + moth holes
			bm.faces.new((verts[iy][ix], verts[iy][ix + 1], verts[iy + 1][ix + 1], verts[iy + 1][ix]))
	me = bpy.data.meshes.new('curtain'); bm.to_mesh(me); bm.free()
	ob = bpy.data.objects.new('curtain', me); bpy.context.collection.objects.link(ob)
	uv = me.uv_layers.new()
	for poly in me.polygons:
		for li in poly.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			uv.data[li].uv = (co.x / w + .5, 1 + co.z / h)
	me.materials.append(tex_material('Curtain', 'curtain_fabric.png', .95))
	bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True); bpy.context.view_layer.objects.active = ob
	bpy.ops.export_scene.gltf(filepath=str(KIT / 'curtain.glb'), export_format='GLB', use_selection=True, export_animations=False)
	print('KIT curtain')

def garbage_bags():
	for k in range(2):
		reset()
		bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4, radius=.5)
		ob = bpy.context.object
		rng = random.Random(40 + k)
		for v in ob.data.vertices:
			v.co.x *= .9 + .2 * k; v.co.y *= .8; v.co.z *= .85
			v.co *= 1 + .07 * math.sin(v.co.x * 11 + k) * math.cos(v.co.y * 9) + .04 * math.sin(v.co.z * 13)
			if v.co.z < -.22: v.co.z = -.22 - (v.co.z + .22) * .15  # sag onto the floor
		bpy.ops.mesh.primitive_cone_add(radius1=.09, depth=.18, location=(0, 0, .46))
		knot = bpy.context.object
		m = bpy.data.materials.new('Bin_bag'); m.use_nodes = True
		p = m.node_tree.nodes.get('Principled BSDF')
		p.inputs['Base Color'].default_value = (.025, .028, .03, 1); p.inputs['Roughness'].default_value = .38
		for o in (ob, knot):
			o.data.materials.append(m)
			for poly in o.data.polygons: poly.use_smooth = True
		finalize([ob, knot], 'garbage_bag_%d' % k, 2, .55 + .1 * k)

def cardboard_boxes():
	for k, (sx, sy, sz, crush) in enumerate([(.55, .4, .38, 0.0), (.45, .45, .3, .12)]):
		reset()
		bpy.ops.mesh.primitive_cube_add(size=1)
		ob = bpy.context.object
		ob.scale = (sx, sy, sz); bpy.ops.object.transform_apply(scale=True)
		for v in ob.data.vertices:
			if v.co.z > 0: v.co.x += crush * (1 if v.co.y > 0 else -.5); v.co.z -= crush * .5 * (v.co.x > 0)
		parts = [ob]
		for side in (-1, 1):  # open flaps
			bpy.ops.mesh.primitive_cube_add(size=1, location=(0, side * (sy / 2 + .1), sz / 2 + .02))
			f = bpy.context.object; f.scale = (sx * .96, .2, .006); f.rotation_euler.x = side * math.radians(35 + 20 * k)
			bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
			parts.append(f)
		m = tex_material('Cardboard', 'cardboard.png')
		for o in parts:
			o.data.materials.append(m); box_uv(o, .6)
		finalize(parts, 'cardboard_box_%d' % k, 0, sx)

wallpaper(0, (.62, .66, .50), (.36, .42, .30))
wallpaper(1, (.70, .58, .46), (.46, .30, .26))
wallpaper(2, (.72, .66, .46), (.42, .36, .22))
wallpaper(3, (.56, .62, .66), (.32, .36, .44))
floorboards(); ceiling(); litter(); fabric(); cardboard()
facade(0, (.72, .69, .61))   # white lime
facade(1, (.70, .59, .44))   # pale ochre wash
print('TEXTURES_READY')
village_props()
pack_props()
curtain()
garbage_bags()
cardboard_boxes()
print('INTERIOR_KIT_READY')
