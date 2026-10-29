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
var _route_waiting := false
var _shore_escape_target: Variant = null
var _debug_timer := 0.0
var _attack_timer := 0.0
var _attack_cooldown := 0.0
var _animal_bite_target: Node3D = null
var _animal_bite_elapsed := 0.0
var _animal_bite_landed := false
var _chase_target: Node3D = null
var _state := "patrol"
var _noise_attract_pos: Vector3 = Vector3.ZERO
var _noise_attract_timer := 0.0
var _chase_stuck_time := 0.0
var _reach_check_timer := 0.0
var _chase_cooldown := 0.0
var _retreat_target := Vector3.ZERO
var _wait_near_timer := 0.0
var _wait_near_pos := Vector3.ZERO
var _howl_timer := randf_range(15.0, 35.0)
var _growl_timer := randf_range(8.0, 18.0)
var _wolf_audio_player: AudioStreamPlayer3D = null
var _wolf_pain_player: AudioStreamPlayer = null
var _wolf_howl_2d_player: AudioStreamPlayer = null
var _wolf_hunger := 40.0
var _wolf_hunger_threshold := 70.0
var _wolf_eating_timer := 0.0
var _wolf_eating_target: Node3D = null
var _prey_flee_timer := 0.0
var _flee_origin := Vector3.INF
# Segundos de huida continua: al agotarse, la presa pierde el sprint y el lobo
# (más resistente) la alcanza — sin esto, dos velocidades parecidas hacían la
# persecución eterna.
var _flee_stamina := 0.0
var _seek_corpse_timer := 0.0
# Cebo reclamado: solo un lobo va a por cada pieza de carne tirada; los demás
# la rondan en vez de amontonarse. La meta wolf_claim en el WorldAction apunta
# al lobo, y el claim solo vale mientras _claimed_meat siga apuntando a ella.
var _claimed_meat: Node3D = null
var _offer_stall_msec := 0
# Acción -> fin del veto (Time.get_ticks_msec): cebo inalcanzable para este
# lobo se ignora un tiempo en vez de dejarlo plantado reintentando.
var _offering_blacklist := {}
var _rot_timer := 0.0
var _flies_attached := false
var _wolf_ai_debug_timer := 0.0
var _resolve_player_timer := 0.0
var health := 240.0
var max_health := 240.0
var _is_dead := false
var is_puppet := false
var _network_motion = preload("res://scripts/AnimalNetworkMotion.gd").new()
var _observer_check_timer := 0.0
var _near_network_observer := false
var current_anim_keyword := "walk"
var _puppet_desired_anim := "walk"
var _tamed_rest_time := 0.0
var _hit_flash_timer := 0.0
var _gutted := false
var _corpse_body: StaticBody3D = null
# Recuperación de atascos y movimiento natural
var _stuck_escalation := 0
var _unstuck_dir := Vector3.ZERO
var _unstuck_timer := 0.0
var _wander_offset := Vector3.ZERO
var _wander_timer := 0.0
var _speed_jitter := 1.0
var _idle_timer := 0.0
var _idle_cooldown := 0.0
# Detección de "sin progreso": el animal se mueve pero no avanza (oscila)
var _progress_ref_pos := Vector3.ZERO
var _progress_timer := 0.0

# Profundidad de agua (rios/lagos): afecta velocidad y hundimiento visual, igual que el jugador
var _water_depth := 0.0
var _water_sink := 0.0
var _water_query_timer := 0.0

# Huellas: contador de distancia recorrida y lado alterno de la pisada.
# Cosmetico por cliente — cada cliente dibuja sus propias huellas al ver al
# animal moverse, así que no viaja nada por la red.
const TrackPrintScript = preload("res://scripts/TrackPrint.gd")
const TRACK_SPECS := {
	"wolf": {"kind": "paw", "size": 0.34, "stride": 0.48, "lat": 0.14},
	"deer": {"kind": "hoof", "size": 0.30, "stride": 0.62, "lat": 0.12},
	"fox": {"kind": "paw", "size": 0.24, "stride": 0.38, "lat": 0.11},
	"bear": {"kind": "bear_paw", "size": 0.58, "stride": 0.78, "lat": 0.22},
}
var _track_started := false
var _track_anchor := Vector3.ZERO
var _track_acc := 0.0
var _track_side := 1.0

static var _scene_cache := {}
static var _shared_sphere: SphereMesh = null
static var _shared_cylinder: CylinderMesh = null

# LOD de IA: reduce frecuencia de actualización para animales lejanos
var _ai_lod_timer := 0.0
var _ai_lod_clock := 0.0
const AI_LOD_NEAR := 40.0   # Distancia: IA completa cada frame
const AI_LOD_MID  := 80.0   # Distancia: IA cada 0.25s
const AI_LOD_FAR  := 120.0  # Distancia: IA cada 1.0s, invisible después
const AI_LOD_CULL := 200.0  # Distancia: sin IA (solo actualiza rot_timer de cadáver)

# Domesticación de lobos. La autoridad es el servidor (o el mundo local en SP);
# los clientes solo ven el estado replicado y envían comandos por RPC.
# tamed_to: "" = salvaje, "local" = jugador local (SP/host), str(peer_id) en servidor.
const TAME_FEEDINGS := 3          # comidas válidas para domesticar
const TAME_FEED_RADIUS := 15.0    # quien alimenta debe seguir cerca al comer
const TAME_GUARD_SECONDS := 60.0  # luto junto al cadáver del dueño antes de volverse salvaje
var tamed_to := ""
var _tame_progress := {}          # feeder_id -> nº de comidas
var _follow_mode := "follow"      # "follow" | "stay" | "patrol" (solo con tamed_to != "")
var _ordered_prey: Node = null        # orden "atacar" sobre un animal (no lobo)
var _orders_cease := false            # orden "no atacar": no enganchar amenazas solo
var _warn_bark_timer := 0.0           # ladrido de aviso al ver amenazas cerca del dueno
var _hunger_warned := false           # aviso "tu lobo tiene hambre" enviado al dueno
var _stay_pos := Vector3.ZERO
var _wolf_foe: Node3D = null      # lobo enemigo en combate canino
var _house_direct_goal := false   # domesticado dentro de casa: guiado directo al dueño
var _foe_timer := 0.0
var _threat_player: Node3D = null # jugador que dañó al dueño (o al que el dueño atacó)
var _threat_timer := 0.0
var _owner_node: Node3D = null
var _owner_client_id := ""
var _owner_dead_timer := 0.0
var _bear_warn_timer := 0.0
var _flank_sign := 0.0

# Cache de grupo wildlife para evitar get_nodes_in_group cada frame
var _cached_wildlife: Array = []
var _wildlife_cache_timer := 0.0

# Puppet mode: visual-only animal controlled by network sync (no AI)
func setup_puppet(kind: String) -> void:
	animal_type = kind
	is_puppet = true
	add_to_group("wildlife")
	match animal_type:
		"wolf":
			health = 240.0
			max_health = 240.0
		"deer":
			health = 80.0
			max_health = 80.0
		"fox":
			health = 50.0
			max_health = 50.0
		"bear":
			health = 650.0
			max_health = 650.0
		_:
			health = 100.0
			max_health = 100.0
	_build_animal()

func puppet_apply(pos: Vector3, rot_y: float, anim: String, dead: bool, gutted: bool, rot_left: float = -1.0) -> void:
	if dead and not _is_dead:
		_network_motion.push(self, pos, rot_y, true)
		_is_dead = true
		_gutted = gutted
		# Without a corpse lifetime the next _process would free the body the
		# same frame it arrived — mirror the server's 300s rot window, then keep
		# tracking whatever the server reports so both sides drop it together.
		_rot_timer = rot_left if rot_left > 0.0 else 300.0
		if _animation_player != null:
			_animation_player.stop()
		_lie_corpse_flat()
	if _is_dead:
		if rot_left > 0.0:
			_rot_timer = rot_left
		return
	_network_motion.push(self, pos, rot_y)
	if not dead:
		_puppet_desired_anim = anim.to_lower()
		_play_animation_by_name(anim)

# Puppet take_damage: forward to server via RPC and apply locally for visual feedback
func take_damage(amount: float, from_knife: bool, attacker: Node = null) -> void:
	if animal_type == "bear" and not from_knife:
		# Bears require 3 rifle shots (650 HP / max 240 dmg per shot -> 3 shots).
		amount = minf(amount, 240.0)
	if not is_puppet:
		# Real animal — apply damage directly
		if _is_dead:
			return
		health = max(0.0, health - amount)
		_hit_flash_timer = 0.3
		if animal_type == "bear":
			# Bears do not flee when shot: they roar and charge the attacker.
			_prey_flee_timer = 0.0
			_chase_cooldown = 0.0
			_bear_warn_timer = 0.0
			_wolf_eating_timer = 0.0
			_wolf_eating_target = null
			_idle_timer = 0.0
			if attacker is Node3D and is_instance_valid(attacker):
				# Contra otro animal (lobo) el combate va por _wolf_foe/_fight_animal —
				# el path de jugador llama apply_damage y no le haria nada.
				if attacker is WildlifeController:
					_wolf_foe = attacker as WildlifeController
					_foe_timer = 20.0
				else:
					_player = attacker as Node3D
					_chase_target = _player
					_state = "chase_player"
			_play_wolf_sound("attack")
		else:
			var critical_wound := animal_type == "wolf" and health > 0.0 and health <= max_health * 0.25
			_prey_flee_timer = 14.0 if critical_wound else (12.0 if (animal_type == "deer" or animal_type == "fox") else 8.0)
			_flee_stamina = 0.0
			_idle_timer = 0.0
			_unstuck_timer = 0.0
			_ai_lod_clock = 10.0
			var threat_node: Node3D = attacker as Node3D if (attacker is Node3D and is_instance_valid(attacker)) else null
			if threat_node == null and _player != null and is_instance_valid(_player):
				threat_node = _player
			if threat_node == null:
				threat_node = _find_nearest_proxy()
			if threat_node != null:
				_flee_origin = threat_node.global_position
				if animal_type == "wolf" and tamed_to.is_empty():
					_player = threat_node
			elif not _flee_origin.is_finite():
				_flee_origin = global_position - global_transform.basis.z * 6.0
			_chase_cooldown = 16.0 if critical_wound else 10.0
			if animal_type == "deer" or animal_type == "fox":
				_state = "flee"
				_play_animation_by_name("gallop" if animal_type == "deer" else "run")
				_alert_nearby_herd(_flee_origin, 42.0)
			elif animal_type == "wolf" and tamed_to.is_empty() and threat_node != null:
				_alert_nearby_pack(threat_node)
		_current_path.clear()
		_path_index = 0
		_path_recalc_timer = 0.0
		_spawn_blood_splatter()
		_play_pain_sound()
		_note_attack(attacker)
		if health <= 0.0:
			_is_dead = true
			_hit_flash_timer = 2.0
			_rot_timer = 300.0
			if _animation_player != null:
				_animation_player.stop()
			_release_owner_record()
			_lie_corpse_flat()
			var scene := get_tree().current_scene
			if scene != null and scene.has_method("_note_wildlife_death"):
				scene._note_wildlife_death(animal_type, global_position)
		return
	# A client reports each hit; health/death and hit feedback come from the
	# server. Predicting death here could hide a still-living animal and
	# discard the remaining rounds of a burst before they reach the server.
	if _is_dead:
		return
	# Also notify the server
	var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
	if net_node != null and net_node.peer != null:
		net_node.damage_animal.rpc_id(1, name, amount, from_knife)

func setup(kind: String, points: Array) -> void:
	animal_type = kind
	add_to_group("wildlife")
	if animal_type == "wolf":
		add_to_group("wildlife_wolf")
		_wolf_hunger = randf_range(25.0, 50.0)
		_wolf_hunger_threshold = randf_range(68.0, 82.0)
	elif animal_type == "bear":
		_wolf_hunger = randf_range(25.0, 65.0)
		_wolf_hunger_threshold = randf_range(65.0, 85.0)
	# Set health based on animal type
	match animal_type:
		"wolf":
			health = 240.0
			max_health = 240.0
		"deer":
			health = 80.0
			max_health = 80.0
		"fox":
			health = 50.0
			max_health = 50.0
		"bear":
			health = 650.0
			max_health = 650.0
		_:
			health = 100.0
			max_health = 100.0
	patrol_points = points.duplicate()
	if patrol_points.is_empty():
		patrol_points = [Vector3.ZERO, Vector3(10, 0, 10), Vector3(-10, 0, -10)]
	global_position = patrol_points[0]
	_last_position = global_position
	_progress_ref_pos = global_position
	target_index = 1 if patrol_points.size() > 1 else 0
	move_speed = 1.55 if animal_type == "bear" else (1.65 if animal_type == "deer" else (2.0 if animal_type == "wolf" else 2.35))
	_speed_jitter = randf_range(0.85, 1.18)
	# Golden-ratio phase spread: sequential wildlife names produce consecutive
	# hashes, so a plain mod clusters them into the same update frame.
	_ai_lod_clock = fposmod(hash(name) * 0.618033988749895, 1.0)
	_wander_timer = randf_range(0.0, 4.0)
	_idle_cooldown = randf_range(4.0, 14.0)
	if animal_type == "wolf":
		_chase_cooldown = 15.0
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
	for radius in [2.0, 4.0, 6.0, 9.0, 13.0, 18.0, 26.0, 36.0, 48.0, 62.0, 80.0, 105.0]:
		for i in range(16):
			var angle := TAU * float(i) / 16.0
			var candidate := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
			candidate.z = clamp(candidate.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
			if _is_position_allowed(candidate):
				return candidate
	return null

# If the animal is currently standing in a blocked area (e.g. stuck in the river),
# force-walk it toward the nearest shore, ignoring the per-step allow check so it
# can cross the water out of the trap.
func _escape_if_trapped(delta: float) -> bool:
	var _t := Time.get_ticks_usec()
	var _r := _escape_if_trapped_impl(delta)
	_pp("escape", _t)
	return _r

func _escape_if_trapped_impl(delta: float) -> bool:
	if _is_position_allowed(global_position):
		_shore_escape_target = null
		return false
	# Don't escape from inside a house with a closed door - wolf should stay trapped
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_is_inside_closed_house"):
		if scene.call("_is_inside_closed_house", global_position):
			return false
	if _shore_escape_target == null:
		_shore_escape_target = _nearest_allowed_point(global_position)
	var safe = _shore_escape_target
	if safe == null:
		return false
	var dir: Vector3 = (safe - global_position)
	dir.y = 0.0
	if dir.length() < 0.01:
		return false
	dir = dir.normalized()
	var step := minf(move_speed * 2.2 * delta, global_position.distance_to(safe))
	var next_pos := global_position + dir * step
	next_pos.x = clamp(next_pos.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
	next_pos.z = clamp(next_pos.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
	global_position = next_pos
	_snap_to_terrain()
	_current_path.clear()
	_path_recalc_timer = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 6.0)
	_play_animation_by_name("trot")
	_walk_time += delta * move_speed * 5.0
	_animate_legs(delta)
	_update_animation_speed(move_speed * 2.2)
	return true

func _exit_tree() -> void:
	_scene_cache.clear()
	_shared_sphere = null
	_shared_cylinder = null

static var perf_usec := 0
static var perf_parts := {}
var _is_dedicated := false
var _dedicated_checked := false

static func _pp(part: String, t0: int) -> void:
	perf_parts[part] = int(perf_parts.get(part, 0)) + Time.get_ticks_usec() - t0

func _process(delta: float) -> void:
	var _t0 := Time.get_ticks_usec()
	_process_body(delta)
	perf_usec += Time.get_ticks_usec() - _t0

func _process_body(delta: float) -> void:
	if not is_puppet and not tamed_to.is_empty() and not _is_dead and _state in ["follow", "guard"] and current_anim_keyword in ["idle", "sit", "lie"] and _threat_player == null:
		_tamed_rest_time += delta
	else:
		_tamed_rest_time = 0.0
	_update_tracks()
	if is_puppet:
		if not _is_dead:
			var prev_puppet_pos := global_position
			_network_motion.advance(self, delta)
			var far_from_viewer := false
			if DisplayServer.get_name() != "headless":
				var sc := get_tree().current_scene
				var lp = sc.get("player") if sc != null else null
				if lp is Node3D and is_instance_valid(lp):
					var ppos: Vector3 = (lp as Node3D).global_position
					var d_sq := Vector2(global_position.x - ppos.x, global_position.z - ppos.z).length_squared()
					far_from_viewer = d_sq > 175.0 * 175.0
					if _visual_root != null and is_instance_valid(_visual_root):
						var want_vis := d_sq < 240.0 * 240.0
						if _visual_root.visible != want_vis:
							_visual_root.visible = want_vis
			if far_from_viewer:
				if _animation_player != null and _animation_player.is_playing():
					_animation_player.pause()
				return
			if _animation_player != null and not _animation_player.is_playing() and not _animation_player.current_animation.is_empty():
				_animation_player.play()
			_update_water_depth(delta)
			if delta > 0.0001 and _network_motion.samples.size() > 1:
				var puppet_moved_xz := Vector2(global_position.x - prev_puppet_pos.x, global_position.z - prev_puppet_pos.z).length()
				var vis_spd := puppet_moved_xz / delta
				if vis_spd > 0.35 and current_anim_keyword in ["idle", "sit", "lie", "eat"]:
					_play_animation_by_name("trot" if vis_spd > move_speed * 1.45 else "walk")
					_update_animation_speed(vis_spd)
				elif vis_spd <= 0.12 and not _puppet_desired_anim.is_empty() and current_anim_keyword != _puppet_desired_anim:
					_play_animation_by_name(_puppet_desired_anim)
		if (animal_type == "wolf" or animal_type == "bear") and not _is_dead:
			_update_wolf_sounds(delta)
		if _is_dead:
			_rot_timer = max(0.0, _rot_timer - delta)
			if _rot_timer <= 0.0:
				_remove_corpse()
			else:
				_update_corpse_flies()
		return
	_wildlife_cache_timer += delta
	if _wildlife_cache_timer >= 1.0:
		_wildlife_cache_timer = 0.0
		_cached_wildlife = get_tree().get_nodes_in_group("wildlife")
	if _is_dead:
		_rot_timer = max(0.0, _rot_timer - delta)
		if _rot_timer <= 0.0:
			_remove_corpse()
		else:
			_update_corpse_flies()
		return
	if patrol_points.size() < 2:
		return
	if _player == null or not is_instance_valid(_player) or _player.is_in_group("net_player_proxy"):
		_resolve_player_timer += delta
		if _resolve_player_timer >= 0.5:
			_resolve_player_timer = 0.0
			_resolve_player()
	# A sheltered/non-targeted client still observes wildlife. Keep motion at
	# full rate near ANY connected observer, not just the AI's chosen target.
	_observer_check_timer -= delta
	if _observer_check_timer <= 0.0:
		_observer_check_timer = 0.5
		_near_network_observer = false
		for observer in get_tree().get_nodes_in_group("net_player_proxy"):
			if observer is Node3D and observer.get_meta("has_real_pos", false) and not observer.get_meta("disconnected", false):
				if global_position.distance_to(observer.global_position) <= AI_LOD_FAR + 10.0:
					_near_network_observer = true
					break
	# ---- LOD de IA por distancia al jugador ----
	var dist_to_player := 0.0
	if not _dedicated_checked:
		_dedicated_checked = true
		var _nm := get_node_or_null("/root/NetworkManager")
		_is_dedicated = _nm != null and _nm.is_dedicated_server
	if not _near_network_observer and _is_dedicated and (_player == null or not is_instance_valid(_player)):
		# Dedicated server with no observer anywhere near: keep the world alive
		# at the far-LOD rate instead of burning a full-rate tick per frame.
		_ai_lod_timer += delta
		_ai_lod_clock += delta
		if _ai_lod_clock < 1.0:
			return
		_ai_lod_clock = fmod(_ai_lod_clock, 1.0)
		delta = _ai_lod_timer
		_ai_lod_timer = 0.0
	elif _player != null and is_instance_valid(_player) and not _near_network_observer:
		dist_to_player = global_position.distance_to(_player.global_position)
		# Animales fuera de rango de cull: solo cuenta rot_timer de cadáver (ya retorna antes si _is_dead)
		if dist_to_player > AI_LOD_CULL and animal_type != "wolf" and animal_type != "bear":
			# Predators keep their territory routes active even far from players.
			return
		# LOD: actualizar IA a frecuencia reducida si están lejos.
		# Acumular el delta mientras esperamos para procesar el tiempo completo
		# al despertar, no solo el delta del frame actual.
		var lod_interval := 0.0
		if _prey_flee_timer <= 0.0:
			if dist_to_player > AI_LOD_MID:
				lod_interval = 1.0
			elif dist_to_player > AI_LOD_NEAR:
				lod_interval = 0.25
		if lod_interval > 0.0:
			_ai_lod_timer += delta
			_ai_lod_clock += delta
			if _ai_lod_clock < lod_interval:
				return
			_ai_lod_clock = fmod(_ai_lod_clock, lod_interval)
			# Procesar con el tiempo acumulado, no solo el frame actual
			delta = _ai_lod_timer
			_ai_lod_timer = 0.0
		else:
			_ai_lod_timer = 0.0
	if _near_network_observer:
		_ai_lod_timer = 0.0
		_ai_lod_clock = 0.0
	# -------------------------------------------
	if _escape_if_trapped(delta):
		return
	_update_stuck_timer(delta)
	_update_water_depth(delta)
	# Salida forzada de un atasco: tiene prioridad sobre la IA normal
	if _unstuck_timer > 0.0:
		_unstuck_timer -= delta
		var burst_speed := move_speed * 1.6
		_play_animation_by_name("trot")
		_move_towards(global_position + _unstuck_dir * 6.0, burst_speed, delta, 8.0)
		_walk_time += delta * burst_speed * 4.8
		_animate_legs(delta)
		_update_animation_speed(burst_speed)
		return
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_chase_cooldown = max(0.0, _chase_cooldown - delta)
	_wolf_ai_debug_timer = max(0.0, _wolf_ai_debug_timer - delta)
	_hit_flash_timer = max(0.0, _hit_flash_timer - delta)
	if animal_type == "wolf" or animal_type == "bear":
		_update_wolf_sounds(delta)
		if animal_type == "bear":
			# Wild bears forage in their territory and never starve to death on their own
			_wolf_hunger = max(15.0, _wolf_hunger - delta * 0.03)
			if _wolf_eating_timer > 0.0 and _player != null and is_instance_valid(_player) and global_position.distance_to(_player.global_position) < 40.0:
				_wolf_eating_timer = 0.0
				_wolf_eating_target = null
		else:
			var drain := 0.15 if _wolf_hunger < 1.0 else 0.035
			var hunger_floor := 0.0
			if not tamed_to.is_empty():
				var own_h := _resolve_owner()
				if own_h != null and bool(own_h.get_meta("disconnected", false)):
					# No dejar morir de inanicion al lobo mientras guarda el cuerpo offline
					hunger_floor = 20.0
				elif _wolf_hunger >= 50.0 and _wolf_foe == null and _threat_player == null and health < max_health:
					health = min(max_health, health + delta * 1.5)
			_wolf_hunger = max(hunger_floor, _wolf_hunger - delta * drain)
		if _wolf_hunger <= 0.0:
			health = max(0.0, health - delta * 5.0)
			if health <= 0.0 and not _is_dead:
				_is_dead = true
				_hit_flash_timer = 2.0
				# Igual que una muerte por daño: sin _rot_timer el cadáver
				# desaparece al frame siguiente en vez de pudrirse 300 s.
				_rot_timer = 300.0
				if _animation_player != null:
					_animation_player.stop()
				_release_owner_record()
				_lie_corpse_flat()
				var scene := get_tree().current_scene
				if scene != null and scene.has_method("_note_wildlife_death"):
					scene._note_wildlife_death(animal_type, global_position)
		if _wolf_eating_timer > 0.0:
			if animal_type == "wolf":
				_play_animation_by_name("eat")
				if is_instance_valid(_wolf_eating_target):
					var toward_food := _wolf_eating_target.global_position - global_position
					toward_food.y = 0.0
					if toward_food.length_squared() > 0.01:
						rotation.y = lerp_angle(rotation.y, atan2(toward_food.x, toward_food.z), minf(1.0, delta * 5.0))
			_wolf_eating_timer -= delta
			var satiation_cap := 60.0 if animal_type == "wolf" else 85.0
			_wolf_hunger = min(satiation_cap, _wolf_hunger + delta * 5.0)
			if not tamed_to.is_empty() and health < max_health:
				health = min(max_health, health + delta * 8.0)
			var is_meat_pickup_target := _wolf_eating_target != null and is_instance_valid(_wolf_eating_target) and ("action_type" in _wolf_eating_target) and _is_meat_action(_wolf_eating_target)
			if (not is_meat_pickup_target and _wolf_hunger >= satiation_cap) or _wolf_eating_timer <= 0.0:
				_wolf_eating_timer = 0.0
				if _wolf_eating_target != null and is_instance_valid(_wolf_eating_target):
					if _wolf_eating_target is WildlifeController:
						_wolf_eating_target._gutted = true
						_wolf_eating_target._spawn_partial_pickups()
						_broadcast_wolf_meat_drops(_wolf_eating_target)
						_wolf_eating_target._remove_corpse()
					elif _wolf_eating_target is BirdController:
						_spawn_partial_bird_pickups(_wolf_eating_target)
						_broadcast_wolf_meat_drops(_wolf_eating_target)
						_wolf_eating_target.queue_free()
					elif _wolf_eating_target.has_meta("proxy_dead") and _wolf_eating_target.get_meta("proxy_dead", false):
						_gut_player_corpse(_wolf_eating_target)
					elif "action_type" in _wolf_eating_target and _is_meat_action(_wolf_eating_target):
						_consume_meat_pickup(_wolf_eating_target)
				_wolf_eating_target = null
			return
	_prey_flee_timer = max(0.0, _prey_flee_timer - delta)
	_flee_stamina = _flee_stamina + delta if _prey_flee_timer > 0.0 else 0.0
	_seek_corpse_timer = max(0.0, _seek_corpse_timer - delta)
	_idle_cooldown = max(0.0, _idle_cooldown - delta)
	# Pausa natural: el animal se detiene brevemente (pastar / vigilar)
	if _idle_timer > 0.0:
		_idle_timer -= delta
		var threatened := _prey_flee_timer > 0.0 or _state != "patrol"
		if threatened:
			_idle_timer = 0.0
		else:
			_play_animation_by_name("idle")
			rotation.y += delta * 0.35 * (1.0 if _speed_jitter > 1.0 else -1.0)
			return
	if _seek_corpse_timer <= 0.0 and _state == "seek_corpse":
		_state = "patrol"
		_chase_stuck_time = 0.0
	var target: Vector3
	var speed: float
	if animal_type == "wolf" or animal_type == "bear":
		var result := _wolf_ai(delta)
		target = result["target"]
		speed = result["speed"]
	else:
		var result := _prey_ai(delta)
		target = result["target"]
		speed = result["speed"]
	# Variación natural: cada animal tiene su propio ritmo y no camina en línea recta
	speed *= _speed_jitter
	var bola_until := float(get_meta("bola_slow_until", 0.0))
	if bola_until > 0.0 and Time.get_unix_time_from_system() < bola_until:
		speed *= 0.25
	if _state == "patrol" and _prey_flee_timer <= 0.0:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(2.5, 5.5)
			var wander_angle := randf_range(0.0, TAU)
			var wander_radius := randf_range(2.0, 6.0)
			_wander_offset = Vector3(cos(wander_angle) * wander_radius, 0.0, sin(wander_angle) * wander_radius)
		target += _wander_offset
	target.x = clamp(target.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
	target.z = clamp(target.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
	# Active chase: the cached path is recomputed every ~1.2s, so waypoints
	# always trail a moving target by several meters. Inside the closing
	# distance steer straight at the live target — and never let the
	# "waypoint reached" early-return below freeze the pursuit inside attack
	# range (prey attack needs <1.5m, unreachable while this cutoff sat at 1.6).
	var chase_live: Node3D = _chase_target if (_chase_target != null and is_instance_valid(_chase_target) and (_state == "chase_prey" or _state == "chase_player" or _state == "fight_wolf")) else null
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() < 1.6 and chase_live == null and _prey_flee_timer <= 0.0 and not (_state in ["follow", "guard", "fight_wolf", "seek_corpse", "flee", "wary", "wary_torch"]):
		target_index = (target_index + 1) % patrol_points.size()
		_current_path.clear()
		_path_index = 0
		_wander_offset = Vector3.ZERO
		_wander_timer = 0.0
		# Pausa ocasional al llegar a un punto de ruta (más natural)
		if _state == "patrol" and _idle_cooldown <= 0.0 and randf() < 0.35:
			_idle_timer = randf_range(1.5, 4.0)
			_idle_cooldown = randf_range(8.0, 18.0)
		return
	if _current_path.is_empty() and speed > 0.0 and to_target.length() > 0.15:
		_path_recalc_timer = 0.0
	_path_recalc_timer -= delta
	if _path_recalc_timer <= 0.0:
		_current_path = _request_path(global_position, target)
		_path_index = 0
		_path_recalc_timer = 0.45 if (_prey_flee_timer > 0.0 or _state in ["flee", "wary", "seek_corpse"]) else 1.2
	var move_target: Vector3 = global_position
	if chase_live != null and global_position.distance_to(chase_live.global_position) < 15.0 and _direct_route_allowed(chase_live.global_position):
		move_target = chase_live.global_position
	elif (_prey_flee_timer > 0.0 or _state == "flee") and (animal_type == "deer" or animal_type == "fox") and _direct_route_allowed(target):
		move_target = target
	elif _house_direct_goal and animal_type == "wolf":
		# Dentro de la casa el interior no es celda de nav: se avanza a paso
		# libre — is_tamed_wolf_allowed_at ya permite el interior con el dueno.
		move_target = target
	elif _current_path.size() > 0 and _path_index < _current_path.size():
		var waypoint: Vector3 = _current_path[_path_index]
		var to_waypoint: Vector3 = waypoint - global_position
		to_waypoint.y = 0.0
		if to_waypoint.length() < 1.5:
			_path_index += 1
			if _path_index < _current_path.size():
				move_target = _current_path[_path_index]
		else:
			move_target = waypoint
	if move_target.distance_to(global_position) < 0.1 and speed > 0.0 and to_target.length() > 0.12:
		if _direct_route_allowed(target) or (to_target.length() < 4.5 and _is_position_allowed(global_position + to_target.normalized() * minf(0.55, to_target.length()))):
			move_target = target
	_route_waiting = move_target.distance_to(global_position) < 0.1 or speed <= 0.0
	if _route_waiting:
		_play_animation_by_name("idle")
	else:
		var turn_spd := 9.0 if (_prey_flee_timer > 0.0 or _state == "flee") else 6.0
		_move_towards(move_target, speed, delta, turn_spd)
	var moved_xz := Vector2(global_position.x - _last_position.x, global_position.z - _last_position.z).length()
	if moved_xz > 0.004:
		if current_anim_keyword in ["idle", "sit", "lie", "eat"]:
			_play_animation_by_name("trot" if speed > move_speed * 1.45 else "walk")
		_walk_time += delta * speed * 4.8
		_animate_legs(delta)
		_update_animation_speed(speed)

func attract_to_noise(pos: Vector3, radius: float) -> void:
	if _is_dead:
		return
	var dist := global_position.distance_to(pos)
	if dist > radius:
		return
	if animal_type == "deer" or animal_type == "fox":
		flee_from_gunshot(pos, minf(radius, 52.0))
		return
	if animal_type == "wolf" or (animal_type == "bear" and not _bear_beyond_territory(pos)):
		_noise_attract_pos = pos
		_noise_attract_timer = 15.0

var _last_gunshot_ms := -1000
var _last_gunshot_origin := Vector3.ZERO

func flee_from_gunshot(pos: Vector3, radius: float) -> void:
	if _is_dead:
		return
	var dist := global_position.distance_to(pos)
	if dist > radius:
		return
	# Keep the escape path through successive rounds from the same vicinity.
	# A different shooter still changes the threat direction immediately.
	var now := Time.get_ticks_msec()
	if now - _last_gunshot_ms < 500 and pos.distance_squared_to(_last_gunshot_origin) < 64.0:
		return
	_last_gunshot_ms = now
	_last_gunshot_origin = pos
	if animal_type == "bear" and dist <= 68.0:
		# A nearby gunshot alerts and angers the bear instead of making it flee
		_prey_flee_timer = 0.0
		_chase_cooldown = 0.0
		_idle_timer = 0.0
		if not _bear_beyond_territory(pos):
			_noise_attract_pos = pos
			_noise_attract_timer = 14.0
		_play_wolf_sound("growl")
		return
	var is_prey := animal_type == "deer" or animal_type == "fox"
	_prey_flee_timer = 11.0 if is_prey else 8.0
	_flee_stamina = 0.0
	_flee_origin = pos
	_chase_cooldown = 10.0
	_chase_target = null
	_idle_timer = 0.0
	_unstuck_timer = 0.0
	_ai_lod_clock = 10.0
	_wander_offset = Vector3.ZERO
	_state = "flee" if is_prey else "patrol"
	_current_path.clear()
	_path_index = 0
	_path_recalc_timer = 0.0
	if is_prey:
		_play_animation_by_name("gallop" if animal_type == "deer" else "run")
		_alert_nearby_herd(pos, 34.0)

func _retreat_from_player() -> Dictionary:
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = Vector3.RIGHT
	_retreat_target = _clamp_flee_goal(global_position, away, 30.0)
	_state = "retreat"
	_chase_target = null
	_chase_cooldown = 10.0
	_chase_stuck_time = 0.0
	_reach_check_timer = 0.0
	_noise_attract_timer = 0.0
	_wait_near_timer = 0.0
	_current_path.clear()
	_path_index = 0
	_path_recalc_timer = 0.0
	if animal_type == "wolf" or animal_type == "bear":
		_play_wolf_sound("growl")
	_play_animation_by_name("trot")
	return {"target": _retreat_target, "speed": move_speed * 2.0}

func _wolf_ai(delta: float) -> Dictionary:
	if _is_dead:
		return {"target": global_position, "speed": 0.0}
	# Suelta la reclamación si el cebo desapareció o el lobo ya va a por otra
	# cosa: así otro animal puede tomar la pieza enseguida.
	if _claimed_meat != null and (not is_instance_valid(_claimed_meat) or _claimed_meat.get("depleted") or (_state != "seek_corpse" and _state != "eating")):
		_claimed_meat = null
	var target: Vector3
	var speed: float = move_speed
	_attack_timer -= delta
	if _noise_attract_timer > 0.0:
		_noise_attract_timer -= delta
	var is_hungry := _wolf_hunger < _wolf_hunger_threshold
	if animal_type == "wolf" and is_hungry and _howl_timer <= 0.0:
		_play_wolf_sound("howl")
		_howl_timer = randf_range(10.0, 20.0)
		if tamed_to.is_empty():
			_rally_pack_on_howl()
	# (Removed: non-hungry wolves flee — now they always attack if player is close)
	# Flee from player when attacked or when gunshot heard nearby.
	# Un lobo domesticado no huye de su amenaza designada: su trabajo es defender.
	# Y ningun lobo abandona un combate canino en curso.
	if _prey_flee_timer > 0.0 and tamed_to == "" and _wolf_foe == null:
		var threat_pos: Vector3 = _flee_origin
		if not threat_pos.is_finite() and _player != null and is_instance_valid(_player):
			threat_pos = _player.global_position
		if not threat_pos.is_finite():
			var np := _find_nearest_proxy()
			if np != null:
				threat_pos = np.global_position
		if threat_pos.is_finite() and global_position.distance_to(threat_pos) < 130.0:
			var away := global_position - threat_pos
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.RIGHT
			target = _clamp_flee_goal(global_position, away, 35.0)
			speed = move_speed * 2.8
			_state = "patrol"
			_chase_target = null
			_chase_cooldown = 10.0
			_play_animation_by_name("run")
			return {"target": target, "speed": speed}
	# Cebo en la mano: un jugador que lleva carne/pescado equipado no es
	# presa — el lobo huele el cebo, lo ronda a distancia y espera a que lo
	# tire al suelo. Si YA hay carne suya tirada, este bloque no interviene:
	# el bloque de alimentación lo manda a comerla directamente.
	var bait_holder := _resolve_bait_holder()
	if animal_type == "wolf" and tamed_to.is_empty() and bait_holder != null:
		var holder_id := _feeder_key(bait_holder)
		var ground_offering := _find_nearest_meat_pickup(holder_id) if (not holder_id.is_empty() and is_hungry) else null
		if ground_offering == null:
			if _state == "chase_player" or _chase_target == bait_holder:
				_chase_target = null
				_chase_stuck_time = 0.0
				_current_path.clear()
				_path_index = 0
				_path_recalc_timer = 0.0
				_chase_cooldown = 3.0
			_state = "wary"
			var bait_dist := global_position.distance_to(bait_holder.global_position)
			if bait_dist > 14.0:
				_play_animation_by_name("walk")
				return {"target": bait_holder.global_position, "speed": move_speed * 1.4}
			var to_holder := bait_holder.global_position - global_position
			to_holder.y = 0.0
			if to_holder.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(to_holder.x, to_holder.z), delta * 4.0)
			if bait_dist < 5.0:
				_play_animation_by_name("walk")
				return {"target": global_position - to_holder.normalized() * 2.5, "speed": move_speed * 0.9}
			if animal_type == "wolf" and randf() < delta * 0.2:
				_play_wolf_sound("growl")
			_play_animation_by_name("idle")
			return {"target": global_position, "speed": 0.0}
	if _state == "retreat":
		if _chase_cooldown > 0.0:
			if global_position.distance_to(_retreat_target) < 1.6:
				_route_waiting = true
				_play_animation_by_name("idle")
				return {"target": global_position, "speed": 0.0}
			_play_animation_by_name("trot")
			return {"target": _retreat_target, "speed": move_speed * 2.0}
		_state = "patrol"
		_path_recalc_timer = 0.0
	# State: wait_near
	if _state == "wait_near" and _wait_near_timer > 0.0:
		_wait_near_timer -= delta
		if _player != null and is_instance_valid(_player):
			var dist_to_player := global_position.distance_to(_player.global_position)
			if dist_to_player < 20.0 and _can_reach_player():
				_chase_stuck_time = 0.0
				_state = "chase_player"
				_chase_target = _player
				speed = move_speed * 2.8
				target = _player.global_position
				_play_animation_by_name("run")
				return {"target": target, "speed": speed}
			var wait_target := _player.global_position
			var to_wait := wait_target - global_position
			to_wait.y = 0.0
			if to_wait.length() > 8.0:
				target = wait_target
				speed = move_speed * 1.2
				_play_animation_by_name("walk")
			else:
				target = global_position
				speed = 0.0
				_play_animation_by_name("idle")
			return {"target": target, "speed": speed}
		else:
			_wait_near_timer = 0.0
	if _wait_near_timer <= 0.0 and _state == "wait_near":
		if _player != null and is_instance_valid(_player):
			var away := (global_position - _player.global_position).normalized()
			away.y = 0.0
			_state = "patrol"
			_chase_stuck_time = 0.0
			if animal_type == "wolf":
				_play_wolf_sound("growl")
			_play_animation_by_name("trot")
			return {"target": _clamp_flee_goal(global_position, away, 30.0), "speed": move_speed * 2.0}
		_state = "patrol"
		_chase_stuck_time = 0.0
		_chase_cooldown = 5.0
	# Combate lobo-vs-lobo: un enemigo canino tiene prioridad sobre todo lo demás
	_foe_timer = max(0.0, _foe_timer - delta)
	# Lobo salvaje: los domesticos son rivales — engancha a uno cercano si anda hostil
	if animal_type == "wolf" and tamed_to.is_empty() and _wolf_foe == null:
		var hostile := is_hungry or _state in ["chase_player", "fight_wolf"] or _threat_player != null
		if hostile:
			for other in _cached_wildlife:
				if other == self or not is_instance_valid(other) or not (other is WildlifeController):
					continue
				var ow := other as WildlifeController
				if ow.animal_type == "wolf" and not ow._is_dead and not ow.tamed_to.is_empty() and global_position.distance_to(ow.global_position) < 14.0:
					_wolf_foe = ow
					_foe_timer = 20.0
					break
	# El lobo domesticado vigila si un lobo salvaje persigue a su dueño
	if tamed_to != "" and _wolf_foe == null and not _orders_cease:
		var owner_for_foe := _resolve_owner()
		if owner_for_foe != null:
			var foe := _find_wolf_threatening(owner_for_foe)
			if foe != null:
				_wolf_foe = foe
				_foe_timer = 20.0
	if not tamed_to.is_empty() and _wolf_foe != null:
		var combat_owner := _resolve_owner()
		if _orders_cease or (is_instance_valid(combat_owner) and is_instance_valid(_wolf_foe) and _wolf_foe.global_position.distance_to(combat_owner.global_position) > 60.0):
			_wolf_foe = null
	if _wolf_foe != null:
		if not is_instance_valid(_wolf_foe) or _wolf_foe.get("_is_dead") or _foe_timer <= 0.0 or global_position.distance_to(_wolf_foe.global_position) > 70.0:
			_wolf_foe = null
		else:
			_state = "fight_wolf"
			_chase_target = _wolf_foe
			return _fight_animal(_wolf_foe, delta)
	_animal_bite_target = null
	# Lobo domesticado: seguir/guardar al dueño o defenderlo de una amenaza
	_threat_timer = max(0.0, _threat_timer - delta)
	if _threat_player != null and (not is_instance_valid(_threat_player) or _threat_timer <= 0.0 or _threat_player.get_meta("proxy_dead", false) or _threat_player.get("is_dead") == true):
		_threat_player = null
	if tamed_to != "":
		var tamed := _tamed_ai(delta)
		if bool(tamed.get("handled", false)):
			return tamed
		# Si no está "handled", _player apunta a la amenaza y sigue la persecución normal
	if animal_type == "wolf" and tamed_to.is_empty() and is_hungry and _prey_flee_timer <= 0.0:
		var offering := _find_active_tame_offering()
		if offering != null:
			if _state == "chase_player":
				_path_recalc_timer = 0.0
			_chase_target = null
			return _seek_meat_pickup(offering)
		# Cebo reclamado o ligado a otro lobo: este ronda la zona esperando
		# su turno en vez de amontonarse encima o atacar al cebador.
		var shadow := _find_shadow_offering()
		if shadow != null:
			var sh_feeder := _find_feeder_node(str(shadow.get_meta("dropped_by")))
			if sh_feeder != null and (_player == null or not is_instance_valid(_player) or _player == sh_feeder):
				_chase_target = null
				return _shadow_offering(shadow, delta)
	if animal_type == "wolf" and tamed_to.is_empty() and _wolf_foe == null:
		var nearby_bear := _find_nearest_live_bear(22.0)
		if nearby_bear != null:
			var away_bear := global_position - nearby_bear.global_position
			away_bear.y = 0.0
			if away_bear.length_squared() < 0.0001:
				away_bear = Vector3.RIGHT
			_state = "patrol"
			_chase_target = null
			_play_animation_by_name("run")
			return {"target": _clamp_flee_goal(global_position, away_bear, 28.0), "speed": move_speed * 2.6}
	# Priority 0: chase player (highest priority)
	if _player != null and is_instance_valid(_player) and _chase_cooldown <= 0.0 and not _player.get_meta("proxy_dead", false) and not _player.get_meta("in_built_shelter", false) and _player.get_meta("protection_timer", 0.0) <= 0.0:
		var dist_to_player := global_position.distance_to(_player.global_position)
		var height_diff := absf(_player.global_position.y - global_position.y)
		var flat_dist := Vector2(global_position.x - _player.global_position.x, global_position.z - _player.global_position.z).length()
		# Skip if player is near a lit campfire or under a roof (house,
		# barn, tent, shelter). The roof check also stops damage through walls,
		# since the attack range test ignores obstacles.
		var scene := get_tree().current_scene
		var out_of_reach := _is_near_lit_campfire(_player.global_position, 10.0)
		if not out_of_reach and scene != null and scene.has_method("_is_pos_wolf_protected") and scene._is_pos_wolf_protected(_player.global_position):
			out_of_reach = true
		if out_of_reach:
			_state = "patrol"
			_chase_target = null
			_bear_warn_timer = 0.0
			_chase_cooldown = 3.0
			if animal_type == "wolf":
				_play_wolf_sound("growl")
			var away := (global_position - _player.global_position).normalized()
			away.y = 0.0
			target = _clamp_flee_goal(global_position, away, 20.0)
			speed = move_speed * 2.0
			_play_animation_by_name("trot")
			return {"target": target, "speed": speed}
		if animal_type == "wolf" and tamed_to.is_empty() and _player_holds_lit_torch(_player) and dist_to_player < 9.5 and health >= max_health * 0.99:
			_state = "wary_torch"
			_chase_target = null
			var to_torch := _player.global_position - global_position
			to_torch.y = 0.0
			if to_torch.length() > 0.01:
				rotation.y = lerp_angle(rotation.y, atan2(to_torch.x, to_torch.z), delta * 4.5)
			if randf() < delta * 0.35:
				_play_wolf_sound("growl")
			if dist_to_player < 6.2:
				var back_dir := -to_torch.normalized() if to_torch.length() > 0.01 else Vector3.RIGHT
				_play_animation_by_name("walk")
				return {"target": _clamp_flee_goal(global_position, back_dir, 8.0), "speed": move_speed * 1.4}
			var side_sign := _get_flank_sign()
			var tangent_torch := Vector3(-to_torch.z, 0.0, to_torch.x).normalized() * side_sign if to_torch.length() > 0.01 else Vector3.RIGHT
			_play_animation_by_name("walk")
			return {"target": global_position + tangent_torch * 3.0, "speed": move_speed * 1.1}
		if _wolf_ai_debug_timer <= 0.0:
			_wolf_ai_debug_timer = 5.0
		var sight_range := _effective_player_sight_range(_player)
		var another_bear_chasing := false
		if animal_type == "bear":
			for node in _cached_wildlife:
				if node == self or not is_instance_valid(node) or not (node is Node3D):
					continue
				if str(node.get("animal_type")) == "bear" and not bool(node.get("_is_dead")) and str(node.get("_state")) == "chase_player" and node.get("_chase_target") == _player:
					if (node as Node3D).global_position.distance_squared_to(_player.global_position) < global_position.distance_squared_to(_player.global_position):
						another_bear_chasing = true
						break
		if animal_type == "bear" and _state == "bear_warn":
			if dist_to_player > 34.0:
				_state = "patrol"
				_chase_target = null
				_bear_warn_timer = 0.0
				_chase_cooldown = 4.0
				_play_animation_by_name("walk")
				return {"target": patrol_points[target_index], "speed": move_speed}
			var warn_decay := delta * (2.2 if ((_player.get("is_sprinting") == true or _player.get_meta("sprinting", false) == true) and dist_to_player < 28.0) else 1.0)
			_bear_warn_timer -= warn_decay
			if dist_to_player > 22.0 and _bear_warn_timer > 0.0 and health >= max_health * 0.99:
				var to_intruder := _player.global_position - global_position
				to_intruder.y = 0.0
				if to_intruder.length() > 0.01:
					rotation.y = lerp_angle(rotation.y, atan2(to_intruder.x, to_intruder.z), delta * 4.0)
				_play_animation_by_name("walk")
				return {"target": _player.global_position, "speed": move_speed * 0.75}
			_bear_warn_timer = 0.0
		var chase_memory_range := _player_chase_memory_range(sight_range)
		if not another_bear_chasing and (dist_to_player < sight_range or (_state == "chase_player" and dist_to_player < chase_memory_range)):
			if animal_type == "bear" and _bear_beyond_territory(_player.global_position):
				return _retreat_from_player()
			if animal_type == "bear" and _state != "chase_player" and _state != "bear_warn" and dist_to_player > 22.0 and health >= max_health * 0.99:
				_state = "bear_warn"
				_bear_warn_timer = 3.5
				_chase_target = _player
				_play_wolf_sound("growl")
				_play_animation_by_name("walk")
				return {"target": _player.global_position, "speed": move_speed * 0.75}
			# If player is elevated (on car/container) and wolf can't reach, give up and leave
			_reach_check_timer -= delta
			if _state != "chase_player" or _reach_check_timer <= 0.0 or height_diff >= 1.8:
				_reach_check_timer = 1.0
				if not _can_reach_player():
					return _retreat_from_player()
				# Keep tracking the player while the route searches along the bank.
				_chase_stuck_time = 0.0
			if _state != "chase_player":
				_play_wolf_sound("growl")
				if animal_type == "wolf" and tamed_to.is_empty():
					_alert_nearby_pack(_player)
			_state = "chase_player"
			_chase_target = _player
			_noise_attract_timer = 0.0
			if dist_to_player < 5.0:
				speed = move_speed * 1.5
			else:
				speed = move_speed * (4.2 if animal_type == "bear" else 4.0)
			if flat_dist <= 4.0 and height_diff < 1.8:
				if _attack_cooldown <= 0.0:
					_attack_cooldown = 2.5
					_attack_timer = randf_range(5.0, 10.0)
					if _player.is_in_group("net_player_proxy"):
						var peer_id: int = _player.get_meta("peer_id", 0)
						var is_disconnected: bool = _player.get_meta("disconnected", false)
						var is_proxy_dead: bool = _player.get_meta("proxy_dead", false)
						if is_proxy_dead:
							pass
						elif is_disconnected and peer_id != 0:
							var hp: float = _player.get_meta("proxy_health", 100.0)
							hp = max(0.0, hp - _predator_player_damage())
							_player.set_meta("proxy_health", hp)
							# saved_health is what a reconnect restores — server-
							# applied damage must land there too.
							_player.set_meta("saved_health", hp)
							if hp <= 0.0:
								_player.set_meta("proxy_dead", true)
								_player.remove_from_group("net_player_proxy")
								_player.add_to_group("interactable")
								var scene_node := get_tree().current_scene
								# The dead character's gear must reach the
								# ground — without the drop it would vanish
								# silently inside the dead record.
								if scene_node != null and scene_node.has_method("_drop_player_loot"):
									scene_node._drop_player_loot(peer_id, _player)
								if scene_node != null and scene_node.has_method("_broadcast_player_death"):
									scene_node._broadcast_player_death(peer_id, _player)
						elif peer_id != 0:
							var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
							if net_node != null and net_node.players.has(peer_id):
								var bite_kind := "%s_bite" % animal_type
								net_node.apply_damage_to_client.rpc_id(peer_id, _predator_player_damage(), bite_kind)
								net_node._broadcast_player_hit(peer_id, bite_kind, _player.global_position)
					elif _player.has_method("apply_damage"):
						_player.apply_damage(_predator_player_damage())
						if _player.has_method("_play_hit_reaction"):
							_player._play_hit_reaction(false)
						var local_net := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
						if local_net != null and local_net.is_host:
							local_net._broadcast_player_hit(local_net.get_my_id(), "%s_bite" % animal_type, _player.global_position)
					if animal_type == "wolf" or animal_type == "bear":
						_play_wolf_sound("attack" if animal_type == "bear" else "bite")
				var away_dir := (global_position - _player.global_position).normalized()
				away_dir.y = 0.0
				if away_dir.length_squared() < 0.0001:
					away_dir = Vector3.RIGHT
				else:
					away_dir = away_dir.normalized()
				if animal_type == "wolf":
					_face_towards(_player.global_position, delta * 7.0)
					var flank_tangent := Vector3(-away_dir.z, 0.0, away_dir.x) * _get_flank_sign()
					target = _player.global_position + (away_dir * 2.4 + flank_tangent * 1.6)
					speed = move_speed * 1.35
					_play_animation_by_name("attack" if flat_dist <= 4.2 else "trot")
				else:
					_face_towards(_player.global_position, delta * 6.0)
					_play_animation_by_name("attack" if flat_dist <= 2.8 else ("walk" if flat_dist <= 2.8 else "run"))
					target = _player.global_position + away_dir * 2.2
					speed = move_speed * 0.65 if flat_dist > 2.4 else 0.0
				_chase_stuck_time = 0.0
			else:
				_play_animation_by_name("run")
				target = _player.global_position
				if animal_type == "wolf" and dist_to_player > 5.0 and dist_to_player < 18.0 and _pack_mate_also_chasing(_player):
					var to_p := (_player.global_position - global_position)
					to_p.y = 0.0
					if to_p.length() > 0.1:
						var n_to_p := to_p.normalized()
						var lat := Vector3(-n_to_p.z, 0.0, n_to_p.x) * _get_flank_sign()
						var pincer_offset := clampf((dist_to_player - 4.0) * 0.35, 1.6, 3.8)
						target += lat * pincer_offset
			var sep := _compute_wolf_separation(3.5)
			if sep.length() > 0.01:
				target += sep
			return {"target": target, "speed": speed}
	# Priority 1: eat nearby corpse when hungry (lower priority than chasing player)
	if is_hungry:
		var corpse := _find_nearest_corpse()
		if corpse != null:
			var dist_to_corpse := global_position.distance_to(corpse.global_position)
			if dist_to_corpse < 2.0:
				_wolf_eating_timer = 8.0
				_wolf_eating_target = corpse
				_state = "eating"
				target = global_position
				speed = 0.0
				_play_animation_by_name("idle")
				return {"target": target, "speed": speed}
			elif dist_to_corpse < 30.0:
				_state = "seek_corpse"
				_seek_corpse_timer = 15.0
				target = corpse.global_position
				speed = move_speed * 2.0
				_play_animation_by_name("trot")
				return {"target": target, "speed": speed}
	# Priority 1.5: detect gutted meat pickups from far away (60m, wolves only so bears don't pack-converge)
	if is_hungry and animal_type == "wolf":
		var meat := _find_nearest_meat_pickup()
		if meat != null and global_position.distance_to(meat.global_position) < 60.0:
			return _seek_meat_pickup(meat)
	# Priority 2: investigate noise (only when hungry)
	if is_hungry and _noise_attract_timer > 0.0:
		_state = "investigate"
		_chase_target = null
		var dist_to_noise := global_position.distance_to(_noise_attract_pos)
		if dist_to_noise > 2.0:
			target = _noise_attract_pos
			speed = move_speed * 2.0
			_play_animation_by_name("trot")
		else:
			_noise_attract_timer = 0.0
			target = patrol_points[target_index]
			speed = move_speed * 1.0
			_play_animation_by_name("walk")
		return {"target": target, "speed": speed}
	# Recelo: quien le dio de comer deja de ser presa; el lobo lo observa
	# manteniendo distancia (~8 m) en vez de atacar — la señal de progreso.
	if not _tame_progress.is_empty():
		var feeder := _nearest_feeder_in_range(14.0)
		if feeder != null:
			_state = "wary"
			var to_feeder := feeder.global_position - global_position
			to_feeder.y = 0.0
			var fd := to_feeder.length()
			if fd > 9.0:
				_play_animation_by_name("walk")
				return {"target": feeder.global_position - to_feeder.normalized() * 8.0, "speed": move_speed * 1.2}
			if fd < 5.0:
				_play_animation_by_name("walk")
				return {"target": global_position - to_feeder.normalized() * 3.0, "speed": move_speed}
			rotation.y = lerp_angle(rotation.y, atan2(to_feeder.x, to_feeder.z), delta * 3.0)
			_play_animation_by_name("idle")
			return {"target": global_position, "speed": 0.0}
	# Priority 3: hunt nearby prey when hungry (wolves hunt deer/fox; bears hunt wolf/deer/fox)
	if is_hungry:
		var nearest_prey := _find_nearest_prey()
		if nearest_prey != null and is_instance_valid(nearest_prey):
			var dist_to_prey := global_position.distance_to(nearest_prey.global_position)
			if dist_to_prey < 45.0:
				_state = "chase_prey"
				_chase_target = nearest_prey
				target = nearest_prey.global_position
				speed = move_speed * 2.8
				var hit_range := 2.2 if animal_type == "bear" else 1.5
				if dist_to_prey < hit_range:
					if _attack_cooldown <= 0.0:
						_attack_cooldown = 2.8 if animal_type == "bear" else 5.0
						nearest_prey.take_damage(60.0 if animal_type == "bear" else 15.0, false, self)
						if animal_type == "wolf" or animal_type == "bear":
							_play_wolf_sound("attack")
					_play_animation_by_name("attack" if animal_type == "wolf" else "run")
				else:
					_play_animation_by_name("trot")
				return {"target": target, "speed": speed}
	# Default: peaceful patrol
	_state = "patrol"
	_chase_target = null
	target = patrol_points[target_index]
	speed = move_speed * 1.0
	_play_animation_by_name("walk")
	return {"target": target, "speed": speed}

func _another_bear_targeting_carrion(carrion: Node3D) -> bool:
	for node in _cached_wildlife:
		if node == self or not is_instance_valid(node) or not (node is Node3D):
			continue
		if str(node.get("animal_type")) == "bear" and not bool(node.get("_is_dead")):
			if node.get("_wolf_eating_target") == carrion or node.get("_chase_target") == carrion:
				return true
	return false

func _find_nearest_corpse() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist_sq := 9999.0 * 9999.0
	var home_anchor: Vector3 = patrol_points[0] if not patrol_points.is_empty() else global_position
	for node in _cached_wildlife:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node == self or not (node is Node3D):
			continue
		var other := node as Node3D
		if not other.get("_is_dead") or other.get("_gutted"):
			continue
		if animal_type == "bear":
			if home_anchor.distance_squared_to(other.global_position) > 85.0 * 85.0:
				continue
			if _another_bear_targeting_carrion(other):
				continue
		var d_sq := global_position.distance_squared_to(other.global_position)
		if d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			nearest = other
	if nearest == null:
		for p in get_tree().get_nodes_in_group("net_player_proxy"):
			if p is Node3D and p.get_meta("proxy_dead", false) and not p.get_meta("gutted", false):
				if animal_type == "bear" and (home_anchor.distance_squared_to((p as Node3D).global_position) > 85.0 * 85.0 or _another_bear_targeting_carrion(p as Node3D)):
					continue
				var d_sq := global_position.distance_squared_to((p as Node3D).global_position)
				if d_sq < nearest_dist_sq:
					nearest_dist_sq = d_sq
					nearest = p as Node3D
	# Search for gutted meat pickups / carrion on the ground
	var meat := _find_nearest_meat_pickup()
	if meat != null:
		if animal_type != "bear" or (home_anchor.distance_squared_to(meat.global_position) <= 85.0 * 85.0 and not _another_bear_targeting_carrion(meat)):
			var d_sq := global_position.distance_squared_to(meat.global_position)
			if d_sq < nearest_dist_sq:
				nearest_dist_sq = d_sq
				nearest = meat
	return nearest

func _find_nearest_proxy() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist_sq := 99999.0 * 99999.0
	for p in get_tree().get_nodes_in_group("net_player_proxy"):
		if not is_instance_valid(p) or not (p is Node3D):
			continue
		if p.get_meta("proxy_dead", false):
			continue
		var d_sq: float = global_position.distance_squared_to((p as Node3D).global_position)
		if d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			nearest = p as Node3D
	# Also check "Player" node on non-server scenes
	if nearest == null:
		var scene := get_tree().current_scene
		if scene != null:
			var player_node := scene.get_node_or_null("Player")
			if player_node != null and is_instance_valid(player_node) and not player_node.get("is_dead"):
				nearest = player_node
	return nearest

func _find_nearest_prey() -> Node3D:
	var nearest: Node3D = null
	var nearest_dist_sq := 9999.0 * 9999.0
	var home_anchor: Vector3 = patrol_points[0] if not patrol_points.is_empty() else global_position
	for node in _cached_wildlife:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node == self or not (node is Node3D):
			continue
		var other := node as Node3D
		if other.get("_is_dead"):
			continue
		var at = other.get("animal_type")
		if at == null:
			continue
		var ats := str(at)
		if animal_type == "bear":
			# Bears can hunt wolves, foxes and deer inside their forest territory,
			# skipping tamed wolves and other bears.
			if ats != "wolf" and ats != "deer" and ats != "fox":
				continue

			if home_anchor.distance_squared_to(other.global_position) > 85.0 * 85.0:
				continue
		else:
			if ats != "deer" and ats != "fox":
				continue
		var d_sq := global_position.distance_squared_to(other.global_position)
		if d_sq < nearest_dist_sq:
			nearest_dist_sq = d_sq
			nearest = other
	return nearest

func _predator_player_damage() -> float:
	return 35.0 if animal_type == "bear" else 25.0

func _effective_player_sight_range(p: Node3D) -> float:
	# Predators should react at a readable distance, not acquire a player from
	# across a clearing. Bears still notice farther away than wolves.
	var base := 50.0 if animal_type == "bear" else 36.0
	if p == null or not is_instance_valid(p):
		return base
	var is_prone_flag: bool = (p.get("is_prone") == true) or (p.get_meta("prone", false) == true)
	if is_prone_flag:
		return base * 0.35
	var is_crouch_flag: bool = (p.get("is_crouching") == true) or (p.get_meta("crouching", false) == true)
	if is_crouch_flag:
		return base * 0.55
	var is_sprint_flag: bool = (p.get("is_sprinting") == true) or (p.get_meta("sprinting", false) == true)
	if is_sprint_flag:
		return base * 1.25
	return base

func _player_chase_memory_range(sight_range: float) -> float:
	# Once it has spotted a target, a predator should lose interest shortly
	# after it leaves sight instead of tracking it for half the map.
	return minf(sight_range * 1.35, 70.0)

func _player_holds_lit_torch(p: Node) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	if p.get_meta("torch_lit", false) == true:
		return true
	if p.get("_torch_lit") == true:
		return true
	return false

func _find_nearest_live_bear(max_dist: float) -> Node3D:
	var best: Node3D = null
	var best_sq := max_dist * max_dist
	for node in _cached_wildlife:
		if node == self or not is_instance_valid(node) or not (node is Node3D):
			continue
		if str(node.get("animal_type")) != "bear" or bool(node.get("_is_dead")):
			continue
		var d_sq := global_position.distance_squared_to((node as Node3D).global_position)
		if d_sq < best_sq:
			best_sq = d_sq
			best = node as Node3D
	return best

func _bear_beyond_territory(target_pos: Vector3) -> bool:
	if patrol_points.is_empty():
		return false
	var home: Vector3 = patrol_points[0]
	var max_leash := 115.0 if health >= max_health * 0.99 else 160.0
	return Vector2(target_pos.x - home.x, target_pos.z - home.z).length_squared() > max_leash * max_leash

func _alert_nearby_pack(target_node: Node3D) -> void:
	if target_node == null or not is_instance_valid(target_node):
		return
	for node in _cached_wildlife:
		if node == self or not is_instance_valid(node) or not (node is WildlifeController):
			continue
		var mate := node as WildlifeController
		if mate.is_puppet or mate.animal_type != "wolf" or mate._is_dead or not mate.tamed_to.is_empty():
			continue
		if mate._chase_cooldown > 0.0 or mate._prey_flee_timer > 0.0:
			continue
		var d := global_position.distance_to(mate.global_position)
		if d <= 55.0 and (mate._state == "patrol" or mate._state == "investigate"):
			mate._noise_attract_pos = target_node.global_position
			mate._noise_attract_timer = maxf(mate._noise_attract_timer, 12.0)
			if mate.global_position.distance_to(target_node.global_position) < 75.0:
				mate._player = target_node
				mate._state = "chase_player"
				mate._chase_target = target_node

func _pack_mate_also_chasing(target_node: Node3D) -> bool:
	for node in _cached_wildlife:
		if node == self or not is_instance_valid(node) or not (node is WildlifeController):
			continue
		var mate := node as WildlifeController
		if mate.animal_type == "wolf" and not mate._is_dead and mate._state == "chase_player" and mate._chase_target == target_node:
			return true
	return false

func _get_flank_sign() -> float:
	if _flank_sign == 0.0:
		_flank_sign = 1.0 if (get_instance_id() % 2 == 0) else -1.0
	return _flank_sign

# Un objetivo de huida fuera del mapa se recorta a +/-GameConst.WORLD_LIMIT y el animal se queda
# clavado contra el límite. Si el destino sale del área jugable, se gira la
# dirección de huida hacia el interior manteniendo la distancia.
func _clamp_flee_goal(from: Vector3, away: Vector3, dist: float) -> Vector3:
	var limit := GameConst.WORLD_LIMIT - 4.0
	var limit_z := GameConst.WORLD_LIMIT_Z - 4.0
	var goal := from + away.normalized() * dist
	if abs(goal.x) <= limit and goal.z > -limit and goal.z < limit_z:
		return goal
	var inward := (Vector3(0.0, 0.0, 0.0) - from)
	inward.y = 0.0
	if inward.length() < 0.01:
		inward = Vector3.RIGHT
	inward = inward.normalized()
	# Componente tangencial: huir bordeando el límite en vez de contra él
	var tangent := Vector3(-inward.z, 0.0, inward.x)
	if tangent.dot(away) < 0.0:
		tangent = -tangent
	for blend in [0.35, 0.6, 0.85, 1.0]:
		var dir: Vector3 = (tangent * (1.0 - blend) + inward * blend).normalized()
		var candidate := from + dir * dist
		if abs(candidate.x) <= limit and candidate.z > -limit and candidate.z < limit_z:
			return candidate
	return Vector3(clamp(goal.x, -limit, limit), goal.y, clamp(goal.z, -limit, limit_z))

func _rally_pack_on_howl() -> void:
	for node in _cached_wildlife:
		if node == self or not is_instance_valid(node) or not (node is WildlifeController):
			continue
		var mate := node as WildlifeController
		if mate.is_puppet or mate.animal_type != "wolf" or mate._is_dead or not mate.tamed_to.is_empty():
			continue
		if mate._state == "patrol" and mate._prey_flee_timer <= 0.0 and global_position.distance_to(mate.global_position) <= 48.0:
			mate._noise_attract_pos = global_position
			mate._noise_attract_timer = maxf(mate._noise_attract_timer, 10.0)

func _alert_nearby_herd(threat_pos: Vector3, radius: float = 36.0) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	var origin_pos := threat_pos if threat_pos.is_finite() else global_position
	var list: Array = _cached_wildlife if not _cached_wildlife.is_empty() else get_tree().get_nodes_in_group("wildlife")
	for node in list:
		if node == self or not is_instance_valid(node) or not (node is WildlifeController):
			continue
		var other := node as WildlifeController
		if other.is_puppet or other._is_dead or (other.animal_type != "deer" and other.animal_type != "fox"):
			continue
		if global_position.distance_to(other.global_position) <= radius:
			other._prey_flee_timer = maxf(other._prey_flee_timer, 9.5)
			other._flee_stamina = 0.0
			other._flee_origin = origin_pos
			other._idle_timer = 0.0
			other._unstuck_timer = 0.0
			other._ai_lod_clock = 10.0
			other._wander_offset = Vector3.ZERO
			if other._state != "flee":
				other._state = "flee"
				other._current_path.clear()
				other._path_index = 0
				other._path_recalc_timer = 0.0
				other._play_animation_by_name("gallop" if other.animal_type == "deer" else "run")

func _effective_prey_alert_range(p: Node3D) -> float:
	var base := _flee_distance()
	if p == null or not is_instance_valid(p):
		return base
	var is_prone_flag: bool = (p.get("is_prone") == true) or (p.get_meta("prone", false) == true)
	if is_prone_flag:
		return 7.5 if animal_type == "deer" else 8.5
	var is_crouch_flag: bool = (p.get("is_crouching") == true) or (p.get_meta("crouching", false) == true)
	if is_crouch_flag:
		return 12.0 if animal_type == "deer" else 13.0
	var is_sprint_flag: bool = (p.get("is_sprinting") == true) or (p.get_meta("sprinting", false) == true)
	if is_sprint_flag:
		return 38.0 if animal_type == "deer" else 34.0
	var is_moving_flag: bool = (p.get("is_moving") == true) or (p.get_meta("moving", false) == true)
	if not is_moving_flag and ("velocity" in p):
		var vel: Vector3 = p.get("velocity")
		is_moving_flag = Vector2(vel.x, vel.z).length() > 0.35
	if is_moving_flag:
		return 26.0 if animal_type == "deer" else 24.0
	return base

func _prey_run_anim() -> String:
	if animal_type == "deer":
		return "gallop" if (_flee_stamina < 6.0 or _prey_flee_timer > 4.5) else "run"
	return "run"

func _apply_fox_zigzag(away: Vector3) -> Vector3:
	if animal_type != "fox":
		return away
	var n := away.normalized()
	var tang := Vector3(-n.z, 0.0, n.x)
	var phase := _flee_stamina * 4.5 + float(get_instance_id() % 17)
	return (n + tang * sin(phase) * 0.32).normalized()

func _prey_ai(delta: float) -> Dictionary:
	var target: Vector3
	var speed: float = move_speed
	# Sprint completo solo los primeros ~10s de huida; luego la presa se agota
	# y el lobo puede alcanzarla (caza realista: la presa es más rápida al
	# arrancar, el depredador más resistente en distancia).
	var fatigue := lerpf(1.0, 0.55, clampf((_flee_stamina - 10.0) / 6.0, 0.0, 1.0))
	var predator_flee_speed := move_speed * (2.4 if animal_type == "fox" else 2.6) * fatigue
	var panic_flee_speed := move_speed * (2.85 if animal_type == "fox" else 3.15) * lerpf(1.0, 0.65, clampf((_flee_stamina - 10.0) / 6.0, 0.0, 1.0))
	# Flee from wolves and bears (larger distance if already fleeing)
	var nearest_predator := _find_nearest_animal("wolf")
	var nearest_bear := _find_nearest_animal("bear")
	if nearest_bear != null and is_instance_valid(nearest_bear) and (nearest_predator == null or global_position.distance_squared_to(nearest_bear.global_position) < global_position.distance_squared_to(nearest_predator.global_position)):
		nearest_predator = nearest_bear
	if nearest_predator != null and is_instance_valid(nearest_predator):
		var dist_to_predator := global_position.distance_to(nearest_predator.global_position)
		var predator_flee_dist := 28.0 if nearest_predator.get("animal_type") == "bear" else 18.0
		if _prey_flee_timer > 0.0:
			predator_flee_dist += 7.0
		if dist_to_predator < predator_flee_dist:
			var away := global_position - nearest_predator.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.RIGHT
			away = _apply_fox_zigzag(away)
			if _state != "flee":
				_state = "flee"
				_current_path.clear()
				_path_index = 0
				_path_recalc_timer = 0.0
			target = _clamp_flee_goal(global_position, away, 25.0)
			speed = predator_flee_speed
			_prey_flee_timer = maxf(_prey_flee_timer, 5.0)
			_play_animation_by_name(_prey_run_anim())
			return {"target": target, "speed": speed}
	# Gunshot or damage panic: flee directly away from the gunshot/threat origin
	# even when the shooter is far beyond normal proximity detection.
	if _prey_flee_timer > 0.0 and _flee_origin.is_finite():
		var away_shot := global_position - _flee_origin
		away_shot.y = 0.0
		if away_shot.length() < 0.01:
			away_shot = Vector3.RIGHT
		away_shot = _apply_fox_zigzag(away_shot)
		_state = "flee"
		target = _clamp_flee_goal(global_position, away_shot, 38.0)
		speed = panic_flee_speed
		_play_animation_by_name(_prey_run_anim())
		return {"target": target, "speed": speed}
	# Flee from player (hearing footsteps/sprint or spotting player)
	var flee_from: Node3D = _player
	if flee_from == null or not is_instance_valid(flee_from):
		if _prey_flee_timer > 0.0:
			flee_from = _find_nearest_proxy()
	if flee_from != null and is_instance_valid(flee_from):
		var dist_to_player := global_position.distance_to(flee_from.global_position)
		var alert_dist := _effective_prey_alert_range(flee_from)
		var player_flee_dist := alert_dist + 12.0 if _prey_flee_timer > 0.0 else alert_dist
		if dist_to_player < player_flee_dist:
			var away := global_position - flee_from.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3.RIGHT
			away = _apply_fox_zigzag(away)
			if _state != "flee":
				_state = "flee"
				_current_path.clear()
				_path_index = 0
				_path_recalc_timer = 0.0
				_idle_timer = 0.0
				if animal_type == "deer":
					_alert_nearby_herd(flee_from.global_position, 32.0)
			_flee_origin = flee_from.global_position
			target = _clamp_flee_goal(global_position, away, 28.0)
			speed = panic_flee_speed
			_prey_flee_timer = maxf(_prey_flee_timer, 5.5)
			_play_animation_by_name(_prey_run_anim())
			return {"target": target, "speed": speed}
	# Flee timer active but no threat nearby — run away from current position
	if _prey_flee_timer > 0.0:
		var flee_dir: Vector3 = (global_position - Vector3(patrol_points[target_index])).normalized()
		flee_dir.y = 0.0
		if flee_dir.length() < 0.01:
			flee_dir = Vector3.RIGHT
		flee_dir = _apply_fox_zigzag(flee_dir)
		_state = "flee"
		target = _clamp_flee_goal(global_position, flee_dir, 28.0)
		speed = panic_flee_speed
		_play_animation_by_name(_prey_run_anim())
		return {"target": target, "speed": speed}
	# Opportunistic fox scavenging: when calm, foxes trot toward unclaimed wild carrion
	if animal_type == "fox":
		var scrap := _find_nearest_meat_pickup()
		if scrap != null and not scrap.has_meta("dropped_by") and global_position.distance_to(scrap.global_position) < 20.0:
			var d_scrap := _flat_distance_to(scrap.global_position)
			if d_scrap < 1.8:
				_consume_meat_pickup(scrap)
				_play_animation_by_name("idle")
				return {"target": global_position, "speed": 0.0}
			_state = "patrol"
			_play_animation_by_name("trot")
			return {"target": scrap.global_position, "speed": move_speed * 1.65}
	_state = "patrol"
	_flee_origin = Vector3.INF
	target = patrol_points[target_index]
	speed = move_speed * 1.0
	_play_animation_by_name("walk")
	return {"target": target, "speed": speed}

func _lie_corpse_flat() -> void:
	if not is_instance_valid(_visual_root):
		return
	if _animation_player != null:
		_animation_player.stop()
	# Reset skeleton to rest pose
	var skel := _find_skeleton(_visual_root)
	if skel != null:
		skel.reset_bone_poses()
	# Rotate the entire node -90 on Z to lie on its side (not on its back),
	# preserving its elevation so rooftop/tower/hill kills stay reachable.
	var current_y_rad := rotation.y
	var basis := Basis.from_euler(Vector3(0.0, current_y_rad, deg_to_rad(-90.0)))
	var corpse_y := maxf(global_position.y, 0.1)
	global_transform = Transform3D(basis, Vector3(global_position.x, corpse_y, global_position.z))
	_visual_root.position = Vector3.ZERO
	_visual_root.rotation_degrees = Vector3.ZERO
	# Add collision body so the player can interact with the corpse
	_corpse_body = StaticBody3D.new()
	_corpse_body.name = "CorpseBody"
	_corpse_body.collision_layer = 2
	_corpse_body.collision_mask = 0
	_corpse_body.add_to_group("prop_collision")
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 0.4, 2.0)
	col_shape.shape = box
	_corpse_body.add_child(col_shape)
	add_child(_corpse_body)
	# Make interactable
	add_to_group("interactable")

func _animal_name() -> String:
	match animal_type:
		"wolf": return "lobo"
		"deer": return "ciervo"
		"fox": return "zorro"
		"bear": return "oso"
		_: return "animal"

func _animal_name_cap() -> String:
	match animal_type:
		"wolf": return "Lobo"
		"deer": return "Ciervo"
		"fox": return "Zorro"
		"bear": return "Oso"
		_: return "Animal"

func _meat_name() -> String:
	match animal_type:
		"wolf": return "Carne cruda de lobo"
		"deer": return "Carne cruda de ciervo"
		"fox": return "Carne cruda de zorro"
		"bear": return "Carne cruda de oso"
		_: return "Carne cruda"

func _meat_count() -> int:
	match animal_type:
		"wolf": return 4
		"deer": return 8
		"fox": return 3
		"bear": return 12
		_: return 4

func _hide_name() -> String:
	match animal_type:
		"wolf": return "Piel de lobo"
		"deer": return "Piel de ciervo"
		"fox": return "Piel de zorro"
		"bear": return "Piel de oso"
		"bird": return "Piel de ave"
		_: return "Piel animal"

func _hide_count() -> int:
	match animal_type:
		"deer": return 2
		"bear": return 4
		_: return 1

func _leftover_meat_count() -> int:
	match animal_type:
		"wolf": return 1
		"deer": return 3
		"fox": return 1
		"bear": return 3
		_: return 1

func _corpse_item_name() -> String:
	match animal_type:
		"wolf": return "Lobo muerto"
		"deer": return "Ciervo muerto"
		"fox": return "Zorro muerto"
		"bear": return "Oso muerto"
		_: return "Animal muerto"

func _tamed_status_text() -> String:
	var parts := PackedStringArray()
	var hp_pct := int(round(health / maxf(max_health, 1.0) * 100.0))
	parts.append("Vida %d%%" % hp_pct)
	var sat_pct := int(round(clampf(_wolf_hunger / 100.0, 0.0, 1.0) * 100.0))
	parts.append("Saciedad %d%%" % sat_pct)
	var state_text := ""
	if health < max_health * 0.5:
		state_text = "herido"
	elif _wolf_hunger < _wolf_hunger_threshold:
		state_text = "hambriento"
	elif _wolf_eating_timer > 0.0:
		state_text = "comiendo"
	elif _wolf_foe != null or _threat_player != null:
		state_text = "defendiendo"
	elif _ordered_prey != null:
		state_text = "cazando"
	elif _orders_cease:
		state_text = "sin atacar"
	elif _follow_mode == "patrol":
		state_text = "patrullando"
	elif _follow_mode == "stay":
		state_text = "quieto"
	if not state_text.is_empty():
		parts.append(state_text.capitalize())
	return "(" + ", ".join(parts) + ")"

func get_interaction_text(player = null) -> String:
	if not _is_dead:
		if animal_type == "wolf" and tamed_to != "":
			var status := _tamed_status_text()
			if _is_owner_actor(player):
				return "Lobo domesticado %s - [F] Ordenes" % status
			return "Lobo domesticado %s" % status
		if animal_type == "wolf" and tamed_to.is_empty() and player != null:
			var fkey := _feeder_key(player)
			var prog := int(_tame_progress.get(fkey, 0)) if not fkey.is_empty() else 0
			if prog > 0:
				return "Lobo receloso (%d/%d comidas) - Suelta carne para domarlo" % [mini(prog, TAME_FEEDINGS), TAME_FEEDINGS]
			if _player_holds_meat(player):
				return "Lobo salvaje - Suelta la carne en el suelo para domarlo (0/%d)" % TAME_FEEDINGS
		return ""
	var an := _animal_name()
	var an_cap := _animal_name_cap()
	if _gutted:
		return "[F] %s vacio" % an_cap
	var has_knife := _player_has_knife(player)
	if has_knife:
		return "[F] Destripar %s  |  [C] Coger %s entero (necesitas mochila)" % [an, an]
	return "[C] Coger %s entero (necesitas mochila)  |  [F] Destripar (necesitas cuchillo/hacha)" % an

func interact(player: Node) -> void:
	if not _is_dead:
		if animal_type == "wolf" and tamed_to != "":
			_interact_tamed(player)
		return
	var an := _animal_name()
	if _gutted:
		if player != null and player.has_signal("notice"):
			player.notice.emit("El %s ya esta vacio." % an)
		return
	var has_knife := _player_has_knife(player)
	if not has_knife:
		if player != null and player.has_signal("notice"):
			player.notice.emit("Necesitas un cuchillo o hacha para destripar.")
		return
	# Puppet: notify server to gut and sync drops to all clients (server spawns meat)
	if is_puppet:
		_gutted = true
		_rot_timer = 5.1
		if player != null and player.has_method("play_action_animation"):
			player.play_action_animation("plant", 5.0)
		if player != null and player.has_signal("notice"):
			player.notice.emit("Destripando al %s..." % an)
		# Notify server to remove animal and sync to other clients
		var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
		if net_node != null:
			net_node.gut_animal.rpc_id(1, name, false)
		# Server will spawn meat and sync via animal_gutted RPC — just remove puppet after animation
		var player_ref: Node = player
		var an_ref := an
		var meat_qty := _meat_count()
		var timer := Timer.new()
		timer.wait_time = 5.0
		timer.one_shot = true
		timer.timeout.connect(func():
			if player_ref != null and is_instance_valid(player_ref) and player_ref.has_signal("notice"):
				player_ref.notice.emit("Destripar al %s: +%d carne cruda, piel, huesos y tendones." % [an_ref, meat_qty])
			_remove_corpse()
		)
		add_child(timer)
		timer.start()
		return
	# Server/local: gut directly
	_gutted = true
	_rot_timer = 5.1
	if player != null and player.has_method("play_action_animation"):
		player.play_action_animation("plant", 5.0)
	if player != null and player.has_signal("notice"):
		player.notice.emit("Destripando al %s..." % an)
	# Spawn meat and remove corpse after the 5-second animation finishes
	var player_ref: Node = player
	var an_ref := an
	var meat_qty := _meat_count()
	var timer := Timer.new()
	timer.wait_time = 5.0
	timer.one_shot = true
	timer.timeout.connect(func():
		_spawn_gut_pickups()
		if player_ref != null and is_instance_valid(player_ref) and player_ref.has_signal("notice"):
			player_ref.notice.emit("Destripar al %s: +%d carne cruda, piel, huesos y tendones." % [an_ref, meat_qty])
		_remove_corpse()
	)
	add_child(timer)
	timer.start()

func collect(player: Node) -> void:
	if not _is_dead:
		return
	var an := _animal_name()
	var corpse_name := _corpse_item_name()
	if _gutted:
		if player != null and player.has_signal("notice"):
			player.notice.emit("El %s ya esta vacio, no hay nada que coger." % an)
		return
	# Need backpack to carry a whole animal
	if not _player_has_backpack(player):
		if player != null and player.has_signal("notice"):
			player.notice.emit("Necesitas una mochila para cargar el %s entero." % an)
		return
	var inventory = player.get("inventory") if player != null else null
	if inventory == null or not inventory.has_method("add_item"):
		return
	var ItemScript = load("res://scripts/Item.gd")
	var whole_animal = ItemScript.create(corpse_name, "material", 8.0, 1, 0.0)
	if player != null and player.get("equipped_backpack") != null and not str(player.get("equipped_backpack")).is_empty():
		whole_animal.cargo_location = "backpack"
	var added: bool = inventory.add_item(whole_animal)
	if added:
		if player != null and player.has_signal("notice"):
			player.notice.emit("Coges el %s entero." % an)
		# For puppets, notify server to remove the animal. Tombstone the id
		# locally too — a sync packet already in flight would otherwise
		# recreate the dead puppet while the server still lists it.
		if is_puppet:
			var scene := get_tree().current_scene
			if scene != null and "_collected_animal_tombstones" in scene:
				scene._collected_animal_tombstones[name.replacen("Puppet_", "")] = Time.get_ticks_msec()
			var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
			if net_node != null:
				net_node.gut_animal.rpc_id(1, name, true)
		_remove_corpse()
	else:
		if player != null and player.has_signal("notice"):
			player.notice.emit("No puedes cargar con el %s, demasiado peso." % an)

func _player_has_knife(player: Node) -> bool:
	if player == null:
		return false
	var inventory = player.get("inventory")
	if inventory == null or not ("items" in inventory):
		return false
	for item in inventory.items:
		if item != null and (item.item_type in ["weapon", "tool_axe"] or item.item_name in ["Hacha", "Hacha de piedra", "Piedra afilada"]) and not (item.has_method("is_broken") and item.is_broken()):
			return true
	return false

func _bone_count() -> int:
	match animal_type:
		"bear": return 3
		"deer": return 2
		"fox": return 1
		_: return 2

func _sinew_count() -> int:
	match animal_type:
		"bear", "deer": return 2
		_: return 1

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
	var base_pos := global_position
	var meat := _meat_name()
	var meat_qty := _meat_count()
	var meat_weight := 0.3
	var meat_use_value := 15.0
	var drop_y := maxf(base_pos.y - 0.04, 0.06)
	# Spawn meat pieces scattered around the corpse
	for i in range(meat_qty):
		var angle := TAU * float(i) / float(meat_qty) + randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle) * randf_range(0.4, 0.9), 0.0, sin(angle) * randf_range(0.4, 0.9))
		var pos := base_pos + offset
		pos.y = drop_y
		var drop_id := "gut_meat_%d_%d" % [Time.get_ticks_msec(), i]
		if scene.has_method("_spawn_ground_pickup"):
			scene.call("_spawn_ground_pickup", meat, "food", pos, meat_weight, 1, meat_use_value, drop_id, "wolf_meat_raw")
	var hide_pos := base_pos + Vector3(0.15, 0.0, -0.2)
	hide_pos.y = drop_y
	if scene.has_method("_spawn_ground_pickup"):
		scene.call("_spawn_ground_pickup", _hide_name(), "resource", hide_pos, 0.65, _hide_count(), 0.0, "gut_hide_%d" % Time.get_ticks_msec())
		scene.call("_spawn_ground_pickup", "Hueso", "resource", base_pos + Vector3(-0.22, drop_y - base_pos.y, -0.15), 0.18, _bone_count(), 0.0, "gut_bone_%d" % Time.get_ticks_msec())
		scene.call("_spawn_ground_pickup", "Tendón", "resource", base_pos + Vector3(0.22, drop_y - base_pos.y, 0.15), 0.06, _sinew_count(), 0.0, "gut_sinew_%d" % Time.get_ticks_msec())

# When a wolf eats a corpse, spawn only leftover meat (wolf consumed most of it)
func _spawn_partial_pickups() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var base_pos := global_position
	var meat := _meat_name()
	var meat_qty := _leftover_meat_count()
	var meat_weight := 0.3
	var meat_use_value := 15.0
	for i in range(meat_qty):
		var angle := TAU * float(i) / float(max(meat_qty, 1)) + randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle) * randf_range(0.4, 0.9), 0.0, sin(angle) * randf_range(0.4, 0.9))
		var pos := base_pos + offset
		pos.y = 0.06
		var drop_id := "gut_meat_%d_%d" % [Time.get_ticks_msec(), i]
		if scene.has_method("_spawn_ground_pickup"):
			scene.call("_spawn_ground_pickup", meat, "food", pos, meat_weight, 1, meat_use_value, drop_id, "wolf_meat_raw")

func _spawn_partial_bird_pickups(corpse: Node3D) -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("_spawn_ground_pickup"):
		return
	corpse.set("_gutted", true)
	var base_pos := corpse.global_position
	var angle := randf_range(0.0, TAU)
	var pos := base_pos + Vector3(cos(angle) * 0.55, 0.0, sin(angle) * 0.55)
	pos.y = 0.06
	scene.call("_spawn_ground_pickup", "Carne cruda de ave", "food", pos, 0.3, 1, 15.0, "bear_bird_meat_%d" % Time.get_ticks_msec(), "bird_meat_raw")

func _broadcast_wolf_meat_drops(corpse: Node3D) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var net_node := scene.get_node_or_null("/root/NetworkManager")
	if net_node == null or net_node.peer == null:
		return
	# Find all wolf_meat_raw actions that were just spawned near the corpse
	var base_pos := corpse.global_position
	var meat_name := ""
	if corpse is WildlifeController:
		meat_name = corpse._meat_name()
	elif corpse is BirdController:
		meat_name = "Carne cruda de ave"
	var drops: Array = []
	var actions_dict: Dictionary = scene.get("world_actions_by_id") if scene.get("world_actions_by_id") != null else {}
	for action_id in actions_dict.keys():
		var action = actions_dict[action_id]
		if not is_instance_valid(action) or not action is Node3D:
			continue
		if not ("action_type" in action) or not ["wolf_meat_raw", "bird_meat_raw"].has(str(action.action_type)):
			continue
		var d := base_pos.distance_to((action as Node3D).global_position)
		if d > 5.0:
			continue
		var drop_id := str(action.action_id)
		var dname := str(action.get_meta("item_name", meat_name))
		var dpos := (action as Node3D).global_position
		drops.append({"id": drop_id, "name": dname, "type": "food", "pos": [dpos.x, dpos.y, dpos.z], "weight": 0.3, "qty": 1, "use": 15.0, "action_type": str(action.action_type)})
	# Broadcast to all clients using animal_gutted so they create wolf_meat_raw actions
	var animal_name: String = corpse.name if corpse != null else "wolf_corpse"
	for pid in net_node.players.keys():
		if pid == multiplayer.get_unique_id():
			continue
		if net_node.players[pid].get("offline", false):
			continue
		if not net_node.peer_alive(pid):
			continue
		net_node.animal_gutted.rpc_id(pid, animal_name, drops)

func _gut_player_corpse(proxy: Node3D) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Mark corpse as gutted so wolves don't eat it again
	proxy.set_meta("gutted", true)
	var base_pos: Vector3 = proxy.global_position
	var meat_name := "Carne humana"
	var meat_qty := 6
	var drops: Array = []
	for i in range(meat_qty):
		var angle := TAU * float(i) / float(meat_qty) + randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle) * randf_range(0.4, 0.9), 0.0, sin(angle) * randf_range(0.4, 0.9))
		var mpos := base_pos + offset
		mpos.y = 0.06
		var mid := "gut_meat_%d_%d" % [Time.get_ticks_msec(), i]
		if scene.has_method("_spawn_ground_pickup"):
			scene.call("_spawn_ground_pickup", meat_name, "food", mpos, 0.3, 1, 12.0, mid, "wolf_meat_raw")
		drops.append({"id": mid, "name": meat_name, "type": "food", "pos": [mpos.x, mpos.y, mpos.z], "weight": 0.3, "qty": 1, "use": 12.0})
	# Broadcast to all clients
	var net_node := scene.get_node_or_null("/root/NetworkManager")
	if net_node != null and net_node.peer != null:
		var animal_name: String = proxy.name
		for pid in net_node.players.keys():
			if pid == multiplayer.get_unique_id():
				continue
			if net_node.players[pid].get("offline", false):
				continue
			if not net_node.peer_alive(pid):
				continue
			net_node.animal_gutted.rpc_id(pid, animal_name, drops)

func _is_meat_action(a: Node) -> bool:
	if a == null or not ("action_type" in a):
		return false
	if str(a.action_type) in ["wolf_meat_raw", "bird_meat_raw", "deer_meat_raw", "fox_meat_raw"]:
		return true
	return a.is_in_group("wolf_meat_pickups")

func _consume_meat_pickup(action: Node3D) -> void:
	if not is_instance_valid(action) or action.is_queued_for_deletion() or action.get("depleted") == true:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var net_node := scene.get_node_or_null("/root/NetworkManager")
	var action_id := ""
	if "action_id" in action:
		action_id = str(action.action_id)
	# Domesticación: la carne tirada por un jugador cercano genera confianza.
	# La meta dropped_by la pone Main al crear el drop (peer_id en servidor,
	# "local" en SP/host).
	if action.has_meta("dropped_by"):
		_register_feeding(str(action.get_meta("dropped_by")), action.global_position)
	# Si el jugador soltó un stack (quantity > 1), consumir solo 1 unidad por
	# comida para que un stack de 3 carnes sirva para las 3 comidas en vez de
	# desaparecer entero de un bocado.
	var qty := int(action.get_meta("item_quantity", 1))
	if qty > 1:
		var remaining := qty - 1
		action.set_meta("item_quantity", remaining)
		if "_dropped_items" in scene and scene._dropped_items is Array:
			for entry in scene._dropped_items:
				if entry is Dictionary and str(entry.get("id", "")) == action_id:
					entry["qty"] = remaining
					break
		if net_node != null and net_node.peer != null and not action_id.is_empty():
			var dur := float(action.get_meta("item_durability", 100.0))
			for pid in net_node.players.keys():
				if pid == multiplayer.get_unique_id() or net_node.players[pid].get("offline", false) or not net_node.peer_alive(pid):
					continue
				net_node.ground_craft_state_changed.rpc_id(pid, action_id, remaining, dur)
		return
	# Remove the meat pickup from the world
	if not action_id.is_empty() and scene.has_method("_net_item_picked_up"):
		scene._net_item_picked_up(action_id)
	# Notify all clients to remove it
	if net_node != null and net_node.peer != null:
		for pid in net_node.players.keys():
			if pid == multiplayer.get_unique_id():
				continue
			if net_node.players[pid].get("offline", false):
				continue
			if not net_node.peer_alive(pid):
				continue
			net_node.item_picked_up.rpc_id(pid, action_id)

func _seek_meat_pickup(meat: Node3D) -> Dictionary:
	# Una pieza, un lobo: mientras la reclama (y sigue yendo a por ella o
	# comiéndola) los demás la rondan en vez de amontonarse encima.
	if _claimed_meat != meat:
		_claimed_meat = meat
		meat.set_meta("wolf_claim", self)
		_offer_stall_msec = 0
	if _flat_distance_to(meat.global_position) < 2.3:
		_offer_stall_msec = 0
		_wolf_eating_timer = 8.0
		_wolf_eating_target = meat
		_state = "eating"
		_play_animation_by_name("idle")
		return {"handled": true, "target": global_position, "speed": 0.0}
	# Si el cebo quedó sobre una celda bloqueada el nav lo deja a 2-3 m y el
	# lobo se plantaba reintentando para siempre. Sin progreso real en ~3.5 s
	# se rinde y veta esa pieza en lugar de quedarse pegado.
	if _route_waiting:
		if _offer_stall_msec == 0:
			_offer_stall_msec = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - _offer_stall_msec > 3500:
			_offer_stall_msec = 0
			_claimed_meat = null
			_blacklist_offering(meat)
			_state = "patrol"
			_current_path.clear()
			_path_index = 0
			return {"handled": true, "target": global_position, "speed": 0.0}
	else:
		_offer_stall_msec = 0
	_state = "seek_corpse"
	_seek_corpse_timer = 15.0
	_play_animation_by_name("trot")
	return {"handled": true, "target": meat.global_position, "speed": move_speed * 2.5}

func _find_nearest_meat_pickup(feeder_id: String = "") -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var nearest: Node3D = null
	var nearest_dist := 9999.0
	for action in get_tree().get_nodes_in_group("wolf_meat_pickups"):
		if not is_instance_valid(action) or not action is Node3D or action.is_queued_for_deletion():
			continue
		# El grupo recoge tanto los pickups de destripar (wolf_meat_raw) como
		# la carne que un jugador suelta en el suelo (marcada con dropped_by).
		if action.get("depleted"):
			continue
		var drop_owner := str(action.get_meta("dropped_by")) if action.has_meta("dropped_by") else ""
		if not feeder_id.is_empty():
			if drop_owner != feeder_id:
				continue
		elif not drop_owner.is_empty():
			# Carroñeo libre: el cebo de domesticación de un jugador no se lo
			# come cualquier lobo — sólo el que ya tiene su confianza o su fiel.
			if drop_owner != tamed_to and not _tame_progress.has(drop_owner):
				continue
		if _is_blacklisted_offering(action):
			continue
		# Otro lobo ya reclamó esta pieza y sigue yendo a por ella.
		if _meat_claimed_by_other(action):
			continue
		var d := global_position.distance_to((action as Node3D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = action as Node3D
	return nearest

#region DOMESTICACIÓN DE LOBOS

# Identidad del que puede domesticar: "local" para el jugador de esta instancia
# (SP/host), str(peer_id) para proxies de red.
func _feeder_key(node: Node) -> String:
	if node == null or not is_instance_valid(node):
		return ""
	if node.is_in_group("net_player_proxy"):
		var pid := int(node.get_meta("peer_id", 0))
		return str(pid) if pid != 0 else ""
	if node.name == "Player":
		return "local"
	return ""

func _find_feeder_node(feeder_id: String) -> Node3D:
	var scene := get_tree().current_scene
	if feeder_id == "local":
		if scene != null:
			var p := scene.get_node_or_null("Player")
			if p is Node3D and is_instance_valid(p):
				return p
		return null
	var pid := int(feeder_id)
	if pid == 0:
		return null
	for pr in get_tree().get_nodes_in_group("net_player_proxy"):
		if int(pr.get_meta("peer_id", -1)) == pid:
			return pr
	# El proxy desconectado sale del grupo pero sigue existiendo (cadáver/loot)
	if scene != null and "server_proxies" in scene:
		for pr in scene.server_proxies.values():
			if pr != null and int(pr.get_meta("peer_id", -1)) == pid:
				return pr
		if "proxy_by_client_id" in scene:
			for pr in scene.proxy_by_client_id.values():
				if pr != null and int(pr.get_meta("peer_id", -1)) == pid:
					return pr
	return null

func _nearest_feeder_in_range(radius: float) -> Node3D:
	var best: Node3D = null
	var best_d := radius
	for id in _tame_progress.keys():
		var n := _find_feeder_node(str(id))
		if n == null:
			continue
		var d := global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

func _resolve_bait_holder() -> Node3D:
	if _player != null and is_instance_valid(_player) and _player_holds_meat(_player):
		return _player
	for id in _tame_progress.keys():
		var n := _find_feeder_node(str(id))
		if n != null and _can_feed_from(n) and global_position.distance_to(n.global_position) <= 35.0 and _player_holds_meat(n):
			return n
	return null

func _flat_dist2(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _flat_distance_to(pos: Vector3) -> float:
	return _flat_dist2(global_position, pos)

func _offering_key(action: Node) -> String:
	var id := str(action.get("action_id"))
	return id if not id.is_empty() and id != "<null>" else str(action.name)

func _blacklist_offering(action: Node3D) -> void:
	_offering_blacklist[_offering_key(action)] = Time.get_ticks_msec() + 40000

func _is_blacklisted_offering(action: Node3D) -> bool:
	var key := _offering_key(action)
	var until := int(_offering_blacklist.get(key, 0))
	if until == 0:
		return false
	if Time.get_ticks_msec() > until:
		_offering_blacklist.erase(key)
		return false
	return true

func _progress_holder_nearby(feeder_id: String, pos: Vector3) -> WildlifeController:
	# El lobo que ya comió más veces la carne de quien ceba es el que puede
	# domesticarse: los demás ceden la pieza en vez de repartirse el progreso.
	var my_progress := int(_tame_progress.get(feeder_id, 0))
	for node in get_tree().get_nodes_in_group("wildlife"):
		var w := node as WildlifeController
		if w == null or w == self or not is_instance_valid(w) or w._is_dead or w.animal_type != "wolf":
			continue
		if int(w._tame_progress.get(feeder_id, 0)) > my_progress and w.global_position.distance_to(pos) <= 25.0:
			return w
	return null

func _meat_claimed_by_other(action: Node3D) -> bool:
	if not action.has_meta("wolf_claim"):
		return false
	var claimer = action.get_meta("wolf_claim")
	if claimer == null or claimer == self or not is_instance_valid(claimer):
		return false
	if claimer.get("_is_dead") == true or claimer.get("_claimed_meat") != action:
		return false
	return true

func _find_active_tame_offering() -> Node3D:
	var best: Node3D = null
	var best_d := 9999.0
	for action in get_tree().get_nodes_in_group("wolf_meat_pickups"):
		if not is_instance_valid(action) or not action is Node3D or action.is_queued_for_deletion():
			continue
		if action.get("depleted"):
			continue
		var dropped_by := str(action.get_meta("dropped_by")) if action.has_meta("dropped_by") else ""
		if dropped_by.is_empty():
			continue
		if _is_blacklisted_offering(action) or _meat_claimed_by_other(action):
			continue
		var feeder := _find_feeder_node(dropped_by)
		if not _can_feed_from(feeder):
			continue
		var dist_meat := _flat_distance_to(action.global_position)
		if dist_meat > TAME_FEED_RADIUS:
			continue
		# Quien la tiró tiene que seguir cerca del cebo: si se marcha, la
		# comida no suma confianza y el lobo no pierde el tiempo yendo a por ella.
		if _flat_dist2(feeder.global_position, action.global_position) > TAME_FEED_RADIUS:
			continue
		# La primera comida decide el vínculo: si otro lobo ya tiene más
		# confianza con el mismo jugador, este cede el paso.
		if _progress_holder_nearby(dropped_by, action.global_position) != null:
			continue
		var path := _request_path(global_position, action.global_position)
		if path.is_empty() or _flat_dist2(path[path.size() - 1], action.global_position) > 3.2:
			continue
		if dist_meat < best_d:
			best_d = dist_meat
			best = action as Node3D
	return best

# Cebo que este lobo NO puede comer (reclamado o ligado a otro lobo con más
# confianza): el animal lo ronda en vez de atacar a quien lo tiró.
func _find_shadow_offering() -> Node3D:
	for action in get_tree().get_nodes_in_group("wolf_meat_pickups"):
		if not is_instance_valid(action) or not action is Node3D or action.is_queued_for_deletion():
			continue
		if action.get("depleted"):
			continue
		var dropped_by := str(action.get_meta("dropped_by")) if action.has_meta("dropped_by") else ""
		if dropped_by.is_empty():
			continue
		if not _meat_claimed_by_other(action) and _progress_holder_nearby(dropped_by, action.global_position) == null:
			continue
		var feeder := _find_feeder_node(dropped_by)
		if not _can_feed_from(feeder):
			continue
		if _flat_distance_to(action.global_position) > TAME_FEED_RADIUS + 10.0:
			continue
		return action as Node3D
	return null

func _shadow_offering(offering: Node3D, delta: float) -> Dictionary:
	_state = "wary"
	var md := _flat_distance_to(offering.global_position)
	if md > 9.0:
		var tgt := offering.global_position + _compute_wolf_separation(2.5)
		_play_animation_by_name("walk")
		return {"target": tgt, "speed": move_speed * 1.6}
	var to_meat := offering.global_position - global_position
	to_meat.y = 0.0
	if to_meat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(to_meat.x, to_meat.z), delta * 4.0)
	if md < 4.0:
		_play_animation_by_name("walk")
		return {"target": global_position - to_meat.normalized() * 2.5, "speed": move_speed * 0.9}
	if randf() < delta * 0.2:
		_play_wolf_sound("growl")
	_play_animation_by_name("idle")
	return {"target": global_position, "speed": 0.0}

func _resolve_owner() -> Node3D:
	if _owner_node != null and is_instance_valid(_owner_node):
		return _owner_node
	_owner_node = _find_feeder_node(tamed_to)
	return _owner_node

func _can_feed_from(feeder: Node3D) -> bool:
	return is_instance_valid(feeder) and not feeder.is_queued_for_deletion() and not feeder.get_meta("proxy_dead", false) and not feeder.get_meta("disconnected", false) and feeder.get("is_dead") != true

# Carne o pescado equipado en la mano: localmente se lee get_held_item();
# en el servidor el proxy de red solo tiene el nombre sincronizado
# (_puppet_held vía puppet_apply_visuals desde sync_player_state).
func _player_holds_meat(p: Node) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	if p.get_meta("proxy_dead", false) or p.get_meta("disconnected", false) or p.get("is_dead") == true:
		return false
	var held_name := ""
	if p.is_in_group("net_player_proxy"):
		if p.get("_puppet_held") != null:
			held_name = str(p.get("_puppet_held"))
		if held_name.is_empty() and p.has_meta("saved_held_item"):
			held_name = str(p.get_meta("saved_held_item", ""))
		if held_name.is_empty():
			var pid := int(p.get_meta("peer_id", 0))
			var scene := get_tree().current_scene
			var net_node := scene.get_node_or_null("/root/NetworkManager") if scene != null else null
			if pid != 0 and net_node != null and "players" in net_node and net_node.players.has(pid):
				held_name = str(net_node.players[pid].get("held_item", ""))
	elif p.has_method("get_held_item"):
		var it = p.get_held_item()
		if it != null:
			held_name = str(it.get("item_name"))
	return _is_meat_name(held_name)

func _is_meat_name(n: String) -> bool:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_is_meat_item_name"):
		return scene._is_meat_item_name(n)
	return n.begins_with("Carne") or n.begins_with("Pez")

func _register_feeding(feeder_id: String, meat_pos: Vector3 = Vector3.INF) -> void:
	if feeder_id.is_empty() or tamed_to != "" or _is_dead:
		return
	var feeder := _find_feeder_node(feeder_id)
	if not _can_feed_from(feeder):
		return
	# Solo cuenta si quien la tiró sigue cerca del lobo O del cebo: tirar la
	# carne y apartarse unos metros no debe anular la confianza ganada.
	var close := global_position.distance_to(feeder.global_position) <= TAME_FEED_RADIUS
	if not close and meat_pos.is_finite():
		close = feeder.global_position.distance_to(meat_pos) <= TAME_FEED_RADIUS
	if not close:
		return
	var n := int(_tame_progress.get(feeder_id, 0)) + 1
	_tame_progress[feeder_id] = n
	if n >= TAME_FEEDINGS:
		if _owner_has_wolf(feeder_id):
			_notify_owner_msg(feeder, "El lobo te acepta, pero ya tienes un lobo fiel.")
			return
		_tame(feeder_id, feeder)
	else:
		if _player == feeder:
			_player = null
		_notify_owner_msg(feeder, "El lobo devora la carne y te observa... parece menos hostil (%d/%d)." % [n, TAME_FEEDINGS])

func _tame(feeder_id: String, feeder: Node3D) -> void:
	tamed_to = feeder_id
	_tame_progress.clear()
	_claimed_meat = null
	_follow_mode = "follow"
	_player = null
	_chase_target = null
	_wolf_foe = null
	_threat_player = null
	_owner_node = feeder
	_owner_client_id = str(feeder.get_meta("client_id", ""))
	_owner_dead_timer = 0.0
	_state = "follow"
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_record_tamed_wolf"):
		scene._record_tamed_wolf(feeder_id, name)
	_notify_owner_msg(feeder, "El lobo te ha aceptado: te acompaña y te defiende. Pulsa F sobre el para darle ordenes.")
	_play_wolf_sound("howl")

# Un jugador solo puede tener un lobo domesticado a la vez
func _owner_has_wolf(feeder_id: String) -> bool:
	for node in get_tree().get_nodes_in_group("wildlife"):
		if node == self or not (node is WildlifeController):
			continue
		var w := node as WildlifeController
		if w.animal_type == "wolf" and not w._is_dead and w.tamed_to == feeder_id:
			return true
	return false

func _go_wild() -> void:
	var old_owner := tamed_to
	tamed_to = ""
	_follow_mode = "follow"
	_threat_player = null
	_threat_timer = 0.0
	_owner_node = null
	_owner_client_id = ""
	_owner_dead_timer = 0.0
	_tame_progress.clear()
	_claimed_meat = null
	_state = "patrol"
	_chase_target = null
	if not old_owner.is_empty():
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_clear_tamed_wolf_record"):
			scene._clear_tamed_wolf_record(old_owner)

func _release_owner_record() -> void:
	# El lobo muere: el registro de "lobo domesticado" del dueño desaparece para
	# que una reconexión no resucite el vínculo sobre un cadáver.
	if tamed_to.is_empty():
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_clear_tamed_wolf_record"):
		scene._clear_tamed_wolf_record(tamed_to)

# Animal combat: one contact check per bite, using the existing attack clip.
func _fight_animal(foe: Node3D, delta: float) -> Dictionary:
	var target := foe.global_position
	var reach := 2.6 if animal_type == "bear" or str(foe.get("animal_type")) == "bear" else 2.1
	_face_towards(target, minf(delta * 3.0, 1.0))
	var close := global_position.distance_to(target) <= reach
	if _animal_bite_target != foe:
		_animal_bite_target = null
	if _animal_bite_target == null and close and _attack_cooldown <= 0.0:
		_animal_bite_target = foe
		_animal_bite_elapsed = 0.0
		_animal_bite_landed = false
		_attack_cooldown = 2.8 if animal_type == "bear" else (1.8 if not tamed_to.is_empty() else 2.5)
		_play_wolf_sound("attack")
	if _animal_bite_target != null:
		_animal_bite_elapsed += delta
		if not _animal_bite_landed and _animal_bite_elapsed >= 0.30:
			_animal_bite_landed = true
			# Recheck contact at impact: escaping prey and walls stop a bite.
			var facing := global_basis.z.normalized().dot((target - global_position).normalized()) > 0.5
			if close and facing and _animal_bite_clear(target):
				foe.take_damage(60.0 if animal_type == "bear" else (35.0 if not tamed_to.is_empty() else 25.0), false, self)
		if _animal_bite_elapsed < 0.85:
			_play_animation_by_name("attack")
			if _animation_player != null:
				_animation_player.speed_scale = 1.0
			return {"target": target, "speed": 0.0}
		_animal_bite_target = null
	_play_animation_by_name("idle" if close else "run")
	return {"target": target, "speed": 0.0 if close else move_speed * 3.4}

func _animal_bite_clear(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.7, target + Vector3.UP * 0.7, 5)
	query.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _tamed_ai(delta: float) -> Dictionary:
	_house_direct_goal = false
	var owner := _resolve_owner()
	var owner_anchor: Vector3 = owner.global_position if owner != null else global_position
	# Desenganche: no perseguir amenazas o presas lejos del dueno — vuelve a su lado.
	if _threat_player != null and (not is_instance_valid(_threat_player) or _threat_player.global_position.distance_to(owner_anchor) > 55.0):
		_threat_player = null
	if _wolf_foe != null and (not is_instance_valid(_wolf_foe) or _wolf_foe.global_position.distance_to(owner_anchor) > 60.0):
		_wolf_foe = null
	if _orders_cease and _threat_player != null:
		_threat_player = null
	if _threat_player != null and is_instance_valid(_threat_player):
		_player = _threat_player
		return {"handled": false}
	_player = null
	# Aviso por ladridos: una amenaza (lobo u oso salvaje) ronda al dueno.
	_warn_bark_timer = maxf(0.0, _warn_bark_timer - delta)
	if owner != null and _warn_bark_timer <= 0.0:
		for w in get_tree().get_nodes_in_group("wildlife"):
			if w == self or not is_instance_valid(w) or w.get("_is_dead") == true:
				continue
			var wt := str(w.get("animal_type"))
			if wt not in ["wolf", "bear"] or not str(w.get("tamed_to")).is_empty():
				continue
			if w.global_position.distance_to(owner_anchor) < 24.0:
				_play_wolf_sound("growl")
				_warn_bark_timer = randf_range(7.0, 12.0)
				break
		if _warn_bark_timer <= 0.0:
			# Grunido flojo: un personaje ajeno se acerca — avisa, no ataca.
			for grp in ["net_player_proxy", "remote_player"]:
				for op in get_tree().get_nodes_in_group(grp):
					if op == owner or not is_instance_valid(op):
						continue
					if op.get_meta("proxy_dead", false) or op.get("is_dead") == true:
						continue
					if op.global_position.distance_to(global_position) < 12.0:
						_play_wolf_sound("growl_low")
						_warn_bark_timer = randf_range(10.0, 18.0)
						break
				if _warn_bark_timer > 0.0:
					break
		if _warn_bark_timer <= 0.0:
			_warn_bark_timer = 2.5
	if _ordered_prey != null:
		var bound_anchor := _stay_pos if _follow_mode == "stay" else owner_anchor
		if not is_instance_valid(_ordered_prey) or _ordered_prey.global_position.distance_to(bound_anchor) > 60.0:
			_ordered_prey = null
		elif _ordered_prey.get("_is_dead") == true:
			# La caza propia se come aqui mismo: el cadaver no es un pickup suelto.
			if _wolf_hunger < _wolf_hunger_threshold:
				_wolf_eating_target = _ordered_prey
				_wolf_eating_timer = 8.0
			_ordered_prey = null
		else:
			var tp: Vector3 = _ordered_prey.global_position
			var td := global_position.distance_to(tp)
			_face_towards(tp, delta * 7.0)
			if td <= 3.0:
				if _attack_cooldown <= 0.0:
					_attack_cooldown = 1.8
					_ordered_prey.take_damage(35.0, false, self)
					_play_wolf_sound("attack")
				_play_animation_by_name("attack")
				return {"handled": true, "target": tp, "speed": 0.0}
			_play_animation_by_name("run")
			return {"handled": true, "target": tp, "speed": move_speed * 3.2}
	if owner == null:
		_state = "guard"
		_play_animation_by_name("idle")
		return {"handled": true, "target": global_position, "speed": 0.0}
	# Hambre: el lobo domesticado sigue comiendo carne cercana (mantenimiento),
	# incluida la que suelta el dueno al destripar ciervos, osos y demas caza.
	# En modo "stay" solo come piezas proximas a su puesto para no abandonarlo.
	if _wolf_hunger < _wolf_hunger_threshold:
		if not _hunger_warned and owner != null:
			_hunger_warned = true
			_notify_owner_msg(owner, "Tu lobo tiene hambre.")
		var food_radius := 14.0 if _follow_mode == "stay" else 45.0
		var food_anchor := _stay_pos if _follow_mode == "stay" else global_position
		var meat := _find_nearest_meat_pickup()
		if meat != null and food_anchor.distance_to(meat.global_position) < food_radius:
			return _seek_meat_pickup(meat)
		# Caza solo si no hay carne cerca: ciervos/zorros al alcance del dueno.
		if _follow_mode != "stay" and not _orders_cease:
			var prey := _find_nearest_prey_for_hunt(food_anchor, food_radius)
			if prey != null:
				_ordered_prey = prey
	elif _wolf_hunger > _wolf_hunger_threshold + 12.0:
		_hunger_warned = false
	# Dueño muerto: guardia sobre el cuerpo un tiempo y luego vuelve a ser salvaje
	var owner_dead := bool(owner.get_meta("proxy_dead", false))
	if not owner_dead and owner.name == "Player":
		owner_dead = bool(owner.get("is_dead"))
	if owner_dead:
		_state = "guard"
		_owner_dead_timer += delta
		if _owner_dead_timer >= TAME_GUARD_SECONDS:
			_go_wild()
			_play_animation_by_name("walk")
			return {"handled": true, "target": patrol_points[target_index], "speed": move_speed}
		var corpse_pos: Vector3 = owner.global_position
		if global_position.distance_to(corpse_pos) > 6.0:
			_play_animation_by_name("trot")
			return {"handled": true, "target": corpse_pos, "speed": move_speed * 2.0}
		_face_towards(corpse_pos, delta)
		_play_animation_by_name("idle")
		return {"handled": true, "target": global_position, "speed": 0.0}
	_owner_dead_timer = 0.0
	# "Quieto" o dueño desconectado: guarda la posición marcada / la última conocida
	var disconnected := bool(owner.get_meta("disconnected", false))
	if _follow_mode == "stay" or disconnected:
		var guard_pos: Vector3 = _stay_pos if _follow_mode == "stay" else owner.global_position
		_state = "guard"
		var stop_r := 6.2 if _tamed_rest_time >= 2.0 else 5.0
		if global_position.distance_to(guard_pos) > stop_r:
			_play_animation_by_name("trot")
			return {"handled": true, "target": guard_pos, "speed": move_speed * 1.8}
		if current_anim_keyword != "lie":
			_face_towards(owner.global_position, delta)
		_play_animation_by_name("idle")
		return {"handled": true, "target": global_position, "speed": 0.0}
	# "Patrullar": recorre sus puntos de patrulla alrededor de la zona marcada.
	if _follow_mode == "patrol":
		_state = "patrol"
		if patrol_points.is_empty():
			patrol_points = [_stay_pos]
		var ptgt: Vector3 = patrol_points[target_index]
		if global_position.distance_to(ptgt) < 1.8:
			target_index = (target_index + 1) % patrol_points.size()
			ptgt = patrol_points[target_index]
		_play_animation_by_name("walk")
		return {"handled": true, "target": ptgt, "speed": move_speed}
	# Seguir al dueño con offset lateral (~2.6 m), histéresis de descanso y
	# velocidad adaptada a la distancia.
	_state = "follow"
	var od := global_position.distance_to(owner.global_position)
	# Si el dueno esta dentro de una casa con la puerta abierta (o el lobo tiene
	# que salir de una porque el dueno ya salio), resolver el paso por el vano
	# antes del corte de cercania para no quedarse al otro lado del muro.
	var house := _tamed_house_override(owner)
	if not house.is_empty():
		if house.has("exit_pos"):
			_house_direct_goal = true
			var exit_pos: Vector3 = house["exit_pos"]
			var ed := global_position.distance_to(exit_pos)
			_play_animation_by_name("run" if ed > 9.0 else "trot")
			return {"handled": true, "target": exit_pos, "speed": move_speed * (2.6 if ed > 9.0 else 1.8)}
		elif bool(house.get("inside", false)):
			_house_direct_goal = true
		else:
			var door_pos: Vector3 = house["door_pos"]
			var dd := global_position.distance_to(door_pos)
			_play_animation_by_name("run" if dd > 9.0 else "trot")
			return {"handled": true, "target": door_pos, "speed": move_speed * (3.2 if dd > 26.0 else (2.1 if dd > 9.0 else 1.4))}
	var follow_stop := 4.2 if _tamed_rest_time >= 2.0 else 2.8
	if od < follow_stop:
		if od < 1.35:
			# No estorbar en puertas/pasillos: echarse a un lado del dueno.
			var aside := _safe_follow_spot(owner.global_position, 2.2)
			_play_animation_by_name("walk")
			return {"handled": true, "target": aside, "speed": move_speed * 1.2}
		_face_towards(owner.global_position, delta)
		_play_animation_by_name("idle")
		return {"handled": true, "target": global_position, "speed": 0.0}
	if od > 75.0:
		# Catch-up: a esa distancia nadie lo ve reaparecer; busca un punto
		# permitido junto al dueno para no aparecer dentro de un muro o casa cerrada.
		global_position = _safe_follow_spot(owner.global_position, 2.8)
		_snap_to_terrain()
		_current_path.clear()
		_path_index = 0
	var follow_goal := _safe_follow_spot(owner.global_position, 2.4)
	var spd := move_speed * 1.4
	var anim := "walk"
	var owner_sprinting: bool = owner.get("is_sprinting") == true or owner.get_meta("sprinting", false) == true
	if owner_sprinting and od > 3.5:
		spd = move_speed * 3.4
		anim = "run"
	elif od > 26.0:
		spd = move_speed * 3.2
		anim = "run"
	elif od > 9.0:
		spd = move_speed * 2.1
		anim = "trot"
	_play_animation_by_name(anim)
	return {"handled": true, "target": follow_goal, "speed": spd}

func _find_nearest_prey_for_hunt(anchor: Vector3, radius: float) -> Node:
	if get_tree() == null:
		return null
	var best: Node = null
	var best_d := radius
	for w in get_tree().get_nodes_in_group("wildlife"):
		if w == self or not is_instance_valid(w) or w.get("_is_dead") == true or w.get("is_puppet") == true:
			continue
		if str(w.get("animal_type")) not in ["deer", "fox"]:
			continue
		var d: float = anchor.distance_to(w.global_position)
		if d < best_d:
			best_d = d
			best = w
	return best

func _face_towards(pos: Vector3, delta: float) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length_squared() > 0.04:
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.z), delta * 3.5)

func _safe_follow_spot(owner_pos: Vector3, pref_dist: float) -> Vector3:
	var to_wolf := global_position - owner_pos
	to_wolf.y = 0.0
	var base_dir := to_wolf.normalized() if to_wolf.length() > 0.05 else Vector3(1.0, 0.0, 0.0)
	for r in [pref_dist, pref_dist * 0.55]:
		for ang in [0.0, 0.65, -0.65, 1.35, -1.35, PI]:
			var cand: Vector3 = owner_pos + base_dir.rotated(Vector3.UP, float(ang)) * float(r)
			if _is_position_allowed(cand):
				return cand
	return owner_pos

# Consulta a Main si el dueno esta dentro de una casa con la puerta abierta:
# {} si no, {"inside": false, "door_pos"} para ir al vano, {"inside": true}
# cuando el lobo ya esta dentro y puede guiarse directo hacia el dueno.
func _tamed_house_override(owner: Node3D) -> Dictionary:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("tamed_wolf_house_target"):
		var r = scene.call("tamed_wolf_house_target", self, owner)
		if r is Dictionary:
			return r
	return {}

# Un lobo salvaje u oso que persiga/ataque al dueño (o aceche muy cerca) se
# convierte en enemigo del domesticado; elige el más cercano al dueño.
func _find_wolf_threatening(owner: Node3D) -> Node3D:
	if global_position.distance_to(owner.global_position) >= 50.0:
		return null
	var best: Node3D = null
	var best_d := 9999.0
	for node in _cached_wildlife:
		if not is_instance_valid(node) or node == self or not (node is WildlifeController):
			continue
		var w := node as WildlifeController
		if w.is_puppet or (w.animal_type != "wolf" and w.animal_type != "bear") or w._is_dead:
			continue
		if w.animal_type == "wolf" and not w.tamed_to.is_empty() and w.tamed_to == tamed_to:
			continue  # lobos del mismo dueño no se atacan
		var d_owner := w.global_position.distance_to(owner.global_position)
		var targeting_owner := w._player == owner or w._chase_target == owner
		var hostile_close := w.tamed_to.is_empty() and ((w._state in ["chase_player", "bear_warn"] and d_owner < 16.0) or d_owner < 9.5)
		if not targeting_owner and not hostile_close:
			continue
		if d_owner < best_d:
			best_d = d_owner
			best = w
	return best

func notify_foe(foe: Node3D, duration: float = 20.0) -> void:
	if foe == null or foe == self or not is_instance_valid(foe) or tamed_to.is_empty() or _is_dead:
		return
	if not (foe is WildlifeController):
		return
	var fw := foe as WildlifeController
	if fw._is_dead or (fw.animal_type != "wolf" and fw.animal_type != "bear"):
		return
	if fw.animal_type == "wolf" and fw.tamed_to == tamed_to:
		return
	if _follow_mode == "stay" and global_position.distance_to(fw.global_position) > 22.0:
		return
	if global_position.distance_to(fw.global_position) > 55.0:
		return
	_wolf_foe = fw
	_foe_timer = duration
	_tamed_rest_time = 0.0
	_prey_flee_timer = 0.0

# Marca a un jugador como amenaza durante `duration` segundos (lo persigue y ataca).
func notify_threat(node: Node3D, duration: float = 20.0) -> void:
	if node == null or not is_instance_valid(node) or tamed_to.is_empty():
		return
	if _feeder_key(node) == tamed_to:
		return  # jamás ataca a su dueño
	_threat_player = node
	_threat_timer = duration
	# La defensa responde de inmediato, sin esperar el cooldown de retirada
	_chase_cooldown = minf(_chase_cooldown, 0.8)
	_prey_flee_timer = 0.0

# Quien daña al lobo: pierde su confianza y, si el lobo es domesticado, se vuelve amenaza.
func _note_attack(attacker: Node) -> void:
	if attacker == null or attacker == self or not is_instance_valid(attacker):
		return
	if attacker is WildlifeController:
		var w := attacker as WildlifeController
		# Devuelve el mordisco: combate contra lobos rivales y, si es
		# domesticado, tambien contra osos que lo ataquen (defensa).
		if (w.animal_type == "wolf" or w.animal_type == "bear") and not w._is_dead and (w.tamed_to.is_empty() or w.tamed_to != tamed_to):
			if w.animal_type == "wolf" or not tamed_to.is_empty():
				_wolf_foe = w
				_foe_timer = 20.0
		return
	var key := _feeder_key(attacker)
	if key.is_empty():
		return
	_tame_progress.erase(key)
	if not tamed_to.is_empty() and key != tamed_to:
		notify_threat(attacker as Node3D, 25.0)
	elif (animal_type == "wolf" or animal_type == "bear") and not _is_dead and tamed_to != key:
		# Si un jugador ataca a un lobo salvaje u oso, su propio lobo domesticado
		# acude a ayudarle en el combate.
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_notify_tamed_wolf_assist"):
			scene._notify_tamed_wolf_assist(key, self)

func _notify_owner_msg(owner: Node, msg: String) -> void:
	var scene := get_tree().current_scene
	if scene == null or owner == null or not is_instance_valid(owner):
		return
	if owner.name == "Player":
		var h = scene.get("hud")
		if h != null and h.has_method("show_notice"):
			h.show_notice(msg)
		elif owner.has_signal("notice"):
			owner.notice.emit(msg)
		return
	var pid := int(owner.get_meta("peer_id", 0))
	var net_node := scene.get_node_or_null("/root/NetworkManager")
	if pid != 0 and net_node != null and net_node.has_method("notice_to_client"):
		if net_node.peer != null and net_node.peer_alive(pid):
			net_node.notice_to_client.rpc_id(pid, msg)

# ¿Este actor es el dueño del lobo? En cliente compara con mi peer_id; el lobo
# real del servidor solo ve "local" (host) — los proxies nunca interactúan.
func _is_owner_actor(player: Node) -> bool:
	if player == null or tamed_to.is_empty():
		return false
	if tamed_to == "local":
		return player.name == "Player"
	var net_node = null
	if get_tree() != null and get_tree().current_scene != null:
		net_node = get_tree().current_scene.get_node_or_null("/root/NetworkManager")
	if net_node != null and net_node.has_method("get_my_id"):
		return str(net_node.get_my_id()) == tamed_to
	return false

func apply_command(mode: String, target: Node = null) -> void:
	# mode: "toggle" | "follow" | "stay" | "patrol" | "attack" | "cease"
	if mode == "attack" and target != null and is_instance_valid(target) and target != self:
		if target is WildlifeController:
			if target.get("_is_dead") == true or (not str(target.get("tamed_to")).is_empty() and str(target.get("tamed_to")) == tamed_to):
				return
			if str((target as WildlifeController).animal_type) in ["wolf", "bear"]:
				_wolf_foe = target
				_foe_timer = 20.0
			else:
				_ordered_prey = target
		elif target is Node3D and (target.is_in_group("net_player_proxy") or target.is_in_group("remote_player")):
			_threat_player = target
			_threat_timer = 25.0
		else:
			_notify_owner_msg(_resolve_owner(), "El lobo no tiene objetivo válido.")
			return
		_orders_cease = false
		_notify_owner_msg(_resolve_owner(), "¡El lobo ataca!")
		return
	if mode == "cease":
		_orders_cease = true
		_animal_bite_target = null
		_wolf_foe = null
		_ordered_prey = null
		_threat_player = null
		_state = "follow" if _follow_mode == "follow" else "guard"
		_notify_owner_msg(_resolve_owner(), "El lobo deja de atacar.")
		return
	if mode == "toggle":
		_follow_mode = "stay" if _follow_mode == "follow" else "follow"
	elif mode in ["stay", "follow", "patrol"]:
		_follow_mode = mode
	else:
		return
	if _follow_mode in ["stay", "patrol"]:
		_stay_pos = global_position
	var owner := _resolve_owner()
	var msg := "El lobo te sigue."
	if _follow_mode == "stay":
		msg = "El lobo guarda esta zona."
	elif _follow_mode == "patrol":
		msg = "El lobo patrulla la zona."
	_notify_owner_msg(owner, msg)

func _interact_tamed(player: Node) -> void:
	if not _is_owner_actor(player):
		if player != null and player.has_signal("notice"):
			player.notice.emit("El lobo solo obedece a su dueño.")
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_show_wolf_orders"):
		scene._show_wolf_orders(self)
	else:
		apply_command("toggle")

#endregion

# Las moscas acuden al cabo de ~45 s muerto y desaparecen con el cadaver
# (el enjambre es hijo de este nodo y se libera con el).
func _update_corpse_flies() -> void:
	if _flies_attached:
		return
	if _rot_timer > 255.0:
		return
	_flies_attached = true
	var swarm := FlySwarm.new()
	swarm.name = "FlySwarm"
	swarm.position = Vector3(0.0, 0.35, 0.0)
	add_child(swarm)

func _remove_corpse() -> void:
	remove_from_group("interactable")
	if is_instance_valid(_corpse_body):
		_corpse_body.queue_free()
		_corpse_body = null
	queue_free()

func _spawn_gutted_meat() -> void:
	_spawn_gut_pickups()

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var result := _find_skeleton(child)
		if result != null:
			return result
	return null

func _spawn_blood_splatter() -> void:
	var _net := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
	if _net != null and _net.is_dedicated_server:
		return
	# Reutiliza el efecto mejorado del jugador (gotas + niebla suaves)
	var player_node := get_tree().current_scene.get_node_or_null("Player")
	if player_node != null and player_node.has_method("_spawn_blood_splatter"):
		player_node._spawn_blood_splatter(global_position + Vector3(0, 0.8, 0))
		return
	_spawn_local_blood_burst(global_position + Vector3(0, 0.8, 0))

func _spawn_local_blood_burst(at_pos: Vector3) -> void:
	var drops := GPUParticles3D.new()
	drops.name = "BloodDrops"
	drops.amount = 36
	drops.lifetime = 0.7
	drops.explosiveness = 1.0
	drops.randomness = 0.9
	drops.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 70.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 7.0
	mat.gravity = Vector3(0, -18.0, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	mat.color = Color(0.45, 0.01, 0.01, 1.0)
	drops.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var qmat := StandardMaterial3D.new()
	qmat.albedo_color = Color(0.45, 0.01, 0.01, 1.0)
	qmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.vertex_color_use_as_albedo = true
	quad.material = qmat
	drops.draw_pass_1 = quad
	get_tree().current_scene.add_child(drops)
	drops.global_position = at_pos
	drops.emitting = true
	drops.finished.connect(drops.queue_free)

func _play_pain_sound() -> void:
	var _net := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
	if _net != null and _net.is_dedicated_server:
		return
	var player_node := get_tree().current_scene.get_node_or_null("Player")
	var dist := 999.0
	if player_node != null and player_node is Node3D:
		dist = global_position.distance_to((player_node as Node3D).global_position)
	var max_pain_dist := 60.0 if animal_type == "bear" else 35.0
	if dist > max_pain_dist:
		return
	if _wolf_pain_player == null:
		_wolf_pain_player = AudioStreamPlayer.new()
		_wolf_pain_player.name = "PainSound"
		add_child(_wolf_pain_player)
	var path := "res://assets/audio/loboherido.wav" if (animal_type == "wolf" or animal_type == "bear") else "res://assets/audio/animal_herido.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			stream = AudioStreamWAV.load_from_file(disk_path)
	if stream == null:
		return
	_wolf_pain_player.stop()
	_wolf_pain_player.stream = stream
	var base_vol := 0.0 if animal_type == "bear" else -4.0
	_wolf_pain_player.volume_db = base_vol - (dist / max_pain_dist) * 14.0
	_wolf_pain_player.pitch_scale = randf_range(0.46, 0.56) if animal_type == "bear" else randf_range(0.85, 1.15)
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
	var lower_keyword := keyword.to_lower()
	if lower_keyword == "idle" and animal_type == "wolf" and _wolf_eating_timer > 0.0:
		lower_keyword = "eat"
	if lower_keyword == "idle" and animal_type == "wolf" and not tamed_to.is_empty() and not is_puppet and _state in ["follow", "guard"] and _threat_player == null:
		if _tamed_rest_time >= 12.0 and _follow_mode == "stay":
			lower_keyword = "lie"
		elif _tamed_rest_time >= 2.0:
			lower_keyword = "sit"
	current_anim_keyword = lower_keyword
	if _animation_player == null:
		return
	# Rest clips keep their authored cadence even after a network speed update.
	if lower_keyword in ["idle", "sit", "lie", "eat"]:
		_animation_player.speed_scale = 1.0
	var current := _animation_player.current_animation
	if not current.is_empty() and current.to_lower().find(lower_keyword) >= 0 and (lower_keyword != "run" or current.to_lower().find("frighten") < 0):
		if not _animation_player.is_playing():
			_animation_player.play(current)
		return
	var best := ""
	var candidates := [lower_keyword]
	if lower_keyword == "gallop":
		candidates = ["gallop", "a_runfast", "run", "trot", "walk"]
	elif lower_keyword == "run":
		candidates = ["a_runfast", "a_runslow", "run", "gallop", "trot", "walk"]
	elif lower_keyword == "trot":
		candidates = ["trot", "walk", "run"]
	var anim_list := _animation_player.get_animation_list()
	for animation_name in anim_list:
		var animation := _animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	for cand_kw in candidates:
		for animation_name in anim_list:
			if animation_name.to_lower().find(cand_kw) >= 0:
				best = animation_name
				break
		if not best.is_empty():
			break
	if best.is_empty():
		return
	if current != best:
		var resting := lower_keyword in ["idle", "sit", "lie", "eat"]
		if resting:
			_animation_player.speed_scale = 1.0
		_animation_player.play(best, 0.65 if lower_keyword in ["sit", "lie"] else 0.2)

func _update_animation_speed(speed: float) -> void:
	if _animation_player == null:
		return
	if current_anim_keyword == "attack":
		_animation_player.speed_scale = 1.0
		return
	var ratio := speed / move_speed
	_animation_player.speed_scale = clamp(ratio, 0.5, 2.5)

func _update_wolf_sounds(delta: float) -> void:
	_howl_timer -= delta
	_growl_timer -= delta
	var is_hungry := _wolf_hunger < _wolf_hunger_threshold
	if is_hungry and _howl_timer <= 0.0:
		_play_wolf_sound("howl")
		_howl_timer = randf_range(20.0, 45.0)
	if _growl_timer <= 0.0:
		if is_puppet:
			_play_wolf_sound("growl")
			_growl_timer = randf_range(8.0, 16.0)
		elif _state == "chase_player" or _state == "chase_deer":
			_play_wolf_sound("growl")
			_growl_timer = randf_range(3.0, 8.0)
		else:
			_growl_timer = randf_range(10.0, 20.0)

func _play_wolf_sound(sound_type: String) -> void:
	var _net := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
	if _net != null and _net.is_dedicated_server:
		# Dedicated servers can't play audio: relay events to clients so each
		# puppet plays the sound locally.
		if (sound_type == "howl" or sound_type == "attack" or sound_type == "growl" or sound_type == "bite") and _net.is_connected:
			_net.animal_sound.rpc(name, sound_type)
		return
	var is_bear := animal_type == "bear"
	# El lobo domesticado no aulla como el salvaje: usa un ladrido corto y mas
	# agudo (growl agudo) para distinguirse de lejos en cualquier sonido.
	var tamed := animal_type == "wolf" and not tamed_to.is_empty()
	if sound_type == "howl" and not is_bear and not tamed:
		var player_node_h := get_tree().current_scene.get_node_or_null("Player")
		var dist_h := 999.0
		if player_node_h != null and player_node_h is Node3D:
			dist_h = global_position.distance_to((player_node_h as Node3D).global_position)
		if dist_h > 40.0:
			return
		if _wolf_howl_2d_player == null:
			_wolf_howl_2d_player = AudioStreamPlayer.new()
			_wolf_howl_2d_player.name = "WolfHowl2D"
			add_child(_wolf_howl_2d_player)
		if _wolf_howl_2d_player.playing:
			return
		var path := "res://assets/external/audio/downloaded/aullidos.mp3"
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if stream == null:
			var disk_path := ProjectSettings.globalize_path(path)
			if FileAccess.file_exists(disk_path):
				stream = AudioStreamMP3.load_from_file(disk_path)
		if stream == null:
			return
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = false
		_wolf_howl_2d_player.stream = stream
		var vol := -6.0 - (dist_h / 40.0) * 14.0
		if player_node_h != null and player_node_h.has_meta("in_house") and player_node_h.get_meta("in_house", false):
			vol -= 20.0
		_wolf_howl_2d_player.volume_db = vol
		_wolf_howl_2d_player.pitch_scale = randf_range(0.85, 1.15)
		_wolf_howl_2d_player.play()
		return
	if _wolf_audio_player == null:
		_wolf_audio_player = AudioStreamPlayer3D.new()
		_wolf_audio_player.name = "WolfSound"
		_wolf_audio_player.unit_size = 14.0 if is_bear else 8.0
		_wolf_audio_player.max_distance = 65.0 if is_bear else 40.0
		_wolf_audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		add_child(_wolf_audio_player)
	if _wolf_audio_player.playing and sound_type != "attack" and sound_type != "bite":
		return
	var path := ""
	match sound_type:
		"growl", "howl", "growl_low":
			path = "res://assets/external/audio/downloaded/wolf_growl.wav"
		"attack":
			path = "res://assets/external/audio/downloaded/wolf_growl.wav"
		"bite":
			path = "res://assets/audio/mordedura.mp3"
		_:
			return
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			if path.get_extension().to_lower() == "mp3":
				stream = AudioStreamMP3.load_from_file(disk_path)
			else:
				stream = AudioStreamWAV.load_from_file(disk_path)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	_wolf_audio_player.stream = stream
	if is_bear:
		_wolf_audio_player.volume_db = 4.0 if sound_type == "attack" or sound_type == "bite" else 1.0
		_wolf_audio_player.pitch_scale = randf_range(0.45, 0.56)
	else:
		if sound_type == "growl_low":
			_wolf_audio_player.volume_db = -14.0
			_wolf_audio_player.pitch_scale = randf_range(0.6, 0.75) * (1.45 if tamed else 1.0)
		else:
			_wolf_audio_player.volume_db = 0.0 if sound_type == "attack" or sound_type == "bite" else -4.0
			_wolf_audio_player.pitch_scale = randf_range(0.85, 1.15) * (1.45 if tamed else 1.0)
	_wolf_audio_player.play()

func _update_stuck_timer(delta: float) -> void:
	if _route_waiting or _idle_timer > 0.0 or _wolf_eating_timer > 0.0:
		_stuck_time = 0.0
		_progress_timer = 0.0
		_last_position = global_position
		_progress_ref_pos = global_position
		return
	if global_position.distance_to(_last_position) < 0.015:
		_stuck_time += delta
	else:
		_stuck_time = 0.0
		_last_position = global_position
		_stuck_escalation = 0
	if _stuck_time > 0.7:
		_stuck_time = 0.0
		_stuck_escalation += 1
		_current_path.clear()
		_path_index = 0
		if _stuck_escalation <= 2:
			# Nivel 1-2: elegir otro punto de patrulla aleatorio (no el siguiente
			# secuencial, que suele apuntar al mismo obstáculo)
			_retarget_from_blocked_route()
		elif _stuck_escalation <= 5:
			# Nivel 3-5: forzar salida en una dirección libre durante un momento
			_begin_unstuck_burst()
		else:
			# Nivel 6+: reposicionar al punto permitido más cercano
			_hard_unstuck()
			_stuck_escalation = 0
	# Detección de falta de progreso: un animal puede oscilar (fuerza de
	# separación contra objetivo de ruta) moviéndose cada frame sin avanzar,
	# lo que resetea _stuck_time y nunca escala. Se mide el desplazamiento
	# neto en una ventana de tiempo.
	if _idle_timer > 0.0:
		_progress_timer = 0.0
		_progress_ref_pos = global_position
		return
	_progress_timer += delta
	if _progress_timer >= 3.0:
		var net_moved := global_position.distance_to(_progress_ref_pos)
		_progress_timer = 0.0
		_progress_ref_pos = global_position
		if net_moved < 2.0:
			_current_path.clear()
			_path_index = 0
			_stuck_escalation += 1
			if _stuck_escalation <= 3:
				_begin_unstuck_burst()
			else:
				_hard_unstuck()
				_stuck_escalation = 0

func _retarget_from_blocked_route() -> void:
	_current_path.clear()
	_path_index = 0
	_path_recalc_timer = 0.0
	if _state == "chase_player":
		return
	if patrol_points.size() <= 1:
		return
	var new_index := target_index
	for _try in range(6):
		new_index = randi() % patrol_points.size()
		if new_index != target_index:
			break
	target_index = new_index

# Busca una dirección libre alrededor del animal y se mueve hacia ella durante
# un breve periodo, ignorando el objetivo de patrulla. Sirve para despegarse de
# esquinas y obstáculos donde el pathfinding no encuentra salida.
func _begin_unstuck_burst() -> void:
	var best_dir := Vector3.ZERO
	var best_clearance := 0.0
	for i in range(12):
		var angle := TAU * float(i) / 12.0 + randf_range(-0.2, 0.2)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var clearance := 0.0
		for step in range(1, 7):
			var probe := global_position + dir * float(step) * 1.2
			probe.x = clamp(probe.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
			probe.z = clamp(probe.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
			if not _is_position_allowed(probe):
				break
			clearance = float(step) * 1.2
		if clearance > best_clearance:
			best_clearance = clearance
			best_dir = dir
	if best_dir.length() < 0.01:
		_hard_unstuck()
		return
	_unstuck_dir = best_dir
	_unstuck_timer = 1.2
	_retarget_from_blocked_route()

# Último recurso: recolocar al animal en la posición permitida más cercana.
func _hard_unstuck() -> void:
	var safe = _nearest_allowed_point(global_position)
	if safe != null:
		var safe_pos: Vector3 = safe
		global_position = Vector3(safe_pos.x, global_position.y, safe_pos.z)
		_snap_to_terrain()
	_unstuck_dir = Vector3.ZERO
	_unstuck_timer = 0.0
	_retarget_from_blocked_route()

func _try_flee_from_player(delta: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var away := global_position - _player.global_position
	away.y = 0.0
	if away.length() > _flee_distance():
		return false
	if away.length() < 0.01:
		away = Vector3.RIGHT
	var flee_goal := _clamp_flee_goal(global_position, away, 20.0)
	_path_recalc_timer -= delta
	if _current_path.is_empty() or _path_index >= _current_path.size() or _path_recalc_timer <= 0.0:
		_current_path = _request_path(global_position, flee_goal)
		_path_index = 0
		_path_recalc_timer = 3.0
	var flee_speed := move_speed * (2.65 if animal_type == "fox" else 2.05)
	var move_target: Vector3 = flee_goal
	if _current_path.size() > 0 and _path_index < _current_path.size():
		var waypoint: Vector3 = _current_path[_path_index]
		var to_waypoint: Vector3 = waypoint - global_position
		to_waypoint.y = 0.0
		if to_waypoint.length() < 1.5:
			_path_index += 1
			if _path_index < _current_path.size():
				move_target = _current_path[_path_index]
		else:
			move_target = waypoint
	_move_towards(move_target, flee_speed, delta, 6.0)
	if global_position.distance_to(_last_position) > 0.01:
		_walk_time += delta * flee_speed * 4.8
		_animate_legs(delta)
	return true

func _update_water_depth(delta: float) -> void:
	var _t := Time.get_ticks_usec()
	_update_water_depth_impl(delta)
	_pp("water_depth", _t)

func _update_water_depth_impl(delta: float) -> void:
	_water_query_timer += delta
	if _water_query_timer >= 0.25:
		_water_query_timer = 0.0
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("get_river_depth_at"):
			_water_depth = float(scene.call("get_river_depth_at", global_position))
		else:
			_water_depth = 0.0
	var target_sink: float = -clamp(_water_depth, 0.0, 1.4) * 0.35
	_water_sink = lerp(_water_sink, target_sink, delta * 5.0)
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.position.y = _water_sink

func _move_towards(target_pos: Vector3, speed: float, delta: float, turn_speed: float) -> void:
	var _t := Time.get_ticks_usec()
	_move_towards_impl(target_pos, speed, delta, turn_speed)
	_pp("move_towards", _t)

func _move_towards_impl(target_pos: Vector3, speed: float, delta: float, turn_speed: float) -> void:
	var dir: Vector3 = target_pos - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	dir = dir.normalized()
	# Separation: push away from nearby animals of same type to avoid stacking
	var sep := _get_separation_vector()
	if sep.length() > 0.01:
		dir = (dir + sep * 0.45).normalized()
	# Profundidad de agua: al igual que el jugador, vadear rios/lagos frena al animal
	if _water_depth > 0.02:
		speed *= lerp(0.72, 0.32, clamp(_water_depth, 0.0, 1.0))
	var step := minf(speed * delta, global_position.distance_to(target_pos))
	var next_pos: Vector3 = global_position + dir * step
	next_pos.x = clamp(next_pos.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
	next_pos.z = clamp(next_pos.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
	if not _is_position_allowed(next_pos):
		if not _move_with_avoidance(dir, speed, delta, turn_speed):
			return
		return
	global_position = next_pos
	_snap_to_terrain()
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * turn_speed)

func _snap_to_terrain() -> void:
	var _t := Time.get_ticks_usec()
	_snap_to_terrain_impl()
	_pp("snap_terrain", _t)

func _snap_to_terrain_impl() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_get_exact_ground_y"):
		global_position.y = float(scene.call("_get_exact_ground_y", global_position.x, global_position.z))
	elif scene != null and scene.has_method("_get_ground_height"):
		global_position.y = float(scene.call("_get_ground_height", global_position))

# Deja una huella cada `stride` metros recorridos (distancia real, así sirve
# igual para el host y para los puppets de otros clientes, que se mueven por
# _network_motion.advance en el frame anterior).
func _update_tracks() -> void:
	var _t := Time.get_ticks_usec()
	_update_tracks_impl()
	_pp("tracks", _t)

func _update_tracks_impl() -> void:
	# tracks_enabled() ya descarta el dedicado (OS.has_feature).
	if not TrackPrintScript.tracks_enabled():
		return
	if _is_dead:
		return
	var spec: Dictionary = TRACK_SPECS.get(animal_type, {})
	if spec.is_empty():
		return
	var pos := global_position
	if not _track_started:
		_track_started = true
		_track_anchor = pos
		return
	var d := pos - _track_anchor
	d.y = 0.0
	var dist := d.length()
	if dist < 0.002:
		return
	var from := _track_anchor
	_track_anchor = pos
	var dir := d / dist
	var scene := get_tree().current_scene
	if scene == null:
		return
	# En partida real hay ~80 animales repartidos por todo el mapa: si los
	# lejanos (>240 m) generan huellas cada frame, agotan el pool global
	# MAX_TRACKS en pocos segundos y borran las huellas cercanas de osos/lobos.
	var local_player = scene.get("player")
	if local_player is Node3D and is_instance_valid(local_player):
		var lp: Vector3 = (local_player as Node3D).global_position
		if Vector2(pos.x - lp.x, pos.z - lp.z).length_squared() > 240.0 * 240.0:
			_track_acc = 0.0
			return
	# Teleport/snap (corrección de red, escape de atasco): retomar sin huella.
	if dist > 8.0:
		_track_acc = 0.0
		return
	# Query each footprint, including lateral offsets and intermediate LOD steps.
	# The AI's cached depth is only a fallback for scenes without water geometry.
	if not scene.has_method("get_river_depth_at") and _water_depth > 0.02:
		_track_acc = 0.0
		return
	var stride := float(spec["stride"])
	var lat_dir := Vector3(-dir.z, 0.0, dir.x)
	var yaw := atan2(dir.x, dir.z)
	# Primera huella a `stride - acc_prev` desde `from`; luego cada stride —
	# los saltos grandes del LOD se reparten por el segmento, no se pierden.
	var s := stride - (_track_acc)
	while s <= dist:
		_track_side = -_track_side
		var pp: Vector3 = from + dir * s + lat_dir * _track_side * float(spec["lat"])
		pp.y = lerpf(from.y, pos.y, s / dist)
		s += stride
		if scene.has_method("get_river_depth_at") and float(scene.call("get_river_depth_at", pp)) > 0.02:
			continue
		var normal := Vector3.UP
		if scene.has_method("_get_exact_ground_y"):
			pp.y = float(scene.call("_get_exact_ground_y", pp.x, pp.z))
			var sample_radius := float(spec["size"]) * 0.5
			var hx0 := float(scene.call("_get_exact_ground_y", pp.x - sample_radius, pp.z))
			var hx1 := float(scene.call("_get_exact_ground_y", pp.x + sample_radius, pp.z))
			var hz0 := float(scene.call("_get_exact_ground_y", pp.x, pp.z - sample_radius))
			var hz1 := float(scene.call("_get_exact_ground_y", pp.x, pp.z + sample_radius))
			normal = Vector3(hx0 - hx1, 2.0 * sample_radius, hz0 - hz1).normalized()
			# A footprint must not bridge a vertical ledge or wall.
			if normal.y < 0.55:
				continue
		pp += normal * 0.015
		TrackPrintScript.spawn(scene, pp, yaw, String(spec["kind"]), float(spec["size"]), normal)
	_track_acc = dist - (s - stride)

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
	var fallback_dir := Vector3.ZERO
	var fallback_pos := Vector3.ZERO
	for candidate in candidates:
		candidate = candidate.normalized()
		var step_dist := speed * delta
		var next_pos: Vector3 = global_position + candidate * step_dist
		next_pos.x = clamp(next_pos.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
		next_pos.z = clamp(next_pos.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
		if not _is_position_allowed(next_pos):
			continue
		# Anticipación a distancia fija: permite esquivar antes de chocar
		var lookahead: Vector3 = global_position + candidate * 1.2
		lookahead.x = clamp(lookahead.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
		lookahead.z = clamp(lookahead.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
		if not _is_position_allowed(lookahead):
			if fallback_dir.length() < 0.01:
				fallback_dir = candidate
				fallback_pos = next_pos
			continue
		global_position = next_pos
		_snap_to_terrain()
		rotation.y = lerp_angle(rotation.y, atan2(candidate.x, candidate.z), delta * turn_speed)
		return true
	# Ningún candidato con anticipación libre: aceptar el mejor paso inmediato
	if fallback_dir.length() > 0.01:
		global_position = fallback_pos
		_snap_to_terrain()
		rotation.y = lerp_angle(rotation.y, atan2(fallback_dir.x, fallback_dir.z), delta * turn_speed)
		return true
	return false


func _is_path_clear(_next_pos: Vector3, _candidate: Vector3) -> bool:
	return true

func _direct_route_allowed(goal: Vector3) -> bool:
	var steps := maxi(1, int(ceil(global_position.distance_to(goal) / 0.5)))
	for i in range(1, steps + 1):
		if not _is_position_allowed(global_position.lerp(goal, float(i) / steps)):
			return false
	return true

func _is_position_allowed(pos: Vector3) -> bool:
	var _t := Time.get_ticks_usec()
	var _r := _is_position_allowed_impl(pos)
	_pp("pos_allowed", _t)
	return _r

func _is_position_allowed_impl(pos: Vector3) -> bool:
	var scene := get_tree().current_scene
	if animal_type == "wolf" and not tamed_to.is_empty() and scene != null and scene.has_method("is_tamed_wolf_allowed_at"):
		return bool(scene.call("is_tamed_wolf_allowed_at", pos, self))
	if (animal_type == "wolf" or animal_type == "bear") and scene != null and scene.has_method("is_wolf_allowed_at"):
		return bool(scene.call("is_wolf_allowed_at", pos))
	if scene != null and scene.has_method("is_wildlife_allowed_at"):
		return bool(scene.call("is_wildlife_allowed_at", pos))
	if scene != null and scene.has_method("_is_near_wildlife_blocker"):
		if bool(scene.call("_is_near_wildlife_blocker", pos, 1.0)):
			return false
	return true

func _get_separation_vector() -> Vector3:
	var _t := Time.get_ticks_usec()
	var _r := _get_separation_vector_impl()
	_pp("separation", _t)
	return _r

func _get_separation_vector_impl() -> Vector3:
	var push := Vector3.ZERO
	var sep_radius := 40.0 if animal_type == "bear" else 3.0
	var sep_radius_sq := sep_radius * sep_radius
	for node in _cached_wildlife:
		if node == self:
			continue
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not (node is Node3D):
			continue
		var other := node as Node3D
		var diff := global_position - other.global_position
		diff.y = 0.0
		var d_sq := diff.length_squared()
		if d_sq <= 0.000001 or d_sq >= sep_radius_sq:
			continue
		# Cheap distance gate first: the dynamic property lookups below only run
		# for animals that are actually close.
		if other.get("animal_type") == null:
			continue
		if str(other.get("animal_type")) != animal_type:
			continue
		var d := sqrt(d_sq)
		push += diff.normalized() * (sep_radius - d) / sep_radius
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
			candidate.x = clamp(candidate.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
			candidate.z = clamp(candidate.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
			if _is_position_allowed(candidate):
				safe_points.append(candidate)
				break
		if safe_points.size() >= 3:
			break
	if safe_points.size() < 2:
		safe_points = [Vector3(-18.0, 0.0, 12.0), Vector3(18.0, 0.0, 16.0), Vector3(34.0, 0.0, 4.0)]
	return safe_points

func _flee_distance() -> float:
	if animal_type == "wolf" or animal_type == "bear":
		return 0.0
	return 16.0 if animal_type == "fox" else 13.0

func _is_near_lit_campfire(pos: Vector3, radius: float) -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	# Check campfire_positions on Main
	if scene.has_method("get_lit_campfire_positions"):
		for cf_pos in scene.get_lit_campfire_positions():
			if pos.distance_to(cf_pos) < radius:
				return true
	return false

func _resolve_player() -> void:
	var _t := Time.get_ticks_usec()
	_resolve_player_impl()
	_pp("resolve_player", _t)

func _resolve_player_impl() -> void:
	if tamed_to != "":
		# Domesticado: solo persigue a la amenaza designada, nunca a otros
		# jugadores por su cuenta (y jamás a su dueño).
		if _threat_player != null and is_instance_valid(_threat_player) and _threat_timer > 0.0:
			_player = _threat_player
		else:
			_player = null
		return
	if _player != null and is_instance_valid(_player):
		# Check if player moved too far or became invalid
		if _player.is_in_group("net_player_proxy"):
			# Re-evaluate: find nearest proxy each time
			_player = null
		elif _tame_progress.has(_feeder_key(_player)):
			# Empezó a alimentarlo a media persecución: deja de ser presa
			_player = null
		else:
			return
	var scene := get_tree().current_scene
	if scene == null:
		return
	# On server: find nearest net_player_proxy (skip protected ones)
	var proxies := get_tree().get_nodes_in_group("net_player_proxy")
	if not proxies.is_empty():
		var nearest: Node3D = null
		var nearest_dist := 99999.0
		for p in proxies:
			if not (p is Node3D):
				continue
			# Quien lo alimenta deja de ser presa aunque aún no lo haya domesticado
			var feeder_pid := int(p.get_meta("peer_id", 0))
			if feeder_pid != 0 and _tame_progress.has(str(feeder_pid)):
				continue
			# Predator targeting respects spawn protection so a loading player
			# isn't selected as a target while the grace period is active.
			if (animal_type == "wolf" or animal_type == "bear") and p.get_meta("protection_timer", 0.0) > 0.0:
				continue
			# Skip proxies that haven't received real position from client
			if not p.get_meta("has_real_pos", false):
				continue
			# Skip dead proxies
			if p.get_meta("proxy_dead", false):
				continue
			# Skip proxies inside a built shelter (protected from animals)
			if p.get_meta("in_built_shelter", false):
				continue
			# Predators cannot target roofed players, regardless of door state.
			if (animal_type == "wolf" or animal_type == "bear") and scene.has_method("_is_pos_wolf_protected") and scene._is_pos_wolf_protected((p as Node3D).global_position):
				continue
			var d: float = global_position.distance_to((p as Node3D).global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest = p as Node3D
		if nearest != null:
			_player = nearest
			if _wolf_ai_debug_timer <= 0.0:
				_wolf_ai_debug_timer = 5.0
			return
		else:
			if _wolf_ai_debug_timer <= 0.0:
				_wolf_ai_debug_timer = 5.0
	# On client/single: find Player node
	_player = scene.get_node_or_null("Player") as Node3D
	if _player != null and _tame_progress.has("local"):
		_player = null

func _request_path(start: Vector3, goal: Vector3) -> Array:
	var _t := Time.get_ticks_usec()
	var _r: Array = _request_path_impl(start, goal)
	_pp("request_path", _t)
	return _r

func _request_path_impl(start: Vector3, goal: Vector3) -> Array:
	var scene := get_tree().current_scene
	if animal_type == "wolf" and not tamed_to.is_empty() and scene != null and scene.has_method("find_path_wildlife"):
		# El nav de presas deja los rios transitables y tambien abre los vanos
		# de puerta: el domesticado puede cruzar el agua siguiendo a su dueno.
		return scene.call("find_path_wildlife", start, goal) as Array
	if (animal_type == "wolf" or animal_type == "bear") and scene != null and scene.has_method("find_path_wolf"):
		return scene.call("find_path_wolf", start, goal) as Array
	if scene != null and scene.has_method("find_path_wildlife"):
		return scene.call("find_path_wildlife", start, goal) as Array
	return [goal]

func _can_reach_player() -> bool:
	if _player == null or not is_instance_valid(_player):
		return false
	var height_diff := absf(_player.global_position.y - global_position.y)
	if height_diff >= 1.8:
		return false
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("find_path_wildlife"):
		return true
	var path: Array = _request_path(global_position, _player.global_position)
	if path.is_empty():
		return false
	var last_point: Vector3 = path[path.size() - 1]
	var dist := last_point.distance_to(_player.global_position)
	return dist < 3.0

func _compute_wolf_separation(radius: float) -> Vector3:
	var push := Vector3.ZERO
	for node in get_tree().get_nodes_in_group("wildlife"):
		if not is_instance_valid(node) or node == self or not (node is Node3D):
			continue
		var other := node as Node3D
		var d := global_position.distance_to(other.global_position)
		if d > radius or d < 0.01:
			continue
		var away := (global_position - other.global_position).normalized()
		away.y = 0.0
		push += away * (radius - d) / radius
	return push

func _animate_legs(delta: float) -> void:
	if _visual_root != null:
		_visual_root.position.y = _water_sink + sin(_walk_time * 2.0) * 0.035
		_visual_root.rotation_degrees.z = sin(_walk_time) * 2.0
	for i in range(_legs.size()):
		var leg := _legs[i]
		var side := 1.0 if i % 2 == 0 else -1.0
		leg.rotation_degrees.x = lerp(leg.rotation_degrees.x, sin(_walk_time + side * PI) * 18.0, delta * 8.0)

func _build_animal() -> void:
	# Dedicated server: skip visual model loading — only AI logic and position matter
	var scene := get_tree().current_scene
	var net_node := scene.get_node_or_null("/root/NetworkManager") if scene != null else null
	if net_node != null and net_node.is_dedicated_server:
		return
	if _try_build_external_animal():
		_create_hitbox()
		return
	var scale_value := 1.25 if animal_type == "bear" else (1.0 if animal_type == "deer" else 0.48)
	var body_color := Color(0.16, 0.11, 0.075) if animal_type == "bear" else (Color(0.30, 0.20, 0.11) if animal_type == "deer" else Color(0.32, 0.28, 0.22))
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
	_create_hitbox()

func _create_hitbox() -> void:
	var body_height := 1.75 if animal_type == "bear" else (1.35 if animal_type == "deer" else (1.05 if animal_type == "wolf" else 0.55))
	var body_center := body_height * 0.5
	var head_y := body_height * 0.85
	var head_radius := 0.34 if animal_type == "bear" else (0.26 if animal_type == "deer" else 0.24)
	var body_area := Area3D.new()
	body_area.name = "BodyHitbox"
	body_area.collision_layer = 1
	body_area.collision_mask = 0
	body_area.monitorable = true
	body_area.monitoring = false
	var body_col := CollisionShape3D.new()
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.60 if animal_type == "bear" else (0.46 if animal_type == "deer" else (0.40 if animal_type == "wolf" else 0.30))
	body_shape.height = body_height
	body_col.shape = body_shape
	body_col.position.y = body_center
	body_area.add_child(body_col)
	add_child(body_area)
	var head_area := Area3D.new()
	head_area.name = "HeadHitbox"
	head_area.collision_layer = 1
	head_area.collision_mask = 0
	head_area.monitorable = true
	head_area.monitoring = false
	var head_col := CollisionShape3D.new()
	var head_shape := SphereShape3D.new()
	head_shape.radius = head_radius
	head_col.shape = head_shape
	head_col.position.y = head_y
	head_area.add_child(head_col)
	add_child(head_area)

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
		var target_height := species_height(animal_type)
		_normalize_model_height(node, target_height, path)
		node.visible = true
		_visual_root = node
		_animation_player = _find_animation_player(node)
		_play_external_walk_animation()
		return true
	return false

static func corpse_species(item_name: String) -> String:
	return {"Ciervo muerto": "deer", "Lobo muerto": "wolf", "Zorro muerto": "fox", "Oso muerto": "bear", "Animal muerto": "wolf"}.get(item_name, "")

static func species_height(kind: String) -> float:
	match kind:
		"deer": return 1.5
		"wolf": return 1.2
		"bear": return 1.65
		_: return 0.55

static var _cached_baked_aabb: Dictionary = {}

static func _normalize_model_height(node: Node3D, target_height: float, cache_key: String = "") -> void:
	var aabb: AABB
	if not cache_key.is_empty() and _cached_baked_aabb.has(cache_key):
		aabb = _cached_baked_aabb[cache_key]
	else:
		aabb = _baked_aabb_local(node)
		if not cache_key.is_empty() and aabb.size.y > 0.001:
			_cached_baked_aabb[cache_key] = aabb
	if aabb.size.y <= 0.001:
		return
	var factor: float = target_height / aabb.size.y
	var bottom_rel: float = aabb.position.y
	node.scale = Vector3.ONE * factor
	node.position.y -= bottom_rel * factor

static func _baked_aabb_local(root: Node) -> AABB:
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	# Bone-attached details (such as a deer's antlers) have a mesh-local AABB
	# in the bone's coordinate space, which can be tens of metres wide even
	# though the rendered antlers sit correctly on the head. Normalize from the
	# skinned body first; static bone attachments inherit the same root scale.
	var skinned_meshes: Array = []
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.skin != null:
			skinned_meshes.append(mesh_instance)
	if not skinned_meshes.is_empty():
		meshes = skinned_meshes
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

static func _collect_mesh_instances(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		_collect_mesh_instances(child, result)

func _animal_asset_candidates() -> Array:
	if animal_type == "deer":
		return [
			GameConst.DEER_MODEL,
			"res://assets/external/quaternius_animals/glTF/Stag.gltf"
		]
	if animal_type == "fox":
		return [
			GameConst.FOX_MODEL
		]
	if animal_type == "bear":
		return [GameConst.BEAR_MODEL]
	if animal_type == "wolf":
		return [
			GameConst.WOLF_MODEL
		]
	return [
		GameConst.FOX_MODEL
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
	_play_animation_by_name("idle")
	if not _animation_player.current_animation.is_empty():
		return
	for animation_name in _animation_player.get_animation_list():
		var lower := animation_name.to_lower()
		if lower.find("walk") >= 0:
			_animation_player.play(animation_name)
			return

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
