extends SceneTree

# Regression for the multiplayer auth gate — runs a real ENet server (the
# autoload NetworkManager) plus in-process "clients" on branch-scoped
# MultiplayerAPIs whose RPCs reach the server autoload at /root/NetworkManager:
#
# - a transport-connected peer that never runs _register_player must never
#   enter `players`, never receive _sync_player_list, and must be kicked after
#   REGISTRATION_TIMEOUT (previously sync_player_state auto-created the entry,
#   letting an unauthenticated peer act as a real player)
# - the broadcast player list never leaks client_id (the reconnection token)
# - a reconnect with the same client_id kicks the stale peer and keeps the new

class ProbeNet extends "res://scripts/NetworkManager.gd":
	var auto_register := true
	func _on_connected_to_server() -> void:
		is_connected = true
		var my_id := multiplayer.get_unique_id()
		players[my_id] = {"name": "Jugador_%d" % my_id, "pos": SPAWN_POS, "rot": 0.0, "ready": true}
		if auto_register:
			_register_player.rpc_id(1, my_id, players[my_id]["name"], client_id, _join_password)
		connection_succeeded.emit()

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _make_probe(scope_name: String, cid: String, register: bool) -> ProbeNet:
	var scope := Node.new()
	scope.name = scope_name
	root.add_child(scope)
	var api := MultiplayerAPI.create_default_interface()
	set_multiplayer(api, scope.get_path())
	var c := ProbeNet.new()
	c.name = "NetworkManager"
	scope.add_child(c)
	c.client_id = cid
	c.auto_register = register
	return c

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== PhantomPeerRegression ===")
	var net = root.get_node_or_null("/root/NetworkManager")
	if net == null or not net.host_game():
		print("FAIL: server did not start")
		quit(1)
		return

	# --- Phantom: connects at transport level, never registers ---
	var phantom: ProbeNet = _make_probe("PhantomScope", "cid_phantom", false)
	phantom.join_game("127.0.0.1")
	var t := create_timer(0.6)
	await t.timeout
	var phantom_id: int = phantom.multiplayer.get_unique_id() if phantom.is_connected else -1
	check(phantom.is_connected, "phantom reaches the transport layer")
	check(phantom_id > 1, "phantom has a real peer id (got %d)" % phantom_id)

	# Inject the RPC that used to auto-create a player entry.
	phantom.sync_player_state.rpc_id(1, phantom_id, Vector3(5, 0, 5), 0.0, "idle", "", "", "")
	phantom.sync_player_state.rpc_id(1, phantom_id, Vector3(6, 0, 6), 0.0, "run", "", "", "")
	await create_timer(0.4).timeout
	check(not net.players.has(phantom_id), "phantom never enters players via sync_player_state")

	# --- Legit client registers; the list must not leak client_id ---
	var legit: ProbeNet = _make_probe("LegitScope", "cid_legit", true)
	legit.join_game("127.0.0.1")
	await create_timer(0.8).timeout
	var legit_id: int = legit.multiplayer.get_unique_id() if legit.is_connected else -1
	check(legit_id > 1 and legit_id != phantom_id, "legit has its own peer id (got %d)" % legit_id)
	check(net.players.has(legit_id), "registered client enters players")
	check(net.players.get(legit_id, {}).get("client_id", "") == "cid_legit", "server keeps client_id for persistence")
	check(not net.players.has(phantom_id), "phantom still absent after a real registration")
	check(legit.players.has(1) and legit.players.has(legit_id), "legit received the player list")
	for pid in legit.players.keys():
		check(not (legit.players[pid] is Dictionary and legit.players[pid].has("client_id")), "broadcast list leaks client_id of peer %d" % pid)
	check(not phantom.players.has(1) and phantom.players.size() == 1, "phantom never received the player list")

	# --- Registration timeout kicks the phantom ---
	await create_timer(net.REGISTRATION_TIMEOUT + 1.5).timeout
	check(not net.peer_alive(phantom_id), "phantom kicked after registration timeout")
	check(not phantom.is_connected, "phantom sees the disconnect locally")
	check(net.peer_alive(legit_id), "registered client survives the sweep")

	# --- Reconnect with the same client_id: stale peer kicked, new one kept ---
	var legit2: ProbeNet = _make_probe("Legit2Scope", "cid_legit", true)
	legit2.join_game("127.0.0.1")
	await create_timer(0.8).timeout
	var legit2_id: int = legit2.multiplayer.get_unique_id() if legit2.is_connected else -1
	check(legit2_id > 1 and legit2_id != legit_id, "reconnect gets a new peer id (got %d)" % legit2_id)
	check(net.players.has(legit2_id), "reconnecting client registered")
	check(net.players.get(legit2_id, {}).get("client_id", "") == "cid_legit", "reconnect claims the same client_id")
	await create_timer(0.6).timeout
	check(not net.players.has(legit_id), "stale entry for the same client_id removed")
	check(not net.peer_alive(legit_id), "stale peer disconnected on cid reclaim")
	check(net.peer_alive(legit2_id), "new connection stays")

	# Cleanup
	if phantom != null and phantom.is_connected:
		phantom.close_connection()
	if legit2 != null and legit2.is_connected:
		legit2.close_connection()
	net.close_connection()
	if failures == 0:
		print("PhantomPeerRegression: ALL PASS")
	else:
		print("PhantomPeerRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
