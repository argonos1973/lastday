extends SceneTree

class World extends "res://scripts/Main.gd":
	var drops: Array = []
	var shots: Array = []
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _spawn_ground_pickup(n: String, t: String, p: Vector3, w: float, q: int, u: float, id: String = "", a: String = "", wet: float = 0.0, c: Color = Color(0,0,0,0)) -> void:
		drops.append({"name": n, "qty": q, "id": id})
	func _net_primitive_shot(id: int, origin: Vector3, dir: Vector3, item: String, speed: float, wind: Vector3 = Vector3.ZERO):
		shots.append([id, wind])

class Animal extends "res://scripts/WildlifeController.gd":
	var damage := 0.0
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _remove_corpse(): pass
	func take_damage(amount: float, _knife: bool = false, _attacker: Node = null): damage += amount

class Shooter extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass

var failures := 0
var recovered := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func run():
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var network = root.get_node("NetworkManager")
	world.net = network
	network.is_host = true
	network.is_dedicated_server = true
	var animal := Animal.new()
	animal.name = "Wildlife_deer_test"
	animal.animal_type = "deer"
	animal._is_dead = true
	world.add_child(animal)
	world._net_gut_animal(str(animal.name), 1)
	var first_count := world.drops.size()
	check(first_count == 11, "Deer yields 8 meat, hide, bone and sinew stacks")
	world._net_gut_animal(str(animal.name), 1)
	check(world.drops.size() == first_count, "Duplicate corpse request cannot award resources twice")
	var ids: Array = world.drops.map(func(d): return d.id)
	animal._gutted = false # A new spawn may reuse the same animal name.
	world._net_gut_animal(str(animal.name), 1)
	for drop in world.drops.slice(first_count):
		check(not ids.has(drop.id), "Respawn must not reuse depleted pickup IDs")
	animal._is_dead = false
	world._net_damage_animal(str(animal.name), 25, false, 1, true)
	check(animal.damage == 25 and float(animal.get_meta("bola_slow_until", 0)) > Time.get_unix_time_from_system(), "Bola slows authoritative animal and deals one hit")
	var wind := Vector3(2,0,1)
	network.primitive_shot(1, Vector3.ZERO, Vector3.FORWARD, "Lanza", 28, wind)
	check(world.shots.size() == 1 and world.shots[0][1] == wind, "Host launch is accepted with exact wind")
	network.primitive_shot(42, Vector3.ZERO, Vector3.FORWARD, "Lanza", 28, wind)
	network.primitive_shot(1, Vector3.ZERO, Vector3.FORWARD, "Lanza", 1000, wind)
	check(world.shots.size() == 1, "Forged shooter and invalid speed rejected")
	var host_shooter := Shooter.new()
	world.add_child(host_shooter)
	network.is_connected = true
	host_shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, 65, [], 30, "Lanza", "weapon", 1, 0, false)
	check(world.shots.size() == 2, "Actual host launch dispatches locally instead of RPC to itself")
	network.is_connected = false
	world.get_child(world.get_child_count()-1).queue_free()
	host_shooter.queue_free()
	# Empty world isolates actual projectile expiry without map or saves.
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var shooter := Shooter.new()
	arena.add_child(shooter)
	shooter.item_dropped.connect(func(_n,_t,_w,_q,_u,_p,_c,_b,_s): recovered += 1)
	shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, 0.1, [], 30, "Lanza", "weapon", 1.0, 0.0, false)
	var projectile = arena.get_child(arena.get_child_count()-1)
	projectile._physics_process(0.1)
	check(recovered == 1, "Range expiry recovers thrown spear once")
	projectile._physics_process(0.1)
	check(recovered == 1, "Queued projectile cannot recover twice")
	shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, 0.1, [], 0, "Lanza", "weapon", 0, 0, false, true, wind)
	projectile = arena.get_child(arena.get_child_count()-1)
	check(projectile.wind_velocity == wind, "Remote projectile uses transmitted wind")
	check(projectile.impact.get_connections().is_empty(), "Remote visual cannot apply duplicate damage")
	projectile._physics_process(0.1)
	check(recovered == 1, "Remote visual cannot duplicate recovered loot")
	var recovered_durabilities: Array = []
	shooter.item_dropped.connect(func(_n,_t,_w,_q,_u,_p,_c,_b,_s):
		recovered_durabilities.append(shooter.get_meta("last_dropped_durability", -1)))
	var in_flight: Array = []
	for durability in [16.0, 72.0]:
		shooter.set_meta("last_dropped_durability", durability)
		shooter.set_meta("last_dropped_max_durability", 100.0)
		shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, .1, [], 0, "Lanza", "tool_spear", 1, 0, false)
		in_flight.append(arena.get_child(arena.get_child_count()-1))
		check(not shooter.has_meta("last_dropped_durability"), "Flight captures durability instead of leaking it to other drops")
	in_flight[1]._physics_process(.1)
	in_flight[0]._physics_process(.1)
	check(recovered_durabilities == [72.0,16.0], "Concurrent spears retain individual durability regardless of landing order")
	current_scene = null
	arena.queue_free()
	world.queue_free()
	await process_frame
	print("PrimitiveNetworkRegression failures=", failures)
	quit(1 if failures else 0)
