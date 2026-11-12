extends SceneTree

class World extends "res://scripts/Main.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass

class Exhaustive extends World:
	func _candidate_river_segs(_pos: Vector3, _margin: float) -> Array:
		return range(river_segments_data.size())

var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	if not ok:
		failures += 1
		push_error(label)

func run():
	var indexed := World.new()
	var exhaustive := Exhaustive.new()
	root.add_child(indexed)
	root.add_child(exhaustive)
	indexed.river_segments_data = indexed._default_river_segments()
	exhaustive.river_segments_data = indexed.river_segments_data
	indexed._road_segments = indexed._generate_road_segments()
	exhaustive._road_segments = indexed._road_segments
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	for i in range(40000):
		var p := Vector3(rng.randf_range(-500,500),0,rng.randf_range(-500,880))
		check(is_equal_approx(indexed.get_river_depth_at(p), exhaustive.get_river_depth_at(p)), "depth")
		check(is_equal_approx(indexed.get_river_surface_y_at(p), exhaustive.get_river_surface_y_at(p)), "surface")
		for margin in [0.0, 8.0, 12.0]:
			check(indexed._is_near_river(p,margin) == exhaustive._is_near_river(p,margin), "shore")
			check(indexed._is_inside_river_band(p,margin) == exhaustive._is_inside_river_band(p,margin), "band")
	var moved := indexed.river_segments_data.duplicate(true)
	for segment in moved:
		segment.center += Vector3(2000,0,2000)
	indexed.river_segments_data = moved
	exhaustive.river_segments_data = moved
	for segment in moved:
		check(indexed._is_near_river(segment.center,0) == exhaustive._is_near_river(segment.center,0), "same-size replacement invalidates cache")
	var water_script = load("res://scripts/RiverWater.gd")
	for lake in [false,true]:
		var water = water_script.new()
		water.mesh = PlaneMesh.new()
		var material := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = "shader_type spatial; void fragment(){ ALBEDO=vec3(sin(TIME)); }"
		material.shader = shader
		water.material_override = material
		water.set_is_lake(lake)
		root.add_child(water)
		check(water.is_processing() == lake, "only lake shader water needs CPU processing")
		water.free()
	var legacy = water_script.new()
	legacy.mesh = PlaneMesh.new()
	legacy.material_override = StandardMaterial3D.new()
	root.add_child(legacy)
	check(legacy.is_processing(), "legacy UV animation remains active")
	legacy.free()
	indexed.free()
	exhaustive.free()
	print("WATER_QUERY_REGRESSION failures=",failures," points=40000")
	quit(1 if failures else 0)
