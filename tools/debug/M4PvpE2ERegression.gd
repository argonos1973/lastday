extends SceneTree

# End-to-end PvP rifle damage over a real ENet loopback:
#   client puppet.take_damage -> /root/NetworkManager (autoload client)
#     -> damage_player RPC -> probe server -> Main._net_damage_player
# Covers body hit, head hit, and self-hit rejection.
# Also verifies a puppet clears _is_firing after the fire action timer.

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
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass
	func _spawn_blood_splatter(_p := Vector3.ZERO, _s := 1.0) -> void:
		pass
	func _hit_marker(_l) -> void:
		pass
	func _spawn_bullet_impact(_p: Vector3, _n: Vector3, _c) -> void:
		pass

var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("=== M4PvpE2ERegression ===")
	var world := ServerWorld.new()
	root.add_child(world)
	current_scene = world
	# Probe server under its own MultiplayerAPI scope (PhantomPeer pattern)
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
	# Autoload NetworkManager joins as the shooter client
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
	# Sender proxy near the victim on the server world
	var sender_proxy := Node3D.new()
	world.add_child(sender_proxy)
	sender_proxy.global_position = Vector3(11, 0, 10)
	sender_proxy.set_meta("peer_id", client_id)
	sender_proxy.set_meta("client_id", "shooter")
	sender_proxy.set_meta("proxy_health", 100.0)
	world.server_proxies[client_id] = sender_proxy
	# Victim proxy + victim puppet (client side representation)
	var victim_id := 77
	var victim_proxy := Node3D.new()
	world.add_child(victim_proxy)
	victim_proxy.global_position = Vector3(10, 0, 10)
	victim_proxy.set_meta("peer_id", victim_id)
	victim_proxy.set_meta("client_id", "victim")
	victim_proxy.set_meta("proxy_health", 100.0)
	victim_proxy.set_meta("saved_health", 100.0)
	victim_proxy.set_meta("saved_inventory", [])
	world.server_proxies[victim_id] = victim_proxy
	var puppet := TestPlayer.new()
	puppet.is_puppet = true
	root.add_child(puppet)
	puppet.set_meta("peer_id", victim_id)
	puppet.add_to_group("remote_player")
	var body := Area3D.new()
	body.name = "BodyHitbox"
	puppet.add_child(body)
	var head := Area3D.new()
	head.name = "HeadHitbox"
	puppet.add_child(head)
	await process_frame
	# --- 1) Direct take_damage on the puppet reaches the server ---
	puppet.take_damage(28.0, false, "rifle")
	await create_timer(0.8).timeout
	var hp1: float = victim_proxy.get_meta("proxy_health", 100.0)
	check(absf(hp1 - 72.0) < 0.01, "puppet body damage reaches server proxy (hp=%.2f)" % hp1)
	# --- 2) Full _apply_rifle_damage path on the BodyHitbox Area3D ---
	var shooter := TestPlayer.new()
	root.add_child(shooter)
	shooter._apply_rifle_damage(body, puppet.global_position + Vector3(0, 1, 0), 10.0, Vector3.UP, true)
	await create_timer(0.8).timeout
	var hp2: float = victim_proxy.get_meta("proxy_health", 100.0)
	check(hp2 < hp1 - 20.0, "M4 projectile hit on BodyHitbox damages victim (hp=%.2f)" % hp2)
	# --- 3) Headshot uses the M4 head profile (60 dmg vs 28 body) ---
	victim_proxy.set_meta("proxy_health", 100.0)
	shooter._apply_rifle_damage(head, puppet.global_position + Vector3(0, 1.6, 0), 10.0, Vector3.UP, true)
	await create_timer(0.8).timeout
	var hp3: float = victim_proxy.get_meta("proxy_health", 100.0)
	check(hp3 <= 100.0 - 55.0, "M4 headshot applies head damage (hp=%.2f)" % hp3)
	# --- 4) Self-hit is rejected ---
	var self_puppet := TestPlayer.new()
	self_puppet.is_puppet = true
	root.add_child(self_puppet)
	self_puppet.set_meta("peer_id", client_id)
	self_puppet.add_to_group("remote_player")
	self_puppet.take_damage(50.0, false, "rifle")
	await create_timer(0.8).timeout
	var hp_self: float = sender_proxy.get_meta("proxy_health", 100.0)
	check(absf(hp_self - 100.0) < 0.01, "self-hit does not damage shooter proxy (hp=%.2f)" % hp_self)
	# --- 5) Puppet fire state clears after the action timer ---
	puppet._is_firing = true
	puppet.third_person_action_timer = 1.0
	puppet.set_process(true)
	var t1 := Time.get_ticks_msec()
	while puppet._is_firing and Time.get_ticks_msec() - t1 < 3000:
		await create_timer(0.1).timeout
	check(not puppet._is_firing, "puppet _is_firing clears after fire timer")
	check(puppet.third_person_action_timer <= 0.0, "puppet action timer elapses")
	# --- 6) Aim release clears the aim pose state ---
	puppet.puppet_set_aiming(true)
	check(puppet._is_aiming, "puppet aim flag set")
	puppet._rifle_aim_pose_active = true
	puppet.puppet_set_aiming(false)
	check(not puppet._is_aiming, "puppet aim flag cleared")
	check(not puppet._rifle_aim_pose_active, "aim pose inactive after release")
	probe.close_connection()
	net.close_connection()
	print("M4_PVP_E2E_ERRORS=", failures)
	quit(1 if failures else 0)
