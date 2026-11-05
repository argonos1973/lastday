extends SceneTree
const WorldTest = preload("res://tools/debug/NaturalGroundCoverRegression.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := WorldTest.TestWorld.new()
	root.add_child(world)
	world.river_segments_data = world._default_river_segments()
	world._road_segments = world._generate_road_segments()
	world._world_rng.seed = 173
	var state := world._world_rng.state
	var cover := preload("res://scripts/NearGroundCover.gd").new()
	world.add_child(cover)
	cover.setup(world)
	var errors := 0
	var max_usec := 0
	for step in range(500):
		var started := Time.get_ticks_usec()
		cover.update_focus(Vector3(190,3,170),1.0)
		max_usec = maxi(max_usec,Time.get_ticks_usec()-started)
		if cover.chunks.size() > 49: errors += 1
		if cover.pending.is_empty(): break
	var original: Dictionary = {}
	var plants := 0
	for key in cover.chunks:
		original[key] = cover.chunks[key].multimesh.buffer
		plants += cover.chunks[key].multimesh.instance_count
		if DisplayServer.get_name() != "headless":
			var node = cover.chunks[key]
			for i in range(node.multimesh.instance_count):
				var pos: Vector3 = node.position + node.multimesh.get_instance_transform(i).origin
				if not world._can_place_ground_vegetation(pos, .8, true) or world._road_verge_growth(pos)<=0: errors += 1
	for step in range(500):
		cover.update_focus(Vector3(-160,0,230),1.0)
		await process_frame
		if cover.chunks.size() > 49 or cover.get_child_count() > 49: errors += 1
		if cover.pending.is_empty(): break
	for step in range(500):
		cover.update_focus(Vector3(190,3,170),1.0)
		await process_frame
		if cover.pending.is_empty(): break
	for key in original:
		if not cover.chunks.has(key) or original[key] != cover.chunks[key].multimesh.buffer: errors += 1
	for step in range(500):
		cover.update_focus(Vector3(190,3,170),.6)
		await process_frame
		if cover.pending.is_empty(): break
	var low_plants := 0
	for node in cover.chunks.values(): low_plants += node.multimesh.instance_count
	if plants == 0 or low_plants >= plants or world._world_rng.state != state: errors += 1
	print("NEAR_GROUND_COVER errors=",errors," normal=",plants," low=",low_plants," chunks=",cover.chunks.size()," max_build_usec=",max_usec)
	world.queue_free()
	await process_frame
	quit(0 if errors==0 else 1)
