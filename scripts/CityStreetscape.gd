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
