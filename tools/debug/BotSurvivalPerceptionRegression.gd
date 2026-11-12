extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
	func _peer_id_for_actor(actor: Node3D) -> int:
		return int(actor.get_meta("peer_id", 0))
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var manager := Manager.new()
	root.add_child(manager)
	var actor := Node3D.new()
	root.add_child(actor)
	var meal := {"name":"Carne asada","type":"food","quantity":1,"weight":.42,"use_value":25.0}
	actor.set_meta("saved_inventory",[meal.duplicate(true)])
	check(manager._take_peace_gift(actor).is_empty(), "never give away last meal")
	actor.set_meta("saved_inventory",[meal.duplicate(true),meal.duplicate(true)])
	var gift := manager._take_peace_gift(actor)
	check(gift.get("use_value") == 25.0 and gift.get("weight") == .42 and gift.get("quantity") == 1, "food keeps actual value and weight")
	check((actor.get_meta("saved_inventory") as Array).size() == 1, "separate stacks retain one meal")
	actor.set_meta("saved_inventory",[{"name":"Vendaje","type":"medical","quantity":2,"weight":.1,"use_value":0.0}])
	gift = manager._take_peace_gift(actor)
	check(gift.get("type") == "medical" and gift.get("weight") == .1, "bandage remains medical")
	check(actor.get_meta("saved_inventory")[0].quantity == 1, "exactly one bandage removed")
	actor.set_meta("peer_id",7)
	var b := {"last_heard_until":Time.get_ticks_msec()/1000.0+10.0,"last_heard_pos":Vector3.ZERO,"last_heard_actor":8}
	check(not manager._can_bot_hear_actor(b,actor,5.0), "another shooter's sound does not reveal silent actor")
	b.last_heard_actor = 7
	check(manager._can_bot_hear_actor(b,actor,5.0), "identified shooter is heard")
	b.last_heard_actor = 8
	actor.set_meta("moving",true)
	check(manager._can_bot_hear_actor(b,actor,5.0), "actual footsteps remain audible")
	actor.free()
	manager.free()
	print("BOT_SURVIVAL_PERCEPTION errors=",errors)
	quit(errors)
