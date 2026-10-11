extends RefCounted
const CENTER := Vector3(9,0,680)
const SOUTH_LIMIT := 900.0
const BLOCK := preload("res://scripts/CityBlock.gd")

static func reserves_terrain(pos: Vector3, radius: float = 0.0) -> bool:
 # An open southern pass, then the new district. Existing inner terrain remains.
 return pos.z+radius>440 and pos.z-radius<760 and absf(pos.x-CENTER.x)<radius+55

static func inside_building(pos: Vector3) -> bool:
 for definition in BLOCK.BUILDINGS:
  var offset: Vector3=pos-CENTER-definition.position
  if absf(offset.x)<5.85 and absf(offset.z)<5.85 and pos.y<7.9: return true
 return false

static func on_road(pos: Vector3, margin: float = 0.0, start_z: float = 500.0) -> bool:
 # start_z: where the generated main road actually ends (mesh continues from there).
 var local:=pos-CENTER
 return (absf(local.x)<3.5+margin and pos.z>=start_z-margin and pos.z<=720+margin) or (absf(local.z)<3.5+margin and absf(local.x)<40+margin)

static func create(world: Node3D, server: bool) -> Node3D:
 var district:=BLOCK.new()
 district.name="SouthernCity"
 district.position=CENTER
 world.add_child(district)
 # Four buildings stay resident for collisions, saving and the existing door RPCs.
 # The prototype's distance unload is intentionally disabled in the main world.
 district.set_process(false)
 for i in range(BLOCK.BUILDINGS.size()):
  var building:Node3D=district.load_building(i)
  var door:Door=building.get_node(str(BLOCK.BUILDINGS[i].id)+"_door")
  var index:int=world._register_wildlife_blocker(building.global_position,9)
  world.wildlife_blockers[index]["door"]=door
  world.wildlife_blockers[index]["house_bounds"]=Rect2(Vector2(building.global_position.x-6,building.global_position.z-6),Vector2(12,12))
 if server:
  district.visible=false
 else:
  var streets:=preload("res://scripts/CityRoad.gd").new()
  streets.position=CENTER
  streets.road_width=7.0
  # Connect to the actual generated road end, not an assumed nominal boundary.
  streets.main_start=world._south_road_end()-CENTER.z
  world.add_child(streets)
  var decay:=preload("res://scripts/CityDecay.gd").new()
  decay.position=CENTER
  world.add_child(decay)
  _road_grass(world)
 return district

# Same verge grass as Main._create_road: tufts fading outward from both edges,
# queued into the shared grass MultiMesh batches before they flush.
static func _road_grass(world: Node3D) -> void:
 var rng: RandomNumberGenerator = world._world_rng
 var grass_base := Color(0.20,0.34,0.12)
 var color_var := Color(0.34,0.46,0.16)
 var grass_depth := 8.0
 var tuft_spacing := 0.25
 var edge := 3.4 # CityRoad road_width=7 -> half 3.5, minus the 4 cm deck lip
 # North-south strip: generated road end -> city south edge (z=720).
 for side in [-1,1]:
  var z0: float = world._south_road_end()
  var num := int((720.0-z0)/tuft_spacing)
  for i in range(num):
   var z := z0+(i+0.5)*tuft_spacing+rng.randf_range(-0.12,0.12)
   for j in range(5):
    var t: float = pow(rng.randf(),1.5)
    var pos := Vector3(CENTER.x+side*(edge+t*grass_depth),0.0,z)
    if world._is_near_river(pos,2.0): continue
    pos.y = world._get_exact_ground_y(pos.x,pos.z)+0.02
    world._queue_grass_instance(pos,rng.randf_range(0.15,0.35)*(1.0-t),rng.randf_range(0.18,0.38),grass_base.lerp(color_var,rng.randf()).darkened(rng.randf_range(0.0,0.12)))
 # Cross street through the block: x -31..49 at z=680, same treatment.
 for side in [-1,1]:
  var num := int(80.0/tuft_spacing)
  for i in range(num):
   var x := CENTER.x-40.0+(i+0.5)*tuft_spacing+rng.randf_range(-0.12,0.12)
   for j in range(5):
    var t: float = pow(rng.randf(),1.5)
    var pos := Vector3(x,0.0,CENTER.z+side*(edge+t*grass_depth))
    if world._is_near_river(pos,2.0): continue
    pos.y = world._get_exact_ground_y(pos.x,pos.z)+0.02
    world._queue_grass_instance(pos,rng.randf_range(0.15,0.35)*(1.0-t),rng.randf_range(0.18,0.38),grass_base.lerp(color_var,rng.randf()).darkened(rng.randf_range(0.0,0.12)))
