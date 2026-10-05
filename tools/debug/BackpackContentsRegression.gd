extends SceneTree

# Regresión: soltar la última mochila mete el exceso dentro del drop
# (meta "contents") en vez de desparramar objetos por el suelo, y el
# contenido se gestiona con K / vuelve al inventario al recogerla.
# Uso: godot --headless --path . --script tools/debug/BackpackContentsRegression.gd

const ItemScript = preload("res://scripts/Item.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class TestWorld extends "res://scripts/Main.gd":
	var saved_world: Dictionary = {}
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		saved_world = SaveHooks.collect_world_data(self)
	# Sin visuales GLB: replica solo la parte de datos de la función real.
	func _spawn_dropped_item_visual(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3, color: Color = Color(0, 0, 0, 0), broken: bool = false, spoilage: float = 0.0, contents: Array = [], wetness: float = 0.0, camo: bool = false) -> void:
		var action = _create_world_action(drop_id, "pickup_item", item_name, pos, Vector3.ONE, Color.WHITE, false, false)
		action.set_meta("item_name", item_name)
		action.set_meta("item_type", item_type)
		action.set_meta("item_weight", item_weight)
		action.set_meta("item_quantity", item_quantity)
		action.set_meta("item_use_value", item_use_value)
		if not contents.is_empty():
			action.set_meta("contents", contents)

class TestNetwork extends Node:
	var is_host := true
	var is_dedicated_server := true
	var is_connected := false
	var peer = null
	var players: Dictionary = {}
	func get_my_id() -> int:
		return 1

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world.net = TestNetwork.new()
	var hud_stub = load("res://scripts/HUD.gd").new()
	world.add_child(hud_stub)
	world.hud = hud_stub
	var player := TestPlayer.new()
	root.add_child(player)
	world.player = player
	player._initializing = false

	# Mochila equipada + inventario por encima de la capacidad base (3).
	# El jugador arranca con ropa en el inventario, así que todo se calcula
	# dinámicamente sobre el estado real.
	var bp = ItemScript.create("Mochila pequena", "backpack", 0.8, 1, 0.0)
	player.inventory.items.append(bp)
	for i in range(9):
		player.inventory.items.append(ItemScript.create("Palo", "resource", 0.3, 1, 0.0))
	player.equipped_backpack = "Mochila pequena"
	player._recalculate_carry_capacity()
	var slots_sin_mochila: int = int(player._compute_carry_capacity(false)["slots"])
	var size_before: int = player.inventory.items.size()
	var expected_packed: int = size_before - 1 - slots_sin_mochila
	var expected_slots: int = slots_sin_mochila + player.SMALL_BACKPACK_SLOTS
	check(player.inventory.max_slots == expected_slots, "Backpack raises carry capacity to %d (got %d)" % [expected_slots, player.inventory.max_slots])

	var drops: Array = []
	player.item_dropped.connect(func(n, t, w, q, u, p, c, b, s): drops.append({"n": n, "t": t, "w": w, "q": q, "u": u, "p": p, "c": c, "b": b, "s": s}))

	# Soltar la mochila: un solo drop (la mochila), nada desparramado.
	player.drop_inventory_item(int(player.inventory.items.find(bp)))
	check(drops.size() == 1, "Dropping a full backpack emits one drop only (got %d)" % drops.size())
	check(drops.size() > 0 and drops[0]["n"] == "Mochila pequena", "The single drop is the backpack itself")
	check(player.has_meta("pending_backpack_contents"), "Overflow is packed inside the backpack drop")
	var packed: Array = player.get_meta("pending_backpack_contents", [])
	check(packed.size() == expected_packed, "Items that no longer fit are packed inside (expected %d, got %d)" % [expected_packed, packed.size()])
	check(player.inventory.items.size() == size_before - 1 - expected_packed, "Inventory shrinks to base capacity without spilling")
	check(player.equipped_backpack.is_empty(), "Backpack unequips when its last unit leaves")

	# El drop en el mundo lleva el contenido en el meta y en la entrada persistida.
	if drops.size() > 0:
		var d0 = drops[0]
		world._on_item_dropped(d0.n, d0.t, d0.w, d0.q, d0.u, d0.p, d0.c, d0.b, d0.s)
	check(not player.has_meta("pending_backpack_contents"), "Pending contents meta is consumed by the drop")
	var action = null
	for k in world.world_actions_by_id.keys():
		action = world.world_actions_by_id[k]
	check(action != null, "A world action exists for the dropped backpack")
	if action != null:
		check((action.get_meta("contents", []) as Array).size() == expected_packed, "World action stores the packed contents")
		check(str(action.get_interaction_text(player)).contains("[K] Abrir"), "Interaction text offers [K] Abrir")
	check(not world._dropped_items.is_empty() and (world._dropped_items[0].get("contents", []) as Array).size() == expected_packed, "Dropped-item entry persists the contents")

	# Recogerla: el contenido vuelve al inventario plano (equipada da huecos).
	if action != null:
		world.handle_world_action_collect(action, player)
	check(player.equipped_backpack == "Mochila pequena", "Picking it up equips the backpack again")
	# Los objetos apilables se funden en un stack: contar unidades, no entradas.
	var units_after := 0
	for it in player.inventory.items:
		if it != null:
			units_after += int(it.quantity)
	check(units_after == size_before, "Packed contents merge back into the inventory (expected %d units, got %d)" % [size_before, units_after])
	check(world._dropped_items.is_empty(), "Consumed drop leaves no ghost entries")

	# Panel K: sacar un objeto del contenido al inventario (host/offline).
	var bp_action = world._create_world_action("bp_drop_1", "pickup_item", "Mochila pequena", Vector3.ZERO, Vector3.ONE, Color.WHITE, false, false)
	bp_action.set_meta("item_name", "Mochila pequena")
	bp_action.set_meta("item_type", "backpack")
	var seed_contents: Array = [
		ItemScript.create("Piedra", "resource", 0.5, 2, 0.0).to_dict(),
		ItemScript.create("Trapos", "resource", 0.05, 1, 0.0).to_dict()
	]
	bp_action.set_meta("contents", seed_contents.duplicate(true))
	world._dropped_items.append({"id": "bp_drop_1", "name": "Mochila pequena", "type": "backpack", "weight": 0.8, "qty": 1, "use": 0.0, "pos": Vector3.ZERO, "contents": seed_contents.duplicate(true)})
	world._backpack_action = bp_action
	var before_take: int = player.inventory.items.size()
	world._backpack_take(0)
	check(player.inventory.items.size() == before_take + 1, "Coger moves the packed stack into the inventory")
	check((bp_action.get_meta("contents", []) as Array).size() == 1, "Contents shrink after Coger")
	check((world._dropped_items[0].get("contents", []) as Array).size() == 1, "Persisted entry follows the take")

	# Panel K: meter un objeto del inventario dentro de la mochila tirada.
	var palo_idx := -1
	for i in range(player.inventory.items.size()):
		if str(player.inventory.items[i].item_name) == "Palo":
			palo_idx = i
			break
	check(palo_idx >= 0, "Inventory still has a Palo to store")
	if palo_idx >= 0:
		var before_store: int = player.inventory.items.size()
		world._backpack_store(palo_idx)
		check(player.inventory.items.size() == before_store - 1, "Meter removes the item from the inventory")
		check((bp_action.get_meta("contents", []) as Array).size() == 2, "Contents grow after Meter")
		check((world._dropped_items[0].get("contents", []) as Array).size() == 2, "Persisted entry follows the store")

	# Round-trip de serialización: el contenido sobrevive a to_dict/from_dict.
	var bp_with_contents = ItemScript.create("Mochila pequena", "backpack", 0.8, 1, 0.0)
	bp_with_contents.contents.append(ItemScript.create("Palo", "resource", 0.3, 2, 0.0))
	var restored_bp = ItemScript.from_dict(bp_with_contents.to_dict())
	check(restored_bp.contents.size() == 1 and restored_bp.contents[0].item_name == "Palo", "Backpack contents survive save serialization")
	var empty_bp = ItemScript.create("Mochila pequena", "backpack", 0.8, 1, 0.0)
	check(not empty_bp.can_stack_with(bp_with_contents), "A filled backpack never merges into a stack")

	# Refugio de palos: el alijo usa el mismo flujo que la mochila — contents en
	# la action, _built_shelters lo persiste para sync/save, y desmontar un
	# refugio con objetos dentro se rechaza.
	var sh_id := "player_shelter_test"
	world._spawn_player_shelter_with_id(sh_id, Vector3(20, 0, 20))
	var sh_action = world.world_actions_by_id.get(sh_id)
	check(sh_action != null, "Built shelter registers a world action")
	check(world._built_shelters.size() == 1, "Spawn registers exactly one persistent shelter")
	player.global_position = Vector3(20, 0, 21)
	if sh_action != null:
		check(str(sh_action.action_type) == "shelter", "Shelter world action type")
		check(str(sh_action.get_interaction_text(player)).contains("[K]"), "Shelter prompt offers [K] for the stash")
		player.inventory.add_item(ItemScript.create("Palo", "resource", 0.3, 1, 0.0))
		var p_idx: int = player.inventory.items.size() - 1
		check(p_idx >= 0, "Inventory has a Palo for the stash")
		if p_idx >= 0:
			world._backpack_action = sh_action
			var inv_before: int = player.inventory.items.size()
			world._backpack_store(p_idx)
			check(player.inventory.items.size() == inv_before - 1, "Meter moves the item into the shelter stash")
			check((sh_action.get_meta("contents", []) as Array).size() == 1, "Shelter action stores the stash")
			check((world._built_shelters[0].get("contents", []) as Array).size() == 1, "built_shelters entry carries the stash for sync/save")
		check(world._net_shelter_dismantled(sh_id, 0) == false, "Dismantling a stocked shelter is refused")
		check(world.world_actions_by_id.has(sh_id), "Refused shelter stays in the world")
		world._backpack_take(0)
		check((sh_action.get_meta("contents", []) as Array).is_empty(), "Coger empties the shelter stash")
		check(world._net_shelter_dismantled(sh_id, 0) == true, "Empty shelter dismantles normally")
		check(not world.world_actions_by_id.has(sh_id), "Dismantled shelter leaves the world")

	player.global_position = Vector3.ZERO
	# Panel del alijo: cada fila lleva thumbnail 3D + linea de estado, y
	# cualquier tecla (Tab, Esc, K...) cierra el panel.
	var stash_action = world._create_world_action("stash_ui", "shelter", "Refugio", Vector3.ZERO, Vector3.ONE, Color.WHITE, false, false)
	stash_action.set_meta("contents", [
		ItemScript.create("Palo", "resource", 0.3, 2, 0.0).to_dict(),
		ItemScript.create("Higo", "food", 0.1, 1, 0.0).to_dict()
	])
	world._backpack_action = stash_action
	world._refresh_backpack_ui()
	check(world._backpack_panel != null, "Stash panel builds for a shelter action")
	var n_thumbs := 0
	var n_state_labels := 0
	for cont in world._backpack_panel.find_children("*", "ItemThumbnail3D", true, false):
		n_thumbs += 1
	for lbl in world._backpack_panel.find_children("*", "Label", true, false):
		if str((lbl as Label).text).contains("Estado"):
			n_state_labels += 1
	check(n_thumbs >= 2, "Each stash row renders a 3D thumbnail (got %d)" % n_thumbs)
	check(n_state_labels >= 2, "Each stash row shows an Estado line (got %d)" % n_state_labels)
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	world._input(ev)
	check(world._backpack_panel == null, "Tab closes the stash panel")
	world._refresh_backpack_ui()
	var ev2 := InputEventKey.new()
	ev2.keycode = KEY_ESCAPE
	ev2.pressed = true
	world._input(ev2)
	check(world._backpack_panel == null, "Escape closes the stash panel")
	world._backpack_action = null

	world.free()
	player.free()
	if failures == 0:
		print("BackpackContentsRegression: ALL CHECKS PASSED")
	else:
		push_error("BackpackContentsRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
