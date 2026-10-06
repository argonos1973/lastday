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
	proxy.set_meta("peer_id", peer_id)
	proxy.set_meta("client_id", cid)
	proxy.set_meta("proxy_health", 100.0)
	world.add_child(proxy)
	proxy.global_position = pos
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
	snet.players[77] = {"name": "dead", "pos": Vector3(10, 0, 10), "client_id": "char_A", "top_camo": true, "top_color": Color(0.8, 0.2, 0.1), "bottom_color": Color(0.1, 0.3, 0.7)}

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
	# Customizable clothing keeps the dead player's own colors in the drop —
	# otherwise observers tint it with their local player colors.
	var shirt_col := Color(0, 0, 0, 0)
	var pants_col := Color(0, 0, 0, 0)
	for e in drops:
		var carr = e.get("color", [])
		if not (carr is Array) or carr.size() < 3:
			continue
		if str(e.get("name", "")) == "Camiseta":
			shirt_col = Color(float(carr[0]), float(carr[1]), float(carr[2]))
		elif str(e.get("name", "")) == "Pantalones":
			pants_col = Color(float(carr[0]), float(carr[1]), float(carr[2]))
	for entry in server._dropped_items:
		if str(entry.get("name", "")) == "Camiseta":
			check(bool(entry.get("camo", false)), "Corpse shirt preserves camouflage in saved and broadcast loot")
	check(shirt_col.is_equal_approx(Color(0.8, 0.2, 0.1)), "Shirt drops with the victim's top color")
	check(pants_col.is_equal_approx(Color(0.1, 0.3, 0.7)), "Pants drop with the victim's bottom color")
	check(names.has("Caña de pescar"), "Back-stored gear drops")
	check((proxy.get_meta("saved_inventory", []) as Array).is_empty(), "Corpse record cleared after drop")
	for e in drops:
		check(server.world_actions_by_id.has(str(e.get("id", ""))), "Drop %s has a world action" % str(e.get("name", "")))

	# --- Death RPC payload is not trusted: only the server record drops ---
	var drops_before := server._dropped_items.size()
	snet.players[78] = {"name": "dead2", "pos": Vector3(20, 0, 20), "client_id": "char_B", "equipped_backpack": "Mochila grande"}
	var proxy2 := _make_proxy(server, 78, "char_B", Vector3(20, 0, 20))
	var inv2: Array = [{"name": "Lata de atun", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 0.0}]
	proxy2.set_meta("saved_inventory", inv2)
	proxy2.set_meta("saved_backpack", "")
	# The RPC declares gear the server never saw — it must not spawn.
	server._net_player_died(78, [{"name": "Rifle francotirador", "type": "weapon_rifle", "quantity": 99}], Vector3(20, 0, 20), "Mochila inventada", "Cuchillo")
	var names2 := {}
	for e in server._dropped_items.slice(drops_before):
		names2[str(e.get("name", ""))] = true
	check(names2.has("Mochila grande"), "Backpack drops from the live player-state record")
	check(names2.has("Lata de atun"), "Death drops the server-side inventory")
	check(not names2.has("Mochila inventada"), "Fabricated RPC backpack does not drop")
	check(not names2.has("Rifle francotirador"), "Fabricated RPC inventory does not drop")
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

	# --- Death loot must never land in water: clients only show a splash for
	# water drops (no visual, no action), so the item is silently unreachable.
	# A corpse by the shore still drops its gear on land. ---
	drops_before = server._dropped_items.size()
	# River rect covers x in [10, 30] at z=10 — the corpse at x=10 sits right at
	# the waterline and every outward scatter to +x would sink without resampling.
	server.river_segments_data = [{"center": Vector3(20.0, 0.0, 10.0), "size": Vector2(20.0, 10.0), "yaw": 0.0}]
	snet.players[82] = {"name": "dead5", "pos": Vector3(10, 0, 10), "client_id": "char_E"}
	var proxy5 := _make_proxy(server, 82, "char_E", Vector3(10, 0, 10))
	proxy5.set_meta("saved_inventory", [
		{"name": "Sombrero de pescador", "type": "clothing", "weight": 0.2, "quantity": 1, "use_value": 0.07},
		{"name": "Higo", "type": "food", "weight": 0.1, "quantity": 2, "use_value": 12.0}
	])
	proxy5.set_meta("saved_clothing", "Camiseta,Pantalones,Zapatillas")
	server._net_player_died(82, [], Vector3(10, 0, 10))
	var names5 := {}
	var water_drops := 0
	for e in server._dropped_items.slice(drops_before):
		names5[str(e.get("name", ""))] = true
		var pa = e.get("pos", [])
		if pa is Array and pa.size() >= 3:
			var dp := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
			if server._is_water_drop_position(dp):
				water_drops += 1
	check(names5.has("Sombrero de pescador"), "Hat drops from corpse record")
	check(water_drops == 0, "No corpse loot lands in water (got %d)" % water_drops)
	server.river_segments_data = []

	# --- Door toggles are validated server-side: known door + sender in reach ---
	var dproxy := _make_proxy(server, 81, "char_door", Vector3(22.0, 0.0, 21.0))
	check(server._net_door_state_changed("Casa abandonada 3 Door", true, 81), "door toggle accepted next to the door")
	check(server._server_door_states.get("Casa abandonada 3 Door", false) == true, "door state recorded")
	dproxy.global_position = Vector3(-50.0, 0.0, -50.0)
	check(not server._net_door_state_changed("Casa abandonada 4 Door", true, 81), "door toggle rejected when sender is far away")
	check(not server._net_door_state_changed("Puerta inventada", true, 81), "unknown door name rejected")
	server.server_proxies.erase(81)
	dproxy.queue_free()

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
