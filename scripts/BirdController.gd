extends Node3D
class_name BirdController

const WORLD_LIMIT := 480.0
const FLIGHT_HEIGHT_MIN := 40.0
const FLIGHT_HEIGHT_MAX := 70.0
const AI_LOD_CULL := 500.0

# Boids parameters
const BOIDS_SEPARATION_RADIUS := 6.0
const BOIDS_ALIGNMENT_RADIUS := 15.0
const BOIDS_COHESION_RADIUS := 20.0
const BOIDS_SEPARATION_WEIGHT := 3.0
const BOIDS_ALIGNMENT_WEIGHT := 1.5
const BOIDS_COHESION_WEIGHT := 1.0
const BOIDS_PATH_WEIGHT := 1.2
const BOIDS_NEIGHBOR_UPDATE_INTERVAL := 0.3
const BOIDS_MAX_SPEED := 8.0
const BOIDS_MIN_SPEED := 3.0
const BOIDS_MAX_FORCE := 4.0

var animal_type := "bird"
var patrol_points: Array = []
var target_index := 0
var move_speed := 5.0
var _wing_phase := 0.0
var _wing_speed := 12.0
var _left_wing: MeshInstance3D = null
var _right_wing: MeshInstance3D = null
var _body_mesh: MeshInstance3D = null
var _bird_root: Node3D = null
var _player: Node3D = null
var _resolve_player_timer := 0.0
var _ai_lod_timer := 0.0
var _target_height := 25.0
var _idle_timer := 0.0
var _idle_cooldown := 8.0
var _is_perched := false
var _perch_timer := 0.0
var _perch_object: Node3D = null
var _is_dead := false
var _gutted := false
var _landed := false
var is_puppet := false
var health := 25.0
var current_anim_keyword := "fly"
var _flee_timer := 0.0
var _flee_origin := Vector3.ZERO
var _corpse_age := 0.0
var _use_external_model := false

# Drinking states
enum DrinkState { FLYING, DESCENDING, DRINKING, ASCENDING, FISHING }
var _drink_state := DrinkState.FLYING
var _drink_cooldown := 60.0
var _drink_target := Vector3.ZERO
var _drink_timer := 0.0
var _saved_height := 50.0
var _drink_approach_pos := Vector3.ZERO
var _drink_approach_dir := Vector3.ZERO
var _is_fishing := false
var _has_fish := false
var _fish_mesh: MeshInstance3D = null
var _fish_eat_timer := 0.0
var _animation_player: AnimationPlayer = null
var _scene_cache: Dictionary = {}

# Boids state
var flock_id := 0
var _flock_neighbors: Array = []
var _neighbor_update_timer := 0.0
var _velocity := Vector3.ZERO

const BIRD_MODEL_PATH := "res://assets/external/bird/simple_bird.glb"
const BIRD_TARGET_HEIGHT := 0.6

func _ready() -> void:
	add_to_group("birds")
	add_to_group("wildlife")
	_build_bird()
	_build_hitbox()

func _build_bird() -> void:
	if _try_load_external_model():
		_use_external_model = true
		_set_visibility_range(_bird_root, 600.0)
		_apply_visible_material_override(_bird_root)
		return
	_build_primitive_bird()
	_set_visibility_range(_bird_root, 600.0)

func _try_load_external_model() -> bool:
	var node := _load_external_node3d(BIRD_MODEL_PATH)
	if node == null:
		return false
	node.name = "ExternalBirdModel"
	node.rotation_degrees = Vector3.ZERO
	add_child(node)
	_normalize_model_height(node, BIRD_TARGET_HEIGHT)
	node.visible = true
	_bird_root = node
	_animation_player = _find_animation_player(node)
	if _animation_player != null:
		_play_fly_animation()
	return true

func _build_primitive_bird() -> void:
	_bird_root = Node3D.new()
	_bird_root.name = "BirdModel"
	_bird_root.scale = Vector3(0.4, 0.4, 0.4)
	add_child(_bird_root)

	var body_color := Color(0.2, 0.15, 0.1)
	var wing_color := Color(0.15, 0.12, 0.08)

	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 1.0
	_body_mesh = MeshInstance3D.new()
	_body_mesh.name = "BirdBody"
	_body_mesh.mesh = body_mesh
	_body_mesh.material_override = _make_material(body_color)
	_body_mesh.scale = Vector3(1.0, 1.0, 1.6)
	_bird_root.add_child(_body_mesh)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	var head := MeshInstance3D.new()
	head.name = "BirdHead"
	head.mesh = head_mesh
	head.material_override = _make_material(body_color)
	head.position = Vector3(0, 0.12, 0.6)
	_bird_root.add_child(head)

	var beak_mesh := CylinderMesh.new()
	beak_mesh.top_radius = 0.0
	beak_mesh.bottom_radius = 0.08
	beak_mesh.height = 0.2
	var beak := MeshInstance3D.new()
	beak.name = "BirdBeak"
	beak.mesh = beak_mesh
	beak.material_override = _make_material(Color(0.9, 0.7, 0.2))
	beak.position = Vector3(0, 0.1, 0.85)
	beak.rotation_degrees.x = 90.0
	_bird_root.add_child(beak)

	var tail_mesh := CylinderMesh.new()
	tail_mesh.top_radius = 0.0
	tail_mesh.bottom_radius = 0.18
	tail_mesh.height = 0.5
	var tail := MeshInstance3D.new()
	tail.name = "BirdTail"
	tail.mesh = tail_mesh
	tail.material_override = _make_material(wing_color)
	tail.position = Vector3(0, 0.06, -0.6)
	tail.rotation_degrees.x = -90.0
	_bird_root.add_child(tail)

	var wing_mesh := BoxMesh.new()
	wing_mesh.size = Vector3(1.4, 0.05, 0.5)

	_left_wing = MeshInstance3D.new()
	_left_wing.name = "BirdWingLeft"
	_left_wing.mesh = wing_mesh
	_left_wing.material_override = _make_material(wing_color)
	var left_pivot := Node3D.new()
	left_pivot.name = "LeftWingPivot"
	left_pivot.position = Vector3(-0.2, 0.1, 0.0)
	_bird_root.add_child(left_pivot)
	_left_wing.position = Vector3(-0.6, 0.0, 0.0)
	left_pivot.add_child(_left_wing)

	_right_wing = MeshInstance3D.new()
	_right_wing.name = "BirdWingRight"
	_right_wing.mesh = wing_mesh
	_right_wing.material_override = _make_material(wing_color)
	var right_pivot := Node3D.new()
	right_pivot.name = "RightWingPivot"
	right_pivot.position = Vector3(0.2, 0.1, 0.0)
	_bird_root.add_child(right_pivot)
	_right_wing.position = Vector3(0.6, 0.0, 0.0)
	right_pivot.add_child(_right_wing)

func _make_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mat.metallic = 0.0
	return mat

func _apply_visible_material_override(root: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.15, 0.1)
	mat.roughness = 0.7
	mat.metallic = 0.0
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	for mi in meshes:
		(mi as MeshInstance3D).material_override = mat

func _set_visibility_range(node: Node, distance: float) -> void:
	return

func setup(points: Array) -> void:
	patrol_points = points.duplicate()
	if patrol_points.is_empty():
		patrol_points = [Vector3.ZERO, Vector3(20, 25, 20)]
	_target_height = randf_range(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX)
	global_position = patrol_points[0]
	global_position.y = _get_ground_y(global_position.x, global_position.z) + _target_height
	target_index = 1 if patrol_points.size() > 1 else 0
	move_speed = randf_range(4.0, 7.0)
	_wing_speed = randf_range(10.0, 16.0)
	_idle_cooldown = randf_range(6.0, 16.0)
	_velocity = Vector3.FORWARD * move_speed

func set_flock_id(id: int) -> void:
	flock_id = id

func _process(delta: float) -> void:
	if is_puppet:
		if not _is_dead:
			_wing_phase += delta * _wing_speed
			_animate_wings()
		return
	if _is_dead:
		_update_falling(delta)
		return
	if _flee_timer > 0.0:
		_flee_timer -= delta
		var away := (global_position - _flee_origin).normalized()
		away.y = 0.4
		_velocity = _velocity.move_toward(away.normalized() * 12.0, delta * 8.0)
		global_position += _velocity * delta
		global_position.y = maxf(global_position.y, _get_ground_y(global_position.x, global_position.z) + 1.0)
		rotation.y = lerp_angle(rotation.y, atan2(_velocity.x, _velocity.z), minf(delta * 4.0, 1.0))
		_wing_phase += delta * _wing_speed * 1.3
		_animate_wings()
		return
	if patrol_points.size() < 2:
		return
	if _player == null or not is_instance_valid(_player):
		_resolve_player_timer += delta
		if _resolve_player_timer >= 1.0:
			_resolve_player_timer = 0.0
			_resolve_player()
	if _player != null and is_instance_valid(_player):
		var dist := global_position.distance_to(_player.global_position)
		if dist < 12.0:
			flee_from_gunshot(_player.global_position, 12.0)
		if dist > AI_LOD_CULL:
			_wing_phase += delta * _wing_speed
			_animate_wings()
			return
	if _is_perched:
		_perch_timer -= delta
		_wing_phase += delta * 3.0
		_animate_wings()
		if _perch_timer <= 0.0:
			_is_perched = false
			_target_height = randf_range(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX)
		return

	# Drinking state machine
	if _drink_state != DrinkState.FLYING:
		_process_drink_state(delta)
		_wing_phase += delta * _wing_speed
		_animate_wings()
		_update_fish_eat(delta)
		return
	_update_fish_eat(delta)

	_drink_cooldown -= delta
	# Only attempt to descend to lake occasionally; most of the time birds fly freely
	if _drink_cooldown <= 0.0 and randf() < 0.3 and _try_start_drinking():
		return
	_drink_cooldown = maxf(_drink_cooldown, 0.0)

	# Update flock neighbors periodically
	_neighbor_update_timer += delta
	if _neighbor_update_timer >= BOIDS_NEIGHBOR_UPDATE_INTERVAL:
		_neighbor_update_timer = 0.0
		_update_flock_neighbors()

	# Compute boids steering forces
	var separation := _compute_separation()
	var alignment := _compute_alignment()
	var cohesion := _compute_cohesion()
	var path_force := _compute_path_force()

	# World boundary force
	var boundary_force := _compute_boundary_force()

	# Combine forces
	var acceleration := Vector3.ZERO
	acceleration += separation * BOIDS_SEPARATION_WEIGHT
	acceleration += alignment * BOIDS_ALIGNMENT_WEIGHT
	acceleration += cohesion * BOIDS_COHESION_WEIGHT
	acceleration += path_force * BOIDS_PATH_WEIGHT
	acceleration += boundary_force

	# Apply acceleration to velocity
	_velocity += acceleration * delta

	# Clamp speed
	var speed := _velocity.length()
	if speed > BOIDS_MAX_SPEED:
		_velocity = _velocity.normalized() * BOIDS_MAX_SPEED
	elif speed < BOIDS_MIN_SPEED:
		if speed > 0.001:
			_velocity = _velocity.normalized() * BOIDS_MIN_SPEED
		else:
			_velocity = Vector3.FORWARD * BOIDS_MIN_SPEED

	# Move
	global_position += _velocity * delta

	# Smooth turn toward velocity direction
	var target_yaw := atan2(_velocity.x, _velocity.z)
	var turn := wrapf(target_yaw - rotation.y, -PI, PI)
	rotation.z = lerp_angle(rotation.z, clampf(-turn * 0.5, -0.5, 0.5), minf(delta * 3.0, 1.0))
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 4.0, 1.0))

	# Maintain altitude
	var current_ground_y := _get_ground_y(global_position.x, global_position.z)
	var desired_y := current_ground_y + _target_height
	global_position.y = lerp(global_position.y, desired_y, delta * 0.8)

	# Check waypoint reached
	var target: Vector3 = patrol_points[target_index]
	var flat_dist := sqrt(pow(target.x - global_position.x, 2) + pow(target.z - global_position.z, 2))
	if flat_dist < 5.0:
		target_index = (target_index + 1) % patrol_points.size()
		_target_height = randf_range(FLIGHT_HEIGHT_MIN, FLIGHT_HEIGHT_MAX)

	# Animate wings
	_wing_phase += delta * _wing_speed
	_animate_wings()

func _try_start_drinking() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var segments: Array = []
	if scene.get("river_segments_data") != null:
		segments = scene.river_segments_data
	elif scene.has_method("get_river_segments_for_minimap"):
		segments = scene.get_river_segments_for_minimap()
	if segments.is_empty():
		return false
	# Find nearest lake segment within reasonable distance (lake only, not rivers)
	var best_pos := Vector3.ZERO
	var best_dist := 600.0
	for seg in segments:
		var size: Vector2 = seg["size"]
		if size.x < 60.0:
			continue
		var center: Vector3 = seg["center"]
		var flat_d := sqrt(pow(center.x - global_position.x, 2) + pow(center.z - global_position.z, 2))
		if flat_d < best_dist:
			best_dist = flat_d
			var yaw: float = deg_to_rad(float(seg["yaw"]))
			var along := Vector3(cos(yaw), 0.0, -sin(yaw))
			var across := Vector3(sin(yaw), 0.0, cos(yaw))
			# Descender cerca del centro del lago (pequeno jitter para que no todos caigan
			# en el mismo punto exacto), en vez de un borde
			var center_jitter := along * randf_range(-size.x * 0.08, size.x * 0.08) + across * randf_range(-size.y * 0.08, size.y * 0.08)
			best_pos = center + center_jitter
			best_pos.y = 0.5
	if best_dist >= 600.0:
		_drink_cooldown = randf_range(60.0, 120.0)
		return false
	_drink_target = best_pos
	_is_fishing = randf() < 0.4
	if _is_fishing:
		_drink_state = DrinkState.FISHING
	else:
		_drink_state = DrinkState.DESCENDING
	_saved_height = _target_height
	_drink_approach_pos = global_position
	var approach_flat := Vector3(_drink_target.x - global_position.x, 0.0, _drink_target.z - global_position.z)
	_drink_approach_dir = approach_flat.normalized() if approach_flat.length() > 0.01 else Vector3.FORWARD
	return true

func _process_drink_state(delta: float) -> void:
	match _drink_state:
		DrinkState.DESCENDING:
			var flat_dir := Vector3(_drink_target.x - global_position.x, 0.0, _drink_target.z - global_position.z)
			var flat_dist := flat_dir.length()
			if flat_dist > 1.5:
				var horizontal_vel := flat_dir.normalized() * move_speed * 0.5
				global_position.x += horizontal_vel.x * delta
				global_position.z += horizontal_vel.z * delta
				var target_yaw := atan2(horizontal_vel.x, horizontal_vel.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, delta * 3.0)
			# Descender gradualmente, casi tocando el agua con las patas
			var water_y := 0.5
			var target_y := water_y + 0.04
			if flat_dist < 8.0:
				target_y = water_y + 0.02
			if flat_dist < 3.0:
				target_y = water_y + 0.01
			if flat_dist > 8.0:
				target_y = maxf(target_y + minf(flat_dist * 0.25, 30.0), _get_ground_y(global_position.x, global_position.z) + 2.0)
			global_position.y = move_toward(global_position.y, target_y, delta * 3.0)
			# Alas mas lentas al aproximarse
			_wing_speed = lerp(_wing_speed, 5.0, delta * 2.0)
			if flat_dist < 2.0 and abs(global_position.y - target_y) < 0.2:
				_drink_state = DrinkState.DRINKING
				_drink_timer = randf_range(4.0, 9.0)
				_wing_speed = 2.0
		DrinkState.DRINKING:
			_drink_timer -= delta
			# Quedarse a ras de agua con ligero balanceo
			var bob := sin(_drink_timer * 2.0) * 0.04
			global_position.y = lerp(global_position.y, 0.51 + bob, delta * 3.0)
			if _drink_timer <= 0.0:
				_drink_state = DrinkState.ASCENDING
				_drink_timer = 0.0
				_wing_speed = lerp(_wing_speed, 8.0, 0.3)
		DrinkState.FISHING:
			var flat_dir_f := Vector3(_drink_target.x - global_position.x, 0.0, _drink_target.z - global_position.z)
			var flat_dist_f := flat_dir_f.length()
			if flat_dist_f > 1.5:
				var horizontal_vel := flat_dir_f.normalized() * move_speed * 0.6
				global_position.x += horizontal_vel.x * delta
				global_position.z += horizontal_vel.z * delta
				var target_yaw := atan2(horizontal_vel.x, horizontal_vel.z)
				rotation.y = lerp_angle(rotation.y, target_yaw, delta * 3.0)
			# Descender rapido para cazar, casi tocando el agua
			var water_y_f := 0.5
			var target_y_f := water_y_f + 0.03
			if flat_dist_f < 5.0:
				target_y_f = water_y_f + 0.015
			if flat_dist_f < 2.0:
				target_y_f = water_y_f + 0.005
			if flat_dist_f > 5.0:
				target_y_f = maxf(target_y_f + minf(flat_dist_f * 0.3, 30.0), _get_ground_y(global_position.x, global_position.z) + 2.0)
			global_position.y = move_toward(global_position.y, target_y_f, delta * 5.0)
			_wing_speed = lerp(_wing_speed, 3.0, delta * 3.0)
			# Al tocar el agua, atrapar el pez
			if flat_dist_f < 2.0 and abs(global_position.y - target_y_f) < 0.15:
				_has_fish = true
				_create_fish_in_talons()
				_drink_state = DrinkState.ASCENDING
				_drink_timer = 0.0
				_wing_speed = lerp(_wing_speed, 10.0, 0.5)
		DrinkState.ASCENDING:
			_drink_timer += delta
			var ground_y := _get_ground_y(global_position.x, global_position.z)
			var target_y_a := ground_y + _saved_height
			# Ascender muy lentamente en vertical, mas rapido en horizontal
			# para seguir la misma trayectoria diagonal de llegada
			var height_diff := target_y_a - global_position.y
			var climb_rate := clamp(height_diff * 0.15, 1.5, 6.0)
			global_position.y += climb_rate * delta
			# Moverse en la misma direccion de aproximacion (no dar la vuelta)
			var ascend_dir := _drink_approach_dir
			global_position.x += ascend_dir.x * move_speed * 0.7 * delta
			global_position.z += ascend_dir.z * move_speed * 0.7 * delta
			var target_yaw_a := atan2(ascend_dir.x, ascend_dir.z)
			rotation.y = lerp_angle(rotation.y, target_yaw_a, delta * 2.0)
			_wing_speed = lerp(_wing_speed, 10.0, delta * 1.0)
			# Solo volver a volar cuando este bastante alto
			if global_position.y >= target_y_a - 2.0:
				_drink_state = DrinkState.FLYING
				_target_height = _saved_height
				_drink_cooldown = randf_range(90.0, 180.0)
				_wing_speed = randf_range(10.0, 16.0)
				# Re-inicializar velocidad en direccion de vuelo
				var fwd := Vector3.FORWARD.rotated(Vector3.UP, rotation.y)
				_velocity = fwd * move_speed
				# Si lleva un pez, programar su desaparicion (se lo come)
				if _has_fish:
					_fish_eat_timer = randf_range(15.0, 30.0)

func _create_fish_in_talons() -> void:
	_remove_fish_from_talons()
	_has_fish = true
	_fish_eat_timer = 30.0
	var fish_mesh := SphereMesh.new()
	fish_mesh.radius = 0.06
	fish_mesh.height = 0.22
	fish_mesh.radial_segments = 8
	fish_mesh.rings = 4
	_fish_mesh = MeshInstance3D.new()
	_fish_mesh.name = "CaughtFish"
	_fish_mesh.mesh = fish_mesh
	_fish_mesh.material_override = _make_material(Color(0.5, 0.45, 0.3))
	_fish_mesh.scale = Vector3(0.7, 0.5, 1.8)
	# Colgar debajo del pajaro, entre las patas
	_fish_mesh.position = Vector3(0.0, -0.15, 0.0)
	_fish_mesh.rotation_degrees.x = 90.0
	if _bird_root != null:
		_bird_root.add_child(_fish_mesh)

func _remove_fish_from_talons() -> void:
	if _fish_mesh != null and is_instance_valid(_fish_mesh):
		_fish_mesh.queue_free()
	_fish_mesh = null
	_has_fish = false

func _update_fish_eat(delta: float) -> void:
	if not _has_fish:
		return
	_fish_eat_timer -= delta
	if _fish_eat_timer <= 0.0:
		_remove_fish_from_talons()

func _update_flock_neighbors() -> void:
	_flock_neighbors.clear()
	for node in get_tree().get_nodes_in_group("birds"):
		if node == self:
			continue
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not (node is BirdController):
			continue
		var other := node as BirdController
		if other._is_dead or other.flock_id != flock_id:
			continue
		if not is_instance_valid(other):
			continue
		_flock_neighbors.append(other)

func _compute_separation() -> Vector3:
	var steer := Vector3.ZERO
	var count := 0
	for other in _flock_neighbors:
		if not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		var o := other as BirdController
		if o == null or o._is_dead:
			continue
		var diff := global_position - o.global_position
		var d := diff.length()
		if d > 0.001 and d < BOIDS_SEPARATION_RADIUS:
			steer += diff.normalized() / d
			count += 1
	if count > 0:
		steer /= count
		if steer.length() > 0.001:
			steer = steer.normalized() * BOIDS_MAX_SPEED - _velocity
			if steer.length() > BOIDS_MAX_FORCE:
				steer = steer.normalized() * BOIDS_MAX_FORCE
	return steer

func _compute_alignment() -> Vector3:
	var sum := Vector3.ZERO
	var count := 0
	for other in _flock_neighbors:
		if not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		var o := other as BirdController
		if o == null or o._is_dead:
			continue
		var d := global_position.distance_to(o.global_position)
		if d < BOIDS_ALIGNMENT_RADIUS:
			sum += o._velocity
			count += 1
	if count > 0:
		sum /= count
		if sum.length() > 0.001:
			sum = sum.normalized() * BOIDS_MAX_SPEED - _velocity
			if sum.length() > BOIDS_MAX_FORCE:
				sum = sum.normalized() * BOIDS_MAX_FORCE
	return sum

func _compute_cohesion() -> Vector3:
	var center := Vector3.ZERO
	var count := 0
	for other in _flock_neighbors:
		if not is_instance_valid(other) or other.is_queued_for_deletion():
			continue
		var o := other as BirdController
		if o == null or o._is_dead:
			continue
		var d := global_position.distance_to(o.global_position)
		if d < BOIDS_COHESION_RADIUS:
			center += o.global_position
			count += 1
	if count > 0:
		center /= count
		var desired := center - global_position
		if desired.length() > 0.001:
			desired = desired.normalized() * BOIDS_MAX_SPEED - _velocity
			if desired.length() > BOIDS_MAX_FORCE:
				desired = desired.normalized() * BOIDS_MAX_FORCE
			return desired
	return Vector3.ZERO

func _compute_path_force() -> Vector3:
	var target: Vector3 = patrol_points[target_index]
	var ground_y := _get_ground_y(target.x, target.z)
	var target_pos := Vector3(target.x, ground_y + _target_height, target.z)
	var desired := target_pos - global_position
	if desired.length() > 0.001:
		desired = desired.normalized() * BOIDS_MAX_SPEED
		var steer := desired - _velocity
		if steer.length() > BOIDS_MAX_FORCE:
			steer = steer.normalized() * BOIDS_MAX_FORCE
		return steer
	return Vector3.ZERO

func _compute_boundary_force() -> Vector3:
	var margin := 40.0
	var steer := Vector3.ZERO
	if global_position.x > WORLD_LIMIT - margin:
		steer.x = -(global_position.x - (WORLD_LIMIT - margin)) / margin * BOIDS_MAX_FORCE
	elif global_position.x < -WORLD_LIMIT + margin:
		steer.x = (-WORLD_LIMIT + margin - global_position.x) / margin * BOIDS_MAX_FORCE
	if global_position.z > WORLD_LIMIT - margin:
		steer.z = -(global_position.z - (WORLD_LIMIT - margin)) / margin * BOIDS_MAX_FORCE
	elif global_position.z < -WORLD_LIMIT + margin:
		steer.z = (-WORLD_LIMIT + margin - global_position.z) / margin * BOIDS_MAX_FORCE
	return steer

func _animate_wings() -> void:
	if _use_external_model and _animation_player != null:
		return
	var flap := sin(_wing_phase)
	if _left_wing != null and _left_wing.get_parent() != null:
		_left_wing.get_parent().rotation_degrees.x = flap * 35.0
	if _right_wing != null and _right_wing.get_parent() != null:
		_right_wing.get_parent().rotation_degrees.x = flap * 35.0

func _try_perch() -> bool:
	if randf() > 0.15:
		return false
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var best_pos := Vector3.ZERO
	var best_found := false
	var search_radius := 15.0
	for node in get_tree().get_nodes_in_group("world_action_visual"):
		if not (node is Node3D):
			continue
		var n3d := node as Node3D
		var flat_dist := sqrt(pow(n3d.global_position.x - global_position.x, 2) + pow(n3d.global_position.z - global_position.z, 2))
		if flat_dist < search_radius:
			var perch_y := n3d.global_position.y + 3.0
			best_pos = Vector3(n3d.global_position.x, perch_y, n3d.global_position.z)
			best_found = true
			break
	if not best_found:
		return false
	global_position = best_pos
	_is_perched = true
	_perch_timer = randf_range(5.0, 15.0)
	rotation.y = randf_range(0, TAU)
	return true

func _resolve_player() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if scene.has_node("PlayerController"):
		_player = scene.get_node("PlayerController")
	elif scene.get("player") != null and is_instance_valid(scene.get("player")):
		_player = scene.get("player")

func _get_ground_y(x: float, z: float) -> float:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_get_exact_ground_y"):
		return float(scene.call("_get_exact_ground_y", x, z))
	elif scene != null and scene.has_method("_get_ground_height"):
		return float(scene.call("_get_ground_height", Vector3(x, 0, z)))
	return 0.0

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

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _play_fly_animation() -> void:
	if _animation_player == null:
		return
	var chosen := ""
	var any_fallback := ""
	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		var lower := animation_name.to_lower()
		if lower.find("fly") >= 0 or lower.find("flap") >= 0 or lower.find("soar") >= 0 or lower.find("glide") >= 0:
			chosen = animation_name
			break
		if any_fallback.is_empty():
			any_fallback = animation_name
	if chosen.is_empty():
		chosen = any_fallback
	if not chosen.is_empty():
		_animation_player.play(chosen)

func _build_hitbox() -> void:
	var body := Area3D.new()
	body.name = "BodyHitbox"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.18
	capsule.height = 0.6
	shape.shape = capsule
	shape.rotation.x = PI / 2.0
	shape.position.y = 0.2
	body.add_child(shape)
	add_child(body)

func flee_from_gunshot(origin: Vector3, radius: float) -> void:
	if _is_dead or is_puppet or global_position.distance_to(origin) > radius:
		return
	_flee_origin = origin
	_flee_timer = 6.0
	_is_perched = false
	_drink_state = DrinkState.FLYING
	_drink_cooldown = 60.0

func take_damage(amount: float, from_knife: bool = false) -> void:
	if _is_dead or amount <= 0.0:
		return
	if is_puppet:
		var net_node := get_node_or_null("/root/NetworkManager")
		if net_node != null:
			net_node.damage_animal.rpc_id(1, name, amount, from_knife)
		return
	health = maxf(0.0, health - amount)
	if health > 0.0:
		return
	_is_dead = true
	current_anim_keyword = "fall"
	_is_perched = false
	_remove_fish_from_talons()
	if _animation_player != null:
		_animation_player.stop()

func _update_falling(delta: float) -> void:
	_corpse_age += delta
	if _corpse_age > 300.0:
		queue_free()
		return
	if _landed:
		return
	var ground := _get_ground_y(global_position.x, global_position.z) + 0.12
	var displacement := _velocity * delta + Vector3.DOWN * 4.905 * delta * delta
	_velocity += Vector3.DOWN * 9.81 * delta
	_velocity *= exp(-0.15 * delta)
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + displacement)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	global_position += displacement
	rotation.z += delta * 2.0
	if not hit.is_empty() or global_position.y <= ground:
		if not hit.is_empty():
			global_position = hit.position + hit.normal * 0.12
		else:
			global_position.y = ground
		_land_corpse()

func _land_corpse() -> void:
	_landed = true
	_velocity = Vector3.ZERO
	rotation.z = PI / 2.0
	current_anim_keyword = "dead"
	add_to_group("interactable")

func _has_butchering_tool(player: Node) -> bool:
	if not is_instance_valid(player):
		return false
	var inv = player.get("inventory")
	if inv == null:
		return false
	for item in inv.items:
		if item != null and (item.item_name == "Cuchillo" or item.item_name == "Hacha") and not item.is_broken():
			return true
	return false

func get_interaction_text(player = null) -> String:
	if not _landed or _gutted:
		return ""
	return "[E] Desplumar y obtener carne del pajaro" if _has_butchering_tool(player) else "Necesitas cuchillo o hacha para aprovechar el pajaro"

func interact(player: Node) -> void:
	if not _is_dead or not _landed or _gutted or not _has_butchering_tool(player):
		return
	if player.global_position.distance_to(global_position) > 5.0:
		return
	var net_node := get_node_or_null("/root/NetworkManager")
	if net_node != null and net_node.is_connected:
		if is_puppet:
			net_node.gut_animal.rpc_id(1, name, false)
		else:
			get_tree().current_scene._net_gut_animal(str(name), net_node.get_my_id(), false)
		return
	_gutted = true
	var scene := get_tree().current_scene
	if scene.has_method("_spawn_ground_pickup"):
		# Generic raw meat already supports skewering, cooking and spoilage.
		scene._spawn_ground_pickup("Carne cruda", "food", global_position, 0.3, 1, 15.0, "bird_meat_%d" % get_instance_id(), "wolf_meat_raw")
	queue_free()

func puppet_apply(pos: Vector3, yaw: float, dead: bool, gutted: bool, landed: bool) -> void:
	global_position = pos
	rotation.y = yaw
	_is_dead = dead
	_gutted = gutted
	if dead and _animation_player != null:
		_animation_player.stop()
	if landed and not _landed:
		_land_corpse()
