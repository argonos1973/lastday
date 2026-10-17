extends SceneTree

# Reproduce "player dies on its own when entering the world".
# Loads the real Main.tscn, waits for the player, prints the nearest
# threat to every spawn zone, then logs the player state each second
# for PLAYER_LIFE seconds of player lifetime.

const PLAYER_LIFE := 60.0

var _elapsed := 0.0
var _player_age := 0.0
var _log_acc := 0.0
var _scene = null
var _last_hp := -1.0
var _threats_done := false
var _violations := 0
var _moved := false
var _save_backups := {}

# The run can end in a player death, and single-player death deletes the
# real savegame — snapshot the user:// save files first and put them back
# on every exit so the test never eats the user's actual saves.
func _backup_saves() -> void:
	for fname in ["savegame.json", "savegame.bak.json", "server_savegame.json"]:
		var p := "user://saves/%s" % fname
		if FileAccess.file_exists(p):
			_save_backups[p] = FileAccess.get_file_as_bytes(p)

func _restore_saves() -> void:
	for p in _save_backups.keys():
		var f := FileAccess.open(p, FileAccess.WRITE)
		if f != null:
			f.store_buffer(_save_backups[p])
			f.close()

func _finish(code: int) -> void:
	_restore_saves()
	quit(code)

func _initialize() -> void:
	print("=== SpawnDeathRepro ===")
	call_deferred("run")

func run() -> void:
	_backup_saves()
	if "--saved" in OS.get_cmdline_user_args():
		var gsess = root.get_node_or_null("/root/GameSession")
		if gsess != null:
			gsess.selected_character_id = "saved"
			print("[repro] forcing saved-character path (Continuar)")
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		print("FAIL: could not load Main.tscn")
		_finish(1)
		return
	_scene = packed.instantiate()
	root.add_child(_scene)
	current_scene = _scene
	print("[repro] Main.tscn instantiated, waiting for player...")

func _threat_report() -> void:
	_threats_done = true
	var wolves: Array = []
	var bears: Array = []
	var npcs: Array = []
	for n in get_nodes_in_group("wildlife"):
		if n is Node3D and not n.get("_is_dead"):
			if str(n.get("animal_type")) == "wolf":
				wolves.append(n)
			elif str(n.get("animal_type")) == "bear":
				bears.append(n)
	for n in get_nodes_in_group("npc"):
		if n is Node3D and not n.get("is_dead"):
			npcs.append(n)
	var fires: Array = _scene.get("campfire_positions") if _scene.get("campfire_positions") != null else []
	print("[repro] threat census: wolves=%d bears=%d npcs=%d fires=%d" % [wolves.size(), bears.size(), npcs.size(), fires.size()])
	for sz in _scene._spawn_zones:
		var wd := INF
		for w in wolves:
			wd = minf(wd, Vector2(w.global_position.x - sz.x, w.global_position.z - sz.z).length())
		var bd := INF
		for b in bears:
			bd = minf(bd, Vector2(b.global_position.x - sz.x, b.global_position.z - sz.z).length())
		var nd := INF
		for n in npcs:
			nd = minf(nd, Vector2(n.global_position.x - sz.x, n.global_position.z - sz.z).length())
		var fd := INF
		for fp in fires:
			if fp is Vector3:
				fd = minf(fd, Vector2(fp.x - sz.x, fp.z - sz.z).length())
		var gy: float = _scene._get_ground_height(sz)
		print("[repro] zone %s ground=%.2f wolf=%.0f bear=%.0f npc=%.0f fire=%.0f" % [sz, gy, wd, bd, nd, fd])

func _process(delta: float) -> bool:
	_elapsed += delta
	if _scene == null or not is_instance_valid(_scene):
		return false
	var player = _scene.get("player")
	if player == null or not is_instance_valid(player):
		if _elapsed > 400.0:
			print("[repro] TIMEOUT waiting for player")
			_finish(1)
		return false
	if not _threats_done:
		_threat_report()
	_player_age += delta
	_log_acc += delta
	var s = player.stats
	var prot: float = player.get_meta("protection_timer", 0.0)
	# A real player would react to the wolf: simulate it by walking away once
	# protection expires so the AFK death afterwards does not mask regressions.
	if not _moved and prot <= 0.0 and _player_age > 1.0:
		_moved = true
		var away := Vector3(30.0, 0.0, 30.0)
		for n in get_nodes_in_group("wildlife"):
			if n is Node3D and not n.get("_is_dead") and str(n.get("animal_type")) in ["wolf", "bear"]:
				var d: float = Vector2(n.global_position.x - player.global_position.x, n.global_position.z - player.global_position.z).length()
				if d < 60.0:
					away = (player.global_position - n.global_position).normalized() * 60.0
					away.y = 0.0
		player.global_position += away
		print("[repro] protection expired at age=%.1f — moving player to %s" % [_player_age, player.global_position])
	if _last_hp < 0.0:
		_last_hp = s.health
	elif s.health < _last_hp - 0.01:
		var pos_now: Vector3 = player.global_position
		var drop: float = _last_hp - s.health
		if drop >= 0.5:
			print("[repro] HP DROP %.1f -> %.1f at t=%.0f pos=%s prot=%.1f" % [_last_hp, s.health, _elapsed, pos_now, prot])
			if prot > 0.0 and drop >= 2.0:
				_violations += 1
				print("[repro] FAIL: predator-scale damage while spawn protection active")
		_last_hp = s.health
	elif s.health > _last_hp:
		_last_hp = s.health
	var pos: Vector3 = player.global_position
	var nearest_wolf := INF
	var wolf_state := ""
	for n in get_nodes_in_group("wildlife"):
		if n is Node3D and not n.get("_is_dead") and str(n.get("animal_type")) in ["wolf", "bear"]:
			var d: float = Vector2(n.global_position.x - pos.x, n.global_position.z - pos.z).length()
			if d < nearest_wolf:
				nearest_wolf = d
				wolf_state = "%s:%s" % [n.get("animal_type"), n.get("_state")]
	if player.is_dead or s.dead or _scene.get("game_over"):
		if prot > 0.0:
			print("[repro] FAIL: PLAYER DIED inside spawn protection at age=%.1f pos=%s" % [_player_age, pos])
			_finish(1)
		else:
			# AFK death after the grace window is legitimate exposure (wolf
			# territory, cold, starvation) — only entry-window kills are bugs.
			print("[repro] player died post-protection at age=%.1f pos=%s (AFK exposure, not an entry kill)" % [_player_age, pos])
			_finish(0 if _violations == 0 else 1)
		return true
	if _log_acc < 5.0:
		return false
	_log_acc = 0.0
	print("[repro] age=%.0f pos=%s hp=%.1f prot=%.1f hunger=%.1f thirst=%.1f sleep=%.1f temp=%.2f dead=%s/%s fall=%s max_fall=%.1f water=%s/%.2f floor=%s pred=%s@%.1f" % [
		_player_age, pos, s.health, prot, s.hunger, s.thirst, s.sleep, s.body_temperature,
		player.is_dead, s.dead, player._is_falling_from_height, player._max_fall_height,
		player.is_in_water, player._water_depth, player.is_on_floor(), wolf_state, nearest_wolf])
	if wolf_state.ends_with("chase_player") and prot > 0.0:
		_violations += 1
		print("[repro] FAIL: predator chasing while spawn protection active")
	if _player_age >= PLAYER_LIFE:
		if _violations == 0:
			print("[repro] survived %ds of player life, no spontaneous death" % int(PLAYER_LIFE))
		else:
			print("[repro] %d protection violations" % _violations)
		_finish(0 if _violations == 0 else 1)
		return true
	return false
