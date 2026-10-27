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

class World extends Node3D:
	var distant_hit := {}
	func raycast_distant_props(_start: Vector3, _end: Vector3) -> Dictionary: return distant_hit

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
	current_scene = null
	world.free()
	print("PRIMITIVE_COVER_ERRORS=", errors)
	quit(1 if errors else 0)
