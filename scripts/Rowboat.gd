extends StaticBody3D

const MODEL := preload("res://assets/models/props/rowboat_animated.glb")
const CYCLE := 2.0
const MAX_SPEED := 3.2
const HULL_MARGIN := 3.0
const BOARD_REACH := 4.6

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
