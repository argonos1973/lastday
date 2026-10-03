extends SceneTree

# Regresión de caza lobo→presa en servidor dedicado:
#  - un lobo hambriento entra en chase_prey, alcanza a la presa y la mata
#    (antes el path cacheado ~1.2 s perseguía waypoints obsoletos y el
#    cutoff de "waypoint alcanzado" a 1.6 m dejaba al lobo clavado justo por
#    encima del rango de ataque de 1.5 m — persecución eterna sin mordisco)
#  - la presa muere, el lobo entra en eating, marca gutted, genera la carne
#    sobrante (_leftover_meat_count) y retira el cadáver
#  - la carne queda registrada en world_actions_by_id y _dropped_items con
#    action_type wolf_meat_raw (persistencia de sesión + sync de late joiners)
#  - animal_gutted viaja por RPC real (loopback ENet) hasta un cliente
#    registrado; el handler de cliente retira el puppet y crea las acciones
#    de carne con los mismos ids que en el servidor
#  - un cliente que entra después recibe la carne vía sync_world_state
#  - el pickup valida contra _dropped_items y agota el action
#  - otro lobo hambriento puede comerse la carne sobrante (_consume_meat_pickup)

const WC = preload("res://scripts/WildlifeController.gd")
const MainScript = preload("res://scripts/Main.gd")

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)
	else:
		print("PASS: ", label)

class ProbeNet extends "res://scripts/NetworkManager.gd":
	func _on_connected_to_server() -> void:
		is_connected = true
		var my_id := multiplayer.get_unique_id()
		players[my_id] = {"name": "Cazador", "pos": Vector3(300, 0, 300), "rot": 0.0, "ready": true}
		_register_player.rpc_id(1, my_id, "Cazador", client_id, _join_password)
		connection_succeeded.emit()

class TestMain extends MainScript:
	var gutted_calls: Array = []
	func _ready() -> void:
		pass  # sin generación de mundo
	func _get_exact_ground_y(_x: float, _z: float, _f: float = 500.0) -> float:
		return 0.0
	func _get_ground_height(_p) -> float:
		return 0.0
	func _is_water_drop_position(_pos: Vector3) -> bool:
		return false
	func _net_animal_gutted(animal_name: String, meat_drops: Array) -> void:
		gutted_calls.append({"name": animal_name, "drops": meat_drops.duplicate(true)})
		super(animal_name, meat_drops)

var m: TestMain = null
var wolf = null
var deer = null
var picked_meat := ""

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== WolfHuntMeatRegression ===")
	var net = root.get_node_or_null("/root/NetworkManager")
	check(net != null and net.host_game(), "server (real autoload) starts on ENet")
	if net == null or not net.is_connected:
		_finish()
		return

	# --- Cliente real por loopback (mismo patrón que PhantomPeerRegression) ---
	var scope := Node.new()
	scope.name = "ClientScope"
	root.add_child(scope)
	var api := MultiplayerAPI.create_default_interface()
	set_multiplayer(api, scope.get_path())
	var probe := ProbeNet.new()
	probe.name = "NetworkManager"
	scope.add_child(probe)
	probe.join_game("127.0.0.1")
	await create_timer(1.0).timeout
	var pid: int = probe.multiplayer.get_unique_id() if probe.is_connected else -1
	check(pid > 1, "client probe registers (got %d)" % pid)
	check(net.players.has(pid), "server tracks the probe player")

	# --- Mundo servidor con Main real (fauna + world actions reales) ---
	m = TestMain.new()
	root.add_child(m)
	current_scene = m
	m.net = net
	m._create_wildlife_animal("deer", [Vector3(12, 0, 0), Vector3(18, 0, 0)])
	m._create_wildlife_animal("wolf", [Vector3.ZERO, Vector3(4, 0, 0)])
	for c in m.get_children():
		if c is WC:
			if c.animal_type == "deer": deer = c
			elif c.animal_type == "wolf": wolf = c
	check(deer != null and wolf != null, "deer + wolf spawned on the server world")
	if deer == null or wolf == null:
		_finish()
		return
	# Hambre asegurada y presa frágil: la caza debe cerrar en ~2 mordiscos.
	wolf._wolf_hunger = 10.0
	wolf._wolf_hunger_threshold = 60.0
	deer.health = 30.0
	var deer_name := String(deer.name)

	# --- Caza en tiempo real: poll hasta que el lobo termine de comer ---
	var kill_pos := Vector3.ZERO
	var saw_chase := false
	var saw_eating := false
	var saw_attack_range := false
	var t := 0.0
	var limit := 60.0
	while t < limit:
		await create_timer(0.25).timeout
		t += 0.25
		if not is_instance_valid(wolf):
			break
		if wolf._state == "chase_prey":
			saw_chase = true
			if is_instance_valid(deer) and wolf.global_position.distance_to(deer.global_position) < 1.5:
				saw_attack_range = true
		if wolf._state == "eating":
			saw_eating = true
			if wolf._wolf_eating_timer > 0.6:
				wolf._wolf_eating_timer = 0.6  # acelera la comida del cadáver
		if is_instance_valid(deer):
			kill_pos = deer.global_position
		elif saw_eating:
			break
	await create_timer(0.5).timeout

	check(saw_chase, "hungry wolf enters chase_prey")
	check(saw_attack_range, "wolf reaches attack range (<1.5m) — the 1.6m waypoint cutoff used to freeze it at ~1.58m forever")
	check(saw_eating, "wolf switches to eating on the fresh corpse")
	check(not is_instance_valid(deer), "corpse removed after the wolf finishes eating")

	# El cazador seguiría hambriento y se comería los restos durante las
	# esperas del test (busca carne a <60 m): lo saciamos y lo alejamos.
	wolf._wolf_hunger = 100.0
	wolf._wolf_hunger_threshold = -1.0
	wolf._wolf_eating_target = null
	wolf._wolf_eating_timer = 0.0
	wolf._state = "patrol"
	wolf.global_position = kill_pos + Vector3(200, 0, 0)

	# --- Carne sobrante registrada en el mundo del servidor ---
	var meat_ids := []
	for aid in m.world_actions_by_id.keys():
		var a = m.world_actions_by_id[aid]
		if is_instance_valid(a) and "action_type" in a and str(a.action_type) == "wolf_meat_raw":
			if a.global_position.distance_to(kill_pos) < 6.0:
				meat_ids.append(str(aid))
	check(meat_ids.size() == 3, "deer leaves 3 leftover meat pickups (got %d)" % meat_ids.size())
	var tracked := 0
	for e in m._dropped_items:
		if meat_ids.has(str(e.get("id", ""))) and str(e.get("action_type", "")) == "wolf_meat_raw":
			tracked += 1
	check(tracked == meat_ids.size() and tracked > 0, "meat tracked in _dropped_items with wolf_meat_raw (session save + late-join sync)")

	# --- Broadcast animal_gutted por RPC real al cliente conectado ---
	check(m.gutted_calls.size() >= 1, "animal_gutted RPC reaches a connected client")
	var drop_ids := []
	if not m.gutted_calls.is_empty():
		var call0: Dictionary = m.gutted_calls[0]
		check(String(call0.get("name", "")) == deer_name, "gutted broadcast names the dead deer")
		for d in call0.get("drops", []):
			drop_ids.append(str(d.get("id", "")))
		var matched := 0
		for mid in meat_ids:
			if drop_ids.has(mid):
				matched += 1
		check(matched == meat_ids.size() and matched > 0, "broadcast drop ids match the server world actions (%d/%d)" % [matched, meat_ids.size()])

	# --- Vista cliente: el handler retira el puppet y crea la carne ---
	# (m2 simula el mundo del cliente; el RPC real ya quedó probado arriba)
	var m2 := TestMain.new()
	root.add_child(m2)
	m2.net = probe
	probe.animals[deer_name] = {"t": "deer", "x": 0.0, "y": 0.0, "z": 0.0, "r": 0.0, "a": "walk", "d": true, "g": false, "rt": 250.0}
	var puppet := WC.new()
	puppet.name = "Puppet_" + deer_name
	m2.add_child(puppet)
	puppet.setup_puppet("deer")
	puppet._is_dead = true
	puppet._rot_timer = 250.0
	m2.puppet_animals[deer_name] = puppet
	m2._net_animal_gutted(deer_name, m.gutted_calls[0]["drops"] if not m.gutted_calls.is_empty() else [])
	await create_timer(6.0).timeout
	check(not m2.puppet_animals.has(deer_name), "client removes the dead deer puppet after animal_gutted")
	check(not probe.animals.has(deer_name), "animal erased from client-side net.animals")
	var m2_meat := 0
	for aid in m2.world_actions_by_id.keys():
		var a2 = m2.world_actions_by_id[aid]
		if is_instance_valid(a2) and "action_type" in a2 and str(a2.action_type) == "wolf_meat_raw":
			m2_meat += 1
	check(m2_meat == meat_ids.size(), "client spawns %d meat actions with server ids (got %d)" % [meat_ids.size(), m2_meat])

	# --- Late joiner: sync_world_state reconstruye la carne ---
	var m3 := TestMain.new()
	root.add_child(m3)
	m3.net = probe
	m3._net_sync_world_state([], m._dropped_items.duplicate(true), [], [], [], [])
	var m3_meat := 0
	for aid in m3.world_actions_by_id.keys():
		var a3 = m3.world_actions_by_id[aid]
		if is_instance_valid(a3) and "action_type" in a3 and str(a3.action_type) == "wolf_meat_raw":
			m3_meat += 1
	check(m3_meat == meat_ids.size(), "late joiner rebuilds %d meat pickups from dropped_items (got %d)" % [meat_ids.size(), m3_meat])

	# --- Recolección: el pickup valida contra _dropped_items en el servidor ---
	if not meat_ids.is_empty():
		if not m.server_proxies.has(pid):
			m._spawn_server_proxy(pid)  # _ready quedó anulado en el TestMain
		check(m.server_proxies.has(pid), "server proxy exists for the registered client")
		var mid: String = meat_ids[0]
		picked_meat = mid
		var meat_node = m.world_actions_by_id[mid]
		m.server_proxies[pid].global_position = meat_node.global_position + Vector3(0.5, 0, 0)
		check(m._net_item_picked_up(mid, pid), "server accepts a meat pickup from a client in reach")
		check(m._depleted_action_ids.has(mid) or not m.world_actions_by_id.has(mid), "picked meat is depleted/removed on the server")
		meat_ids.erase(mid)

	# --- Otro lobo hambriento puede comerse la carne sobrante ---
	# Aleja el proxy del probe: la persecución de jugador tiene prioridad sobre
	# la carne y secuestraría al segundo lobo.
	if m.server_proxies.has(pid):
		m.server_proxies[pid].global_position = Vector3(500, 0, 500)
		net.players[pid]["pos"] = Vector3(500, 0, 500)
	# Las escenas m2/m3 son clientes simulados: sus acciones comparten el
	# grupo global wolf_meat_pickups. En producción servidor y cliente son
	# procesos distintos; aquí hay que quitarlas o el lobo engancha una copia.
	m2.queue_free()
	m3.queue_free()
	await process_frame
	if meat_ids.size() > 1:
		var wolf2 = null
		m._create_wildlife_animal("wolf", [Vector3(50, 0, 50), Vector3(55, 0, 50)])
		for c in m.get_children():
			if c is WC and c.animal_type == "wolf" and c != wolf:
				wolf2 = c
		var meat_node2 = m.world_actions_by_id.get(meat_ids[-1])
		if wolf2 != null and meat_node2 != null and is_instance_valid(meat_node2):
			wolf2._wolf_hunger = 10.0
			wolf2.global_position = meat_node2.global_position + Vector3(1.0, 0, 0)
			var t2 := 0.0
			while t2 < 12.0 and is_instance_valid(wolf2) and is_instance_valid(meat_node2):
				await create_timer(0.5).timeout
				t2 += 0.5
				if wolf2._state == "eating" and wolf2._wolf_eating_timer > 0.4:
					wolf2._wolf_eating_timer = 0.4
			check(not is_instance_valid(meat_node2) or not m.world_actions_by_id.has(meat_ids[-1]), "a second hungry wolf can eat the leftover meat pickup")

	if probe.is_connected:
		probe.close_connection()
	_finish()

func _finish() -> void:
	var net = root.get_node_or_null("/root/NetworkManager")
	if net != null:
		net.close_connection()
	if failures == 0:
		print("WolfHuntMeatRegression: ALL PASS")
	else:
		print("WolfHuntMeatRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
