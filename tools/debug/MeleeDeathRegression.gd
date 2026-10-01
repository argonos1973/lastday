extends SceneTree

# Melee-death regression: Standing Death Forward 02.glb loads and retargets to
# the character skeleton, the server tags validated melee kills with the
# "melee" cause so the victim and every remote puppet play the beaten-death
# clip ("dead_melee" travels in the generic anim field for late joiners), and
# non-melee deaths keep the procedural fall pose.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass

class TestScene extends Node:
	var hud = null
	var remote_players := {}

class ServerWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

class ServerNet extends Node:
	var is_connected := true
	var is_host := true
	var is_dedicated_server := true
	var peer = ENetMultiplayerPeer.new()
	var players: Dictionary = {}
	var client_id := 0
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return false

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _make_player() -> Node:
	var player := TestPlayer.new()
	root.add_child(player)
	return player

func _mount_model(player: Node) -> Node3D:
	var model: Node3D = load("res://assets/animations/inicio.glb").instantiate()
	player.add_child(model)
	player.third_person_model = model
	player._setup_third_person_animation(model)
	return model

func _initialize() -> void:
	print("=== MeleeDeathRegression ===")
	await process_frame
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene

	# --- Clip loads and retargets on a real player ---
	var player: Node = _make_player()
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.notice.connect(func(_t): pass)
	if player.flashlight == null:
		player.flashlight = SpotLight3D.new()
		player.add_child(player.flashlight)
	var model: Node3D = _mount_model(player)
	await process_frame

	var ap: AnimationPlayer = player.third_person_animation_player
	check(ap != null, "third_person_animation_player exists")
	check(player.third_person_melee_death_animation == "melee_death/MeleeDeathExternal",
		"melee death animation resolved (got '%s')" % player.third_person_melee_death_animation)
	check(ap.has_animation("melee_death/MeleeDeathExternal"), "player has melee_death/MeleeDeathExternal")
	var death: Animation = ap.get_animation("melee_death/MeleeDeathExternal")
	check(death != null and death.length > 1.0, "death clip has length (got %.2f)" % (death.length if death != null else -1.0))
	check(death != null and death.loop_mode == Animation.LOOP_NONE, "death clip does not loop")
	var skel: Skeleton3D = player._find_skeleton(model)
	var unresolved := 0
	for t in death.get_track_count():
		var p := str(death.track_get_path(t))
		var colon := p.rfind(":")
		if colon < 0:
			continue
		var bone := p.substr(colon + 1)
		if bone.begins_with("mixamorig") and skel.find_bone(bone) == -1:
			unresolved += 1
	check(unresolved == 0, "all death tracks resolve on the character skeleton (%d left)" % unresolved)
	# The hips position track must survive: it carries the drop to the ground.
	var hips_pos_found := false
	for t in death.get_track_count():
		if death.track_get_type(t) == Animation.TYPE_POSITION_3D and str(death.track_get_path(t)).find("Hips") >= 0:
			hips_pos_found = true
	check(hips_pos_found, "hips position track kept (corpse must fall to the ground)")

	# --- Local victim: melee cause plays the clip, procedural pose stays off ---
	player.die("melee")
	check(player.is_dead, "die(melee) marks the player dead")
	check(player._beaten_death, "die(melee) selects the beaten-death visual")
	check(ap.current_animation == "melee_death/MeleeDeathExternal" and ap.is_playing(),
		"melee death clip is playing (got '%s')" % ap.current_animation)
	check(player._get_current_anim() == "dead_melee", "synced anim carries the melee cause (got '%s')" % player._get_current_anim())
	var rot_before: Vector3 = model.rotation_degrees
	for i in range(20):
		player._update_death_pose(0.1)
	check(absf(model.rotation_degrees.x - rot_before.x) < 0.01, "procedural fall stays off during the death clip")
	# A repeated force-death with the same cause is idempotent.
	player.die("melee")
	check(player._beaten_death, "repeated melee death keeps the beaten visual")

	# --- Non-melee death keeps the procedural fall ---
	var natural: Node = _make_player()
	await process_frame
	natural.set_process(false)
	natural.set_physics_process(false)
	natural.notice.connect(func(_t): pass)
	if natural.flashlight == null:
		natural.flashlight = SpotLight3D.new()
		natural.add_child(natural.flashlight)
	var natural_model: Node3D = _mount_model(natural)
	await process_frame
	natural.die()
	check(natural.is_dead, "generic death marks the player dead")
	check(not natural._beaten_death, "generic death does not play the beaten clip")
	check(not natural.third_person_animation_player.is_playing(), "generic death stops the animation player")
	natural._update_death_pose(1.5)
	check(natural_model.rotation_degrees.x < -10.0, "generic death still runs the procedural fall")

	# --- Remote puppet: dead_melee plays the clip, dead keeps the old pose ---
	var puppet: Node = _make_player()
	await process_frame
	puppet.set_process(false)
	puppet.set_physics_process(false)
	puppet.is_puppet = true
	_mount_model(puppet)
	await process_frame
	puppet.puppet_apply(Vector3.ZERO, 0.0, "dead_melee")
	check(puppet.is_dead, "dead_melee marks the puppet dead")
	check(puppet._beaten_death, "dead_melee plays the beaten clip on the puppet")
	check(puppet.third_person_animation_player.current_animation == "melee_death/MeleeDeathExternal",
		"puppet animation player runs the melee death clip (got '%s')" % puppet.third_person_animation_player.current_animation)
	# A generic "dead" follow-up must not stomp the clip.
	puppet.puppet_apply(Vector3.ZERO, 0.0, "dead")
	check(puppet._beaten_death, "generic dead sync does not downgrade the melee death")

	var plain_puppet: Node = _make_player()
	await process_frame
	plain_puppet.set_process(false)
	plain_puppet.set_physics_process(false)
	plain_puppet.is_puppet = true
	_mount_model(plain_puppet)
	await process_frame
	plain_puppet.puppet_apply(Vector3.ZERO, 0.0, "dead")
	check(plain_puppet.is_dead and not plain_puppet._beaten_death, "generic dead puppet keeps the procedural fall")
	check(not plain_puppet.third_person_animation_player.is_playing(), "generic dead puppet stops its animation player")

	# --- Raced packets: generic "dead" first, melee tag afterwards upgrades ---
	var race_puppet: Node = _make_player()
	await process_frame
	race_puppet.set_process(false)
	race_puppet.set_physics_process(false)
	race_puppet.is_puppet = true
	_mount_model(race_puppet)
	await process_frame
	race_puppet.puppet_apply(Vector3.ZERO, 0.0, "dead")
	check(race_puppet.is_dead and not race_puppet._beaten_death, "raced puppet starts procedural-dead")
	race_puppet.puppet_apply(Vector3.ZERO, 0.0, "dead_melee")
	check(race_puppet._beaten_death, "late dead_melee upgrades the corpse to the beaten clip")
	check(race_puppet.third_person_animation_player.current_animation == "melee_death/MeleeDeathExternal",
		"upgraded corpse plays the melee death clip (got '%s')" % race_puppet.third_person_animation_player.current_animation)

	# --- Hit reaction: melee damage plays Head Hit on the victim ---
	var hitter: Node = _make_player()
	await process_frame
	hitter.set_process(false)
	hitter.set_physics_process(false)
	hitter.notice.connect(func(_t): pass)
	_mount_model(hitter)
	await process_frame
	var hit_ap: AnimationPlayer = hitter.third_person_animation_player
	check(not hitter.third_person_hit_animation.is_empty(), "hit animation resolved (got '')")
	check(hit_ap.has_animation("hit/HitExternal"), "player has hit/HitExternal")
	var client_side := ServerWorld.new()
	root.add_child(client_side)
	client_side.player = hitter
	client_side._net_apply_damage(10.0, "melee")
	check(absf(hitter.stats.health - 90.0) < 0.01, "melee hit deals damage (hp=%.1f)" % float(hitter.stats.health))
	check(hit_ap.current_animation == "hit/HitExternal" and hit_ap.is_playing(),
		"melee hit plays the flinch clip (got '%s')" % hit_ap.current_animation)
	check(hitter._get_current_anim() == "hit/HitExternal", "flinch travels through the synced anim name")
	hit_ap.stop()
	client_side._net_apply_damage(10.0, "")
	check(not hit_ap.is_playing(), "non-melee damage does not trigger the flinch")

	# --- A remote puppet replays the victim's synced flinch clip ---
	var hit_puppet: Node = _make_player()
	await process_frame
	hit_puppet.set_process(false)
	hit_puppet.set_physics_process(false)
	hit_puppet.is_puppet = true
	_mount_model(hit_puppet)
	await process_frame
	hit_puppet.puppet_apply(Vector3.ZERO, 0.0, "hit/HitExternal")
	check(hit_puppet.third_person_animation_player.current_animation == "hit/HitExternal",
		"remote puppet plays the synced flinch (got '%s')" % hit_puppet.third_person_animation_player.current_animation)

	# --- Server: only validated melee kills carry the melee cause ---
	var server := ServerWorld.new()
	root.add_child(server)
	var snet := ServerNet.new()
	server.add_child(snet)
	server.net = snet
	snet.players[9] = {"name": "attacker", "pos": Vector3(11, 0, 10), "client_id": "atk"}
	snet.players[77] = {"name": "victim_melee", "pos": Vector3(10, 0, 10), "client_id": "vic"}
	snet.players[78] = {"name": "victim_rifle", "pos": Vector3(20, 0, 20), "client_id": "vic2"}
	var attacker := Node3D.new()
	server.add_child(attacker)
	attacker.global_position = Vector3(11, 0, 10)
	attacker.set_meta("peer_id", 9)
	attacker.set_meta("client_id", "atk")
	server.server_proxies[9] = attacker
	var victim := Node3D.new()
	server.add_child(victim)
	victim.global_position = Vector3(10, 0, 10)
	victim.set_meta("peer_id", 77)
	victim.set_meta("client_id", "vic")
	victim.set_meta("proxy_health", 100.0)
	victim.set_meta("saved_inventory", [])
	server.server_proxies[77] = victim
	var victim_rifle := Node3D.new()
	server.add_child(victim_rifle)
	victim_rifle.global_position = Vector3(20, 0, 20)
	victim_rifle.set_meta("peer_id", 78)
	victim_rifle.set_meta("client_id", "vic2")
	victim_rifle.set_meta("proxy_health", 100.0)
	victim_rifle.set_meta("saved_inventory", [])
	server.server_proxies[78] = victim_rifle

	server._net_damage_player(77, 200.0, 9, "melee")
	check(victim.get_meta("proxy_dead", false), "melee kill flags the proxy dead")
	check(str(snet.players[77].get("anim", "")) == "dead_melee",
		"melee kill broadcasts dead_melee (got '%s')" % str(snet.players[77].get("anim", "")))
	server._net_damage_player(78, 200.0, 9, "rifle")
	check(victim_rifle.get_meta("proxy_dead", false), "rifle kill flags the proxy dead")
	check(str(snet.players[78].get("anim", "")) == "dead",
		"rifle kill keeps the generic dead anim (got '%s')" % str(snet.players[78].get("anim", "")))

	# --- Raced client death: notify_death lands before the validated melee hit ---
	var raced := Node3D.new()
	server.add_child(raced)
	raced.global_position = Vector3(12, 0, 10)
	raced.set_meta("peer_id", 79)
	raced.set_meta("client_id", "vic3")
	raced.set_meta("proxy_health", 8.0)
	raced.set_meta("saved_inventory", [])
	server.server_proxies[79] = raced
	snet.players[79] = {"name": "victim_raced", "pos": raced.global_position, "client_id": "vic3", "anim": ""}
	# The victim's own client flags the proxy dead before the melee RPC arrives.
	server._net_player_died(79, [], raced.global_position)
	check(raced.get_meta("proxy_dead", false), "self-report flags the raced proxy dead")
	check(str(snet.players[79].get("anim", "")) == "dead",
		"raced death starts generic (got '%s')" % str(snet.players[79].get("anim", "")))
	server._net_damage_player(79, 10.0, 9, "melee")
	check(str(snet.players[79].get("anim", "")) == "dead_melee",
		"late melee kill upgrades the raced corpse (got '%s')" % str(snet.players[79].get("anim", "")))
	# A repeat melee hit must not rebroadcast — the upgrade is one-shot.
	server._net_damage_player(79, 10.0, 9, "melee")
	check(str(snet.players[79].get("anim", "")) == "dead_melee", "repeat melee hit stays dead_melee")
	# A rifle hit on the corpse must not rewrite the cause.
	snet.players[78]["anim"] = "dead"
	server._net_damage_player(78, 10.0, 9, "rifle")
	check(str(snet.players[78].get("anim", "")) == "dead", "rifle hit on a corpse keeps generic dead")

	server.free()
	if failures == 0:
		print("PASS: melee deaths play Standing Death Forward on victim and puppets; other deaths keep the old pose")
	quit(1 if failures else 0)
