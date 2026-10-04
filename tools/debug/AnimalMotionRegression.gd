extends SceneTree

const Motion = preload("res://scripts/AnimalNetworkMotion.gd")
class World extends "res://scripts/Main.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass
class Net extends RefCounted:
	var animals := {}
class Puppet extends "res://scripts/WildlifeController.gd":
	var received := 0
	func _ready() -> void: pass
	func puppet_apply(pos: Vector3, yaw: float, anim: String, dead: bool, gutted: bool, rot_left: float = -1.0) -> void:
		received += 1
		super.puppet_apply(pos, yaw, anim, dead, gutted, rot_left)

class LodAnimal extends "res://scripts/WildlifeController.gd":
	var ticks := 0
	func _ready() -> void: pass
	func _escape_if_trapped(_delta: float) -> bool:
		ticks += 1
		return true

var errors := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var body := Node3D.new()
	root.add_child(body)
	for fps in [30, 60, 144]:
		var motion = Motion.new()
		motion.push(body, Vector3.ZERO, 0.0)
		var next_packet := 0.15
		var last_x := 0.0
		var min_step := INF
		var max_step := 0.0
		for frame in range(fps * 4):
			if motion.clock + 0.000001 >= next_packet:
				motion.push(body, Vector3(motion.clock * 4.0, 0, 0), 0.0)
				next_packet += 0.15
			motion.advance(body, 1.0 / fps)
			if motion.clock > 0.5:
				var step := body.position.x - last_x
				min_step = minf(min_step, step)
				max_step = maxf(max_step, step)
			last_x = body.position.x
		check(absf(body.position.x - 4.0 * (4.0 - Motion.BUFFER_SECONDS)) < 0.01, "FPS-independent trajectory at %d FPS" % fps)
		check(min_step > 0.0 and max_step / min_step < 1.02, "Constant movement between packets at %d FPS" % fps)
		var end: Vector3 = motion.samples.back()["pos"]
		motion.advance(body, 2.0)
		check(body.position.is_equal_approx(end), "Packet loss stops at last known position")
		motion.push(body, Vector3(100, 0, 0), 1.0)
		check(body.position.is_equal_approx(Vector3(100, 0, 0)), "Teleport resets interpolation")
		motion.advance(body, 0.01)
		check(body.position.x == 100.0, "No rewind after teleport")
	var jitter = Motion.new()
	jitter.push(body, Vector3.ZERO, 0.0)
	var arrival := 0.1
	var packet := 0
	var previous_x := 0.0
	for frame in range(240):
		if jitter.clock + 0.000001 >= arrival:
			jitter.push(body, Vector3(jitter.clock * 3.0, 0, 0), 0.0)
			packet += 1
			arrival += 0.2 if packet % 2 else 0.1
		jitter.advance(body, 1.0 / 60.0)
		if frame > 30:
			check(absf(body.position.x - previous_x - 0.05) < 0.001, "Uneven packet arrival remains smooth")
		previous_x = body.position.x
	var turn = Motion.new()
	turn.push(body, Vector3.ZERO, deg_to_rad(179.0))
	turn.advance(body, 0.15)
	turn.push(body, Vector3.ZERO, deg_to_rad(-179.0))
	turn.advance(body, 0.145)
	check(absf(absf(body.rotation.y) - PI) < 0.01, "Yaw takes shortest path through 180 degrees")
	body.free()
	var world := World.new()
	root.add_child(world)
	current_scene = world
	world.net = Net.new()
	var puppet := Puppet.new()
	world.add_child(puppet)
	puppet.is_puppet = true
	puppet.set_process(false)
	world.puppet_animals["test"] = puppet
	world.net.animals["test"] = {"t": "deer", "x": 5.0, "_sample": 1}
	for i in range(20): world._update_puppet_animals()
	check(puppet.received == 1, "Main consumes each network sample only once")
	world.net.animals["test"]["_sample"] = 2
	world._update_puppet_animals()
	check(puppet.received == 2, "Stationary samples still arrive")
	puppet.puppet_apply(Vector3(6, 0, 0), 0.0, "walk", true, false, 120.0)
	check(puppet.global_position.x == 6.0, "Death snaps to authoritative corpse position")
	check(puppet._rot_timer == 120.0, "Corpse lifetime preserved")
	var observer := Node3D.new()
	world.add_child(observer)
	observer.add_to_group("net_player_proxy")
	observer.set_meta("has_real_pos", true)
	observer.set_meta("in_built_shelter", true)
	observer.position = Vector3(80, 0, 0)
	var far_target := Node3D.new()
	world.add_child(far_target)
	far_target.position = Vector3(110, 0, 0)
	var animal := LodAnimal.new()
	world.add_child(animal)
	animal.set_process(false)
	animal.animal_type = "deer"
	animal._player = far_target
	animal.patrol_points = [Vector3.ZERO, Vector3(5, 0, 0)]
	for i in range(10): animal._process(1.0 / 60.0)
	check(animal.ticks == 10, "Sheltered observer keeps nearby animal simulation smooth")
	observer.remove_from_group("net_player_proxy")
	animal._observer_check_timer = 0.0
	animal.ticks = 0
	for i in range(10): animal._process(1.0 / 60.0)
	check(animal.ticks == 0, "Distant unobserved wildlife still uses LOD")
	world.free()
	print("ANIMAL_MOTION_ERRORS=", errors)
	quit(1 if errors else 0)
