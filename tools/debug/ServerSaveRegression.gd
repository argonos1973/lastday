extends SceneTree

# Verifies the dedicated-server save separation:
# - connected modes never read/write the single-player savegame.json
# - dedicated server writes its own server_savegame.json (world + players by client_id)
# - server save preloads world state and restores reconnecting players

const SaveHooksScript = preload("res://scripts/SaveGameHooks.gd")

class World extends "res://scripts/Main.gd":
	var sent_restore: Array = []
	var sent_spawn_only: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _delayed_send_reconnect_state(peer_id: int, pos: Vector3, inv: Array, hp: float, hunger: float, thirst: float, clothing: String, backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float, prone: bool = false, crouching: bool = false, extra: Dictionary = {}) -> void:
		sent_restore.append([peer_id, pos])
	func _delayed_send_spawn_pos(peer_id: int, pos: Vector3, died: bool = false) -> void:
		sent_spawn_only.append([peer_id, pos])
	var spawned_pickups: Array = []
	func _spawn_ground_pickup(item_name: String, item_type: String, pos: Vector3, weight: float, qty: int, use_value: float, fixed_id: String = "", action_type_override: String = "") -> void:
		spawned_pickups.append(pos)
		_dropped_items.append({"id": fixed_id, "name": item_name, "type": item_type, "weight": weight, "qty": qty, "use": use_value, "pos": [pos.x, pos.y, pos.z], "action_type": "pickup_item"})

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
	# Use a cid not claimed by any live proxy so this exercises the save path.
	world._server_saved_players["cid_restore"] = {"pos": [3.0, 0.4, 4.0], "inventory": [{"name": "Hacha"}], "extra": {"back_items": [{"name": "Rifle francotirador"}]}}
	var fresh := Node3D.new()
	fresh.name = "ServerProxy_7"
	world.add_child(fresh)
	world.server_proxies[7] = fresh
	world._match_proxy_to_client(7, "cid_restore")
	check(world._server_saved_players.has("cid_restore"), "restored player entry kept as merge baseline")
	var rinv: Array = fresh.get_meta("saved_inventory", [])
	check(rinv.size() == 1 and str(rinv[0].get("name", "")) == "Hacha", "restored proxy keeps saved inventory meta")
	check(fresh.global_position.distance_to(Vector3(3.0, 0.4, 4.0)) < 0.001, "restored proxy placed at saved position")
	check(fresh.get_meta("saved_extra", {}).get("back_items", []).size() == 1, "restored proxy keeps extra meta")

	# Register-RPC-before-proxy race: a saved player whose proxy has not been
	# spawned yet must still be restored (previously fell through to a random
	# spawn because server_proxies.has(peer_id) was false).
	world._server_saved_players["cid_race"] = {"pos": [7.0, 0.4, 8.0], "inventory": [{"name": "Pan"}], "health": 66.0}
	world._match_proxy_to_client(9, "cid_race")
	check(world.server_proxies.has(9), "missing proxy spawned synchronously during match")
	if world.server_proxies.has(9):
		var race_proxy: Node3D = world.server_proxies[9]
		check(race_proxy.global_position.distance_to(Vector3(7.0, 0.4, 8.0)) < 0.001, "raced proxy placed at saved position")
		check(str(race_proxy.get_meta("client_id", "")) == "cid_race", "raced proxy gets client_id")
	check(world._server_saved_players.has("cid_race"), "raced player entry kept as merge baseline")

	# Reconnect racing ahead of the disconnect: the proxy is still live under a
	# stale peer_id — it must be rebound, not duplicated into a bare proxy.
	var stale := Node3D.new()
	stale.set_meta("client_id", "cid_stale")
	stale.set_meta("saved_clothing", "Camiseta,Pantalones")
	stale.set_meta("saved_inventory", [{"name": "Cuerda"}])
	world.add_child(stale)
	stale.global_position = Vector3(44.0, 0.4, 45.0)
	stale.set_meta("saved_pos", stale.global_position)
	world.server_proxies[50] = stale
	var dupe := Node3D.new()
	world.add_child(dupe)
	world.server_proxies[60] = dupe
	world._match_proxy_to_client(60, "cid_stale")
	check(not world.server_proxies.has(50), "stale peer_id proxy removed on rebind")
	check(world.server_proxies.get(60) == stale, "reconnect rebinds existing proxy to new peer_id")
	check(str(stale.get_meta("saved_clothing", "")) == "Camiseta,Pantalones", "rebound proxy keeps saved clothing")
	check(not is_instance_valid(dupe) or dupe.is_queued_for_deletion(), "fresh duplicate proxy freed on rebind")

	# A bare proxy must never strip fields the baseline already saved.
	# (cid_race's live proxy at peer 9 is still around — remove it first so the
	# bare one is the only claim on a fresh cid.)
	if world.server_proxies.has(9):
		var race_p: Node3D = world.server_proxies[9]
		world.server_proxies.erase(9)
		race_p.queue_free()
	var bare := Node3D.new()
	bare.set_meta("client_id", "cid_race")
	bare.set_meta("peer_id", 77)
	world.add_child(bare)
	bare.global_position = Vector3(9.0, 0.4, 9.0)
	world.server_proxies[77] = bare
	net.players[77] = {"client_id": "cid_race", "char_name": "RaceChar"}
	world._save_world_change_silent()
	var merged: Dictionary = sgm.load_server_game().get("players", {}).get("cid_race", {})
	check(not merged.is_empty(), "bare proxy still produces a player record")
	check(merged.has("health") and float(merged.get("health")) == 66.0, "baseline fills health stripped from bare proxy")
	check(merged.has("inventory") and merged["inventory"].size() == 1, "baseline fills inventory stripped from bare proxy")
	var mp: Array = merged.get("pos", [])
	check(mp.size() == 3 and is_equal_approx(float(mp[0]), 9.0), "live proxy position wins over baseline")
	world.server_proxies.erase(77)
	bare.queue_free()
	net.players.erase(77)

	# Unknown client falls back to normal new-player flow
	var fresh2 := Node3D.new()
	world.add_child(fresh2)
	world.server_proxies[8] = fresh2
	world._match_proxy_to_client(8, "cid_unknown")
	check(fresh2.get_meta("client_id", "") == "cid_unknown", "new player proxy gets client_id")

	# Bare saved record (appearance/pos only, no state keys — e.g. stripped by
	# an old corrupt save): restore the position but never send an empty
	# inventory restore, which would wipe the client's starting gear.
	world._server_saved_players["cid_bare"] = {"pos": [5.0, 0.4, 6.0], "char_name": "Bare"}
	world._match_proxy_to_client(11, "cid_bare")
	await process_frame
	await process_frame
	check(world.sent_spawn_only.any(func(e): return e[0] == 11), "bare record sends spawn position only")
	check(not world.sent_restore.any(func(e): return e[0] == 11), "bare record never sends empty inventory restore")
	if world.server_proxies.has(11):
		check(world.server_proxies[11].global_position.distance_to(Vector3(5.0, 0.4, 6.0)) < 0.001, "bare record still restores position")

	# Bare live proxy (no saved_* metas — its client never synced): same rule.
	var bare_live := Node3D.new()
	bare_live.set_meta("client_id", "cid_barelive")
	world.add_child(bare_live)
	bare_live.global_position = Vector3(12.0, 0.4, 13.0)
	bare_live.set_meta("saved_pos", bare_live.global_position)
	world.proxy_by_client_id["cid_barelive"] = bare_live
	world._match_proxy_to_client(70, "cid_barelive")
	await process_frame
	await process_frame
	check(world.sent_spawn_only.any(func(e): return e[0] == 70), "bare live proxy sends spawn position only")
	check(not world.sent_restore.any(func(e): return e[0] == 70), "bare live proxy never sends empty restore")
	check(world.server_proxies.get(70) == bare_live, "bare live proxy rebound to new peer")

	# Records/proxies with real state still get the full restore.
	check(world.sent_restore.any(func(e): return e[0] == 7), "saved record sends inventory restore")
	check(world.sent_restore.any(func(e): return e[0] == 60), "stateful rebind sends inventory restore")
	check(world.sent_spawn_only.any(func(e): return e[0] == 8), "new player gets spawn position only")

	# Death: loot drops at the client's real death position — not the proxy's
	# stale last-synced pos — and the corpse stays pinned to it.
	net.players[80] = {"client_id": "cid_dying", "pos": Vector3(1.0, 0.4, 1.0), "anim": "run"}
	var dying := Node3D.new()
	dying.set_meta("client_id", "cid_dying")
	dying.set_meta("peer_id", 80)
	dying.set_meta("saved_inventory", [{"name": "Hacha", "type": "tool", "weight": 1.0, "quantity": 1}])
	world.add_child(dying)
	dying.global_position = Vector3(1.0, 0.4, 1.0)
	world.server_proxies[80] = dying
	var death_p := Vector3(30.0, 0.45, -25.0)
	world._net_player_died(80, [{"name": "Hacha", "type": "tool", "weight": 1.0, "quantity": 1}], death_p)
	check(dying.global_position.distance_to(death_p) < 0.001, "death anchors proxy to real death position")
	check((net.players[80]["pos"] as Vector3).distance_to(death_p) < 0.001, "death anchors player list position")
	check(dying.get_meta("proxy_dead", false), "death marks proxy dead")
	check(world.spawned_pickups.size() == 1 and (world.spawned_pickups[0] as Vector3).distance_to(death_p) < 5.0, "death loot spawns around the corpse")
	check((dying.get_meta("saved_inventory", []) as Array).is_empty(), "dropped inventory cleared from proxy")
	world.server_proxies.erase(80)
	net.players.erase(80)
	dying.queue_free()

	# Server character appearance: a client_id with a saved record gets its own
	# stored look back (the Inicio card must not reskin the server character).
	world._server_saved_players["cid_look"] = {"char_name": "Soldado", "top_color": "0.1,0.2,0.3", "bottom_color": "0.4,0.5,0.6", "top_camo": true}
	var aargs: Array = world._saved_appearance_args("cid_look")
	check(aargs.size() == 8, "saved appearance payload built for known client_id")
	if aargs.size() == 8:
		check(str(aargs[0]) == "Soldado", "saved appearance keeps character name")
		check((aargs[1] as Color).is_equal_approx(Color(0.1, 0.2, 0.3)), "saved appearance keeps top color")
		check(aargs[6] == true, "saved appearance keeps camo flag")
	check(world._saved_appearance_args("cid_norecord").is_empty(), "no appearance payload for unknown client_id")

	# Dead record: fresh start — spawn-only, baseline erased so the corpse's
	# gear can't merge back into the new character's record.
	world._server_saved_players["cid_dead"] = {"pos": [9.0, 0.4, 9.0], "inventory": [{"name": "Hacha"}], "clothing": "Camiseta", "dead": true}
	world._match_proxy_to_client(90, "cid_dead")
	await process_frame
	await process_frame
	check(world.sent_spawn_only.any(func(e): return e[0] == 90), "dead record sends spawn position only")
	check(not world.sent_restore.any(func(e): return e[0] == 90), "dead record never restores inventory")
	check(not world._server_saved_players.has("cid_dead"), "dead record baseline erased")
	if world.server_proxies.has(90):
		check(not (world.server_proxies[90] as Node3D).has_meta("saved_inventory"), "dead record leaves no gear metas on fresh proxy")

	# hp<=0 without a death flag (quit while dying / decay between saves) counts
	# as dead: gear drops once at the record position, then a fresh start.
	var pickups_before := world.spawned_pickups.size()
	world._server_saved_players["cid_hp0"] = {"pos": [7.0, 0.4, 7.0], "health": 0.0, "inventory": [{"name": "Hacha"}, {"name": "Pan"}], "clothing": "Camiseta"}
	world._match_proxy_to_client(91, "cid_hp0")
	await process_frame
	await process_frame
	check(world.sent_spawn_only.any(func(e): return e[0] == 91), "hp0 record sends spawn position only")
	check(not world.sent_restore.any(func(e): return e[0] == 91), "hp0 record never restores inventory")
	check(not world._server_saved_players.has("cid_hp0"), "hp0 record baseline erased")
	check(world.spawned_pickups.size() == pickups_before + 2, "hp0 record drops the corpse gear once")
	if world.server_proxies.has(91):
		var hp0_proxy: Node3D = world.server_proxies[91]
		check(not hp0_proxy.has_meta("saved_inventory") and not hp0_proxy.has_meta("loot_dropped"), "hp0 proxy is clean for the fresh character")

	# An offline peer (parked in proxy_by_client_id) must not respawn a bare
	# ghost proxy — it would hijack the cid in the save dedup and strip fields.
	net.players[77] = {"client_id": "cid_off", "offline": true}
	world._update_server_proxies(0.016)
	check(not world.server_proxies.has(77), "offline peer does not respawn a ghost proxy")
	check(not offproxy.get_meta("proxy_dead", false), "offline proxy does not starve to death")
	check(not offproxy.has_meta("saved_hunger"), "offline proxy stats stay frozen")

	# --- Server world-state restore (post-restart, no visuals spawned) ---
	sgm.save_server_game({
		"dropped_items": [{"id": "drop_1", "name": "Lata", "pos": [1.0, 0.1, 2.0]}],
		"built_campfires": [{"id": "cf_1", "pos": [4.0, 0.0, 5.0]}],
		"lit_campfires": [{"id": "cf_1", "pos": [4.0, 0.0, 5.0], "fire_name": "fire_cf_1"}],
		"built_shelters": [{"id": "sh_1", "pos": [6.0, 0.0, 7.0]}],
		"open_doors": ["house_1 Door"],
		"campfire_fire_timers": {"fire_cf_1": 30000},
		"dead_wildlife": [{"name": "Wolf_9", "type": "wolf", "pos": [0.0, 0.0, 0.0], "rot": 0.0}],
	}, {})
	world._load_server_world_state()
	check(world._dropped_items.size() == 1, "server restores dropped item list")
	check(world._built_campfires.size() == 1, "server restores built campfires")
	check(world._lit_campfires.size() == 1, "server restores lit campfires")
	check(world._built_shelters.size() == 1, "server restores built shelters")
	check(world._server_door_states.get("house_1 Door", false) == true, "server restores open door states")
	check(world.campfire_fire_timers.has("fire_cf_1"), "server restores campfire burn timers")

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

	# --- Join in flight: peer created but handshake pending (dead/slow server).
	# It must still count as multiplayer — otherwise the client falls into the
	# single-player path and savegame.json leaks into the session (open doors).
	net.is_connected = false
	net.is_host = false
	net.is_dedicated_server = false
	net.peer = ENetMultiplayerPeer.new()
	var save_path: String = sgm.get_save_path()
	var bak_path := "user://saves/savegame.bak.json"
	var had_local: bool = FileAccess.file_exists(save_path)
	var old_main := FileAccess.get_file_as_string(save_path) if had_local else ""
	var had_bak: bool = FileAccess.file_exists(bak_path)
	var old_bak := FileAccess.get_file_as_string(bak_path) if had_bak else ""
	var gsess = root.get_node_or_null("/root/GameSession")
	var old_cid := ""
	if gsess != null:
		old_cid = str(gsess.selected_character_id)
		gsess.selected_character_id = "saved"
	sgm.save_game({"pos": [0.0, 0.4, 0.0]}, {"open_doors": ["Leak Door"], "depleted_action_ids": ["leak_cut"], "picked_up_loot_ids": ["leak_loot"]})
	world._pending_open_doors.clear()
	world._depleted_action_ids.erase("leak_cut")
	world._depleted_action_ids.erase("leak_loot")
	SaveHooksScript.preload_saved_world_state(world)
	SaveHooksScript.maybe_load_saved_game(world, host_player)
	check(world._pending_open_doors.is_empty(), "join in flight never loads single-player open_doors")
	check(not world._depleted_action_ids.has("leak_cut"), "join in flight never loads single-player depleted ids")
	check(not world._depleted_action_ids.has("leak_loot"), "join in flight never loads picked-up loot ids")
	world._mp_session = false
	var pre_write_hash := _local_save_hash(sgm)
	SaveHooksScript.maybe_save_game(world, host_player)
	check(_local_save_hash(sgm) == pre_write_hash, "join in flight never writes savegame.json")
	# Restore the real local save byte-for-byte
	if had_local:
		var rf := FileAccess.open(save_path, FileAccess.WRITE)
		if rf != null:
			rf.store_string(old_main)
			rf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	if had_bak:
		var bf := FileAccess.open(bak_path, FileAccess.WRITE)
		if bf != null:
			bf.store_string(old_bak)
			bf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bak_path))
	if gsess != null:
		gsess.selected_character_id = old_cid
	net.peer = null

	# Restore previous server save state
	sgm.delete_server_save()
	if had_server_save:
		sgm.save_server_game(old_server_save.get("world", {}), old_server_save.get("players", {}))

	world.free()
	if failures == 0:
		print("PASS: dedicated server uses its own save file; local save untouched; players persist by client_id")
	quit(1 if failures else 0)
