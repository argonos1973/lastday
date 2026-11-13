extends SceneTree
## Timing harness for the "bots shoot the player" freeze report. Measures the
## real per-shot cost of each suspect function at world scale (~9-30k nodes,
## 75 wildlife) without generating the map. Run:
##   work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/CombatShotPerf.gd

class StubAnimal extends Node3D:
	var calls := 0
	func flee_from_gunshot(_pos: Vector3, _radius: float) -> void:
		calls += 1

class StubDayCycle extends Node:
	var temp := 20.0
	func get_ambient_temperature() -> float:
		return temp

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class TestScene extends Node3D:
	var hud = null
	var day_cycle := StubDayCycle.new()
	var net = null
	var player: Node = null
	var remote_players: Dictionary = {}
	var survivor_bot_mgr = null
	# Minimal stand-ins for the analytical queries RifleProjectile runs per substep.
	var _tree_grid := {}
	func raycast_distant_props(_from_pos: Vector3, _to_pos: Vector3) -> Dictionary:
		return {}
	func get_river_surface_y_at(_world_pos: Vector3) -> float:
		return 0.085
	func get_river_depth_at(_world_pos: Vector3) -> float:
		return 0.0
	func get_day_cycle() -> Node:
		return day_cycle
	func _ready() -> void:
		add_child(day_cycle)

func _t(label: String, fn: Callable, iters: int = 1) -> void:
	var t0 := Time.get_ticks_usec()
	for i in range(iters):
		fn.call()
	var us := (Time.get_ticks_usec() - t0) / iters
	print("%9.2f us  %s  (x%d)" % [us / 1.0, label, iters])

func _initialize() -> void:
	print("=== CombatShotPerf ===")
	await process_frame
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene

	# ---- Scale 1: node tree as big as the live server world (nodes=9139) and
	# a client-like world with visual houses/props (~25k nodes).
	var filler_parent := Node3D.new()
	filler_parent.name = "Filler"
	scene.add_child(filler_parent)
	for i in range(22000):
		var n := Node3D.new()
		filler_parent.add_child(n)
	var wild_parent := Node3D.new()
	wild_parent.name = "Wildlife"
	scene.add_child(wild_parent)
	var animals: Array = []
	for i in range(75):
		var a := StubAnimal.new()
		a.add_to_group("wildlife")
		wild_parent.add_child(a)
		animals.append(a)
	await process_frame

	print("-- baseline node count: %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

	_t("get_nodes_in_group('wildlife')", func(): get_nodes_in_group("wildlife"), 20)
	_t("shot wildlife flee loop (75 calls)", func():
		for w in get_nodes_in_group("wildlife"):
			w.flee_from_gunshot(Vector3(100, 0, 100), 120.0), 20)

	# ---- Scale 2: real PlayerController (local victim) + real puppet.
	var player := TestPlayer.new()
	scene.add_child(player)
	scene.player = player
	await process_frame
	var puppet := TestPlayer.new()
	puppet.is_puppet = true
	scene.add_child(puppet)
	scene.remote_players[901] = puppet
	await process_frame

	_t("player.apply_damage rifle hit", func(): player.apply_damage(34.0, "rifle"), 20)
	player.stats.health = 100.0

	# Pools: prepare then measure warm-path bursts.
	player.prepare_combat_effects()
	await process_frame
	_t("CombatBloodEffects.burst", func(): player._spawn_blood_splatter(Vector3(1, 1, 0), 1.0), 40)
	_t("_spawn_bullet_impact (dust+chips+hole)", func():
		player._spawn_bullet_impact(Vector3(2, 0.5, 0), Vector3.UP, scene), 40)
	_t("_spawn_muzzle_flash", func(): player._spawn_muzzle_flash(Vector3.ZERO, Vector3.FORWARD), 40)

	# Muzzle flash + shoot sound + projectile for a remote shot (puppet path
	# minus the skeleton/anim parts that need a real model).
	_t("puppet play_rifle_shot_remote (stubbed body)", func():
		puppet.play_rifle_shot_remote(Vector3(5, 1.4, 0), Vector3(-1, 0, 0).normalized(), Vector3.ZERO), 30)
	# Let spawned projectiles fly a few frames so their physics cost appears.
	for i in range(30):
		await physics_frame
		await process_frame

	# ---- Projectile physics: launch N concurrent real projectiles.
	var proj_script = load("res://scripts/RifleProjectile.gd")
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 10, 200)
	cs.shape = shape
	body.add_child(cs)
	body.collision_layer = 1
	scene.add_child(body)
	await physics_frame
	# Baseline: physics frame with zero projectiles.
	var tb0 := Time.get_ticks_usec()
	for i in range(20):
		await physics_frame
	print("%9.2f us  physics frame baseline (0 projectiles)" % [(Time.get_ticks_usec() - tb0) / 20.0])
	_t("RifleProjectile add + 1st step", func():
		var p = proj_script.new()
		p.velocity = Vector3(0, 0, -780)
		p.max_distance = 150.0
		scene.add_child(p)
		p.global_position = Vector3(0, 3, 100), 30)
	for i in range(10):
		await physics_frame
	# measure steady-state per physics frame with 12 live projectiles
	var projs := []
	for i in range(12):
		var p = proj_script.new()
		p.velocity = Vector3(randf_range(-50, 50), 0, -780)
		p.max_distance = 150.0
		scene.add_child(p)
		p.global_position = Vector3(i * 2.0, 3, 100)
		projs.append(p)
	await physics_frame
	var t0 := Time.get_ticks_usec()
	for i in range(20):
		await physics_frame
	print("%9.2f us  physics frame with ~12 live projectiles" % [(Time.get_ticks_usec() - t0) / 20.0])
	for p in projs:
		if is_instance_valid(p):
			p.queue_free()

	# ---- First-time model costs: load + instantiate the M4 / sniper GLBs
	# exactly like _update_puppet_held_item -> _build_third_person_rifle does.
	_t("M4 GLB load+instantiate (cold)", func():
		PlayerController._model_cache.clear()
		var m = player._load_external_node3d(PlayerController.M4_MODEL)
		if m != null: m.queue_free(), 1)
	_t("M4 instantiate (cached PackedScene)", func():
		var m = player._load_external_node3d(PlayerController.M4_MODEL)
		if m != null: m.queue_free(), 30)
	_t("sniper GLB instantiate (cached)", func():
		var m = player._load_external_node3d(PlayerController.REAL_RIFLE_MODEL)
		if m != null: m.queue_free(), 30)

	# ---- Bot-side per-shot work (server/SP host): notify_sound_event +
	# record paths on a real SurvivorBotManager shell.
	var mgr = load("res://scripts/SurvivorBotManager.gd").new()
	mgr.world = scene
	scene.survivor_bot_mgr = mgr
	for bid in [901, 902, 903, 904, 905, 906, 907, 908, 909]:
		var px := Node3D.new()
		scene.add_child(px)
		px.global_position = Vector3(bid % 10, 0, 0)
		mgr.bots[bid] = {
			"bot_id": bid, "proxy": px, "faction": "hostile",
			"aggro_target": null, "aggro_timer": 0.0, "sense_t": 0.0,
			"sleeping": false, "sitting": false, "crouching": false,
			"hide_timer": 0.0, "health": 100.0, "team_leader_id": 0,
			"explore_target": Vector3.INF, "caution_until": 0.0,
		}
	_t("notify_sound_event gunshot (9 bots)", func():
		mgr.notify_sound_event(901, Vector3(40, 0, 0), "gunshot", 220.0), 30)
	_t("record_zone_hazard", func():
		mgr.record_zone_hazard(901, Vector3(1, 0, 1), "forest", 0.3, true), 30)
	_t("on_bot_damaged rifle", func():
		mgr.on_bot_damaged(902, 20.0, 901, "rifle"), 20)

	# AI memory snapshot + worker enqueue cost on main thread.
	_t("_ai_save_memory (snapshot+dup)", func(): mgr._ai_save_memory(), 10)

	# Bullet-hole decal churn at cap (forces eviction path).
	_t("bullet hole decal at cap", func():
		for i in range(200):
			PlayerController._bullet_holes.append(Node3D.new())
		var t := Time.get_ticks_usec()
		player._spawn_bullet_hole_decal(Vector3.ZERO, Vector3.UP, scene)
		var inner_us: float = float(Time.get_ticks_usec() - t)
		print("%9.2f us    inner decal call" % inner_us)
		PlayerController._bullet_holes.clear(), 1)

	print("=== done ===")
	quit(0)
