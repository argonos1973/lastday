extends SceneTree

# Regresión: al recoger del suelo no se sueltan otros objetos del inventario
# ni se duplica nada.
# - El cambio de mochila saca la EQUIPADA (no una de repuesto) y si con la
#   nueva no cabría lo llevado, avisa y la deja en el suelo.
# - Cambiar una prenda por otra que dé menos capacidad avisa igual: no se
#   expulsan objetos al perder huecos.
# - En el swap del mismo nombre cae la prenda LLEVADA, no una copia de repuesto.
# - El chaleco recogido con [C] guarda sus metas de munición en la copia del
#   inventario (no en el objeto temporal): re-equiparlo no regenera cargadores.
# Uso: godot --headless --path . --script tools/debug/PickupSwapRegression.gd

const ItemScript = preload("res://scripts/Item.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _wear_survival_clothing(_n, _on, _c = Color(0, 0, 0, 0)) -> void:
		pass
	func _wear_clothing_visual(_n, _c = Color(0, 0, 0, 0)) -> void:
		pass
	func _sync_third_person_equipment(_i = null, _cosmetic := false) -> void:
		pass

class TestHUD extends "res://scripts/HUD.gd":
	func show_countdown(_text: String, _duration: float) -> void: pass
	func hide_countdown() -> void: pass

class TestWorld extends "res://scripts/Main.gd":
	var spawned_drops: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _hide_action_visual(_action) -> void:
		pass
	func _spawn_dropped_item_visual(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3, color: Color = Color(0, 0, 0, 0), broken: bool = false, spoilage: float = 0.0, contents: Array = [], wetness: float = 0.0, camo: bool = false, pelt: String = "") -> void:
		var action = _create_world_action(drop_id, "pickup_item", item_name, pos, Vector3.ONE, Color.WHITE, false, false)
		action.set_meta("item_name", item_name)
		action.set_meta("item_type", item_type)
		action.set_meta("item_weight", item_weight)
		action.set_meta("item_quantity", item_quantity)
		action.set_meta("item_use_value", item_use_value)
		if not contents.is_empty():
			action.set_meta("contents", contents)
		if not pelt.is_empty():
			action.set_meta("item_pelt", pelt)
		spawned_drops.append({"id": drop_id, "name": item_name, "pelt": pelt})

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

func _make_pickup_action(world, id: String, item_name: String, item_type: String, weight := 0.5, qty := 1, use_value := 0.0):
	var action = world._create_world_action(id, "pickup_item", item_name, Vector3.ZERO, Vector3.ONE, Color.WHITE, false, false)
	action.set_meta("item_name", item_name)
	action.set_meta("item_type", item_type)
	action.set_meta("item_weight", weight)
	action.set_meta("item_quantity", qty)
	action.set_meta("item_use_value", use_value)
	return action

func _count_named(items: Array, item_name: String) -> int:
	var n := 0
	for it in items:
		if it != null and str(it.item_name) == item_name:
			n += 1
	return n

func _count_type(items: Array, item_type: String) -> int:
	var n := 0
	for it in items:
		if it != null and str(it.item_type) == item_type:
			n += 1
	return n

func _fill_stored(player, item_name: String, units: int) -> void:
	for i in range(units):
		player.inventory.items.append(ItemScript.create(item_name, "resource", 0.05, 1, 0.0))

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	world.net = TestNetwork.new()
	var hud_stub = TestHUD.new()
	world.add_child(hud_stub)
	world.hud = hud_stub
	var player := TestPlayer.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	world.player = player
	player._initializing = false

	var notices: Array = []
	player.notice.connect(func(m): notices.append(str(m)))
	var drops: Array = []
	var drop_pelts: Array = []
	player.item_dropped.connect(func(n, t, w, q, u, p, c, b, s):
		drop_pelts.append(str(player.get_meta("last_dropped_pelt", "")))
		drops.append({"n": n, "t": t, "w": w, "q": q, "u": u, "p": p, "c": c, "b": b, "s": s}))

	# ------------------------------------------------------------------
	# 1) Swap de mochila: la que sale es la EQUIPADA, no una de repuesto.
	#    Antes se quitaba la primera del inventario: la de repuesto se
	#    destruía y una copia de la equipada aparecía en el suelo.
	var spare = ItemScript.create("Mochila pequena", "backpack", 0.9, 1, 0.0)
	player.inventory.items.append(spare)
	var mil = ItemScript.create("Mochila militar", "backpack", 1.8, 1, 0.0)
	mil.set_meta("equipped_slot", "backpack")
	player.inventory.items.append(mil)
	player.equipped_backpack = "Mochila militar"
	player._recalculate_carry_capacity()

	var bp_action = _make_pickup_action(world, "bp_pick_1", "Mochila pequena", "backpack", 0.9)
	await world.handle_world_action_collect(bp_action, player)

	check(player.equipped_backpack == "Mochila pequena", "Swap equips the picked backpack")
	check(player.inventory.items.has(spare), "Spare backpack survives the swap")
	check(_count_named(player.inventory.items, "Mochila militar") == 0,
		"Equipped military backpack left the inventory")
	var mil_drops := 0
	for d in drops:
		if str(d["n"]) == "Mochila militar":
			mil_drops += 1
	check(mil_drops == 1, "Exactly one military backpack lands on the ground (got %d)" % mil_drops)
	check(_count_type(player.inventory.items, "backpack") == 2,
		"Inventory keeps spare + newly equipped backpack (got %d)" % _count_type(player.inventory.items, "backpack"))
	drops.clear()
	drop_pelts.clear()

	# ------------------------------------------------------------------
	# 2) Recoger una mochila MENOR que dejaría sin huecos: aviso y se queda.
	#    Con la militar todo cabía; con la pequeña no -> no se suelta nada.
	var mil2 = ItemScript.create("Mochila militar", "backpack", 1.8, 1, 0.0)
	mil2.set_meta("equipped_slot", "backpack")
	player.inventory.items.append(mil2)
	player.equipped_backpack = "Mochila militar"
	var new_slots: int = 0
	var prev_eq := player.equipped_backpack
	player.equipped_backpack = "Mochila pequena"
	new_slots = int(player._compute_carry_capacity(true)["slots"])
	player.equipped_backpack = prev_eq
	var missing: int = new_slots + 1 - player.inventory.get_stored_count()
	if missing > 0:
		_fill_stored(player, "Trapos", missing)
	check(player.inventory.get_stored_count() > new_slots, "Fixture: stored exceeds the small backpack capacity")
	player._recalculate_carry_capacity()

	var bp_small = _make_pickup_action(world, "bp_pick_2", "Mochila pequena", "backpack", 0.9)
	var stored_before: int = player.inventory.get_stored_count()
	var items_before: int = player.inventory.items.size()
	await world.handle_world_action_collect(bp_small, player)
	check(player.equipped_backpack == "Mochila militar", "Overflow swap refused: keeps the worn backpack")
	check(drops.is_empty(), "Overflow swap drops nothing")
	check(player.inventory.get_stored_count() == stored_before and player.inventory.items.size() == items_before,
		"Overflow swap leaves the inventory untouched")
	check(not bool(bp_small.depleted), "Refused backpack stays on the ground")
	check(notices.any(func(m): return m.contains("espacio")), "Overflow swap warns the player")
	drops.clear()
	drop_pelts.clear()

	# ------------------------------------------------------------------
	# 3) Ropa del mismo nombre: cae la LLEVADA, no una de repuesto.
	for i in range(player.inventory.items.size() - 1, -1, -1):
		var it = player.inventory.items[i]
		if it != null and str(it.item_type) == "resource":
			player.inventory.items.remove_at(i)
	# La de repuesto va PRIMERO en el array: el bug quitaba la primera
	# coincidencia por nombre (la de repuesto) en vez de la llevada.
	var spare_j = ItemScript.create("Chaqueta de piel", "clothing", 1.2, 1, 0.0)
	spare_j.set_meta("pelt_species", "ciervo")
	player.inventory.items.append(spare_j)
	var worn = ItemScript.create("Chaqueta de piel", "clothing", 1.2, 1, 0.0)
	worn.set_meta("pelt_species", "lobo")
	worn.set_meta("equipped_slot", "torso")
	player.inventory.items.append(worn)
	player._equipped_slots["torso"] = "Chaqueta de piel"
	player._recalculate_carry_capacity()

	var jacket = _make_pickup_action(world, "cloth_pick_1", "Chaqueta de piel", "clothing", 1.2)
	jacket.set_meta("item_pelt", "zorro")
	await world.handle_world_action(jacket, player)

	check(drop_pelts.size() == 1 and drop_pelts[0] == "lobo",
		"Same-name swap drops the WORN jacket (pelt lobo, got %s)" % str(drop_pelts))
	check(not player.inventory.items.has(worn), "The worn jacket left the inventory")
	check(player.inventory.items.has(spare_j), "The spare same-name jacket stays in the bag")
	check(str(player._equipped_slots.get("torso", "")) == "Chaqueta de piel", "New jacket equipped")
	var equipped_new = player._equipped_item_for_slot("torso")
	check(equipped_new != null and str(equipped_new.get_meta("pelt_species", "")) == "zorro",
		"The equipped jacket is the picked one (zorro)")
	drops.clear()
	drop_pelts.clear()

	# ------------------------------------------------------------------
	# 4) Cambiar a una prenda que dé MENOS capacidad: aviso y se queda.
	for i in range(player.inventory.items.size() - 1, -1, -1):
		var it2 = player.inventory.items[i]
		if it2 != null and (str(it2.item_type) == "clothing" or str(it2.get_meta("equipped_slot", "")) == "torso"):
			player.inventory.items.remove_at(i)
	player._equipped_slots.erase("torso")
	var mil_j = ItemScript.create("Chaqueta militar", "clothing", 1.5, 1, 0.0)
	mil_j.set_meta("equipped_slot", "torso")
	player.inventory.items.append(mil_j)
	player._equipped_slots["torso"] = "Chaqueta militar"
	player._recalculate_carry_capacity()

	var prev_worn2 = player._equipped_slots["torso"]
	player._equipped_slots["torso"] = "Camiseta"
	var camiseta_slots: int = int(player._compute_carry_capacity(true)["slots"])
	player._equipped_slots["torso"] = prev_worn2
	missing = int(camiseta_slots) + 1 - player.inventory.get_stored_count()
	if missing > 0:
		_fill_stored(player, "Trapos", missing)
	check(player.inventory.get_stored_count() > camiseta_slots, "Fixture: stored exceeds the Camiseta capacity")
	player._recalculate_carry_capacity()

	var tee = _make_pickup_action(world, "cloth_pick_2", "Camiseta", "clothing", 0.3)
	await world.handle_world_action(tee, player)
	check(str(player._equipped_slots.get("torso", "")) == "Chaqueta militar",
		"Capacity-losing swap refused: military jacket stays on")
	check(drops.is_empty(), "Capacity-losing swap drops nothing")
	check(not bool(tee.depleted), "Refused garment stays on the ground")
	check(notices.any(func(m): return m.contains("espacio")), "Capacity-losing swap warns the player")
	drops.clear()
	drop_pelts.clear()

	# ------------------------------------------------------------------
	# 5) Chaleco por [C]: las metas de munición llegan a la copia guardada.
	#    Con el objeto temporal se perdían: re-equiparlo regeneraba 5
	#    cargadores y un chaleco de jugador concedía munición.
	for i in range(player.inventory.items.size() - 1, -1, -1):
		var it3 = player.inventory.items[i]
		if it3 != null and str(it3.item_type) == "resource":
			player.inventory.items.remove_at(i)
	player._recalculate_carry_capacity()
	var vest_drop = _make_pickup_action(world, "vest_pick_1", "Chaleco táctico", "clothing", 1.2)
	vest_drop.set_meta("player_dropped", true)
	var reserve_before: int = player._rifle_reserve_ammo
	await world.handle_world_action_collect(vest_drop, player)
	check(player._rifle_reserve_ammo == reserve_before, "Player-dropped vest grants no ammo on collect")
	var stored_vest = null
	for it in player.inventory.items:
		if it != null and str(it.item_name) == "Chaleco táctico":
			stored_vest = it
	check(stored_vest != null, "Vest stored via collect")
	if stored_vest != null:
		check(bool(stored_vest.get_meta("player_dropped", false)), "Stored copy keeps player_dropped meta")
	player.equip_clothing("Chaleco táctico")
	check(player._rifle_reserve_ammo == reserve_before, "Equipping a player-dropped vest grants no ammo")
	player.unequip_clothing("Chaleco táctico")
	if stored_vest != null:
		var vi: int = player.inventory.items.find(stored_vest)
		if vi >= 0:
			player.inventory.remove_index(vi)

	var vest_world = _make_pickup_action(world, "vest_pick_2", "Chaleco táctico", "clothing", 1.2)
	await world.handle_world_action_collect(vest_world, player)
	var expected_reserve: int = reserve_before + player.RIFLE_MAG_SIZE * 5
	check(player._rifle_reserve_ammo == expected_reserve, "World vest grants its 5 magazines once")
	var stored_vest2 = null
	for it in player.inventory.items:
		if it != null and str(it.item_name) == "Chaleco táctico":
			stored_vest2 = it
	if stored_vest2 != null:
		check(bool(stored_vest2.get_meta("vest_mags_granted", false)), "Stored copy keeps vest_mags_granted meta")
	player.equip_clothing("Chaleco táctico")
	player.unequip_clothing("Chaleco táctico")
	player.equip_clothing("Chaleco táctico")
	check(player._rifle_reserve_ammo == expected_reserve, "Re-equipping the vest does NOT re-grant magazines")

	world.free()
	player.free()
	if failures == 0:
		print("PickupSwapRegression: ALL CHECKS PASSED")
	else:
		push_error("PickupSwapRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
