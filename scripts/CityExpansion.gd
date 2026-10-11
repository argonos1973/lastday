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
 world.add_child(deck);deck.visible=not server
 # Collision as three boxes following the deck profile — a trimesh rim snags
 # the capsule at the bridge ends; the up-ramp reaches ground level so entry
 # is flush.
 var ramp_deg:=rad_to_deg(atan(0.05))
 for seg in [{"z":341.0,"top":.35,"tilt":-ramp_deg},{"z":380.0,"top":.65,"tilt":0.0},{"z":419.0,"top":.35,"tilt":ramp_deg}]:
  var col:=StaticBody3D.new()
  var cs:=CollisionShape3D.new();var bs:=BoxShape3D.new()
  var half_len:=17.5
  bs.size=Vector3(7.0,1.0,half_len*2.0);cs.shape=bs
  col.position=Vector3(9,seg["top"]-.5,seg["z"]);col.rotation_degrees.x=seg["tilt"]
  col.add_child(cs);world.add_child(col)
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
 _bridge_details(world, server)

static func _bridge_details(world: Node3D, server: bool) -> void:
 if server: return # dressing only; deck+rails already carry the collision
 var concrete:=StandardMaterial3D.new();concrete.albedo_color=Color(.34,.33,.29);concrete.roughness=.92
 var dark:=StandardMaterial3D.new();dark.albedo_color=Color(.20,.19,.17);dark.roughness=.98
 # Parapet cap beam and posts — the flat rail boxes read as solid pretil.
 var concrete_tex:=load("res://assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg")
 if concrete_tex != null: concrete.albedo_texture=concrete_tex;concrete.uv1_scale=Vector3(.5,.5,.5)
 for x in [5.35,12.65]:
  var cap:=MeshInstance3D.new();var cb:=BoxMesh.new();cb.size=Vector3(.34,.16,62.4);cap.mesh=cb
  cap.position=Vector3(x,1.55,380);cap.material_override=concrete;world.add_child(cap)
  for i in range(16):
   var post:=MeshInstance3D.new();var pb:=BoxMesh.new();pb.size=Vector3(.3,.5,.24);post.mesh=pb
   post.position=Vector3(x,1.62,350.5+i*4.0);post.material_override=concrete;world.add_child(post)
  # Edge fascia beam under the deck, visible from the water line.
  var fascia:=MeshInstance3D.new();var fb:=BoxMesh.new();fb.size=Vector3(.22,.42,90);fascia.mesh=fb
  fascia.position=Vector3(x+(.02 if x<9 else -.02),.38,380);fascia.material_override=dark;world.add_child(fascia)
 # Support piers down to the riverbed (visual; water already blocks traversal).
 for z in [356,380,404]:
  for x in [6.3,11.7]:
   var pier:=MeshInstance3D.new();var cyl:=CylinderMesh.new()
   cyl.top_radius=.34;cyl.bottom_radius=.42;cyl.height=3.0;cyl.radial_segments=10;pier.mesh=cyl
   pier.position=Vector3(x,bridge_height(z)-1.6,z);pier.material_override=dark;world.add_child(pier)
  var beam:=MeshInstance3D.new();var bb:=BoxMesh.new();bb.size=Vector3(7.6,.3,1.0);beam.mesh=bb
  beam.position=Vector3(9,bridge_height(z)-.3,z);beam.material_override=dark;world.add_child(beam)
 # Abutments: stone blocks the deck dies into on both banks.
 for z in [334.2,425.8]:
  var abut:=MeshInstance3D.new();var ab:=BoxMesh.new();ab.size=Vector3(8.6,1.5,1.8);abut.mesh=ab
  abut.position=Vector3(9,.0,z);abut.material_override=concrete;world.add_child(abut)
