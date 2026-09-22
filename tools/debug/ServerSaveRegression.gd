extends SceneTree

# Verifies the dedicated-server save separation:
# - connected modes never read/write the single-player savegame.json
# - dedicated server writes its own server_savegame.json (world + players by client_id)
# - server save preloads world state and restores reconnecting players

const SaveHooksScript = preload("res://scripts/SaveGameHooks.gd")

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _local_save_hash(sgm: Node) -> String:
	var path: String = sgm.get_save_path()
	if not FileAccess.file_exists(path):
		return "none"
	var f := FileAccess.open(path, FileAccess.READ)
	var t: String = f.get_as_text() if f != null else ""
	return str(t.hash())

func run() -> void:
	var sgm = root.get_node_or_null("/root/SaveGameManager")
	var net = root.get_node_or_null("/root/NetworkManager")
	check(sgm != null and net != null, "autoloads available")
	if sgm == null or net == null:
		quit(1)
		return

	# Preserve any pre-existing server save; start clean
	var had_server_save: bool = sgm.has_server_save()
	var old_server_save: Dictionary = sgm.load_server_game() if had_server_save else {}
	sgm.delete_server_save()
	var local_hash_before := _local_save_hash(sgm)

	# Fake dedicated-server network state
	net.is_connected = true
	net.is_host = true
	net.is_dedicated_server = true
	net.client_id = "server"
	net.players.clear()

	var world := World.new()
	root.add_child(world)
	current_scene = world
	world.net = net
	world.player = Node3D.new()
	world.add_child(world.player)

	# --- Server save roundtrip: world + players by client_id ---
	var proxy := Node3D.new()
	proxy.name = "ServerProxy_42"
	proxy.set_meta("client_id", "cid_abc")
	proxy.set_meta("saved_inventory", [{"name": "Hacha", "quantity": 1}])
	proxy.set_meta("saved_health", 80.0)
	proxy.set_meta("saved_hunger", 55.0)
	proxy.set_meta("saved_thirst", 60.0)
	proxy.set_meta("saved_clothing", "Camiseta")
	proxy.set_meta("saved_rot", 1.25)
	proxy.set_meta("saved_extra", {
		"back_items": [{"name": "Rifle francotirador"}],
		"held_item_data": {},
		"rifle_ammo": {"initialized": true, "magazine": 3, "reserve": 15},
		"stats_extra": {"sleep": 60.0, "survival_seconds": 3600.0},
	})
	world.add_child(proxy)
	proxy.set_meta("peer_id", 42)
	# Appearance comes from the live player table, not the proxy
	net.players[42] = {"client_id": "cid_abc", "char_name": "TestServerChar", "top_color": Color(0.1, 0.2, 0.3), "top_camo": true}
	proxy.global_position = Vector3(10.0, 0.4, -20.0)
	world.server_proxies[42] = proxy

	# Offline proxy (disconnected player) also persisted
	var offproxy := Node3D.new()
	offproxy.set_meta("client_id", "cid_off")
	offproxy.set_meta("saved_inventory", [{"name": "Cuchillo"}])
	world.add_child(offproxy)
	offproxy.global_position = Vector3(-5.0, 0.4, 7.0)
	world.proxy_by_client_id["cid_off"] = offproxy

	# Stale entry from a previous boot must survive the next save
	world._server_saved_players["cid_ghost"] = {"pos": [1.0, 0.4, 2.0], "inventory": [{"name": "Pan"}]}

	world._save_world_change_silent()
	check(sgm.has_server_save(), "dedicated server writes server_savegame.json")
	var ssave: Dictionary = sgm.load_server_game()
	check(ssave.has("world"), "server save contains world data")
	var players: Dictionary = ssave.get("players", {})
	check(players.has("cid_abc"), "online proxy persisted under client_id")
	check(players.has("cid_off"), "disconnected proxy persisted under client_id")
	check(players.has("cid_ghost"), "unreconnected saved player survives new saves")
	if players.has("cid_abc"):
		var inv: Array = players["cid_abc"].get("inventory", [])
		check(inv.size() == 1 and str(inv[0].get("name", "")) == "Hacha", "proxy inventory stored")
		var p: Array = players["cid_abc"].get("pos", [])
		check(p.size() == 3 and is_equal_approx(float(p[0]), 10.0) and is_equal_approx(float(p[2]), -20.0), "proxy position stored")
		var extra: Dictionary = players["cid_abc"].get("extra", {})
		check(extra.get("back_items", []).size() == 1, "back-slot items persisted in extra")
		check(int(extra.get("rifle_ammo", {}).get("reserve", 0)) == 15, "rifle ammo persisted in extra")
		check(float(extra.get("stats_extra", {}).get("survival_seconds", 0.0)) == 3600.0, "extended stats persisted in extra")
		check(str(players["cid_abc"].get("char_name", "")) == "TestServerChar", "character name persisted")
		check(str(players["cid_abc"].get("top_color", "")).begins_with("0.1"), "appearance color persisted")
	check(_local_save_hash(sgm) == local_hash_before, "single-player save untouched by dedicated save")

	# --- Connected client must not write any save ---
	net.is_host = false
	net.is_dedicated_server = false
	sgm.delete_server_save()
	world._save_world_change_silent()
	check(not sgm.has_server_save(), "pure client never writes server save")
	check(_local_save_hash(sgm) == local_hash_before, "pure client never writes local save")

	# --- Preload: dedicated server reads server save, not savegame.json ---
	net.is_host = true
	net.is_dedicated_server = true
	sgm.save_server_game({
		"depleted_action_ids": ["test_depleted"],
		"legit_cut_trees": [],
		"picked_up_loot_ids": ["test_loot"],
		"fruit_tree_cooldowns": {"fruit_a": 5000.0},
		"fruit_tree_types": {"fruit_a": "apple"},
	}, {"cid_abc": {"pos": [3.0, 0.4, 4.0], "inventory": [{"name": "Hacha"}], "extra": {"back_items": [{"name": "Rifle francotirador"}]}}})
	SaveHooksScript.preload_saved_world_state(world)
	check(world._depleted_action_ids.has("test_depleted"), "server save preloads depleted actions")
	check(world._depleted_action_ids.has("test_loot"), "server save preloads picked loot")
	check(world._pending_fruit_cooldowns.get("fruit_a", 0.0) == 5000.0, "server save preloads fruit cooldowns")
	check(world._server_saved_players.has("cid_abc"), "server save stashes saved players")
	check(_local_save_hash(sgm) == local_hash_before, "preload does not touch local save")

	# --- Reconnect restore: saved player data lands on the fresh proxy ---
	var fresh := Node3D.new()
	fresh.name = "ServerProxy_7"
	world.add_child(fresh)
	world.server_proxies[7] = fresh
	world._match_proxy_to_client(7, "cid_abc")
	check(not world._server_saved_players.has("cid_abc"), "restored player entry consumed")
	var rinv: Array = fresh.get_meta("saved_inventory", [])
	check(rinv.size() == 1 and str(rinv[0].get("name", "")) == "Hacha", "restored proxy keeps saved inventory meta")
	check(fresh.global_position.distance_to(Vector3(3.0, 0.4, 4.0)) < 0.001, "restored proxy placed at saved position")
	check(fresh.get_meta("saved_extra", {}).get("back_items", []).size() == 1, "restored proxy keeps extra meta")

	# Unknown client falls back to normal new-player flow
	var fresh2 := Node3D.new()
	world.add_child(fresh2)
	world.server_proxies[8] = fresh2
	world._match_proxy_to_client(8, "cid_unknown")
	check(fresh2.get_meta("client_id", "") == "cid_unknown", "new player proxy gets client_id")

	# --- Host (non-dedicated) also uses server save, with full own-player payload ---
	net.is_dedicated_server = false
	net.client_id = "host_cid"
	var host_player := TestPlayer.new()
	world.add_child(host_player)
	world.player = host_player
	world._save_server_world()
	var hsave: Dictionary = sgm.load_server_game()
	check(hsave.get("players", {}).has("host_cid"), "host saves own player under client_id")
	check(_local_save_hash(sgm) == local_hash_before, "host save still leaves local savegame.json alone")

	# Restore previous server save state
	sgm.delete_server_save()
	if had_server_save:
		sgm.save_server_game(old_server_save.get("world", {}), old_server_save.get("players", {}))

	world.free()
	if failures == 0:
		print("PASS: dedicated server uses its own save file; local save untouched; players persist by client_id")
	quit(1 if failures else 0)
