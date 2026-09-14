extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass

class TestHUD extends "res://scripts/HUD.gd":
	func _resolve_location(): pass

func _initialize():
	call_deferred("run")

func run():
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var player := TestPlayer.new()
	player.stats = load("res://scripts/SurvivalStats.gd").new()
	player.inventory = load("res://scripts/Inventory.gd").new()
	player.add_child(player.stats)
	player.add_child(player.inventory)
	scene.add_child(player)
	var cycle = load("res://scripts/DayNightCycle.gd").new()
	cycle.fixed_time = true
	scene.add_child(cycle)
	var hud := TestHUD.new()
	scene.add_child(hud)
	hud.setup(player, cycle)
	for hour in [12.0, 23.0, 4.0]:
		cycle.time_of_day = hour
		hud.show_notice("HUD visible a las %s" % hour)
		hud.toggle_inventory()
		await create_timer(0.4).timeout
		assert(hud.root.is_visible_in_tree())
		assert(hud.status_panel.is_visible_in_tree())
		assert(hud.notice_label.is_visible_in_tree() and hud.notice_label.modulate.a > 0.9)
		assert(hud.inventory_panel.is_visible_in_tree())
		assert(hud.root.size.x > 0 and hud.root.size.y > 0)
		if hour == 23.0 and OS.get_cmdline_user_args().has("--render-check"):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://work/hud-night-runtime.png")
		for key in ["health", "hunger", "thirst", "temp", "energy", "sleep"]:
			assert(hud.status_icons[key].wrapper.is_visible_in_tree())
		hud.toggle_inventory()
		await create_timer(0.3).timeout
	# Reopening before the closing animation ends must not hide the panel.
	hud.toggle_inventory()
	hud.toggle_inventory()
	hud.toggle_inventory()
	await create_timer(0.4).timeout
	assert(hud.inventory_panel.is_visible_in_tree())
	var ray = load("res://scripts/InteractionRaycast.gd").new()
	scene.add_child(ray)
	ray.interaction_distance = 3.5
	var pickup = load("res://scripts/WorldAction.gd").new()
	scene.add_child(pickup)
	pickup.action_type = "pickup_item"
	pickup.position = Vector3(0, 0, -1.5)
	assert(ray._is_close_enough(player, pickup))
	pickup.position.z = -3.0
	assert(not ray._is_close_enough(player, pickup))
	pickup.position = Vector3(0, 4, -0.5)
	assert(not ray._is_close_enough(player, pickup))
	print("PASS: HUD day/night, stats, messages, inventory reopen and pickup reach")
	scene.free()
	quit()
