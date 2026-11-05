extends SceneTree

class TestWorld extends "res://scripts/Main.gd":
	var samples: Dictionary = {}
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _save_world_change_silent() -> void: pass
	func _get_exact_ground_y(x: float, z: float, _fallback := 0.0) -> float:
		return x*.05 + z*.01
	func _get_ground_height(pos: Vector3) -> float:
		return pos.x*.05 + pos.z*.01
	func _can_place_ground_vegetation(pos: Vector3, margin := .8, short_grass := false) -> bool:
		# Artificial obstacle also exercises checking each offset, not its center.
		return absf(pos.x-180.0) > 1.0 and super._can_place_ground_vegetation(pos,margin,short_grass)
	func _queue_grass_instance(pos: Vector3, height: float, radius: float, color: Color) -> void:
		samples[pos] = [height,radius,color]

var errors := 0
func check(ok: bool, message: String) -> void:
	if not ok: errors += 1
	print("PASS " if ok else "FAIL ",message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world.river_segments_data = world._default_river_segments()
	world._road_segments = world._generate_road_segments()
	world._world_rng.seed = 713
	var state := world._world_rng.state
	var settings = preload("res://scripts/GraphicsSettings.gd")
	var previous_config = settings._cached_config
	var previous_saved = settings._cached_file_saved
	settings._cached_config = ConfigFile.new()
	settings._cached_file_saved = false
	var sets: Array = []
	for quality in range(3):
		settings._cached_config.set_value("graphics","detail",quality)
		world.samples.clear()
		for x in range(165,201,3):
			for z in range(150,190,3):
				world._queue_natural_ground_patch(Vector3(x,0,z),.3,.4,Color.GREEN)
		sets.append(world.samples.duplicate())
	check(sets[0].size() > 0 and sets[0].size() < sets[1].size() and sets[1].size() < sets[2].size(),"Quality scales density")
	for quality in range(2):
		var subset := true
		for pos in sets[quality]:
			subset = subset and sets[quality+1].has(pos) and sets[quality+1][pos] == sets[quality][pos]
		check(subset,"Lower quality preserves the same plants")
	check(world._world_rng.state == state,"Decoration preserves gameplay RNG")
	var valid := true
	for pos: Vector3 in sets[2]:
		valid = valid and world._can_place_ground_vegetation(pos,.8,true) and absf(pos.y-world._get_exact_ground_y(pos.x,pos.z)-.008)<.001
	check(valid,"Every plant clears obstacles and follows terrain")
	settings._cached_config.set_value("graphics","detail",1)
	world.samples.clear()
	await world._create_grass_carpet()
	var southern := 0
	valid = true
	for pos: Vector3 in world.samples:
		southern += int(pos.z > 500)
		valid = valid and world._can_place_ground_vegetation(pos,.8,true)
	check(southern > 0,"City southern extension receives ground cover")
	check(valid,"Full-map placement respects exclusions")
	print("GROUND_COVER count=",world.samples.size()," south=",southern," errors=",errors)
	settings._cached_config = previous_config
	settings._cached_file_saved = previous_saved
	world.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
