extends SceneTree

# End-to-end cooperative feeding over a real ENet loopback:
#   autoload client -> feed_other_player.rpc_id(1,...) -> probe server
#     -> Main._net_feed_other_player -> saved_* metas on the target proxy
#     -> receive_fed_by_player.rpc_id(target) -> client handler
#     -> Main._net_receive_fed_by_player -> live stats bump.
# Covers the client->server leg (_accepts_client_request + _sender_within)
# and the server->client live delivery leg that the unit test never reaches
# (FakeNet.peer_alive() returns false there).

class ProbeNet extends "res://scripts/NetworkManager.gd":
	func _on_connected_to_server() -> void:
		pass

class ServerWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void:
		pass
	func _physics_process(_d: float) -> void:
		pass
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func play_action_animation(_a: String, _t: float = 1.0) -> void:
		pass

var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== FeedLiveE2ERegression ===")
	var world := ServerWorld.new()
	root.add_child(world)
	current_scene = world
	var scope := Node.new()
	scope.name = "ServerScope"
	root.add_child(scope)
	var api := MultiplayerAPI.create_default_interface()
	set_multiplayer(api, scope.get_path())
	var probe := ProbeNet.new()
	probe.name = "NetworkManager"
	scope.add_child(probe)
	check(probe.host_game(), "probe hosts ENet server")
	if probe.peer == null:
		print("FAIL: probe has no peer")
		quit(1)
		return
	world.net = probe
	var net = root.get_node_or_null("/root/NetworkManager")
	check(net != null, "autoload NetworkManager present")
	if net == null:
		quit(1)
		return
	check(net.join_game("127.0.0.1"), "autoload joins probe server")
	var t0 := Time.get_ticks_msec()
	while not net.is_connected and Time.get_ticks_msec() - t0 < 4000:
		await create_timer(0.05).timeout
	check(net.is_connected, "autoload connected to probe")
	await create_timer(0.6).timeout
	var client_id: int = net.get_my_id()
	check(client_id > 1, "client has real peer id (got %d)" % client_id)
	check(probe.players.has(client_id), "probe registered the client")

	# The live receiver on this process: world.player with real stats.
	var receiver := TestPlayer.new()
	world.add_child(receiver)
	receiver.stats = preload("res://scripts/SurvivalStats.gd").new()
	world.player = receiver
	receiver.stats.hunger = 40.0
	receiver.stats.thirst = 30.0
	receiver.stats.health = 60.0

	# Sender proxy (the giver = autoload client) close to the victim proxy.
	var sender_proxy := Node3D.new()
	world.add_child(sender_proxy)
	sender_proxy.global_position = Vector3(0.5, 0, 10)
	sender_proxy.set_meta("peer_id", client_id)
	sender_proxy.set_meta("proxy_health", 100.0)
	sender_proxy.set_meta("saved_hunger", 40.0)
	sender_proxy.set_meta("saved_thirst", 30.0)
	sender_proxy.set_meta("saved_health", 60.0)
	world.server_proxies[client_id] = sender_proxy

	# --- A) Client->server leg: giver RPC updates the victim proxy metas ---
	var victim_id := 77
	var victim_proxy := Node3D.new()
	world.add_child(victim_proxy)
	victim_proxy.global_position = Vector3(0.0, 0, 11.8)
	victim_proxy.set_meta("peer_id", victim_id)
	victim_proxy.set_meta("saved_hunger", 30.0)
	victim_proxy.set_meta("saved_thirst", 25.0)
	victim_proxy.set_meta("saved_health", 60.0)
	victim_proxy.set_meta("proxy_health", 60.0)
	world.server_proxies[victim_id] = victim_proxy

	net.feed_other_player.rpc_id(1, victim_id, "Naranja", "food", 20.0, 4.0, 3.0, false)
	await create_timer(0.8).timeout
	check(absf(float(victim_proxy.get_meta("saved_hunger", 0.0)) - 50.0) < 0.01,
		"feed RPC bumps saved_hunger on victim proxy (%.2f)" % float(victim_proxy.get_meta("saved_hunger", -1.0)))
	check(absf(float(victim_proxy.get_meta("saved_thirst", 0.0)) - 29.0) < 0.01,
		"feed RPC bumps saved_thirst on victim proxy (%.2f)" % float(victim_proxy.get_meta("saved_thirst", -1.0)))
	check(absf(float(victim_proxy.get_meta("saved_health", 0.0)) - 63.0) < 0.01,
		"feed RPC bumps saved_health on victim proxy (%.2f)" % float(victim_proxy.get_meta("saved_health", -1.0)))

	# --- B) Server->client live leg: receiver client gets the stat bump ---
	# sender=0 == host-authorized call, skipping the proximity/self guards.
	world._net_feed_other_player(client_id, "Naranja", "food", 30.0, 5.0, 0.0, false, 0)
	await create_timer(0.8).timeout
	check(absf(receiver.stats.hunger - 70.0) < 0.01,
		"live receiver gets +30 hunger (hunger=%.2f)" % receiver.stats.hunger)
	check(absf(receiver.stats.thirst - 35.0) < 0.01,
		"live receiver gets +5 thirst (thirst=%.2f)" % receiver.stats.thirst)
	check(absf(float(sender_proxy.get_meta("saved_hunger", 0.0)) - 70.0) < 0.01,
		"server meta saved_hunger for live receiver (%.2f)" % float(sender_proxy.get_meta("saved_hunger", -1.0)))

	# --- C) Reject: giver too far from the victim proxy on the server ---
	sender_proxy.global_position = Vector3(60, 0, 10)
	var before_h: float = float(victim_proxy.get_meta("saved_hunger", 0.0))
	net.feed_other_player.rpc_id(1, victim_id, "Naranja", "food", 20.0, 0.0, 0.0, false)
	await create_timer(0.8).timeout
	check(absf(float(victim_proxy.get_meta("saved_hunger", 0.0)) - before_h) < 0.01,
		"out-of-range feed is rejected by _sender_within")

	probe.close_connection()
	net.close_connection()
	print("FEED_LIVE_E2E_ERRORS=", failures)
	quit(1 if failures else 0)
