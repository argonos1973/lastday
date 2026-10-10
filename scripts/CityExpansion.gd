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
  if absf(offset.x)<5.85 and absf(offset.z)<5.85 and pos.y<6.4: return true
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
 _bridge(world, server)
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
 return district

static func bridge_height(z: float) -> float:
 return .05+minf(clampf((z-335.0)/12.0,0,1),clampf((425.0-z)/12.0,0,1))*.60

static func above_bridge(pos: Vector3) -> bool:
 return absf(pos.x-9.0)<3.5 and pos.z>335 and pos.z<425 and pos.y>=bridge_height(pos.z)-.12

static func _bridge(world: Node3D, server: bool) -> void:
 var material:=ShaderMaterial.new()
 material.shader=preload("res://scripts/road_surface.gdshader")
 material.set_shader_parameter("aggregate",load("res://assets/textures/dirt_road/Ground038_1K-JPG_Color.jpg"))
 var st:=SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in range(335,426):
  for x in [5.5,12.5]:
   st.set_uv(Vector2(x,z)*.5)
   st.set_uv2(Vector2((x-9)/3.5,z))
   st.add_vertex(Vector3(x,bridge_height(z),z))
 for row in range(90):
  var a:=row*2
  for index in [a,a+2,a+1,a+1,a+2,a+3]:st.add_index(index)
 st.generate_normals()
 var deck:=MeshInstance3D.new()
 deck.name="SouthRiverBridge"
 deck.mesh=st.commit();deck.material_override=material
 world.add_child(deck);deck.create_trimesh_collision();deck.visible=not server
 for x in [5.35,12.65]:
  var rail:=StaticBody3D.new()
  rail.position=Vector3(x,1.05,380)
  var shape:=BoxShape3D.new();shape.size=Vector3(.18,.85,62)
  var collision:=CollisionShape3D.new();collision.shape=shape;rail.add_child(collision)
  world.add_child(rail)
  if not server:
   var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=shape.size;mesh.mesh=box
   var concrete:=StandardMaterial3D.new();concrete.albedo_color=Color(.29,.28,.25);concrete.roughness=.95
   mesh.material_override=concrete;rail.add_child(mesh)
