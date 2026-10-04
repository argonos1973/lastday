extends SceneTree

class World extends "res://scripts/Main.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass

class Target extends Node3D:
	var damage := 0.0
	func apply_damage(amount: float) -> void: damage += amount

class Wolf extends WildlifeController:
	func _ready() -> void: pass
	func _play_wolf_sound(_kind: String) -> void: pass
	func _clamp_flee_goal(start: Vector3, direction: Vector3, distance: float) -> Vector3:
		return start + direction * distance

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	world._military_tent_pos = Vector3(200, 0, 200)
	world._remote_tent_pos = Vector3(-400, 0, -380)
	world._built_shelters.append({"pos": [100.0, 0.0, 100.0]})
	var positions: Array[Vector3] = [Vector3(-340, 0, 280), Vector3(250, 0, -258), world._military_tent_pos, world._remote_tent_pos, Vector3(100, 0, 100)]
	for i in range(world.HOUSE_DATA.size()):
		positions.append(world.HOUSE_DATA[i]["pos"])
		world._server_door_states["Casa abandonada %d Door" % (i + 1)] = true
	var player := Target.new()
	world.add_child(player)
	var wolf := Wolf.new()
	world.add_child(wolf)
	wolf.set_process(false)
	wolf.animal_type = "wolf"
	wolf._wolf_hunger = 100.0
	wolf._player = player
	for pos in positions:
		check(world._is_pos_wolf_protected(pos), "Roof must protect with open doors at %s" % pos)
		player.position = pos
		wolf.position = pos + Vector3(1, 0, 0)
		for mode in ["local", "connected", "disconnected"]:
			var proxy: bool = mode != "local"
			if proxy: player.add_to_group("net_player_proxy")
			player.set_meta("disconnected", mode == "disconnected")
			player.set_meta("proxy_health", 100.0)
			wolf._chase_cooldown = 0.0
			wolf._state = "chase_player"
			wolf._chase_target = player
			wolf._attack_cooldown = 0.0
			wolf._wolf_ai(0.016)
			check(wolf._state != "chase_player" and wolf._chase_target == null, "Roof cancels an active chase")
			check(player.damage == 0 and player.get_meta("proxy_health") == 100.0, "No damage under roof")
			if proxy: player.remove_from_group("net_player_proxy")
	check(not world._is_pos_wolf_protected(Vector3(48, 0, -48)), "Old tent location must not protect empty ground")
	check(not world._is_pos_wolf_protected(Vector3(600, 0, 600)), "Outdoors remains exposed")
	world._built_shelters.clear()
	check(not world._is_pos_wolf_protected(Vector3(100, 0, 100)), "Dismantling shelter removes protection")
	for tent in [{"pos": world._military_tent_pos, "yaw": 35.0}, {"pos": world._remote_tent_pos, "yaw": 120.0}]:
		var origin: Vector3 = tent["pos"]
		var angle := deg_to_rad(float(tent["yaw"]))
		check(world._is_pos_wolf_protected(origin + Vector3(0, 0, 5).rotated(Vector3.UP, angle)), "Rotated tent interior protected")
		check(not world._is_pos_wolf_protected(origin + Vector3(5, 0, 0).rotated(Vector3.UP, angle)), "Outside tent not protected")
	world.free()
	print("WOLF_ROOF_ERRORS=", failures)
	quit(1 if failures else 0)
