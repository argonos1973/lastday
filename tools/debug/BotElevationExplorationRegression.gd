extends SceneTree
## Real bot locomotion/decision code in an isolated world; no network or saves.
const Routes = preload("res://scripts/BotElevationRoutes.gd")
const City = preload("res://scripts/CityBlock.gd")
const Expansion = preload("res://scripts/CityExpansion.gd")

class World extends Node3D:
	var _watchtower_climb: Array = []
	var bot_nav = null
	var wolf_nav = null
	var wildlife_blockers: Array = []
	var _spawn_zones: Array = []
	var _military_tent_pos := Vector3.ZERO
	var _remote_tent_pos := Vector3.ZERO
	var _city_tent_pos := Vector3.ZERO
	var _city_tent2_pos := Vector3.ZERO
	func get_river_depth_at(_p: Vector3) -> float: return 0.0

class Manager extends SurvivorBotManager:
	var clear := true
	var target: Node3D
	func _ground_y(x: float, z: float, _from: float = -INF) -> float:
		return HighMountainZone.ground_height_at(Vector3(x,0,z)) + .035 if x < -210 and z < -210 else .12
	func _is_pos_blocked(_p: Vector3, _r: float = .42, _deep: bool = false) -> bool: return false
	func _is_step_blocked(_a: Vector3, _z: Vector3, _deep: bool = false) -> bool: return false
	func _wall_between(_a: Vector3, _z: Vector3) -> bool: return false
	func _is_city_building_door_open(_idx: int, _pos: Vector3) -> bool: return true
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0
	func _world_day_phase() -> String: return "day"
	func _has_clear_shot(_a: Vector3, _z: Vector3) -> bool: return clear
	func _find_actor_by_peer_id(_id: int) -> Node3D: return target
	func _bot_ambush_forbidden(_b: Dictionary, _id: int) -> bool: return false
	func rally_bot_team(_id: int, _target: Node3D) -> void: pass

var errors := 0
var checks := 0
var mgr: Manager
var actor: Node3D

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(label)

func bot() -> Dictionary:
	return {"proxy":actor,"bot_id":901,"pos":actor.position,"rot":0.0,"health":100.0,
		"hunger":95.0,"thirst":95.0,"energy":100.0,"path":[],"path_idx":0,"path_timer":0.0,
		"stuck_timer":0.0,"stuck_count":0,"last_move_pos":actor.position,"has_rifle":false,
		"avoid_t":0.0,"anim":"idle","faction":"hostile","_mem":{"visited":[],"personality":{},"stats":{}}}

func travel(b: Dictionary, goal: Vector3, label: String, ticks: int = 1500) -> void:
	var maximum_step := 0.0
	var wrong_descent := false
	for i in ticks:
		if actor.position.distance_to(goal) < .2: break
		var before := actor.position
		mgr._move_bot_towards(b,goal,3.2,.1,"walk")
		wrong_descent = wrong_descent or (actor.position.y < before.y-.01 and str(b.anim)=="stairs")
		maximum_step = maxf(maximum_step,actor.position.distance_to(before))
	check(actor.position.distance_to(goal) < .3, "%s arrived: %s, wanted %s" % [label,actor.position,goal])
	check(maximum_step < .7,"%s no teleport/pop through floors (step %.2f)" % [label,maximum_step])
	check(not wrong_descent,"%s descent never plays human ascending clip" % label)
	check((b.get("_unreachable",[]) as Array).is_empty(),"%s not marked unreachable while climbing" % label)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var w := World.new()
	root.add_child(w)
	mgr = Manager.new()
	root.add_child(mgr)
	mgr.world = w
	actor = Node3D.new()
	root.add_child(actor)
	for idx in range(City.BUILDINGS.size()):
		var def: Dictionary = City.BUILDINGS[idx]
		var origin: Vector3 = Expansion.CENTER + def.position
		var yaw: float = def.yaw
		var flat := idx%4 in [1,2] and idx < 16
		var local_goal := Vector3(1.6,7.86,4.8) if flat else (Vector3(1.2,11.82,-2.2) if idx==16 else Vector3(-1.2,3.92,-2.6))
		var entry := origin + Vector3(.15,.12,8.3).rotated(Vector3.UP,yaw)
		actor.position = entry
		var b := bot()
		travel(b,origin+local_goal.rotated(Vector3.UP,yaw),"%s up" % def.id)
		travel(b,entry,"%s down" % def.id)
	actor.position = Vector3(41,.06,739.8)
	var cb := bot()
	travel(cb,Vector3(39.6,29.46,750.8),"clock tower 7 floors")
	travel(cb,Vector3(41,.06,739.8),"clock tower descent")
	for route in Routes.summit_routes():
		var pts: Array = route.points
		actor.position = pts[0]
		var tb := bot()
		travel(tb,pts.back(),"%s ascent" % route.id,2500)
		travel(tb,pts[int(pts.size()/2)],"%s intermediate floor" % route.id,2500)
		travel(tb,pts[0],"%s descent" % route.id,2500)
	# Road must reach the plateau through its gate, not cut across its cliffs.
	actor.position = Vector3(-252,.835,-268)
	var mb := bot()
	travel(mb,Vector3(-356,56.035,-356),"summit road ascent",5000)
	travel(mb,Vector3(-252,.835,-268),"summit road descent",5000)
	# Reaching the first road point is not an exit: outside a ten-metre
	# radius the former resolver pulled an actor back to the foot forever.
	travel(mb,Vector3(-210,.12,-210),"continue from road foot into the valley",2500)
	for water in [Vector3(-158,.12,-137), Vector3(184,.12,-303)]:
		actor.position = Vector3(-247.6,.6,-268.9)
		var thirsty := bot()
		thirsty["thirst"] = 8.0
		thirsty["_act"] = "drink"
		thirsty["drink_at"] = water
		travel(thirsty,water,"Carlos leaves the mountain approach to drink at %s" % water,2500)
	for leg in [[Vector2(-265.7,-270.9), Vector2(-294,-280)],
			[Vector2(-268.8,-256.2), Vector2(-37,24)],
			[Vector2(-247.6,-268.9), Vector2(-265,-277)]]:
		var start: Vector2 = leg[0]
		var finish: Vector2 = leg[1]
		actor.position = Vector3(start.x,mgr._ground_y(start.x,start.y),start.y)
		var forager := bot()
		forager["_act"] = "forage"
		var food := Vector3(finish.x,mgr._ground_y(finish.x,finish.y),finish.y)
		travel(forager,food,"Kael forage interruption %s -> %s" % [start,finish],2500)
	actor.position = Vector3(-252,.835,-268)
	var intermediate := bot()
	var road := HighMountainZone.get_road_polyline_3d()
	for fraction in [.75, .65, .85]:
		var point: Vector3 = road[int(float(road.size() - 1) * fraction)]
		point.y = mgr._ground_y(point.x,point.z)
		travel(intermediate,point,"intermediate mountain road destination %.2f" % fraction,5000)
	var pois := mgr._explore_pois()
	var roofs := 0
	var regions := {}
	for p in pois:
		regions[mgr._exploration_region(p.pos)] = true
		if str(p.kind)=="tower" and p.pos.y > 7.0 and p.pos.y < 9.0: roofs+=1
	check(roofs==8,"all eight flat house roofs are exploration goals")
	check(regions.size()>=12,"exploration covers outer forest, south and summit (%d regions)" % regions.size())
	actor.position = Vector3.ZERO
	var eb := bot()
	check(mgr._bot_needs_outing(eb),"healthy equipped bot can explore despite having a home")
	eb.energy = 20.0
	check(not mgr._bot_can_expedition(eb),"exhaustion takes priority over expeditions")
	eb.energy = 100.0
	var counts := {}
	for region in regions: counts[region] = 50
	counts[mgr._exploration_region(Vector3(-375,56,-375))] = 0
	eb._mem.exploration_regions = counts
	var pick: Dictionary = mgr._ai_pick_poi(eb,[],[],false)
	check(mgr._exploration_region(pick.pos)==mgr._exploration_region(Vector3(-375,56,-375)),"unexplored summit region wins over repeatedly looted village")
	# No blind shots: climbing may use the last sighting, firing still needs LOS.
	actor.position = Vector3(25,.12,671)
	var foe := Node3D.new()
	root.add_child(foe)
	foe.position = Vector3(25,.12,690)
	mgr.target = foe
	actor.set_meta("saved_inventory",[{"name":"Fusil de asalto","type":"weapon","quantity":1}])
	actor.set_meta("bot_gun_ammo",{"m4_magazine":30,"m4_reserve":30})
	var ab := bot()
	ab._ambush = {"target_id":4,"pos":foe.position,"seen_msec":Time.get_ticks_msec(),"t":0.0}
	mgr._bot_try_ambush(ab,.1)
	var post: Vector3 = ab._ambush.get("post",Vector3.INF)
	check(post.is_finite() and post.y>3.0,"armed ambusher chooses a reachable elevated post")
	if post.is_finite():
		actor.position = post
		mgr.clear = false
		var known: Vector3 = ab._ambush.pos
		foe.position += Vector3(10,0,10)
		for i in 30: mgr._bot_try_ambush(ab,.1)
		check(ab._ambush.pos==known and ab.get("aggro_target")==null,"hidden target is neither tracked nor fired on from height")
		mgr.clear = true
		for i in 30:
			mgr._bot_try_ambush(ab,.1)
			if ab.get("aggro_target")!=null: break
		check(ab.get("aggro_target")==foe and ab.get("_overwatch",{}).get("post")==post,"visible target triggers the ambush while retaining the elevated firing post")
		ab.aggro_target = null
		ab._ambush = {"target_id":4,"pos":known,"post":post,"t":40.0}
		mgr.clear = false
		ab._ambush.seen_msec = Time.get_ticks_msec()-151000
		check(not mgr._bot_try_ambush(ab,.1) and ab._ambush.is_empty(),"stale elevated ambush expires")
	print("BotElevationExploration: checks=%d errors=%d" % [checks,errors])
	foe.free()
	actor.free()
	mgr.free()
	w.free()
	quit(1 if errors else 0)
