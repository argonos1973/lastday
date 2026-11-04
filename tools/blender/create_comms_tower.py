"""DayZ 'Green Mountain' style Communications Tower (68 m total height, 6 walkable circular decks).
 climbed via vertical steel ladders with safety cages from deck to deck:
  - Ground entrance & base terrace (y = 0 m)
  - Deck 1 (y = 14.0 m): Lower concrete saucer ring + microwave drums
  - Deck 2 (y = 19.5 m): Middle concrete saucer ring + relay cabinets
  - Deck 3 (y = 25.0 m): Upper saucer ring + radial steel spoked halo above
  - Deck 4 (y = 31.0 m): Spoked steel catwalk ring at base of white cone
  - Deck 5 (y = 41.0 m): Transition ring at base of red/white striped mast
  - Deck 6 (y = 52.0 m): Top sniper/observation gallery below the antenna cage & spire (spire tip at 68.0 m)
Exports to assets/models/props/military_comms_tower.glb."""
import bpy, bmesh, math, random
import numpy as np
from pathlib import Path
from mathutils import Vector

R = Path(__file__).resolve().parents[2]
OUT_GLB = R / 'assets/models/props/military_comms_tower.glb'
OUT_PREVIEW = R / 'build/tmp/comms_tower_preview.png'
OUT_CLOSEUP = R / 'build/tmp/comms_tower_closeup.png'

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def v(p):
	# Godot (x, y_up, z) -> Blender (x, -z, y_up)
	return (p[0], -p[2], p[1])


CONCRETE_TEX = 'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg'
CONCRETE_ROUGH = 'assets/external/textures/concrete_floor_02/concrete_floor_02_rough_4k.jpg'
PLASTER_TEX = 'assets/external/textures/plaster_brick_01/plaster_brick_01_diff_4k.jpg'
PLASTER_ROUGH = 'assets/external/textures/plaster_brick_01/plaster_brick_01_rough_4k.jpg'
RUST_TEX = 'assets/external/textures/rusty_metal_03/rusty_metal_03_diff_4k.jpg'


def mat(name, c, rough=0.84, metal=0.0, texture=None, rough_tex=None, tint=None, emit=None, tex_scale=1.0):
	m = bpy.data.materials.new(name)
	m.diffuse_color = (*c, 1.0)
	m.use_nodes = True
	p = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
	p.inputs['Base Color'].default_value = (*c, 1.0)
	p.inputs['Roughness'].default_value = rough
	p.inputs['Metallic'].default_value = metal
	if emit and 'Emission Color' in p.inputs:
		p.inputs['Emission Color'].default_value = (*emit, 1.0)
		p.inputs['Emission Strength'].default_value = 3.8
	if texture and (R / texture).exists():
		im = bpy.data.images.load(str(R / texture), check_existing=True).copy()
		im.name = name
		im.scale(1024, 1024)
		px = np.empty(len(im.pixels), dtype=np.float32)
		im.pixels.foreach_get(px)
		px = px.reshape(1024, 1024, 4)
		# Realzar micro-contraste y suciedad ambiental para evitar aspecto plano
		luma = px[:, :, :3].mean(axis=2, keepdims=True)
		px[:, :, :3] = np.clip(luma + (px[:, :, :3] - luma) * 1.18, 0.02, 0.98)
		if tint:
			px[:, :, :3] = np.clip(px[:, :, :3] * np.array(tint, dtype=np.float32), 0.02, 0.98)
		im.pixels.foreach_set(px.ravel())
		im.pack()
		t = m.node_tree.nodes.new('ShaderNodeTexImage')
		t.image = im
		if abs(tex_scale - 1.0) > 1e-4:
			# KHR_texture_transform: Godot respeta uv_scale exportado por glTF
			tc = m.node_tree.nodes.new('ShaderNodeTexCoord')
			mp = m.node_tree.nodes.new('ShaderNodeMapping')
			mp.inputs['Scale'].default_value = (tex_scale, tex_scale, tex_scale)
			m.node_tree.links.new(tc.outputs['UV'], mp.inputs['Vector'])
			m.node_tree.links.new(mp.outputs['Vector'], t.inputs['Vector'])
		m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
		# Tangent normal and roughness maps remain real image textures in glTF.
		gray = px[:, :, :3].mean(axis=2)
		dy, dx = np.gradient(gray)
		normal = np.stack((-dx * 3.2, -dy * 3.2, np.ones_like(gray)), axis=2)
		normal /= np.linalg.norm(normal, axis=2)[:, :, None]
		if rough_tex and (R / rough_tex).exists():
			rim_img = bpy.data.images.load(str(R / rough_tex), check_existing=True).copy()
			rim_img.scale(1024, 1024)
			rpx = np.empty(len(rim_img.pixels), dtype=np.float32)
			rim_img.pixels.foreach_get(rpx)
			r_chan = np.clip(rough + (rpx.reshape(1024, 1024, 4)[:, :, 0] - 0.5) * 0.45, 0.25, 0.99)
			bpy.data.images.remove(rim_img)
		else:
			r_chan = np.clip(rough + (gray - gray.mean()) * 0.35, 0.28, 0.99)
		for suffix, rgb in [('Normal', normal * .5 + .5), ('Roughness', np.repeat(r_chan[:, :, None], 3, axis=2))]:
			image = bpy.data.images.new(name + '_' + suffix, width=1024, height=1024)
			image.colorspace_settings.name = 'Non-Color'
			image.pixels.foreach_set(np.concatenate((rgb, np.ones((1024,1024,1))),axis=2).astype(np.float32).ravel())
			image.pack()
			node = m.node_tree.nodes.new('ShaderNodeTexImage'); node.image = image
			if t.inputs['Vector'].is_linked:
				m.node_tree.links.new(t.inputs['Vector'].links[0].from_socket, node.inputs['Vector'])
			if suffix == 'Normal':
				nm = m.node_tree.nodes.new('ShaderNodeNormalMap')
				m.node_tree.links.new(node.outputs['Color'], nm.inputs['Color'])
				m.node_tree.links.new(nm.outputs['Normal'], p.inputs['Normal'])
			else:
				m.node_tree.links.new(node.outputs['Color'], p.inputs['Roughness'])
	return m


concrete_white = mat('GM_concrete_white', (0.78, 0.79, 0.76), rough=0.88,
	texture=CONCRETE_TEX, rough_tex=CONCRETE_ROUGH, tint=(1.06, 1.05, 0.99), tex_scale=4.0)
concrete_rib = mat('GM_concrete_rib', (0.68, 0.70, 0.67), rough=0.90,
	texture=CONCRETE_TEX, rough_tex=CONCRETE_ROUGH, tint=(0.88, 0.90, 0.85), tex_scale=4.0)
concrete_dark = mat('GM_concrete_dark', (0.40, 0.42, 0.40), rough=0.93,
	texture=PLASTER_TEX, rough_tex=PLASTER_ROUGH, tint=(0.74, 0.76, 0.72), tex_scale=3.0)
paint_red = mat('GM_stripe_red', (0.66, 0.13, 0.10), rough=0.70, metal=0.18,
	texture=RUST_TEX, tint=(1.12, 0.24, 0.16), tex_scale=2.2)
paint_white = mat('GM_stripe_white', (0.84, 0.83, 0.79), rough=0.74, metal=0.14,
	texture=CONCRETE_TEX, rough_tex=CONCRETE_ROUGH, tint=(1.38, 1.36, 1.28), tex_scale=2.2)
steel_galv = mat('GM_steel_galv', (0.48, 0.51, 0.49), rough=0.52, metal=0.74,
	texture=CONCRETE_TEX, rough_tex=CONCRETE_ROUGH, tint=(0.96, 1.00, 1.04), tex_scale=2.5)
steel_dark = mat('GM_steel_dark', (0.18, 0.20, 0.19), rough=0.50, metal=0.78,
	texture=RUST_TEX, tint=(0.58, 0.62, 0.58), tex_scale=2.5)
olive_metal = mat('GM_olive_metal', (0.23, 0.28, 0.19), rough=0.72, metal=0.42,
	texture=RUST_TEX, tint=(0.54, 0.70, 0.40), tex_scale=2.0)
dish_white = mat('GM_dish_white', (0.82, 0.83, 0.80), rough=0.44, metal=0.26,
	texture=CONCRETE_TEX, rough_tex=CONCRETE_ROUGH, tint=(1.32, 1.32, 1.26), tex_scale=2.0)
beacon_red = mat('GM_beacon_red', (1.0, 0.12, 0.08), rough=0.22, metal=0.0, emit=(1.0, 0.14, 0.06))


def box(name, p, s, m, solid=True, yaw=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
	o = bpy.context.object
	o.name = ('Solid_' if solid else 'Detail_') + name
	o.scale = (s[0], s[2], s[1])
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if abs(yaw) > 1e-4:
		o.rotation_euler = (0.0, 0.0, yaw)
		bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
	o.location = v(p)
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
	o.data.materials.append(m)
	return o


def cbox(name, p, s, yaw=0.0):
	bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
	o = bpy.context.object
	o.name = 'Collision_' + name
	o.scale = (s[0], s[2], s[1])
	bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
	if abs(yaw) > 1e-4:
		o.rotation_euler = (0.0, 0.0, yaw)
		bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
	o.location = v(p)
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
	return o


def rod(name, a, b, r, m, verts=8, solid=False):
	av, bv = Vector(v(a)), Vector(v(b))
	delta = bv - av
	if delta.length < 1e-4:
		return None
	bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=delta.length, location=(av + bv) * 0.5)
	o = bpy.context.object
	o.name = ('Solid_' if solid else 'Detail_') + name
	o.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	o.data.materials.append(m)
	return o


def cone_frustum(name, y0, y1, r0, r1, m, segs=28, solid=True):
	bpy.ops.mesh.primitive_cone_add(
		vertices=segs, radius1=r0, radius2=r1, depth=(y1 - y0),
		location=v((0.0, (y0 + y1) * 0.5, 0.0))
	)
	o = bpy.context.object
	o.name = ('Solid_' if solid else 'Detail_') + name
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
	o.data.materials.append(m)
	for poly in o.data.polygons:
		poly.use_smooth = True
	return o


def torus_ring(name, y, major_r, minor_r, m, segs=32):
	bpy.ops.mesh.primitive_torus_add(
		major_radius=major_r, minor_radius=minor_r,
		major_segments=segs, minor_segments=8,
		location=v((0.0, y, 0.0))
	)
	o = bpy.context.object
	o.name = 'Detail_' + name
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
	o.data.materials.append(m)
	return o


# Radio del fuste central de la torre en función de la altura y (0..56 m)
def shaft_radius(y):
	if y <= 14.0:
		t = y / 14.0
		return 5.40 * (1.0 - t) + 4.25 * t
	elif y <= 25.0:
		t = (y - 14.0) / 11.0
		return 4.15 * (1.0 - t) + 3.55 * t
	elif y <= 31.0:
		t = (y - 25.0) / 6.0
		return 3.40 * (1.0 - t) + 2.95 * t
	elif y <= 41.0:
		t = (y - 31.0) / 10.0
		return 2.85 * (1.0 - t) + 1.95 * t
	else:
		t = min(1.0, (y - 41.0) / 15.0)
		return 1.88 * (1.0 - t) + 1.35 * t


# ---------------------------------------------------------------------------
# 1. BASE DE HORMIGÓN Y FUSTE INFERIOR ESTRIADO BLANCO (y = 0 .. 25 m)
# ---------------------------------------------------------------------------
cone_frustum('BasePlinth', -0.4, 0.4, 7.6, 7.2, concrete_dark, segs=32, solid=True)
cone_frustum('LowerShaft', 0.0, 14.0, 5.40, 4.25, concrete_white, segs=32, solid=True)
cone_frustum('SaucerCore1', 14.0, 19.5, 4.15, 3.85, concrete_white, segs=28, solid=True)
cone_frustum('SaucerCore2', 19.5, 25.0, 3.85, 3.55, concrete_white, segs=28, solid=True)

# Costillas/estrías verticales blancas características de Green Mountain (foto 2)
RIB_COUNT = 28
for i in range(RIB_COUNT):
	ang = (i / float(RIB_COUNT)) * math.tau
	# Dejar libre el sector de la escalera de mano del tramo 0 (ang ~ 0 rad, cara +Z)
	if abs(math.sin(ang)) < 0.16 and math.cos(ang) > 0.0:
		continue
	r_bot = 5.42
	r_top = 4.26
	p_bot = (math.sin(ang) * r_bot, 0.3, math.cos(ang) * r_bot)
	p_top = (math.sin(ang) * r_top, 13.8, math.cos(ang) * r_top)
	rod('FluteRib_%d' % i, p_bot, p_top, 0.11, concrete_rib, verts=6, solid=False)

# Caseta de entrada blindada al pie de la torre (lado Sur/Oeste)
box('EntryBunker', (-4.8, 1.6, 2.6), (3.2, 3.2, 3.6), concrete_dark, solid=True)
box('EntryDoorFrame', (-6.42, 1.25, 2.6), (0.18, 2.3, 1.35), olive_metal, solid=False)

# ---------------------------------------------------------------------------
# 2. CONO BLANCO INTERMEDIO (y = 25 .. 41 m) Y FUSTE ROJO/BLANCO (y = 41 .. 56 m)
# ---------------------------------------------------------------------------
cone_frustum('MidNeck', 25.0, 31.0, 3.40, 2.95, concrete_white, segs=28, solid=True)
cone_frustum('WhiteTaperCone', 31.0, 41.0, 2.85, 1.95, concrete_white, segs=28, solid=True)

# Bandas alternas Rojas y Blancas desde y = 41.0 m hasta y = 56.0 m (6 franjas de 2.5 m)
STRIPE_H = 2.5
for s_idx in range(6):
	sy0 = 41.0 + s_idx * STRIPE_H
	sy1 = sy0 + STRIPE_H
	s_mat = paint_red if s_idx % 2 == 0 else paint_white
	cone_frustum('StripeShaft_%d' % s_idx, sy0, sy1, shaft_radius(sy0), shaft_radius(sy1), s_mat, segs=24, solid=True)

# ---------------------------------------------------------------------------
# 3. PISOS / PLATILLOS CIRCULARES TRANSITABLES (Decks 1..6)
#    Cada piso tiene una escotilla (hatch_angle) por donde llega la escalera de mano
#    desde el piso inferior, y el resto de los 360° es suelo firme con barandilla.
# ---------------------------------------------------------------------------
# Definición de los 6 pisos donde el jugador puede establecerse:
# (level_idx, y, inner_r, outer_r, style, ladder_in_angle_deg, ladder_out_angle_deg, ladder_in_r_shaft)
DECKS = [
	(1, 14.0, 4.10, 6.85, 'saucer',   0.0,  38.0, 4.85),
	(2, 19.5, 3.80, 6.85, 'saucer',  38.0, -32.0, 4.15),
	(3, 25.0, 3.50, 6.75, 'saucer', -32.0,  28.0, 3.85),
	(4, 31.0, 2.85, 5.85, 'spoked',  28.0, -25.0, 3.40),
	(5, 41.0, 1.90, 4.25, 'ring',   -25.0,  20.0, 2.45),
	(6, 52.0, 1.42, 3.85, 'top',     20.0,   0.0, 1.88),
]


def build_walkable_ring_deck(idx, y, r_in, r_out, style, hatch_deg, ladder_r_shaft):
	# Construimos el anillo con 24 sectores trapezoidales; el sector que coincide
	# con hatch_deg se deja abierto (escotilla amplia alrededor de r_ladder) para que el jugador
	# suba/baje por la escalera de mano limpiamente y camine por los otros 23 sectores.
	n_sec = 24
	hatch_rad = math.radians(hatch_deg)
	slab_h = 0.34 if style == 'saucer' else 0.22
	deck_mat = concrete_white if style == 'saucer' else steel_galv

	# Labio cónico inferior y nervios radiales de soporte bajo cada piso
	if style == 'saucer':
		cone_frustum('SaucerLip_%d' % idx, y - 0.72, y - 0.16, r_in + 0.12, r_out - 0.18, concrete_dark, segs=28, solid=False)
		for rb_i in range(16):
			ra = (rb_i / 16.0) * math.tau
			if abs((ra - hatch_rad + math.pi) % math.tau - math.pi) < 0.22:
				continue
			rod('SaucerRib_%d_%d' % (idx, rb_i),
				(math.sin(ra) * (r_in + 0.05), y - 0.95, math.cos(ra) * (r_in + 0.05)),
				(math.sin(ra) * (r_out - 0.22), y - 0.18, math.cos(ra) * (r_out - 0.22)),
				0.09, concrete_rib, verts=6, solid=False)
	else:
		# Jabalcones diagonales de acero sosteniendo las plataformas metálicas (pisos 4, 5 y 6)
		for st_i in range(12):
			sa = (st_i / 12.0) * math.tau
			if abs((sa - hatch_rad + math.pi) % math.tau - math.pi) < 0.26:
				continue
			rod('DeckBrace_%d_%d' % (idx, st_i),
				(math.sin(sa) * max(1.25, r_in - 0.08), y - 1.65, math.cos(sa) * max(1.25, r_in - 0.08)),
				(math.sin(sa) * (r_out - 0.18), y - 0.10, math.cos(sa) * (r_out - 0.18)),
				0.065, steel_dark, verts=6, solid=False)

	# Corona de radios metálicos para el piso 4 (rueda de radios abierta)
	if style == 'spoked':
		torus_ring('SpokeOuterRim_%d' % idx, y - 0.05, r_out, 0.11, steel_galv, segs=32)
		torus_ring('SpokeMidRim_%d' % idx, y - 0.05, (r_in + r_out) * 0.5, 0.08, steel_galv, segs=32)
		for sp in range(24):
			sa = (sp / 24.0) * math.tau
			rod('Spoke_%d_%d' % (idx, sp),
				(math.sin(sa) * r_in, y - 0.05, math.cos(sa) * r_in),
				(math.sin(sa) * r_out, y - 0.05, math.cos(sa) * r_out),
				0.06, steel_galv)

	r_hatch_outer = max(r_in + 1.38, ladder_r_shaft + 0.98)
	for s in range(n_sec):
		a0 = (s / float(n_sec)) * math.tau
		a1 = ((s + 1) / float(n_sec)) * math.tau
		amid = 0.5 * (a0 + a1)
		# Diferencia angular mínima respecto a la escotilla de llegada
		diff = abs((amid - hatch_rad + math.pi) % math.tau - math.pi)
		is_hatch = diff < (math.tau / float(n_sec)) * 0.65

		if not is_hatch:
			# Sector de suelo caminable (Solid_ para recibir colisión trimesh exacta)
			rmid = 0.5 * (r_in + r_out)
			depth_r = (r_out - r_in) + 0.12
			arc_w = rmid * (math.tau / float(n_sec)) + 0.14
			px = math.sin(amid) * rmid
			pz = math.cos(amid) * rmid
			box('DeckSec_%d_%d' % (idx, s), (px, y - slab_h * 0.5, pz), (arc_w, slab_h, depth_r), deck_mat, solid=True, yaw=amid)
		else:
			# En el sector de la escotilla ponemos solo el borde exterior más allá de la escalera
			# si queda espacio suficiente, dejando libre todo el paso vertical del jugador.
			if r_out > r_hatch_outer + 0.32:
				rmid = 0.5 * (r_hatch_outer + r_out)
				depth_r = r_out - r_hatch_outer
				arc_w = rmid * (math.tau / float(n_sec)) + 0.10
				px = math.sin(amid) * rmid
				pz = math.cos(amid) * rmid
				box('DeckHatchRim_%d_%d' % (idx, s), (px, y - slab_h * 0.5, pz), (arc_w, slab_h, depth_r), deck_mat, solid=True, yaw=amid)
			# Brocal amarillo/acero alrededor de la escotilla
			for hside in (-1, 1):
				ha = hatch_rad + hside * (math.tau / float(n_sec)) * 0.52
				h_rmid = 0.5 * (r_in + min(r_out - 0.15, r_hatch_outer))
				h_len = max(0.5, min(r_out - 0.15, r_hatch_outer) - r_in)
				box('HatchCurb_%d_%d' % (idx, hside), (math.sin(ha) * h_rmid, y + 0.06, math.cos(ha) * h_rmid), (0.06, 0.12, h_len), steel_dark, solid=False, yaw=ha)

		# Barandilla perimetral exterior + rodapié + muro de colisión invisible en los 24 sectores
		rail_r = r_out - 0.08
		arc_rail = rail_r * (math.tau / float(n_sec)) + 0.06
		rx = math.sin(amid) * rail_r
		rz = math.cos(amid) * rail_r
		box('RailTop_%d_%d' % (idx, s), (rx, y + 1.08, rz), (arc_rail, 0.055, 0.055), steel_galv, solid=False, yaw=amid)
		box('RailMid_%d_%d' % (idx, s), (rx, y + 0.56, rz), (arc_rail, 0.045, 0.045), steel_galv, solid=False, yaw=amid)
		box('RailToe_%d_%d' % (idx, s), (rx, y + 0.08, rz), (arc_rail, 0.14, 0.03), steel_dark, solid=False, yaw=amid)
		p0x, p0z = math.sin(a0) * rail_r, math.cos(a0) * rail_r
		rod('RailPost_%d_%d' % (idx, s), (p0x, y, p0z), (p0x, y + 1.12, p0z), 0.036, steel_galv)
		cbox('DeckGuard_%d_%d' % (idx, s), (rx, y + 0.60, rz), (arc_rail + 0.06, 1.22, 0.10), yaw=amid)


for idx, dy, rin, rout, st, hin, _hout, r_sh in DECKS:
	build_walkable_ring_deck(idx, dy, rin, rout, st, hin, r_sh)


# ---------------------------------------------------------------------------
# 4. ESCALERAS DE MANO VERTICALES CON JAULA GUARDACUERPOS (Tramos 0..5)
#    Coinciden exactamente con LADDER_FLIGHTS_META en HighMountainZone.gd.
# ---------------------------------------------------------------------------
LADDER_FLIGHTS = [
	# (flight_idx, y_bottom, y_top, angle_deg, r_shaft)
	(0,  0.0, 14.0,   0.0, 4.85),
	(1, 14.0, 19.5,  38.0, 4.15),
	(2, 19.5, 25.0, -32.0, 3.85),
	(3, 25.0, 31.0,  28.0, 3.40),
	(4, 31.0, 41.0, -25.0, 2.45),
	(5, 41.0, 52.0,  20.0, 1.88),
]

LADDER_W = 0.52
RUNG_STEP = 0.34

for f_idx, y0, y1, ang_deg, r_shaft in LADDER_FLIGHTS:
	ang = math.radians(ang_deg)
	r_base = r_shaft + 0.54
	nx, nz = math.sin(ang), math.cos(ang)
	tx, tz = math.cos(ang), -math.sin(ang)  # tangente horizontal
	cx, cz = nx * r_base, nz * r_base

	# Largueros verticales izquierdo y derecho (sobresalen 1.05 m sobre el piso de llegada)
	top_rail_y = y1 + 1.05
	for side in (-1, 1):
		sx = cx + tx * (side * LADDER_W * 0.5)
		sz = cz + tz * (side * LADDER_W * 0.5)
		rod('LadderRail_%d_%d' % (f_idx, side), (sx, y0, sz), (sx, top_rail_y, sz), 0.032, paint_white, verts=8, solid=False)

	# Peldaños horizontales cada 34 cm
	n_rungs = int((y1 - y0) / RUNG_STEP)
	for r_i in range(1, n_rungs + 1):
		ry = y0 + r_i * RUNG_STEP
		if ry > y1 + 0.05:
			break
		p_left = (cx - tx * (LADDER_W * 0.5), ry, cz - tz * (LADDER_W * 0.5))
		p_right = (cx + tx * (LADDER_W * 0.5), ry, cz + tz * (LADDER_W * 0.5))
		rod('LadderRung_%d_%d' % (f_idx, r_i), p_left, p_right, 0.022, steel_galv, verts=8, solid=False)

	# Patas de anclaje al fuste cada 3.0 m
	for by in np.arange(y0 + 1.5, y1, 3.0):
		r_wall = shaft_radius(float(by))
		for side in (-1, 1):
			sx = cx + tx * (side * LADDER_W * 0.5)
			sz = cz + tz * (side * LADDER_W * 0.5)
			wx = nx * r_wall + tx * (side * LADDER_W * 0.5)
			wz = nz * r_wall + tz * (side * LADDER_W * 0.5)
			rod('LadderBracket_%d' % f_idx, (wx, float(by), wz), (sx, float(by), sz), 0.024, steel_dark)

	# Jaula guardacuerpos (aros semicirculares blancos + pletinas verticales como en la foto 5)
	cage_start = y0 + 2.4
	cage_end = y1 - 0.3
	if cage_end > cage_start:
		cage_r = 0.44
		cage_cx = cx + nx * 0.38
		cage_cz = cz + nz * 0.38
		for hy in np.arange(cage_start, cage_end + 0.05, 1.45):
			# Aro poligonal abierto hacia la escalera
			segs = 8
			for k in range(segs):
				a_k0 = ang - math.pi * 0.65 + (k / float(segs)) * (math.pi * 1.30)
				a_k1 = ang - math.pi * 0.65 + ((k + 1) / float(segs)) * (math.pi * 1.30)
				p0 = (cage_cx + math.sin(a_k0) * cage_r, float(hy), cage_cz + math.cos(a_k0) * cage_r)
				p1 = (cage_cx + math.sin(a_k1) * cage_r, float(hy), cage_cz + math.cos(a_k1) * cage_r)
				rod('CageHoop_%d' % f_idx, p0, p1, 0.020, paint_white, verts=6)
		# 3 barras verticales uniendo los aros de la jaula
		for k_ang in (-0.42, 0.0, 0.42):
			ba = ang + k_ang * math.pi
			bx = cage_cx + math.sin(ba) * cage_r
			bz = cage_cz + math.cos(ba) * cage_r
			rod('CageStrap_%d' % f_idx, (bx, cage_start, bz), (bx, cage_end, bz), 0.018, paint_white, verts=6)


# ---------------------------------------------------------------------------
# 5. PARABÓLICAS DE MICROONDAS, CASETAS DE RADIO Y AGUJA DE CORONACIÓN (52..68 m)
# ---------------------------------------------------------------------------
def add_drum_antenna(name, y, deck_y, r_mount, ang_deg, drum_r=1.15):
	a = math.radians(ang_deg)
	nx, nz = math.sin(a), math.cos(a)
	tx, tz = math.cos(a), -math.sin(a)
	px, pz = nx * r_mount, nz * r_mount
	r_wall = shaft_radius(y) - 0.12
	# Celosía triangular de soporte al fuste + puntales al piso
	rod(name + '_ArmM', (nx * r_wall, y, nz * r_wall), (px, y, pz), 0.095, steel_dark)
	for side in (-1, 1):
		bx = nx * r_wall + tx * (0.55 * side)
		bz = nz * r_wall + tz * (0.55 * side)
		rod(name + '_ArmDiag_%d' % side, (bx, y - 0.35, bz), (px + tx * (0.18 * side), y, pz + tz * (0.18 * side)), 0.055, steel_galv)
	rod(name + '_Post', (nx * (r_mount - 0.18), deck_y, nz * (r_mount - 0.18)), (nx * (r_mount - 0.18), y, nz * (r_mount - 0.18)), 0.075, steel_galv)
	# Tambor cilíndrico blindado con anillo frontal oscuro, radomo convexo y guía de ondas coaxial
	bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=drum_r, depth=0.64, location=v((px, y, pz)))
	d = bpy.context.object
	d.name = 'Detail_' + name
	quat = Vector(v((nx, 0.0, nz))).to_track_quat('Z', 'Y')
	d.rotation_euler = quat.to_euler()
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	d.data.materials.append(dish_white)
	for poly in d.data.polygons:
		poly.use_smooth = True
	# Aro tensor metálico exterior del tambor (misma orientación que el cilindro frontal)
	bpy.ops.mesh.primitive_torus_add(major_radius=drum_r * 0.99, minor_radius=0.055, major_segments=24, minor_segments=8,
		location=v((px + nx * 0.28, y, pz + nz * 0.28)))
	rim = bpy.context.object
	rim.name = 'Detail_' + name + '_Rim'
	rim.rotation_euler = quat.to_euler()
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	rim.data.materials.append(steel_dark)
	# Domo central del radomo + bajante coaxial
	bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=drum_r * 0.34,
		location=v((px + nx * 0.26, y, pz + nz * 0.26)))
	cap = bpy.context.object
	cap.name = 'Detail_' + name + '_Cap'
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
	cap.data.materials.append(olive_metal)
	rod(name + '_Coax', (px - nx * 0.20, y - drum_r * 0.75, pz - nz * 0.20), (nx * (r_wall + 0.15), deck_y + 0.35, nz * (r_wall + 0.15)), 0.032, steel_dark)


# Tambores parabólicos en los platillos (anclados al fuste y al piso)
for a_deg in (55, 135, 225, 305):
	add_drum_antenna('Drum14_%d' % a_deg, 15.6, 14.0, 6.25, a_deg, 1.15)
for a_deg in (15, 110, 195, 280):
	add_drum_antenna('Drum20_%d' % a_deg, 21.1, 19.5, 6.20, a_deg, 1.05)
for a_deg in (75, 165, 255):
	add_drum_antenna('Drum25_%d' % a_deg, 26.5, 25.0, 6.10, a_deg, 0.95)

# Casetas/armarios técnicos en los pisos para que el jugador se parapete o establezca
for idx, dy, a_deg in [(1, 14.0, 180.0), (2, 19.5, 145.0), (3, 25.0, 210.0), (4, 31.0, 180.0)]:
	a = math.radians(a_deg)
	r_cab = shaft_radius(dy) + 0.85
	box('RelayCabinet_%d' % idx, (math.sin(a) * r_cab, dy + 0.95, math.cos(a) * r_cab), (1.35, 1.90, 0.85), olive_metal, solid=True, yaw=-a)

# Jaula cilíndrica superior (y = 56.0 .. 61.2 m), mástil central continuo y aguja roja/blanca hasta 68.0 m
cone_frustum('TopCapCore', 55.9, 56.5, 1.45, 1.55, steel_dark, segs=24, solid=True)
cone_frustum('UpperCageCoreMast', 56.3, 61.3, 0.62, 0.42, paint_white, segs=20, solid=True)
cone_frustum('UpperCageTopPlate', 61.05, 61.35, 1.42, 0.52, steel_dark, segs=24, solid=True)
for c_i in range(12):
	ca = (c_i / 12.0) * math.tau
	ca_next = ((c_i + 1) / 12.0) * math.tau
	cr = 1.38
	rod('UpperCageCol_%d' % c_i, (math.sin(ca) * cr, 56.2, math.cos(ca) * cr), (math.sin(ca) * cr, 61.2, math.cos(ca) * cr), 0.055, steel_galv)
	rod('UpperCageSpoke_%d' % c_i, (math.sin(ca) * 0.42, 61.18, math.cos(ca) * 0.42), (math.sin(ca) * cr, 61.18, math.cos(ca) * cr), 0.045, steel_galv)
	rod('UpperCageBotSpoke_%d' % c_i, (math.sin(ca) * 0.60, 56.45, math.cos(ca) * 0.60), (math.sin(ca) * cr, 56.45, math.cos(ca) * cr), 0.045, steel_dark)
	# Arriostramiento diagonal en X en la jaula superior de celosía
	for b_y0, b_y1 in ((56.3, 57.9), (57.9, 59.5), (59.5, 61.1)):
		rod('UpperCageDiagA_%d_%.1f' % (c_i, b_y0),
			(math.sin(ca) * cr, b_y0, math.cos(ca) * cr),
			(math.sin(ca_next) * cr, b_y1, math.cos(ca_next) * cr), 0.026, steel_galv, verts=6)
		rod('UpperCageDiagB_%d_%.1f' % (c_i, b_y0),
			(math.sin(ca_next) * cr, b_y0, math.cos(ca_next) * cr),
			(math.sin(ca) * cr, b_y1, math.cos(ca) * cr), 0.026, steel_galv, verts=6)
for ring_y in (57.4, 58.8, 60.2, 61.2):
	torus_ring('UpperCageRing_%.1f' % ring_y, ring_y, 1.38, 0.05, steel_galv, segs=24)

# Contrafuertes de hormigón armado en el zócalo inferior y nervios de compresión
for bf_i in range(8):
	ba = (bf_i / 8.0) * math.tau + math.radians(22.5)
	if abs(math.sin(ba)) < 0.28 and math.cos(ba) > 0.0:
		continue
	bx, bz = math.sin(ba) * 5.85, math.cos(ba) * 5.85
	box('BaseButtress_%d' % bf_i, (bx, 1.45, bz), (0.52, 2.90, 1.45), concrete_dark, solid=False, yaw=ba)
for comp_y in (4.6, 9.2, 13.65):
	torus_ring('ShaftCompressionBand_%.1f' % comp_y, comp_y, shaft_radius(comp_y) + 0.08, 0.09, concrete_rib, segs=32)

# Aguja final continua (y = 61.25 .. 67.85 m) a franjas rojas y blancas + pararrayos y antenas látigo
for sp_i in range(6):
	ay0 = 61.25 + sp_i * 1.10
	ay1 = ay0 + 1.12
	sp_mat = paint_red if sp_i % 2 == 0 else paint_white
	r_sp0 = max(0.09, 0.38 * (1.0 - sp_i * 0.12))
	r_sp1 = max(0.08, 0.38 * (1.0 - (sp_i + 1) * 0.12))
	cone_frustum('SpireSeg_%d' % sp_i, ay0, ay1, r_sp0, r_sp1, sp_mat, segs=16, solid=False)
for dip_i in range(4):
	da = (dip_i / 4.0) * math.tau
	for dy_d in (62.8, 65.2):
		rod('SpireDipole_%d_%.1f' % (dip_i, dy_d),
			(math.sin(da) * 0.18, dy_d, math.cos(da) * 0.18),
			(math.sin(da) * 0.95, dy_d, math.cos(da) * 0.95), 0.022, steel_galv, verts=6)
		rod('SpireDipoleTip_%d_%.1f' % (dip_i, dy_d),
			(math.sin(da) * 0.95, dy_d - 0.42, math.cos(da) * 0.95),
			(math.sin(da) * 0.95, dy_d + 0.42, math.cos(da) * 0.95), 0.016, steel_galv, verts=6)
rod('LightningRodTip', (0.0, 67.85, 0.0), (0.0, 68.55, 0.0), 0.025, steel_galv, verts=8)

bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.26, location=v((0.0, 67.90, 0.0)))
top_beacon = bpy.context.object
top_beacon.name = 'Detail_TopBeacon'
bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
top_beacon.data.materials.append(beacon_red)

# ---------------------------------------------------------------------------
# 6. DETALLES "AUTORADOS" DE LA TORRE REAL: antenas de panel, canales de cable,
#    caseta de servicio, puerta del búnker y balizas de altura media.
# ---------------------------------------------------------------------------
def panel_antenna(name, y, ang_deg, tilt_deg=0.0):
	# Antena de panel rectangular como las que montan las torres GSM reales:
	# brazo de soporte + unidad RRU trasera + panel blanco 0.58 x 2.05 m pegado al extremo de los brazos.
	a = math.radians(ang_deg)
	nx, nz = math.sin(a), math.cos(a)
	r_wall = shaft_radius(y)
	arm_out = r_wall + 0.72
	rod(name + '_ArmA', (nx * (r_wall - 0.05), y + 0.75, nz * (r_wall - 0.05)), (nx * arm_out, y + 0.75, nz * arm_out), 0.055, steel_galv)
	rod(name + '_ArmB', (nx * (r_wall - 0.05), y - 0.75, nz * (r_wall - 0.05)), (nx * arm_out, y - 0.75, nz * arm_out), 0.055, steel_galv)
	rod(name + '_Mast', (nx * arm_out, y - 0.95, nz * arm_out), (nx * arm_out, y + 0.95, nz * arm_out), 0.042, steel_dark)
	box(name + '_RRU', (nx * (arm_out - 0.16), y, nz * (arm_out - 0.16)), (0.34, 0.58, 0.18), steel_galv, solid=False, yaw=a)
	box(name, (nx * (arm_out + 0.08), y, nz * (arm_out + 0.08)), (0.58, 2.05, 0.16), dish_white, solid=False, yaw=a)
	box(name + '_CapT', (nx * (arm_out + 0.08), y + 1.04, nz * (arm_out + 0.08)), (0.60, 0.06, 0.18), steel_dark, solid=False, yaw=a)
	box(name + '_CapB', (nx * (arm_out + 0.08), y - 1.04, nz * (arm_out + 0.08)), (0.60, 0.06, 0.18), steel_dark, solid=False, yaw=a)

# Tres sectores de antenas de panel en el fuste rojo/blanco (y~44-50 m) y en la jaula superior
for pa_i, (py, pa) in enumerate([(44.5, 30.0), (44.5, 150.0), (44.5, 270.0),
	(48.5, 90.0), (48.5, 210.0), (48.5, 330.0),
	(57.6, 60.0), (57.6, 180.0), (57.6, 300.0)]):
	panel_antenna('PanelAnt_%d' % pa_i, py, pa, tilt_deg=-4.0)

# Canales verticales de cables/waveguide abrazando el fuste (dos caras opuestas)
for ct_i, ca in enumerate([150.0, 330.0]):
	ca_r = math.radians(ca)
	cnx, cnz = math.sin(ca_r), math.cos(ca_r)
	y_cur = 2.5
	while y_cur < 51.5:
		y_next = min(y_cur + 5.0, 51.5)
		r0 = shaft_radius(y_cur) + 0.10
		r1 = shaft_radius(y_next) + 0.10
		cx0, cz0 = cnx * r0, cnz * r0
		cx1, cz1 = cnx * r1, cnz * r1
		seg = box('CableTray_%d_%d' % (ct_i, int(y_cur)),
			((cx0 + cx1) * 0.5, (y_cur + y_next) * 0.5, (cz0 + cz1) * 0.5),
			(0.34, y_next - y_cur + 0.15, 0.14), steel_dark, solid=False, yaw=ca_r)
		y_cur = y_next

# Caseta de servicio de la operadora junto a la base (lado Este del zócalo)
box('ServiceShed', (5.9, 1.15, 3.4), (2.9, 2.3, 2.5), olive_metal, solid=True, yaw=0.0)
box('ServiceShedRoof', (5.9, 2.36, 3.4), (3.16, 0.14, 2.76), concrete_dark, solid=False, yaw=0.0)
box('ServiceShedDoor', (4.42, 0.95, 3.4), (0.10, 1.9, 0.9), steel_dark, solid=False, yaw=0.0)
box('ServiceShedSwitchbox', (4.41, 1.35, 2.55), (0.14, 0.52, 0.38), steel_galv, solid=False, yaw=0.0)
box('ServiceShedVent', (5.9, 2.15, 4.62), (0.9, 0.35, 0.08), steel_galv, solid=False, yaw=0.0)

# Hoja de la puerta blindada del búnker de entrada + losa de visera y lámpara enrejada
box('EntryBunkerRoof', (-4.8, 3.28, 2.6), (3.48, 0.18, 3.88), concrete_rib, solid=False, yaw=0.0)
box('EntryBunkerCanopy', (-6.65, 2.52, 2.6), (0.65, 0.12, 1.65), concrete_dark, solid=False, yaw=0.0)
box('EntryBunkerDoor', (-6.44, 1.12, 2.6), (0.10, 2.05, 1.15), steel_dark, solid=False, yaw=0.0)
rod('EntryBunkerDoorBar', (-6.52, 1.12, 2.25), (-6.52, 1.12, 2.95), 0.03, steel_galv)
bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.025, major_segments=16, minor_segments=6, location=v((-6.53, 1.15, 2.6)))
wheel = bpy.context.object
wheel.name = 'Detail_BunkerWheel'
wheel.rotation_euler = (0.0, math.pi * 0.5, 0.0)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
wheel.data.materials.append(steel_galv)

# Balizas rojas de altura media (normativa aeronáutica) en el cuerpo blanco
for b_i, (by, ba) in enumerate([(21.0, 200.0), (36.5, 20.0)]):
	ba_r = math.radians(ba)
	br = shaft_radius(by) + 0.35
	bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.17,
		location=v((math.sin(ba_r) * br, by, math.cos(ba_r) * br)))
	mb = bpy.context.object
	mb.name = 'Detail_MidBeacon_%d' % b_i
	bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
	mb.data.materials.append(beacon_red)
	rod('MidBeaconPost_%d' % b_i,
		(math.sin(ba_r) * (br - 0.30), by, math.cos(ba_r) * (br - 0.30)),
		(math.sin(ba_r) * br, by, math.cos(ba_r) * br), 0.035, steel_galv)

# ---------------------------------------------------------------------------
# 7. UNIR GEOMETRÍA EN Solid_CommsTower, Detail_CommsTower Y Collision_CommsTower + EXPORTAR GLB
# ---------------------------------------------------------------------------
# Visual-only fabrication details. Keep Solid_/Collision_ vertices unchanged.
joint = mat('GM_recesses', (.075,.078,.071), rough=.96)
rust = mat('GM_runoff', (.19,.115,.065), rough=.94)
for y in range(2, 14, 2):
    torus_ring('FormworkJoint_%d' % y, y, shaft_radius(y) + .008, .012, joint, segs=64)
    for angle in range(0,360,45):
        a=math.radians(angle); r=shaft_radius(y-.45)
        rod('FormTie', (math.sin(a)*r,y-.45,math.cos(a)*r), (math.sin(a)*(r+.014),y-.45,math.cos(a)*(r+.014)), .036, joint, verts=8)
# Anchor plates, paired bolts and cable tray clamps.
for y in (14,19.5,25,31,41,52):
    for angle in range(0,360,45):
        a=math.radians(angle); r=shaft_radius(y)+.25
        box('AnchorPlate', (math.sin(a)*r,y+.10,math.cos(a)*r),(.22,.20,.025),steel_dark,solid=False,yaw=a)
        for d in (-.065,.065):
            x=math.sin(a)*r+math.cos(a)*d; z=math.cos(a)*r-math.sin(a)*d
            rod('AnchorBolt',(x,y+.10,z),(x+math.sin(a)*.045,y+.10,z+math.cos(a)*.045),.024,steel_galv,verts=6)
for y in range(4,50,3):
    for angle in (150,330):
        a=math.radians(angle);r=shaft_radius(y)+.19
        box('CableTrayClamp',(math.sin(a)*r,y,math.cos(a)*r),(.43,.065,.08),steel_galv,solid=False,yaw=a)
# Recessed louvres instead of a featureless ventilation rectangle.
for h in range(6):
    box('VentLouvre',(5.9,2.04+h*.047,4.68),(.82,.018,.065),steel_dark,solid=False)
# Thin tapered runoff stains on the lower shaft, flush with each polygon face.
rng=random.Random(1304)
for i in range(48):
    segment=rng.randrange(32); a=(segment+.5)*math.tau/32
    top=rng.uniform(3,13.8); length=rng.uniform(.4,2.7); width=rng.uniform(.025,.11)
    verts=[]
    for y,w in ((top,width),(top-length,width*.12)):
        r=shaft_radius(y)*math.cos(math.pi/32)+.006
        for side in (-1,1):
            verts.append(v((math.sin(a)*r+math.cos(a)*w*side,y,math.cos(a)*r-math.sin(a)*w*side)))
    mesh=bpy.data.meshes.new('Runoff');mesh.from_pydata(verts,[],[(0,1,3,2)])
    o=bpy.data.objects.new('Detail_Runoff',mesh);bpy.context.collection.objects.link(o);mesh.materials.append(rust)
# World-sized UVs eliminate stretched concrete and oversized rust patterns.
for o in list(bpy.context.scene.objects):
    if o.type!='MESH' or o.name.startswith('Collision_'):continue
    uv=o.data.uv_layers.active or o.data.uv_layers.new(name='UVMap')
    for face in o.data.polygons:
        axis=max(range(3),key=lambda i:abs(face.normal[i]))
        coords=[i for i in range(3) if i!=axis]
        for li in face.loop_indices:
            co=o.data.vertices[o.data.loops[li].vertex_index].co
            uv.data[li].uv=(co[coords[0]]/8.0,co[coords[1]]/8.0)

for prefix in ('Solid_', 'Detail_', 'Collision_'):
	objs = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.name.startswith(prefix)]
	if not objs:
		continue
	bpy.ops.object.select_all(action='DESELECT')
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.join()
	objs[0].name = prefix + 'CommsTower'

OUT_GLB.parent.mkdir(parents=True, exist_ok=True)
(R / 'build/tmp').mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(R / 'build/tmp/comms_tower_realistic.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT_GLB), export_format='GLB', export_animations=False)
print('GREEN_MOUNTAIN_TOWER_GLB_READY:', OUT_GLB)

# Renderizar 2 vistas de verificación (general + detalle de platillos y escalera de mano)
OUT_PREVIEW.parent.mkdir(parents=True, exist_ok=True)
for o in [o for o in bpy.context.scene.objects if o.name.startswith('Collision_')]:
	o.hide_render = True

scn = bpy.context.scene
scn.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [
	i.identifier for i in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items
] else 'BLENDER_EEVEE'
scn.render.resolution_x = 900
scn.render.resolution_y = 1350

world = bpy.data.worlds.new('PreviewWorld')
scn.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
bg.inputs['Color'].default_value = (0.46, 0.62, 0.82, 1.0)
bg.inputs['Strength'].default_value = 1.15

bpy.ops.object.light_add(type='SUN', location=(35, -45, 70))
sun = bpy.context.object
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), math.radians(16), math.radians(28))

bpy.ops.object.camera_add(location=(26.0, -64.0, 28.0))
cam = bpy.context.object
scn.camera = cam
direction = Vector((0.0, 0.0, 33.0)) - cam.location
cam.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 28.0
scn.render.filepath = str(OUT_PREVIEW)
bpy.ops.render.render(write_still=True)

# Segunda toma en contrapicado mostrando los platillos, la corona de radios y la escalera con jaula
cam.location = Vector((12.0, -24.0, 8.0))
direction2 = Vector((0.0, 0.0, 29.0)) - cam.location
cam.rotation_euler = direction2.to_track_quat('-Z', 'Y').to_euler()
cam.data.lens = 24.0
scn.render.filepath = str(OUT_CLOSEUP)
bpy.ops.render.render(write_still=True)
print('GREEN_MOUNTAIN_PREVIEWS_READY:', OUT_PREVIEW, OUT_CLOSEUP)
