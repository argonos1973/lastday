extends SceneTree

class Arena extends Node3D:
	var distant_cover := false
	func raycast_distant_props(_a: Vector3, _b: Vector3) -> Dictionary:
		return {"position": Vector3.ZERO} if distant_cover else {}

class Manager extends "res://scripts/SurvivorBotManager.gd":
	var weapon := "Rifle francotirador"
	var moves := 0
	func _best_weapon_name(_proxy: Node3D) -> String: return weapon
	func _is_bot_wolf_protected(_b: Dictionary) -> bool: return false
	func _move_bot_towards(_b: Dictionary, _goal: Vector3, _speed: float, _delta: float, _anim: String) -> void: moves += 1

class Animal extends Node3D:
	var _is_dead := false
	var damage := 0.0
	func take_damage(amount: float, _knife: bool, _attacker: Node = null): damage += amount

var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var arena := Arena.new()
	root.add_child(arena)
	current_scene = arena
	var manager := Manager.new()
	arena.add_child(manager)
	manager.world = arena
	var proxy := Node3D.new()
	arena.add_child(proxy)
	var animal := Animal.new()
	arena.add_child(animal)
	animal.position = Vector3(0,0,-8)
	var b := {"proxy":proxy,"bot_id":9001,"shoot_cooldown":0.0,"attack_cooldown":0.0}
	check(manager._has_clear_shot(proxy.position,animal.position), "open sight line")
	arena.distant_cover = true
	check(not manager._has_clear_shot(proxy.position,animal.position), "analytical distant cover blocks sight")
	manager._handle_predator_encounter(b,animal,.1)
	check(manager.moves == 1 and not b.is_aiming, "rifle bot navigates instead of aiming into cover")
	manager._bot_fire_rifle_at(b,animal,100)
	check(animal.damage == 0, "release guard prevents damage behind cover")
	manager.weapon = "Cuchillo"
	animal.position.z = -2
	manager._handle_predator_encounter(b,animal,.1)
	check(animal.damage == 0 and manager.moves == 2, "melee cannot hit through cover")
	arena.distant_cover = false
	animal.position.y = 2.2
	manager._handle_predator_encounter(b,animal,.1)
	check(animal.damage == 0 and manager.moves == 3, "melee cannot hit another floor")
	animal.position.y = 0
	manager._handle_predator_encounter(b,animal,.1)
	check(animal.damage > 0, "unobstructed melee still damages the predator")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(4,4,.2)
	wall.add_child(shape)
	arena.add_child(wall)
	wall.position = Vector3(0,1,-1)
	await physics_frame
	await physics_frame
	animal.position.y = 0
	check(not manager._has_clear_shot(proxy.position,animal.position), "physical wall blocks sight")
	arena.free()
	print("BOT_COVER errors=",errors)
	quit(errors)
