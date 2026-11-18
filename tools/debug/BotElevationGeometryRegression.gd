extends SceneTree
const Routes = preload("res://scripts/BotElevationRoutes.gd")
const City = preload("res://scripts/CityBlock.gd")
const Expansion = preload("res://scripts/CityExpansion.gd")
class World extends "res://scripts/Main.gd":
	func _ready() -> void: set_process(false); set_physics_process(false)
	func _exit_tree() -> void: pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return .025
class Manager extends SurvivorBotManager:
	func _is_city_building_door_open(_i: int, _p: Vector3) -> bool: return true
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0
var errors := 0
var checks := 0
var mgr: Manager
var actor: Node3D
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: errors += 1; push_error(label)
func travel(goal: Vector3, label: String, ticks: int = 1800) -> void:
	var b := {"proxy":actor,"bot_id":901,"pos":actor.position,"rot":0.0,"health":100.0,"hunger":95.0,"thirst":95.0,"energy":100.0,"path":[],"path_idx":0,"path_timer":0.0,"stuck_timer":0.0,"stuck_count":0,"last_move_pos":actor.position,"has_rifle":false,"avoid_t":0.0,"anim":"idle","_mem":{}}
	var hits := {}
	var space := actor.get_world_3d().direct_space_state
	for i in ticks:
		if actor.position.distance_to(goal) < .25: break
		var before := actor.position
		mgr._move_bot_towards(b,goal,3.2,.1,"walk")
		for height in [.9,1.65]:
			var query := PhysicsRayQueryParameters3D.create(before+Vector3.UP*height,actor.position+Vector3.UP*height,5)
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				if hits.is_empty(): print("CROSS ",label," ",before," -> ",actor.position," height=",height," at=",hit.position)
				hits[str(hit.collider.get_parent().name)] = true
	check(actor.position.distance_to(goal)<.3,"%s reaches target with real collisions (%s)" % [label,actor.position])
	check(hits.is_empty(),"%s crosses no walls/ceilings: %s" % [label,hits])
func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	mgr = Manager.new()
	root.add_child(mgr)
	mgr.world = world
	actor = Node3D.new()
	root.add_child(actor)
	var district := City.new()
	district.position = Expansion.CENTER
	world.add_child(district)
	for idx in [0,1,2,3,16]:
		var building := district.load_building(idx)
		var door := building.get_node(str(City.BUILDINGS[idx].id)+"_door") as Door
		door.is_open = true
		door.rotation_degrees.y = door.open_yaw
	await physics_frame
	await physics_frame
	for idx in [0,1,2,3,16]:
		var building: Node3D = district.buildings[idx]
		var goal := Vector3(1.6,7.86,4.8) if idx in [1,2] else (Vector3(1.2,11.82,-2.2) if idx==16 else Vector3(-1.2,3.92,-2.6))
		actor.position = building.to_global(Vector3(.15,.12,8.3))
		travel(building.to_global(goal),"%s up" % building.name)
		travel(building.to_global(Vector3(.15,.12,8.3)),"%s down" % building.name)
	district.free()
	var clock_tower := preload("res://scripts/CityClockTower.gd").new()
	clock_tower.position = clock_tower.WORLD_POSITION
	world.add_child(clock_tower)
	clock_tower.set_process(false)
	await physics_frame
	await physics_frame
	actor.position = Vector3(41,.06,739.8)
	travel(Vector3(39.6,29.46,750.8),"clock tower up")
	travel(Vector3(41,.06,739.8),"clock tower down")
	clock_tower.free()
	var base := Vector3(-375,56,-375)
	var yaw := deg_to_rad(HighMountainZone.BASE_YAW_DEG)
	var wp := base+HighMountainZone.WATCH_TOWER_OFFSET.rotated(Vector3.UP,yaw)-Vector3(0,1.145*.85,0)
	HighMountainZone._build_summit_watchtower_collision(world,wp,Vector3.ONE*.85,HighMountainZone.BASE_YAW_DEG)
	world._register_wildlife_blocker(base+HighMountainZone.WATCH_TOWER_OFFSET.rotated(Vector3.UP,yaw),4.0)
	HighMountainZone._spawn_green_mountain_comms_tower(world,world,base+HighMountainZone.COMMS_TOWER_OFFSET.rotated(Vector3.UP,yaw),HighMountainZone.BASE_YAW_DEG,true)
	await physics_frame
	await physics_frame
	for route in Routes.summit_routes():
		check(mgr._is_pos_blocked(route.center+Vector3(0,2,0)),str(route.id)+" shaft stays blocked outside the stair corridor")
		actor.position = route.points[0]
		travel(route.points.back(),str(route.id)+" up",2600)
		travel(route.points[0],str(route.id)+" down",2600)
	print("BotElevationGeometry: checks=%d errors=%d" % [checks,errors])
	actor.free()
	mgr.free()
	world.free()
	quit(1 if errors else 0)
