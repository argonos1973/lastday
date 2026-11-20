extends SceneTree

class Actor extends "res://scripts/PlayerController.gd":
	var test_item
	var sight_hit := {}
	var launched_direction := Vector3.ZERO
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _update_hand_socket(): pass
	func get_held_item(): return test_item
	func _rifle_sight_hit(_o: Vector3, _d: Vector3, _e: Array[RID]) -> Dictionary: return sight_hit
	func play_action_animation(_action: String, _duration: float = .55): pass
	func _schedule_melee_swing_sound(_delay: float): pass
	func _launch_primitive_projectile(_o: Vector3, d: Vector3, _s: float, _range: float, _excluded: Array[RID], _damage: float, _name: String, _type: String, _weight: float, _use: float, _bola: bool, _visual: bool = false, _wind: Vector3 = Vector3.ZERO):
		launched_direction = d

class World extends "res://scripts/Main.gd":
	var distant_hit := {}
	func _ready(): set_process(false); set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _get_exact_ground_y(_x: float, _z: float, _fallback: float = 500.0) -> float: return 0.0
	func raycast_distant_props(_start: Vector3, _end: Vector3) -> Dictionary: return distant_hit

class BotManager extends SurvivorBotManager:
	var damage_events := 0
	var last_damage := 0.0
	func _apply_bot_damage_to_target(_b: Dictionary, _target: Node3D, amount: float, _weapon: String) -> void:
		damage_events += 1
		last_damage = amount

var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var actor := Actor.new()
	world.add_child(actor)
	actor.camera = Camera3D.new()
	actor.add_child(actor.camera)
	actor.camera.position.y = 1.42
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.test_item = preload("res://scripts/Item.gd").create("Lanza", "tool_spear", 1, 1, 0)
	actor.sight_hit = {"position": Vector3(.2,1.42,-1)}
	actor._throw_aimed_weapon()
	check(actor._throw_release_target == actor.sight_hit.position, "Spear uses nearby sight hit")
	actor._throw_release_item = null
	actor._shoot_cooldown = 0
	actor.test_item = preload("res://scripts/Item.gd").create("Arco de madera", "weapon_bow", 1, 1, 0)
	actor.inventory.add_item(preload("res://scripts/Item.gd").create("Flecha de madera", "ammo_arrow", .06, 1, 3))
	actor._shoot_bow()
	actor._tick_primitive_releases(1)
	check(actor.launched_direction.x > .2, "Arrow converges on nearby target instead of distant fallback")
	actor._hand_skeleton = Skeleton3D.new()
	actor.add_child(actor._hand_skeleton)
	actor.third_person_hand_item_root = Node3D.new()
	actor.add_child(actor.third_person_hand_item_root)
	actor.third_person_hand_item_root.position = Vector3(1,1.42,0)
	var wall := StaticBody3D.new()
	wall.collision_layer = 4
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(.1,3,3)
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector3(.5,1.42,0)
	await physics_frame
	await physics_frame
	var origin := actor._spear_release_origin([actor.get_rid()])
	check(origin.x < .45, "Spear cannot spawn beyond layer-4 cover")
	wall.queue_free()
	await physics_frame
	world.distant_hit = {"position":Vector3(.3,1.42,0),"normal":Vector3.LEFT}
	origin = actor._spear_release_origin([actor.get_rid()])
	check(origin.x < .3, "Spear respects distant batched cover")
	var bow_origin := actor._bow_release_origin([actor.get_rid()], Vector3.RIGHT)
	check(bow_origin.x < .3, "Bow respects distant batched cover")
	world.distant_hit = {}
	var close_bow_origin := actor._bow_release_origin([actor.get_rid()], Vector3.RIGHT, Vector3(.45, 1.42, 0))
	check(close_bow_origin.x < .35, "Bow pulls release origin back when target_pt is close")
	world.distant_hit = {}
	actor.free()
	await _check_bot_and_vehicle_cover(world)
	current_scene = null
	world.free()
	print("PRIMITIVE_COVER_ERRORS=", errors)
	quit(1 if errors else 0)

func _check_bot_and_vehicle_cover(world) -> void:
	world._create_road_vehicle_colliders()
	var manager := BotManager.new()
	world.add_child(manager); manager.world = world
	var shooter := Node3D.new(); world.add_child(shooter)
	var victim := Node3D.new(); world.add_child(victim)
	victim.add_to_group("net_player_proxy"); victim.set_meta("peer_id", 42); victim.set_meta("crouching", true)
	var capsule_probe := preload("res://scripts/RifleProjectile.gd").new()
	world.add_child(capsule_probe); capsule_probe.set_physics_process(false)
	capsule_probe._refresh_proxy_candidates()
	check(capsule_probe._proxy_segment_hit(Vector3(-2, 1.5, 0), Vector3(2, 1.5, 0)).is_empty(),
		"a spear above a crouched head misses: no extra invisible 36 cm")
	check(not capsule_probe._proxy_segment_hit(Vector3(-2, .65, 0), Vector3(2, .65, 0)).is_empty(),
		"a real crouched torso hit still registers")
	capsule_probe.free()
	var inventory := [
		{"name": "Lanza", "type": "tool_spear", "quantity": 1, "weight": 1.0, "durability": 80.0, "max_durability": 100.0},
		{"name": "Lanza", "type": "tool_spear", "quantity": 1, "weight": 1.0, "durability": 0.0, "max_durability": 100.0}]
	shooter.set_meta("saved_inventory", inventory.duplicate(true))
	var b := {"proxy": shooter, "bot_id": 901, "held_item": "Lanza", "anim": "idle", "health": 100.0, "energy": 100.0}
	await physics_frame
	await physics_frame
	for car_name in ["JunkCarCollision0", "ScrapBarricadeCarCollision"]:
		var car: Node3D = world.get_node(car_name)
		var side := car.basis.x
		shooter.global_position = car.global_position - side * 8.0
		victim.global_position = car.global_position + side * 3.0
		var origin := shooter.global_position + Vector3.UP * 1.4
		var aim := manager._bot_target_torso(victim)
		check(is_equal_approx(aim.y - victim.global_position.y, 0.65), "crouched victim is aimed at the torso, not the head")
		check(not manager._bot_can_release_throw(b, victim, "Lanza"), car_name+" blocks a throw at the crouched victim")
		manager._bot_fire_thrown(b, victim, "Lanza", false)
		check(not b.has("_throw_pending") and manager._bot_item_count(shooter, "Lanza") == 1, car_name+" prevents spending a spear through cover")
		# Even a projectile already in flight must stop on the real car shell.
		manager._bot_launch_projectile(b, origin, (aim-origin).normalized(), "Lanza", GameConst.SPEAR_THROW_SPEED,
			GameConst.THROW_MAX_DISTANCE, 65, false, "lanza")
		var projectile = world.get_child(world.get_child_count()-1)
		var hits: Array = []
		projectile.impact.connect(func(c, _p, _d, _n): hits.append(c))
		projectile._physics_process(0.8)
		check(hits.size() == 1 and hits[0] == car and manager.damage_events == 0, car_name+" stops the swept spear before the victim")
		await physics_frame
	shooter.position = Vector3(-50, 0, -50); victim.position = shooter.position + Vector3(0, 0, -15)
	var aim := manager._bot_aim_point(b, victim, 15.0, "throw")
	manager._bot_aim_st(b)["dir"] = (aim - (shooter.position + Vector3.UP*1.4)).normalized()
	manager._bot_fire_thrown(b, victim, "Lanza", false)
	check(b.has("_throw_pending") and manager._bot_effective_net_anim(b) == "attack", "throw has a visible windup")
	check(manager._bot_item_count(shooter, "Lanza") == 1, "windup has not spent the spear yet")
	await create_timer(PlayerController.THROW_RELEASE_DELAY + 0.05).timeout
	check(manager._bot_item_count(shooter, "Lanza") == 0 and b.held_item == "", "release removes exactly one spear from the hand and inventory")
	var flights: Array = world.get_children().filter(func(n): return n.get_script() == preload("res://scripts/RifleProjectile.gd"))
	check(flights.size() == 1, "release launches one real projectile")
	if not flights.is_empty():
		var projectile = flights[0]
		check(is_equal_approx(projectile.launch_speed, GameConst.SPEAR_THROW_SPEED), "bot uses the player's hand-thrown speed")
		check(float(b._shot_log[-1].spread) >= 2.5, "hand throw has a minimum angular error")
		var before: int = world._dropped_items.size()
		projectile.traveled = projectile.max_distance - 0.01
		projectile._physics_process(0.01)
		projectile._physics_process(0.01)
		check(world._dropped_items.size() == before + 1, "flight expires into one recoverable weapon, never an inventory refill")
		if world._dropped_items.size() > before:
			check(float(world._dropped_items[-1].get("durability", -1)) == 78.0, "recovered spear keeps its actual wear")
			var action = world.world_actions_by_id.get(world._dropped_items[-1].id)
			check(action != null and float(action.get_meta("item_durability", -1)) == 78.0,
				"a human picking up the landed spear receives its wear too")
	# Losing the target or moving during windup cannot fire or consume an item.
	shooter.set_meta("saved_inventory", inventory.duplicate(true))
	b.held_item = "Lanza"; b.anim = "idle"
	manager._bot_fire_thrown(b, victim, "Lanza", false)
	shooter.position.x += 1.0
	await create_timer(PlayerController.THROW_RELEASE_DELAY + 0.05).timeout
	check(manager._bot_item_count(shooter, "Lanza") == 1, "movement during windup cancels without losing the spear")
	victim.position = shooter.position + Vector3(0, 0, -40)
	check(not manager._bot_can_release_throw(b, victim, "Lanza"), "bot will not throw at a distant forty-metre target")
	check(PlayerController.spear_actor_damage(true, 0.75) < 100.0
		and PlayerController.spear_actor_damage(false, 0.75) < PlayerController.spear_actor_damage(false, 1.0),
		"spent spears lose wounding energy and cannot retain a point-blank instant kill")
	var spent := preload("res://scripts/RifleProjectile.gd").new()
	spent.launch_speed = GameConst.SPEAR_THROW_SPEED
	spent.velocity = Vector3.FORWARD * spent.launch_speed * 0.75
	manager._on_bot_projectile_impact(b, spent, victim, victim.position + Vector3.UP * .65, 65, false, "lanza")
	check(is_equal_approx(manager.last_damage, PlayerController.spear_actor_damage(false, .75)),
		"authoritative impact actually uses residual energy and a crouched torso is not a headshot")
	spent.free()
	shooter.free(); victim.free()
