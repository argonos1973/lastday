extends SceneTree
const CityBlock = preload("res://scripts/CityBlock.gd")
const CityExpansion = preload("res://scripts/CityExpansion.gd")

class World extends "res://scripts/Main.gd":
	func _ready() -> void: set_process(false); set_physics_process(false)
	func _exit_tree() -> void: pass
	func _spawn_remote_player(_id: int) -> void: pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return .025
class Manager extends SurvivorBotManager:
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0
	func _kill_bot(b: Dictionary, cause: String) -> void: b["death_cause"] = cause
	func _abandon_unreachable_goal(b: Dictionary, _goal: Vector3, _nav_reason: String = "") -> void: b["abandoned"] = true
	func _ai_note_loot(_b: Dictionary, _nm: String, _tp: String) -> void: pass
	func _auto_equip_best_gear(_b: Dictionary) -> void: pass

var errors := 0
var checks := 0
var world: World
var manager: Manager
var actor: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors += 1; push_error(message)
func bot() -> Dictionary:
	return {"proxy":actor,"bot_id":901,"pos":actor.position,"rot":0.0,"health":100.0,"hunger":95.0,"thirst":95.0,"energy":100.0,"path":[],"path_idx":0,"path_timer":0.0,"stuck_timer":0.0,"stuck_count":0,"last_move_pos":actor.position,"has_rifle":false,"avoid_t":0.0,"anim":"idle","_mem":{}}
func travel(goal: Vector3, label: String) -> void:
	var b := bot()
	var crossed := false
	for tick in 700:
		if actor.position.distance_to(goal) < .3: break
		var before := actor.position
		manager._move_bot_towards(b,goal,6.2,.1,"run")
		var q := PhysicsRayQueryParameters3D.create(before+Vector3.UP,actor.position+Vector3.UP,5)
		if before.distance_to(actor.position) > .001 and not actor.get_world_3d().direct_space_state.intersect_ray(q).is_empty(): crossed = true
		if before.distance_to(actor.position) < .001:
			check(str(b.anim) == "idle", label+" stops animation when blocked")
		# Complete only door tweens, using the same animation as the real world.
		for door in get_nodes_in_group("doors"):
			if door._tween != null and door._tween.is_running(): door._tween.custom_step(.1)
		if tick % 10 == 0: await physics_frame
	check(actor.position.distance_to(goal)<.4,"%s reaches goal: %s -> %s waypoint=%s" % [label,actor.position,goal,b.get("_interior_last_waypoint")])
	check(not crossed,label+" crosses no walls")

func city_drink_escape(city: Node3D) -> void:
	# Live regression: Carlos and Ataulfo died dehydrated on the ground floor of
	# city_10 while nominally walking to the plaza fountain. The full decision
	# tick —not only the movement primitive— must leave the front-facing house,
	# route around its shell and reach water behind/north of the building.
	if world.day_cycle == null:
		world.day_cycle = DayNightCycle.new()
		world.day_cycle.process_mode = Node.PROCESS_MODE_DISABLED
		world.day_cycle.time_of_day = 14.0
		world.add_child(world.day_cycle)
	var fountain_pos := Vector3(41.0, 0.0, 728.0)
	var drink = world._create_world_action("city10_escape_drink", "drink_water", "Fuente de la plaza", fountain_pos + Vector3(0, .9, 0), Vector3(4.6, 1.7, 4.6), Color.TRANSPARENT, true, false)
	if drink != null:
		drink.set_meta("drink_source", "de la fuente")
		drink.set_meta("water_reach", 2.8)
	manager._spawn_bot(manager.BOT_CONFIGS[0])
	var b: Dictionary = manager.bots[901]
	var city10: Node3D = city.buildings[9]
	var inside := city10.to_global(Vector3(0, .12, -1.0))
	b.proxy.global_position = inside
	b.proxy.set_meta("saved_pos", inside)
	b["pos"] = inside
	b["thirst"] = 8.0
	b["hunger"] = 90.0
	b["health"] = 100.0
	b["energy"] = 100.0
	b["sleep"] = 100.0
	b["drink_scan"] = 0.0
	b["drink_at"] = Vector3.INF
	b["drink_walk_t"] = 0.0
	b["_bad_water"] = []
	b["_s_leader"] = null
	b["_s_foe"] = null
	b["_s_predator"] = null
	b["_s_loot"] = {}
	b["_s_prey"] = null
	var st: SurvivalStats = b.get("vstats")
	if st != null:
		st.body_temperature = 36.6
		st.wetness = 0.0
		st.energy = 100.0
		st.sleep = 100.0
	var escaped := false
	var hydrated := false
	var min_dist := INF
	for tick in 500:
		manager._tick_bot(b, .1)
		var pos: Vector3 = b.proxy.global_position
		min_dist = minf(min_dist, Vector2(pos.x - fountain_pos.x, pos.z - fountain_pos.z).length())
		if not world._is_player_in_house(pos):
			escaped = true
		if float(b["thirst"]) >= 95.0:
			hydrated = true
			break
		if tick % 5 == 0:
			await physics_frame
	print("city10 drink escape: pos=%s act=%s drink_at=%s escaped=%s min_dist=%.2f thirst=%.1f" % [b.proxy.global_position, b.get("_act"), b.get("drink_at"), escaped, min_dist, float(b["thirst"])])
	check(escaped, "city_10 ground floor: critical thirst leaves the building")
	check(hydrated or min_dist < 4.0, "city_10 ground floor: critical thirst reaches the plaza fountain (min_d=%.2f thirst=%.1f)" % [min_dist, float(b["thirst"])])
	# The same full decision tick must descend an upper city floor. This is the
	# exact live death pocket in city_06: sofa side, y=3.92, critical thirst,
	# destination outside at the plaza fountain.
	var city06: Node3D = city.buildings[5]
	var upstairs := city06.to_global(Vector3(-1.5, 3.92, -0.3))
	b.proxy.global_position = upstairs
	b.proxy.set_meta("saved_pos", upstairs)
	b["pos"] = upstairs
	b["thirst"] = 8.0
	b["drink_scan"] = 0.0
	b["drink_at"] = Vector3.INF
	b["drink_walk_t"] = 0.0
	b["_bad_water"] = []
	var descended := false
	var upstairs_min_dist := INF
	for tick in 650:
		manager._tick_bot(b, .1)
		var upos: Vector3 = b.proxy.global_position
		upstairs_min_dist = minf(upstairs_min_dist, Vector2(upos.x - fountain_pos.x, upos.z - fountain_pos.z).length())
		if upos.y < 1.0:
			descended = true
		if float(b["thirst"]) >= 95.0:
			break
		if tick % 5 == 0:
			await physics_frame
	print("city06 upstairs drink escape: pos=%s act=%s descended=%s min_dist=%.2f thirst=%.1f" % [b.proxy.global_position, b.get("_act"), descended, upstairs_min_dist, float(b["thirst"])])
	check(descended, "city_06 upper floor: critical thirst descends the stairs")
	check(float(b["thirst"]) >= 95.0 or upstairs_min_dist < 4.0,
		"city_06 upper floor: critical thirst reaches the fountain after descending (min_d=%.2f thirst=%.1f)" % [upstairs_min_dist, float(b["thirst"])])
	# Ataulfo died dehydrated in the same rotated flat-roof pocket of city_03
	# (local ~=(-1.3,3.92,-0.3)). The full thirst decision —not only the
	# movement primitive— must abandon loot/material work, descend and leave.
	var city03: Node3D = city.buildings[2]
	var c3up := city03.to_global(Vector3(-1.3, 3.92, -0.3))
	b.proxy.global_position = c3up
	b.proxy.set_meta("saved_pos", c3up)
	b["pos"] = c3up
	b["thirst"] = 42.0
	b["drink_scan"] = 0.0
	b["drink_at"] = Vector3.INF
	b["drink_walk_t"] = 0.0
	b["_bad_water"] = []
	var c3_descended := false
	var c3_min_dist := INF
	for tick in 650:
		manager._tick_bot(b, .1)
		var c3pos: Vector3 = b.proxy.global_position
		c3_min_dist = minf(c3_min_dist, Vector2(c3pos.x - fountain_pos.x, c3pos.z - fountain_pos.z).length())
		if c3pos.y < 1.0:
			c3_descended = true
		if float(b["thirst"]) >= 95.0:
			break
		if tick % 5 == 0:
			await physics_frame
	print("city03 upstairs drink escape: pos=%s act=%s descended=%s min_dist=%.2f thirst=%.1f" % [b.proxy.global_position, b.get("_act"), c3_descended, c3_min_dist, float(b["thirst"])])
	check(c3_descended, "city_03 upper floor: critical thirst descends the stairs")
	check(float(b["thirst"]) >= 95.0 or c3_min_dist < 4.0,
		"city_03 upper floor: critical thirst reaches the fountain after descending (min_d=%.2f thirst=%.1f)" % [c3_min_dist, float(b["thirst"])])
	if drink != null:
		world.world_actions_by_id.erase("city10_escape_drink")
		drink.queue_free()

func hot_house_escape() -> void:
	var fire := Vector3(-20,0,30)
	var pit := WorldAction.new()
	world.add_child(pit)
	pit.position = fire
	world.world_actions_by_id["hot_house"] = pit
	check(world._net_campfire_lit("hot_house","TestHouseFire",fire),"house 10 fire is burning")
	var door := world.get_node("Casa abandonada 10 Door") as Door
	door.set_open(false,false)
	if door._tween != null: door._tween.custom_step(1.0)
	world._server_door_states[door.name] = false
	world._refresh_nav_door_caches()
	world.day_cycle = DayNightCycle.new()
	world.day_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	world.day_cycle.time_of_day = 23.0
	world.add_child(world.day_cycle)
	manager._spawn_bot(manager.BOT_CONFIGS[1])
	var b: Dictionary = manager.bots[902]
	var carlos: Node3D = b.proxy
	carlos.position = Vector3(-20.5,.1,30.7)
	carlos.set_meta("proxy_health",14.0)
	b.merge({"pos":carlos.position,"health":14.0,"hide_timer":5.0,"sleeping":true},true)
	var st: SurvivalStats = b.vstats
	st.body_temperature = 37.95
	var crossed := 0
	var through_door := true
	var min_hp := float(b.health)
	for i in 400:
		var before := carlos.position
		manager._tick_bot(b,.05)
		min_hp = minf(min_hp,st.health)
		if st.dead: break
		if world._is_player_in_house(before) != world._is_player_in_house(carlos.position):
			crossed += 1
			through_door = through_door and door.is_open and absf(carlos.position.x + 20.0) < 1.0 and carlos.position.z > 33.0
		if door._tween != null and door._tween.is_running(): door._tween.custom_step(.05)
		if i % 5 == 0: await physics_frame
	print("Hot house 10: crossings=%d min_hp=%.2f final_hp=%.2f temp=%.2f" % [crossed,min_hp,st.health,st.body_temperature])
	check(crossed == 1 and through_door and not world._is_player_in_house(carlos.position),
		"hot house 10: escapes through the door once (pos=%s crossings=%s)" % [carlos.position,crossed])
	check(not st.dead and st.body_temperature < 37.8 and st.health > min_hp and min_hp < 14.0,
		"hot house 10: thermal damage stops and health recovers (min=%.2f hp=%.2f temp=%.2f)" % [min_hp,st.health,st.body_temperature])
	# Same exposure without an escape: the fatal tick must name the damage.
	carlos.position = fire + Vector3(1,0,0)
	b.health = .04
	st.dead = false
	st.body_temperature = 37.95
	manager._bot_survival_tick(b,.05)
	check(b.get("death_cause") == "heatstroke","fatal moderate overheating is not an unexplained death")

func run() -> void:
	world = World.new()
	root.add_child(world)
	current_scene = world
	world._register_server_house_blockers()
	for h in world._HOUSE_SHELL_LAYOUT:
		world._create_house(Vector3(h[2],0,h[3]),h[0],h[1],h[4],h[5],h[6],true)
	for origin in [Vector3(45,0,120),Vector3(-340,0,280)]:
		world._create_barn_shell_colliders(origin,str(origin.x))
	var city := preload("res://scripts/CityBlock.gd").new()
	city.position = CityExpansion.CENTER
	world.add_child(city)
	for idx in CityBlock.BUILDINGS.size():
		var building := city.load_building(idx)
		var def: Dictionary = CityBlock.BUILDINGS[idx]
		var door := building.get_node(str(def.id)+"_door") as Door
		var fp: Vector2 = def.get("footprint",Vector2(6,6))
		var yaw := float(def.yaw)
		var i := world._register_wildlife_blocker(building.global_position,fp.length())
		var out := Vector3.BACK.rotated(Vector3.UP,yaw)
		world.wildlife_blockers[i].merge({"door":door,"door_name":str(door.name),"door_pos":door.global_position,"door_center":building.to_global(Vector3(.15,.12,6.08)),"door_out_dir":Vector2(out.x,out.z),"city_building_index":idx,"building_yaw":yaw,"house_bounds":Rect2(Vector2(building.global_position.x-fp.x,building.global_position.z-fp.y),fp*2)},true)
	world.bot_nav = world._new_nav_pathfinding()
	world.bot_nav.build(world.wildlife_blockers,[])
	world.wolf_nav = world.bot_nav
	world.nav = world.bot_nav
	world._refresh_nav_door_caches()
	manager = Manager.new()
	root.add_child(manager)
	manager.world = world
	actor = Node3D.new()
	root.add_child(actor)
	await physics_frame
	await physics_frame
	for h in world._HOUSE_SHELL_LAYOUT:
		var center := Vector3(h[2],0,h[3])
		var target := center+Vector3(0,0,-1)
		for offset in [Vector3(0,0,-h[5]*.5-5),Vector3(h[4]*.5+5,0,0)]:
			var door := world.get_node(str(h[0])+" Door") as Door
			door.set_open(false,false)
			if door._tween != null: door._tween.custom_step(1.0)
			world._server_door_states[door.name] = false
			world._refresh_nav_door_caches()
			actor.position = center+offset
			await travel(target,str(h[1])+" enter "+str(offset))
			check(door.is_open,str(h[1])+" opened door")
			# Another survivor closes the door while the bot is in the room.
			door.set_open(false,false)
			if door._tween != null: door._tween.custom_step(1.0)
			world._server_door_states[door.name] = false
			world._refresh_nav_door_caches()
			await travel(center+offset,str(h[1])+" exit")
			check(door.is_open,str(h[1])+" reopens door from inside")
		var wall_out := center+Vector3(h[4]*.5+.8,0,0)
		var item_in := center+Vector3(h[4]*.5-.8,.3,0)
		check(manager._is_step_blocked(center+Vector3(h[4]*.5+.4,0,0),center+Vector3(h[4]*.5-.3,0,0)),str(h[1])+" margin escape never enters through a wall")
		check(not manager._bot_can_reach_loot(wall_out,item_in),str(h[1])+" cannot loot through side wall")
		check(manager._bot_can_reach_loot(center,center+Vector3(.5,.3,0)),str(h[1])+" can collect reachable interior loot")
		actor.position = wall_out
		actor.set_meta("saved_inventory",[])
		var entry := {"id":str(h[1])+"_test_loot","name":"Palo","type":"material","weight":.1,"qty":1,"pos":item_in}
		world._dropped_items = [entry]
		var looter := bot()
		manager._collect_loot_entry(looter,entry)
		check(world._dropped_items.size()==1 and actor.get_meta("saved_inventory").is_empty(),str(h[1])+" outside collection keeps item in world")
		await travel(center,str(h[1])+" goes inside to loot")
		await travel(center+Vector3(h[4]*.5-1.3,0,0),str(h[1])+" approaches interior item")
		manager._collect_loot_entry(looter,entry)
		check(world._dropped_items.is_empty() and manager._bot_item_count(actor,"Palo")==1,str(h[1])+" interior loot transfers once to inventory")
	# Live hypothermia regression: Kael was INSIDE Casa 8 at (-40.6,-7.9)
	# while the thermal refuge target was inside Casa 1. The resolver iterated
	# Casa 1 first and aimed through Casa 8's wall; he oscillated there until
	# nav_blocked and then froze. The current building's exit must be resolved
	# before any destination-house entrance.
	actor.position = Vector3(-40.6, 0.1, -7.9)
	var kael_probe := bot()
	var kael_goal := Vector3(-23.0, 0.1, -17.0)
	var kael_wp: Vector3 = manager._resolve_door_approach_goal(kael_probe, actor.position, kael_goal)
	check(kael_wp.x < -35.0 and kael_wp.z > -5.0,
		"casa8->casa1: resolver exits current Casa 8 before entering Casa 1 (wp=%s)" % kael_wp)
	await travel(kael_goal, "casa8 interior reaches Casa 1 refuge")
	for idx in CityBlock.BUILDINGS.size():
		var building: Node3D = city.buildings[idx]
		actor.position = building.to_global(Vector3(0,.12,-11))
		await travel(building.to_global(Vector3(.15,.12,4.6)),building.name+" enter from rear")
		await travel(building.to_global(Vector3(11,.12,0)),building.name+" exit to side")
	# Regression from the live dehydration death: Elena was pinned upstairs in
	# city_06 beside the upper sofa at local (-1.5,3.92,-0.3). From that exact
	# pocket the bot must still reach the landing, descend and leave the house.
	var city06: Node3D = city.buildings[5]
	actor.position = city06.to_global(Vector3(-1.5,3.92,-0.3))
	await travel(city06.to_global(Vector3(11,.12,0)),"city_06 upper floor sofa pocket exits")
	# Live regression: Kael remained running in city_03 (rotated PI, flat roof)
	# around local (-1.1,3.92,-0.1). Both mirrored flat-roof variants must
	# descend from that pocket instead of oscillating on the landing.
	for idx in [2,3]:
		var cb: Node3D = city.buildings[idx]
		actor.position = cb.to_global(Vector3(-1.1,3.92,-0.1))
		await travel(cb.to_global(Vector3(11,.12,0)),"city_%02d rotated upper pocket exits" % (idx+1))
	for origin in [Vector3(45,0,120),Vector3(-340,0,280)]:
		for side in [-1,1]:
			actor.position = origin+Vector3(9,0,side*6)
			await travel(origin,"barn %s enter %s" % [origin,side])
			await travel(origin+Vector3(-9,0,side*6),"barn %s exit %s" % [origin,side])
	await city_drink_escape(city)
	await hot_house_escape()
	print("BotHouseTraversal: checks=%d errors=%d" % [checks,errors])
	actor.free(); manager.free(); world.free()
	quit(1 if errors else 0)
