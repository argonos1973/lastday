extends Node3D
class_name WildlifeController

var patrol_points: Array = []
var target_index := 0
var move_speed := 1.2
var animal_type := "deer"
var _walk_time := 0.0
var _legs: Array[Node3D] = []
var _visual_root: Node3D
var _player: Node3D
var _animation_player: AnimationPlayer
var _stuck_time := 0.0
var _last_position := Vector3.ZERO
var _current_path: Array = []
var _path_index := 0
var _path_recalc_timer := 0.0

static var _scene_cache := {}
static var _shared_sphere: SphereMesh = null
static var _shared_cylinder: CylinderMesh = null

func setup(kind: String, points: Array) -> void:
	animal_type = kind
	add_to_group("wildlife")
	patrol_points = points.duplicate()
	if patrol_points.is_empty():
		patrol_points = [Vector3.ZERO, Vector3(10, 0, 10), Vector3(-10, 0, -10)]
	global_position = patrol_points[0]
	_last_position = global_position
	target_index = 1 if patrol_points.size() > 1 else 0
	move_speed = 1.65 if animal_type == "deer" else 2.35
	_build_animal()

# Replace any patrol point that falls inside the river (or other blocked area)
# with the nearest allowed position, so animals never patrol into the water.
func _sanitize_patrol_points() -> void:
	for i in range(patrol_points.size()):
		var p: Vector3 = patrol_points[i]
		if not _is_position_allowed(p):
			var safe = _nearest_allowed_point(p)
			if safe != null:
				patrol_points[i] = safe

func _nearest_allowed_point(origin: Vector3):
	for radius in [2.0, 4.0, 6.0, 9.0, 13.0, 18.0]:
		for i in range(16):
			var angle := TAU * float(i) / 16.0
			var candidate := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -68.0, 68.0)
			candidate.z = clamp(candidate.z, -68.0, 68.0)
			if _is_position_allowed(candidate):
				return candidate
	return null

# If the animal is currently standing in a blocked area (e.g. stuck in the river),
# force-walk it toward the nearest shore, ignoring the per-step allow check so it
# can cross the water out of the trap.
func _escape_if_trapped(delta: float) -> bool:
	if _is_position_allowed(global_position):
		return false
	var safe = _nearest_allowed_point(global_position)
	if safe == null:
		return false
	var dir: Vector3 = (safe - global_position)
	dir.y = 0.0
	if dir.length() < 0.01:
		return false
	dir = dir.normalized()
	var step := move_speed * 2.2 * delta
	var next_pos := global_position + dir * step
	next_pos.x = clamp(next_pos.x, -72.0, 72.0)
	next_pos.z = clamp(next_pos.z, -72.0, 72.0)
	global_position = next_pos
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 6.0)
	_walk_time += delta * move_speed * 5.0
	_animate_legs(delta)
	return true

func _process(delta: float) -> void:
	if patrol_points.size() < 2:
		return
	_resolve_player()
	_update_stuck_timer(delta)
	if _try_flee_from_player(delta):
		return
	var target: Vector3 = patrol_points[target_index]
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.55:
		target_index = (target_index + 1) % patrol_points.size()
		_current_path.clear()
		_path_index = 0
		return
	_path_recalc_timer -= delta
	if _current_path.is_empty() or _path_index >= _current_path.size() or _path_recalc_timer <= 0.0:
		_current_path = _request_path(global_position, target)
		_path_index = 0
		_path_recalc_timer = 3.0
	var move_target: Vector3 = target
	if _current_path.size() > 0 and _path_index < _current_path.size():
		var waypoint: Vector3 = _current_path[_path_index]
		var to_waypoint: Vector3 = waypoint - global_position
		to_waypoint.y = 0.0
		if to_waypoint.length() < 1.0:
			_path_index += 1
			if _path_index < _current_path.size():
				move_target = _current_path[_path_index]
		else:
			move_target = waypoint
	_move_towards(move_target, move_speed, delta, 5.0)
	_walk_time += delta * move_speed * 5.0
	_animate_legs(delta)

func _update_stuck_timer(delta: float) -> void:
	if global_position.distance_to(_last_position) < 0.015:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
		_last_position = global_position
	if _stuck_time > 1.5:
		_retarget_from_blocked_route()
		_stuck_time = 0.0
		_current_path.clear()
		_path_index = 0

func _retarget_from_blocked_route() -> void:
	_current_path.clear()
	_path_index = 0
	for i in range(32):
		var angle := randf_range(0.0, TAU)
		var distance := randf_range(8.0, 20.0)
		var candidate := global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
		candidate.x = clamp(candidate.x, -68.0, 68.0)
		candidate.z = clamp(candidate.z, -68.0, 68.0)
		if not _is_position_allowed(candidate):
			continue
		if patrol_points.size() < 3:
			patrol_points.append(candidate)
			target_index = patrol_points.size() - 1
		else:
			patrol_points[target_index] = candidate
		return
	target_index = (target_index + 1) % patrol_points.size()

func _try_flee_from_player(delta: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length() > _flee_distance():
		return false
	if away.length() < 0.01:
		away = Vector3.RIGHT
	var flee_goal := global_position + away.normalized() * 20.0
	flee_goal.x = clamp(flee_goal.x, -68.0, 68.0)
	flee_goal.z = clamp(flee_goal.z, -68.0, 68.0)
	_path_recalc_timer -= delta
	if _current_path.is_empty() or _path_index >= _current_path.size() or _path_recalc_timer <= 0.0:
		_current_path = _request_path(global_position, flee_goal)
		_path_index = 0
		_path_recalc_timer = 1.5
	var flee_speed := move_speed * (2.65 if animal_type == "fox" else 2.05)
	var move_target: Vector3 = flee_goal
	if _current_path.size() > 0 and _path_index < _current_path.size():
		var waypoint: Vector3 = _current_path[_path_index]
		var to_waypoint: Vector3 = waypoint - global_position
		to_waypoint.y = 0.0
		if to_waypoint.length() < 1.0:
			_path_index += 1
			if _path_index < _current_path.size():
				move_target = _current_path[_path_index]
		else:
			move_target = waypoint
	_move_towards(move_target, flee_speed, delta, 8.0)
	_walk_time += delta * flee_speed * 4.8
	_animate_legs(delta)
	return true

func _move_towards(target_pos: Vector3, speed: float, delta: float, turn_speed: float) -> void:
	var dir: Vector3 = target_pos - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	var step := speed * delta
	var next_pos: Vector3 = global_position + dir * step
	next_pos.x = clamp(next_pos.x, -72.0, 72.0)
	next_pos.z = clamp(next_pos.z, -72.0, 72.0)
	global_position = next_pos
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * turn_speed)

func _move_with_avoidance(dir: Vector3, speed: float, delta: float, turn_speed: float) -> bool:
	dir.y = 0.0
	if dir.length() < 0.01:
		return false
	dir = dir.normalized()
	var avoidance := _get_avoidance_vector()
	if avoidance.length() > 0.01:
		var steer := dir + avoidance * 1.5
		steer.y = 0.0
		if steer.length() > 0.01:
			dir = steer.normalized()
	var candidates := [
		dir,
		dir.rotated(Vector3.UP, deg_to_rad(20.0)),
		dir.rotated(Vector3.UP, deg_to_rad(-20.0)),
		dir.rotated(Vector3.UP, deg_to_rad(45.0)),
		dir.rotated(Vector3.UP, deg_to_rad(-45.0)),
		dir.rotated(Vector3.UP, deg_to_rad(70.0)),
		dir.rotated(Vector3.UP, deg_to_rad(-70.0)),
		dir.rotated(Vector3.UP, deg_to_rad(100.0)),
		dir.rotated(Vector3.UP, deg_to_rad(-100.0)),
		dir.rotated(Vector3.UP, deg_to_rad(140.0)),
		dir.rotated(Vector3.UP, deg_to_rad(-140.0)),
		dir.rotated(Vector3.UP, deg_to_rad(180.0))
	]
	for candidate in candidates:
		candidate = candidate.normalized()
		var step_dist := speed * delta
		var next_pos: Vector3 = global_position + candidate * step_dist
		next_pos.x = clamp(next_pos.x, -72.0, 72.0)
		next_pos.z = clamp(next_pos.z, -72.0, 72.0)
		if not _is_position_allowed(next_pos):
			continue
		var lookahead: Vector3 = global_position + candidate * step_dist * 2.5
		lookahead.x = clamp(lookahead.x, -72.0, 72.0)
		lookahead.z = clamp(lookahead.z, -72.0, 72.0)
		if not _is_position_allowed(lookahead):
			continue
		global_position = next_pos
		rotation.y = lerp_angle(rotation.y, atan2(candidate.x, candidate.z), delta * turn_speed)
		return true
	return false


func _is_path_clear(_next_pos: Vector3, _candidate: Vector3) -> bool:
	return true

func _is_position_allowed(pos: Vector3) -> bool:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("is_wildlife_allowed_at"):
		return bool(scene.call("is_wildlife_allowed_at", pos))
	return true

func _get_avoidance_vector() -> Vector3:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_wildlife_avoidance_vector_at"):
		var result = scene.call("get_wildlife_avoidance_vector_at", global_position)
		if result is Vector3:
			return result
	return Vector3.ZERO

func _find_safe_patrol_points(source_points: Array) -> Array:
	var safe_points: Array = []
	var centers := source_points.duplicate()
	if centers.is_empty():
		centers = [Vector3.ZERO]
	for center in centers:
		var center_pos: Vector3 = center
		for i in range(24):
			var angle := TAU * float(i) / 24.0
			var radius := 6.0 + float(i % 4) * 4.0
			var candidate := center_pos + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -68.0, 68.0)
			candidate.z = clamp(candidate.z, -68.0, 68.0)
			if _is_position_allowed(candidate):
				safe_points.append(candidate)
				break
		if safe_points.size() >= 3:
			break
	if safe_points.size() < 2:
		safe_points = [Vector3(-18.0, 0.0, 12.0), Vector3(18.0, 0.0, 16.0), Vector3(34.0, 0.0, 4.0)]
	return safe_points

func _flee_distance() -> float:
	return 16.0 if animal_type == "fox" else 13.0

func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	_player = scene.get_node_or_null("Player") as Node3D

func _request_path(start: Vector3, goal: Vector3) -> Array:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("find_path_wildlife"):
		return scene.call("find_path_wildlife", start, goal) as Array
	return [goal]

func _animate_legs(delta: float) -> void:
	if _visual_root != null:
		_visual_root.position.y = sin(_walk_time * 2.0) * 0.035
		_visual_root.rotation_degrees.z = sin(_walk_time) * 2.0
	for i in range(_legs.size()):
		var leg := _legs[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		leg.rotation_degrees.x = lerp(leg.rotation_degrees.x, sin(_walk_time + side * PI) * 18.0, delta * 8.0)

func _build_animal() -> void:
	if _try_build_external_animal():
		return
	var scale_value := 1.0 if animal_type == "deer" else 0.48
	var body_color := Color(0.30, 0.20, 0.11) if animal_type == "deer" else Color(0.32, 0.28, 0.22)
	var body := _mesh_sphere("WildlifeBody", Vector3(0, 0.55 * scale_value, 0), Vector3(0.55, 0.32, 0.95) * scale_value, body_color)
	add_child(body)
	var chest := _mesh_sphere("WildlifeChest", Vector3(0, 0.66 * scale_value, 0.42 * scale_value), Vector3(0.42, 0.34, 0.40) * scale_value, body_color.lightened(0.05))
	add_child(chest)
	var head := _mesh_sphere("WildlifeHead", Vector3(0, 0.92 * scale_value, 0.82 * scale_value), Vector3(0.24, 0.22, 0.30) * scale_value, body_color.lightened(0.08))
	add_child(head)
	if animal_type == "deer":
		_add_antlers(scale_value)
	else:
		_add_ears(scale_value, body_color)
	for x in [-0.24, 0.24]:
		for z in [-0.36, 0.42]:
			var leg := _mesh_cylinder("WildlifeLeg", Vector3(x * scale_value, 0.20 * scale_value, z * scale_value), 0.045 * scale_value, 0.45 * scale_value, body_color.darkened(0.14))
			add_child(leg)
			_legs.append(leg)

func _try_build_external_animal() -> bool:
	var candidates := _animal_asset_candidates()
	for path in candidates:
		var node := _load_external_node3d(path)
		if node == null:
			continue
		node.name = "ExternalWildlifeModel"
		node.rotation_degrees = Vector3.ZERO
		add_child(node)
		# Normalize by bounding box so models authored in different units end up
		# at a believable real-world height (deer ~1.5 m, fox ~0.55 m).
		var target_height := 1.5 if animal_type == "deer" else 0.55
		_normalize_model_height(node, target_height)
		_visual_root = node
		_animation_player = _find_animation_player(node)
		_play_external_walk_animation()
		return true
	return false

func _normalize_model_height(node: Node3D, target_height: float) -> void:
	var aabb := _baked_aabb_local(node)
	if aabb.size.y <= 0.001:
		return
	var factor: float = target_height / aabb.size.y
	var bottom_rel: float = aabb.position.y
	node.scale = Vector3.ONE * factor
	node.position.y -= bottom_rel * factor

func _baked_aabb_local(root: Node) -> AABB:
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	var combined := AABB()
	var has_any := false
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var raw := mi.get_aabb()
		if not has_any:
			combined = raw
			has_any = true
		else:
			combined = combined.merge(raw)
	return combined

func _collect_mesh_instances(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		_collect_mesh_instances(child, result)

func _animal_asset_candidates() -> Array:
	if animal_type == "deer":
		return [
			"res://assets/external/quaternius_animals/glTF/Deer.gltf",
			"res://assets/external/quaternius_animals/glTF/Stag.gltf"
		]
	if animal_type == "fox":
		return [
			"res://assets/external/quaternius_animals/glTF/Fox.gltf",
			"res://assets/external/realistic/root_glb/fox_-_realistic_3d_model_demo_free.glb"
		]
	return [
		"res://assets/external/quaternius_animals/glTF/Fox.gltf"
	]

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_external_walk_animation() -> void:
	if _animation_player == null:
		return
	var chosen := ""
	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		var lower := animation_name.to_lower()
		if lower.find("walk") >= 0 or lower.find("run") >= 0:
			chosen = animation_name
			break
		if chosen.is_empty():
			chosen = animation_name
	if not chosen.is_empty():
		_animation_player.play(chosen)

func _load_external_node3d(path: String) -> Node3D:
	if _scene_cache.has(path):
		var cached = _scene_cache[path]
		if cached is PackedScene:
			return (cached as PackedScene).instantiate() as Node3D
		elif cached is Node3D:
			return (cached as Node3D).duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION) as Node3D
	var instance: Node = null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
			instance = (loaded as PackedScene).instantiate()
			_scene_cache[path] = loaded
	if instance == null and (path.get_extension().to_lower() == "gltf" or path.get_extension().to_lower() == "glb"):
		instance = _load_gltf_node3d(path)
		if instance != null:
			_scene_cache[path] = instance
	if instance is Node3D:
		return instance as Node3D
	if instance != null:
		instance.queue_free()
	return null

func _load_gltf_node3d(path: String) -> Node3D:
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(disk_path, state)
	if error != OK:
		return null
	var generated_scene := document.generate_scene(state)
	if generated_scene is Node3D:
		return generated_scene as Node3D
	if generated_scene != null:
		generated_scene.queue_free()
	return null

func _add_antlers(scale_value: float) -> void:
	for side in [-1.0, 1.0]:
		var antler := _mesh_cylinder("DeerAntler", Vector3(side * 0.10 * scale_value, 1.12 * scale_value, 0.86 * scale_value), 0.012 * scale_value, 0.38 * scale_value, Color(0.55, 0.48, 0.34))
		antler.rotation_degrees = Vector3(28, 0, side * 22)
		add_child(antler)

func _add_ears(scale_value: float, body_color: Color) -> void:
	for side in [-1.0, 1.0]:
		var ear := _mesh_sphere("RabbitEar", Vector3(side * 0.13 * scale_value, 1.15 * scale_value, 0.82 * scale_value), Vector3(0.07, 0.22, 0.05) * scale_value, body_color.lightened(0.06))
		ear.rotation_degrees.z = side * 14.0
		add_child(ear)

func _mesh_sphere(node_name: String, pos: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.scale = scale_value
	if _shared_sphere == null:
		_shared_sphere = SphereMesh.new()
		_shared_sphere.radius = 1.0
		_shared_sphere.height = 2.0
		_shared_sphere.radial_segments = 12
		_shared_sphere.rings = 6
	mesh_instance.mesh = _shared_sphere
	mesh_instance.material_override = _make_material(color)
	return mesh_instance

func _mesh_cylinder(node_name: String, pos: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	if _shared_cylinder == null:
		_shared_cylinder = CylinderMesh.new()
		_shared_cylinder.top_radius = 1.0
		_shared_cylinder.bottom_radius = 1.0
		_shared_cylinder.height = 1.0
		_shared_cylinder.radial_segments = 8
	mesh_instance.mesh = _shared_cylinder
	mesh_instance.scale = Vector3(radius, height, radius)
	mesh_instance.material_override = _make_material(color)
	return mesh_instance

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	return material
