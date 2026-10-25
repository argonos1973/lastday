extends SceneTree
const ItemData = preload("res://scripts/Item.gd")
class Actor extends "res://scripts/PlayerController.gd":
	var test_item
	var launches: Array = []
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func get_held_item(): return test_item
	func play_action_animation(_action: String, _duration: float = 0.55): pass
	func _schedule_melee_swing_sound(_delay: float): pass
	func _sync_held_item(): pass
	func _launch_primitive_projectile(o: Vector3, d: Vector3, speed: float, distance: float, excluded: Array[RID], damage: float, item: String, type: String, weight: float, use: float, bola: bool, visual: bool = false, wind: Vector3 = Vector3.ZERO):
		launches.append({"origin":o,"item":item})
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var actor := Actor.new()
	world.add_child(actor)
	actor.camera = Camera3D.new()
	actor.add_child(actor.camera)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.inventory.add_item(ItemData.create("Flecha de madera", "ammo_arrow", .06, 10, 3))
	for mode in ["complete", "death", "swap", "reequip"]:
		actor.test_item = ItemData.create("Arco de madera", "weapon_bow", 1, 1, 0)
		actor.is_dead = false
		actor.stats.energy = 100
		actor._shoot_cooldown = 0
		actor.launches.clear()
		var count := actor._count_inventory_arrows()
		actor._shoot_bow()
		check(actor.launches.is_empty() and actor._count_inventory_arrows() == count, "Bow waits for release without consuming ammo: " + mode)
		actor._tick_primitive_releases(.3)
		check(actor.launches.is_empty(), "No premature arrow")
		if mode == "death": actor.is_dead = true
		if mode == "swap": actor.test_item = null
		if mode == "reequip": actor._held_selection_revision += 1
		actor._tick_primitive_releases(.5)
		check(actor.launches.size() == (1 if mode == "complete" else 0), "Bow cancellation: " + mode)
		check(actor._count_inventory_arrows() == count - (1 if mode == "complete" else 0), "Only real launch consumes arrow: " + mode)
		check(is_equal_approx(actor.stats.energy,96.5 if mode == "complete" else 100), "Only real launch costs energy: " + mode)
		actor._tick_primitive_releases(1)
		check(actor.launches.size() <= 1, "No double release")
	for mode in ["complete", "death", "swap", "reequip"]:
		actor.test_item = ItemData.create("Lanza", "tool_spear", 1, 1, 0)
		actor._held_item_external = true
		actor.is_dead = false
		actor.stats.energy = 100
		actor._shoot_cooldown = 0
		actor.launches.clear()
		actor._throw_aimed_weapon()
		actor.position = Vector3(4,0,2)
		if mode == "death": actor.is_dead = true
		if mode == "swap": actor.test_item = null
		if mode == "reequip": actor._held_selection_revision += 1
		actor._tick_primitive_releases(.5)
		check(actor.launches.size() == (1 if mode == "complete" else 0), "Throw cancellation: " + mode)
		if mode == "complete":
			check(actor.launches[0].origin.distance_to(actor.position + Vector3(0,1.42,0)) < .01, "Throw originates at current player position")
		check(is_equal_approx(actor.stats.energy,94 if mode == "complete" else 100), "Cancelled throws cost no energy")
	actor.is_dead = false
	actor.third_person_model = Node3D.new()
	actor.add_child(actor.third_person_model)
	actor.third_person_animation_player = AnimationPlayer.new()
	actor.add_child(actor.third_person_animation_player)
	var lib := AnimationLibrary.new()
	var clip := Animation.new()
	clip.length = 1.5
	lib.add_animation("throw", clip)
	actor.third_person_animation_player.add_animation_library("", lib)
	actor.third_person_attack_animation = "throw"
	actor.third_person_action_animation = "throw"
	actor.third_person_action_timer = .8
	actor._throw_aim_hold = true
	actor._throw_aim_frozen = true
	actor.third_person_animation_player.play("throw")
	actor.third_person_animation_player.seek(.4, true)
	actor._update_third_person_animation(false,.016)
	actor.third_person_animation_player.advance(.2)
	check(actor.third_person_animation_player.speed_scale == 0, "Animation update preserves frozen aiming pose")
	actor._throw_aim_hold = false
	actor._throw_aim_frozen = false
	actor._update_third_person_animation(false,.016)
	check(actor.third_person_animation_player.speed_scale == 1, "Release resumes animation")
	current_scene = null
	world.free()
	print("PRIMITIVE_RELEASE_ERRORS=", errors)
	quit(1 if errors else 0)
