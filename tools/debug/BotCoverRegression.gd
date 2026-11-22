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
	check(not manager._bot_within_aim_sight(b, animal, 8.0), "analytical cover also blocks aim recognition")
	manager._handle_predator_encounter(b,animal,.1)
	check(manager.moves == 1 and not b.is_aiming, "rifle bot navigates instead of aiming into cover")
	manager._bot_fire_rifle_at(b,animal,100)
	check(animal.damage == 0, "release guard prevents damage behind cover")
	manager.weapon = "Cuchillo"
	animal.position.z = -2
	manager._handle_predator_encounter(b,animal,.1)
	check(animal.damage == 0 and manager.moves == 2, "melee cannot hit through cover")
	arena.distant_cover = false
	check(manager._bot_within_aim_sight(b, animal, 8.0), "aim recognition recovers once cover is removed")
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
	# Doma: la defensa manda. Bajo fuego se aparca; el lobo manso no pasa a
	# ser objetivo; si se revuelve es un depredador mas; en calma se retoma.
	var wolf := Animal.new()
	arena.add_child(wolf)
	wolf.position = Vector3(9, 0, 0)
	wolf.set("_is_dead", false)
	var shooter := Node3D.new()
	arena.add_child(shooter)
	shooter.position = Vector3(0, 0, 40)
	var tb := {"proxy": proxy, "bot_id": 9001, "aggro_target": null, "_s_foe": null, "_s_predator": null,
		"flee_until": 0.0, "hide_timer": 0.0, "_last_attacker_msec": -999999, "_wolf_bite_msec": -999999, "_tame_pause_until": 0.0}
	check(not manager._bot_tame_interrupted(tb, wolf), "calm: taming is allowed")
	tb["_last_attacker_msec"] = Time.get_ticks_msec() # recibe un disparo
	tb["aggro_target"] = shooter
	check(manager._bot_tame_interrupted(tb, wolf), "shot while taming: taming is interrupted")
	check(not manager._bot_wolf_is_aggressive(tb, wolf), "the wolf being tamed is not treated as an aggressor")
	var evs: Array = (manager._ensure_bot_memory(9001) as Dictionary).get("events", [])
	check(evs.any(func(e): return str(e.get("type", "")) == "tame_interrupted"), "interruption is recorded once in memory")
	tb["aggro_target"] = null
	tb["_last_attacker_msec"] = -999999
	check(manager._bot_tame_interrupted(tb, wolf), "hysteresis: no instant flip back to taming when the threat ends")
	tb["_tame_pause_until"] = 0.0
	check(not manager._bot_tame_interrupted(tb, wolf), "once safe again the taming resumes")
	tb["_wolf_bite_msec"] = Time.get_ticks_msec()
	check(manager._bot_wolf_is_aggressive(tb, wolf) and manager._bot_tame_interrupted(tb, wolf),
		"a wolf that bites is handled as a predator, not as a pet in progress")
	wolf.free()
	shooter.free()
	arena.free()
	print("BOT_COVER errors=",errors)
	quit(errors)
