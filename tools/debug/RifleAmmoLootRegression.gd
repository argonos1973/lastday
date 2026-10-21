extends SceneTree

# Loose rifle ammunition regression: "Cargador de fusil" items (type "ammo")
# load rounds straight into the rifle reserve when used — no tactical vest
# required. Before this, a rifle without a vest could never be reloaded once
# the one-time starting reserve was spent.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	# Keep the inventory roomy: the real recalc shrinks capacity back to the
	# naked-player base and overflows drop the items the test just added.
	func _recalculate_carry_capacity() -> void:
		if inventory != null:
			inventory.max_slots = 20
			inventory.max_weight = 999.0

class FakeMain extends "res://scripts/Main.gd":
	pass

var failures := 0
var notices: Array = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _find_item(player, item_name: String) -> int:
	for i in range(player.inventory.items.size()):
		if str(player.inventory.items[i].item_name) == item_name:
			return i
	return -1

func _initialize() -> void:
	print("=== RifleAmmoLootRegression ===")
	await process_frame

	var world := FakeMain.new()
	root.add_child(world)
	var player := TestPlayer.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.notice.connect(func(msg): notices.append(msg))

	var ItemScript = load("res://scripts/Item.gd")
	check(player.inventory != null, "test player has an inventory")

	# One magazine, one use: +RIFLE_MAG_SIZE reserve, item consumed.
	var mag = ItemScript.create("Cargador de fusil", "ammo", 0.3, 1, 5.0)
	check(player.inventory.add_item(mag), "magazine fits in inventory")
	var before: int = player._rifle_reserve_ammo
	player._use_inventory_index(_find_item(player, "Cargador de fusil"))
	check(player._rifle_reserve_ammo == before + player.RIFLE_MAG_SIZE,
		"using a magazine adds %d rounds to the reserve" % player.RIFLE_MAG_SIZE)
	check(_find_item(player, "Cargador de fusil") < 0, "magazine is consumed on use")
	check(notices.size() == 1 and str(notices[0]).contains("+%d" % player.RIFLE_MAG_SIZE),
		"notice reports the loaded rounds")

	# A stack of 3 loses one unit per use, item stays until empty.
	notices.clear()
	var stack = ItemScript.create("Cargador de fusil", "ammo", 0.3, 3, 5.0)
	player.inventory.add_item(stack)
	player._use_inventory_index(_find_item(player, "Cargador de fusil"))
	check(player._rifle_reserve_ammo == before + player.RIFLE_MAG_SIZE * 2,
		"one unit of a stack loads one magazine")
	var stack_idx: int = _find_item(player, "Cargador de fusil")
	check(stack_idx >= 0 and player.inventory.items[stack_idx].quantity == 2,
		"stack keeps the remaining units")
	player._use_inventory_index(_find_item(player, "Cargador de fusil"))
	player._use_inventory_index(_find_item(player, "Cargador de fusil"))
	check(_find_item(player, "Cargador de fusil") < 0, "empty stack leaves inventory")

	# use_value drives the rounds per item when it is set.
	var big_pack = ItemScript.create("Caja de balas", "ammo", 0.6, 1, 10.0)
	player.inventory.add_item(big_pack)
	var res_before: int = player._rifle_reserve_ammo
	player._use_inventory_index(_find_item(player, "Caja de balas"))
	check(player._rifle_reserve_ammo == res_before + 10,
		"box of rounds honors its use_value")

	# Non-ammo items never touch the reserve through the use path.
	res_before = player._rifle_reserve_ammo
	var stone = ItemScript.create("Piedra", "resource", 0.45, 1, 0.0)
	player.inventory.add_item(stone)
	var stone_idx: int = _find_item(player, "Piedra")
	player._load_ammo_item(player.inventory.items[stone_idx], stone_idx) # must refuse non-ammo
	check(player._rifle_reserve_ammo == res_before, "non-ammo item grants nothing")
	check(_find_item(player, "Piedra") == stone_idx, "non-ammo item is not consumed")

	# The whole point of the fix: after _use_inventory_index the reserve is
	# non-empty, so _reload_rifle gets past its empty-reserve early return on
	# a fresh no-vest player (init once spent, magazine empty).
	var player2 := TestPlayer.new()
	root.add_child(player2)
	player2.set_process(false)
	player2.set_physics_process(false)
	player2._rifle_ammo_initialized = true   # as after spending the start reserve
	player2._rifle_magazine = 0
	player2._rifle_reserve_ammo = 0
	var mag2 = ItemScript.create("Cargador de fusil", "ammo", 0.3, 1, 5.0)
	player2.inventory.add_item(mag2)
	player2._use_inventory_index(_find_item(player2, "Cargador de fusil"))
	check(player2._rifle_reserve_ammo == player2.RIFLE_MAG_SIZE,
		"loose magazine restores a dead reserve without any vest")

	# 5.56 ammo routes to its own M4 pool — never to the 7.62 reserve.
	var m4_res_before: int = player._m4_reserve_ammo
	var res762_before: int = player._rifle_reserve_ammo
	var m4mag = ItemScript.create("Cargador de M4", "ammo", 0.45, 1, 30.0)
	player.inventory.add_item(m4mag)
	player._use_inventory_index(_find_item(player, "Cargador de M4"))
	check(player._m4_reserve_ammo == m4_res_before + 30,
		"M4 magazine feeds 30 NATO 5.56 rounds into the M4 reserve")
	check(player._rifle_reserve_ammo == res762_before,
		"M4 magazine never touches the 7.62 reserve")
	check(_find_item(player, "Cargador de M4") < 0, "M4 magazine is consumed on use")
	var loose = ItemScript.create("Balas 5.56", "ammo", 0.24, 1, 30.0)
	player.inventory.add_item(loose)
	player._use_inventory_index(_find_item(player, "Balas 5.56"))
	check(player._m4_reserve_ammo == m4_res_before + 60,
		"loose 5.56 rounds also feed the M4 reserve")
	# The M4 reload drains only its own pool (30-round magazine).
	var player3 := TestPlayer.new()
	root.add_child(player3)
	player3.set_process(false)
	player3.set_physics_process(false)
	player3._held_item_reference = ItemScript.create("Fusil de asalto", "weapon_rifle", 3.1, 1, 0.0)
	player3._held_item_external = true
	player3._m4_ammo_initialized = true
	player3._m4_magazine = 5
	player3._m4_reserve_ammo = 40
	player3._rifle_magazine = 4
	player3._rifle_reserve_ammo = 11
	player3._reload_rifle()
	await create_timer(2.5).timeout
	check(player3._m4_magazine == 30 and player3._m4_reserve_ammo == 15,
		"M4 reload tops its 30-round magazine from its own reserve")
	check(player3._rifle_magazine == 4 and player3._rifle_reserve_ammo == 11,
		"M4 reload never touches the 7.62 pools")
	player3.free()

	print("RIFLE_AMMO_LOOT failures=", failures)
	quit(1 if failures else 0)
