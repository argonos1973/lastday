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
var client_id := ""

# player_id -> { "name": String, "pos": Vector3, "rot": float, "ready": bool }
var players: Dictionary = {}

func _load_or_generate_client_id() -> void:
	var path := "user://client_id.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			client_id = f.get_as_text().strip_edges()
			if client_id.length() > 0:
				return
	client_id = str(randi()) + "_" + str(Time.get_ticks_msec())
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(client_id)

func _ready() -> void:
	_load_or_generate_client_id()
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
	# Only server has direct ENet connections to all peers — set timeout there
	if is_host and peer != null:
		var enet_peer := peer.get_peer(id)
		if enet_peer != null:
			enet_peer.set_timeout(120000, 120000, 180000)
	# Don't send player list here — wait for _register_player so client_id is processed
	# and old offline entries are removed before sending the list
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	if is_host:
		# On server: keep player in list but mark as offline (don't erase)
		# so other clients still see the character in the world
		if players.has(id):
			players[id]["offline"] = true
	else:
		# On client: don't erase if player is marked offline (server keeps them)
		# The _sync_player_list RPC will update the list authoritatively
		if players.has(id) and not players[id].get("offline", false):
			players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
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
	_register_player.rpc_id(1, my_id, players[my_id]["name"], client_id)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	is_connected = false
	connection_failed.emit()

func _on_server_disconnected() -> void:
	is_connected = false
	players.clear()
	connection_failed.emit()

@rpc("any_peer", "reliable")
func _register_player(id: int, player_name: String, cid: String = "") -> void:
	if not is_host:
		return
	players[id] = {
		"name": player_name,
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	# Store client_id for proxy matching
	if not cid.is_empty():
		players[id]["client_id"] = cid
		# Remove old offline entry with same client_id
		var old_pid_to_remove := -1
		for pid in players.keys():
			if pid != id and players[pid].get("client_id", "") == cid:
				old_pid_to_remove = pid
				break
		if old_pid_to_remove != -1:
			players.erase(old_pid_to_remove)
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_match_proxy_to_client"):
			scene.call("_match_proxy_to_client", id, cid)
			# After matching, update player position from restored proxy
			if scene.server_proxies.has(id):
				players[id]["pos"] = scene.server_proxies[id].global_position
				players[id]["equipped_clothing"] = scene.server_proxies[id].get_meta("saved_clothing", "")
				players[id]["equipped_backpack"] = scene.server_proxies[id].get_meta("saved_backpack", "")
				players[id]["held_item"] = scene.server_proxies[id].get_meta("saved_held_item", "")
	# Send updated list to all clients (including new one)
	_sync_player_list.rpc(players.duplicate(true))
	# Send current positions of all online players to the new client
	if peer != null and peer.get_peer(id) != null:
		for pid in players.keys():
			if pid == id or pid == multiplayer.get_unique_id():
				continue
			if players[pid].get("offline", false):
				continue
			var pdata: Dictionary = players[pid]
			sync_player_state.rpc_id(id, pid, pdata.get("pos", Vector3(8.0, 0.4, 2.5)), pdata.get("rot", 0.0), pdata.get("anim", "idle"), pdata.get("equipped_clothing", ""), pdata.get("held_item", ""), pdata.get("equipped_backpack", ""))
	_check_all_ready()

@rpc("authority", "reliable")
func _sync_player_list(list: Dictionary) -> void:
	for pid in list.keys():
		pass
	players = list
	if players.size() >= 1:
		all_players_ready.emit()

func _check_all_ready() -> void:
	if players.size() >= 1:
		all_players_ready.emit()

# Position sync — called by each client for their own player
# Server relays to all other clients (dedicated server doesn't auto-forward)
@rpc("any_peer", "unreliable_ordered")
func sync_player_state(id: int, pos: Vector3, rot: float, anim: String, equipped_clothing: String, held_item: String, equipped_backpack: String) -> void:
	if not players.has(id):
		players[id] = {"name": "Jugador_%d" % id, "pos": pos, "rot": rot, "ready": true}
	# Ignore position updates from reconnecting clients (they're still at spawn pos)
	if is_host:
		var scene := get_tree().current_scene
		if scene != null and scene.server_proxies.has(id):
			if scene.server_proxies[id].get_meta("reconnecting", false):
				return
			# Force dead anim for dead proxies
			if scene.server_proxies[id].get_meta("proxy_dead", false):
				anim = "dead"
				equipped_clothing = ""
				held_item = ""
				equipped_backpack = ""
	players[id]["pos"] = pos
	players[id]["rot"] = rot
	players[id]["anim"] = anim
	players[id]["equipped_clothing"] = equipped_clothing
	players[id]["held_item"] = held_item
	players[id]["equipped_backpack"] = equipped_backpack
	# Server relays to all other clients
	if is_host and peer != null:
		for pid in players.keys():
			if pid != id and pid != multiplayer.get_unique_id():
				# Skip offline players
				if players[pid].get("offline", false):
					continue
				# Skip peers that are not actually connected
				if peer.get_peer(pid) == null:
					continue
				sync_player_state.rpc_id(pid, id, pos, rot, anim, equipped_clothing, held_item, equipped_backpack)

@rpc("authority", "reliable")
func set_client_spawn_pos(pos: Vector3, _arg2: Variant = null, _arg3: Variant = null, _arg4: Variant = null, _arg5: Variant = null, _arg6: Variant = null, _arg7: Variant = null) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_apply_net_spawn_pos"):
		scene.call("_apply_net_spawn_pos", pos)

@rpc("any_peer", "reliable")
func sync_player_inventory(items_data: Array, health: float, hunger: float, thirst: float, equipped_clothing: String, equipped_backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_store_player_inventory"):
		scene.call("_store_player_inventory", sender, items_data, health, hunger, thirst, equipped_clothing, equipped_backpack, held_item, held_idx, sleeping, sitting, rot)

@rpc("authority", "reliable")
func restore_player_inventory(items_data: Array, health: float, hunger: float, thirst: float, equipped_clothing: String, equipped_backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_apply_restored_inventory"):
		scene.call("_apply_restored_inventory", items_data, health, hunger, thirst, equipped_clothing, equipped_backpack, held_item, held_idx, sleeping, sitting, rot)

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

# Server tells specific client that they are dead (HP reached 0 on server)
@rpc("authority", "reliable")
func force_death_to_client() -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_force_death"):
		scene._net_force_death()

# Server reliably broadcasts player death to all clients
@rpc("authority", "reliable")
func broadcast_player_death(peer_id: int, pos: Vector3, rot: float) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_player_death_broadcast"):
		scene._net_player_death_broadcast(peer_id, pos, rot)

# Client tells server to damage another player (PvP)
@rpc("any_peer", "reliable")
func damage_player(target_peer_id: int, amount: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_damage_player"):
		scene._net_damage_player(target_peer_id, amount, sender)

# Client tells server to damage an animal
@rpc("any_peer", "reliable")
func damage_animal(animal_name: String, amount: float, from_knife: bool) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_damage_animal"):
		scene._net_damage_animal(animal_name, amount, from_knife)

# Client tells server to gut an animal (server processes and relays to all clients)
@rpc("any_peer", "reliable")
func gut_animal(animal_name: String, collect_mode: bool = false) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_gut_animal"):
		scene._net_gut_animal(animal_name, sender, collect_mode)

# Server tells all clients to remove gutted animal and spawn meat
@rpc("authority", "reliable")
func animal_gutted(animal_name: String, meat_drops: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_animal_gutted"):
		scene._net_animal_gutted(animal_name, meat_drops)

# Client tells server it picked up an item (server relays to all other clients)
@rpc("any_peer", "reliable")
func item_picked_up(action_id: String) -> void:
	# Server relays to all other clients
	if is_host and peer != null:
		for pid in players.keys():
			if pid != multiplayer.get_unique_id():
				item_picked_up.rpc_id(pid, action_id)
	# All clients: remove the item from world
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_item_picked_up"):
		scene._net_item_picked_up(action_id)

# Client tells server it dropped an item in the world (server relays to all other clients)
@rpc("any_peer", "reliable")
func item_dropped(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3) -> void:
	# Server relays to all other clients
	if is_host and peer != null:
		for pid in players.keys():
			if pid != multiplayer.get_unique_id():
				item_dropped.rpc_id(pid, drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos)
	# All clients (except the original dropper, who already spawned it locally): spawn the visual
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_item_dropped"):
		scene._net_item_dropped(drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos)

# Client tells server its player died (server drops inventory as loot)
@rpc("any_peer", "reliable")
func notify_death(inventory_data: Array = [], hp: float = 0.0, hunger: float = 0.0, thirst: float = 0.0, clothing: String = "", backpack: String = "", held: String = "", held_index: int = 0, sleeping: bool = false, sitting: bool = false, rot: float = 0.0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_player_died"):
		scene._net_player_died(sender, inventory_data)

func get_player_list() -> Dictionary:
	return players

# Generic RPC: client tells server a world action was completed.
# action_id: the action to remove (empty string if none)
# spawns: array of dictionaries with item spawn data
# extra_visual: "tree_remains", "cabin", or ""
# extra_pos: position for the extra visual
@rpc("any_peer", "reliable")
func world_action_completed(action_id: String, spawns: Array, extra_visual: String, extra_pos: Vector3) -> void:
	if is_host and peer != null:
		for pid in players.keys():
			if pid != multiplayer.get_unique_id():
				world_action_completed.rpc_id(pid, action_id, spawns, extra_visual, extra_pos)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_world_action_completed"):
		scene._net_world_action_completed(action_id, spawns, extra_visual, extra_pos)

# Client tells server it built a campfire (server relays to all other clients)
@rpc("any_peer", "reliable")
func campfire_built(cf_id: String, pos: Vector3) -> void:
	if is_host and peer != null:
		for pid in players.keys():
			if pid != multiplayer.get_unique_id():
				campfire_built.rpc_id(pid, cf_id, pos)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_campfire_built"):
		scene._net_campfire_built(cf_id, pos)

# Client tells server it built a shelter (server relays to all other clients)
@rpc("any_peer", "reliable")
func shelter_built(sh_id: String, pos: Vector3) -> void:
	if is_host and peer != null:
		for pid in players.keys():
			if pid != multiplayer.get_unique_id():
				shelter_built.rpc_id(pid, sh_id, pos)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_shelter_built"):
		scene._net_shelter_built(sh_id, pos)

# Client tells server it lit a campfire (server relays to all other clients)
@rpc("any_peer", "reliable")
func campfire_lit(action_id: String, fire_name: String, pos: Vector3) -> void:
	if is_host and peer != null:
		for pid in players.keys():
			if pid != multiplayer.get_unique_id():
				campfire_lit.rpc_id(pid, action_id, fire_name, pos)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_campfire_lit"):
		scene._net_campfire_lit(action_id, fire_name, pos)

# Server sends world state to a newly connected client
@rpc("authority", "reliable")
func sync_world_state(depleted_ids: Array, dropped_items: Array, campfires: Array, lit_campfires: Array, open_doors: Array, shelters: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_sync_world_state"):
		scene._net_sync_world_state(depleted_ids, dropped_items, campfires, lit_campfires, open_doors, shelters)

# Client tells server a door was toggled (server relays to all other clients)
@rpc("any_peer", "reliable")
func door_state_changed(door_name: String, is_open: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host and peer != null:
		for pid in players.keys():
			if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
				if peer.get_peer(pid) != null:
					door_state_changed.rpc_id(pid, door_name, is_open)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_door_state_changed"):
		scene._net_door_state_changed(door_name, is_open)

func get_my_id() -> int:
	return multiplayer.get_unique_id()

# Client requests loot inventory from a dead player corpse
@rpc("any_peer", "reliable")
func request_loot(dead_peer_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_request_loot"):
		scene._net_request_loot(sender, dead_peer_id)

# Server sends corpse inventory to requesting client
@rpc("authority", "reliable")
func send_loot(dead_peer_id: int, items_data: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_receive_loot"):
		scene._net_receive_loot(dead_peer_id, items_data)

# Client takes an item from a dead player corpse
@rpc("any_peer", "reliable")
func take_loot(dead_peer_id: int, item_index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_take_loot"):
		scene._net_take_loot(sender, dead_peer_id, item_index)

# Server sends a single looted item to the taker's client
@rpc("authority", "reliable")
func add_looted_item(item_data: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_add_looted_item"):
		scene._net_add_looted_item(item_data)
