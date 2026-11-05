extends SceneTree
const TestWorld = preload("res://tools/debug/RoadVergeRegression.gd").TestWorld
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world._road_segments = world._generate_road_segments()
	var rng := RandomNumberGenerator.new()
	rng.seed = 613
	var errors := 0
	# Every exhaustive hit must survive broad-phase filtering, including large margins.
	for i in range(12000):
		var pos := Vector3(rng.randf_range(-500,500),0,rng.randf_range(-500,900))
		var margin: float = [-.22,0.0,1.0,6.5,8.0,12.0][i % 6]
		var candidates: Array = world._candidate_road_segs(pos,margin)
		for si in range(world._road_segments.size()):
			var seg: Dictionary = world._road_segments[si]
			var yaw := deg_to_rad(float(seg.yaw))
			var offset: Vector3 = pos-seg.center
			if absf(offset.dot(Vector3(cos(yaw),0,-sin(yaw)))) <= seg.size.x*.5+margin and absf(offset.dot(Vector3(sin(yaw),0,cos(yaw)))) <= seg.size.y*.5+margin:
				if not candidates.has(si): errors += 1
	# Same count and endpoints: replacing only an intermediate segment must invalidate.
	var replacement: Array = world._road_segments.duplicate(true)
	replacement[1] = {"center":Vector3(420,0,-420),"size":Vector2(80,20),"yaw":45.0}
	world._road_segments = replacement
	if not world._candidate_road_segs(Vector3(420,0,-420),0).has(1): errors += 1
	world._road_segments = []
	if not world._candidate_road_segs(Vector3.ZERO,0).is_empty(): errors += 1
	print("ROAD_INDEX errors=",errors)
	world.queue_free()
	await process_frame
	quit(0 if errors == 0 else 1)
