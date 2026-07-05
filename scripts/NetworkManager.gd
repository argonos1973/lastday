extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal connection_succeeded()
signal all_players_ready()

const PORT := 5005
const DISCOVERY_PORT := 5006
const MAX_PLAYERS := 4
const SPAWN_POS := Vector3(8.0, 0.4, 2.5)

var peer: ENetMultiplayerPeer = null
var is_host := false
var is_connected := false
var is_dedicated_server := false
var _broadcast_server: PacketPeerUDP = null
var _probe_listener: PacketPeerUDP = null
var _broadcast_timer := 0.0

# player_id -> { "name": String, "pos": Vector3, "rot": float, "ready": bool }
var players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	# Auto-start dedicated server if --server argument is passed
	var args := OS.get_cmdline_args()
	if args.has("--server"):
		start_dedicated_server()

func start_dedicated_server() -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("No se pudo crear el servidor: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	is_dedicated_server = true
	_start_broadcast()
	print("[NET] Servidor dedicado iniciado en puerto %d" % PORT)
	print("[NET] IP local: %s" % _get_local_ip())
	print("[NET] Esperando jugadores...")
	return true

func host_game() -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		push_error("No se pudo crear el servidor: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	_start_broadcast()
	players[multiplayer.get_unique_id()] = {
		"name": "Host",
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	print("[NET] Servidor iniciado en puerto %d" % PORT)
	print("[NET] IP local: %s" % _get_local_ip())
	return true

func _start_broadcast() -> void:
	# Sender socket on ephemeral port for broadcasting
	_broadcast_server = PacketPeerUDP.new()
	_broadcast_server.set_broadcast_enabled(true)
	_broadcast_server.bind(0)
	_broadcast_server.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	# Listener socket on DISCOVERY_PORT for responding to probes
	_probe_listener = PacketPeerUDP.new()
	_probe_listener.bind(DISCOVERY_PORT)
	print("[NET] Broadcast de descubrimiento activo en puerto %d" % DISCOVERY_PORT)

func _get_local_ip() -> String:
	var ips := IP.get_local_addresses()
	for ip in ips:
		var s := str(ip)
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			return s
	if ips.size() > 0:
		return str(ips[0])
	return "127.0.0.1"

func _get_all_local_ips() -> Array:
	var result: Array = []
	var ips := IP.get_local_addresses()
	for ip in ips:
		var s := str(ip)
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			result.append(s)
	if result.is_empty() and ips.size() > 0:
		result.append(str(ips[0]))
	return result

func _process(_delta: float) -> void:
	if is_host:
		# Listen for probe packets from clients doing active scan
		if _probe_listener != null:
			var count := _probe_listener.get_available_packet_count()
			while count > 0:
				var packet := _probe_listener.get_packet()
				var msg := packet.get_string_from_utf8()
				if msg == "LASTDAY_PROBE":
					var sender_ip := _probe_listener.get_packet_ip()
					var sender_port := _probe_listener.get_packet_port()
					var all_ips := _get_all_local_ips()
					var response := "LASTDAY_SERVER:" + ",".join(all_ips)
					_broadcast_server.set_dest_address(sender_ip, sender_port)
					_broadcast_server.put_packet(response.to_utf8_buffer())
					# Reset back to broadcast mode
					_broadcast_server.set_dest_address("255.255.255.255", DISCOVERY_PORT)
					print("[NET] Respondido probe de %s:%d con IPs: %s" % [sender_ip, sender_port, ",".join(all_ips)])
				count -= 1
		# Periodic broadcast
		if _broadcast_server != null:
			_broadcast_timer += _delta
			if _broadcast_timer >= 2.0:
				_broadcast_timer = 0.0
				var all_ips := _get_all_local_ips()
				var msg := "LASTDAY_SERVER:" + ",".join(all_ips)
				_broadcast_server.set_dest_address("255.255.255.255", DISCOVERY_PORT)
				_broadcast_server.put_packet(msg.to_utf8_buffer())

func _exit_tree() -> void:
	if _broadcast_server != null:
		_broadcast_server.close()
		_broadcast_server = null
	if _probe_listener != null:
		_probe_listener.close()
		_probe_listener = null

func join_game(ip: String) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("No se pudo conectar al servidor: %d" % err)
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	print("[NET] Conectando a %s:%d..." % [ip, PORT])
	return true

func close_connection() -> void:
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_connected = false
	is_host = false
	players.clear()

func _on_peer_connected(id: int) -> void:
	print("[NET] Peer conectado: %d" % id)
	# Generous timeout so clients don't get kicked while loading the world
	if peer != null:
		var enet_peer := peer.get_peer(id)
		if enet_peer != null:
			enet_peer.set_timeout(120000, 120000, 180000)
	if is_host:
		# Send current player list to the new client
		_sync_player_list.rpc_id(id, players)
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	print("[NET] Peer desconectado: %d" % id)
	players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	print("[NET] Conectado al servidor")
	# Generous timeout so we don't drop the server while loading the world
	if peer != null:
		var server_peer := peer.get_peer(1)
		if server_peer != null:
			server_peer.set_timeout(120000, 120000, 180000)
	is_connected = true
	var my_id := multiplayer.get_unique_id()
	players[my_id] = {
		"name": "Jugador_%d" % my_id,
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	_register_player.rpc_id(1, my_id, players[my_id]["name"])
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	print("[NET] Fallo de conexion")
	is_connected = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	print("[NET] Servidor desconectado")
	is_connected = false
	players.clear()
	connection_failed.emit()

@rpc("any_peer", "reliable")
func _register_player(id: int, player_name: String) -> void:
	if not is_host:
		return
	players[id] = {
		"name": player_name,
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	_sync_player_list.rpc(players.duplicate(true))
	_check_all_ready()

@rpc("authority", "reliable")
func _sync_player_list(list: Dictionary) -> void:
	players = list
	if players.size() >= 1:
		all_players_ready.emit()

func _check_all_ready() -> void:
	if players.size() >= 1:
		all_players_ready.emit()

# Position sync — called by each client for their own player
@rpc("any_peer", "unreliable_ordered")
func sync_player_state(id: int, pos: Vector3, rot: float, anim: String, equipped_clothing: String, held_item: String) -> void:
	if not players.has(id):
		players[id] = {"name": "Jugador_%d" % id, "pos": pos, "rot": rot, "ready": true}
	players[id]["pos"] = pos
	players[id]["rot"] = rot
	players[id]["anim"] = anim
	players[id]["equipped_clothing"] = equipped_clothing
	players[id]["held_item"] = held_item

# Animal state broadcast — server sends to all clients
# animal_id -> { "type": String, "pos": Vector3, "rot": float, "anim": String, "dead": bool }
var animals: Dictionary = {}

@rpc("authority", "unreliable_ordered")
func sync_animals(data: Dictionary) -> void:
	# Merge chunks instead of replacing (server may split into multiple packets)
	for key in data.keys():
		animals[key] = data[key]

# Server tells specific client to apply damage
@rpc("authority", "reliable")
func apply_damage_to_client(amount: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_apply_damage"):
		scene._net_apply_damage(amount)

# Client tells server to damage an animal
@rpc("any_peer", "reliable")
func damage_animal(animal_name: String, amount: float, from_knife: bool) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_damage_animal"):
		scene._net_damage_animal(animal_name, amount, from_knife)

func get_player_list() -> Dictionary:
	return players

func get_my_id() -> int:
	return multiplayer.get_unique_id()
