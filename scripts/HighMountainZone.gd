extends RefCounted
class_name HighMountainZone

# Centro de la meseta militar en la cumbre Noroeste y su cota (+56 m)
const SUMMIT_CENTER := Vector2(-375.0, -375.0)
const SUMMIT_HEIGHT := 56.0
const PLATEAU_RADIUS := 36.0
const MASSIF_OUTER_RADIUS := 132.0
const BASE_YAW_DEG := 45.0 # Mira hacia el Sureste (+X, +Z, hacia el valle central)

# Picos secundarios que rodean la cumbre por el Norte y Oeste formando la cordillera
const PEAKS := [
	{"pos": Vector2(-448.0, -432.0), "rx": 68.0, "rz": 58.0, "h": 78.0},
	{"pos": Vector2(-362.0, -458.0), "rx": 64.0, "rz": 54.0, "h": 72.0},
	{"pos": Vector2(-462.0, -345.0), "rx": 62.0, "rz": 56.0, "h": 70.0},
	{"pos": Vector2(-292.0, -445.0), "rx": 56.0, "rz": 50.0, "h": 62.0},
	{"pos": Vector2(-445.0, -268.0), "rx": 54.0, "rz": 50.0, "h": 58.0},
]

# Rampa/camino militar que sube desde el Sureste (-275, -275) hasta la puerta de la meseta (-349, -349)
const ROAD_START := Vector2(-272.0, -272.0)
const ROAD_END := Vector2(-350.0, -350.0)
const ROAD_HALF_W := 6.5

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


static func ground_height_at(pos: Vector3) -> float:
	if pos.x >= -210.0 or pos.z >= -210.0:
		return 0.0
	var p := Vector2(pos.x, pos.z)
	var h := 0.0

	# 1) Macizo principal con meseta plana en la cima (r <= PLATEAU_RADIUS)
	var d_summit := p.distance_to(SUMMIT_CENTER)
	if d_summit <= PLATEAU_RADIUS:
		h = SUMMIT_HEIGHT
	elif d_summit < MASSIF_OUTER_RADIUS:
		var t := (d_summit - PLATEAU_RADIUS) / (MASSIF_OUTER_RADIUS - PLATEAU_RADIUS)
		var smooth := 1.0 - (t * t * (3.0 - 2.0 * t))
		h = SUMMIT_HEIGHT * pow(maxf(0.0, smooth), 1.05)

	# 2) Rampa/camino militar de subida por la ladera Sureste (pendiente constante y suave)
	var seg := ROAD_END - ROAD_START
	var seg_len2 := seg.length_squared()
	if seg_len2 > 0.01:
		var u := clampf((p - ROAD_START).dot(seg) / seg_len2, 0.0, 1.0)
		var closest := ROAD_START + seg * u
		var dist_road := p.distance_to(closest)
		if dist_road < ROAD_HALF_W + 10.0:
			var road_h := SUMMIT_HEIGHT * smoothstep(0.0, 1.0, u)
			var blend := 1.0 - smoothstep(ROAD_HALF_W, ROAD_HALF_W + 10.0, dist_road)
			h = lerpf(h, maxf(h, road_h), blend)

	# 3) Picos alpinos secundarios (solo fuera de la explanada de la base)
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
	return h


static func blocks_vegetation(pos: Vector3) -> bool:
	if pos.x >= -210.0 or pos.z >= -210.0:
		return false
	var p := Vector2(pos.x, pos.z)
	# Despejar la explanada militar de la cima y el camino de subida
	if p.distance_to(SUMMIT_CENTER) < PLATEAU_RADIUS + 5.0:
		return true
	var seg := ROAD_END - ROAD_START
	var u := clampf((p - ROAD_START).dot(seg) / seg.length_squared(), 0.0, 1.0)
	if p.distance_to(ROAD_START + seg * u) < ROAD_HALF_W + 2.5:
		return true
	# Sin árboles en las cumbres nevadas muy altas (> 58 m)
	if ground_height_at(pos) > 58.0:
		return true
	return false


static func create(world: Node3D, server_only: bool = false) -> void:
	var root := Node3D.new()
	root.name = "HighMountainZone"
	world.add_child(root)
	world.set("_high_mountain_ready", true)

	if not server_only:
		_build_mountain_terrain_mesh(world, root)
		_adapt_forest_to_mountain(world)

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
			if pos.x >= -210.0 or pos.z >= -210.0:
				continue
			var skey: Vector2i = world._tree_mm_slot_key(pos)
			if blocks_vegetation(pos):
				world._hide_multimesh_tree_at(pos)
				entries.remove_at(i)
				continue
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
				if p.x < -210.0 and p.z < -210.0:
					if blocks_vegetation(p):
						pts.remove_at(j)
					else:
						pts[j] = Vector3(p.x, maxf(p.y, ground_height_at(p)), p.z)


static func _build_mountain_terrain_mesh(world: Node3D, parent: Node3D) -> void:
	# Malla de terreno continua para el macizo Noroeste (-510..-220 en X y Z)
	var x0 := -510.0
	var z0 := -510.0
	var span := 290.0
	var steps := 72
	var step := span / float(steps)
	var uv_scale := 1.0 / 1000.0

	var st_rock := SurfaceTool.new()
	st_rock.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_snow := SurfaceTool.new()
	st_snow.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_snow := false

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

			# Capa de nieve alpina en las cumbres altas (> 59 m, fuera de la meseta)
			var avg_y := 0.25 * (ya0 + yb0 + yc0 + yd0)
			var d_plat := Vector2(0.5 * (xa + xb), 0.5 * (za + zb)).distance_to(SUMMIT_CENTER)
			if avg_y > 58.5 and d_plat > PLATEAU_RADIUS + 6.0:
				has_snow = true
				var lift := Vector3(0.0, 0.08, 0.0)
				st_snow.add_vertex(va + lift)
				st_snow.add_vertex(vb + lift)
				st_snow.add_vertex(vc + lift)
				st_snow.add_vertex(vb + lift)
				st_snow.add_vertex(vd + lift)
				st_snow.add_vertex(vc + lift)

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

	if has_snow:
		st_snow.generate_normals()
		var snow_mi := MeshInstance3D.new()
		snow_mi.name = "HighMountainSnowCaps"
		snow_mi.mesh = st_snow.commit()
		snow_mi.material_override = MaterialFactory.make_material(Color(0.84, 0.87, 0.90), true)
		parent.add_child(snow_mi)


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
				SUMMIT_HEIGHT
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
		var r_climb: float = r_shaft + 0.88
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
