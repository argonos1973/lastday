extends RefCounted
const CENTER := Vector3(9,0,680)
const SOUTH_LIMIT := 900.0
const BLOCK := preload("res://scripts/CityBlock.gd")

static func reserves_terrain(pos: Vector3, radius: float = 0.0) -> bool:
 # An open southern pass, then the new district. Existing inner terrain remains.
 return pos.z+radius>440 and pos.z-radius<760 and absf(pos.x-CENTER.x)<radius+55

static func near_building(pos: Vector3, margin: float) -> bool:
 for definition in BLOCK.BUILDINGS:
  var offset: Vector3 = pos-CENTER-definition.position
  if absf(offset.x)<6+margin and absf(offset.z)<6+margin: return true
 return false

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
  _ford(world)
  _road_grass(world)
  _cars(world)
 return district

# Abandoned cars on the new road and the cross street, same client-only
# pattern as _create_new_world_props (visual + local collision box).
static func _cars(world: Node3D) -> void:
 var space_state: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
 var specs := [
  {"name":"CityJunkCar0","pos":Vector3(10.5,0.0,555.0),"scale":Vector3.ONE*2.0,"rot":Vector3(0,35,0),"coll":Vector3(2.0,2.0,4.0),"paths":[world.ABANDONED_JUNK_CAR_MODEL],"fix":0.0},
  {"name":"CityJunkCar1","pos":Vector3(7.2,0.0,646.0),"scale":Vector3.ONE*2.0,"rot":Vector3(0,-58,0),"coll":Vector3(2.0,2.0,4.0),"paths":[world.ABANDONED_JUNK_CAR_MODEL],"fix":0.0},
  {"name":"CityScrapCar","pos":Vector3(24.0,0.0,681.5),"scale":Vector3.ONE*0.5,"rot":Vector3(0,82,0),"coll":Vector3(2.0,2.5,4.0),"paths":[world.SCRAP_BARRICADE_CAR_MODEL],"fix":world.SCRAP_CAR_Y_CORRECTION},
 ]
 for spec in specs:
  var pos: Vector3 = spec["pos"]
  var ground_y: float = NodeUtils.raycast_ground_y(space_state,pos)
  if not world._try_instance_external_scene(spec["paths"],spec["name"],pos,spec["scale"],spec["rot"],true,ground_y):
   continue
  var node := world.get_node_or_null(spec["name"])
  var coll_pos := pos
  if node is Node3D:
   (node as Node3D).force_update_transform()
   (node as Node3D).position.y += float(spec["fix"])
   coll_pos = Vector3(pos.x,(node as Node3D).position.y,pos.z)
   world._disable_emission_recursive(node)
  world._create_invisible_collision_box_rotated(str(spec["name"])+"Collision",coll_pos,spec["coll"],float(spec["rot"].y))
  var coll := world.get_node_or_null(str(spec["name"])+"Collision")
  if coll != null: coll.add_to_group("prop_collision")

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
