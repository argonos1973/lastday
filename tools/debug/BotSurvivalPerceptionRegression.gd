extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
	var loot_item_builds := 0
	func _loot_entry_item_dict(entry: Dictionary) -> Dictionary:
		loot_item_builds += 1
		return super._loot_entry_item_dict(entry)
	func _peer_id_for_actor(actor: Node3D) -> int:
		return int(actor.get_meta("peer_id", 0))
	var los := true
	func _has_clear_shot(_a: Vector3, _b: Vector3) -> bool: return los
class LootWorld extends Node3D:
	var _dropped_items: Array = []
	var _depleted_action_ids: Array = []
	var _pickup_claims := {}
	var _pickup_claim_until := {}
	var world_actions_by_id := {}

func test_loot_search(manager: Manager, proxy: Node3D) -> void:
	var world := LootWorld.new()
	root.add_child(world)
	manager.world = world
	proxy.set_meta("saved_inventory", [])
	var bot := {"bot_id": 901, "proxy": proxy, "backpack": "Mochila militar", "hunger": 90.0, "health": 100.0}
	var near := {"id": "near", "name": "Fusil de asalto", "type": "weapon_rifle", "weight": 3.6, "qty": 1, "pos": [28.0, 0.0, 0.0]}
	world._dropped_items = [near]
	var chosen := manager._find_nearby_valuable_loot(bot, 28.0)
	check(chosen.get("id") == "near", "loot exactly at the radius remains reachable")
	for i in range(2000):
		var far := near.duplicate(true)
		far["id"] = "far_%d" % i
		far["pos"] = [60.0 + i, 0.0, 0.0]
		world._dropped_items.append(far)
	manager.loot_item_builds = 0
	check(manager._find_nearby_valuable_loot(bot, 28.0) == chosen, "distant drops cannot change the selected local loot")
	check(manager.loot_item_builds == 1, "thousands of distant drops do not trigger recipe/inventory evaluations")
	world._dropped_items = [near]
	near["pos"] = [28.01, 0.0, 0.0]
	check(manager._find_nearby_valuable_loot(bot, 28.0).is_empty(), "loot just outside the radius is excluded")
	near["pos"] = [18.0, 35.0, 0.0]
	check(manager._find_nearby_valuable_loot(bot, 28.0).get("id") == "near", "upper floors remain reachable beyond the spherical radius")
	near["pos"] = [18.01, 3.0, 0.0]
	check(manager._find_nearby_valuable_loot(bot, 28.0).is_empty(), "upper-floor loot requires proximity to the building")
	near["pos"] = [3.0, 0.0, 0.0]
	world._pickup_claims["near"] = 902
	world._pickup_claim_until["near"] = Time.get_ticks_msec() + 10000
	check(manager._find_nearby_valuable_loot(bot, 28.0).is_empty(), "another bot's live claim still prevents selection")
	world._pickup_claims.clear()
	near["weight"] = 1000.0
	check(manager._find_nearby_valuable_loot(bot, 28.0).is_empty(), "nearby loot must still fit in the inventory")
	near["weight"] = 3.6
	world._depleted_action_ids.append("near")
	check(manager._find_nearby_valuable_loot(bot, 28.0).is_empty(), "depleted loot remains excluded")
	manager.world = null
	world.free()
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
	# Percepcion honesta: vista exige alcance + linea de vision; oido exige pista sonora
	var me := Node3D.new()
	root.add_child(me)
	var bp := {"proxy": me, "bot_id": 901, "last_heard_until": 0.0, "last_heard_pos": Vector3.INF, "last_heard_actor": 0}
	actor.set_meta("moving", false)
	actor.position = Vector3(8, 0, 0)
	manager.los = false
	check(not manager._bot_perceives_actor(bp, actor, 52.0), "still actor 8 m behind a wall is not perceived")
	manager.los = true
	check(manager._bot_perceives_actor(bp, actor, 52.0), "same actor with line of sight is perceived")
	actor.position = Vector3(80, 0, 0)
	check(not manager._bot_perceives_actor(bp, actor, 52.0), "actor beyond visual range is not perceived even in the open")
	actor.set_meta("crouching", true)
	actor.position = Vector3(40, 0, 0)
	check(not manager._bot_perceives_actor(bp, actor, 52.0), "crouched actor at 40 m is harder to spot")
	actor.set_meta("crouching", false)
	# Valor aparente: mochila/arma/ropa visibles, jamas el inventario
	actor.set_meta("saved_inventory", [meal.duplicate(true), meal.duplicate(true), meal.duplicate(true), meal.duplicate(true), meal.duplicate(true), meal.duplicate(true)])
	check(is_equal_approx(manager._bot_observed_loot_value(bp, actor, 0), 0.0), "inventory contents are invisible to an observer")
	actor.set_meta("saved_backpack", "Mochila militar")
	actor.set_meta("saved_held_item", "Fusil de asalto")
	actor.set_meta("saved_clothing", "Chaqueta,Pantalon")
	check(is_equal_approx(manager._bot_observed_loot_value(bp, actor, 0), 5.0 + 4.0 + 1.2), "visible backpack + rifle + clothes define apparent value")
	# Vulnerabilidad aparente: postura o herida presenciada, no proxy_health
	actor.set_meta("proxy_health", 3.0)
	check(not manager._bot_observed_vulnerable(bp, actor, 7), "low internal health alone does not look vulnerable")
	bp["_seen_wounded"] = {7: Time.get_ticks_msec()}
	check(manager._bot_observed_vulnerable(bp, actor, 7), "a witnessed wound does")
	bp["_seen_wounded"] = {}
	actor.set_meta("saved_sleeping", true)
	check(manager._bot_observed_vulnerable(bp, actor, 7), "a sleeping survivor looks vulnerable")
	# Horario unico: mismas fases para el mundo y para los bots
	check(DayNightCycle.is_night_at(21.5) and not DayNightCycle.is_night_at(21.4) and DayNightCycle.is_night_at(5.9) and not DayNightCycle.is_night_at(6.0),
		"clock night is 21:30-06:00 from a single definition")
	check(DayNightCycle.phase_at(12.0) == "day" and DayNightCycle.phase_at(17.0) == "prep" and DayNightCycle.phase_at(20.0) == "dusk"
			and DayNightCycle.phase_at(23.0) == "night" and DayNightCycle.phase_at(6.3) == "dawn", "day phases: dawn/day/prep/dusk/night")
	check(not DayNightCycle.is_dark_at(19.4) and not DayNightCycle.is_dark_at(20.0) and DayNightCycle.is_dark_at(21.0),
		"dusk keeps usable light at 20:00 and turns dark near its end")
	check(DayNightCycle.is_dark_at(20.4, 1.0) and not DayNightCycle.is_dark_at(20.4, 0.0), "a storm brings darkness earlier at dusk")
	check(not DayNightCycle.is_dark_at(13.0, 1.0), "a storm at midday is not night")
	var prev_light := 2.0
	var monotonic := true
	for i in range(41):
		var lt := DayNightCycle.light_amount_at(19.5 + float(i) * 0.05)
		if lt > prev_light + 0.0001:
			monotonic = false
		prev_light = lt
	check(monotonic and prev_light == 0.0, "light falls smoothly through dusk with no jumps")
	test_loot_search(manager, me)
	me.free()
	actor.free()
	manager.free()
	print("BOT_SURVIVAL_PERCEPTION errors=",errors)
	quit(errors)
