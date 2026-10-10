extends Node3D
## Same asphalt, aggregate and metric UV convention as Main._create_road.
var road_width := 10.0
var main_start := -40.0
func _ready() -> void:
 var material := ShaderMaterial.new()
 material.shader = preload("res://scripts/road_surface.gdshader")
 material.set_shader_parameter("aggregate",load("res://assets/textures/dirt_road/Ground038_1K-JPG_Color.jpg"))
 _strip(main_start,40,false,material)
 _strip(-40,-road_width*.5,true,material)
 _strip(road_width*.5,40,true,material)

func _strip(start: float, finish: float, sideways: bool, material: Material) -> void:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows := int(ceil(finish-start))
 for row in range(rows+1):
  var along := lerpf(start,finish,float(row)/rows)
  for col in range(11):
   var across := (float(col)/10.0-.5)*road_width
   var point := Vector3(along,.04,across) if sideways else Vector3(across,.04,along)
   st.set_uv(Vector2(point.x+global_position.x,point.z+global_position.z)*.5)
   st.set_uv2(Vector2(across/(road_width*.5),along+(global_position.x if sideways else global_position.z)))
   st.add_vertex(point)
 for row in range(rows):
  for col in range(10):
   var a := row*11+col
   var indices := [a,a+11,a+1,a+1,a+11,a+12] if not sideways else [a,a+1,a+11,a+1,a+12,a+11]
   for index in indices: st.add_index(index)
 st.generate_normals()
 var instance := MeshInstance3D.new()
 instance.mesh=st.commit()
 instance.material_override=material
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(instance)
 instance.create_trimesh_collision()
