extends Node
## Reproducible combat frame profile on the REAL world with the REAL renderer
## (run windowed, not headless). Each scenario samples wall-clock frame times
## and CombatProf sections, and prints every slow frame with the events that
## happened in it. Same seed, same spots and same script before/after a change.
##
## Editor binary (fast iteration):
##   work/godot4.7/Godot.app/Contents/MacOS/Godot --path . --script tools/debug/CombatFrameProfile.gd -- [--out=/abs/file.json] [--soak=600] [--only=a,b] [--secs=8]
## Exported release client (export templates ignore --script, so the start menu
## hands over to this node when it sees the opt-in flag):
##   "build/macos/LastDay.app/Contents/MacOS/Last Day" -- --combat-profile [same options]
## Saves are never touched: the SaveGameManager autoload is swapped for a stub.
##
## Remote shooters are real PlayerController puppets driven through the same
## handlers the RPCs call on a client (_net_player_shot_rifle, _net_apply_damage),
## so the client-side cost of PvP is measured without a second machine.

const ItemScript = preload("res://scripts/Item.gd")
const GraphicsSettings = preload("res://scripts/GraphicsSettings.gd")
const SPIKE_MS := 50.0
const SPIKE_MARGIN_MS := 25.0

class NoSave extends Node:
	func has_save() -> bool:
		return true
	func load_game() -> Dictionary:
		return {}
	func save_game(_player: Dictionary, _world: Dictionary) -> bool:
		return false
	func enable_auto_save() -> void:
		pass

class ProbeWorld extends "res://scripts/Main.gd":
	signal profile_ready
	func _ready() -> void:
		await super._ready()
		profile_ready.emit()
	func _save_world_change_silent() -> void:
		pass
	func _on_player_died() -> void:
		game_over = true # keep the scene: the harness measures the death frames

var world: Node
var player: Node
var rows: Array = []
var secs := 8.0
var only: Array = []
var _rifle_item = null
var _m4_item = null
var _burst_queue: Array = [] # [{t: float, pid: int}]
# Slow-frame threshold for attribution. The idle scenario of each spot sets it
# to its own p50 + SPIKE_MARGIN_MS so hitches are judged against that spot's
# render load instead of a fixed number the baseline may already exceed.
var _spike_ms := SPIKE_MS
var _clock := 0.0

func _ready() -> void:
	call_deferred("run")

func _arg(prefix: String, fallback: String = "") -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return fallback

func _pct(sorted: Array, fraction: float) -> float:
	if sorted.is_empty():
		return 0.0
	return float(sorted[clampi(int(ceil(float(sorted.size() - 1) * fraction)), 0, sorted.size() - 1)])

func _ground(x: float, z: float) -> float:
	return float(world._get_exact_ground_y(x, z))

func _settle(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		_keep_alive()
		await get_tree().process_frame

var _nan_reported := false
func _keep_alive() -> void:
	if not _nan_reported and not (player.global_position.is_finite() and player.camera.global_transform.is_finite()):
		_nan_reported = true
		print("HARNESS_WARN player/camera transform is not finite: pos=", player.global_position, " rot=", player.rotation, " pitch=", player._pitch)
	if not _nan_reported:
		for node in get_tree().get_nodes_in_group("wildlife"):
			if node is Node3D and not (node as Node3D).global_position.is_finite():
				_nan_reported = true
				print("HARNESS_WARN animal with non-finite position: ", node.name, " type=", node.get("animal_type"), " state=", node.get("_state"))
				break
	if player.get("is_dead") == true:
		return
	player.stats.health = player.stats.max_health
	player.stats.energy = 100.0
	player.stats.hunger = 100.0
	player.stats.thirst = 100.0

func _teleport(pos: Vector3) -> void:
	player.global_position = Vector3(pos.x, _ground(pos.x, pos.z) + 0.3, pos.z)
	player.velocity = Vector3.ZERO

# Third-person camera sits behind the player: iterate so the centre ray of the
# real camera passes through the target point.
func _aim_at(point: Vector3) -> void:
	if not point.is_finite():
		print("HARNESS_WARN non-finite aim point ignored: ", point)
		return
	var cam: Camera3D = player.camera
	for i in 3:
		var from: Vector3 = cam.global_position
		var d := point - from
		player.rotation.y = atan2(-d.x, -d.z)
		player._pitch = clampf(atan2(d.y, Vector2(d.x, d.z).length()), -1.2, 1.2)
		player._recoil_pitch = 0.0
		player._recoil_yaw = 0.0
		cam.rotation.x = player._pitch
		cam.rotation.y = 0.0
		player.force_update_transform()
		cam.force_update_transform()

# Back equipment in the hands lives outside the inventory as one external unit:
# the same state use_back_item()/restore_held_item() produce.
func _hold(item) -> void:
	if player.get_held_item() == item:
		return
	player.clear_hands()
	item.quantity = 1
	player._held_selection_revision += 1
	player.held_index = -1
	player._held_item_reference = item
	player._held_item_external = true
	player._sync_held_item()

var _fire_diag_left := 3
func _fire() -> void:
	player._is_reloading = false
	player._shoot_cooldown = 0.0
	player._rifle_magazine = 5
	player._m4_magazine = 30
	player.stats.energy = 100.0
	var before := int(CombatProf.events_snapshot().get("shot.local", 0))
	player._shoot_rifle()
	if int(CombatProf.events_snapshot().get("shot.local", 0)) == before and _fire_diag_left > 0:
		_fire_diag_left -= 1
		var held = player.get_held_item()
		print("HARNESS_WARN shot did not fire: held=", (str(held.item_name) + "/" + str(held.item_type)) if held != null else "null",
			" dead=", player.is_dead, " camera=", player.camera != null, " loaded=", player._loaded_rounds(), " energy=", player.stats.energy,
			" inv=", player.inventory.items.size())

func _nearest_animal(kind: String) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("wildlife"):
		if not (node is WildlifeController) or node.is_puppet or node._is_dead or node.animal_type != kind:
			continue
		var d: float = node.global_position.distance_squared_to(player.global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

func _bring(animal: Node3D, dist: float, side: float = 0.0) -> void:
	if animal == null:
		return
	var fwd: Vector3 = -player.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var pos: Vector3 = player.global_position + fwd * dist + right * side
	animal.global_position = Vector3(pos.x, _ground(pos.x, pos.z) + 0.05, pos.z)
	animal._current_path.clear()
	animal._path_index = 0

func _animal_aim_point(animal: Node3D) -> Vector3:
	var h := 1.0
	match str(animal.animal_type):
		"wolf": h = 0.55
		"fox": h = 0.35
		"bear": h = 1.0
		"deer": h = 0.95
	return animal.global_position + Vector3(0.0, h, 0.0)

func _add_puppet(pid: int, pos: Vector3, held: String) -> void:
	var p := Vector3(pos.x, _ground(pos.x, pos.z), pos.z)
	world.net.players[pid] = {
		"name": "Probe%d" % pid, "char_name": "", "pos": p, "rot": 0.0, "anim": "rifleaim",
		"equipped_clothing": "Camiseta,Pantalones,Zapatillas", "clothing_colors": [],
		"held_item": held, "equipped_backpack": "", "is_aiming": true, "has_rifle": true,
		"sleeping": false, "sitting": false, "prone": false, "crouching": false,
		"torch_lit": false, "flashlight_on": false,
		"top_color": Color(0.3, 0.35, 0.28), "bottom_color": Color(0.22, 0.24, 0.26),
		"shoes_color": Color(0.14, 0.12, 0.10), "hair_color": Color(0.2, 0.14, 0.08),
		"skin_color": Color(0.8, 0.68, 0.56), "top_camo": false, "bottom_camo": false,
	}
	world._spawn_remote_player(pid)

func _remove_puppets(pids: Array) -> void:
	for pid in pids:
		world.net.players.erase(pid)
	world._update_remote_players()

func _face_puppets(pids: Array) -> void:
	for pid in pids:
		var data: Dictionary = world.net.players[pid]
		var to: Vector3 = player.global_position - (data.pos as Vector3)
		data.rot = atan2(-to.x, -to.z)

# One remote round exactly as the client receives it. `miss` offsets the line
# so the bullet snaps past the local player and lands in the scenery behind.
func _remote_round(pid: int, miss: float) -> void:
	var rp: Node3D = world.remote_players.get(pid)
	if rp == null or not is_instance_valid(rp):
		return
	var origin: Vector3 = rp.global_position + Vector3(0.0, 1.4, 0.0)
	var target: Vector3 = player.global_position + Vector3(miss, 1.2, 0.0)
	var dir := (target - origin).normalized()
	world._net_player_shot_rifle(pid, origin + dir * 0.8, dir, Vector3.ZERO)

func _queue_burst(pid: int, rounds: int) -> void:
	for i in rounds:
		_burst_queue.append({"t": _clock + 0.09 * float(i), "pid": pid, "miss": 1.4 + 0.3 * float(i)})

func _pump_bursts() -> void:
	var keep: Array = []
	for item in _burst_queue:
		if float(item.t) <= _clock:
			_remote_round(int(item.pid), float(item.miss))
		else:
			keep.append(item)
	_burst_queue = keep

# Samples `seconds` of real frames. `tick` runs once per frame BEFORE it renders
# with (elapsed, delta) and performs the scenario's actions.
func _scenario(label: String, seconds: float, tick: Callable) -> void:
	if not only.is_empty() and not only.has(label):
		return
	CombatProf.reset()
	CombatProf.spike_ms = _spike_ms
	var frames: Array = []
	var physics: Array = []
	var process: Array = []
	var started := Time.get_ticks_usec()
	var previous := started
	var elapsed := 0.0
	var occluded := 0
	_clock = 0.0
	_burst_queue.clear()
	while elapsed < seconds:
		_keep_alive()
		tick.call(elapsed)
		_pump_bursts()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - previous) / 1000.0
		previous = now
		elapsed = float(now - started) / 1000000.0
		_clock = elapsed
		# macOS throttles an occluded window (the drawable blocks up to 1 s):
		# those frames measure the desktop, not the game — drop them, visibly.
		if not DisplayServer.window_can_draw():
			occluded += 1
			CombatProf.end_frame(0.0)
			continue
		frames.append(ms)
		physics.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0)
		process.append(float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0)
		CombatProf.end_frame(ms)
	if frames.is_empty():
		frames.append(0.0)
		physics.append(0.0)
		process.append(0.0)
	var combat: Dictionary = CombatProf.snapshot()
	var events: Dictionary = CombatProf.events_snapshot()
	var spikes: Dictionary = CombatProf.take_spikes()
	var over_50 := 0
	var over_100 := 0
	var frame_sum := 0.0
	for ms: float in frames:
		frame_sum += ms
	var sorted := frames.duplicate()
	sorted.sort()
	var threshold := _spike_ms
	if label.contains("idle"):
		_spike_ms = maxf(SPIKE_MS, _pct(sorted, 0.50) + SPIKE_MARGIN_MS)
	var hitches := 0
	for ms: float in frames:
		if ms > 50.0: over_50 += 1
		if ms > 100.0: over_100 += 1
		if ms >= threshold: hitches += 1
	physics.sort()
	process.sort()
	var proj_usec := 0
	var proj_ticks := 0
	for key: String in ["proj.phys_frame", "proj.phys_impact", "proj.capsule_impact", "proj.phys_expired", "proj.water_impact"]:
		if combat.has(key):
			proj_usec += int(combat[key].usec)
			proj_ticks += int(combat[key].calls)
	var impact_usec := int(combat.get("proj.impact_handler", {}).get("usec", 0))
	var row := {
		"scenario": label, "frames": frames.size(), "fps": 1000.0 * float(frames.size()) / maxf(0.001, frame_sum),
		"p50": _pct(sorted, 0.50), "p95": _pct(sorted, 0.95), "p99": _pct(sorted, 0.99), "max": float(sorted.back()),
		"over_50": over_50, "over_100": over_100, "hitch_threshold": threshold, "hitches": hitches,
		"physics_p95": _pct(physics, 0.95), "physics_max": float(physics.back()), "process_p95": _pct(process, 0.95),
		"projectile_ms": float(proj_usec) / 1000.0, "projectile_ticks": proj_ticks,
		"impact_ms": float(impact_usec) / 1000.0, "impacts": int(combat.get("proj.impact_handler", {}).get("calls", 0)),
		"memory_mb": float(OS.get_static_memory_usage()) / 1048576.0, "occluded_frames": occluded,
		"events": events, "sections": combat, "spikes": spikes.samples, "spike_count": int(spikes.count),
	}
	rows.append(row)
	print("SCN %-22s fps=%5.1f p50=%6.2f p95=%6.2f p99=%6.2f max=%7.2f >50=%d >100=%d hitch(>=%.0f)=%d phys_p95=%5.2f phys_max=%6.2f proj=%7.2fms/%d impact=%6.2fms/%d mem=%.0fMB" % [
		label, row.fps, row.p50, row.p95, row.p99, row.max, over_50, over_100, threshold, hitches, row.physics_p95, row.physics_max,
		row.projectile_ms, proj_ticks, row.impact_ms, row.impacts, row.memory_mb])
	if occluded > 0:
		print("  OCCLUDED frames dropped=%d kept=%d (window occluded: not game time)" % [occluded, frames.size()])
	if not events.is_empty():
		print("  EVENTS ", events)
	var labels: Array = combat.keys()
	labels.sort_custom(func(a: String, b: String) -> bool: return int(combat[a].usec) > int(combat[b].usec))
	for index in range(mini(12, labels.size())):
		var item: Dictionary = combat[labels[index]]
		print("  SEC %-26s calls=%5d total=%8.2fms avg=%7.1fus max=%7.2fms" % [labels[index], int(item.calls), float(item.usec) / 1000.0, float(item.usec) / maxf(1.0, float(item.calls)), float(item.max_usec) / 1000.0])
	for spike: Dictionary in spikes.samples:
		var parts: Array = []
		for key: String in spike.sections_usec:
			parts.append("%s=%.2f" % [key, float(spike.sections_usec[key]) / 1000.0])
		print("  SPIKE %7.1fms events=%s sections_ms=[%s]" % [float(spike.ms), str(spike.events) if not (spike.events as Dictionary).is_empty() else "none", ", ".join(parts)])

func _combat_block(tag: String, forest: Vector3, look: Vector3) -> void:
	var state := {"next": 0.0, "animal": null}
	# -- rifle vs deer / wolf / bear: the animal is brought 26 m ahead and runs.
	for kind: String in ["deer", "wolf", "bear"]:
		_teleport(forest)
		_aim_at(look)
		_hold(_rifle_item)
		var animal := _nearest_animal(kind)
		_bring(animal, 26.0)
		await _settle(1.0)
		state.next = 0.0
		await _scenario("%srifle_%s" % [tag, kind], secs, func(t: float) -> void:
			if animal == null or not is_instance_valid(animal) or animal._is_dead:
				animal = _nearest_animal(kind)
				_bring(animal, 26.0)
			if animal != null and animal.global_position.distance_to(player.global_position) > 95.0:
				_bring(animal, 30.0)
			if animal != null and t >= float(state.next):
				state.next = t + 0.9
				_aim_at(_animal_aim_point(animal))
				_fire())
	# -- M4 bursts vs a group of animals.
	_teleport(forest)
	_aim_at(look)
	_hold(_m4_item)
	var herd: Array = []
	for kind: String in ["deer", "fox", "wolf"]:
		var a := _nearest_animal(kind)
		if a != null:
			_bring(a, 24.0 + 3.0 * float(herd.size()), -6.0 + 6.0 * float(herd.size()))
			herd.append(a)
	await _settle(1.0)
	state.next = 0.0
	await _scenario("%sm4_bursts_animals" % tag, secs, func(t: float) -> void:
		if t >= float(state.next) and not herd.is_empty():
			state.next = t + 0.55
			var a: Node3D = herd[int(t * 2.0) % herd.size()]
			if is_instance_valid(a) and not a._is_dead:
				if a.global_position.distance_to(player.global_position) > 95.0:
					_bring(a, 28.0)
				_aim_at(_animal_aim_point(a))
			_fire())
	# -- PvP: one remote sniper/M4 trading shots with the local player.
	_teleport(forest)
	_aim_at(look)
	var fwd: Vector3 = (look - forest).normalized()
	var right := fwd.cross(Vector3.UP)
	_add_puppet(5001, forest + fwd * 34.0 + right * 4.0, PlayerController.M4_NAME)
	_add_puppet(5002, forest + fwd * 38.0 - right * 9.0, "Rifle francotirador")
	for i in 40:
		world._update_remote_players()
		_face_puppets([5001, 5002])
		await get_tree().process_frame
	await _settle(1.0)
	var net_tick := {"t": 0.0}
	var sync := func(t: float) -> void:
		if t - float(net_tick.t) >= 0.05:
			net_tick.t = t
			_face_puppets([5001, 5002])
			world._update_remote_players()
	state.next = 0.0
	var remote_next := {"a": 0.3, "b": 0.6}
	_hold(_m4_item)
	await _scenario("%spvp_duel" % tag, secs, func(t: float) -> void:
		sync.call(t)
		if t >= float(state.next):
			state.next = t + 0.7
			var rp: Node3D = world.remote_players.get(5001)
			if rp != null and is_instance_valid(rp):
				_aim_at(rp.global_position + Vector3(0.0, 1.2, 0.0))
			_fire()
		if t >= float(remote_next.a):
			remote_next.a = t + 1.15
			_queue_burst(5001, 3))
	# -- Two remote players firing at once while the local player fires too.
	state.next = 0.0
	remote_next = {"a": 0.2, "b": 0.25}
	await _scenario("%stwo_shooters" % tag, secs, func(t: float) -> void:
		sync.call(t)
		if t >= float(state.next):
			state.next = t + 0.6
			_fire()
		if t >= float(remote_next.a):
			remote_next.a = t + 1.15
			_queue_burst(5001, 3)
		if t >= float(remote_next.b):
			remote_next.b = t + 1.85
			_remote_round(5002, -1.2))
	# -- Local player receiving hits (victim-side RPC) under remote fire.
	state.next = 0.4
	remote_next = {"a": 0.2, "b": 0.9}
	await _scenario("%staking_hits" % tag, secs, func(t: float) -> void:
		sync.call(t)
		if t >= float(remote_next.a):
			remote_next.a = t + 1.15
			_queue_burst(5001, 3)
		if t >= float(state.next):
			state.next = t + 1.15
			world._net_apply_damage(9.0, "m4")
		if t >= float(remote_next.b):
			remote_next.b = t + 2.4
			world._net_apply_damage(20.0, "arco"))
	_remove_puppets([5001, 5002])
	await _settle(0.5)

func run() -> void:
	secs = float(_arg("--secs=", "8"))
	var only_arg := _arg("--only=")
	if not only_arg.is_empty():
		only = Array(only_arg.split(","))
	var soak := float(_arg("--soak=", "0"))
	# Launched from the start menu in an exported client: drop the menu scene.
	var menu := get_tree().current_scene
	if menu != null:
		get_tree().current_scene = null
		menu.queue_free()
		await get_tree().process_frame
	var save_manager := get_tree().root.get_node("SaveGameManager")
	get_tree().root.remove_child(save_manager)
	save_manager.free()
	var no_save := NoSave.new()
	no_save.name = "SaveGameManager"
	get_tree().root.add_child(no_save)
	get_tree().root.get_node("GameSession").selected_character_id = ""
	Engine.max_fps = 60
	get_tree().root.size = Vector2i(1280, 720)
	# Keep the window drawable for the whole run. Without vsync an over-budget
	# frame is measured as-is instead of being rounded up to the next refresh;
	# max_fps still paces light frames at 60 like the real game.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	seed(20240611)
	CombatProf.enabled = true
	CombatProf.driver = false
	world = ProbeWorld.new()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await world.profile_ready
	player = world.player
	player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(4.0).timeout
	print("COMBAT_PROFILE_READY nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT), " wildlife=", get_tree().get_nodes_in_group("wildlife").size(),
		" renderer=", ProjectSettings.get_setting("rendering/renderer/rendering_method"), " viewport=", get_tree().root.size,
		" graphics=", GraphicsSettings.effective_snapshot(get_tree().root), " LastDayNav=", ClassDB.class_exists("LastDayNav"))
	_rifle_item = ItemScript.create("Rifle francotirador", "weapon_rifle", 3.5, 1, 0.0)
	_m4_item = ItemScript.create(PlayerController.M4_NAME, "weapon_rifle", 3.0, 1, 0.0)
	_hold(_rifle_item)
	var state := {"next": 0.0}

	# ---- House spot: fixed (the spawn point is random per session) ----------
	# "Casa abandonada 3" (_HOUSE_DOOR_LAYOUT): front wall at z = 18 + 7.5 / 2.
	var home := Vector3(26.0, 0.0, 36.0)
	var wall_target := Vector3(25.0, 1.6, 21.75)
	_teleport(home)
	_aim_at(wall_target)
	await _settle(3.0)
	await _scenario("idle_house", secs, func(_t: float) -> void: pass)
	state.next = 0.0
	await _scenario("rifle_wall", secs, func(t: float) -> void:
		if t >= float(state.next):
			state.next = t + 0.9
			_aim_at(wall_target)
			_fire())

	# ---- Forest spot ------------------------------------------------------
	var tree_pos := Vector3.INF
	var best_d := INF
	for key in world._tree_grid:
		for entry in world._tree_grid[key]:
			var tp: Vector3 = entry.pos
			var d := tp.distance_to(home)
			if d > 45.0 and d < best_d and not world._depleted_action_ids.has("fell_tree_%d" % int(entry.id)):
				best_d = d
				tree_pos = tp
	if tree_pos == Vector3.INF:
		tree_pos = home + Vector3(40.0, 0.0, 0.0)
	var back: Vector3 = home - tree_pos
	back.y = 0.0
	var forest: Vector3 = tree_pos + back.normalized() * 22.0
	var tree_target: Vector3 = tree_pos + Vector3(0.0, 1.4, 0.0)
	_teleport(forest)
	_aim_at(tree_target)
	await _settle(4.0)
	print("COMBAT_PROFILE_FOREST spot=", forest, " tree=", tree_pos)
	await _scenario("idle_forest", secs, func(_t: float) -> void: pass)
	state.next = 0.0
	_hold(_rifle_item)
	await _scenario("rifle_tree", secs, func(t: float) -> void:
		if t >= float(state.next):
			state.next = t + 0.9
			_aim_at(tree_target)
			_fire())

	await _combat_block("", forest, tree_target)

	# ---- Animal death (processing of a kill in view) ------------------------
	_teleport(forest)
	_aim_at(tree_target)
	_hold(_rifle_item)
	var victims: Array = []
	for kind: String in ["deer", "wolf", "fox"]:
		var a := _nearest_animal(kind)
		if a != null:
			_bring(a, 14.0 + 3.0 * float(victims.size()), -4.0 + 4.0 * float(victims.size()))
			victims.append(a)
	await _settle(1.0)
	state.next = 0.5
	var kill_index := {"i": 0}
	await _scenario("animal_death", minf(secs, 6.0), func(t: float) -> void:
		if t >= float(state.next) and int(kill_index.i) < victims.size():
			state.next = t + 1.5
			var a: Node3D = victims[int(kill_index.i)]
			kill_index.i = int(kill_index.i) + 1
			if is_instance_valid(a):
				_aim_at(_animal_aim_point(a))
				_fire()
				a.take_damage(9999.0, false, player))

	# ---- Bots shooting the player (host-authoritative bots, real AI) --------
	var mgr: Node = world.survivor_bot_mgr
	if mgr != null and not mgr.bots.is_empty() and (only.is_empty() or only.has("bots_fire") or only.has("idle_bots")):
		var first: Dictionary = mgr.bots[mgr.bots.keys()[0]]
		var first_proxy: Node3D = first["proxy"]
		_teleport(first_proxy.global_position + Vector3(0.0, 0.0, 18.0))
		_aim_at(first_proxy.global_position + Vector3(0.0, 1.2, 0.0))
		await _settle(4.0)
		await _scenario("idle_bots", minf(secs, 5.0), func(_t: float) -> void: pass)
		var armed := 0
		for bid in mgr.bots.keys():
			if armed >= 3:
				break
			var b: Dictionary = mgr.bots[bid]
			var proxy: Node3D = b.get("proxy")
			if proxy == null or not is_instance_valid(proxy):
				continue
			var inv: Array = proxy.get_meta("saved_inventory", [])
			inv.append({"name": "Fusil de asalto", "type": "weapon", "quantity": 1, "durability": 100.0, "max_durability": 100.0})
			inv.append({"name": "Balas 5,56", "type": "ammo", "quantity": 10, "use_value": 30})
			proxy.set_meta("saved_inventory", inv)
			proxy.set_meta("has_rifle", true)
			b["aggro_target"] = player
			b["aggro_timer"] = 120.0
			b["sense_t"] = 0.0
			b["faction"] = "hostile"
			armed += 1
		await _scenario("bots_fire", maxf(secs, 14.0), func(_t: float) -> void:
			for bid in mgr.bots.keys():
				var b: Dictionary = mgr.bots[bid]
				if b.get("aggro_target") == null:
					b["aggro_target"] = player
					b["aggro_timer"] = 120.0)
		for bid in mgr.bots.keys():
			mgr.bots[bid]["aggro_target"] = null
			mgr.bots[bid]["aggro_timer"] = 0.0

	# ---- Combat after a long session -------------------------------------
	if soak > 0.0:
		_teleport(forest)
		_aim_at(tree_target)
		print("COMBAT_PROFILE_SOAK seconds=", soak)
		await _settle(soak)
		await _scenario("soak_idle_forest", secs, func(_t: float) -> void: pass)
		await _combat_block("soak_", forest, tree_target)

	# ---- Player death (last: the corpse stays down) -------------------------
	_teleport(forest)
	_aim_at(tree_target)
	await _settle(2.0)
	state.next = 0.5
	var died := {"done": false}
	await _scenario("player_death", 3.0, func(t: float) -> void:
		if t >= 0.5 and not bool(died.done):
			died.done = true
			world._net_apply_damage(30.0, "arco")
			world._net_force_death(""))

	var out_path := _arg("--out=")
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"rows": rows, "secs": secs, "soak": soak}, "  "))
			file.close()
			print("COMBAT_PROFILE_SAVED ", out_path)
	print("COMBAT_PROFILE_DONE scenarios=", rows.size())
	world._scene_quitting = true
	get_tree().current_scene = null
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
