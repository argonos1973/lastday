extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal connection_succeeded()
signal all_players_ready()

const PORT := 5005
const MAX_PLAYERS := 4
const SPAWN_POS := Vector3(8.0, 0.4, 2.5)

var peer: ENetMultiplayerPeer = null
var is_host := false
var is_connected := false
var is_dedicated_server := false

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
	peer.set_meta("timeout", 30000) # 30s timeout for slow clients
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	is_dedicated_server = true
	print("[NET] Servidor dedicado iniciado en puerto %d" % PORT)
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
	players[multiplayer.get_unique_id()] = {
		"name": "Host",
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	print("[NET] Servidor iniciado en puerto %d" % PORT)
	return true

func join_game(ip: String) -> bool:
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT, 0, 0, 30000) # 30s timeout
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

func get_player_list() -> Dictionary:
	return players

func get_my_id() -> int:
	return multiplayer.get_unique_id()
