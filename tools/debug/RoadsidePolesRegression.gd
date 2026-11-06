extends SceneTree

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func _min_dist_to_road_center(world: World, p: Vector3) -> float:
	var best := INF
	for seg in world._road_segments:
		var c: Vector3 = seg["center"]
		var yaw: float = deg_to_rad(float(seg["yaw"]))
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var across := Vector3(sin(yaw), 0.0, cos(yaw))
		var half_l: float = float(seg["size"].x) * 0.5
		var off := p - c
		var la := clampf(off.dot(along), -half_l, half_l)
		var closest := c + along * la
		var d := Vector2(p.x - closest.x, p.z - closest.z).length()
		if d < best:
			best = d
	return best

func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	world._terrain_rng.seed = world.TERRAIN_SEED
	world._world_rng.seed = GameConst.WORLD_SEED
	world.river_segments_data = world._default_river_segments()
	world._road_segments = world._generate_road_segments()
	world._create_road()
	world._spawn_roadside_street_light("QStreetLightA", -22.0, -1.0)
	world._spawn_roadside_street_light("QStreetLightB", 14.0, -1.0)
	world._create_power_line(Vector3(15, 0, -40), Vector3(15, 0, 40))
	preload("res://scripts/CityStreetscape.gd")._telephone_poles(world)
	await process_frame
	await process_frame

	var errors := 0
	var light_count := 0
	var tele_count := 0
	var city_tele_count := 0
	var light_positions: Array[Vector3] = []
	var tele_positions: Array[Vector3] = []
	var city_tele_positions: Dictionary = {} # street index -> Array[Vector3]
	var city_wire_count := 0
	var max_pole_base_y := -INF
	var extra_pole_meshes := ["Object_8", "Object_10", "Object_11", "Object_12", "Object_14", "Object_16", "Object_17", "Object_18", "Object_20", "Object_22", "Object_23", "Object_24", "Object_26", "Object_28"]

	for c in world.get_children():
		if not (c is Node3D):
			continue
		var nm := str(c.name)
		var is_city_tele := nm.begins_with("CityTelephonePole_")
		var is_light := nm.begins_with("RoadLight_") or nm.begins_with("QStreetLight")
		var is_tele := nm.begins_with("RoadTelephonePole_") or nm.begins_with("TelephonePoleGLB_")
		if nm.begins_with("CityTelephoneWires_"):
			city_wire_count += 1
			continue
		if not is_light and not is_tele and not is_city_tele:
			continue
		if nm.ends_with("Collision"):
			continue
		var p: Vector3 = (c as Node3D).global_position
		var ground_p := Vector3(p.x, 0.0, p.z)
		if is_city_tele:
			city_tele_count += 1
			max_pole_base_y = maxf(max_pole_base_y, p.y)
			# Poles on perpendicular streets legitimately sit ~5 m apart at
			# intersections — only flag overlaps within the same street run.
			var street_key := nm.get_slice("_", 1)
			if not city_tele_positions.has(street_key):
				city_tele_positions[street_key] = []
			var same_street: Array = city_tele_positions[street_key]
			for prev in same_street:
				if Vector2(p.x - prev.x, p.z - prev.z).length() < 9.0:
					print("FAIL overlapping city tele poles: ", nm, " pos=", p, " prev=", prev)
					errors += 1
			same_street.append(p)
			if p.y > 1.5:
				print("FAIL floating city pole: ", nm, " pos=", p)
				errors += 1
			if world.get_river_depth_at(ground_p) > 0.0 or world._is_near_river(ground_p, 2.5):
				print("FAIL city pole water: ", nm, " pos=", ground_p)
				errors += 1
			if preload("res://scripts/CityExpansion.gd").on_road(ground_p, 1.6, world._south_road_end()):
				print("FAIL city pole on road: ", nm, " pos=", ground_p)
				errors += 1
			if preload("res://scripts/CityExpansion.gd").near_building(ground_p, 1.0):
				print("FAIL city pole in building: ", nm, " pos=", ground_p)
				errors += 1
			continue
		if is_light:
			light_count += 1
			for prev in light_positions:
				if Vector2(p.x - prev.x, p.z - prev.z).length() < 12.0:
					print("FAIL overlapping street lights: ", nm, " pos=", p, " prev=", prev)
					errors += 1
			light_positions.append(p)
		if is_tele:
			tele_count += 1
			max_pole_base_y = maxf(max_pole_base_y, p.y)
			for prev in tele_positions:
				if Vector2(p.x - prev.x, p.z - prev.z).length() < 9.0:
					print("FAIL overlapping tele poles: ", nm, " pos=", p, " prev=", prev)
					errors += 1
			tele_positions.append(p)
		if p.y > 1.5:
			print("FAIL floating pole: ", nm, " pos=", p)
			errors += 1
		var r_depth := world.get_river_depth_at(ground_p)
		var near_riv := world._is_near_river(ground_p, 3.5)
		var on_road := world._is_on_road(ground_p)
		var dist_center := _min_dist_to_road_center(world, ground_p)
		if r_depth > 0.0 or near_riv:
			print("FAIL water: ", nm, " pos=", ground_p, " depth=", r_depth, " near_riv=", near_riv)
			errors += 1
		if on_road or dist_center < 4.5:
			print("FAIL on_road: ", nm, " pos=", ground_p, " on_road=", on_road, " dist_center=", dist_center)
			errors += 1
		if dist_center > 8.5:
			print("FAIL too_far_from_road: ", nm, " pos=", ground_p, " dist_center=", dist_center)
			errors += 1
		var meshes: Array = []
		NodeUtils.collect_mesh_instances(c, meshes)
		for m in meshes:
			var mi := m as MeshInstance3D
			if is_tele and str(mi.name) in extra_pole_meshes:
				print("FAIL multi-pole mesh still present: ", nm, "/", mi.name)
				errors += 1
			var waabb: AABB = mi.global_transform * mi.get_aabb()
			var mc := Vector3(waabb.get_center().x, 0.0, waabb.get_center().z)
			if world.get_river_depth_at(mc) > 0.0 or world._is_near_river(mc, 2.0):
				print("FAIL mesh in water: ", nm, "/", mi.name, " center=", mc)
				errors += 1
			if is_tele and world._is_on_road(mc):
				print("FAIL tele mesh on road: ", nm, "/", mi.name, " center=", mc)
				errors += 1

	var wires := world.get_node_or_null("RoadTelephoneWires") as MeshInstance3D
	if wires == null or wires.mesh == null or wires.mesh.get_surface_count() == 0:
		print("FAIL missing RoadTelephoneWires mesh")
		errors += 1
	# Every wire mesh must hug the pole tops (~4.0 m above base), never float
	# metres overhead like the old y=42.2 local pin bug did.
	for c in world.get_children():
		if not (c is MeshInstance3D):
			continue
		var wnm := str(c.name)
		if not (wnm.begins_with("RoadTelephoneWires") or wnm.begins_with("PowerLineWires") or wnm.begins_with("CityTelephoneWires_")):
			continue
		var waabb: AABB = (c as MeshInstance3D).global_transform * (c as MeshInstance3D).get_aabb()
		if max_pole_base_y > -INF and waabb.end.y > max_pole_base_y + 5.0:
			print("FAIL floating wires: ", wnm, " top=", waabb.end.y, " max_pole_base=", max_pole_base_y)
			errors += 1
	if city_tele_count < 30 or city_wire_count < 6:
		print("FAIL too few city tele poles/wires: poles=", city_tele_count, " wires=", city_wire_count)
		errors += 1
	if light_count < 10 or tele_count < 22:
		print("FAIL too few poles placed: lights=", light_count, " tele=", tele_count)
		errors += 1

	print("ROADSIDE_POLES lights=%d tele=%d city_tele=%d city_wires=%d wires=%s errors=%d" % [light_count, tele_count, city_tele_count, city_wire_count, str(wires != null and wires.mesh != null), errors])
	world.free()
	quit(1 if errors > 0 else 0)
