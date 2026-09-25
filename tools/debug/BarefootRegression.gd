extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")

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

func _count_blood(scene: Node) -> int:
	var n := 0
	for c in scene.get_children():
		if str(c.name).begins_with("BloodDrops"):
			n += 1
	return n

func _drive_barefoot(player: Node, seconds: float, running: bool) -> void:
	var step := 0.05
	var steps := int(seconds / step)
	for i in range(steps):
		player.is_moving = true
		player.is_sprinting = running
		player._update_barefoot(step)

func _initialize() -> void:
	print("=== BarefootRegression ===")
	await process_frame
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene
	var player := TestPlayer.new()
	root.add_child(player)
	await process_frame
	player.stats.health = 100.0
	player.stats.body_temperature = 36.6

	# Case 1: shoes on — walking harms nothing.
	player.equip_clothing("Zapatillas")
	var feet_item := str(player._equipped_slots.get("feet", ""))
	check(feet_item == "Zapatillas", "Player starts with shoes (got '%s')" % feet_item)
	_drive_barefoot(player, 10.0, false)
	check(player.stats.feet_wound == 0.0, "Walking with shoes keeps feet_wound 0 (got %.1f)" % player.stats.feet_wound)

	# Case 2: barefoot walking — wound builds slowly, small damage.
	player.unequip_clothing("Zapatillas")
	check(player._is_barefoot(), "Unequipping shoes makes the player barefoot")
	var hp_before: float = player.stats.health
	_drive_barefoot(player, 30.0, false)
	check(player.stats.feet_wound > 15.0, "30s barefoot walk wounds feet (got %.1f)" % player.stats.feet_wound)
	var walk_drain: float = hp_before - player.stats.health
	check(walk_drain > 0.5 and walk_drain < 8.0, "Walking barefoot drains little health (got %.2f)" % walk_drain)
	check(_count_blood(scene) == 0, "Walking barefoot spawns no blood")

	# Case 3: barefoot running — faster wound growth, bigger drain, blood.
	player.stats.feet_wound = 20.0
	var hp_run: float = player.stats.health
	var wound_run: float = player.stats.feet_wound
	_drive_barefoot(player, 4.0, true)
	var run_drain: float = hp_run - player.stats.health
	var run_wound_gain: float = player.stats.feet_wound - wound_run
	check(run_wound_gain > 15.0, "Running barefoot builds wound fast (got %.1f/4s)" % run_wound_gain)
	check(run_drain > 2.0, "Running barefoot drains more health (got %.2f/4s)" % run_drain)
	check(_count_blood(scene) > 0, "Running wounded barefoot splatters blood")

	# Case 4: cold ambient chills bare feet.
	scene.day_cycle.temp = 0.0
	var temp_before: float = player.stats.body_temperature
	_drive_barefoot(player, 10.0, false)
	check(player.stats.body_temperature < temp_before - 0.2, "Cold chills bare feet (%.2f -> %.2f)" % [temp_before, player.stats.body_temperature])
	scene.day_cycle.temp = 25.0

	# Case 5: bandage heals the wound.
	player.stats.feet_wound = 60.0
	var venda = ItemScript.create("Venda", "medical", 0.1, 1, 15.0)
	player.inventory.items.append(venda)
	var vi: int = player.inventory.items.find(venda)
	player.inventory.use_index(vi, player.stats)
	check(player.stats.feet_wound == 0.0, "Bandage clears feet_wound (got %.1f)" % player.stats.feet_wound)

	# Case 6: wearing shoes recovers faster than staying barefoot.
	player.stats.feet_wound = 40.0
	player.equip_clothing("Zapatillas")
	for i in range(200):  # 10s with shoes
		player.is_moving = true
		player.is_sprinting = false
		player._update_barefoot(0.05)
	check(player.stats.feet_wound < 22.0, "Shoes heal wounds fast (got %.1f)" % player.stats.feet_wound)

	# Case 7: sleep heals the wound.
	player.stats.feet_wound = 60.0
	player.stats.do_sleep(1.0)
	check(player.stats.feet_wound <= 30.0, "Sleep heals feet (got %.1f)" % player.stats.feet_wound)

	# Case 8: save round-trip keeps the wound.
	player.stats.feet_wound = 33.0
	var d: Dictionary = player.stats.to_dict()
	var st2 = preload("res://scripts/SurvivalStats.gd").new()
	st2.from_dict(d)
	check(abs(st2.feet_wound - 33.0) < 0.01, "feet_wound survives save/load (got %.1f)" % st2.feet_wound)
	st2.free()

	player.free()
	scene.free()
	if failures == 0:
		print("BarefootRegression: ALL PASS")
	else:
		print("BarefootRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
