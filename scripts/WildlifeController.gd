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
var _debug_timer := 0.0
var _attack_timer := 0.0
var _attack_cooldown := 0.0
var _chase_target: Node3D = null
var _state := "patrol"
var _howl_timer := randf_range(15.0, 35.0)
var _growl_timer := randf_range(8.0, 18.0)
var _wolf_audio_player: AudioStreamPlayer3D = null
var _wolf_pain_player: AudioStreamPlayer3D = null
var health := 100.0
var max_health := 100.0
var _is_dead := false
var _hit_flash_timer := 0.0
var _gutted := false
var _corpse_body: StaticBody3D = null

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
	move_speed = 1.65 if animal_type == "deer" else (2.0 if animal_type == "wolf" else 2.35)
	_build_animal()
	call_deferred("_sanitize_patrol_points")

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
	# Don't escape from inside a house with a closed door - wolf should stay trapped
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_is_inside_closed_house"):
		if scene.call("_is_inside_closed_house", global_position):
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
	if _is_dead:
		return
	if patrol_points.size() < 2:
		return
	_resolve_player()
	if _escape_if_trapped(delta):
		return
	_update_stuck_timer(delta)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_hit_flash_timer = max(0.0, _hit_flash_timer - delta)
	if animal_type == "wolf":
		_update_wolf_sounds(delta)
	var target: Vector3
	var speed: float
	if animal_type == "wolf":
		var result := _wolf_ai(delta)
		target = result["target"]
		speed = result["speed"]
	else:
		var result := _prey_ai(delta)
		target = result["target"]
		speed = result["speed"]
	target.x = clamp(target.x, -55.0, 55.0)
	target.z = clamp(target.z, -55.0, 55.0)
	var to_target := target - global_position
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
		_path_recalc_timer = 1.5
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
	_move_towards(move_target, speed, delta, 8.0)
	_walk_time += delta * speed * 4.8
	_animate_legs(delta)
	_update_animation_speed(speed)

func _wolf_ai(delta: float) -> Dictionary:
	var target: Vector3
	var speed: float = move_speed
	_attack_timer -= delta
	# Priority 1: chase player if close enough
	if _player != null and is_instance_valid(_player):
		var dist_to_player := global_position.distance_to(_player.global_position)
		if dist_to_player < 20.0:
			_state = "chase_player"
			_chase_target = _player
			speed = move_speed * 2.8
			if dist_to_player < 2.0:
				if _attack_cooldown <= 0.0:
					_attack_cooldown = 5.0
					_attack_timer = randf_range(8.0, 15.0)
					_player.apply_damage(8.0)
					_play_wolf_sound("attack")
				_play_animation_by_name("run")
				# Stop at minimum distance — don't overlap the player
				var away_dir := (global_position - _player.global_position).normalized()
				away_dir.y = 0.0
				target = _player.global_position + away_dir * 2.5
				speed = 0.0
			else:
				_play_animation_by_name("run")
				target = _player.global_position
			return {"target": target, "speed": speed}
	# Priority 2: chase nearby deer
	var nearest_deer := _find_nearest_animal("deer")
	if nearest_deer != null and is_instance_valid(nearest_deer):
		var dist_to_deer := global_position.distance_to(nearest_deer.global_position)
		if dist_to_deer < 15.0:
			_state = "chase_deer"
			_chase_target = nearest_deer
			target = nearest_deer.global_position
			speed = move_speed * 2.5
			if dist_to_deer < 1.5:
				_play_animation_by_name("run")
			else:
				_play_animation_by_name("trot")
			return {"target": target, "speed": speed}
	# Default: patrol
	_state = "patrol"
	_chase_target = null
	target = patrol_points[target_index]
	speed = move_speed * 1.0
	_play_animation_by_name("walk")
	return {"target": target, "speed": speed}

func _prey_ai(delta: float) -> Dictionary:
	var target: Vector3
	var speed: float = move_speed
	var nearest_wolf := _find_nearest_animal("wolf")
	if nearest_wolf != null and is_instance_valid(nearest_wolf):
		var dist_to_wolf := global_position.distance_to(nearest_wolf.global_position)
		if dist_to_wolf < 20.0:
			var away := global_position - nearest_wolf.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.RIGHT
			target = global_position + away.normalized() * 20.0
			speed = move_speed * 2.5
			_play_animation_by_name("gallop")
			return {"target": target, "speed": speed}
	if _player != null and is_instance_valid(_player):
		var away := global_position - _player.global_position
		away.y = 0.0
		if away.length() < _flee_distance():
			if away.length() < 0.01:
				away = Vector3.RIGHT
			target = global_position + away.normalized() * 15.0
			speed = move_speed * (2.65 if animal_type == "fox" else 2.05)
			_play_animation_by_name("gallop")
			return {"target": target, "speed": speed}
	target = patrol_points[target_index]
	speed = move_speed * 1.0
	_play_animation_by_name("walk")
	return {"target": target, "speed": speed}

func take_damage(amount: float, _from_knife: bool) -> void:
	if _is_dead:
		return
	health = max(0.0, health - amount)
	_hit_flash_timer = 0.3
	_spawn_blood_splatter()
	_play_wolf_pain_sound()
	if health <= 0.0:
		_is_dead = true
		_hit_flash_timer = 2.0
		if _animation_player != null:
			_animation_player.stop()
		# Lie the corpse flat on the ground
		_lie_corpse_flat()

func _lie_corpse_flat() -> void:
	if not is_instance_valid(_visual_root):
		return
	if _animation_player != null:
		_animation_player.stop()
	# Reset skeleton to rest pose
	var skel := _find_skeleton(_visual_root)
	if skel != null:
		skel.reset_bone_poses()
	# Rotate the entire node -90 on Z to lie on its side (not on its back)
	var current_y_rad := rotation.y
	var basis := Basis.from_euler(Vector3(0.0, current_y_rad, deg_to_rad(-90.0)))
	global_transform = Transform3D(basis, Vector3(global_position.x, 0.1, global_position.z))
	_visual_root.position = Vector3.ZERO
	_visual_root.rotation_degrees = Vector3.ZERO
	# Add collision body so the player can interact with the corpse
	_corpse_body = StaticBody3D.new()
	_corpse_body.name = "CorpseBody"
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.4, 2.0)
	col_shape.shape = box
	_corpse_body.add_child(col_shape)
	add_child(_corpse_body)
	# Make interactable
	add_to_group("interactable")

func get_interaction_text(player = null) -> String:
	if not _is_dead:
		return ""
	if _gutted:
		return "[E] Lobo vacio"
	var has_knife := _player_has_knife(player)
	if has_knife:
		return "[E] Destripar lobo  |  [C] Coger lobo entero (necesitas mochila)"
	return "[E] Necesitas un cuchillo  |  [C] Coger lobo (necesitas mochila)"

func interact(player: Node) -> void:
	if not _is_dead:
		return
	if _gutted:
		if player != null and player.has_signal("notice"):
			player.notice.emit("El lobo ya esta vacio.")
		return
	var has_knife := _player_has_knife(player)
	if not has_knife:
		if player != null and player.has_signal("notice"):
			player.notice.emit("Necesitas un cuchillo para destripar.")
		return
	# Gut: spawn 5 meat pieces and 1 skin on the ground
	_gutted = true
	if player != null and player.has_method("play_action_animation"):
		player.play_action_animation("plant", 5.0)
	_spawn_gut_pickups()
	if player != null and player.has_signal("notice"):
		player.notice.emit("Destripar al lobo: +5 carne cruda, +1 piel.")
	# Remove the corpse after the 5-second animation finishes
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(_remove_corpse)
	add_child(timer)
	timer.start()

func collect(player: Node) -> void:
	if not _is_dead:
		return
	if _gutted:
		if player != null and player.has_signal("notice"):
			player.notice.emit("El lobo ya esta vacio, no hay nada que coger.")
		return
	# Need backpack to carry a whole wolf
	if not _player_has_backpack(player):
		if player != null and player.has_signal("notice"):
			player.notice.emit("Necesitas una mochila para cargar el lobo entero.")
		return
	var inventory = player.get("inventory") if player != null else null
	if inventory == null or not inventory.has_method("add_item"):
		return
	var ItemScript = load("res://scripts/Item.gd")
	var whole_wolf = ItemScript.create("Lobo muerto", "material", 8.0, 1, 0.0)
	var added: bool = inventory.add_item(whole_wolf)
	if added:
		if player != null and player.has_signal("notice"):
			player.notice.emit("Coges el lobo entero.")
		_remove_corpse()
	else:
		if player != null and player.has_signal("notice"):
			player.notice.emit("No puedes cargar con el lobo, demasiado peso.")

func _player_has_knife(player: Node) -> bool:
	if player == null:
		return false
	var inventory = player.get("inventory")
	if inventory == null or not ("items" in inventory):
		return false
	for item in inventory.items:
		if item != null and item.item_type == "weapon":
			return true
	return false

func _player_has_backpack(player: Node) -> bool:
	if player == null:
		return false
	var equipped_bp = player.get("equipped_backpack")
	if equipped_bp != null and not str(equipped_bp).is_empty():
		return true
	var inventory = player.get("inventory")
	if inventory == null or not ("items" in inventory):
		return false
	for item in inventory.items:
		if item != null and (item.item_type == "backpack" or item.item_name == "Mochila pequena"):
			return true
	return false

func _spawn_gut_pickups() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var meat_model := "res://cc0_-_raw_meat_4.glb"
	var base_pos := global_position
	# Spawn 5 meat pieces scattered around the corpse
	for i in range(5):
		var angle := TAU * float(i) / 5.0 + randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle) * randf_range(0.4, 0.9), 0.0, sin(angle) * randf_range(0.4, 0.9))
		var pos := base_pos + offset
		pos.y = 0.06
		var drop_id := "gut_meat_%d_%d" % [Time.get_ticks_msec(), i]
		var visual_name := "Pickup_" + drop_id
		if scene.has_method("_try_instance_external_scene"):
			scene.call("_try_instance_external_scene", [meat_model], visual_name, pos, Vector3.ONE * 1.0, Vector3(0, randf_range(0, 360), 0), true, 0.06)
		if scene.has_method("_create_world_action"):
			var action = scene.call("_create_world_action", drop_id, "wolf_meat_raw", "Carne cruda de lobo", pos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
			if action != null:
				action.set_meta("visual_name", visual_name)
				action.set_meta("item_name", "Carne cruda de lobo")
				action.set_meta("item_type", "food")
				action.set_meta("item_weight", 0.3)
				action.set_meta("item_quantity", 1)
				action.set_meta("item_use_value", 15.0)
	# Spawn 1 skin
	var skin_pos := base_pos + Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))
	skin_pos.y = 0.06
	var skin_id := "gut_skin_%d" % Time.get_ticks_msec()
	var skin_visual := "Pickup_" + skin_id
	if scene.has_method("_try_instance_external_scene"):
		scene.call("_try_instance_external_scene", ["res://assets/external/kenney_survival_kit/Models/GLB format/clothing-shirt.glb"], skin_visual, skin_pos, Vector3.ONE * 0.4, Vector3(0, randf_range(0, 360), 0), true, 0.06)
	if scene.has_method("_create_world_action"):
		var skin_action = scene.call("_create_world_action", skin_id, "pickup_item", "Piel de lobo", skin_pos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
		if skin_action != null:
			skin_action.set_meta("visual_name", skin_visual)
			skin_action.set_meta("item_name", "Piel de lobo")
			skin_action.set_meta("item_type", "clothing")
			skin_action.set_meta("item_weight", 0.8)
			skin_action.set_meta("item_quantity", 1)
			skin_action.set_meta("item_use_value", 0.3)

func _remove_corpse() -> void:
	remove_from_group("interactable")
	if is_instance_valid(_corpse_body):
		_corpse_body.queue_free()
	_corpse_body = null
	queue_free()

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _spawn_blood_splatter() -> void:
	var particles := GPUParticles3D.new()
	particles.name = "WolfBloodSplatter"
	particles.amount = 40
	particles.lifetime = 0.8
	particles.explosiveness = 1.0
	particles.randomness = 1.0
	particles.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.color = Color(0.6, 0.05, 0.05, 1.0)
	mat.scale_min = 0.08
	mat.scale_max = 0.2
	particles.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.06
	sphere.height = 0.12
	particles.draw_pass_1 = sphere
	get_tree().current_scene.add_child(particles)
	particles.global_position = global_position + Vector3(0, 0.8, 0)
	particles.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): particles.queue_free())

func _play_wolf_pain_sound() -> void:
	if _wolf_pain_player == null:
		_wolf_pain_player = AudioStreamPlayer3D.new()
		_wolf_pain_player.name = "WolfPainSound"
		_wolf_pain_player.unit_size = 3.0
		_wolf_pain_player.max_distance = 40.0
		add_child(_wolf_pain_player)
	var path := "res://assets/external/audio/downloaded/wolf_growl.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			stream = AudioStreamWAV.load_from_file(disk_path)
	if stream == null:
		return
	_wolf_pain_player.stop()
	_wolf_pain_player.stream = stream
	_wolf_pain_player.volume_db = 2.0
	_wolf_pain_player.pitch_scale = randf_range(0.85, 1.15)
	_wolf_pain_player.play()

func _find_nearest_animal(kind: String) -> Node3D:
	var nearest: Node3D = null
	var nearest_dist := 9999.0
	for node in get_tree().get_nodes_in_group("wildlife"):
		if node == self:
			continue
		if not (node is Node3D):
			continue
		var other := node as Node3D
		if other.get("animal_type") == null:
			continue
		if str(other.get("animal_type")) != kind:
			continue
		var d := global_position.distance_to(other.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = other
	return nearest

func _play_animation_by_name(keyword: String) -> void:
	if _animation_player == null:
		return
	var lower_keyword := keyword.to_lower()
	var current := _animation_player.current_animation
	if not current.is_empty() and current.to_lower().find(lower_keyword) >= 0:
		return
	var best := ""
	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		var lower := animation_name.to_lower()
		if lower.find(lower_keyword) >= 0:
			best = animation_name
			break
	if best.is_empty():
		return
	if current != best:
		_animation_player.play(best, 0.2)

func _update_animation_speed(speed: float) -> void:
	if _animation_player == null:
		return
	var ratio := speed / move_speed
	_animation_player.speed_scale = clamp(ratio, 0.5, 2.5)

func _update_wolf_sounds(delta: float) -> void:
	_howl_timer -= delta
	_growl_timer -= delta
	if _howl_timer <= 0.0:
		_play_wolf_sound("howl")
		_howl_timer = randf_range(20.0, 45.0)
	if _growl_timer <= 0.0:
		if _state == "chase_player" or _state == "chase_deer":
			_play_wolf_sound("growl")
			_growl_timer = randf_range(3.0, 8.0)
		else:
			_growl_timer = randf_range(10.0, 20.0)

func _play_wolf_sound(sound_type: String) -> void:
	if _wolf_audio_player == null:
		_wolf_audio_player = AudioStreamPlayer3D.new()
		_wolf_audio_player.name = "WolfSound"
		_wolf_audio_player.unit_size = 8.0
		_wolf_audio_player.max_distance = 60.0
		add_child(_wolf_audio_player)
	if _wolf_audio_player.playing:
		return
	var path := ""
	match sound_type:
		"howl":
			path = "res://assets/external/audio/downloaded/wolf_howl.wav"
		"growl":
			path = "res://assets/external/audio/downloaded/wolf_growl.wav"
		"attack":
			path = "res://assets/external/audio/downloaded/wolf_growl.wav"
		_:
			return
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			stream = AudioStreamWAV.load_from_file(disk_path)
	if stream == null:
		return
	_wolf_audio_player.stream = stream
	_wolf_audio_player.volume_db = -8.0 if sound_type == "attack" else -15.0
	_wolf_audio_player.pitch_scale = randf_range(0.85, 1.15)
	_wolf_audio_player.play()

func _update_stuck_timer(delta: float) -> void:
	if global_position.distance_to(_last_position) < 0.015:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
		_last_position = global_position
	if _stuck_time > 0.5:
		_retarget_from_blocked_route()
		_stuck_time = 0.0
		_current_path.clear()
		_path_index = 0

func _retarget_from_blocked_route() -> void:
	_current_path.clear()
	_path_index = 0
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
	# Separation: push away from nearby animals of same type to avoid stacking
	var sep := _get_separation_vector()
	if sep.length() > 0.01:
		dir = (dir + sep * 0.8).normalized()
	var step := speed * delta
	var next_pos: Vector3 = global_position + dir * step
	next_pos.x = clamp(next_pos.x, -72.0, 72.0)
	next_pos.z = clamp(next_pos.z, -72.0, 72.0)
	if not _is_position_allowed(next_pos):
		if not _move_with_avoidance(dir, speed, delta, turn_speed):
			return
		return
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
	if scene != null and scene.has_method("_is_near_wildlife_blocker"):
		if bool(scene.call("_is_near_wildlife_blocker", pos, 1.0)):
			return false
	return true

func _get_separation_vector() -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("wildlife"):
		if node == self:
			continue
		if not (node is Node3D):
			continue
		var other := node as Node3D
		if other.get("animal_type") == null:
			continue
		if str(other.get("animal_type")) != animal_type:
			continue
		var diff := global_position - other.global_position
		diff.y = 0.0
		var d := diff.length()
		if d > 0.001 and d < 3.0:
			push += diff.normalized() * (3.0 - d) / 3.0
	if push.length() > 0.01:
		return push.normalized()
	return Vector3.ZERO

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
	if animal_type == "wolf":
		return 0.0
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
		var target_height := 1.5 if animal_type == "deer" else (1.2 if animal_type == "wolf" else 0.55)
		_normalize_model_height(node, target_height)
		node.visible = true
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
	if animal_type == "wolf":
		return [
			"res://assets/external/wolf/WolfAnimated.glb"
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
	var walk_fallback := ""
	var any_fallback := ""
	for animation_name in _animation_player.get_animation_list():
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		var lower := animation_name.to_lower()
		if lower.find("walk") >= 0 and lower.find("_f") >= 0:
			chosen = animation_name
			break
		if lower.find("walk") >= 0 or lower.find("trot") >= 0 or lower.find("run") >= 0 or lower.find("gallop") >= 0:
			if walk_fallback.is_empty():
				walk_fallback = animation_name
		if any_fallback.is_empty():
			any_fallback = animation_name
	if chosen.is_empty():
		chosen = walk_fallback if not walk_fallback.is_empty() else any_fallback
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
