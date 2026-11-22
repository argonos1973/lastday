extends SceneTree

# Ground pickups reach down before granting the item. Local and remote actors
# share the same clip, and ground food then transitions to its eating gesture.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass

class TestWorld extends "res://scripts/Main.gd":
	func _ready(): set_process(false); set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass

class TestBots extends "res://scripts/SurvivorBotManager.gd":
	func _is_world_night() -> bool: return false
	func _bot_supply_goal_allowed(_b: Dictionary, _goal: Vector3) -> bool: return true

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _make_player() -> Node:
	var player := TestPlayer.new()
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)
	return player

func _mount_model(player: Node) -> AnimationPlayer:
	var model: Node3D = load("res://assets/animations/inicio.glb").instantiate()
	player.add_child(model)
	player.third_person_model = model
	player._setup_third_person_animation(model)
	return player.third_person_animation_player

func _ground_item(world: Node, id: String, pos: Vector3, item_name := "Seta", item_type := "food"):
	var action = world._create_world_action(id, "eat_food" if item_type == "food" else "pickup_item", item_name,
		pos, Vector3.ONE * 0.2, Color.WHITE, false, false)
	action.set_meta("item_name", item_name)
	action.set_meta("item_type", item_type)
	action.set_meta("item_weight", 0.1)
	action.set_meta("item_quantity", 1)
	action.set_meta("item_use_value", 12.0)
	var visual := Node3D.new()
	visual.name = id + "_visual"
	world.add_child(visual)
	action.set_meta("visual_name", str(visual.name))
	world._dropped_items.append({"id":id, "name":item_name, "type":item_type, "pos":pos, "qty":1, "weight":0.1, "use":12.0})
	return action

func _test_ground_transactions() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var player: Node = _make_player()
	player.inventory.items.clear()
	player.inventory.max_weight = 0.0
	player.stats.hunger = 40.0
	var action = _ground_item(world, "meal", Vector3(0.0, 0.0, -0.7))
	var visual: Node3D = world.get_node("meal_visual")
	world.handle_world_action_eat(action, player)
	check(player._interact_busy and not action.depleted and player.stats.hunger == 40.0,
		"pickup starts without granting nutrition or consuming the mushroom")
	player._ground_gesture.tick(player.GroundGesture.GRAB_TIME)
	check(not visual.visible, "world object hides only after the hand reaches it")
	player.cancel_active_action()
	await create_timer(0.15).timeout
	check(visual.visible and not action.depleted and player.stats.hunger == 40.0,
		"cancelled pickup restores the object and changes no vital stats")
	world.handle_world_action_eat(action, player)
	await create_timer(player.GroundGesture.DURATION + 0.25).timeout
	check(player._ground_gesture != null and player._ground_gesture.phase == "eat",
		"ground mushroom finishes pickup before beginning the meal")
	check(player.stats.hunger == 40.0 and not action.depleted and not visual.visible,
		"meal has its own completion point with the mushroom held off the ground")
	player.cancel_active_action()
	await create_timer(0.15).timeout
	check(visual.visible and not action.depleted and player.inventory.items.is_empty(),
		"cancelled meal returns the mushroom without creating an inventory copy")
	await world.handle_world_action_eat(action, player)
	check(action.depleted and player.stats.hunger == 52.0 and player.inventory.items.is_empty(),
		"ground food can be eaten with a full bag and restores nutrition exactly once")
	var stone = _ground_item(world, "stone_test", Vector3(0,0,-0.7), "Piedra", "resource")
	await world.handle_world_action_collect(stone, player)
	check(not stone.depleted and world.get_node("stone_test_visual").visible and player.inventory.items.is_empty(),
		"failed capacity check leaves the pickup visible and intact")
	player.inventory.max_weight = 50.0
	await world.handle_world_action_collect(stone, player)
	check(stone.depleted and player.inventory.items.size() == 1, "normal pickup commits one real item after its gesture")
	var cancelled = _ground_item(world, "walk_cancel", Vector3(0,0,-0.7), "Palo", "resource")
	world.handle_world_action_collect(cancelled, player)
	player.position.x = 1.0
	await create_timer(0.2).timeout
	check(not cancelled.depleted and not player._interact_busy, "moving away cancels a pending pickup")
	player.position = Vector3.ZERO
	var manager := TestBots.new()
	world.add_child(manager)
	manager.world = world
	var proxy := Node3D.new()
	world.add_child(proxy)
	proxy.position = Vector3(10,0,0)
	proxy.set_meta("saved_inventory", [])
	world.server_proxies[901] = proxy
	var food = _ground_item(world, "bot_meal", Vector3(10,0,-0.7))
	var b := {"bot_id":901, "proxy":proxy, "pos":proxy.position, "health":90.0, "hunger":10.0,
		"thirst":50.0, "torch_lit":false, "held_item":"", "backpack":"", "anim":"idle",
		"clothing":"", "clothing_colors":[], "has_rifle":false,
		"_forage":{"id":"bot_meal", "kind":"eat", "name":"Seta", "pos":food.position, "use":12.0, "t":0.0, "t_need":1.2}}
	check(manager._bot_try_forage(b, 1.0), "bot begins collecting its ground food")
	check(player.GroundGesture.decode(b.anim)[0] == "pickup" and b.hunger == 10.0,
		"bot shows pickup without receiving food early")
	check(not world._claim_world_pickup("bot_meal", 1), "a bot's active reservation also excludes human pickups")
	manager._bot_try_forage(b, 1.3)
	check(player.GroundGesture.decode(b.anim)[0] == "eat" and b.hunger == 10.0,
		"bot switches from pickup to eating before applying nutrition")
	manager._cancel_bot_ground_pickup(b)
	check(not world._pickup_claims.has("bot_meal") and not food.depleted and b._forage.t == 0.0,
		"interruption releases the bot claim and resets the interrupted gesture")
	manager._bot_try_forage(b, 2.3)
	manager._bot_try_forage(b, 1.2)
	check(food.depleted and b.hunger == 22.0, "bot commits one mushroom after both phases")
	var loot = _ground_item(world, "bot_loot", Vector3(10,0,-0.7), "Vendaje", "medical")
	var entry: Dictionary = world._dropped_items.back()
	manager._tick_loot_pickup(b, entry, 1.0)
	check(not loot.depleted and (proxy.get_meta("saved_inventory") as Array).is_empty(),
		"bot loot stays in the world until the pickup finishes")
	b.health -= 0.01
	manager._tick_loot_pickup(b, entry, 0.1)
	check(float(b.get("_loot_pickup", {}).get("t", 0.0)) > 1.0,
		"passive health decay cannot prevent collecting lifesaving supplies")
	b.health -= 1.0
	b["flinch_timer"] = 0.3
	manager._tick_loot_pickup(b, entry, 2.0)
	check(not loot.depleted and not world._pickup_claims.has("bot_loot"),
		"damage interrupts a bot pickup without granting inventory")
	b["flinch_timer"] = 0.0
	manager._tick_loot_pickup(b, entry, player.GroundGesture.DURATION + 0.1)
	check(loot.depleted and (proxy.get_meta("saved_inventory") as Array).size() == 1,
		"bot loot commits exactly once after an uninterrupted gesture")
	manager.world = null
	player.free()
	world.free()
	current_scene = null

func _world_mesh_aabb(node: Node) -> AABB:
	var has_any := false
	var acc := AABB()
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and not (n as Node3D).visible:
			continue
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var ga := mi.global_transform * mi.get_aabb()
			acc = ga if not has_any else acc.merge(ga)
			has_any = true
		for c in n.get_children():
			stack.append(c)
	return acc

func _test_pickup_hand_dimensions() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var actor: Node = _make_player()
	if actor.third_person_model == null:
		actor._create_third_person_model()
	var puppet: Node = _make_player()
	puppet.stats = SurvivalStats.new()
	puppet.add_child(puppet.stats)
	puppet.stats.set_process(false)
	puppet.setup_as_puppet()
	puppet.puppet_apply_visuals("Camiseta,Pantalones,Zapatillas", "", "")
	await process_frame

	world._spawn_ground_pickup("Mochila militar", "backpack", Vector3(0.0, 0.0, -0.7), 1.8, 1, 0.0, "bp_scale_test")
	var gvis := world.get_node_or_null("Pickup_bp_scale_test")
	var ground_box := _world_mesh_aabb(gvis)
	var ground_extent := maxf(ground_box.size.x, maxf(ground_box.size.y, ground_box.size.z))
	actor.begin_ground_gesture("bp_scale_test", "Mochila militar", "backpack")
	actor.play_action_animation("pickup", actor.GroundGesture.DURATION)
	actor._ground_gesture.tick(actor.GroundGesture.GRAB_TIME + 0.05)
	actor._update_hand_socket()
	var hand_box := _world_mesh_aabb(actor.third_person_hand_item_root)
	var hand_extent := maxf(hand_box.size.x, maxf(hand_box.size.y, hand_box.size.z))
	check(actor.third_person_hand_item_root.find_child("ThirdPersonBackpack", true, false) != null,
		"military backpack pickup builds the real backpack mesh in hand")
	check(hand_extent >= 0.65 and absf(hand_extent - ground_extent) < 0.14,
		"military backpack keeps its real dimensions in hand (ground=%.2f hand=%.2f)" % [ground_extent, hand_extent])
	actor.end_ground_gesture()

	var bp_item = preload("res://scripts/Item.gd").create("Mochila militar", "backpack", 1.8, 1, 0.0)
	actor.inventory.items.append(bp_item)
	actor._select_held_item(actor.inventory.items.size() - 1)
	var held_box := _world_mesh_aabb(actor.third_person_hand_item_root)
	var held_extent := maxf(held_box.size.x, maxf(held_box.size.y, held_box.size.z))
	check(held_extent >= 0.65, "military backpack carried in hand from inventory keeps full dimensions (%.2f)" % held_extent)
	actor.clear_hands()

	puppet._update_puppet_held_item("Mochila militar")
	puppet._update_hand_socket()
	var puppet_bp_box := _world_mesh_aabb(puppet.third_person_hand_item_root)
	var puppet_extent := maxf(puppet_bp_box.size.x, maxf(puppet_bp_box.size.y, puppet_bp_box.size.z))
	check(puppet.third_person_hand_item_root.find_child("ThirdPersonBackpack", true, false) != null and puppet_extent >= 0.65,
		"remote puppet carrying military backpack shows full-sized backpack (%.2f)" % puppet_extent)

	for pair in [["Chaqueta militar", "clothing", "HeldClothing"], ["Piel de lobo", "resource", "HeldPelt"]]:
		var pid := "dim_" + str(pair[0]).replace(" ", "_")
		world._spawn_ground_pickup(pair[0], pair[1], Vector3(0.0, 0.0, -0.7), 1.0, 1, 0.0, pid)
		actor.begin_ground_gesture(pid, pair[0], pair[1])
		actor._ground_gesture.tick(actor.GroundGesture.GRAB_TIME + 0.05)
		var pbox := _world_mesh_aabb(actor.third_person_hand_item_root)
		var longest := maxf(pbox.size.x, maxf(pbox.size.y, pbox.size.z))
		check(actor.third_person_hand_item_root.find_child(pair[2], true, false) != null and longest >= 0.55,
			"%s keeps real mesh and dimensions in hand (longest=%.2f)" % [pair[0], longest])
		actor.end_ground_gesture()

	puppet.free()
	actor.free()
	world.free()
	current_scene = null

func _initialize() -> void:
	print("=== PickupAnimRegression ===")
	await process_frame

	var player: Node = _make_player()
	await process_frame
	var ap: AnimationPlayer = _mount_model(player)
	await process_frame

	var offset: float = player.THIRD_PERSON_GATHER_ANIM_OFFSET
	var gather: String = player.third_person_gather_animation
	var interact: String = player.third_person_interact_animation
	check(not gather.is_empty(), "gather animation resolved")
	check(ap.has_animation(gather), "gather clip exists in player")
	check(not interact.is_empty(), "interact animation resolved")

	ap.play(player.third_person_idle_animation, 0.0)
	for action in ["pickup", "collect"]:
		player.play_action_animation(action, player.GroundGesture.DURATION)
		check(player.third_person_action_timer == player.GroundGesture.DURATION, action + " waits for the pickup gesture")
		check(player.third_person_action_animation == player._motion("pickup_ground"), action + " uses the ground-reaching clip")
		check(ap.get_animation(player.third_person_action_animation).loop_mode == Animation.LOOP_NONE, action + " is a single pickup")

	# Forage resolves the same clip — same offset keeps sender/puppet aligned.
	player.play_action_animation("forage", 3.0)
	check(player.third_person_action_animation == gather,
		"forage selects gather clip (got '%s')" % player.third_person_action_animation)
	check(ap.current_animation_position >= offset - 0.01,
		"forage seeks identically (pos %.2f)" % ap.current_animation_position)
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""
	player.third_person_action_start_offset = 0.0

	# Non-gesture actions keep their own timing (no seek leaks).
	player.play_action_animation("plant", 1.0)
	check(player.third_person_action_start_offset == 0.0,
		"plant action carries no seek offset (got %.2f)" % player.third_person_action_start_offset)
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""

	player.play_action_animation("pick_fruit", 3.0)
	check(ap.current_animation == player._motion("pick_fruit"), "tree fruit uses the branch-reaching clip")
	check(player.third_person_action_timer == 3.0, "fruit timing remains three seconds")
	player.third_person_action_timer = 0.0
	player._held_item_external = true
	player._held_item_reference = preload("res://scripts/Item.gd").create("Pala", "tool_shovel", 1.0)
	player.play_action_animation("dig", 4.0)
	check(ap.current_animation == player._motion("dig"), "shovel work uses digging")
	check(player.third_person_action_timer == 4.0, "digging does not change the action window")
	player.play_action_animation("eat", 2.0)
	check(ap.current_animation == player.third_person_eat_animation, "eating uses the mouth gesture")
	check(player.third_person_action_timer == 2.0, "eating retains its two-second window")
	check(ap.current_animation_position == 0.0 and ap.speed_scale == player.EAT_GESTURE_SPEED,
		"eating plays its own short take from the start at natural speed")
	check(ap.get_animation(player.third_person_eat_animation) != ap.get_animation(player.third_person_drink_animation),
		"food and bottle do not alias the same animation")
	player.third_person_action_timer = 0.0
	player.third_person_action_animation = ""
	player._held_item_reference = preload("res://scripts/Item.gd").create("Fusil de asalto", "weapon_rifle", 3.0)
	player._rifle_in_hands = true
	player._motion_posture = ""
	player._tick_cosmetic_rifle_motion(false, 0.0)
	player.is_crouching = true
	check(player._tick_cosmetic_rifle_motion(false, 0.016) == player._motion("stand_to_crouch"), "crouching selects its transition")
	check(player.third_person_action_timer == 0.0, "posture motion does not block gameplay")
	check(player._tick_cosmetic_rifle_motion(true, 0.016).is_empty(), "movement interrupts the cosmetic transition")
	player.is_crouching = false
	player._tick_cosmetic_rifle_motion(true, 0.0)
	player.is_jumping = true
	player._jump_animation_timer = 1.2
	player._update_third_person_animation(false, 0.016)
	check(ap.current_animation == player._motion("jump_up"), "rifle jump starts with takeoff")
	player._update_third_person_animation(false, 0.25)
	check(ap.current_animation == player._motion("jump_air"), "rifle jump continues in the air")
	player.is_jumping = false
	player._max_fall_height = player.position.y + 0.5
	player._land_after_fall()
	player._update_third_person_animation(false, 0.016)
	check(ap.current_animation == player._motion("jump_land"), "rifle jump lands without changing gravity")

	# A remote puppet receiving the synced gather clip seeks to the kneel too —
	# otherwise remote players only see the standing wind-up.
	var puppet: Node = _make_player()
	await process_frame
	var puppet_ap: AnimationPlayer = _mount_model(puppet)
	await process_frame
	check(ap.get_animation_library("motion") == puppet_ap.get_animation_library("motion"), "compatible actors share one motion library")
	puppet.is_puppet = true
	var packet: String = player.GroundGesture.packet("pickup", "seta|1", "Seta", "food", 0.7)
	puppet.puppet_apply(Vector3.ZERO, 0.0, packet)
	check(puppet_ap.current_animation == puppet._motion("pickup_ground"), "remote pickup selects the same clip")
	check(absf(puppet_ap.current_animation_position - 0.7) < 0.02, "joining during a pickup preserves its phase")
	check(puppet._ground_gesture.action_id == "seta|1", "gesture IDs survive packet escaping")
	check(puppet._ground_gesture.item.item_name == "Seta", "remote gesture displays the actual food")
	puppet.puppet_apply(Vector3.ZERO, 0.0, player.GroundGesture.packet("eat", "seta|1", "Seta", "food"))
	check(puppet_ap.current_animation == puppet.third_person_eat_animation, "ground pickup transitions to eating")
	puppet.puppet_apply(Vector3.ZERO, 0.0, "idle")
	check(puppet._ground_gesture == null, "remote interruption clears the temporary item")
	for clip_name in ap.get_animation_library("motion").get_animation_list():
		var motion: Animation = ap.get_animation("motion/" + clip_name)
		for track in motion.get_track_count():
			check(motion.track_get_type(track) == Animation.TYPE_ROTATION_3D, "motions never move or scale the controller")
	puppet.puppet_apply(Vector3.ZERO, 0.0, "idle")
	puppet.puppet_apply(Vector3.ZERO, 0.0, gather)
	check(puppet_ap.current_animation == gather,
		"puppet plays synced gather clip (got '%s')" % puppet_ap.current_animation)
	check(puppet_ap.current_animation_position >= offset - 0.01,
		"puppet seeks to the kneel (pos %.2f)" % puppet_ap.current_animation_position)
	# InteractExternal (legacy/edge pickups) seeks to its own gesture point.
	puppet.puppet_apply(Vector3.ZERO, 0.0, interact)
	check(puppet_ap.current_animation_position >= player.THIRD_PERSON_INTERACT_ANIM_OFFSET - 0.01,
		"puppet interact clip seeks to its bend (pos %.2f)" % puppet_ap.current_animation_position)
	# A plain locomotion clip still plays from the start.
	puppet.puppet_apply(Vector3.ZERO, 0.0, "external/PlantExternal")
	check(puppet_ap.current_animation_position < 0.5,
		"puppet plant clip is not seeked (pos %.2f)" % puppet_ap.current_animation_position)

	player.queue_free()
	puppet.queue_free()
	await process_frame
	await _test_ground_transactions()
	await _test_pickup_hand_dimensions()
	print("PickupAnimRegression failures=%d" % failures)
	quit(1 if failures > 0 else 0)
