extends SceneTree
## City furniture must match the VILLAGE houses' placed sizes
## (Main._create_house_interior) and every bed must be sleepable through a
## BedInteractable area that encloses its frame collider (aim-ray safe).
var failures := 0
func check(ok: bool, label: String, extra := "") -> void:
	if ok: print("PASS %s %s" % [label, extra])
	else:
		failures += 1
		print("FAIL %s %s" % [label, extra])
func world_aabb(n: Node3D) -> AABB:
	var r := AABB(); var first := true
	n.force_update_transform()
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		r = a if first else r.merge(a); first = false
	return r
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var block := preload("res://scripts/CityBlock.gd").new()
	block.name = "CityBlock"
	world.add_child(block)
	var sleeper := Node3D.new()
	var sc := GDScript.new()
	sc.source_code = "extends Node3D\nvar slept := false\nvar sleep_pos := Vector3.ZERO\nvar sleep_bed := false\nfunc start_sleep(p, on_bed):\n slept = true\n sleep_pos = p\n sleep_bed = on_bed\n"
	sc.reload()
	sleeper.set_script(sc)
	var house: Node3D = block.load_building(0)
	check(house != null, "building 0 loads")
	var interior: Node3D = house.get_node("Interior")
	# Village reference sizes (measured placed): bed 4.13x1.60x1.73,
	# hutch 2.79 tall, fridge 1.90, stove 1.36, sink cab 1.51, toilet 1.42,
	# bath sink 1.79. Compare each placed piece's height and longest footprint.
	var expected := { # node name -> [min longest horizontal dim, min height]
		"bed": [3.7, 1.4], "dresser_hutch": [1.4, 2.6], "tall_dresser": [0.85, 2.6],
		"fridge": [1.6, 1.7], "stove": [0.85, 1.25], "gas_stove": [0.85, 1.25],
		"sink_cabinet": [0.95, 1.35], "toilet": [0.8, 1.3], "bath_sink": [0.8, 1.65],
		"sofa_old": [2.6, 1.2], "armchair": [0.95, 1.2], "chair_a": [0.6, 0.5],
		"bookshelf": [0.85, 2.4], "cabinet": [0.85, 1.35], "tv_stand": [1.15, 1.6],
		"desk_table": [1.0, 1.0], "side_table": [0.65, 0.55],
	}
	var seen := {}
	for node in interior.get_children():
		if not (node is Node3D) or node.name == "BedInteractable": continue
		var base: String = (node as Node3D).name
		if base in ["sofa"]: continue
		var key := base
		if base in ["sofa_old", "sofa_wrecked"]: key = "sofa_old"
		if not expected.has(key): continue
		if seen.has(key): continue
		seen[key] = true
		var a := world_aabb(node)
		var horiz := maxf(a.size.x, a.size.z)
		var e: Array = expected[key]
		check(horiz >= e[0] and a.size.y >= e[1], "size %s" % base, "%.2fx%.2fx%.2f" % [a.size.x, a.size.y, a.size.z])
		# Nothing may clip through the exterior walls (interior ~+-5.8 m).
		var local := (house.global_transform.affine_inverse() * a)
		check(absf(local.get_center().x) + local.size.x * 0.5 <= 5.85 and absf(local.get_center().z) + local.size.z * 0.5 <= 5.85, "inside walls %s" % base)
	for want in ["bed", "fridge", "stove", "toilet", "bath_sink", "sink_cabinet", "dresser_hutch"]:
		check(seen.has(want), "piece present %s" % want)
	# The bed: village size, sleepable area enclosing its frame collider.
	var bed: Node3D = interior.get_node_or_null("bed")
	check(bed != null, "bed node")
	if bed != null:
		var ba := world_aabb(bed)
		check(ba.size.x > 3.8 and ba.size.y > 1.4 and ba.size.z > 1.4, "bed matches village", "%.2fx%.2fx%.2f" % [ba.size.x, ba.size.y, ba.size.z])
		var area := bed.get_node_or_null("BedInteractable")
		check(area is Area3D, "BedInteractable area")
		var frame := bed.get_node_or_null("BedFrame")
		check(frame is StaticBody3D, "bed frame collider")
		if area is Area3D:
			check(area.has_method("interact") and area.has_method("get_interaction_text"), "bed interactable methods")
			check(area.is_in_group("interactable"), "bed in interactable group")
			var bp: Vector3 = area.get("bed_position")
			var bl := house.to_local(bp)
			check(absf(bp.x) > 0.01 and bl.y > 4.5 and bl.y < 5.3, "bed_position above mattress", str(bp))
			sleeper.slept = false
			area.interact(sleeper)
			check(sleeper.slept and sleeper.sleep_bed and sleeper.sleep_pos.distance_to(bp) < 0.01, "interact starts bed sleep")
			# Aim ray: from above the mattress the area must win over the frame.
			await physics_frame
			var q := PhysicsRayQueryParameters3D.create(bp + Vector3(0, 1.2, 0), bp + Vector3(0, -0.5, 0))
			q.collide_with_areas = true
			var hit := world.get_world_3d().direct_space_state.intersect_ray(q)
			check(not hit.is_empty() and hit.get("collider") == area, "aim ray hits sleep area first")
	# A rotated house must report a sane world bed_position too.
	var house2: Node3D = block.load_building(2) # city_03, yaw PI
	check(house2 != null, "rotated building loads")
	if house2 != null:
		var bed2: Node3D = house2.get_node_or_null("Interior/bed")
		check(bed2 != null and bed2.get_node_or_null("BedInteractable") is Area3D, "rotated bed sleepable")
		if bed2 != null:
			var bp2: Vector3 = bed2.get_node("BedInteractable").get("bed_position")
			check(bp2.distance_to(house2.global_position) < 8.0 and bp2.y > 4.0 and bp2.y < 6.0, "rotated bed_position world", str(bp2))
	print("CITY_FURNITURE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
