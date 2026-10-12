extends RefCounted
const CENTER := Vector3(9,0,680)
const SOUTH_LIMIT := 900.0
const ROAD_RING := Rect2(-40.0,-40.0,144.0,176.0) # local X/Z: world x=-31..113, z=640..816
const BLOCK := preload("res://scripts/CityBlock.gd")

static func reserves_terrain(pos: Vector3, radius: float = 0.0) -> bool:
 # An open southern pass, then the new district. Existing inner terrain remains.
 return pos.z+radius>440 and pos.z-radius<840 and pos.x+radius>-46 and pos.x-radius<130

static func near_building(pos: Vector3, margin: float) -> bool:
 if preload("res://scripts/CityClockTower.gd").contains(pos,margin):return true
 for definition in BLOCK.BUILDINGS:
  var offset: Vector3 = pos-CENTER-definition.position
  if absf(offset.x)<6+margin and absf(offset.z)<6+margin: return true
 return false

static func inside_building(pos: Vector3) -> bool:
 if preload("res://scripts/CityClockTower.gd").contains(pos):return true
 for definition in BLOCK.BUILDINGS:
  var offset: Vector3=pos-CENTER-definition.position
  if absf(offset.x)<5.85 and absf(offset.z)<5.85 and pos.y<7.9: return true
 return false

static func on_road(pos: Vector3, margin: float = 0.0, start_z: float = 500.0) -> bool:
 # start_z: world z where the generated main road actually ends (mesh continues from there).
 var local:=pos-CENTER
 # Perimeter loop around the district. Match the same local rectangle used by
 # CityRoad so traffic, vegetation, loot and AI see the rendered road as road.
 var ring_right:=ROAD_RING.position.x+ROAD_RING.size.x
 var ring_bottom:=ROAD_RING.position.y+ROAD_RING.size.y
 if local.z>=ROAD_RING.position.y-margin and local.z<=ring_bottom+margin and (absf(local.x-ROAD_RING.position.x)<=3.5+margin or absf(local.x-ring_right)<=3.5+margin):return true
 if local.x>=ROAD_RING.position.x-margin and local.x<=ring_right+margin and (absf(local.z-ROAD_RING.position.y)<=3.5+margin or absf(local.z-ring_bottom)<=3.5+margin):return true
 for x in [0.0,64.0]:
  var z_begin := start_z-CENTER.z if x==0.0 else -40.0
  if absf(local.x-x)<3.5+margin and local.z>=z_begin-margin and local.z<=136+margin: return true
 for z in [0.0,96.0]:
  if absf(local.z-z)<3.5+margin and local.x>=-40-margin and local.x<=104+margin: return true
 return false

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
 preload("res://scripts/CityStreetscape.gd").create(world, server)
 if server:
  district.visible=false
 else:
  var streets:=preload("res://scripts/CityRoad.gd").new()
  streets.position=CENTER
  streets.road_width=7.0
  streets.expanded=true
  streets.perimeter_enabled=true
  # Connect to the actual generated road end, not an assumed nominal boundary.
  streets.main_start=world._south_road_end()-CENTER.z
  world.add_child(streets)
  var decay:=preload("res://scripts/CityDecay.gd").new()
  decay.position=CENTER
  world.add_child(decay)
  _ford(world)
  _road_grass(world)
  # Cars and plaza are shared with dedicated-server collision setup.
 return district

# The road crosses the river where the old bridge used to be: the carriageway
# dips under the waterline as a flooded ford. A worn gravel apron fades over
# the asphalt into both banks and shore stones mark each waterline, so the
# crossing reads as a natural ford instead of a road ending in water.
static func _ford(world: Node3D) -> void:
 if world.river_segments_data.is_empty() or world._road_segments.is_empty():
  return
 var z := 340.0
 var wet0 := -1.0
 var wet1 := -1.0
 while z < 460.0:
  if world.get_river_depth_at(Vector3(CENTER.x,0.0,z)) > 0.0:
   if wet0 < 0.0: wet0 = z
   wet1 = z
  z += 0.5
 if wet0 < 0.0:
  return
 var rng: RandomNumberGenerator = world._world_rng
 var z0 := wet0 - 6.0
 var z1 := wet1 + 6.0
 var rows := 24
 var cols := 4
 var half_w := 4.8
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for iz in range(rows + 1):
  var t := float(iz) / rows
  var zz := lerpf(z0, z1, t)
  var z_fade := smoothstep(0.0, 0.22, t) * smoothstep(1.0, 0.78, t)
  for ix in range(cols + 1):
   var u := float(ix) / cols
   var xx := CENTER.x + (u - 0.5) * half_w * 2.0
   var x_fade := smoothstep(0.0, 0.18, u) * smoothstep(1.0, 0.82, u)
   var yy: float = float(world._get_exact_ground_y(xx, zz)) + 0.055
   st.set_color(Color(1, 1, 1, 0.92 * z_fade * x_fade))
   st.set_uv(Vector2(u * half_w * 2.0 / 4.5, zz / 4.5))
   st.set_normal(Vector3.UP)
   st.add_vertex(Vector3(xx, yy, zz))
 for iz in range(rows):
  for ix in range(cols):
   var a := iz * (cols + 1) + ix
   var b := (iz + 1) * (cols + 1) + ix
   st.add_index(a); st.add_index(a + 1); st.add_index(b)
   st.add_index(a + 1); st.add_index(b + 1); st.add_index(b)
 var mi := MeshInstance3D.new()
 mi.name = "FordGravel"
 mi.mesh = st.commit()
 mi.material_override = world._get_shore_band_material()
 world.add_child(mi)
 for zw in [wet0 + 0.4, wet1 - 0.4]:
  for k in range(7):
   var xx := CENTER.x + rng.randf_range(-5.5, 5.5)
   var zz: float = zw + rng.randf_range(-1.2, 1.2)
   var pos := Vector3(xx, 0.0, zz)
   pos.y = world._get_exact_ground_y(xx, zz) + 0.02
   if rng.randf() < 0.5:
    world._try_instance_external_scene(NodeUtils.shuffled_paths(world.SHORE_PEBBLES, rng), "ShorePebblePatch", pos, Vector3.ONE * rng.randf_range(0.55, 1.0), Vector3(0, rng.randf_range(0, 360), 0), false, 0.0)
   else:
    world._try_instance_external_scene(NodeUtils.shuffled_paths(world.SHORE_FLATSTONES, rng), "FordStone", pos, Vector3.ONE * rng.randf_range(0.45, 0.9), Vector3(0, rng.randf_range(0, 360), 0), false, 0.0)

# Same verge grass as Main._create_road: tufts fading outward from both edges,
# queued into the shared grass MultiMesh batches before they flush.
static func _road_grass(world: Node3D) -> void:
 var rng: RandomNumberGenerator = world._world_rng
 var grass_base := Color(0.20,0.34,0.12)
 var color_var := Color(0.34,0.46,0.16)
 var grass_depth := 8.0
 var tuft_spacing := 0.25
 var edge := 3.4 # CityRoad road_width=7 -> half 3.5, minus the 4 cm deck lip
 # Rural approach: deep verges until the pavements begin (local z=-40 -> world 640).
 for side in [-1,1]:
  var z0: float = world._south_road_end()
  var num := int((640.0-z0)/tuft_spacing)
  for i in range(num):
   var z := z0+(i+0.5)*tuft_spacing+rng.randf_range(-0.12,0.12)
   for j in range(5):
    var t: float = pow(rng.randf(),1.5)
    var pos := Vector3(CENTER.x+side*(edge+t*grass_depth),0.0,z)
    if world._is_near_river(pos,2.0): continue
    pos.y = world._get_exact_ground_y(pos.x,pos.z)+0.02
    world._queue_grass_instance(pos,rng.randf_range(0.15,0.35)*(1.0-t),rng.randf_range(0.18,0.38),grass_base.lerp(color_var,rng.randf()).darkened(rng.randf_range(0.0,0.12)))
 # District streets: shallow tufts in the verge between pavement and facades.
 _verge_grass(world,rng,grass_base,color_var)

static func _verge_grass(world: Node3D, rng: RandomNumberGenerator, base: Color, varc: Color) -> void:
 var spacing := 0.25
 for xc in [0.0,64.0]: # avenues run along z, local z -40..136
  for i in range(int(176.0/spacing)):
   var lz := -40.0+(i+0.5)*spacing+rng.randf_range(-0.12,0.12)
   for side in [-1,1]:
    for j in range(3):
     var t := pow(rng.randf(),1.5)
     _verge_tuft(world,rng,Vector3(CENTER.x+xc+side*(6.4+t*2.2),0.0,CENTER.z+lz),base,varc,t)
 for zc in [0.0,96.0]: # cross streets run along x, local x -40..104
  for i in range(int(144.0/spacing)):
   var lx := -40.0+(i+0.5)*spacing+rng.randf_range(-0.12,0.12)
   for side in [-1,1]:
    for j in range(3):
     var t := pow(rng.randf(),1.5)
     _verge_tuft(world,rng,Vector3(CENTER.x+lx,0.0,CENTER.z+zc+side*(6.4+t*2.2)),base,varc,t)

static func _verge_tuft(world: Node3D, rng: RandomNumberGenerator, pos: Vector3, base: Color, varc: Color, t: float) -> void:
 var streetscape := preload("res://scripts/CityStreetscape.gd")
 if streetscape.on_pavement(pos,0.0) or near_building(pos,0.4) or world._is_near_river(pos,2.0): return
 for car in streetscape.CAR_POSITIONS:
  if Vector2(pos.x,pos.z).distance_squared_to(Vector2(streetscape.ORIGIN.x+car.x,streetscape.ORIGIN.z+car.z))<6.8: return
 pos.y = world._get_exact_ground_y(pos.x,pos.z)+0.02
 world._queue_grass_instance(pos,rng.randf_range(0.15,0.35)*(1.0-t),rng.randf_range(0.18,0.38),base.lerp(varc,rng.randf()).darkened(rng.randf_range(0.0,0.12)))
