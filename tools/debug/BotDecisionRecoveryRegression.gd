extends SceneTree
class Arena extends Node3D:
	var world_actions_by_id := {}
	var _pickup_claims := {}
	var _depleted_action_ids := []
class Manager extends "res://scripts/SurvivorBotManager.gd":
	func _ensure_world_action_caches() -> void: pass
class Action extends Node3D:
	var action_type := "eat_food"
class Enemy extends Node3D:
	var is_dead := false
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var world := Arena.new()
	root.add_child(world)
	var manager := Manager.new()
	world.add_child(manager)
	manager.world = world
	var proxy := Node3D.new()
	world.add_child(proxy)
	var blocked := Action.new()
	world.add_child(blocked)
	blocked.position = Vector3(3,0,0)
	var accessible := Action.new()
	world.add_child(accessible)
	accessible.position = Vector3(30,0,0)
	world.world_actions_by_id = {"blocked":blocked,"accessible":accessible}
	manager._cached_eat_ids = ["blocked","accessible"]
	var b := {"proxy":proxy,"_unreachable":[{"pos":blocked.position,"until":Time.get_ticks_msec()/1000.0+100.0}]}
	check(manager._find_forage_target(b,60).get("id") == "accessible", "choose alternative food after a navigation failure")
	blocked.action_type = "pick_fruit"
	accessible.action_type = "pick_fruit"
	manager._cached_eat_ids = []
	manager._cached_fruit_ids = ["blocked","accessible"]
	check(manager._find_forage_target(b,60).get("id") == "accessible", "fruit respects unreachable zones")
	b._unreachable[0].until = -1.0
	check(manager._find_forage_target(b,60).get("id") == "blocked", "resource can be retried after temporary exclusion expires")
	var enemy := Enemy.new()
	world.add_child(enemy)
	b._s_foe = enemy
	check(manager._sensed_node(b,"_s_foe") == enemy,"live opponent remains sensed")
	enemy.is_dead = true
	check(manager._sensed_node(b,"_s_foe") == null,"dead opponent no longer blocks survival decisions")
	b._s_corpse = enemy
	check(manager._sensed_node(b,"_s_corpse") == enemy,"corpse remains available to scavenge")
	enemy.is_dead = false
	b.aggro_target = enemy
	b._ambush = {"target_id":8}
	b.crouching = true
	proxy.set_meta("crouching",true)
	check(not manager._bot_try_ambush(b,.1) and b._ambush.is_empty() and not b.crouching, "actual attacker interrupts stalking posture")
	world.free()
	print("BOT_DECISION_RECOVERY errors=",errors)
	quit(errors)
