extends Node

var _screenshot_taken := false
var _drink_triggered := false
var _wait_timer := 0.0
var _screenshot_count := 0
var _test_light: OmniLight3D = null

func _process(delta: float) -> void:
	_wait_timer += delta

	if _wait_timer < 15.0:
		if int(_wait_timer) % 5 == 0 and int(_wait_timer) != int(_wait_timer - delta):
			print("Waiting... t=", _wait_timer)
		return

	var main = get_node_or_null("/root/Main")
	if main == null:
		print("Main not found")
		return
	var player = main.get("player")
	if player == null or not is_instance_valid(player):
		if int(_wait_timer) % 5 == 0 and int(_wait_timer) != int(_wait_timer - delta):
			print("Player not found at t=", _wait_timer)
		return

	print("Player found at t=", _wait_timer)

	# Activate built-in frontal debug camera (overrides camera in _physics_process)
	player._frontal_camera = true

	if _test_light == null:
		_test_light = OmniLight3D.new()
		_test_light.name = "TestDrinkLight"
		_test_light.light_energy = 4.0
		_test_light.light_color = Color(1.0, 0.95, 0.8)
		_test_light.position = Vector3(0, 2.5, 3.0)
		player.add_child(_test_light)

	if not _drink_triggered:
		var ItemScript = load("res://scripts/Item.gd")
		var bottle = ItemScript.create("Botella de agua", "water", 0.3, 1, 20.0)
		player.inventory.add_item(bottle)
		player.held_index = player.inventory.items.size() - 1
		player._sync_held_item()
		call_deferred("_trigger_drink", player)
		_drink_triggered = true
		print("Drink triggered at t=", _wait_timer)


	if _drink_triggered and _screenshot_count < 4:
		var screenshot_times = [15.5, 16.0, 16.5, 17.0]
		if _wait_timer > screenshot_times[_screenshot_count]:
			var img = get_viewport().get_texture().get_image()
			var path = "res://tools/drink_screenshot_" + str(_screenshot_count) + ".png"
			img.save_png(path)
			print("Screenshot ", _screenshot_count, " saved at t=", _wait_timer)
			_screenshot_count += 1

	if _screenshot_count >= 4 and not _screenshot_taken:
		_screenshot_taken = true
		get_tree().quit()

	if _screenshot_taken:
		get_tree().quit()

func _trigger_drink(player: Node) -> void:
	player._drink_held_item()
