extends SceneTree

# Regression: a dead server character's gear (inventory + backpack + back
# equipment + clothing) must drop as ground pickups, persist in _dropped_items,
# and be respawned on a client that joins afterwards.

class ServerWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass

class ServerNet extends Node:
	var is_connected := true
	var is_host := true
	var is_dedicated_server := true
	var peer = null
	var players: Dictionary = {}
	var client_id := 0
	func get_my_id() -> int:
		return 1

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _make_proxy(world: Node, peer_id: int, cid: String, pos: Vector3) -> Node3D:
	var proxy := Node3D.new()
	proxy.name = "Proxy_%d" % peer_id
	proxy.global_position = pos
	proxy.set_meta("peer_id", peer_id)
	proxy.set_meta("client_id", cid)
	proxy.set_meta("proxy_health", 100.0)
	world.add_child(proxy)
	world.server_proxies[peer_id] = proxy
	return proxy

func _drop_ids(world: Node) -> Array:
	var out: Array = []
	for e in world._dropped_items:
		out.append(str(e.get("id", "")))
	return out

func _initialize() -> void:
	print("=== DeathLootRegression ===")
	await process_frame
	var server := ServerWorld.new()
	root.add_child(server)
	var snet := ServerNet.new()
	server.add_child(snet)
	server.net = snet
	snet.players[77] = {"name": "dead", "pos": Vector3(10, 0, 10), "client_id": "char_A"}

	# A connected character carrying loot, a backpack, shoulder gear and clothes.
	var inv: Array = [
		{"name": "Rifle", "type": "weapon_rifle", "weight": 3.5, "quantity": 1, "use_value": 0.0},
		{"name": "Higo", "type": "food", "weight": 0.1, "quantity": 3, "use_value": 12.0},
		{"name": "Venda", "type": "medical", "weight": 0.05, "quantity": 2, "use_value": 30.0}
	]
	var proxy := _make_proxy(server, 77, "char_A", Vector3(10, 0, 10))
	proxy.set_meta("saved_inventory", inv)
	proxy.set_meta("saved_backpack", "Mochila pequena")
	proxy.set_meta("saved_clothing", "Camiseta,Pantalones")
	proxy.set_meta("saved_extra", {"back_items": [{"name": "Caña de pescar", "type": "tool_fishing", "weight": 1.2, "quantity": 1, "use_value": 0.0}]})
	proxy.set_meta("saved_health", 0.0)

	server._net_player_died(77, inv, Vector3(10, 0, 10))

	check(proxy.get_meta("proxy_dead", false), "Death flags the proxy dead")
	var drops := server._dropped_items
	# 3 inventory stacks + backpack + 2 clothing + 1 back item = 7 pickups.
	check(drops.size() == 7, "All gear drops to the ground (got %d, expected 7)" % drops.size())
	var names := {}
	for e in drops:
		names[str(e.get("name", ""))] = true
	check(names.has("Rifle"), "Rifle drops")
	check(names.has("Higo"), "Food drops")
	check(names.has("Venda"), "Medical drops")
	check(names.has("Mochila pequena"), "Backpack itself drops")
	check(names.has("Camiseta") and names.has("Pantalones"), "Worn clothing drops")
	check(names.has("Caña de pescar"), "Back-stored gear drops")
	check((proxy.get_meta("saved_inventory", []) as Array).is_empty(), "Corpse record cleared after drop")
	for e in drops:
		check(server.world_actions_by_id.has(str(e.get("id", ""))), "Drop %s has a world action" % str(e.get("name", "")))

	# --- Backpack arrives only via the death RPC (saved_backpack meta stale) ---
	var drops_before := server._dropped_items.size()
	snet.players[78] = {"name": "dead2", "pos": Vector3(20, 0, 20), "client_id": "char_B"}
	var proxy2 := _make_proxy(server, 78, "char_B", Vector3(20, 0, 20))
	var inv2: Array = [{"name": "Lata de atun", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 0.0}]
	proxy2.set_meta("saved_inventory", inv2)
	proxy2.set_meta("saved_backpack", "")
	server._net_player_died(78, inv2, Vector3(20, 0, 20), "Mochila grande", "Cuchillo")
	var names2 := {}
	for e in server._dropped_items.slice(drops_before):
		names2[str(e.get("name", ""))] = true
	check(names2.has("Mochila grande"), "Backpack from death RPC drops despite empty meta")
	check(names2.has("Lata de atun"), "RPC death still drops inventory")
	check(str(proxy2.get_meta("saved_backpack", "")) == "", "saved_backpack cleared after drop")
	# A repeated death notification must not refill or duplicate the corpse.
	server._net_player_died(78, inv2, Vector3(20, 0, 20), "Mochila grande", "")
	check(server._dropped_items.size() == drops_before + 2, "Second death notice does not duplicate loot")

	# --- No meta and empty RPC backpack -> fall back to net.players record ---
	drops_before = server._dropped_items.size()
	snet.players[79] = {"name": "dead3", "pos": Vector3(30, 0, 30), "client_id": "char_C", "equipped_backpack": "Mochila de senderismo"}
	var proxy3 := _make_proxy(server, 79, "char_C", Vector3(30, 0, 30))
	var inv3: Array = [{"name": "Cerillas", "type": "tool", "weight": 0.05, "quantity": 1, "use_value": 0.0}]
	proxy3.set_meta("saved_inventory", inv3)
	proxy3.set_meta("saved_backpack", "")
	server._net_player_died(79, inv3, Vector3(30, 0, 30), "", "")
	var names3 := {}
	for e in server._dropped_items.slice(drops_before):
		names3[str(e.get("name", ""))] = true
	check(names3.has("Mochila de senderismo"), "Backpack falls back to equipped_backpack record")

	# --- Backpack already inside the inventory list must not drop twice ---
	drops_before = server._dropped_items.size()
	snet.players[80] = {"name": "dead4", "pos": Vector3(40, 0, 40), "client_id": "char_D", "equipped_backpack": "Mochila"}
	var proxy4 := _make_proxy(server, 80, "char_D", Vector3(40, 0, 40))
	var inv4: Array = [{"name": "Mochila", "type": "backpack", "weight": 0.5, "quantity": 1, "use_value": 0.0}]
	proxy4.set_meta("saved_inventory", inv4)
	proxy4.set_meta("saved_backpack", "Mochila")
	server._net_player_died(80, inv4, Vector3(40, 0, 40), "Mochila", "")
	var bp_count := 0
	for e in server._dropped_items.slice(drops_before):
		if str(e.get("name", "")) == "Mochila":
			bp_count += 1
	check(bp_count == 1, "Backpack listed in inventory is not duplicated (got %d)" % bp_count)

	# A DIFFERENT character joins later: the world-state sync must respawn every
	# drop on their client as a visible, interactable pickup.
	var client := ServerWorld.new()
	root.add_child(client)
	var cnet := ServerNet.new()
	cnet.is_host = false
	cnet.is_dedicated_server = false
	client.add_child(cnet)
	client.net = cnet
	client._net_sync_world_state([], server._dropped_items.duplicate(true), [], [], [], [])
	for e in server._dropped_items:
		var did := str(e.get("id", ""))
		check(client.world_actions_by_id.has(did), "New client receives drop %s" % str(e.get("name", "")))
		var act = client.world_actions_by_id.get(did)
		if act != null:
			check(act.is_in_group("interactable") or act.has_method("interact"), "Drop %s is interactable" % str(e.get("name", "")))

	server.free()
	client.free()
	if failures == 0:
		print("DeathLootRegression: ALL PASS")
	else:
		print("DeathLootRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
