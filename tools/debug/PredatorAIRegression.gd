extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const WildlifeControllerScript = preload("res://scripts/WildlifeController.gd")

class TestMain extends MainScript:
	func _ready() -> void:
		pass
	func is_wildlife_allowed_at(_pos: Vector3) -> bool:
		return true
	func is_wolf_allowed_at(_pos: Vector3) -> bool:
		return true
	func _is_near_road(_pos: Vector3, _margin: float) -> bool:
		return false
	func _is_near_wildlife_blocker(_pos: Vector3, _extra_margin: float = 0.0) -> bool:
		return false
	func _is_pos_wolf_protected(_pos: Vector3) -> bool:
		return false
	func _get_exact_ground_y(_x: float, _z: float, _fallback: float = 0.0) -> float:
		return 0.0

class TestPredator extends WildlifeControllerScript:
	var last_sound := ""
	func _build_animal() -> void:
		pass
	func _play_animation_by_name(keyword: String) -> void:
		current_anim_keyword = keyword.to_lower()
	func _play_wolf_sound(sound: String) -> void:
		last_sound = sound
	func _compute_wolf_separation(_radius: float) -> Vector3:
		return Vector3.ZERO
	func _is_near_lit_campfire(_pos: Vector3, _radius: float) -> bool:
		return false
	func _can_reach_player() -> bool:
		return true

class TestPlayer extends Node3D:
	var health := 100.0
	var is_prone := false
	var is_crouching := false
	var is_sprinting := false
	var is_moving := false
	var _torch_lit := false
	func apply_damage(amount: float) -> void:
		health -= amount

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := TestMain.new()
	root.add_child(world)
	current_scene = world

	var player := TestPlayer.new()
	world.add_child(player)

	# 1. Sigilo por postura (de pie, agachado, tumbado, corriendo)
	var wolf := TestPredator.new()
	world.add_child(wolf)
	wolf.setup("wolf", [Vector3.ZERO, Vector3(10, 0, 0)])
	wolf._chase_cooldown = 0.0
	wolf._player = player
	wolf._wolf_hunger = 100.0
	wolf._wolf_hunger_threshold = 0.0

	player.global_position = Vector3(28, 0, 0)
	player.is_prone = true
	wolf._state = "patrol"
	wolf._wolf_ai(0.05)
	check(wolf._state == "patrol", "Prone player at 28m is undetected by wolf (prone range ~12.6m)")

	player.is_prone = false
	player.is_crouching = true
	player.global_position = Vector3(28, 0, 0)
	wolf._state = "patrol"
	wolf._wolf_ai(0.05)
	check(wolf._state == "patrol", "Crouching player at 28m is undetected by wolf (crouch range ~23.4m)")

	player.is_crouching = false
	player.is_sprinting = true
	player.global_position = Vector3(40, 0, 0)
	wolf._state = "patrol"
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player", "Sprinting player at 40m is detected by wolf (sprint range ~45m)")
	wolf._state = "patrol"
	player.global_position = Vector3(60, 0, 0)
	wolf._wolf_ai(0.05)
	check(wolf._state == "patrol", "Sprinting player at 60m stays unnoticed (outside sprint range ~45m)")
	player.is_sprinting = false

	# 2. Antorcha encendida mantiene al lobo salvaje a raya ("wary_torch")
	player._torch_lit = true
	player.global_position = Vector3(4.0, 0, 0)
	wolf.global_position = Vector3.ZERO
	wolf._state = "chase_player"
	var torch_res: Dictionary = wolf._wolf_ai(0.05)
	check(wolf._state == "wary_torch" and player.health == 100.0, "Lit torch keeps uninjured wild wolf at bay without biting")
	check(torch_res["target"].distance_to(player.global_position) > 4.0, "Wolf backs away from close lit torch")
	player._torch_lit = false

	# 3. Alerta de manada, flanqueo y rodeo entre mordiscos
	var mate := TestPredator.new()
	world.add_child(mate)
	mate.setup("wolf", [Vector3(0, 0, 12), Vector3(10, 0, 12)])
	mate._chase_cooldown = 0.0
	mate._state = "patrol"
	var pack_list: Array = [wolf, mate]
	wolf._cached_wildlife = pack_list
	mate._cached_wildlife = pack_list

	player.global_position = Vector3(14, 0, 0)
	wolf.global_position = Vector3.ZERO
	wolf._state = "patrol"
	wolf._chase_cooldown = 0.0
	wolf._wolf_ai(0.05)
	check(wolf._state == "chase_player" and mate._state == "chase_player" and mate._chase_target == player, "Wolf entering chase alerts nearby pack mate to join pursuit")

	# Flanqueo a media distancia cuando hay compañero persiguiendo
	wolf.global_position = Vector3.ZERO
	player.global_position = Vector3(10, 0, 0)
	var flank_res: Dictionary = wolf._wolf_ai(0.05)
	check(absf(flank_res["target"].z) > 1.0, "Pack wolf offsets target laterally to flank prey at mid-range")

	# Rodeo activo (strafe) en rango de mordisco en vez de quedarse quieto (speed > 0)
	player.global_position = Vector3(2.0, 0, 0)
	wolf._attack_cooldown = 2.0
	var melee_res: Dictionary = wolf._wolf_ai(0.05)
	check(float(melee_res["speed"]) > 0.0, "Wolf circles laterally between bites instead of standing still")
	mate.free()

	# 4. Lobo salvaje huye de un oso cercano y huye más tiempo si está gravemente herido
	var bear := TestPredator.new()
	world.add_child(bear)
	bear.setup("bear", [Vector3(8, 0, 0), Vector3(20, 0, 0)])
	wolf.global_position = Vector3.ZERO
	wolf._cached_wildlife = [wolf, bear]
	var flee_bear_res: Dictionary = wolf._wolf_ai(0.05)
	check(wolf._state == "patrol" and flee_bear_res["target"].x < 0.0, "Wild wolf yields and flees away from a nearby live bear")

	wolf.health = 100.0
	wolf.take_damage(60.0, false, player) # queda en 40 HP (<= 25% de 240)
	check(wolf._prey_flee_timer >= 14.0 and wolf._chase_cooldown >= 16.0, "Critically wounded wolf flees for a longer recovery window")
	wolf.free()

	# 5. Oso territorial: fase de aviso ("bear_warn"), desescalada si te alejas, carga si te acercas, y límite de territorio
	bear.global_position = Vector3.ZERO
	bear.patrol_points = [Vector3.ZERO, Vector3(10, 0, 0)]
	bear._cached_wildlife = [bear]
	bear._player = player
	bear._state = "patrol"
	bear._chase_cooldown = 0.0
	bear.health = bear.max_health

	player.global_position = Vector3(30, 0, 0)
	bear._wolf_ai(0.05)
	check(bear._state == "bear_warn" and bear.last_sound == "growl", "Bear enters territorial warning state when player is at mid-range (30m)")

	player.global_position = Vector3(40, 0, 0)
	bear._wolf_ai(0.05)
	check(bear._state == "patrol" and bear._chase_cooldown > 0.0, "Bear stands down and returns to patrol if player backs away during warning")

	bear._chase_cooldown = 0.0
	player.global_position = Vector3(28, 0, 0)
	bear._wolf_ai(0.05)
	check(bear._state == "bear_warn", "Bear warns again when player re-enters mid-range")
	player.global_position = Vector3(18, 0, 0)
	bear._wolf_ai(0.05)
	check(bear._state == "chase_player", "Bear charges immediately when player steps inside 22m personal space")

	player.global_position = Vector3(125, 0, 0)
	bear.global_position = Vector3(80, 0, 0)
	bear._wolf_ai(0.05)
	check(bear._state == "retreat", "Uninjured bear stops chasing and retreats when player leaves its 115m territory")
	bear.free()

	# 6. Ciervos: detección por oído (sprint/caminar vs agachado/tumbado), animación gallop y huida en manada al disparar
	var deer1 := TestPredator.new()
	var deer2 := TestPredator.new()
	world.add_child(deer1)
	world.add_child(deer2)
	deer1.setup("deer", [Vector3.ZERO, Vector3(10, 0, 0)])
	deer2.setup("deer", [Vector3(14, 0, 0), Vector3(24, 0, 0)])
	deer1._player = player
	deer2._player = player
	deer1._cached_wildlife = [deer1, deer2]
	deer2._cached_wildlife = [deer1, deer2]

	player.is_crouching = true
	player.is_sprinting = false
	player.is_moving = true
	player.global_position = Vector3(18, 0, 0)
	deer1.global_position = Vector3.ZERO
	deer1._prey_flee_timer = 0.0
	deer1._state = "patrol"
	deer1._prey_ai(0.05)
	check(deer1._state == "patrol", "Crouching hunter at 18m does not spook deer (crouch alert range 12m)")

	player.is_crouching = false
	player.is_moving = true
	player.global_position = Vector3(23, 0, 0)
	deer1._prey_ai(0.05)
	check(deer1._state == "flee" and deer1.current_anim_keyword == "gallop", "Walking player at 23m is heard by deer and triggers gallop escape")
	check(deer2._state == "flee" and deer2._prey_flee_timer > 0.0, "Spooked deer alerts nearby herd mate to flee together")

	deer1._state = "patrol"
	deer1._prey_flee_timer = 0.0
	deer2._state = "patrol"
	deer2._prey_flee_timer = 0.0
	player.is_moving = false
	player.is_sprinting = true
	player.global_position = Vector3(34, 0, 0)
	deer1._prey_ai(0.05)
	check(deer1._state == "flee" and deer1.current_anim_keyword == "gallop", "Sprinting player at 34m is heard by deer from afar")
	player.is_sprinting = false

	# Disparar a un ciervo (incluso de lejos) hace huir al ciervo y a toda la manada cercana
	deer1._state = "patrol"
	deer1._prey_flee_timer = 0.0
	deer2._state = "patrol"
	deer2._prey_flee_timer = 0.0
	player.global_position = Vector3(70, 0, 0)
	deer1.take_damage(40.0, false, player)
	check(deer1._state == "flee" and deer1._prey_flee_timer >= 11.0 and deer1.current_anim_keyword == "gallop", "Shot deer bolts immediately in gallop")
	check(deer2._state == "flee" and deer2._prey_flee_timer >= 9.0, "Shooting one deer causes nearby herd deer to flee in panic")

	var deer_scene: PackedScene = load("res://assets/models/wildlife/deer.glb")
	var deer_inst := deer_scene.instantiate()
	var deer_ap: AnimationPlayer = deer1._find_animation_player(deer_inst)
	check(deer_ap != null and deer_ap.has_animation("gallop") and deer_ap.has_animation("run"), "deer.glb contains both the new gallop bounding animation and run animation")
	deer_inst.free()
	deer1.free()
	deer2.free()

	world.queue_free()
	await process_frame
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
