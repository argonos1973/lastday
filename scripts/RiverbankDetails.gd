extends RefCounted
## Blender-authored gravel/grass modules. Local +Z points away from water.
const DIRECTORY := "res://assets/models/props/shore/"
static var _meshes: Array = []
static var _meshes_loaded := false

static func _load_meshes() -> void:
	if _meshes_loaded:
		return
	_meshes_loaded = true
	_meshes.resize(3)
	for variant in range(3):
		var scene: PackedScene = load(DIRECTORY + "riverbank_reference_%d.glb" % variant)
		if scene == null:
			continue
		var source := scene.instantiate()
		var parts := source.find_children("*", "MeshInstance3D", true, false)
		if not parts.is_empty():
			_meshes[variant] = (parts[0] as MeshInstance3D).mesh
		source.free()

static func placements(world: Node3D, center: Vector3, size: Vector2, yaw: float) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([center, size, yaw])
	var along := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
	var across := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var batches: Array = [[], [], []]
	var lake := size.x >= 60.0
	var rx := size.x * .43
	var rz := size.y * .43
	var perimeter := PI * (3.0 * (rx + rz) - sqrt((3.0 * rx + rz) * (rx + 3.0 * rz)))
	var count := ceili(perimeter / 5.7) if lake else maxi(1, ceili(size.x / 5.8))
	for side in ([1.0] if lake else [-1.0, 1.0]):
		for i in range(count):
			var pos: Vector3
			var outward: Vector3
			if lake:
				var theta := TAU * float(i) / float(count)
				outward = (along * (cos(theta) / rx) + across * (sin(theta) / rz)).normalized()
				pos = center + along * (cos(theta) * rx) + across * (sin(theta) * rz)
			else:
				outward = across * float(side)
				pos = center + along * (float(i + .5) * size.x / count - size.x * .5) + outward * (size.y * .5 + .12)
			# Real banks alternate cobble bars with open grass/mud reaches.
			if rng.randf() < .28:
				continue
			# At river joints the neighbouring channel may cover this bank.
			# Leave that part open rather than putting grass and rocks in midwater.
			if float(world.call("get_river_depth_at", pos + outward * .7)) > .02:
				continue
			if not bool(world.call("_can_place_ground_vegetation", pos + outward, -1.0)):
				continue
			pos += along * rng.randf_range(-.5, .5) + outward * rng.randf_range(-.15, .25)
			var yaw_jitter := rng.randf_range(-.1, .1)
			var rot := Basis(Vector3.UP, yaw_jitter)
			outward = (rot * outward).normalized()
			pos.y = float(world.call("_get_ground_height", pos)) + .008
			var tangent := Vector3.UP.cross(outward)
			var length_scale := clampf(size.x / count / 6.0, .65, 1.05) if not lake else 1.0
			var basis := Basis(tangent * length_scale * rng.randf_range(.92, 1.08), Vector3.UP, outward * rng.randf_range(.85, 1.10))
			batches[i % 3].append(Transform3D(basis, pos))
	return batches

static func create(world: Node3D, center: Vector3, size: Vector2, yaw: float) -> Node3D:
	_load_meshes()
	var root := Node3D.new()
	root.name = "ReferenceRiverbanks"
	world.add_child(root)
	var batches := placements(world, center, size, yaw)
	for variant in range(3):
		if batches[variant].is_empty() or _meshes[variant] == null:
			continue
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = _meshes[variant]
		multi.instance_count = batches[variant].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, batches[variant][i])
		var node := MultiMeshInstance3D.new()
		node.name = "BankVariant%d" % variant
		node.multimesh = multi
		node.visibility_range_end = 110.0
		node.visibility_range_end_margin = 15.0
		root.add_child(node)
	return root
