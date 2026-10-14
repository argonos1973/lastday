extends SceneTree

# Military vest magazine regression: a world-loot "Chaleco táctico" grants five
# full rifle magazines of reserve ammo on pickup. A player-dropped vest (meta
# "player_dropped" set by _spawn_dropped_item_visual) must NOT re-grant — or
# dropping and re-picking the same vest mints infinite ammo.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class FakeAction extends Node:
	pass

class FakeMain extends "res://scripts/Main.gd":
	pass

var failures := 0
var notices: Array = []

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	print("=== VestMagazinesRegression ===")
	await process_frame

	var world := FakeMain.new()
	root.add_child(world)
	var player := TestPlayer.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	player.notice.connect(func(msg): notices.append(msg))

	# World loot vest: full grant.
	var loot_action := FakeAction.new()
	root.add_child(loot_action)
	var before: int = player._rifle_reserve_ammo
	world._grant_vest_magazines(loot_action, player, "Chaleco táctico")
	check(player._rifle_reserve_ammo == before + player.RIFLE_MAG_SIZE * 5,
		"world vest grants 5 full magazines of reserve ammo")
	check(notices.size() == 1 and str(notices[0]).contains("5 cargadores"),
		"pickup notice announces the loaded magazines")

	# Player-dropped vest: empty pouches, no grant, no notice.
	var dropped_action := FakeAction.new()
	root.add_child(dropped_action)
	dropped_action.set_meta("player_dropped", true)
	before = player._rifle_reserve_ammo
	notices.clear()
	world._grant_vest_magazines(dropped_action, player, "Chaleco táctico")
	check(player._rifle_reserve_ammo == before,
		"player-dropped vest grants no ammo (anti-exploit)")
	check(notices.is_empty(), "dropped vest stays silent")

	# Other clothing and null actors never grant.
	before = player._rifle_reserve_ammo
	world._grant_vest_magazines(loot_action, player, "Chaqueta militar")
	world._grant_vest_magazines(loot_action, null, "Chaleco táctico")
	check(player._rifle_reserve_ammo == before,
		"non-vest items and missing actors are ignored")

	# Equipping the rifle AFTER receiving the vest's 5 magazines must preserve
	# all 5 magazines (25 rounds) instead of overwriting reserve to 15.
	var player2 := TestPlayer.new()
	root.add_child(player2)
	player2.set_process(false)
	player2.set_physics_process(false)
	world._grant_vest_magazines(loot_action, player2, "Chaleco táctico")
	player2._initialize_rifle_ammo()
	check(player2._rifle_reserve_ammo >= player2.RIFLE_MAG_SIZE * 5,
		"rifle initialization preserves the 5 vest magazines (%d rounds)" % player2._rifle_reserve_ammo)
	check(player2.get_vest_magazines_count() >= 5,
		"vest reports at least 5 magazines available")

	print("VEST_MAGAZINES failures=", failures)
	quit(1 if failures else 0)
