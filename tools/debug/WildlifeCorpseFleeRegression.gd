extends SceneTree

# Regresión multiplayer de fauna:
#  - un puppet marcado muerto conserva el cadáver (rot_timer) en vez de
#    desaparecer al siguiente frame, y expira siguiendo el reloj del servidor
#  - la protección de spawn solo blinda contra lobos: ciervos/zorros siguen
#    huyendo de un proxy protegido
#  - una entrada stale (puppet liberado) en puppet_animals no impide recrearlo

const WC = preload("res://scripts/WildlifeController.gd")
const NavScript = preload("res://scripts/NavPathfinding.gd")
const MainScript = preload("res://scripts/Main.gd")

var errors := 0

func check(cond: bool, msg: String) -> void:
	if not cond:
		errors += 1
		print("FAIL: " + msg)
	else:
		print("PASS: " + msg)

class TestWorld extends Node3D:
	var nav := NavScript.new()
	func find_path_wildlife(start: Vector3, goal: Vector3) -> Array:
		return nav.find_path(start, goal)
	func is_wildlife_allowed_at(_pos: Vector3) -> bool:
		return true
	func _get_exact_ground_y(_x: float, _z: float) -> float:
		return 0.0
	func _is_pos_wolf_protected(_pos: Vector3) -> bool:
		return false

func make_deer(world: Node, pos: Vector3) -> Node3D:
	var d = WC.new()
	d.name = "Wildlife_deer_0"
	world.add_child(d)
	d.setup("deer", [pos, pos + Vector3(8, 0, 0), pos + Vector3(-8, 0, 8)])
	return d

func make_puppet(world: Node) -> Node3D:
	var p = WC.new()
	p.name = "Puppet_Wildlife_deer_9"
	world.add_child(p)
	p.setup_puppet("deer")
	return p

func make_proxy(world: Node, pid: int, pos: Vector3, protection: float) -> Node3D:
	var p := Node3D.new()
	p.name = "ServerProxy_%d" % pid
	p.add_to_group("net_player_proxy")
	p.set_meta("peer_id", pid)
	p.set_meta("has_real_pos", true)
	p.set_meta("protection_timer", protection)
	p.position = pos
	world.add_child(p)
	return p

class FakeNet:
	var animals := {}
	var peer = null
	var is_dedicated_server := false
	var is_host := false
	var is_connected := true
	var players := {}

class TestMain extends MainScript:
	func _ready() -> void:
		pass  # sin generación de mundo

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	world.nav.build([], [])
	var dt := 1.0 / 30.0

	# --- 1. Un puppet que recibe dead=true debe conservar el cadáver ---
	var puppet := make_puppet(world)
	puppet.puppet_apply(Vector3(3, 0, 3), 0.0, "walk", true, false, 240.0)
	check(puppet._is_dead, "puppet_apply marks the puppet dead")
	check(puppet._rot_timer > 0.0, "dead puppet gets a corpse lifetime (was removed next frame before)")
	for i in range(10):
		puppet._process(dt)
	check(is_instance_valid(puppet), "corpse survives subsequent frames")

	# El reloj del cadáver sigue al del servidor (sync de 'rt')
	puppet.puppet_apply(puppet.global_position, 0.0, "walk", true, false, 12.5)
	check(absf(puppet._rot_timer - 12.5) < 0.01, "server rot clock keeps syncing while dead")
	puppet._rot_timer = 0.05
	puppet._process(0.1)
	await process_frame
	check(not is_instance_valid(puppet) or puppet.is_queued_for_deletion(), "corpse frees itself when the clock reaches 0")

	# --- 2. Muerte local del puppet por cuchillo: cadáver no instantáneo ---
	var puppet2 := make_puppet(world)
	puppet2.take_damage(999.0, true)
	check(puppet2._is_dead and puppet2._rot_timer > 0.0, "knife-killed puppet keeps a visible corpse")
	for i in range(10):
		puppet2._process(dt)
	check(is_instance_valid(puppet2), "knife-killed corpse survives frames")
	puppet2.queue_free()

	# --- 3. Protección de spawn: las presas huyen igual, los lobos no atacan ---
	var prot_proxy := make_proxy(world, 7, Vector3(10, 0, 0), 30.0)
	var deer := make_deer(world, Vector3.ZERO)
	for i in range(90):
		deer._process(dt)
		if deer._prey_flee_timer > 0.0:
			break
	check(deer._player == prot_proxy, "deer resolves a spawn-protected proxy as its player")
	check(deer._prey_flee_timer > 0.0, "deer flees a protected player (protection only blocks wolves)")
	check(deer.global_position.distance_to(Vector3.ZERO) > 0.5, "deer actually moved away")

	# El lobo sigue sin perseguir al proxy protegido
	var wolf = WC.new()
	wolf.name = "Wildlife_wolf_0"
	world.add_child(wolf)
	wolf.setup("wolf", [Vector3(20, 0, 0), Vector3(24, 0, 0)])
	for i in range(60):
		wolf._process(dt)
	check(wolf._player != prot_proxy, "wolf still ignores the protected proxy")
	prot_proxy.set_meta("protection_timer", 0.0)
	for i in range(60):
		wolf._process(dt)
	check(wolf._player == prot_proxy, "wolf resolves the proxy once protection expires")

	# --- 4. Proxy sin posición real nunca es objetivo ---
	var ghost := make_proxy(world, 8, Vector3(2, 0, 0), 0.0)
	ghost.set_meta("has_real_pos", false)
	var deer2 := make_deer(world, Vector3(0, 0, 40))
	var other := make_proxy(world, 9, Vector3(60, 0, 40), 0.0)
	for i in range(90):
		deer2._process(dt)
	check(deer2._player != ghost, "proxy without real position is never resolved")

	# --- 5. Entrada stale en puppet_animals: el cadáver se recrea ---
	var m := TestMain.new()
	root.add_child(m)
	m.net = FakeNet.new()
	m.net.animals["Wildlife_deer_0"] = {"t": "deer", "x": 5.0, "y": 0.0, "z": 5.0, "r": 0.0, "a": "walk", "d": true, "g": false, "rt": 200.0}
	m._update_puppet_animals()
	var cp = m.puppet_animals.get("Wildlife_deer_0")
	check(cp != null and is_instance_valid(cp), "dead animal spawns as a corpse puppet")
	check(cp._is_dead and cp._rot_timer > 0.0, "recreated corpse carries its rot clock")
	# Simula el bug viejo: el puppet se libera pero la entrada queda
	cp.queue_free()
	m._update_puppet_animals()
	var cp2 = m.puppet_animals.get("Wildlife_deer_0")
	check(cp2 != null and is_instance_valid(cp2), "freed puppet entry does not block recreation (was the invisible-corpse bug)")
	# Cuando el servidor deja de emitirlo, el cadáver cliente se limpia
	m.net.animals.erase("Wildlife_deer_0")
	m.net.animals["Wildlife_fox_0"] = {"t": "fox", "x": 0.0, "y": 0.0, "z": 0.0, "r": 0.0, "a": "walk", "d": false, "g": false}
	m._update_puppet_animals()
	check(m.puppet_animals.has("Wildlife_deer_0") and is_instance_valid(m.puppet_animals["Wildlife_deer_0"]), "dead puppet is kept briefly after the server drops it")
	m.puppet_animals["Wildlife_deer_0"]._rot_timer = 0.01
	m.puppet_animals["Wildlife_deer_0"]._process(0.05)
	await process_frame
	m._update_puppet_animals()
	check(not m.puppet_animals.has("Wildlife_deer_0"), "expired corpse clears from the puppet table")

	print("ERRORS=%d" % errors)
	quit(1 if errors > 0 else 0)
