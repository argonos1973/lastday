extends Node3D
## Same asphalt, aggregate and metric UV convention as Main._create_road.
## Outer columns and open ends slope down to ground level so the 4 cm deck
## edge is a walkable ramp instead of a knife edge that snags the capsule.
var road_width := 10.0
var main_start := -40.0
var expanded := false
var _offset := Vector3.ZERO
func _ready() -> void:
 var material := ShaderMaterial.new()
 material.shader = preload("res://scripts/road_surface.gdshader")
 material.set_shader_parameter("aggregate",load("res://assets/textures/dirt_road/Ground038_1K-JPG_Color.jpg"))
 if expanded:
  for x in [0.0,64.0]:
   _offset=Vector3(x,0,0)
   _strip(main_start if x==0.0 else -40.0,136,false,material)
  for z in [0.0,96.0]:
   _offset=Vector3(0,0,z)
   for span in [Vector2(-40,-3.5),Vector2(3.5,60.5),Vector2(67.5,104)]:
    _strip(span.x,span.y,true,material)
 else:
  _strip(main_start,40,false,material,true,true,-4.6,4.6)
  _strip(-40,-road_width*.5,true,material,true,false)
  _strip(road_width*.5,40,true,material,false,true)

func _strip(start: float, finish: float, sideways: bool, material: Material, skirt_start := true, skirt_end := true, flat_from := 1e9, flat_to := -1e9) -> void:
 var st := SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var rows := int(ceil(finish-start))
 var cols := 13
 for row in range(-1,rows+2):
  var end_row := row == -1 or row == rows+1
  var along := lerpf(start-.35,finish+.35,float(row+1)/float(rows+2)) if end_row else lerpf(start,finish,float(row)/rows)
  var end_skirt := end_row and (skirt_start if row == -1 else skirt_end)
  var side_flat := along >= flat_from and along <= flat_to
  for col in range(cols):
   var edge := col == 0 or col == cols-1
   var across := (road_width/2.0+.35)*(-1.0 if col==0 else 1.0) if edge else (float(col-1)/10.0-.5)*road_width
   var height := .0 if end_skirt or (edge and not side_flat) else .04
   var point := Vector3(along,height,across) if sideways else Vector3(across,height,along)
   point += _offset
   st.set_uv(Vector2(point.x+global_position.x,point.z+global_position.z)*.5)
   st.set_uv2(Vector2(clampf(across/(road_width*.5),-1,1),along+(global_position.x if sideways else global_position.z)))
   st.add_vertex(point)
 var total_rows := rows+2
 for row in range(total_rows):
  for col in range(cols-1):
   var world := get_tree().current_scene
   var along := lerpf(start,finish,clampf(float(row)/maxf(1,rows),0,1))
   var across := (float(col)/float(cols-1)-.5)*road_width
   var sample := to_global(_offset + (Vector3(along,0,across) if sideways else Vector3(across,0,along)))
   if world != null and world.has_method("get_river_depth_at") and float(world.get_river_depth_at(sample))>0.0: continue
   var a := row*cols+col
   var indices := [a,a+cols,a+1,a+1,a+cols,a+cols+1] if not sideways else [a,a+1,a+cols,a+1,a+cols+1,a+cols]
   for index in indices: st.add_index(index)
 st.generate_normals()
 var instance := MeshInstance3D.new()
 instance.mesh=st.commit()
 instance.material_override=material
 instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(instance)
 # Flush-top collider: trimesh edges snag the player capsule, so the walkable
 # surface is a box ending at ground level — the deck's 4 cm are cosmetic.
 var body := StaticBody3D.new()
 var cs := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 var len := finish-start
 if sideways:
  shape.size=Vector3(len,.4,road_width+.7); body.position=Vector3((start+finish)/2.0,-.2,0)
 else:
  shape.size=Vector3(road_width+.7,.4,len); body.position=Vector3(0,-.2,(start+finish)/2.0)
 body.position += _offset
 cs.shape=shape
 body.add_child(cs)
 add_child(body)
