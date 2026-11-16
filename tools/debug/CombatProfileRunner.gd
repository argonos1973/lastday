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

# A/B switches (diagnosis only, never used for the reported numbers).
var _ab_no_flash := false

func _apply_ab() -> void:
	if not _ab_no_flash:
		return
	var actors: Array = [player]
	actors.append_array(world.remote_players.values())
	for actor in actors:
		if is_instance_valid(actor):
			var flash: Node = actor.get_node_or_null("MuzzleFlash")
			if flash != null and flash.get("light") != null:
				flash.light.visible = false

var _nan_reported := false
func _keep_alive() -> void:
	_apply_ab()
	if not _nan_reported and not (player.global_position.is_finite() and player.camera.global_transform.is_finite()):
		_nan_reported = true
		print("HARNESS_WARN player/camera transform is not finite: pos=", player.global_position, " rot=", player.rotation, " pitch=", player._pitch)
	if not _nan_reported:
		for node in get_tree().get_nodes_in_group("wildlife"):
			if node is Node3D and not (node as Node3D).global_position.is_finite():
				_nan_reported = true
				print("HARNESS_WARN animal with non-finite position: ", node.name, " type=", node.get("animal_type"), " state=", node.get("_state"))
				break
	if player.get("is_dead") == true or _health_locked:
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
	if not only.is_empty() and not only.has(label) and not label.begins_with("idle_forest_adj"):
		return
	await _wait_drawable()
	CombatProf.reset()
	CombatProf.spike_ms = _spike_ms
	var frames: Array = []
	var physics: Array = []
	var process: Array = []
	var render_cpu: Array = []
	var render_gpu: Array = []
	# Frame classes: frames with a shot, with a projectile impact, the frame
	# right after a shot, and quiet frames (the scenario's own baseline).
	var classes := {"shot": [], "impact": [], "after_shot": [], "quiet": []}
	var previous_was_shot := false
	var vp: RID = get_tree().root.get_viewport_rid()
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
		var rc := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		var rg := RenderingServer.viewport_get_measured_render_time_gpu(vp)
		render_cpu.append(rc)
		render_gpu.append(rg)
		var ev: Dictionary = CombatProf.frame_events()
		var is_shot := ev.has("shot.local") or ev.has("rpc.shot_rifle")
		if is_shot:
			classes.shot.append(ms)
		elif CombatProf.frame_has("proj.impact_handler"):
			classes.impact.append(ms)
		elif previous_was_shot:
			classes.after_shot.append(ms)
		else:
			classes.quiet.append(ms)
		previous_was_shot = is_shot
		CombatProf.end_frame(ms, {"render_cpu_ms": rc, "render_gpu_ms": rg})
	if frames.size() < 10:
		print("SCN %-22s SKIPPED: window occluded (%d frames dropped, %d kept)" % [label, occluded, frames.size()])
		rows.append({"scenario": label, "skipped": true, "occluded_frames": occluded})
		return
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
	render_cpu.sort()
	render_gpu.sort()
	var class_stats := {}
	for key: String in classes:
		var values: Array = classes[key]
		if values.is_empty():
			continue
		values.sort()
		var total := 0.0
		for v: float in values:
			total += v
		class_stats[key] = {"n": values.size(), "p50": _pct(values, 0.5), "mean": total / float(values.size()), "max": float(values.back())}
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
		"render_cpu_p50": _pct(render_cpu, 0.5), "render_cpu_p95": _pct(render_cpu, 0.95), "render_cpu_max": float(render_cpu.back()),
		"render_gpu_p50": _pct(render_gpu, 0.5), "render_gpu_p95": _pct(render_gpu, 0.95), "frame_classes": class_stats,
		"events": events, "sections": combat, "spikes": spikes.samples, "spike_count": int(spikes.count),
	}
	rows.append(row)
	print("SCN %-22s fps=%5.1f p50=%6.2f p95=%6.2f p99=%6.2f max=%7.2f >50=%d >100=%d hitch(>=%.0f)=%d phys_p95=%5.2f phys_max=%6.2f proj=%7.2fms/%d impact=%6.2fms/%d mem=%.0fMB" % [
		label, row.fps, row.p50, row.p95, row.p99, row.max, over_50, over_100, threshold, hitches, row.physics_p95, row.physics_max,
		row.projectile_ms, proj_ticks, row.impact_ms, row.impacts, row.memory_mb])
	print("  RENDER cpu_p50=%.2f cpu_p95=%.2f cpu_max=%.2f gpu_p50=%.2f gpu_p95=%.2fms" % [row.render_cpu_p50, row.render_cpu_p95, row.render_cpu_max, row.render_gpu_p50, row.render_gpu_p95])
	var class_parts: Array = []
	for key: String in class_stats:
		class_parts.append("%s[n=%d p50=%.1f mean=%.1f max=%.1f]" % [key, int(class_stats[key].n), float(class_stats[key].p50), float(class_stats[key].mean), float(class_stats[key].max)])
	print("  FRAMES ", " ".join(class_parts))
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
		var extra: Dictionary = spike.get("extra", {})
		print("  SPIKE %7.1fms render_cpu=%6.1f render_gpu=%6.1f events=%s sections_ms=[%s]" % [float(spike.ms), float(extra.get("render_cpu_ms", 0.0)), float(extra.get("render_gpu_ms", 0.0)), str(spike.events) if not (spike.events as Dictionary).is_empty() else "none", ", ".join(parts)])

# Diagnosis: does the first positional light on a set of materials stall the
# draw, and does a zero-energy light already count? Bare lights, no gameplay.
# Each line lists frame_ms/render_cpu_ms per frame; render time is reported by
# the engine one frame late, so a stall shows on the frame after its cause.
func _probe_light_variants() -> void:
	var vp: RID = get_tree().root.get_viewport_rid()
	var base: Vector3 = player.global_position
	var steps := [
		["omni_zero_energy", "omni", 0.0, Vector3.ZERO],
		["omni_then_lit", "omni", 5.0, Vector3.ZERO],
		["omni_lit_again", "omni", 5.0, Vector3.ZERO],
		["spot_lit", "spot", 5.0, Vector3.ZERO],
		["spot_lit_again", "spot", 5.0, Vector3.ZERO],
		["omni_lit_25m_away", "omni", 5.0, Vector3(0.0, 0.0, -25.0)],
		["omni_lit_25m_again", "omni", 5.0, Vector3(0.0, 0.0, -25.0)],
	]
	for step: Array in steps:
		await _wait_drawable()
		var light: Light3D
		if str(step[1]) == "omni":
			var omni := OmniLight3D.new()
			omni.omni_range = 7.0
			light = omni
		else:
			var spot := SpotLight3D.new()
			spot.spot_range = 9.0
			spot.spot_angle = 80.0
			light = spot
		light.light_energy = float(step[2])
		light.shadow_enabled = false
		var previous := Time.get_ticks_usec()
		var line: Array = []
		for frame in 8:
			if frame == 2:
				world.add_child(light)
				light.global_position = base + (step[3] as Vector3) + Vector3(0.0, 1.5, 0.0)
				light.rotation_degrees = Vector3(-80.0, 0.0, 0.0)
			if frame == 5:
				light.queue_free()
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			line.append("%s%.0f/%.0f" % ["*" if frame >= 2 and frame < 5 else "", float(now - previous) / 1000.0, RenderingServer.viewport_get_measured_render_time_cpu(vp)])
			previous = now
		print("PROBE_LIGHT %-20s drawable=%s frame_ms/render_cpu_ms (* = light present): %s" % [str(step[0]), DisplayServer.window_can_draw(), " ".join(line)])
		await _settle(0.4)

# Runs `action` once and returns the slowest of the next frames: the cost of
# doing that thing for the first (or second) time, isolated from everything else.
func _probe_step(label: String, action: Callable, frames_after: int = 5) -> float:
	await _wait_drawable()
	var quiet: Array = []
	var previous := Time.get_ticks_usec()
	for i in 6:
		_keep_alive()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		quiet.append(float(now - previous) / 1000.0)
		previous = now
	quiet.sort()
	var base: float = quiet[quiet.size() / 2]
	var script_started := Time.get_ticks_usec()
	action.call()
	var script_ms := float(Time.get_ticks_usec() - script_started) / 1000.0
	var worst := 0.0
	var line: Array = []
	previous = Time.get_ticks_usec()
	for i in frames_after:
		if player.get("is_dead") != true:
			_keep_alive()
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := float(now - previous) / 1000.0
		previous = now
		worst = maxf(worst, ms)
		line.append("%.0f" % ms)
	print("PROBE_STEP %-26s base=%5.1f worst=%7.1f excess=%7.1f script=%6.2fms frames=[%s]" % [label, base, worst, worst - base, script_ms, " ".join(line)])
	probe_rows.append({"step": label, "base": base, "worst": worst, "excess": worst - base, "script_ms": script_ms})
	return worst - base

var probe_rows: Array = []

# First use vs second use of every combat effect, in view, one at a time.
func _probe_first_use() -> void:
	var cam: Camera3D = player.camera
	var fwd: Vector3 = -cam.global_transform.basis.z
	var point: Vector3 = cam.global_position + fwd * 5.0
	var floor_point := Vector3(point.x, _ground(point.x, point.z) + 0.02, point.z)
	var dust := Color(0.42, 0.36, 0.30)
	for pass_name: String in ["first", "again"]:
		await _probe_step("muzzle_flash." + pass_name, func() -> void: player._spawn_muzzle_flash(point, fwd))
		await _settle(0.4)
		await _probe_step("blood." + pass_name, func() -> void: player._spawn_blood_splatter(point, 1.0))
		await _probe_step("impact_dust." + pass_name, func() -> void: player._spawn_impact_dust(floor_point, Vector3.UP, dust))
		await _probe_step("impact_chips." + pass_name, func() -> void: player._spawn_impact_chips(floor_point, Vector3.UP, dust, false))
		await _probe_step("impact_sparks." + pass_name, func() -> void: player._spawn_impact_chips(floor_point, Vector3.UP, dust, true))
		await _probe_step("bullet_hole." + pass_name, func() -> void: player._spawn_bullet_hole_decal(floor_point, Vector3.UP, world))
		await _probe_step("shoot_sound." + pass_name, func() -> void: player._play_shoot_sound(false))
		_hold(_rifle_item)
		await _settle(0.5)
		await _probe_step("local_shot_rifle." + pass_name, func() -> void: _fire())
		await _settle(1.2)
		_hold(_m4_item)
		await _settle(0.5)
		await _probe_step("local_shot_m4." + pass_name, func() -> void: _fire())
		await _settle(1.2)
		await _probe_step("hit_taken_m4." + pass_name, func() -> void: world._net_apply_damage(6.0, "m4"))
		await _settle(1.0)
		await _probe_step("hit_taken_bow." + pass_name, func() -> void: world._net_apply_damage(6.0, "arco"))
		await _settle(1.0)

# Does toggling Environment adjustments (the low-health desaturation) rebuild
# the scene shaders? Also samples the steady cost of leaving them enabled.
func _probe_environment_adjust() -> void:
	var env: Environment = world.day_cycle.world_environment.environment
	var hud: Node = world.hud
	# The HUD owns the flag every frame: park it so the probe is the only writer.
	var hud_overlay = hud.get("_damage_overlay")
	hud.set("_damage_overlay", null)
	print("PROBE_ADJUST initial adjustment_enabled=", env.adjustment_enabled)
	var initial := env.adjustment_enabled
	await _probe_step("adjust.flip_1", func() -> void: env.adjustment_enabled = not initial, 6)
	await _scenario("idle_forest_adj_%s" % ("on" if env.adjustment_enabled else "off"), 5.0, func(_t: float) -> void: pass)
	await _probe_step("adjust.flip_back", func() -> void: env.adjustment_enabled = initial, 6)
	await _scenario("idle_forest_adj_%s" % ("on" if env.adjustment_enabled else "off"), 5.0, func(_t: float) -> void: pass)
	await _probe_step("adjust.flip_again", func() -> void: env.adjustment_enabled = not initial, 6)
	await _probe_step("adjust.restore", func() -> void: env.adjustment_enabled = initial, 6)
	# Picture check: is the neutral-adjustment image the same picture? Compare
	# against the frame-to-frame difference of the unchanged scene (wind, sky).
	env.adjustment_enabled = false
	await _settle(0.5)
	var off_a := await _grab()
	var off_b := await _grab()
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.0
	env.adjustment_saturation = 1.0
	await _settle(0.5)
	var on_a := await _grab()
	var on_b := await _grab()
	env.adjustment_enabled = false
	await _settle(0.3)
	var off_c := await _grab()
	print("PROBE_ADJUST_IMAGE mean_abs_diff_per_channel(0-255): off_vs_off=%.3f on_vs_on=%.3f off_vs_on=%.3f on_vs_off_after=%.3f" % [
		_image_diff(off_a, off_b), _image_diff(on_a, on_b), _image_diff(off_b, on_a), _image_diff(on_b, off_c)])
	var shot_dir := _arg("--shots=")
	if not shot_dir.is_empty():
		off_b.save_png(shot_dir.path_join("adjust_off.png"))
		on_a.save_png(shot_dir.path_join("adjust_on_neutral.png"))
	env.adjustment_enabled = initial
	hud.set("_damage_overlay", hud_overlay)

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	await get_tree().process_frame
	return image

func _mean_luma(a: Image) -> float:
	var da := a.get_data()
	if da.is_empty():
		return -1.0
	var total := 0.0
	var count := 0
	for i in range(0, da.size() - 3, 28):
		total += 0.299 * float(da[i]) + 0.587 * float(da[i + 1]) + 0.114 * float(da[i + 2])
		count += 1
	return total / float(count)

# El grading de salud baja por overlay de pantalla: la imagen herida debe
# oscurecer/desaturar (no quedar negra ni igual) y el cruce no debe costar
# el ~1 s que costaba la variante de Environment.
var _health_locked := false

func _probe_health_grade() -> void:
	if world.player == null or world.player.stats == null:
		return
	var stats = world.player.stats
	var full_hp := float(stats.max_health)
	var saved := float(stats.health)
	stats.health = full_hp
	await _settle(0.4)
	var healthy_a := await _grab()
	_health_locked = true
	await _probe_step("grade.hurt_flip", func() -> void: stats.health = full_hp * 0.4, 6)
	var hurt := await _grab()
	await _probe_step("grade.heal_flip", func() -> void: stats.health = full_hp, 6)
	_health_locked = false
	var healthy_b := await _grab()
	var lum_h := _mean_luma(healthy_a)
	var lum_hurt := _mean_luma(hurt)
	print("PROBE_GRADE diff healthy_vs_hurt=%.2f healthy_vs_healed=%.2f luma healthy=%.1f hurt=%.1f ratio=%.2f" % [
		_image_diff(healthy_a, hurt), _image_diff(healthy_a, healthy_b), lum_h, lum_hurt, lum_hurt / maxf(lum_h, 0.01)])
	var shot_dir := _arg("--shots=")
	if not shot_dir.is_empty():
		healthy_a.save_png(shot_dir.path_join("grade_healthy.png"))
		hurt.save_png(shot_dir.path_join("grade_hurt.png"))
	stats.health = saved

func _image_diff(a: Image, b: Image) -> float:
	var da := a.get_data()
	var db := b.get_data()
	if da.size() != db.size() or da.is_empty():
		return -1.0
	var total := 0
	var step := 7 # sample every 7th byte: ~130k samples, all channels
	var count := 0
	for i in range(0, da.size(), step):
		total += absi(int(da[i]) - int(db[i]))
		count += 1
	return float(total) / float(count)

# The death of the local player, one stage per frame group, then the real call.
func _probe_death_steps() -> void:
	await _probe_step("death.view_mode", func() -> void: player._apply_view_mode())
	await _probe_step("death.stats_dead_signal", func() -> void:
		player.stats.health = 0.0
		player.stats.changed.emit())
	await _probe_step("death.unequip_clothing", func() -> void:
		for slot in player._equipped_slots.keys():
			var equipped_item := str(player._equipped_slots[slot])
			if not equipped_item.is_empty():
				player.unequip_clothing(equipped_item))
	await _probe_step("death.clip", func() -> void: player._apply_melee_death_visual(), 8)
	await _probe_step("death.full_die_call", func() -> void: world._net_force_death(""), 8)

# The user's desktop can cover the window (another Space, a full-screen app):
# an occluded window is not drawn, so wait instead of sampling nothing.
func _wait_drawable() -> void:
	if DisplayServer.window_can_draw():
		return
	print("HARNESS_WAIT window occluded - waiting until it is visible again")
	var until := Time.get_ticks_msec() + 180000
	while not DisplayServer.window_can_draw() and Time.get_ticks_msec() < until:
		DisplayServer.window_move_to_foreground()
		_keep_alive()
		await get_tree().process_frame
	await _settle(1.0)

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
	_ab_no_flash = OS.get_cmdline_user_args().has("--ab-no-flash")
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
	RenderingServer.viewport_set_measure_render_time(get_tree().root.get_viewport_rid(), true)
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
	if OS.get_cmdline_user_args().has("--probe-light"):
		await _probe_light_variants()
	if OS.get_cmdline_user_args().has("--probe-grade"):
		await _probe_health_grade()
	if OS.get_cmdline_user_args().has("--probe-adjust"):
		await _probe_environment_adjust()
	if OS.get_cmdline_user_args().has("--probe-first-use"):
		await _probe_first_use()
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

	if OS.get_cmdline_user_args().has("--probe-death"):
		_teleport(forest)
		_aim_at(tree_target)
		await _settle(2.0)
		await _probe_death_steps()

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
			file.store_string(JSON.stringify({"rows": rows, "probes": probe_rows, "secs": secs, "soak": soak}, "  "))
			file.close()
			print("COMBAT_PROFILE_SAVED ", out_path)
	print("COMBAT_PROFILE_DONE scenarios=", rows.size())
	world._scene_quitting = true
	get_tree().current_scene = null
	world.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()
