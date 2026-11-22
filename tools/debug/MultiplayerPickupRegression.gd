extends SceneTree

class TestMain extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void: pass
	func _save_world_change_silent() -> void: pass

class ProbeNet extends "res://scripts/NetworkManager.gd":
	var replies: Dictionary = {}
	var gifts: Array = []
	var client_world: Node

	func _on_connected_to_server() -> void:
		is_connected = true
		var id := multiplayer.get_unique_id()
		players[id] = {"name":"Probe", "ready":true}
		_register_player.rpc_id(1, id, "Probe", client_id, _join_password)
	@rpc("authority", "reliable")
	func pickup_claim_result(id: String, accepted: bool) -> void:
		replies[id] = accepted
		if is_instance_valid(client_world) and client_world._pickup_replies.has(id):
			client_world._pickup_replies[id] = accepted
	@rpc("authority", "reliable")
	func backpack_give(data: Dictionary) -> void:
		gifts.append(data)
	@rpc("authority", "reliable")
	func backpack_contents_synced(_id: String, _contents: Array) -> void: pass
	@rpc("any_peer", "reliable")
	func item_picked_up(_id: String) -> void: pass
	@rpc("any_peer", "reliable")
	func world_action_completed(id: String, spawns: Array, extra: String, pos: Vector3) -> void:
		if _accepts_world_sender(multiplayer.get_remote_sender_id()) and is_instance_valid(client_world):
			client_world._net_world_action_completed(id, spawns, extra, pos)

class NightBots extends "res://scripts/SurvivorBotManager.gd":
	func _is_world_night() -> bool: return true

# An activated action and a distant, unactivated tree must both disappear.
func tree_fixture(world: Node3D, active: bool) -> MultiMesh:
	var pos := Vector3(60, 0, 60)
	var entry := {"id":987654,"pos":pos,"visual_name":""}
	world._tree_entries_by_id[987654] = entry
	world._tree_grid[Vector2i.ZERO] = [entry]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = CylinderMesh.new()
	mm.instance_count = 1
	var transform := Transform3D(Basis.IDENTITY, pos)
	mm.set_instance_transform(0, transform)
	var visual := MultiMeshInstance3D.new()
	visual.multimesh = mm
	world.add_child(visual)
	world._tree_mm_slots[world._tree_mm_slot_key(pos)] = [[mm, 0, transform]]
	if active:
		var action := WorldAction.new()
		action.action_id = "fell_tree_987654"
		action.action_type = "fell_tree"
		action.position = pos
		world.add_child(action)
		world.world_actions_by_id[action.action_id] = action
	return mm

func check_bot_tree_chain(main, a: ProbeNet, b: ProbeNet) -> void:
	var old_dedicated: bool = main.net.is_dedicated_server
	main.net.is_dedicated_server = true
	var clients: Array = []
	var meshes: Array = []
	for peer in [a, b]:
		var view := TestMain.new()
		root.add_child(view)
		view.net = peer
		peer.client_world = view
		clients.append(view)
		meshes.append(tree_fixture(view, peer == a))
	tree_fixture(main, true)
	var manager := NightBots.new()
	main.add_child(manager)
	manager.set_process(false)
	manager.world = main
	var proxy := Node3D.new()
	main.add_child(proxy)
	main.server_proxies[901] = proxy
	proxy.position = Vector3(60, 0, 60)
	proxy.set_meta("saved_inventory", [
		{"name":"Hacha","type":"tool_axe","quantity":1,"weight":1.4,"durability":80.0},
		{"name":"Palo","type":"resource","quantity":1,"weight":0.3}])
	var bot := {"proxy":proxy,"bot_id":901,"clothing":"","backpack":"Mochila militar",
		"torch_lit":false,"held_item":"Hacha","campfire_id":"","campfire_pos":Vector3.INF,
		"shelter_id":"","hunger":80.0,"thirst":80.0,"health":100.0,"_mem":{}}
	manager._bot_fell_tree_complete(bot, {"id":"fell_tree_987654","pos":proxy.position})
	await create_timer(0.3).timeout
	var logs: Array = main._dropped_items.filter(func(e): return str(e.id).begins_with("pickup_Tronco_fell_tree_987654_"))
	check(logs.size() == 4 and manager._bot_item_count(proxy, "Tronco") == 0,
		"bot felling creates four distinct world logs, never direct inventory grants")
	check(main._legit_cut_trees.has("fell_tree_987654"), "server records a legitimate cut for persistence")
	check(not manager._bot_build_and_light_campfire(bot, Vector3(65,0,60)),
		"felled tree alone cannot pay for a campfire before pickup")
	for i in clients.size():
		var view = clients[i]
		check(view._hidden_tree_transforms.has(Vector3(60,0,60)) and view._cut_remains_positions.size() == 1,
			"real peer %d hides the standing tree and creates visible stump/log remains" % i)
		check(logs.all(func(e): return view.world_actions_by_id.has(e.id)),
			"real peer %d receives all four log pickups" % i)
		if DisplayServer.get_name() != "headless":
			check(meshes[i].get_instance_transform(0).basis.get_scale().length() < 0.001,
				"GPU tree instance is hidden for peer %d" % i)
	# The existing reach/rise must finish before either log enters inventory.
	# A broken/lost axe after chopping must not block picking up the logs.
	proxy.set_meta("saved_inventory", [{"name":"Palo","type":"resource","quantity":1,"weight":0.3}])
	for entry in logs.slice(0, 2):
		proxy.global_position = manager._loot_entry_pos(entry)
		var before: int = manager._bot_item_count(proxy, "Tronco")
		bot["_s_loot"] = entry
		manager._bot_prepare_night_supplies(bot, 0.7)
		check(manager._bot_item_count(proxy, "Tronco") == before, "pickup cannot grant a log before the gesture finishes")
		manager._bot_prepare_night_supplies(bot, 0.8)
		check(manager._bot_item_count(proxy, "Tronco") == before + 1, "completed ground gesture acquires one real log")
	await create_timer(0.3).timeout
	check(clients.all(func(view): return not view.world_actions_by_id.has(logs[0].id) and not view.world_actions_by_id.has(logs[1].id)),
		"both peers remove the two collected logs")
	var saved := SaveGameHooks.collect_world_data(main)
	var restored := TestMain.new()
	root.add_child(restored)
	tree_fixture(restored, true)
	SaveGameHooks.apply_saved_world_data(restored, JSON.parse_string(JSON.stringify(saved)))
	check(restored._depleted_action_ids.has("fell_tree_987654") and restored._cut_remains_positions.size() == 1,
		"save/load retains the cut tree and visible remains")
	check(restored.world_actions_by_id.has(logs[2].id) and not restored.world_actions_by_id.has(logs[0].id),
		"save/load restores only uncollected logs")
	var late := TestMain.new()
	root.add_child(late)
	tree_fixture(late, true)
	late._net_sync_world_state(main._depleted_action_ids.duplicate(), main._dropped_items.duplicate(true), [], [], [])
	check(late._hidden_tree_transforms.has(Vector3(60,0,60)) and late._cut_remains_positions.size() == 1 and late.world_actions_by_id.has(logs[3].id),
		"late world sync hides an activated tree and restores remaining logs")
	check(manager._bot_build_and_light_campfire(bot, Vector3(65,0,60)),
		"two acquired logs and one stick build the real campfire")
	check(manager._bot_item_count(proxy, "Tronco") == 0 and manager._bot_item_count(proxy, "Palo") == 0,
		"real campfire consumes exactly the acquired materials")
	# Drain reliable RPCs before returning to the unrelated pickup cases.
	await create_timer(0.2).timeout
	for peer in [a, b]:
		peer.client_world = null
	for view in clients:
		view.free()
	restored.free()
	late.free()
	main.server_proxies.erase(901)
	proxy.free()
	manager.free()
	main.net.is_dedicated_server = old_dedicated

class Actor extends Node3D:
	signal notice(message: String)
	var _interact_busy := false
	var _action_serial := 0
	var inventory := Inventory.new()
	func _init() -> void: add_child(inventory)
	func _mark_action_started() -> int:
		_action_serial += 1
		return _action_serial

var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)

func probe(label: String) -> ProbeNet:
	var scope := Node.new()
	scope.name = label
	root.add_child(scope)
	var api := MultiplayerAPI.create_default_interface()
	api.root_path = scope.get_path()
	set_multiplayer(api, scope.get_path())
	var n := ProbeNet.new()
	n.name = "NetworkManager"
	scope.add_child(n)
	n.client_id = "pickup_regression_" + label
	n.join_game("ws://127.0.0.1:19081" if OS.get_cmdline_user_args().has("--websocket") else "127.0.0.1")
	return n

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var server = root.get_node("NetworkManager")
	if not server.host_game():
		check(false, "test port available")
		quit(1)
		return
	if OS.get_cmdline_user_args().has("--websocket"):
		server.peer.close()
		var ws := WebSocketMultiplayerPeer.new()
		ws.outbound_buffer_size = 4 * 1024 * 1024
		ws.inbound_buffer_size = 1024 * 1024
		check(ws.create_server(19081, "127.0.0.1") == OK, "isolated WebSocket listener")
		server.peer = ws
		server.multiplayer.multiplayer_peer = ws
	var main := TestMain.new()
	root.add_child(main)
	current_scene = main
	main.net = server
	var a := probe("PickupA")
	var b := probe("PickupB")
	await create_timer(0.6).timeout
	var aid := a.multiplayer.get_unique_id()
	var bid := b.multiplayer.get_unique_id()
	check(server.players.has(aid) and server.players.has(bid), "two real clients registered")
	await check_bot_tree_chain(main, a, b)
	for id in [aid, bid]:
		var proxy := Node3D.new()
		main.add_child(proxy)
		proxy.set_meta("saved_inventory", [])
		main.server_proxies[id] = proxy
	var gesture := PlayerController.GroundGesture.packet("pickup", "floor|test", "Seta amanita", "food", 0.7)
	a.sync_player_state.rpc_id(1, aid, Vector3.ZERO, 0.0, gesture, "", "", "")
	await create_timer(0.2).timeout
	check(str(server.players[aid].get("anim", "")) == gesture and str(b.players.get(aid, {}).get("anim", "")) == gesture,
		"pickup identity and phase reach the host and the other real client unchanged")
	if OS.get_cmdline_user_args().has("--websocket"):
		check(server.can_send_snapshot(aid), "healthy WebSocket accepts snapshots")
		# Stop polling the receiver while filling the OS/TCP buffers. Production
		# must stop adding poses before the WebSocket's 4 MB queue is exhausted.
		multiplayer_poll = false
		for generation in 256:
			if not server.can_send_snapshot(aid): break
			server.sync_animals.rpc_id(aid, {"_gen":generation,"_total":1,"deer_test":{"t":"deer","x":1.0,"padding":"x".repeat(80000)}})
		check((server.peer as WebSocketMultiplayerPeer).get_peer(aid).get_current_outbound_buffered_amount() < 200000, "snapshot backlog stays bounded")
		check(not server.can_send_snapshot(aid), "queued wildlife snapshot applies backpressure")
		check(server.can_send_snapshot(bid), "slow client does not block healthy client")
		multiplayer_poll = true
		await create_timer(.6).timeout
		check(server.can_send_snapshot(aid), "snapshots resume after buffer drains")
		check(a.animals.has("deer_test"), "wildlife snapshot reaches WebSocket client")
	main._dropped_items.append({"id":"skin", "name":"Tocado de oso", "type":"clothing", "qty":1, "pos":Vector3.ZERO, "pelt":"bear"})
	a.request_pickup_claim.rpc_id(1, "skin")
	b.request_pickup_claim.rpc_id(1, "skin")
	await create_timer(0.25).timeout
	check(a.replies.has("skin") and b.replies.has("skin") and a.replies["skin"] != b.replies["skin"], "simultaneous claims have exactly one winner")
	var winner: ProbeNet = a if a.replies.get("skin", false) else b
	var loser: ProbeNet = b if winner == a else a
	var winner_id := winner.multiplayer.get_unique_id()
	check(not main._net_item_picked_up("skin", loser.multiplayer.get_unique_id()), "non-owner cannot commit a reserved pickup")
	# Failed local capacity check: release lets the other player try again.
	winner.release_pickup_claim.rpc_id(1, "skin")
	await create_timer(0.15).timeout
	check(not main._pickup_claims.has("skin"), "cancelled pickup releases reservation")
	winner.request_pickup_claim.rpc_id(1, "skin")
	await create_timer(0.15).timeout
	# Use the production RPC, not the probe's receiving override.
	winner.rpc_id(1, "item_picked_up", "skin")
	await create_timer(0.15).timeout
	check(main._depleted_action_ids.has("skin"), "owner commit depletes world item")
	check(not main._net_item_picked_up("skin", loser.multiplayer.get_unique_id()), "already depleted item rejects duplicate commit")
	var inv: Array = main.server_proxies[winner_id].get_meta("saved_inventory")
	check(inv.size() == 1 and inv[0].get("pelt_species") == "bear", "reconnect inventory preserves pelt species")
	var original: Array = [{"name":"Piedra", "type":"resource", "quantity":1}, {"name":"Tronco", "type":"resource", "quantity":1}]
	main._dropped_items.append({"id":"stash", "pos":Vector3.ZERO, "contents":original.duplicate(true)})
	a.backpack_take.rpc_id(1, "stash", 0, original)
	await create_timer(0.15).timeout
	b.backpack_take.rpc_id(1, "stash", 0, original)
	await create_timer(0.15).timeout
	check(a.gifts.size() == 1 and a.gifts[0]["name"] == "Piedra", "first stash withdrawal returns selected item")
	check(b.gifts.is_empty(), "stale stash selection never returns the shifted item")
	b.backpack_take.rpc_id(1, "stash", 0, [original[1]])
	await create_timer(0.15).timeout
	check(b.gifts.size() == 1 and b.gifts[0]["name"] == "Tronco", "refreshed stash selection succeeds")
	# Un refugio no pertenece al peer que lo construyó: cualquier jugador dentro
	# de alcance puede abrir el alijo, sacar y guardar por la ruta autoritativa.
	var sh_id := "foreign_shelter"
	var sh_contents: Array = [{"name":"Piedra", "type":"resource", "quantity":1}]
	var sh_action = main._create_world_action(sh_id, "shelter", "Refugio", Vector3.ZERO, Vector3(2.0, 1.5, 3.0), Color.WHITE, true, false)
	sh_action.set_meta("contents", sh_contents.duplicate(true))
	main._built_shelters.append({"id":sh_id, "pos":Vector3.ZERO, "yaw":0.0, "contents":sh_contents.duplicate(true), "pelt_lined":false, "camo_covered":false})
	main.server_proxies[bid].global_position = Vector3(20.0, 0.0, 0.0)
	b.backpack_take.rpc_id(1, sh_id, 0, sh_contents)
	await create_timer(0.15).timeout
	check(b.gifts.size() == 1, "out-of-range player cannot raid a shelter")
	main.server_proxies[bid].global_position = Vector3.ZERO
	b.backpack_take.rpc_id(1, sh_id, 0, sh_contents)
	await create_timer(0.15).timeout
	check(b.gifts.size() == 2 and b.gifts[1]["name"] == "Piedra", "non-owner takes an item from another shelter")
	check((sh_action.get_meta("contents", []) as Array).is_empty() and (main._built_shelters[0].get("contents", []) as Array).is_empty(), "shelter take persists authoritative contents")
	b.backpack_store.rpc_id(1, sh_id, {"name":"Tronco", "type":"resource", "quantity":1})
	await create_timer(0.15).timeout
	check((sh_action.get_meta("contents", []) as Array).size() == 1 and str(sh_action.get_meta("contents", [])[0].get("name", "")) == "Tronco", "non-owner stores an item in another shelter")
	check((main._built_shelters[0].get("contents", []) as Array).size() == 1, "shelter store persists authoritative contents")
	# Exercise the actual client handler: no optimistic inventory mutation.
	var client := TestMain.new()
	root.add_child(client)
	client.net = a
	a.client_world = client
	var actor := Actor.new()
	client.add_child(actor)
	var action := WorldAction.new()
	action.action_type = "pickup_item"
	action.action_id = "client_gate"
	action.set_meta("item_name", "Piedra")
	action.set_meta("item_type", "resource")
	client.add_child(action)
	main._dropped_items.append({"id":"client_gate", "name":"Piedra", "type":"resource", "qty":1, "pos":Vector3.ZERO})
	check(main._claim_world_pickup("client_gate", bid), "other player reserves client test item")
	client.handle_world_action_collect(action, actor)
	check(actor.inventory.items.is_empty(), "inventory unchanged while awaiting authority")
	await create_timer(0.25).timeout
	check(actor.inventory.items.is_empty() and not action.depleted and not actor._interact_busy, "denied claim leaves inventory and item untouched")
	main._pickup_claims.erase("client_gate")
	client.handle_world_action_collect(action, actor)
	actor._action_serial += 1
	actor._interact_busy = false
	await create_timer(0.25).timeout
	check(actor.inventory.items.is_empty() and not action.depleted and not main._pickup_claims.has("client_gate"),
		"cancelling while awaiting the server releases the claim and never starts the pickup")
	actor.inventory.max_weight = 0.0
	await client.handle_world_action_collect(action, actor)
	await create_timer(0.15).timeout
	check(not main._pickup_claims.has("client_gate") and not action.depleted, "full inventory releases claim without consuming item")
	actor.inventory.max_weight = 18.0
	await client.handle_world_action_collect(action, actor)
	await create_timer(0.15).timeout
	check(actor.inventory.items.size() == 1 and main._depleted_action_ids.has("client_gate"), "granted claim adds exactly one item and commits to server")
	check(not main._pickup_claims.has("client_gate"), "successful handler releases claim")
	# world_action_completed respeta el claim: tala/construccion/desmontaje
	# commitean por esa RPC, no por item_picked_up.
	main._pickup_claims["treeX"] = aid
	main._pickup_claim_until["treeX"] = Time.get_ticks_msec() + 60000
	check(not main._net_world_action_completed("treeX", [], "", Vector3.ZERO, bid), "world_action_completed rejected for another peer's claim")
	# La reserva caduca: un peer vivo que nunca libera no bloquea para siempre.
	main._pickup_claim_until["treeX"] = Time.get_ticks_msec() - 1
	check(main._claim_world_pickup("treeX", bid), "expired claim can be re-taken by another peer")
	check(main._net_world_action_completed("treeX", [], "", Vector3.ZERO, bid), "new claim owner may complete its reserved action")
	# Tipos consumibles/de construccion recien cubiertos por el claim.
	for t in ["pick_fruit", "fell_tree", "fell_bush", "cut_log", "build_cabin", "shelter", "farm_plot"]:
		var wa := WorldAction.new()
		wa.action_type = t
		check(main._pickup_needs_claim(wa), "claim covers %s" % t)
		wa.free()
	# Revalidacion de alcance: quien se aleja durante el timer no commitea.
	var far_actor := Actor.new()
	client.add_child(far_actor)
	far_actor.global_position = Vector3(100.0, 0.0, 0.0)
	var wa_reach := WorldAction.new()
	wa_reach.action_id = "reach_a"
	wa_reach.action_type = "pickup_item"
	client.add_child(wa_reach)
	check(not main._actor_still_reaches(wa_reach, far_actor, 15.0), "walked-away actor fails commit reach check")
	far_actor.global_position = Vector3(1.0, 0.0, 0.0)
	check(main._actor_still_reaches(wa_reach, far_actor, 15.0), "near actor passes commit reach check")
	wa_reach.free()
	far_actor.free()
	client.free()
	a.close_connection()
	b.close_connection()
	server.close_connection()
	main.free()
	a.get_parent().queue_free()
	b.get_parent().queue_free()
	await process_frame
	print("failures=", failures)
	quit(1 if failures else 0)
