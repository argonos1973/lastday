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
import bpy, bmesh, math
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


def mat(name, c, rough=0.84, metal=0.0, texture=None, tint=None, emit=None):
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
		im.scale(512, 512)
		if tint:
			px = np.empty(len(im.pixels), dtype=np.float32)
			im.pixels.foreach_get(px)
			px = px.reshape(-1, 4)
			px[:, :3] *= tint
			im.pixels.foreach_set(px.ravel())
		im.pack()
		t = m.node_tree.nodes.new('ShaderNodeTexImage')
		t.image = im
		m.node_tree.links.new(t.outputs['Color'], p.inputs['Base Color'])
	return m


concrete_white = mat('GM_concrete_white', (0.80, 0.81, 0.79), rough=0.86)
concrete_rib = mat('GM_concrete_rib', (0.72, 0.74, 0.72), rough=0.88)
concrete_dark = mat('GM_concrete_dark', (0.44, 0.46, 0.44), rough=0.92,
	texture='assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg')
paint_red = mat('GM_stripe_red', (0.68, 0.12, 0.09), rough=0.58, metal=0.25)
paint_white = mat('GM_stripe_white', (0.86, 0.85, 0.82), rough=0.60, metal=0.20)
steel_galv = mat('GM_steel_galv', (0.48, 0.51, 0.49), rough=0.56, metal=0.68)
steel_dark = mat('GM_steel_dark', (0.18, 0.20, 0.19), rough=0.54, metal=0.72)
olive_metal = mat('GM_olive_metal', (0.23, 0.28, 0.19), rough=0.74, metal=0.38)
dish_white = mat('GM_dish_white', (0.82, 0.83, 0.80), rough=0.48, metal=0.22)
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
# (level_idx, y, inner_r, outer_r, style, ladder_in_angle_deg, ladder_out_angle_deg)
DECKS = [
	(1, 14.0, 4.10, 6.85, 'saucer',   0.0,  38.0),
	(2, 19.5, 3.80, 6.85, 'saucer',  38.0, -32.0),
	(3, 25.0, 3.50, 6.75, 'saucer', -32.0,  28.0),
	(4, 31.0, 2.85, 5.85, 'spoked',  28.0, -25.0),
	(5, 41.0, 1.90, 3.65, 'ring',   -25.0,  20.0),
	(6, 52.0, 1.42, 3.35, 'top',     20.0,   0.0),
]


def build_walkable_ring_deck(idx, y, r_in, r_out, style, hatch_deg):
	# Construimos el anillo con 24 sectores trapezoidales; el sector que coincide
	# con hatch_deg se deja abierto (escotilla de 1.15 m de paso) para que el jugador
	# suba/baje por la escalera de mano limpiamente y camine por los otros 23 sectores.
	n_sec = 24
	hatch_rad = math.radians(hatch_deg)
	slab_h = 0.34 if style == 'saucer' else 0.20
	deck_mat = concrete_white if style == 'saucer' else steel_galv

	# Labio cónico inferior de los platillos de hormigón (como en las fotos 2 y 5)
	if style == 'saucer':
		cone_frustum('SaucerLip_%d' % idx, y - 0.65, y - 0.16, r_in + 0.15, r_out - 0.25, concrete_dark, segs=28, solid=False)

	# Corona de radios metálicos para el piso 4 (foto 2 y 4: rueda de radios abierta)
	if style == 'spoked':
		torus_ring('SpokeOuterRim_%d' % idx, y - 0.05, r_out, 0.11, steel_galv, segs=32)
		torus_ring('SpokeMidRim_%d' % idx, y - 0.05, (r_in + r_out) * 0.5, 0.08, steel_galv, segs=32)
		for sp in range(24):
			sa = (sp / 24.0) * math.tau
			rod('Spoke_%d_%d' % (idx, sp),
				(math.sin(sa) * r_in, y - 0.05, math.cos(sa) * r_in),
				(math.sin(sa) * r_out, y - 0.05, math.cos(sa) * r_out),
				0.06, steel_galv)

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
			# para que la barandilla exterior siga continua
			r_hatch_outer = r_in + 1.35
			if r_out > r_hatch_outer + 0.35:
				rmid = 0.5 * (r_hatch_outer + r_out)
				depth_r = r_out - r_hatch_outer
				arc_w = rmid * (math.tau / float(n_sec)) + 0.10
				px = math.sin(amid) * rmid
				pz = math.cos(amid) * rmid
				box('DeckHatchRim_%d_%d' % (idx, s), (px, y - slab_h * 0.5, pz), (arc_w, slab_h, depth_r), deck_mat, solid=True, yaw=amid)

		# Barandilla perimetral exterior + muro de colisión invisible en los 24 sectores
		rail_r = r_out - 0.08
		arc_rail = rail_r * (math.tau / float(n_sec)) + 0.06
		rx = math.sin(amid) * rail_r
		rz = math.cos(amid) * rail_r
		box('RailTop_%d_%d' % (idx, s), (rx, y + 1.05, rz), (arc_rail, 0.055, 0.055), steel_galv, solid=False, yaw=amid)
		box('RailMid_%d_%d' % (idx, s), (rx, y + 0.55, rz), (arc_rail, 0.045, 0.045), steel_galv, solid=False, yaw=amid)
		p0x, p0z = math.sin(a0) * rail_r, math.cos(a0) * rail_r
		rod('RailPost_%d_%d' % (idx, s), (p0x, y, p0z), (p0x, y + 1.08, p0z), 0.035, steel_galv)
		cbox('DeckGuard_%d_%d' % (idx, s), (rx, y + 0.60, rz), (arc_rail + 0.06, 1.22, 0.10), yaw=amid)


for idx, dy, rin, rout, st, hin, _hout in DECKS:
	build_walkable_ring_deck(idx, dy, rin, rout, st, hin)


# ---------------------------------------------------------------------------
# 4. ESCALERAS DE MANO VERTICALES CON JAULA GUARDACUERPOS (Tramos 0..5)
#    Cada tramo sube pegado al fuste desde el piso anterior hasta la escotilla
#    del siguiente piso. Exporta además un volumen Collision_Ladder_<idx> para
#    que el juego detecte la escalera de mano y active la animación de trepar.
# ---------------------------------------------------------------------------
LADDER_FLIGHTS = [
	# (flight_idx, y_bottom, y_top, angle_deg)
	(0,  0.0, 14.0,   0.0),
	(1, 14.0, 19.5,  38.0),
	(2, 19.5, 25.0, -32.0),
	(3, 25.0, 31.0,  28.0),
	(4, 31.0, 41.0, -25.0),
	(5, 41.0, 52.0,  20.0),
]

LADDER_W = 0.52
RUNG_STEP = 0.34

for f_idx, y0, y1, ang_deg in LADDER_FLIGHTS:
	ang = math.radians(ang_deg)
	# Colocamos la escalera ligeramente por fuera de la pared superior/inferior del tramo
	r_base = max(shaft_radius(y0), shaft_radius(y1)) + 0.52
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
	px, pz = nx * r_mount, nz * r_mount
	r_wall = shaft_radius(y) - 0.12
	rod(name + '_Arm', (nx * r_wall, y, nz * r_wall), (px, y, pz), 0.11, steel_dark)
	rod(name + '_Post', (nx * (r_mount - 0.18), deck_y, nz * (r_mount - 0.18)), (nx * (r_mount - 0.18), y, nz * (r_mount - 0.18)), 0.08, steel_galv)
	bpy.ops.mesh.primitive_cylinder_add(vertices=18, radius=drum_r, depth=0.52, location=v((px, y, pz)))
	d = bpy.context.object
	d.name = 'Detail_' + name
	d.rotation_euler = Vector(v((nx, 0.0, nz))).to_track_quat('Z', 'Y').to_euler()
	bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
	d.data.materials.append(dish_white)


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
	cr = 1.38
	rod('UpperCageCol_%d' % c_i, (math.sin(ca) * cr, 56.2, math.cos(ca) * cr), (math.sin(ca) * cr, 61.2, math.cos(ca) * cr), 0.055, steel_galv)
	rod('UpperCageSpoke_%d' % c_i, (math.sin(ca) * 0.42, 61.18, math.cos(ca) * 0.42), (math.sin(ca) * cr, 61.18, math.cos(ca) * cr), 0.045, steel_galv)
for ring_y in (57.4, 58.8, 60.2, 61.2):
	torus_ring('UpperCageRing_%.1f' % ring_y, ring_y, 1.38, 0.05, steel_galv, segs=24)

# Aguja final continua (y = 61.25 .. 67.85 m) a franjas rojas y blancas + baliza emisiva encastrada
for sp_i in range(6):
	ay0 = 61.25 + sp_i * 1.10
	ay1 = ay0 + 1.12
	sp_mat = paint_red if sp_i % 2 == 0 else paint_white
	r_sp0 = max(0.09, 0.38 * (1.0 - sp_i * 0.12))
	r_sp1 = max(0.08, 0.38 * (1.0 - (sp_i + 1) * 0.12))
	cone_frustum('SpireSeg_%d' % sp_i, ay0, ay1, r_sp0, r_sp1, sp_mat, segs=16, solid=False)

bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=0.26, location=v((0.0, 67.90, 0.0)))
top_beacon = bpy.context.object
top_beacon.name = 'Detail_TopBeacon'
bpy.ops.object.transform_apply(location=True, rotation=False, scale=True)
top_beacon.data.materials.append(beacon_red)

# ---------------------------------------------------------------------------
# 6. UNIR GEOMETRÍA EN Solid_CommsTower, Detail_CommsTower Y Collision_CommsTower + EXPORTAR GLB
# ---------------------------------------------------------------------------
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
