extends Node3D
## Deterministic dressing outside the clear walking/door/stair routes.
func _ready() -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 812
 var grass := SurfaceTool.new()
 grass.begin(Mesh.PRIMITIVE_TRIANGLES)
 for a in [0.0, PI/3, PI*2/3]:
  var side := Vector3(cos(a),0,sin(a))*.18
  for v in [-side,Vector3(.1,.8,0),side]: grass.set_color(Color(.23,.22,.14)); grass.add_vertex(v)
 grass.generate_normals()
 var mat := StandardMaterial3D.new()
 mat.vertex_color_use_as_albedo = true
 mat.cull_mode = BaseMaterial3D.CULL_DISABLED
 mat.roughness = 1
 grass.set_material(mat)
 var mm := MultiMesh.new()
 mm.transform_format = MultiMesh.TRANSFORM_3D
 mm.mesh = grass.commit()
 mm.instance_count = 420
 for i in range(420):
  var x := rng.randf_range(-34,34)
  var z := rng.randf_range(9.3,10.5) * (-1 if i%2 else 1)
  if absf(x)<10 or absf(absf(x)-16)<2: x=28+rng.randf_range(-2,3)
  var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(.3,1.2))
  mm.set_instance_transform(i,Transform3D(basis,Vector3(x,.11,z)))
 var clumps := MultiMeshInstance3D.new()
 clumps.multimesh = mm
 add_child(clumps)
 var stone := StandardMaterial3D.new()
 stone.albedo_color=Color(.27,.25,.22)
 var rubble := MultiMesh.new()
 rubble.transform_format=MultiMesh.TRANSFORM_3D
 var mesh := BoxMesh.new()
 mesh.size=Vector3(.4,.13,.25)
 mesh.material=stone
 rubble.mesh=mesh
 rubble.instance_count=110
 for i in range(110):
  var x := rng.randf_range(-31,31)
  if absf(x)<9 or absf(absf(x)-16)<2: x=30
  rubble.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(.4,1.8)),Vector3(x,.13,rng.randf_range(8,10.5)*(-1 if i%2 else 1))))
 var stones := MultiMeshInstance3D.new()
 stones.multimesh=rubble
 add_child(stones)
 for pos in [Vector3(-28,0,-27),Vector3(28,0,26),Vector3(-29,0,22),Vector3(28,0,-26)]:
  _branch(pos,pos+Vector3(.2,6,0),.16)
  var trunk := StaticBody3D.new()
  trunk.position = pos + Vector3(.1,3,.1)
  var trunk_shape := CollisionShape3D.new()
  var cylinder := CylinderShape3D.new()
  cylinder.radius=.16; cylinder.height=6
  trunk_shape.shape=cylinder
  trunk.add_child(trunk_shape)
  add_child(trunk)
  for j in range(8):
   var start: Vector3 = pos+Vector3(0,2.3+j*.45,0)
   var end: Vector3 = start+Vector3(cos(j*2.4)*2,1.2,sin(j*2.4)*2)
   _branch(start,end,.055)
   _branch(end,end+Vector3(.4,.9,.35),.021)

func _branch(a: Vector3,b: Vector3,radius: float) -> void:
 var mi := MeshInstance3D.new()
 var cylinder := CylinderMesh.new()
 cylinder.top_radius=radius*.3
 cylinder.bottom_radius=radius
 cylinder.height=a.distance_to(b)
 cylinder.radial_segments=6
 mi.mesh=cylinder
 var material := StandardMaterial3D.new()
 material.albedo_color=Color(.12,.10,.08)
 mi.material_override=material
 mi.position=(a+b)*.5
 mi.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
 add_child(mi)
