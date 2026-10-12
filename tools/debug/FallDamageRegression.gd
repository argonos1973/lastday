extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _is_on_walkable_ground() -> bool:
		return true

class StubDayCycle extends Node:
	var temp := 20.0
	func get_ambient_temperature() -> float:
		return temp

class TestScene extends Node:
	var hud = null
	var day_cycle := StubDayCycle.new()
	func get_day_cycle() -> Node:
		return day_cycle
	func get_hud() -> Node:
		return null
	func _ready() -> void:
		add_child(day_cycle)

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _land_from(player: Node, apex_y: float, land_y: float) -> void:
	player._is_falling_from_height = true
	player._fall_height = apex_y
	player._max_fall_height = apex_y
	player.global_position.y = land_y
	player._land_after_fall()

func _reset_fall_state(player: Node) -> void:
	player._is_falling_from_height = false
	player._fall_height = 0.0
	player._max_fall_height = 0.0
	player.is_in_water = false
	player._water_depth = 0.0

func _initialize() -> void:
	print("=== FallDamageRegression ===")
	await process_frame
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene
	var player := TestPlayer.new()
	root.add_child(player)
	await process_frame

	# Case 1: small drop (<3 m) is safe — no damage, no foot wound.
	player.stats.health = 100.0
	player.stats.feet_wound = 0.0
	_land_from(player, 12.0, 9.5)
	check(player.stats.health == 100.0, "2.5 m drop is harmless")
	check(player.stats.feet_wound == 0.0, "2.5 m drop leaves no foot wound")
	check(not player._is_falling_from_height and player._max_fall_height == 0.0, "fall state resets on landing")

	# Case 2: flat jump (apex ~1 m above landing) is harmless.
	_reset_fall_state(player)
	_land_from(player, 1.1, 0.0)
	check(player.stats.health == 100.0, "flat jump is harmless")

	# Case 3: 5 m drop -> (5-3)*9 = 18 damage + proportional foot wound.
	_reset_fall_state(player)
	_land_from(player, 5.0, 0.0)
	check(is_equal_approx(player.stats.health, 82.0), "5 m drop deals 18 damage (got %.1f)" % player.stats.health)
	check(player.stats.feet_wound > 0.0, "5 m drop wounds the feet (limp)")

	# Case 4: roof-height drop (~8 m) -> 45 damage.
	_reset_fall_state(player)
	player.stats.health = 100.0
	_land_from(player, 8.0, 0.0)
	check(is_equal_approx(player.stats.health, 55.0), "8 m roof drop deals 45 damage (got %.1f)" % player.stats.health)

	# Case 5: landing in deep water softens the impact (45 * 0.3 = 13.5).
	_reset_fall_state(player)
	player.stats.health = 100.0
	player.is_in_water = true
	player._water_depth = 0.8
	_land_from(player, 8.0, 0.0)
	check(is_equal_approx(player.stats.health, 86.5), "8 m drop into water deals 13.5 damage (got %.1f)" % player.stats.health)

	# Case 6: lethal fall (tower height ~29 m) drains health to zero.
	_reset_fall_state(player)
	player.stats.health = 100.0
	_land_from(player, 29.0, 0.0)
	check(player.stats.health == 0.0, "29 m tower drop is lethal")

	# Case 7: dead/puppet players take no further fall damage.
	_reset_fall_state(player)
	var puppet := TestPlayer.new()
	root.add_child(puppet)
	puppet.is_puppet = true
	await process_frame
	puppet.stats.health = 50.0
	_land_from(puppet, 20.0, 0.0)
	check(puppet.stats.health == 50.0, "puppets ignore fall damage")
	puppet.free()

	# Case 8: falling in stages — the apex height is what counts.
	_reset_fall_state(player)
	player.stats.health = 100.0
	player._is_falling_from_height = true
	player._max_fall_height = 10.0
	player.global_position.y = 0.0
	player._land_after_fall()  # (10-3)*9 = 63 damage
	check(is_equal_approx(player.stats.health, 37.0), "staged fall keeps apex height (got %.1f)" % player.stats.health)

	player.free()
	scene.free()
	if failures == 0:
		print("FallDamageRegression: ALL PASS")
	else:
		print("FallDamageRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
