extends RefCounted
const ORIGIN := Vector3(9,0,680)
const CAR_POSITIONS := [Vector3(-7.5,0,-30),Vector3(7.5,0,35),Vector3(56.5,0,-30),Vector3(71.5,0,35),Vector3(-7.5,0,66),Vector3(7.5,0,125),Vector3(56.5,0,66),Vector3(71.5,0,125)]

# Pavement modules sit 4..6 m off each street centre; a 6.2 half-band also
# covers the asphalt so verge dressing can simply skip the whole corridor.
static func on_pavement(pos: Vector3, margin: float = 0.0) -> bool:
 var local := pos - ORIGIN
 for x in [0.0,64.0]:
  if absf(local.x-x)<6.2+margin and local.z>-40.0-margin and local.z<136.0+margin: return true
 for z in [0.0,96.0]:
  if absf(local.z-z)<6.2+margin and local.x>-40.0-margin and local.x<104.0+margin: return true
 return false

static func tree_positions() -> Array[Vector3]:
 var result: Array[Vector3] = []
 for x in [0.0,64.0]:
  for z in range(-36,134,9):
   if absf(z)<10 or absf(z-96)<10: continue
   for side in [-1,1]: result.append(ORIGIN+Vector3(x+side*9,0,z))
 return result

static func create(world: Node3D, server: bool) -> void:
 var tower:=preload("res://scripts/CityClockTower.gd").new()
 tower.name="CityClockTower";tower.position=tower.WORLD_POSITION
 world.add_child(tower);tower.visible=not server
 world._register_wildlife_blocker(tower.position,12.0)

 var plaza: Node3D = load("res://assets/models/environment/city/district_plaza.glb").instantiate()
 plaza.name="DistrictPlaza";plaza.position=ORIGIN+Vector3(32,0,48)
 world.add_child(plaza)
 for mi in plaza.find_children("*","MeshInstance3D",true,false):
  if str(mi.name).begins_with("Solid_"): mi.create_trimesh_collision()
 plaza.visible=not server
 var paving:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,18)
 paving.mesh=plane;paving.position=plaza.position+Vector3(0,.008,0);paving.visible=not server
 var material:=StandardMaterial3D.new();material.albedo_texture=load("res://assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg");material.uv1_scale=Vector3(8,8,8);material.roughness=.95
 paving.material_override=material;world.add_child(paving)
 _fountain(world,server,plaza.position)
 _pavements(world,server)
 for i in range(CAR_POSITIONS.size()):
  var pos: Vector3=ORIGIN+CAR_POSITIONS[i]
  var name: String="DistrictParkedCar%d"%i
  var paths: Array=[world.ABANDONED_JUNK_CAR_MODEL] if i%2==0 else [world.SCRAP_BARRICADE_CAR_MODEL]
  var factor: float=2.0 if i%2==0 else .5
  var yaw: float=0.0 if i%2==0 else 180.0
  # Both hosts and clients receive the same solid footprint.
  world._create_invisible_collision_box_rotated(name+"Collision",pos+Vector3(0,.8,0),Vector3(2,1.6,4.2),yaw)
  world._register_wildlife_blocker(pos,2.4)
  if not server:
   world._try_instance_external_scene(paths,name,pos,Vector3.ONE*factor,Vector3(0,yaw,0),true,0.0)
   var car:Node3D=world.get_node_or_null(name)
   if car!=null:
    world._disable_emission_recursive(car)
    if i%2:car.position.y+=world.SCRAP_CAR_Y_CORRECTION

# Scanned octagonal stone bowl (clean_fountain_scan.py drops the museum stand
# and detached urn shells), carried on a generated plinth and pedestal, full
# of stagnant water. A short broken spout just reaches the surface.
static func _fountain(world: Node3D, server: bool, center: Vector3) -> void:
 world._create_invisible_collision_box("DistrictFountainCollision",center,Vector3(2.5,1.2,2.5))
 world._register_wildlife_blocker(center,1.6)
 if server:return
 var stone:=StandardMaterial3D.new()
 stone.albedo_texture=load("res://assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg")
 stone.uv1_scale=Vector3(3,3,3);stone.roughness=.95
 var plinth:=MeshInstance3D.new();plinth.name="DistrictFountainPlinth"
 var plinth_box:=BoxMesh.new();plinth_box.size=Vector3(1.5,.14,1.5);plinth.mesh=plinth_box
 plinth.position=center+Vector3(0,.10,0);plinth.material_override=stone;world.add_child(plinth)
 var pedestal:=MeshInstance3D.new();pedestal.name="DistrictFountainPedestal"
 var column:=CylinderMesh.new();column.top_radius=.38;column.bottom_radius=.5;column.height=.30;column.radial_segments=8
 pedestal.mesh=column;pedestal.rotation.y=PI/8
 pedestal.position=center+Vector3(0,.32,0);pedestal.material_override=stone;world.add_child(pedestal)
 var fountain: Node3D = load("res://assets/models/environment/city/district_fountain.glb").instantiate()
 fountain.name="DistrictFountain"
 var box:=_node_aabb(fountain)
 var bowl_center:=box.position+box.size*.5 # scanned bowl is off-centre in its node
 fountain.position=center+Vector3(-bowl_center.x,.45-box.position.y,-bowl_center.z)
 world.add_child(fountain)
 var water:=MeshInstance3D.new();water.name="DistrictFountainWater"
 var disc:=CylinderMesh.new();disc.top_radius=.78;disc.bottom_radius=.78;disc.height=.02;disc.radial_segments=8
 water.mesh=disc;water.rotation.y=PI/8;water.position=center+Vector3(0,.95,0)
 var wm:=StandardMaterial3D.new();wm.albedo_color=Color(.13,.19,.12,.82);wm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 wm.roughness=.08;wm.metallic=.3;wm.cull_mode=BaseMaterial3D.CULL_DISABLED
 water.material_override=wm;world.add_child(water)
 var spout:=MeshInstance3D.new();spout.name="DistrictFountainSpout"
 var stem:=CylinderMesh.new();stem.top_radius=.10;stem.bottom_radius=.16;stem.height=.55;stem.radial_segments=8
 spout.mesh=stem;spout.rotation.y=PI/8;spout.position=center+Vector3(0,.72,0);spout.material_override=stone;world.add_child(spout)
 var cap:=MeshInstance3D.new();cap.name="DistrictFountainSpoutCap"
 var cap_box:=BoxMesh.new();cap_box.size=Vector3(.26,.06,.26);cap.mesh=cap_box
 cap.position=center+Vector3(0,.98,0);cap.material_override=stone;world.add_child(cap)

static func _node_aabb(n: Node) -> AABB:
 var box:=AABB();var first:=true;var stack:Array=[n]
 while not stack.is_empty():
  var cur: Node=stack.pop_back()
  if cur is MeshInstance3D:
   var a: AABB=cur.transform*cur.get_aabb()
   if first:box=a;first=false
   else:box=box.merge(a)
  stack.append_array(cur.get_children())
 return box

static func _pavements(world: Node3D, server: bool) -> void:
 var source:Node3D=load("res://assets/models/environment/city/district_pavement.glb").instantiate()
 var mi:MeshInstance3D=source as MeshInstance3D
 if mi==null:
  var meshes:=source.find_children("*","MeshInstance3D",true,false)
  if meshes.is_empty():
   source.free()
   return
  mi=meshes[0]
 var mesh:Mesh=mi.mesh
 var placements:Array[Transform3D]=[]
 for x in [0.0,64.0]:
  for z in range(-40,136,2):
   if absf(z)<6 or absf(z-96)<6:continue
   for side in [-1,1]:placements.append(Transform3D(Basis.IDENTITY,ORIGIN+Vector3(x+side*5,0,z)))
 for z in [0.0,96.0]:
  for x in range(-40,104,2):
   if absf(x)<7 or absf(x-64)<7:continue
   for side in [-1,1]:placements.append(Transform3D(Basis(Vector3.UP,PI/2),ORIGIN+Vector3(x,0,z+side*5)))
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=placements.size()
 var faces:=PackedVector3Array();var base:=mesh.get_faces()
 for i in range(placements.size()):
  mm.set_instance_transform(i,placements[i])
  for vertex in base:faces.append(placements[i]*vertex)
 var visual:=MultiMeshInstance3D.new();visual.name="DistrictPavements";visual.multimesh=mm;visual.visible=not server;world.add_child(visual)
 var body:=StaticBody3D.new();body.name="DistrictPavementCollision"
 var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces)
 var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);world.add_child(body)
 source.free()
