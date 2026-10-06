extends SceneTree
# Rifle sling: route wraps the outer garment, ends sit on the rifle swivels,
# rebuilds when the torso garment changes, stays cheap per update and is
# fully removed with the rifle.
#   Godot --headless --path . --script tools/debug/RifleStrapRegression.gd

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _setup_third_person_animation(_character: Node3D) -> void: pass

var errors := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _min_rest_clearance(sys) -> float:
	var lowest := INF
	for p in sys._rest_body_points:
		var frame: Array = sys._surface_frame(p)
		if not frame.is_empty():
			lowest = minf(lowest, (p - frame[0]).dot(frame[1]))
	return lowest

func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.equip_clothing("Camiseta")
	actor._build_rifle_on_back()
	var model: Node3D = actor.third_person_model
	var started := Time.get_ticks_usec()
	actor._update_rifle_strap(1.0 / 30.0)
	var build_ms := (Time.get_ticks_usec() - started) / 1000.0
	var sys = actor._rifle_strap_system
	check(sys != null and sys._route.size() == sys.BODY_POINTS, "Body route is solved")
	var strap := model.find_child("ProceduralStrapMesh", false, false) as MeshInstance3D
	check(strap != null and strap.mesh != null, "Band mesh exists")
	var expected_rings: int = sys.BODY_POINTS + sys.CONNECTOR_POINTS * 2
	check(strap != null and strap.mesh.surface_get_array_len(0) == expected_rings * 8, "Band has a full rectangular cross-section per ring")
	check(strap != null and strap.material_override != null and strap.material_override.albedo_texture != null, "Band uses the webbing texture")
	var hardware := model.find_child("RifleSlingHardware", false, false)
	check(hardware != null and hardware.get_child_count() == 3, "Swivels and tri-glide exist")
	var barrel := model.to_local(actor._strap_barrel_marker.global_position)
	var stock := model.to_local(actor._strap_stock_marker.global_position)
	check(sys._previous[0].distance_to(barrel) < 0.0001, "Band starts exactly at the barrel swivel")
	check(sys._previous[sys._previous.size() - 1].distance_to(stock) < 0.0001, "Band ends exactly at the stock swivel")
	var shirt_clear: float = _min_rest_clearance(sys)
	check(shirt_clear >= sys.CLEARANCE - 0.003, "Band rests on the shirt, not inside it (%.4f)" % shirt_clear)
	var longest := 0.0
	for i in sys._previous.size() - 1:
		longest = maxf(longest, sys._previous[i].distance_to(sys._previous[i + 1]))
	check(longest < 0.2, "No long straight chords cut through the body (%.3f)" % longest)
	# Per-update cost: skinning only, no surface work.
	var skel: Skeleton3D = actor._find_skeleton(model)
	var spine := skel.find_bone("mixamorig_Spine1")
	started = Time.get_ticks_usec()
	for i in 60:
		skel.set_bone_pose_rotation(spine, Quaternion(Vector3.RIGHT, sin(i * 0.2) * 0.3))
		skel.force_update_all_bone_transforms()
		actor._update_rifle_strap(1.0 / 30.0)
	var update_ms := (Time.get_ticks_usec() - started) / 1000.0 / 60.0
	check(update_ms < 3.0, "Per-update cost stays small (%.2f ms)" % update_ms)
	skel.set_bone_pose_rotation(spine, Quaternion.IDENTITY)
	skel.force_update_all_bone_transforms()
	actor._update_rifle_strap(1.0 / 30.0)
	# Bulkier garment on the same rifle: the route must be re-solved over it.
	# (Swap the visible torso meshes directly — equip_clothing would also
	# resync the back and drop this inventory-less test rifle.)
	var shirt_points := PackedVector3Array(sys._rest_body_points)
	var tops := model.find_child("Tops", true, false) as MeshInstance3D
	var jacket := model.find_child("soldier_torso", true, false) as MeshInstance3D
	tops.visible = false
	jacket.visible = true
	actor._update_rifle_strap(1.0 / 30.0)
	var moved := 0.0
	for i in shirt_points.size():
		moved = maxf(moved, shirt_points[i].distance_to(sys._rest_body_points[i]))
	check(moved > 0.03, "Route is re-solved over the jacket (%.3f)" % moved)
	var jacket_clear: float = _min_rest_clearance(sys)
	check(jacket_clear >= sys.CLEARANCE - 0.003, "Band rests on the jacket, not inside it (%.4f)" % jacket_clear)
	actor._clear_rifle_on_back()
	check(model.find_child("ProceduralStrapMesh", false, false) == null, "Band is removed with the rifle")
	check(model.find_child("RifleSlingHardware", false, false) == null, "Hardware is removed with the rifle")
	print("build=%.1fms update=%.2fms shirt_clear=%.4f jacket_clear=%.4f" % [build_ms, update_ms, shirt_clear, jacket_clear])
	actor.stats.free()
	actor.queue_free()
	await process_frame
	print("RIFLE_STRAP_ERRORS=", errors)
	quit(1 if errors else 0)
