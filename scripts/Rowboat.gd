extends StaticBody3D

const MODEL := preload("res://assets/models/props/rowboat_animated.glb")
const CYCLE := 2.0
const MAX_SPEED := 3.2
const HULL_MARGIN := 3.0
const BOARD_REACH := 4.6
const WATER_Y := 0.24
const OAR_SPLASH_PATH := "res://objetocaeagua.mp3"
const WAKE_LOOP_PATH := "res://andarporagua.mp3"

var lake_center := Vector3.ZERO
var lake_size := Vector2(150, 90)
var lake_yaw := 0.0
var occupant := 0
var rowing_time := 0.0
var rowing := false
var speed := 0.0
var exit_position := Vector3.ZERO
var return_position := Vector3.ZERO
var world: Node
var visual: Node3D
var animation_player: AnimationPlayer
var passenger: Node3D
var _axis := Vector2.ZERO
var _input_age := 0.0
var _send_timer := 0.0
var _exit_timer := 0.0
var _can_exit := false
var _network_position := Vector3.ZERO
var _network_yaw := 0.0
var _sequence := 0
var _last_sequence := -1
var _request_times: Dictionary = {}
var _wake: GPUParticles3D
var _oar_splash_l: GPUParticles3D
var _oar_splash_r: GPUParticles3D
var _oar_audio: AudioStreamPlayer3D
var _oar_audio_remaining := 0.0
var _wake_audio: AudioStreamPlayer3D
var _fx_prev_pos := Vector3.ZERO
var _fx_speed := 0.0
var _fx_velocity := Vector3.ZERO
var _bow_foam: Array[GPUParticles3D] = []
var _bow_spray: Array[GPUParticles3D] = []
var _oar_foam: Array[GPUParticles3D] = []
var _oar_ripples: Array[GPUParticles3D] = []
var _oars: Array[Node3D] = []
var _blade_points := [Vector3(-1.283951, -0.863600, -1.250282), Vector3(1.264295, -0.852445, -1.235754)]
var _previous_blades: Array[Vector3] = []
var _blade_velocities := [Vector3.ZERO, Vector3.ZERO]
var _oar_pulling := [false, false]
var _foam_texture: Texture2D
var _ripple_texture: Texture2D

func _ready() -> void:
	world = get_parent()
	add_to_group("interactable")
	add_to_group("prop_collision")
	collision_layer = 1
	collision_mask = 0
	process_priority = 100
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.95, 0.8, 5.3)
	col.shape = shape
	col.position = Vector3(0, 0.49, 0.15)
	add_child(col)
	if not _dedicated():
		visual = MODEL.instantiate()
		add_child(visual)
		var players := visual.find_children("*", "AnimationPlayer", true, false)
		if not players.is_empty():
			animation_player = players[0]
			animation_player.play("Animation")
			animation_player.pause()
		_create_water_fx()
	_fx_prev_pos = global_position
	_network_position = position
	_network_yaw = rotation.y
	if _networked() and not _authority():
		var state: Dictionary = world.net.rowboat_state
		if not state.is_empty():
			apply_network_state(state)

func _networked() -> bool:
	return world != null and world.get("net") != null and world.net.is_connected

func _authority() -> bool:
	return not _networked() or world.net.is_host

func _dedicated() -> bool:
	return world.get("net") != null and world.net.is_dedicated_server

func local_peer() -> int:
	return world.net.get_my_id() if _networked() else 1

func get_interaction_text(_actor = null) -> String:
	return "Bote ocupado" if occupant != 0 else "Entrar en bote - [F]"

func can_board_from(pos: Vector3) -> bool:
	return pos.is_finite() and absf(pos.y - global_position.y) < 3.0 and Vector2(pos.x, pos.z).distance_to(Vector2(global_position.x, global_position.z)) <= BOARD_REACH

func interact(actor: Node) -> void:
	if actor == null or actor.get("is_dead") == true or not can_board_from(actor.global_position):
		return
	if actor.get("is_sleeping") == true or actor.get("_interact_busy") == true or actor.get("_consumption_pending") == true:
		return
	if occupant == 0 and actor.get_held_item() != null:
		actor._store_held_item()
		if actor.get_held_item() != null:
			actor.notice.emit("Guarda el objeto de las manos antes de entrar en el bote.")
			return
	if _authority():
		request_action(local_peer(), "enter")
	else:
		world.net.request_rowboat.rpc_id(1, "enter")

func request_exit() -> void:
	if _authority():
		request_action(local_peer(), "exit")
	else:
		world.net.request_rowboat.rpc_id(1, "exit")

func _actor_for(peer_id: int) -> Node3D:
	if peer_id == local_peer() and world.get("player") != null:
		return world.player
	return world.remote_players.get(peer_id) if world.get("remote_players") != null else null

func _peer_alive(peer_id: int) -> bool:
	if not _networked():
		return peer_id == 1 and world.player != null and not world.player.is_dead
	if not world.net.players.has(peer_id):
		return false
	var data: Dictionary = world.net.players[peer_id]
	if data.get("offline", false) or str(data.get("anim", "")).contains("dead"):
		return false
	var actor := _actor_for(peer_id)
	if actor != null and actor.get("is_dead") == true:
		return false
	var proxy: Node = world.server_proxies.get(peer_id)
	return proxy == null or not proxy.get_meta("proxy_dead", false)

func request_action(sender: int, action: String) -> void:
	if not _authority() or not _peer_alive(sender):
		return
	var now := Time.get_ticks_msec()
	if now - int(_request_times.get(sender, -1000)) < 250:
		return
	_request_times[sender] = now
	if action == "enter":
		if occupant != 0:
			return
		var actor := _actor_for(sender)
		var pos: Vector3 = actor.global_position if actor != null else world.net.players[sender].get("pos", Vector3.INF)
		if not can_board_from(pos):
			return
		if actor != null and (actor.get("is_sleeping") == true or actor.get("_interact_busy") == true or actor.get("_consumption_pending") == true):
			return
		return_position = pos
		occupant = sender
		_axis = Vector2.ZERO
		_input_age = 0.0
		_sync_passenger()
	elif action == "exit" and occupant == sender:
		var shore := find_exit_position()
		if shore.is_empty():
			return
		exit_position = shore.position
		_release_passenger()
	_send_state()

func accept_input(sender: int, axis: Vector2) -> void:
	if not _authority() or sender != occupant or occupant == 0 or not axis.is_finite():
		return
	_axis = axis.limit_length(1.0)
	_input_age = 0.0

func water_local(pos: Vector3) -> Vector3:
	return (pos - lake_center).rotated(Vector3.UP, -lake_yaw)

func contains_hull(pos: Vector3) -> bool:
	var p := water_local(pos)
	var radii := lake_size * 0.425 - Vector2.ONE * HULL_MARGIN
	return radii.x > 0 and radii.y > 0 and pow(p.x / radii.x, 2) + pow(p.z / radii.y, 2) <= 1.0

func clamp_to_lake(pos: Vector3) -> Vector3:
	var p := water_local(pos)
	var radii := lake_size * 0.425 - Vector2.ONE * HULL_MARGIN
	var radius := Vector2(p.x / radii.x, p.z / radii.y).length()
	if radius > 1.0:
		p.x /= radius
		p.z /= radius
	p.y = -0.20
	return lake_center + p.rotated(Vector3.UP, lake_yaw)

func simulate(delta: float) -> void:
	_input_age += delta
	if _input_age > 0.5 or occupant == 0:
		_axis = Vector2.ZERO
	rowing = occupant != 0 and _axis.length_squared() > 0.01
	var target_speed := -_axis.y * MAX_SPEED
	speed = move_toward(speed, target_speed, delta * (1.3 if rowing else 2.0))
	rotation.y -= _axis.x * delta * 0.7
	var proposed := global_position - global_basis.z * speed * delta
	if contains_hull(proposed):
		global_position = proposed
	else:
		speed = 0.0
	if rowing:
		rowing_time = fposmod(rowing_time + delta, CYCLE)

func _physics_process(delta: float) -> void:
	if world.get("_scene_quitting") == true:
		return
	if _authority():
		if occupant != 0 and not _peer_alive(occupant):
			exit_position = global_position if _occupant_dead() else return_position
			_release_passenger()
		if occupant == local_peer() and not _dedicated():
			accept_input(occupant, _local_input())
		simulate(delta)
		_exit_timer -= delta
		if _exit_timer <= 0:
			_exit_timer = 0.3
			var shore := find_exit_position()
			_can_exit = not shore.is_empty()
			if _can_exit:
				exit_position = shore.position
		_sync_authoritative_position()
	elif occupant == local_peer():
		_input_age += delta
		if _input_age >= 0.1:
			_input_age = 0.0
			world.net.rowboat_input.rpc_id(1, _local_input())
	_send_timer += delta
	if _authority() and _send_timer >= 0.1:
		_send_timer = 0.0
		_send_state()

func _local_input() -> Vector2:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _process(delta: float) -> void:
	if not _authority():
		global_position = global_position.lerp(_network_position, 1.0 - exp(-delta * 18.0))
		rotation.y = lerp_angle(rotation.y, _network_yaw, 1.0 - exp(-delta * 18.0))
		if rowing:
			rowing_time = fposmod(rowing_time + delta, CYCLE)
	_sync_passenger()
	if animation_player != null:
		animation_player.seek(rowing_time, true)
	if is_instance_valid(passenger):
		passenger.update_rowing_pose(rowing_time)
	_update_water_fx(delta)

func _sync_passenger() -> void:
	if occupant == 0:
		return
	var actor := _actor_for(occupant)
	if actor == null or actor.get("third_person_model") == null or actor.get("is_dead") == true:
		return
	if passenger != actor:
		passenger = actor
		passenger.begin_rowing(self)
	passenger.global_position = global_position
	passenger.rotation.y = rotation.y + PI

func _occupant_dead() -> bool:
	var actor := _actor_for(occupant)
	if actor != null and actor.get("is_dead") == true:
		return true
	if _networked():
		var proxy: Node = world.server_proxies.get(occupant)
		return (proxy != null and proxy.get_meta("proxy_dead", false)) or str(world.net.players.get(occupant, {}).get("anim", "")).contains("dead")
	return false

func _release_passenger() -> void:
	var was_dead := _occupant_dead()
	var old_id := occupant
	occupant = 0
	_axis = Vector2.ZERO
	speed = 0.0
	rowing = false
	if is_instance_valid(passenger):
		passenger.end_rowing(exit_position)
	passenger = null
	if _networked() and world.net.players.has(old_id):
		world.net.players[old_id]["pos"] = exit_position
		world.net.players[old_id]["anim"] = "dead" if was_dead else "idle"
		var proxy: Node = world.server_proxies.get(old_id)
		if proxy != null:
			proxy.global_position = exit_position
			proxy.set_meta("saved_pos", exit_position)

func _sync_authoritative_position() -> void:
	if occupant == 0 or not _networked() or not world.net.players.has(occupant):
		return
	world.net.players[occupant]["pos"] = global_position
	world.net.players[occupant]["rot"] = rotation.y + PI
	var proxy: Node = world.server_proxies.get(occupant)
	if proxy != null:
		proxy.global_position = global_position

func find_exit_position() -> Dictionary:
	var p := water_local(global_position)
	var radii := lake_size * 0.425
	var angle := atan2(p.z / radii.y, p.x / radii.x)
	for offset in [0.0, 0.06, -0.06, 0.12, -0.12]:
		var theta: float = angle + offset
		var edge := Vector3(cos(theta) * (radii.x + 1.0), 0, sin(theta) * (radii.y + 1.0))
		var pos := lake_center + edge.rotated(Vector3.UP, lake_yaw)
		if Vector2(pos.x, pos.z).distance_to(Vector2(global_position.x, global_position.z)) > BOARD_REACH:
			continue
		if world.get_river_depth_at(pos) > 0.02:
			continue
		var query := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 8.0, pos - Vector3.UP * 3.0, 1)
		query.exclude = [get_rid()]
		var ground := get_world_3d().direct_space_state.intersect_ray(query)
		if ground.is_empty() or ground.normal.y < 0.8 or ground.position.y < lake_center.y - 0.15 or ground.position.y > lake_center.y + 1.5:
			continue
		pos.y = ground.position.y + 0.12
		var body := CapsuleShape3D.new()
		body.radius = 0.34
		body.height = 1.75
		var clearance := PhysicsShapeQueryParameters3D.new()
		clearance.shape = body
		clearance.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 0.9)
		clearance.collision_mask = 1
		clearance.exclude = [get_rid()]
		if is_instance_valid(passenger):
			clearance.exclude = [get_rid(), passenger.get_rid()]
		if get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty():
			return {"position": pos}
	return {}

func passenger_prompt() -> String:
	return "W/S: remar | A/D: girar | F: salir del bote" if _can_exit else "W/S: remar | A/D: girar | Acercate a la orilla para salir"

func _create_water_fx() -> void:
	_foam_texture = _water_particle_texture(false)
	_ripple_texture = _water_particle_texture(true)
	_wake = _make_foam(130, 2.6)
	_wake.name = "WakeFx"
	var wake_mat := _wake.process_material as ParticleProcessMaterial
	wake_mat.emission_box_extents = Vector3(0.55, 0, 0.16)
	wake_mat.scale_min = 0.8
	wake_mat.scale_max = 1.3
	_wake.position = Vector3(0, WATER_Y, 2.5)
	add_child(_wake)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var suffix := "L" if i == 0 else "R"
		var foam := _make_foam(64, 1.8)
		foam.name = "BowFoam" + suffix
		foam.position = Vector3(side * 0.72, WATER_Y, -2.4)
		add_child(foam)
		_bow_foam.append(foam)
		var spray := _make_spray(24, 0.55, false)
		spray.name = "BowSpray" + suffix
		spray.position = foam.position
		add_child(spray)
		_bow_spray.append(spray)
		var churn := _make_foam(40, 1.6)
		churn.name = "OarFoam" + suffix
		add_child(churn)
		_oar_foam.append(churn)
		var ripple := _make_foam(2, 1.2, true)
		ripple.name = "OarRipple" + suffix
		ripple.one_shot = true
		ripple.explosiveness = 0.8
		add_child(ripple)
		_oar_ripples.append(ripple)
		var oar := visual.find_child("OarLeft" if i == 0 else "OarRight", true, false) as Node3D
		_oars.append(oar)
		_previous_blades.append(to_local(oar.to_global(_blade_points[i])) if oar != null else Vector3.ZERO)
	_oar_splash_l = _make_splash(Vector3(-2.1, WATER_Y, -1))
	_oar_splash_r = _make_splash(Vector3(2.1, WATER_Y, -1))
	_oar_audio = AudioStreamPlayer3D.new()
	_oar_audio.name = "OarSplashAudio"
	_oar_audio.unit_size = 5.0
	_oar_audio.max_distance = 45.0
	_oar_audio.stream = _load_fx_stream(OAR_SPLASH_PATH)
	_oar_audio.position = Vector3(0, WATER_Y, 0.3)
	add_child(_oar_audio)
	_wake_audio = AudioStreamPlayer3D.new()
	_wake_audio.name = "WakeAudio"
	_wake_audio.unit_size = 4.0
	_wake_audio.max_distance = 30.0
	var wake_stream := _load_fx_stream(WAKE_LOOP_PATH)
	if wake_stream is AudioStreamMP3:
		# Skip the recording intro; loop_offset keeps the loop in the useful part.
		wake_stream.loop = true
		wake_stream.loop_offset = 4.0
	_wake_audio.stream = wake_stream
	_wake_audio.volume_db = -80.0
	add_child(_wake_audio)

func _make_splash(pos: Vector3) -> GPUParticles3D:
	var splash := _make_spray(36, 0.6, false)
	splash.name = "OarSplash" + ("L" if pos.x < 0 else "R")
	splash.position = pos
	add_child(splash)
	return splash

func _water_particle_texture(ripple: bool) -> Texture2D:
	var image := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 73
	noise.frequency = 0.18
	for y in range(96):
		for x in range(96):
			var p := (Vector2(x, y) - Vector2(47.5, 47.5)) / 47.5
			var radius := p.length()
			var grain := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var alpha := 0.0
			if ripple:
				alpha = exp(-pow((radius - 0.72 + (grain - 0.5) * 0.06) / 0.045, 2.0)) * smoothstep(0.2, 0.7, grain) * 0.6
			else:
				alpha = (1.0 - smoothstep(0.3, 1.0, radius)) * smoothstep(0.32, 0.7, grain)
			image.set_pixel(x, y, Color(0.86, 0.94, 0.96, alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _particle_fade() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color(1, 1, 1, 0.65), Color(1, 1, 1, 0)])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture

func _make_foam(amount: int, lifetime: float, ripple := false) -> GPUParticles3D:
	var p := _make_spray(amount, lifetime, false)
	var mat := p.process_material as ParticleProcessMaterial
	mat.gravity = Vector3.ZERO
	mat.direction = Vector3.BACK
	mat.spread = 0.0
	mat.initial_velocity_min = 0.08
	mat.initial_velocity_max = 0.18
	mat.emission_box_extents = Vector3(0.09, 0, 0.09)
	mat.scale_min = 0.35 if ripple else 0.22
	mat.scale_max = 0.55 if ripple else 0.48
	mat.color = Color(0.88, 0.96, 1, 0.65)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.25))
	curve.add_point(Vector2(0.25, 0.6))
	curve.add_point(Vector2(1, 1.0))
	var growth := CurveTexture.new()
	growth.curve = curve
	mat.scale_curve = growth
	mat.scale_min *= 3.5 if ripple else 2.6
	mat.scale_max *= 3.5 if ripple else 2.6
	var mesh := PlaneMesh.new()
	mesh.size = Vector2.ONE
	var surf := StandardMaterial3D.new()
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.albedo_texture = _ripple_texture if ripple else _foam_texture
	surf.roughness = 1.0
	surf.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = surf
	p.draw_pass_1 = mesh
	return p

func _make_spray(amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.randomness = 0.65
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-16, -2, -16), Vector3(32, 6, 32))
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(0.12, 0.015, 0.12)
	mat.direction = Vector3(0, 1, 0.4).normalized()
	mat.spread = 28.0
	mat.initial_velocity_min = 0.65
	mat.initial_velocity_max = 1.5
	mat.gravity = Vector3(0, -5.0, 0)
	mat.scale_min = 0.018
	mat.scale_max = 0.045
	mat.color = Color(0.8, 0.91, 0.96, 0.7)
	mat.color_ramp = _particle_fade()
	p.process_material = mat
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var surf := StandardMaterial3D.new()
	surf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	surf.vertex_color_use_as_albedo = true
	surf.roughness = 0.25
	mesh.material = surf
	p.draw_pass_1 = mesh
	return p

func _load_fx_stream(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var loaded = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if loaded is AudioStream:
			return loaded
	var disk_path := ProjectSettings.globalize_path(path)
	if path.get_extension().to_lower() == "mp3" and FileAccess.file_exists(disk_path):
		var mp3 := AudioStreamMP3.load_from_file(disk_path)
		if mp3 is AudioStream:
			return mp3
	return null

func _update_water_fx(delta: float) -> void:
	if _wake == null or delta <= 0.0:
		return
	var displacement := global_position - _fx_prev_pos
	displacement.y = 0
	_fx_prev_pos = global_position
	var teleported := displacement.length() > maxf(1.0, MAX_SPEED * delta * 2.5)
	var velocity := displacement / delta
	_fx_velocity = Vector3.ZERO if teleported else _fx_velocity.lerp(velocity, 1.0 - exp(-delta * 12.0))
	_fx_speed = minf(_fx_velocity.length(), MAX_SPEED)
	var moving := _fx_speed > 0.18
	var strength := clampf(_fx_speed / MAX_SPEED, 0.0, 1.0)
	var travel := 1.0 if _fx_velocity.dot(-global_basis.z) >= 0 else -1.0
	_wake.position.z = 2.5 * travel
	_wake.emitting = moving
	_wake.amount_ratio = maxf(0.05, strength)
	var wake_mat := _wake.process_material as ParticleProcessMaterial
	wake_mat.direction = Vector3(0, 0, travel)
	wake_mat.initial_velocity_min = 0.08 + strength * 0.12
	wake_mat.initial_velocity_max = 0.2 + strength * 0.35
	for i in range(_bow_foam.size()):
		var side := -1.0 if i == 0 else 1.0
		var foam := _bow_foam[i]
		foam.position = Vector3(side * (0.72 if travel > 0 else 0.38), WATER_Y, -2.4 if travel > 0 else 2.1)
		foam.emitting = moving
		foam.amount_ratio = maxf(0.05, strength)
		var mat := foam.process_material as ParticleProcessMaterial
		mat.direction = Vector3(side * 0.85, 0, travel).normalized()
		mat.initial_velocity_min = 0.15 + strength * 0.3
		mat.initial_velocity_max = 0.3 + strength * 0.65
		var spray := _bow_spray[i]
		spray.position = foam.position
		spray.emitting = moving and strength > 0.3
		spray.amount_ratio = maxf(0.05, strength * strength)
		var spray_mat := spray.process_material as ParticleProcessMaterial
		spray_mat.direction = Vector3(side * 0.7, 0.65, travel * 0.5).normalized()
		spray_mat.initial_velocity_min = 0.3 + strength * 0.3
		spray_mat.initial_velocity_max = 0.5 + strength * 0.75
	if _wake_audio != null and _wake_audio.stream != null:
		var target := lerpf(-24.0, -8.0, strength) if moving else -80.0
		_wake_audio.volume_db = lerpf(_wake_audio.volume_db, target, 1.0 - exp(-delta * 4.0))
		_wake_audio.pitch_scale = lerpf(0.85, 1.05, strength)
		if _wake_audio.volume_db > -55.0 and not _wake_audio.playing:
			_wake_audio.play()
		elif _wake_audio.volume_db < -55.0 and _wake_audio.playing:
			_wake_audio.stop()
	_oar_audio_remaining = maxf(0.0, _oar_audio_remaining - delta)
	if _oar_audio != null and (_oar_audio_remaining == 0.0 or not rowing):
		_oar_audio.stop()
	_update_oar_fx(delta, teleported)

func _update_oar_fx(delta: float, teleported: bool) -> void:
	var entered := false
	for i in range(_oars.size()):
		var oar := _oars[i]
		if oar == null:
			continue
		var blade := to_local(oar.to_global(_blade_points[i]))
		var pivot := to_local(oar.global_position)
		var measured_velocity := (blade - _previous_blades[i]) / delta
		_blade_velocities[i] = _blade_velocities[i].lerp(measured_velocity, 1.0 - exp(-delta * 18.0)) if rowing and not teleported else Vector3.ZERO
		var blade_velocity: Vector3 = _blade_velocities[i]
		_previous_blades[i] = blade
		var depth := pivot.y - blade.y
		var contact := pivot.lerp(blade, clampf((pivot.y - WATER_Y) / maxf(depth, 0.001), 0.0, 1.0))
		contact.y = WATER_Y
		var pulling := rowing and not teleported and blade.y < WATER_Y and blade_velocity.z > 0.15 and blade_velocity.length() < 6.0
		var force := clampf(blade_velocity.length() / 2.0, 0.15, 1.0)
		var spray := _oar_splash_l if i == 0 else _oar_splash_r
		spray.position = contact
		spray.emitting = pulling
		spray.amount_ratio = force
		var spray_mat := spray.process_material as ParticleProcessMaterial
		spray_mat.direction = Vector3(blade_velocity.x * 0.25, 0.9, 0.6).normalized()
		spray_mat.initial_velocity_max = lerpf(0.8, 1.6, force)
		var foam := _oar_foam[i]
		foam.position = contact
		foam.emitting = pulling
		foam.amount_ratio = force
		var foam_mat := foam.process_material as ParticleProcessMaterial
		foam_mat.direction = Vector3(blade_velocity.x, 0, maxf(0.1, blade_velocity.z)).normalized()
		if pulling and not _oar_pulling[i]:
			_oar_ripples[i].position = contact
			_oar_ripples[i].restart()
			entered = true
		_oar_pulling[i] = pulling
	if entered and _oar_audio != null and not _oar_audio.playing:
		_oar_audio.position = (_oar_foam[0].position + _oar_foam[1].position) * 0.5
		_play_stroke_audio()

func _play_stroke_audio() -> void:
	if _oar_audio != null and _oar_audio.stream != null:
		_oar_audio.pitch_scale = randf_range(0.94, 1.06)
		_oar_audio.volume_db = randf_range(-7.0, -4.0)
		_oar_audio.play(2.0)
		_oar_audio_remaining = 1.0

func _send_state() -> void:
	if not _networked() or not _authority():
		return
	_sequence += 1
	var state := {"seq": _sequence, "pos": global_position, "yaw": rotation.y, "occupant": occupant, "time": rowing_time, "rowing": rowing, "exit": exit_position, "can_exit": _can_exit}
	for id in world.net.players:
		if id != local_peer() and not world.net.players[id].get("offline", false) and world.net.peer.get_peer(id) != null:
			world.net.sync_rowboat.rpc_id(id, state)

func apply_network_state(state: Dictionary) -> void:
	if _authority() or int(state.get("seq", -1)) <= _last_sequence:
		return
	_last_sequence = int(state.seq)
	exit_position = state.exit
	var next_occupant: int = state.occupant
	if occupant != next_occupant:
		_release_passenger()
		occupant = next_occupant
	_network_position = state.pos
	_network_yaw = state.yaw
	rowing_time = state.time
	rowing = state.rowing
	_can_exit = state.can_exit

func save_state() -> Dictionary:
	return {"x": global_position.x, "z": global_position.z, "yaw": rotation.y, "return": [return_position.x, return_position.y, return_position.z]}

func restore_state(state: Dictionary, actor: Node3D = null) -> void:
	if state.is_empty() or not _authority():
		return
	var pos := Vector3(float(state.get("x", global_position.x)), lake_center.y, float(state.get("z", global_position.z)))
	var yaw := float(state.get("yaw", rotation.y))
	if not pos.is_finite() or not is_finite(yaw):
		return
	global_position = clamp_to_lake(pos)
	rotation.y = yaw
	var dry = state.get("return", [])
	if dry is Array and dry.size() == 3:
		return_position = Vector3(float(dry[0]), float(dry[1]), float(dry[2]))
	if actor != null and not actor.is_dead:
		occupant = local_peer()
		_sync_passenger()

func _exit_tree() -> void:
	if is_instance_valid(passenger) and passenger.is_inside_tree():
		passenger.end_rowing(return_position)
