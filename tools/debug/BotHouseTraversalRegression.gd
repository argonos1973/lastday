extends SceneTree
const CityBlock = preload("res://scripts/CityBlock.gd")
const CityExpansion = preload("res://scripts/CityExpansion.gd")

class World extends "res://scripts/Main.gd":
	func _ready() -> void: set_process(false); set_physics_process(false)
	func _exit_tree() -> void: pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return .025
class Manager extends SurvivorBotManager:
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0
	func _abandon_unreachable_goal(b: Dictionary, _goal: Vector3) -> void: b["abandoned"] = true
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
	for idx in CityBlock.BUILDINGS.size():
		var building: Node3D = city.buildings[idx]
		actor.position = building.to_global(Vector3(0,.12,-11))
		await travel(building.to_global(Vector3(.15,.12,4.6)),building.name+" enter from rear")
		await travel(building.to_global(Vector3(11,.12,0)),building.name+" exit to side")
	for origin in [Vector3(45,0,120),Vector3(-340,0,280)]:
		for side in [-1,1]:
			actor.position = origin+Vector3(9,0,side*6)
			await travel(origin,"barn %s enter %s" % [origin,side])
			await travel(origin+Vector3(-9,0,side*6),"barn %s exit %s" % [origin,side])
	print("BotHouseTraversal: checks=%d errors=%d" % [checks,errors])
	actor.free(); manager.free(); world.free()
	quit(1 if errors else 0)
