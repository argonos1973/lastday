extends RefCounted
const ORIGIN := Vector3(9,0,680)
const CAR_POSITIONS := [Vector3(-7.5,0,-30),Vector3(7.5,0,35),Vector3(56.5,0,-30),Vector3(71.5,0,35),Vector3(-7.5,0,66),Vector3(7.5,0,125),Vector3(56.5,0,66),Vector3(71.5,0,125)]
const APOCALYPSE_KIT := "res://assets/external/quaternius_zombie_apocalypse/Environment/glTF/"
const STREET_LAMP_MODEL := "res://assets/models/environment/city/props/street_lamp_01.glb"
const BUS_STOP_MODEL := "res://assets/models/environment/city/props/bus_stop.glb"
const CITY_BENCH_MODEL := "res://assets/models/environment/city/props/city_bench.glb"
# Keep lamps on the broad transverse sidewalks, away from the parked cars and
# the narrow house entrances. Each instance shares the imported GLB resources.
const STREET_LAMP_OFFSETS := [
 Vector3(-30,0,-5), Vector3(28,0,5), Vector3(38,0,-5), Vector3(90,0,5),
 Vector3(-30,0,101), Vector3(28,0,91), Vector3(38,0,101), Vector3(90,0,91)
]

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
  var mname := str(mi.name)
  # Strip the primitive baked benches inside district_plaza.glb (one was facing
  # away from the fountain and both overlapped the PBR CityPlazaBench_2..3).
  if mname.begins_with("Solid_Bench"):
   mi.visible = false
   continue
  if mname.begins_with("Solid_"):
   mi.create_trimesh_collision()
 plaza.visible=not server
 var paving:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(20,18)
 paving.mesh=plane;paving.position=plaza.position+Vector3(0,.008,0);paving.visible=not server
 paving.material_override=_make_pavement_material(true);world.add_child(paving)
 _fountain(world,server,plaza.position)
 _pavements(world,server)
 _urban_details(world,server)
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

# Street furniture gives the residential grid a readable urban scale: full-size
# PBR lamps, traffic control at the two main crossings, and small abandoned
# service piles. Colliders are created on both hosts so traversal matches in MP.
static func _urban_details(world: Node3D, server: bool) -> void:
 for i in range(STREET_LAMP_OFFSETS.size()):
  var pos: Vector3 = ORIGIN + STREET_LAMP_OFFSETS[i]
  var name := "CityStreetLamp_%02d" % i
  world._create_invisible_collision_box(name + "Collision", pos, Vector3(.28,3.9,.28))
  world._register_wildlife_blocker(pos,0.5)
  if not server:
   world._try_instance_external_scene([STREET_LAMP_MODEL],name,pos,Vector3.ONE,Vector3(0,90.0 if i%2 else -90.0,0),true,0.0)

 # A small bus shelter anchors the eastern approach to the main crossing.
 # Rotated 180 deg so its open front and bench face the roadway (z=0) instead
 # of turning its back glass screen to the street.
 var stop_pos: Vector3 = ORIGIN + Vector3(40,0,5.2)
 world._create_invisible_collision_box("CityBusStopCollision",stop_pos,Vector3(3.8,2.5,1.6))
 world._register_wildlife_blocker(stop_pos,2.2)
 if not server:
  if world._try_instance_external_scene([BUS_STOP_MODEL],"CityBusStop",stop_pos,Vector3.ONE,Vector3(0,180.0,0),true,0.0):
   _weather_prop(world.get_node_or_null("CityBusStop"),Color(.38,.39,.33))

 # The benches face the fountain and keep a clear route around its basin.
 var bench_spots := [
  [Vector3(26,0,48),90.0], [Vector3(38,0,48),-90.0],
  [Vector3(32,0,42),0.0], [Vector3(32,0,54),180.0]
 ]
 for i in range(bench_spots.size()):
  var spot: Array = bench_spots[i]
  var pos: Vector3 = ORIGIN + spot[0]
  var name := "CityPlazaBench_%d" % i
  world._create_invisible_collision_box(name + "Collision",pos,Vector3(1.9,1.0,.75))
  world._register_wildlife_blocker(pos,1.0)
  if not server:
   if world._try_instance_external_scene([CITY_BENCH_MODEL],name,pos,Vector3.ONE,Vector3(0,float(spot[1]),0),true,0.0):
    _weather_prop(world.get_node_or_null(name),Color(.48,.45,.38))

 # The signals sit on the outer corners of the crossings, leaving the road
 # centre and pedestrian entrances clear.
 var signal_spots := [
  [Vector3(3.5,0,-4.3),180.0],
  [Vector3(67.5,0,91.7),0.0]
 ]
 for i in range(signal_spots.size()):
  var spot: Array = signal_spots[i]
  var pos: Vector3 = ORIGIN + spot[0]
  var name := "CityTrafficSignal_%d" % i
  world._create_invisible_collision_box(name + "Collision",pos,Vector3(.48,3.5,.48))
  world._register_wildlife_blocker(pos,0.5)
  if not server:
   world._try_instance_external_scene([APOCALYPSE_KIT + "TrafficLight_1.gltf"],name,pos,Vector3.ONE,Vector3(0,float(spot[1]),0),true,0.0)

 # A damaged town marker and refuse piles establish the outskirts without
 # filling the plaza or narrowing the sidewalks.
 var clutter := [
  ["TownSign.gltf",Vector3(-35,0,-34),Vector3.ONE,270.0,Vector3(.8,1.8,.5)],
  ["TrashBag_1.gltf",Vector3(-25,0,-8),Vector3.ONE,25.0,Vector3(.85,.75,.8)],
  ["TrashBag_2.gltf",Vector3(-24.3,0,-8.35),Vector3(.9,.9,.9),-12.0,Vector3(.85,.7,.8)],
  ["Pallet_Broken.gltf",Vector3(99,0,129),Vector3.ONE,18.0,Vector3(1.4,.35,1.1)],
  ["Barrel.gltf",Vector3(100.5,0,128.5),Vector3(.9,.9,.9),-8.0,Vector3(.65,1.0,.65)],
  ["TrashBag_1.gltf",Vector3(86,0,87),Vector3(.9,.9,.9),48.0,Vector3(.8,.7,.75)]
 ]
 for i in range(clutter.size()):
  var item: Array = clutter[i]
  var pos: Vector3 = ORIGIN + item[1]
  var name := "CityAbandonedProp_%02d" % i
  world._create_invisible_collision_box(name + "Collision",pos,item[4])
  world._register_wildlife_blocker(pos,maxf((item[4] as Vector3).x,(item[4] as Vector3).z)*0.5+0.3)
  if not server:
   world._try_instance_external_scene([APOCALYPSE_KIT + str(item[0])],name,pos,item[2],Vector3(0,float(item[3]),0),true,0.0)

static func _weather_prop(root: Node, tint: Color) -> void:
 if root == null:
  return
 var meshes: Array = root.find_children("*","MeshInstance3D",true,false)
 if root is MeshInstance3D:
  meshes.append(root)
 for mesh_node in meshes:
  var mesh_instance := mesh_node as MeshInstance3D
  if mesh_instance.mesh == null:
   continue
  for surface in range(mesh_instance.mesh.get_surface_count()):
   var source: Material = mesh_instance.get_active_material(surface)
   if source is StandardMaterial3D:
    var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
    material.albedo_color = material.albedo_color * tint
    material.roughness = maxf(material.roughness,.88)
    material.metallic = minf(material.metallic,.12)
    mesh_instance.set_surface_override_material(surface,material)

# The complete scanned stone fountain (octagonal basin, column and finial),
# recentred and stripped of its scanned paving by clean_fountain_scan.py.
# It stands directly on the plaza medallion; the baked 'FountainWater' sheet
# follows the real inner rim, so the basin reads full to just below the coping.
static func _fountain(world: Node3D, server: bool, center: Vector3) -> void:
 # The scan is ~1.8x2.3 m; 1.6x/1.4x scaling turns it into a monumental
 # plaza fountain (~2.9 m basin, ~3.3 m tall, rim ~1.2 m — still reachable).
 world._create_invisible_collision_box("DistrictFountainCollision",center,Vector3(3.0,.95,3.0))
 world._create_invisible_collision_box("DistrictFountainColumnCollision",center+Vector3(0,.95,0),Vector3(.9,2.4,.9))
 world._register_wildlife_blocker(center,2.0)
 var drink=world._create_world_action("district_fountain_drink","drink_water","Fuente de la plaza",center+Vector3(0,.9,0),Vector3(4.6,1.7,4.6),Color(0.08,0.22,0.48,0.0),true,false)
 if drink!=null:drink.set_meta("drink_source","de la fuente")
 if server:return
 var fountain: Node3D = load("res://assets/models/environment/city/district_fountain.glb").instantiate()
 fountain.name="DistrictFountain";fountain.position=center+Vector3(0,.03,0);fountain.scale=Vector3(1.6,1.4,1.6)
 world.add_child(fountain)
 var water:=fountain.find_child("FountainWater",true,false) as MeshInstance3D
 if water!=null:
  water.name="DistrictFountainWater"
  var wm:=StandardMaterial3D.new();wm.albedo_color=Color(.16,.22,.17,.86);wm.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
  wm.roughness=.06;wm.metallic_specular=.8;wm.cull_mode=BaseMaterial3D.CULL_DISABLED
  water.material_override=wm

static func _make_pavement_material(is_plaza: bool = false) -> ShaderMaterial:
 var sm := ShaderMaterial.new()
 var sh := Shader.new()
 sh.code = """
shader_type spatial;
uniform sampler2D concrete_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool is_plaza = false;
varying vec3 wpos;
varying vec3 lpos;
varying vec3 lnorm;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	vec2 uv_world = wpos.xz * 0.28;
	vec3 base_tex = texture(concrete_tex, uv_world).rgb;
	float grain = dot(base_tex, vec3(0.333));

	// Sidewalk slab grid (0.66m x 0.66m tiles with beveled mortar joints)
	float tile_sz = is_plaza ? 0.90 : 0.66;
	vec2 tile_uv = wpos.xz / tile_sz;
	vec2 tile_id = floor(tile_uv);
	vec2 f = fract(tile_uv);
	vec2 edge_d = min(f, 1.0 - f);
	float joint = 1.0 - smoothstep(0.018, 0.048, min(edge_d.x, edge_d.y));

	// Per-slab tone variation and weathered stain patches
	float slab_rnd = hash21(tile_id);
	vec3 slab_col = vec3(0.46, 0.45, 0.42) * (0.72 + grain * 0.58) * (0.91 + slab_rnd * 0.16);

	// Granite curbstone along vertical faces and outer 18 cm lip
	float is_side = 1.0 - smoothstep(0.45, 0.85, abs(lnorm.y));
	float curb_band = max(is_side, smoothstep(0.80, 0.96, max(abs(lpos.x), abs(lpos.z))));
	float curb_joint = 1.0 - smoothstep(0.015, 0.04, min(fract((wpos.x + wpos.z) * 0.85), 1.0 - fract((wpos.x + wpos.z) * 0.85)));
	vec3 curb_col = vec3(0.38, 0.37, 0.34) * (0.76 + grain * 0.50);
	curb_col = mix(curb_col, vec3(0.14, 0.13, 0.11), curb_joint * 0.65);

	vec3 col = mix(slab_col, curb_col, curb_band * (is_plaza ? 0.0 : 1.0));
	// Mortar joints and gutter grime at the base of the 12 cm curb
	col = mix(col, vec3(0.15, 0.16, 0.13), joint * (1.0 - curb_band * 0.7) * 0.72);
	float gutter_dirt = (1.0 - smoothstep(0.0, 0.055, lpos.y)) * is_side;
	col = mix(col, vec3(0.16, 0.18, 0.12), gutter_dirt * 0.68);

	float h = grain * 0.45 - joint * 0.35 - curb_joint * curb_band * 0.30;
	vec3 n_pert = normalize(vec3(-dFdx(h) * 2.8, 1.0, -dFdy(h) * 2.8));
	NORMAL = normalize(mix(NORMAL, n_pert, 0.45));

	ALBEDO = col;
	ROUGHNESS = clamp(0.90 - grain * 0.10 + joint * 0.06, 0.78, 0.97);
	SPECULAR = 0.22;
}
"""
 sm.shader = sh
 sm.set_shader_parameter("concrete_tex", load("res://assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg"))
 sm.set_shader_parameter("is_plaza", is_plaza)
 return sm

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
   if absf(z)<4 or absf(z-96)<4:continue
   for side in [-1,1]:placements.append(Transform3D(Basis.IDENTITY,ORIGIN+Vector3(x+side*5,0,z)))
 for z in [0.0,96.0]:
  for x in range(-40,104,2):
   if absf(x)<6 or absf(x-64)<6:continue
   for side in [-1,1]:placements.append(Transform3D(Basis(Vector3.UP,PI/2),ORIGIN+Vector3(x,0,z+side*5)))
 var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=mesh;mm.instance_count=placements.size()
 var faces:=PackedVector3Array();var base:=mesh.get_faces()
 for i in range(placements.size()):
  mm.set_instance_transform(i,placements[i])
  for vertex in base:faces.append(placements[i]*vertex)
 var visual:=MultiMeshInstance3D.new();visual.name="DistrictPavements";visual.multimesh=mm;visual.visible=not server
 if not server:
  visual.material_override=_make_pavement_material(false)
 world.add_child(visual)
 var body:=StaticBody3D.new();body.name="DistrictPavementCollision"
 var shape:=ConcavePolygonShape3D.new();shape.set_faces(faces)
 var collider:=CollisionShape3D.new();collider.shape=shape;body.add_child(collider);world.add_child(body)
 source.free()
