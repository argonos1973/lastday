extends SceneTree

const Fixtures = preload("res://scripts/RowboatRegression.gd")
const BoatScript = preload("res://scripts/Rowboat.gd")
const TEST_PORT := 15573
var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		errors += 1

func run() -> void:
	var server := OS.get_cmdline_user_args().has("--net-server")
	var observer := OS.get_cmdline_user_args().has("--observer")
	var world := Fixtures.TestWorld.new()
	root.add_child(world)
	current_scene = world
	var net = root.get_node("NetworkManager")
	var api := root.get_multiplayer()
	for signal_name in ["peer_connected", "peer_disconnected", "connected_to_server", "server_disconnected", "connection_failed"]:
		for connection in api.get_signal_connection_list(signal_name):
			api.disconnect(signal_name, connection.callable)
	world.net = net
	net.is_host = server
	net.is_connected = server
	net.is_dedicated_server = server
	net.players.clear()
	net.peer = ENetMultiplayerPeer.new()
	if server:
		net.peer.set_bind_ip("127.0.0.1")
		if net.peer.create_server(TEST_PORT, 4) != OK:
			push_error("Unable to bind local rowboat test port")
			quit(1)
			return
		api.peer_connected.connect(func(id: int): net.players[id] = {"pos": Vector3(260, 0.2, -268), "anim": "idle"})
		api.peer_disconnected.connect(func(id: int): net.players[id]["offline"] = true)
	else:
		if net.peer.create_client("127.0.0.1", TEST_PORT) != OK:
			quit(1)
			return
	api.multiplayer_peer = net.peer
	world.river_segments_data = [{"center": Vector3(250, 0.085, -307), "size": Vector2(150, 90), "yaw": 0.0}]
	world._create_invisible_collision_box("Ground", Vector3(250, -0.3, -307), Vector3(220, 0.3, 140))
	var actor := Fixtures.TestPlayer.new()
	world.player = actor
	world.add_child(actor)
	actor.position = Vector3(260, 0.2, -268)
	var boat := BoatScript.new()
	boat.name = "LakeRowboat"
	boat.lake_center = Vector3(250, 0.085, -307)
	boat.position = boat.clamp_to_lake(Vector3(260, 0, -270))
	world.lake_rowboat = boat
	world.add_child(boat)
	var initial := boat.position
	if server:
		print("ROWBOAT_NETWORK_SERVER_READY")
		var saw_occupant := false
		var moved := false
		for i in range(120):
			await create_timer(0.1).timeout
			saw_occupant = saw_occupant or boat.occupant != 0
			moved = moved or boat.position.distance_to(initial) > 2.0
		check(saw_occupant, "ENet host accepted a real remote passenger")
		check(moved, "ENet host simulated remote rowing input")
		check(boat.occupant == 0, "Disconnect releases authoritative seat")
	else:
		boat.set_physics_process(false)
		for i in range(50):
			if api.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
				break
			await create_timer(0.1).timeout
		if api.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			push_error("Local rowboat test connection timed out")
			quit(1)
			return
		net.is_connected = true
		var id := api.get_unique_id()
		net.players[id] = {"pos": actor.position}
		if observer:
			for i in range(50):
				if boat.occupant != 0:
					break
				await create_timer(0.1).timeout
			var owner := boat.occupant
			net.request_rowboat.rpc_id(1, "enter")
			net.rowboat_input.rpc_id(1, Vector2(1, 1))
			net.request_rowboat.rpc_id(1, "exit")
			await create_timer(0.5).timeout
			check(owner != 0 and owner != id and boat.occupant == owner, "Second ENet client cannot steal or release occupied boat")
		else:
			await create_timer(0.3).timeout
			net.request_rowboat.rpc_id(1, "enter")
			for i in range(30):
				if boat.occupant == id:
					break
				await create_timer(0.1).timeout
			check(boat.occupant == id and actor.rowing_boat == boat, "ENet client receives boarding and seats avatar")
			for i in range(25):
				net.rowboat_input.rpc_id(1, Vector2(0, -1))
				await create_timer(0.1).timeout
			check(boat.position.distance_to(initial) > 2.0, "ENet client receives moving boat snapshots")
			net.rowboat_input.rpc_id(1, Vector2.ZERO)
			net.request_rowboat.rpc_id(1, "exit")
			await create_timer(0.3).timeout
			check(boat.occupant == id, "ENet host rejects deep-water exit")
	world._scene_quitting = true
	net.close_connection()
	world.queue_free()
	await process_frame
	print("ROWBOAT_NETWORK_ERRORS=", errors)
	quit(1 if errors else 0)
