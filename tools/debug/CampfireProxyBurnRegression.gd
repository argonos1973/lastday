extends SceneTree

# Verifies that parked offline proxies burn when standing in a lit campfire
# on the dedicated server, using the same radius/damage as the local player.
class FakeNet extends Node:
	signal player_connected(id)
	signal player_disconnected(id)
	signal connection_failed
	var peer = null
	var players := {}
	var is_host := true
	var is_dedicated_server := true
	var is_connected := true
	func get_my_id() -> int:
		return 1

var _failures := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_failures += 1
		print("FAIL: " + label)

func _make_proxy(pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.set_meta("peer_id", 42)
	p.set_meta("proxy_health", 10.0)
	p.set_meta("saved_health", 10.0)
	p.set_meta("saved_inventory", [{"name": "Trapos", "type": "resource", "weight": 0.1, "quantity": 2, "use_value": 0.0}])
	p.add_to_group("net_player_proxy")
	return p

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# net stays null through _ready so Main skips the dedicated-server boot
	# path (which would delete the server save); the fake is assigned after.
	var main: Node = load("res://scripts/Main.gd").new()
	get_root().add_child(main)
	var fake := FakeNet.new()
	get_root().add_child(fake)
	main.net = fake
	var fire_pos := Vector3(5.0, 0.0, 5.0)
	main.campfire_positions.append(fire_pos)

	# Proxy standing inside the burn radius (<0.6 m) takes damage.
	var burning := _make_proxy(Vector3(5.0, 0.0, 5.2))
	get_root().add_child(burning)
	burning.global_position = Vector3(5.0, 0.0, 5.2)
	main.proxy_by_client_id["cid_burn"] = burning
	main._update_server_proxies(1.0)
	_check(absf(burning.get_meta("proxy_health") - 5.0) < 0.01, "proxy in fire loses 5 hp per second")
	_check(absf(burning.get_meta("saved_health") - 5.0) < 0.01, "saved_health tracks the burn")

	# Proxy just outside the burn radius but inside the warmth ring is safe —
	# offline stats are frozen, so warmth is meaningless and must not hurt.
	var warm := _make_proxy(Vector3(5.0, 0.0, 7.0))
	get_root().add_child(warm)
	warm.global_position = Vector3(5.0, 0.0, 7.0)
	main.proxy_by_client_id["cid_warm"] = warm
	main._update_server_proxies(1.0)
	_check(absf(warm.get_meta("proxy_health") - 10.0) < 0.01, "proxy at 2 m takes no fire damage")

	# Burning to zero marks the proxy dead, moves it to interactable and drops loot.
	main._update_server_proxies(1.0)
	_check(burning.get_meta("proxy_dead", false), "burned-to-zero proxy is dead")
	_check(not burning.is_in_group("net_player_proxy"), "dead proxy leaves net_player_proxy")
	_check(burning.is_in_group("interactable"), "dead proxy becomes interactable corpse")
	_check(burning.get_meta("loot_dropped", false), "corpse loot dropped")

	# Dead proxies are skipped — no double death processing.
	var hp_after: float = burning.get_meta("proxy_health")
	main._update_server_proxies(1.0)
	_check(absf(burning.get_meta("proxy_health") - hp_after) < 0.01, "dead proxy not damaged further")

	if _failures > 0:
		push_error("CampfireProxyBurnRegression: %d failure(s)" % _failures)
		quit(1)
	else:
		print("CampfireProxyBurnRegression: all checks passed")
		quit(0)
