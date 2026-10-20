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

class Actor extends Node3D:
	signal notice(message: String)
	var _interact_busy := false
	var inventory := Inventory.new()
	func _init() -> void: add_child(inventory)

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
	n.join_game("127.0.0.1")
	return n

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var server = root.get_node("NetworkManager")
	if not server.host_game():
		check(false, "test port available")
		quit(1)
		return
	var main := TestMain.new()
	root.add_child(main)
	current_scene = main
	main.net = server
	var a := probe("PickupA")
	var b := probe("PickupB")
	await create_timer(0.6).timeout
	var aid := a.multiplayer.get_unique_id()
	var bid := b.multiplayer.get_unique_id()
	check(server.players.has(aid) and server.players.has(bid), "two real ENet clients registered")
	for id in [aid, bid]:
		var proxy := Node3D.new()
		main.add_child(proxy)
		proxy.set_meta("saved_inventory", [])
		main.server_proxies[id] = proxy
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
	for t in ["pick_fruit", "fell_tree", "fell_bush", "cut_log", "build_cabin", "shelter"]:
		var wa := WorldAction.new()
		wa.action_type = t
		check(main._pickup_needs_claim(wa), "claim covers %s" % t)
		wa.free()
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
