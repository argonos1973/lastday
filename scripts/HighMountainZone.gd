extends RefCounted
class_name HighMountainZone

# Centro de la meseta militar en la cumbre Noroeste y su cota (+56 m)
const SUMMIT_CENTER := Vector2(-375.0, -375.0)
const SUMMIT_HEIGHT := 56.0
const PLATEAU_RADIUS := 38.0
const MASSIF_OUTER_RADIUS := 142.0
const BASE_YAW_DEG := 45.0 # Mira hacia el Sureste (+X, +Z, hacia el valle central)

# Picos secundarios que rodean la cumbre por el Norte y Oeste formando la cordillera
const PEAKS := [
	{"pos": Vector2(-462.0, -452.0), "rx": 64.0, "rz": 56.0, "h": 78.0},
	{"pos": Vector2(-368.0, -474.0), "rx": 60.0, "rz": 50.0, "h": 72.0},
	{"pos": Vector2(-478.0, -352.0), "rx": 58.0, "rz": 54.0, "h": 70.0},
	{"pos": Vector2(-288.0, -458.0), "rx": 54.0, "rz": 48.0, "h": 62.0},
	{"pos": Vector2(-458.0, -262.0), "rx": 52.0, "rz": 48.0, "h": 58.0},
]

const ROAD_START := Vector2(-252.0, -268.0)
const ROAD_END := Vector2(-350.0, -350.0)
const ROAD_HALF_W := 4.6
const ASPHALT_HALF_W := 3.5

# Puntos de control 3D (x, cota_y, z) de la carretera:
# Arranca sobre la calzada de la carretera principal Norte-Sur (término en z=-208)
# y se desvía hacia el Oeste con una curva amplia en (8, -212)->(-10, -226); cruza el
# valle hasta el pie de la montaña (-252, -268) y sube RODEANDO la montaña en espiral
# por sus laderas Sur -> Oeste -> Norte -> Este hasta entrar por la puerta Sureste
# de la Base Militar (-356, -356, cota +56 m).
const MOUNTAIN_ROAD_WAYPOINTS_3D := [
	Vector3(9.0, 0.0, -196.0),
	Vector3(7.5, 0.0, -212.0),
	Vector3(-10.0, 0.0, -226.0),
	Vector3(-46.0, 0.0, -232.0),
	Vector3(-95.0, 0.0, -238.0),
	Vector3(-155.0, 0.0, -248.0),
	Vector3(-205.0, 0.4, -259.0),
	Vector3(-252.0, 0.8, -268.0),
	Vector3(-296.0, 5.5, -266.0),
	Vector3(-348.0, 11.5, -258.0),
	Vector3(-402.0, 18.0, -268.0),
	Vector3(-444.0, 24.5, -298.0),
	Vector3(-468.0, 31.0, -346.0),
	Vector3(-462.0, 37.0, -398.0),
	Vector3(-430.0, 42.5, -438.0),
	Vector3(-380.0, 47.0, -448.0),
	Vector3(-334.0, 51.0, -430.0),
	Vector3(-310.0, 54.0, -388.0),
	Vector3(-322.0, 55.5, -348.0),
	Vector3(-346.0, 56.0, -346.0),
	Vector3(-356.0, 56.0, -356.0),
]

static var _cached_road_3d: PackedVector3Array = PackedVector3Array()


static func _catmull_rom_3d(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		(2.0 * p1)
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


static func get_road_polyline_3d() -> PackedVector3Array:
	if not _cached_road_3d.is_empty():
		return _cached_road_3d
	var pts := PackedVector3Array()
	var n := MOUNTAIN_ROAD_WAYPOINTS_3D.size()
	var subdiv := 8
	for i in range(n - 1):
		var p0: Vector3 = MOUNTAIN_ROAD_WAYPOINTS_3D[maxi(0, i - 1)]
		var p1: Vector3 = MOUNTAIN_ROAD_WAYPOINTS_3D[i]
		var p2: Vector3 = MOUNTAIN_ROAD_WAYPOINTS_3D[i + 1]
		var p3: Vector3 = MOUNTAIN_ROAD_WAYPOINTS_3D[mini(n - 1, i + 2)]
		for s in range(subdiv):
			if i > 0 and s == 0:
				continue
			var t := float(s) / float(subdiv)
			var q := _catmull_rom_3d(p0, p1, p2, p3, t)
			q.y = clampf(q.y, 0.0, SUMMIT_HEIGHT)
			pts.append(q)
	pts.append(MOUNTAIN_ROAD_WAYPOINTS_3D[n - 1])
	_cached_road_3d = pts
	return _cached_road_3d


const COMMS_TOWER_OFFSET := Vector3(0.0, 0.0, -10.5)
const WATCH_TOWER_OFFSET := Vector3(13.5, 0.0, 11.5)
const TENT_A_OFFSET := Vector3(-13.5, 0.0, 4.5)
const TENT_B_OFFSET := Vector3(13.5, 0.0, -2.5)

const LADDER_FLIGHTS_META := [
	# (flight_idx, y_bottom_local, y_top_local, angle_deg, r_shaft_max)
	[0,  0.0, 14.0,   0.0, 5.40],
	[1, 14.0, 19.5,  38.0, 4.15],
	[2, 19.5, 25.0, -32.0, 3.85],
	[3, 25.0, 31.0,  28.0, 3.40],
	[4, 31.0, 41.0, -25.0, 2.85],
	[5, 41.0, 52.0,  20.0, 1.88],
]


static func in_bounds_xz(x: float, z: float) -> bool:
	return x < -210.0 and z < -210.0


static func on_road(pos: Vector3, margin: float = 0.0) -> bool:
	if pos.x > 16.0 + margin or pos.x < -485.0 - margin or pos.z > -190.0 + margin or pos.z < -465.0 - margin:
		return false
	var p := Vector2(pos.x, pos.z)
	var r_max := ASPHALT_HALF_W + margin
	var r_max2 := r_max * r_max
	var pts := get_road_polyline_3d()
	for i in range(pts.size() - 1):
		var a3 := pts[i]
		var b3 := pts[i + 1]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 <= 0.001:
			continue
		var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		if p.distance_squared_to(a + ab * t) <= r_max2:
			return true
	return false


static func _closest_mountain_road_info(p: Vector2) -> Vector2:
	# Devuelve Vector2(distancia_xz, cota_y_carretera). Se recorren todas las muestras:
	# el tramo de aproximación por el valle tiene cota ~0 y solo resulta "el más cercano"
	# junto al pie de la montaña, que es exactamente donde debe tallarse la cornisa baja.
	var pts := get_road_polyline_3d()
	var best_d2 := 1e12
	var best_y := 0.0
	for i in range(pts.size() - 1):
		var a3 := pts[i]
		var b3 := pts[i + 1]
		var a := Vector2(a3.x, a3.z)
		var b := Vector2(b3.x, b3.z)
		var ab := b - a
		var len2 := ab.length_squared()
		if len2 <= 0.001:
			continue
		var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
		var d2 := p.distance_squared_to(a + ab * t)
		if d2 < best_d2:
			best_d2 = d2
			best_y = lerpf(a3.y, b3.y, t)
	return Vector2(sqrt(best_d2), best_y)


static func ground_height_at(pos: Vector3) -> float:
	if pos.x >= -210.0 or pos.z >= -210.0:
		return 0.0
	var p := Vector2(pos.x, pos.z)
	var h := 0.0

	# 1) Macizo principal con meseta plana en la cima (r <= PLATEAU_RADIUS)
	var d_summit2 := p.distance_squared_to(SUMMIT_CENTER)
	var d_summit := sqrt(d_summit2) if d_summit2 < (MASSIF_OUTER_RADIUS + 40.0) * (MASSIF_OUTER_RADIUS + 40.0) else 999.0
	if d_summit <= PLATEAU_RADIUS:
		h = SUMMIT_HEIGHT
	elif d_summit < MASSIF_OUTER_RADIUS:
		var t := (d_summit - PLATEAU_RADIUS) / (MASSIF_OUTER_RADIUS - PLATEAU_RADIUS)
		var smooth := 1.0 - (t * t * (3.0 - 2.0 * t))
		h = SUMMIT_HEIGHT * pow(maxf(0.0, smooth), 1.05)

	# 2) Picos alpinos secundarios (solo fuera de la explanada de la base)
	if d_summit > PLATEAU_RADIUS + 4.0:
		var dome_shield := clampf((d_summit - (PLATEAU_RADIUS + 4.0)) / 18.0, 0.0, 1.0)
		for pk in PEAKS:
			var c: Vector2 = pk["pos"]
			var rx: float = pk["rx"]
			var rz: float = pk["rz"]
			var dx := (p.x - c.x) / rx
			var dz := (p.y - c.y) / rz
			var d2 := dx * dx + dz * dz
			if d2 < 1.0:
				var pct := sqrt(d2)
				var ph: float = float(pk["h"]) * pow(1.0 - pct, 0.82)
				h = maxf(h, lerpf(SUMMIT_HEIGHT, ph, dome_shield))

	# 3) Terraza/cornisa tallada alrededor de la montaña por donde sube la carretera serpenteante
	if pos.x < -235.0 and pos.z < -240.0 and d_summit > 23.5:
		var rinfo := _closest_mountain_road_info(p)
		var dist_road := rinfo.x
		var road_y := rinfo.y
		var outer_blend_w := ROAD_HALF_W + 8.5
		if dist_road < outer_blend_w:
			var blend := 1.0 - smoothstep(ROAD_HALF_W, outer_blend_w, dist_road)
			h = lerpf(h, road_y, blend)
	return h


static func _inside_military_base_compound(p: Vector2, margin: float = 1.5) -> bool:
	var rel := p - SUMMIT_CENTER
	var yaw := -deg_to_rad(BASE_YAW_DEG)
	var c := cos(yaw)
	var s := sin(yaw)
	var lx := rel.x * c - rel.y * s
	var lz := rel.x * s + rel.y * c
	return absf(lx) <= 21.8 + margin and absf(lz) <= 21.8 + margin


static func blocks_vegetation(pos: Vector3) -> bool:
	if on_road(pos, 5.8):
		return true
	if pos.x >= -210.0 or pos.z >= -210.0:
		return false
	var p := Vector2(pos.x, pos.z)
	# Despejar únicamente el interior amurallado de la Base Militar (permitiendo árboles alrededor de la base)
	if _inside_military_base_compound(p, 2.0):
		return true
	# Sin árboles por encima del límite alpino de vegetación (> 59 m)
	if ground_height_at(pos) > 59.0:
		return true
	return false


static func create(world: Node3D, server_only: bool = false) -> void:
	var root := Node3D.new()
	root.name = "HighMountainZone"
	world.add_child(root)
	world.set("_high_mountain_ready", true)

	if not server_only:
		_build_mountain_terrain_mesh(world, root)
		_build_mountain_road_mesh(world, root)
		_build_mountain_road_verges(world)
		_adapt_forest_to_mountain(world)
		_build_mountain_alpine_forest(world, root)

	_build_summit_military_base(world, root, server_only)


static func _adapt_forest_to_mountain(world: Node3D) -> void:
	var tree_grid: Dictionary = world.get("_tree_grid")
	var mm_slots: Dictionary = world.get("_tree_mm_slots")
	var col_grid: Dictionary = world.get("_forest_collision_grid")
	if tree_grid == null or mm_slots == null:
		return
	for key in tree_grid.keys():
		var entries: Array = tree_grid[key]
		for i in range(entries.size() - 1, -1, -1):
			var entry: Dictionary = entries[i]
			var pos: Vector3 = entry.get("pos", Vector3.ZERO)
			if pos.x > 16.0 or pos.z > -208.0:
				continue
			var skey: Vector2i = world._tree_mm_slot_key(pos)
			if blocks_vegetation(pos):
				world._hide_multimesh_tree_at(pos)
				entries.remove_at(i)
				continue
			if pos.x < -210.0 and pos.z < -210.0:
				var hm_y := ground_height_at(pos)
				if hm_y > pos.y + 0.2 and mm_slots.has(skey):
					var new_pos := Vector3(pos.x, hm_y, pos.z)
					entry["pos"] = new_pos
					for slot in mm_slots[skey]:
						var mm: MultiMesh = slot[0]
						var idx: int = slot[1]
						var xf: Transform3D = slot[2]
						xf.origin.y = hm_y
						mm.set_instance_transform(idx, xf)
						slot[2] = xf
	if col_grid != null:
		for ckey in col_grid.keys():
			var pts: Array = col_grid[ckey]
			for j in range(pts.size() - 1, -1, -1):
				var p: Vector3 = pts[j]
				if p.x <= 16.0 and p.z <= -208.0:
					if blocks_vegetation(p):
						pts.remove_at(j)
					elif p.x < -210.0 and p.z < -210.0:
						pts[j] = Vector3(p.x, maxf(p.y, ground_height_at(p)), p.z)


static func _build_mountain_road_mesh(world: Node3D, parent: Node3D) -> void:
	# Construye toda la carretera serpenteante en un único MeshInstance3D continuo (1 draw call)
	# desde la carretera principal Norte-Sur (9, -196), rodeando la montaña hasta la Base Militar (-356, -356, y=+56 m).
	var poly := get_road_polyline_3d()
	var samples: Array[Vector3] = []
	var step_len := 3.2
	for i in range(poly.size() - 1):
		var a: Vector3 = poly[i]
		var b: Vector3 = poly[i + 1]
		var dist := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
		var n_steps := maxi(1, int(ceil(dist / step_len)))
		for s in range(n_steps):
			if i > 0 and s == 0:
				continue
			samples.append(a.lerp(b, float(s) / float(n_steps)))
	samples.append(poly[poly.size() - 1])
	if samples.size() < 2:
		return

	var grid_w := 6
	var road_w := ASPHALT_HALF_W * 2.0
	var half_w := ASPHALT_HALF_W
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var accum_u := 0.0

	for i in range(samples.size()):
		var cur3: Vector3 = samples[i]
		var cur := Vector2(cur3.x, cur3.z)
		if i > 0:
			var prev3: Vector3 = samples[i - 1]
			accum_u += cur.distance_to(Vector2(prev3.x, prev3.z))
		var dir: Vector2
		if i == 0:
			dir = (Vector2(samples[1].x, samples[1].z) - cur).normalized()
		elif i == samples.size() - 1:
			dir = (cur - Vector2(samples[i - 1].x, samples[i - 1].z)).normalized()
		else:
			dir = (Vector2(samples[i + 1].x, samples[i + 1].z) - Vector2(samples[i - 1].x, samples[i - 1].z)).normalized()
		var across := Vector2(-dir.y, dir.x)

		for ix in range(grid_w + 1):
			var tw := float(ix) / float(grid_w)
			var local_w := -half_w + tw * road_w
			var p2 := cur + across * local_w
			var edge_lip := smoothstep(0.75, 1.0, absf(tw * 2.0 - 1.0))
			var deck_lift := lerpf(0.14, 0.04, edge_lip)
			var terrain_y: float = float(world._get_exact_ground_y(p2.x, p2.y))
			var base_y: float = maxf(terrain_y, cur3.y) if (p2.x < -235.0 and p2.y < -240.0) else terrain_y
			var gy: float = base_y + deck_lift
			st.set_color(Color(0.0, 0.0, 0.0, 1.0))
			st.set_uv(Vector2(p2.x, p2.y) * 0.5)
			st.set_uv2(Vector2(tw * 2.0 - 1.0, accum_u))
			st.add_vertex(Vector3(p2.x, gy, p2.y))

	var row_verts := grid_w + 1
	for i in range(samples.size() - 1):
		for ix in range(grid_w):
			var i00 := i * row_verts + ix
			var i10 := i00 + 1
			var i01 := (i + 1) * row_verts + ix
			var i11 := i01 + 1
			st.add_index(i00)
			st.add_index(i01)
			st.add_index(i10)
			st.add_index(i10)
			st.add_index(i01)
			st.add_index(i11)

	st.generate_normals()
	var road_mi := MeshInstance3D.new()
	road_mi.name = "HighMountainRoad"
	road_mi.mesh = st.commit()
	road_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var asphalt_mat := ShaderMaterial.new()
	asphalt_mat.shader = preload("res://scripts/road_surface.gdshader")
	var color_tex := load("res://assets/textures/dirt_road/Ground038_1K-JPG_Color.jpg")
	if color_tex != null:
		asphalt_mat.set_shader_parameter("aggregate", color_tex)
	road_mi.material_override = asphalt_mat
	parent.add_child(road_mi)


static func _build_mountain_road_verges(world: Node3D) -> void:
	# Márgenes de hierba como en el resto de carreteras (mismo patrón que _create_road):
	# matojos densos pegados al asfalto que se abren hacia afuera perdiendo densidad.
	var poly := get_road_polyline_3d()
	if poly.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GameConst.WORLD_SEED ^ 0x52445747 # "RDWG" — stream propio, no altera el RNG del mundo
	var grass_base := Color(0.20, 0.34, 0.12)
	var color_var := Color(0.34, 0.46, 0.16)
	var grass_depth := 8.0
	var tuft_spacing := 0.28
	for i in range(poly.size() - 1):
		var a3: Vector3 = poly[i]
		var b3: Vector3 = poly[i + 1]
		var seg2 := Vector2(b3.x - a3.x, b3.z - a3.z)
		var seg_len := seg2.length()
		if seg_len <= 0.05:
			continue
		var dir2 := seg2 / seg_len
		var across := Vector2(-dir2.y, dir2.x)
		var num_tufts := maxi(1, int(seg_len / tuft_spacing))
		for side in [-1, 1]:
			for t_i in range(num_tufts):
				var t_along := (float(t_i) + 0.5) * tuft_spacing + rng.randf_range(-0.12, 0.12)
				var along2 := dir2 * t_along
				for _j in range(5):
					var t: float = pow(rng.randf(), 1.5)
					var side_f := float(side)
					var edge_x := a3.x + along2.x + across.x * side_f * (ASPHALT_HALF_W - 0.1 + t * grass_depth)
					var edge_z := a3.z + along2.y + across.y * side_f * (ASPHALT_HALF_W - 0.1 + t * grass_depth)
					var gpos := Vector3(edge_x, 0.0, edge_z)
					if world._is_on_road(gpos) or world._is_near_river(gpos, 2.0):
						continue
					gpos.y = float(world._get_exact_ground_y(edge_x, edge_z)) + 0.02
					var density_fade := 1.0 - t
					var h := rng.randf_range(0.15, 0.35) * density_fade
					var r := rng.randf_range(0.18, 0.38)
					var c := grass_base.lerp(color_var, rng.randf()).darkened(rng.randf_range(0.0, 0.12))
					world._queue_grass_instance(gpos, h, r, c)


static func _build_mountain_alpine_forest(world: Node3D, parent: Node3D) -> void:
	var tree_meshes: Array = world.get("_forest_tree_meshes")
	if (tree_meshes == null or tree_meshes.is_empty()) and world.has_method("_load_forest_tree_pack"):
		world._load_forest_tree_pack()
		tree_meshes = world.get("_forest_tree_meshes")
	if tree_meshes == null or tree_meshes.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = GameConst.WORLD_SEED ^ 0x4D544E
	var candidate_positions: Array[Vector3] = []

	# 1) Pinos y abetos rodeando el exterior de la Base Militar en la meseta y corona superior
	for i in range(95):
		var ang := (float(i) / 95.0) * TAU + rng.randf_range(-0.03, 0.03)
		var rad := rng.randf_range(26.5, 46.0)
		var px := SUMMIT_CENTER.x + cos(ang) * rad
		var pz := SUMMIT_CENTER.y + sin(ang) * rad
		var cpos := Vector3(px, 0.0, pz)
		if blocks_vegetation(cpos):
			continue
		cpos.y = float(world._get_exact_ground_y(px, pz))
		candidate_positions.append(cpos)

	# 2) Bosque alpino por todas las laderas de la montaña nueva (entre las vueltas de la carretera)
	for i in range(420):
		var ang := rng.randf_range(0.0, TAU)
		var rad := rng.randf_range(46.0, 142.0)
		var px := SUMMIT_CENTER.x + cos(ang) * rad
		var pz := SUMMIT_CENTER.y + sin(ang) * rad
		if px < -492.0 or pz < -492.0 or px > -212.0 or pz > -212.0:
			continue
		var cpos := Vector3(px, 0.0, pz)
		if blocks_vegetation(cpos):
			continue
		cpos.y = float(world._get_exact_ground_y(px, pz))
		if cpos.y < 1.5 or cpos.y > 58.0:
			continue
		candidate_positions.append(cpos)

	# 3) Arboleda flanqueando el tramo de carretera de aproximación desde el valle hasta el pie del macizo
	for i in range(70):
		var t := rng.randf_range(0.08, 0.96)
		var road_x := lerpf(9.0, -252.0, t)
		var road_z := lerpf(-220.0, -268.0, t)
		var side := -1.0 if (i % 2 == 0) else 1.0
		var offset := rng.randf_range(8.5, 28.0) * side
		var px := road_x + rng.randf_range(-4.0, 4.0)
		var pz := road_z + offset
		var cpos := Vector3(px, 0.0, pz)
		if blocks_vegetation(cpos) or world._is_on_road(cpos):
			continue
		cpos.y = float(world._get_exact_ground_y(px, pz))
		candidate_positions.append(cpos)

	# Filtrar solapamientos entre árboles alpinos (mínimo 3.2 m de separación)
	var accepted: Array[Vector3] = []
	for cpos in candidate_positions:
		var too_close := false
		for prev in accepted:
			if Vector2(cpos.x - prev.x, cpos.z - prev.z).length_squared() < 3.2 * 3.2:
				too_close = true
				break
		if not too_close:
			accepted.append(cpos)

	if accepted.is_empty():
		return

	var variant_batches: Array = []
	for _v in range(tree_meshes.size()):
		variant_batches.append([])

	var col_grid: Dictionary = world.get("_forest_collision_grid")
	var col_cell_size: float = float(world.get("_forest_collision_grid_size")) if world.get("_forest_collision_grid_size") != null else 25.0

	for pos in accepted:
		var v_idx: int = int(world._pick_forest_tree_variant(rng))
		var entry: Dictionary = tree_meshes[v_idx]
		var tree_scale := rng.randf_range(0.88, 1.38)
		var base_height: float = float(entry.get("height", 5.0))
		if base_height * tree_scale < 1.0:
			tree_scale = 1.0 / maxf(0.01, base_height)
		var yaw_deg := rng.randf_range(0.0, 360.0)
		var up_fix_deg: float = float(entry.get("up_fix_deg", -90.0))
		var basis := Basis.from_euler(Vector3(deg_to_rad(up_fix_deg), 0.0, deg_to_rad(yaw_deg))).scaled(Vector3.ONE * tree_scale)
		var xf := Transform3D(basis, pos)
		(variant_batches[v_idx] as Array).append(xf)
		if col_grid != null:
			var ckey := Vector2i(int(floor(pos.x / col_cell_size)), int(floor(pos.z / col_cell_size)))
			if not col_grid.has(ckey):
				col_grid[ckey] = []
			(col_grid[ckey] as Array).append(pos)

	for v_idx in range(tree_meshes.size()):
		var xforms: Array = variant_batches[v_idx]
		if xforms.is_empty():
			continue
		var entry: Dictionary = tree_meshes[v_idx]
		var src_mesh: ArrayMesh = entry.get("mesh", null)
		if src_mesh == null:
			continue
		var count := xforms.size()
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = src_mesh
		mm.instance_count = count
		for j in range(count):
			var t: Transform3D = xforms[j]
			mm.set_instance_transform(j, t)
			var h1 := fposmod(sin(t.origin.x * 12.9898 + t.origin.z * 78.233) * 43758.5453, 1.0)
			var h2 := fposmod(sin(t.origin.x * 39.3467 + t.origin.z * 11.135) * 24634.6345, 1.0)
			var h3 := fposmod(sin(t.origin.x * 73.156 + t.origin.z * 52.235) * 18456.321, 1.0)
			mm.set_instance_custom_data(j, Color(h1, h2, h3, 1.0))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "MountainAlpineForestMM_%d" % v_idx
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		parent.add_child(mmi)

		var branch_mesh: ArrayMesh = entry.get("branch_mesh", null)
		if branch_mesh != null:
			var bmm := MultiMesh.new()
			bmm.transform_format = MultiMesh.TRANSFORM_3D
			bmm.use_custom_data = true
			bmm.mesh = branch_mesh
			bmm.instance_count = count
			for j in range(count):
				var bt: Transform3D = xforms[j]
				bmm.set_instance_transform(j, bt)
				var h1 := fposmod(sin(bt.origin.x * 12.9898 + bt.origin.z * 78.233) * 43758.5453, 1.0)
				var h2 := fposmod(sin(bt.origin.x * 39.3467 + bt.origin.z * 11.135) * 24634.6345, 1.0)
				var h3 := fposmod(sin(bt.origin.x * 73.156 + bt.origin.z * 52.235) * 18456.321, 1.0)
				bmm.set_instance_custom_data(j, Color(h1, h2, h3, 1.0))
			var bmmi := MultiMeshInstance3D.new()
			bmmi.name = "MountainAlpineForestMM_%d_leaves" % v_idx
			bmmi.multimesh = bmm
			bmmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			parent.add_child(bmmi)


static func _build_mountain_terrain_mesh(world: Node3D, parent: Node3D) -> void:
	# Malla de terreno continua para el macizo Noroeste (-510..-220 en X y Z)
	var x0 := -510.0
	var z0 := -510.0
	var span := 290.0
	var steps := 88
	var step := span / float(steps)
	var uv_scale := 1.0 / 1000.0

	var st_rock := SurfaceTool.new()
	st_rock.begin(Mesh.PRIMITIVE_TRIANGLES)

	for iz in range(steps):
		var za := z0 + float(iz) * step
		var zb := za + step
		for ix in range(steps):
			var xa := x0 + float(ix) * step
			var xb := xa + step
			var ya0 := ground_height_at(Vector3(xa, 0.0, za))
			var yb0 := ground_height_at(Vector3(xb, 0.0, za))
			var yc0 := ground_height_at(Vector3(xa, 0.0, zb))
			var yd0 := ground_height_at(Vector3(xb, 0.0, zb))
			if ya0 <= 0.05 and yb0 <= 0.05 and yc0 <= 0.05 and yd0 <= 0.05:
				continue
			var va := Vector3(xa, ya0 - 0.15, za)
			var vb := Vector3(xb, yb0 - 0.15, za)
			var vc := Vector3(xa, yc0 - 0.15, zb)
			var vd := Vector3(xb, yd0 - 0.15, zb)

			st_rock.set_uv(Vector2(va.x * uv_scale + 0.5, va.z * uv_scale + 0.5))
			st_rock.add_vertex(va)
			st_rock.set_uv(Vector2(vb.x * uv_scale + 0.5, vb.z * uv_scale + 0.5))
			st_rock.add_vertex(vb)
			st_rock.set_uv(Vector2(vc.x * uv_scale + 0.5, vc.z * uv_scale + 0.5))
			st_rock.add_vertex(vc)

			st_rock.set_uv(Vector2(vb.x * uv_scale + 0.5, vb.z * uv_scale + 0.5))
			st_rock.add_vertex(vb)
			st_rock.set_uv(Vector2(vd.x * uv_scale + 0.5, vd.z * uv_scale + 0.5))
			st_rock.add_vertex(vd)
			st_rock.set_uv(Vector2(vc.x * uv_scale + 0.5, vc.z * uv_scale + 0.5))
			st_rock.add_vertex(vc)

	st_rock.generate_normals()
	var rock_mesh := st_rock.commit()
	var mi := MeshInstance3D.new()
	mi.name = "HighMountainMassif"
	mi.mesh = rock_mesh
	if world.get("_cached_leafy_material") != null:
		mi.material_override = world.get("_cached_leafy_material")
	else:
		mi.material_override = MaterialFactory.make_forest_ground_material()
	var sb := StaticBody3D.new()
	sb.name = "HighMountainMassifCol"
	sb.set_collision_layer_value(1, true)
	var cs := CollisionShape3D.new()
	cs.shape = rock_mesh.create_trimesh_shape()
	sb.add_child(cs)
	mi.add_child(sb)
	parent.add_child(mi)


static func spawn_summit_base_loot(world: Node3D, tmpl: Dictionary) -> void:
	# Loot militar de la cima: tiendas de la base, pie de la torre, plataforma de la
	# torre de vigilancia y nido de francotirador del piso superior de la Green Mountain.
	# Se llama desde _create_house_loot (cliente/host); IDs fijos, sin consumir RNG.
	var yaw_rad := deg_to_rad(BASE_YAW_DEG)
	var base_origin := Vector3(SUMMIT_CENTER.x, SUMMIT_HEIGHT, SUMMIT_CENTER.y)
	var floor_y := SUMMIT_HEIGHT + 0.06

	var tent_a := base_origin + TENT_A_OFFSET.rotated(Vector3.UP, yaw_rad)
	var tent_a_yaw := deg_to_rad(BASE_YAW_DEG + 90.0)
	var tent_b := base_origin + TENT_B_OFFSET.rotated(Vector3.UP, yaw_rad)
	var tent_b_yaw := deg_to_rad(BASE_YAW_DEG - 90.0)
	var ct := base_origin + COMMS_TOWER_OFFSET.rotated(Vector3.UP, yaw_rad)
	var wt := base_origin + WATCH_TOWER_OFFSET.rotated(Vector3.UP, yaw_rad)

	var put := func(id: String, key: String, pos: Vector3, fy: float) -> void:
		var d: Dictionary = (tmpl[key] as Dictionary).duplicate()
		d["id"] = id
		# pos.y debe ser la cota absoluta del suelo: la acción y _dropped_items
		# registran esta posición para alcance/interacción, no el nodo visual.
		pos.y = fy
		d["pos"] = pos
		d["floor_y"] = fy
		world._create_pickup_item(d)

	# Tienda A (mirando al Noreste): francotirador + casco + pantalones + comida
	var ta_spots := [
		["summit_tentA_loot_rifle", "rifle", Vector3(1.1, 0.0, -2.0)],
		["summit_tentA_loot_mag", "mag", Vector3(0.5, 0.0, -2.4)],
		["summit_tentA_loot_helmet", "helmet", Vector3(-1.6, 0.0, 1.6)],
		["summit_tentA_loot_pants", "pants", Vector3(1.5, 0.0, 1.4)],
		["summit_tentA_loot_food", "food", Vector3(-0.9, 0.0, 0.4)],
	]
	for s in ta_spots:
		put.call(s[0], s[1], tent_a + (s[2] as Vector3).rotated(Vector3.UP, tent_a_yaw), floor_y)

	# Tienda B (mirando al Suroeste): M4 + 2 cargadores + chaleco + mochila + comida
	var tb_spots := [
		["summit_tentB_loot_m4", "m4", Vector3(1.2, 0.0, -2.2)],
		["summit_tentB_loot_m4mag_0", "m4_mag", Vector3(0.4, 0.0, -2.5)],
		["summit_tentB_loot_m4mag_1", "m4_mag", Vector3(1.0, 0.0, -2.5)],
		["summit_tentB_loot_vest", "vest", Vector3(1.6, 0.0, -1.4)],
		["summit_tentB_loot_pack", "backpack", Vector3(1.8, 0.0, 1.8)],
		["summit_tentB_loot_food", "food", Vector3(-1.2, 0.0, 0.8)],
	]
	for s in tb_spots:
		put.call(s[0], s[1], tent_b + (s[2] as Vector3).rotated(Vector3.UP, tent_b_yaw), floor_y)

	# Pie de la torre junto a la puerta del búnker de entrada (local -X, +Z del fuste)
	var tower_local := func(p: Vector3) -> Vector3:
		return ct + p.rotated(Vector3.UP, yaw_rad)
	var foot_spots := [
		["summit_towerfoot_m4", "m4", Vector3(-7.1, 0.0, 3.4)],
		["summit_towerfoot_m4mag", "m4_mag", Vector3(-6.6, 0.0, 2.6)],
		["summit_towerfoot_jacket", "jacket", Vector3(-6.9, 0.0, 4.3)],
	]
	for s in foot_spots:
		put.call(s[0], s[1], tower_local.call(s[2]), floor_y)

	# Plataforma de la torre de vigilancia de la base (~9.4 m sobre la meseta)
	var wt_top_y := 64.45
	var wt_spots := [
		["summit_watchtower_vest", "vest", Vector3(0.9, 0.0, 0.6)],
		["summit_watchtower_food", "food", Vector3(-1.2, 0.0, -0.8)],
	]
	for s in wt_spots:
		put.call(s[0], s[1], wt + (s[2] as Vector3).rotated(Vector3.UP, yaw_rad), wt_top_y)

	# Nido de francotirador del piso superior (cubierta 6, +52 m local): rifle + 2 cargadores,
	# en el lado opuesto a la escotilla de la escalera (hatch a 20° -> loot a ~200°)
	var nest_y := SUMMIT_HEIGHT + 52.06
	var nest_ang := deg_to_rad(200.0)
	var nest_center := Vector3(sin(nest_ang) * 2.45, 0.0, cos(nest_ang) * 2.45)
	var nest_spots := [
		["summit_tower_nest_rifle", "rifle", nest_center],
		["summit_tower_nest_mag_0", "mag", nest_center + Vector3(0.55, 0.0, 0.15)],
		["summit_tower_nest_mag_1", "mag", nest_center + Vector3(0.15, 0.0, 0.55)],
	]
	for s in nest_spots:
		put.call(s[0], s[1], tower_local.call(s[2]), nest_y)


static func _build_summit_military_base(world: Node3D, parent: Node3D, server_only: bool) -> void:
	var base_origin := Vector3(SUMMIT_CENTER.x, SUMMIT_HEIGHT, SUMMIT_CENTER.y)
	var yaw_rad := deg_to_rad(BASE_YAW_DEG)

	# 1) Perímetro de barricadas de hormigón (24x24 m con puerta hacia la rampa Sureste +Z local)
	var wall_scale := Vector3(2.2, 2.2, 2.2)
	var wall_step := 3.90
	var wall_len := 4.05
	var wall_h := 1.90
	var wall_thick := 1.42
	var x_min := -21.45
	var x_max := 21.45
	var z_min := -21.45
	var z_max := 21.45
	var gate_half := 4.2
	var seg_idx := 0

	for side_i in range(2):
		var z_local: float = z_min if side_i == 0 else z_max
		var is_front := (side_i == 1)
		for bi in range(11):
			var x_cur := x_min + (float(bi) + 0.5) * wall_step
			if is_front and absf(x_cur) < gate_half:
				continue
			var wpos := base_origin + Vector3(x_cur, 0.0, z_local).rotated(Vector3.UP, yaw_rad)
			wpos.y = SUMMIT_HEIGHT
			if not server_only:
				world._try_instance_external_scene(
					["res://assets/models/props/concrete_barricade.glb"],
					"SummitBaseWall_%d" % seg_idx,
					wpos,
					wall_scale,
					Vector3(0.0, BASE_YAW_DEG, 0.0),
					false,
					0.0
				)
			world._create_invisible_collision_box_rotated(
				"SummitBaseWallCol_%d" % seg_idx,
				wpos,
				Vector3(wall_len, wall_h, wall_thick),
				BASE_YAW_DEG
			)
			world._register_wildlife_blocker(wpos, 2.1)
			seg_idx += 1

	for side_x_i in range(2):
		var side_x: float = x_min if side_x_i == 0 else x_max
		var wall_yaw := BASE_YAW_DEG + 90.0
		for z_i in range(10):
			var z_cur := z_min + (float(z_i) + 1.0) * wall_step
			var wpos := base_origin + Vector3(side_x, 0.0, z_cur).rotated(Vector3.UP, yaw_rad)
			wpos.y = SUMMIT_HEIGHT
			if not server_only:
				world._try_instance_external_scene(
					["res://assets/models/props/concrete_barricade.glb"],
					"SummitBaseWall_%d" % seg_idx,
					wpos,
					wall_scale,
					Vector3(0.0, wall_yaw, 0.0),
					false,
					0.0
				)
			world._create_invisible_collision_box_rotated(
				"SummitBaseWallCol_%d" % seg_idx,
				wpos,
				Vector3(wall_len, wall_h, wall_thick),
				wall_yaw
			)
			world._register_wildlife_blocker(wpos, 2.1)
			seg_idx += 1

	# 2) Torre de vigilancia militar actual en la esquina delantera junto a la entrada
	var wt_world := base_origin + WATCH_TOWER_OFFSET.rotated(Vector3.UP, yaw_rad)
	var wt_scale := Vector3(0.85, 0.85, 0.85)
	var wt_pos := Vector3(wt_world.x, SUMMIT_HEIGHT - 1.145 * wt_scale.y, wt_world.z)
	if not server_only:
		world._try_instance_external_scene(
			["res://assets/models/props/military_watch_tower.glb"],
			"SummitMilitaryWatchTower",
			wt_pos,
			wt_scale,
			Vector3(0.0, BASE_YAW_DEG, 0.0),
			false,
			0.0
		)
		if world._try_instance_external_scene(
			["res://assets/models/props/watchtower_camo_net.glb"],
			"SummitMilitaryWatchTowerCamoNet",
			wt_pos,
			wt_scale,
			Vector3(0.0, BASE_YAW_DEG, 0.0),
			false,
			0.0
		):
			world._apply_camo_net_material(world.get_node_or_null("SummitMilitaryWatchTowerCamoNet"))
	world._register_wildlife_blocker(wt_world, 4.0)
	_build_summit_watchtower_collision(world, wt_pos, wt_scale, BASE_YAW_DEG)

	# 3) Tiendas militares en la explanada
	for t_i in range(2):
		var t_off: Vector3 = TENT_A_OFFSET if t_i == 0 else TENT_B_OFFSET
		var t_yaw: float = BASE_YAW_DEG + (90.0 if t_i == 0 else -90.0)
		var t_pos := base_origin + t_off.rotated(Vector3.UP, yaw_rad)
		t_pos.y = SUMMIT_HEIGHT
		var t_name := "SummitMilitaryTent_%d" % t_i
		if not server_only:
			world._try_instance_external_scene(
				["res://assets/models/props/tent/tent_military.glb"],
				t_name,
				t_pos,
				Vector3.ONE * 1.5,
				Vector3(0.0, t_yaw, 0.0),
				true,
				0.0
			)
			var t_node := world.get_node_or_null(t_name) as Node3D
			if t_node != null:
				world._build_military_tent_collision(t_node, t_name + "_Col", t_name + "_RoofCol")
		world._register_wildlife_blocker(t_pos, 4.5)

	# 4) Torre de Comunicaciones estilo DayZ Green Mountain (68 m de altura + 6 pisos + escaleras de mano)
	var ct_pos := base_origin + COMMS_TOWER_OFFSET.rotated(Vector3.UP, yaw_rad)
	ct_pos.y = SUMMIT_HEIGHT
	_spawn_green_mountain_comms_tower(world, parent, ct_pos, BASE_YAW_DEG, server_only)


static func _spawn_green_mountain_comms_tower(world: Node3D, parent: Node3D, tower_pos: Vector3, yaw_deg: float, server_only: bool) -> void:
	var packed := load("res://assets/models/props/military_comms_tower.glb") as PackedScene
	if packed == null:
		return
	var inst := packed.instantiate() as Node3D
	inst.name = "GreenMountainCommsTower"
	inst.position = tower_pos
	inst.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	parent.add_child(inst)

	for child in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi.name.begins_with("Solid_") or mi.name.begins_with("Collision_"):
			mi.create_trimesh_collision()
			for sb in mi.get_children():
				if sb is StaticBody3D:
					(sb as StaticBody3D).set_collision_layer_value(1, true)
					(sb as StaticBody3D).set_collision_layer_value(3, true)
		if mi.name.begins_with("Detail_"):
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mi.name.begins_with("Collision_"):
			mi.visible = false
		elif server_only:
			mi.visible = false

	# Registrar los 6 tramos de escalera de mano (ladder_volume) en coordenadas globales
	var yaw_rad := deg_to_rad(yaw_deg)
	for entry in LADDER_FLIGHTS_META:
		var f_idx: int = int(entry[0])
		var y0_local: float = float(entry[1])
		var y1_local: float = float(entry[2])
		var ang_deg: float = float(entry[3])
		var r_shaft: float = float(entry[4])
		var r_climb: float = r_shaft + 0.74
		var ang_local := deg_to_rad(ang_deg)
		var local_offset := Vector3(sin(ang_local) * r_climb, 0.0, cos(ang_local) * r_climb)
		var world_offset := local_offset.rotated(Vector3.UP, yaw_rad)
		var local_inward := Vector3(-sin(ang_local), 0.0, -cos(ang_local)).rotated(Vector3.UP, yaw_rad)

		var lnode := Node3D.new()
		lnode.name = "CommsTowerLadderVolume_%d" % f_idx
		lnode.position = tower_pos + Vector3(world_offset.x, 0.5 * (y0_local + y1_local), world_offset.z)
		lnode.set_meta("ladder_bottom_y", tower_pos.y + y0_local)
		lnode.set_meta("ladder_top_y", tower_pos.y + y1_local)
		lnode.set_meta("ladder_center_xz", Vector2(tower_pos.x + world_offset.x, tower_pos.z + world_offset.z))
		lnode.set_meta("ladder_inward_dir", Vector2(local_inward.x, local_inward.z).normalized())
		lnode.add_to_group("ladder_volume")
		parent.add_child(lnode)

	world._register_wildlife_blocker(tower_pos, 7.8)


static func _build_summit_watchtower_collision(world: Node3D, tower_pos: Vector3, tower_scale: Vector3, yaw_deg: float) -> void:
	# Reutiliza la misma geometría de colisión de _build_military_watchtower_collision
	# orientada con yaw_deg para la torre de vigilancia de la cima.
	var rig := Node3D.new()
	rig.name = "SummitMilitaryWatchTowerCollision"
	rig.position = tower_pos
	rig.rotation_degrees.y = yaw_deg
	rig.scale = tower_scale
	world.add_child(rig)
	var stairs := StaticBody3D.new()
	stairs.name = "Stairs"
	stairs.collision_layer = 1
	stairs.collision_mask = 3
	stairs.add_to_group("stair_surface")
	rig.add_child(stairs)
	var solid := StaticBody3D.new()
	solid.name = "Solid"
	solid.collision_layer = 1
	solid.collision_mask = 3
	rig.add_child(solid)
	world._watchtower_ramp(stairs, Vector3(-0.30, 1.12, -2.50), Vector3(-1.90, 2.01, -2.50), 1.24)
	world._watchtower_ramp(stairs, Vector3(-2.50, 2.01, -1.90), Vector3(-2.50, 4.25, 1.90), 1.24)
	world._watchtower_ramp(stairs, Vector3(-1.90, 4.25, 2.50), Vector3(1.90, 6.49, 2.50), 1.24)
	world._watchtower_ramp(stairs, Vector3(2.50, 6.49, 1.90), Vector3(2.50, 8.73, -1.68), 1.24)
	world._watchtower_ramp(stairs, Vector3(1.90, 8.73, -2.50), Vector3(-1.92, 10.99, -2.50), 1.24)
	world._watchtower_box(solid, Vector3(-2.50, 1.93, -2.50), Vector3(1.24, 0.16, 1.24))
	world._watchtower_box(solid, Vector3(-2.50, 4.17, 2.50), Vector3(1.24, 0.16, 1.24))
	world._watchtower_box(solid, Vector3(2.50, 6.41, 2.50), Vector3(1.24, 0.16, 1.24))
	world._watchtower_box(solid, Vector3(2.50, 8.65, -2.38), Vector3(1.24, 0.16, 1.48))
	world._watchtower_box(solid, Vector3(-0.62, 10.93, 0.64), Vector3(5.08, 0.12, 4.96))
	world._watchtower_box(solid, Vector3(2.52, 10.93, 0.84), Vector3(1.24, 0.12, 4.56))
	world._watchtower_box(solid, Vector3(-2.53, 10.93, -2.48), Vector3(1.22, 0.12, 1.28))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			world._watchtower_box(solid, Vector3(2.95 * sx, 1.48, 2.95 * sz), Vector3(0.32, 0.72, 0.32))
	world._watchtower_box(solid, Vector3(0.0, 8.50, -1.84), Vector3(3.76, 13.20, 0.08))
	world._watchtower_box(solid, Vector3(-1.84, 6.40, 0.0), Vector3(0.08, 9.00, 3.76))
	world._watchtower_box(solid, Vector3(0.0, 8.50, 1.84), Vector3(3.76, 13.20, 0.08))
	world._watchtower_box(solid, Vector3(1.84, 8.50, 0.0), Vector3(0.08, 13.20, 3.76))
	world._watchtower_box(solid, Vector3(-1.75, 2.00, -3.16), Vector3(2.90, 1.80, 0.08))
	world._watchtower_box(solid, Vector3(-3.16, 6.50, 0.0), Vector3(0.08, 11.20, 6.40))
	world._watchtower_box(solid, Vector3(0.0, 8.00, 3.16), Vector3(6.40, 8.20, 0.08))
	world._watchtower_box(solid, Vector3(3.16, 9.20, 0.0), Vector3(0.08, 6.80, 6.40))
	world._watchtower_box(solid, Vector3(0.0, 10.60, -3.16), Vector3(6.40, 4.00, 0.08))
	world._watchtower_box(solid, Vector3(2.52, 11.65, -1.42), Vector3(1.24, 1.30, 0.08))
	world._watchtower_box(solid, Vector3(-1.84, 13.05, -1.25), Vector3(0.08, 4.10, 1.26))
	world._watchtower_box(solid, Vector3(-1.84, 13.05, 1.25), Vector3(0.08, 4.10, 1.26))
	world._watchtower_box(solid, Vector3(-1.84, 14.68, 0.0), Vector3(0.08, 0.84, 1.24))
	world._watchtower_box(solid, Vector3(0.0, 15.05, 0.0), Vector3(3.76, 0.16, 3.76))
