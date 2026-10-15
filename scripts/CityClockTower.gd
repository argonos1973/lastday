extends Node3D
const WORLD_POSITION := Vector3(41,0,750)
const FLOOR_HEIGHT := 4.2
const TOP_FLOOR := 29.4
var _hands:Array[Node3D]=[]
var _bases:Array[Basis]=[]
var _last_minute: int=-1
var time_source:Node

func _ready() -> void:
 var model:Node3D=load("res://assets/models/environment/city/clock_tower.glb").instantiate()
 add_child(model)
 for mi in model.find_children("*","MeshInstance3D",true,false):
  if str(mi.name).begins_with("Solid_") or str(mi.name).begins_with("Collision_"):
   mi.create_trimesh_collision()
  if str(mi.name).begins_with("Collision_"):
   mi.visible=false
   if str(mi.name).contains("StairRamp"):
    for body in mi.get_children():
     if body is StaticBody3D:body.add_to_group("stair_surface")
  else:
   _upgrade_tower_mesh_materials(mi)
 for kind in ["Hour","Minute"]:
  for face in range(4):
   var hand:Node3D=model.find_child("Clock%s_%d"%[kind,face],true,false)
   if hand!=null:
    _hands.append(hand);_bases.append(hand.basis)
    hand.set_meta("hour_hand",kind=="Hour")
 set_clock_time(12.0)

# Same local DayNightCycle the sky and HUD read, so all three always agree.
func _process(_delta:float) -> void:
 if not is_visible_in_tree():return
 if not is_instance_valid(time_source):time_source=get_parent().get("day_cycle") as Node
 var hour:float
 if is_instance_valid(time_source):
  hour=float(time_source.get("time_of_day"))
 else:
  var now:=Time.get_time_dict_from_system()
  hour=float(now.hour)+float(now.minute)/60.0+float(now.second)/3600.0
 var minute:int=int(fposmod(hour,24.0)*60.0)
 if minute!=_last_minute:
  _last_minute=minute
  set_clock_time(hour)

func set_clock_time(hour:float) -> void:
 for i in range(_hands.size()):
  var turns:float=fposmod(hour,12.0)/12.0 if _hands[i].get_meta("hour_hand") else fposmod(hour,1.0)
  _hands[i].basis=_bases[i]*Basis(Vector3(0,0,1),turns*TAU)

static func contains(pos:Vector3, margin:float=0.0) -> bool:
 var local:=pos-WORLD_POSITION
 return absf(local.x)<9+margin and absf(local.z)<8+margin and local.y>=-.2 and local.y<29.4

func _upgrade_tower_mesh_materials(mi: MeshInstance3D) -> void:
 if mi == null or mi.mesh == null:
  return
 var block_script := preload("res://scripts/CityBlock.gd")
 for s in range(mi.mesh.get_surface_count()):
  var smat := mi.mesh.surface_get_material(s)
  var mname := str(smat.resource_name).to_lower() if smat != null else ""
  if "aged_stone" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("stone", Color(0.76, 0.72, 0.64), 0.28, 1.40))
  elif "exposed_brick" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("brick", Color(0.72, 0.46, 0.36), 0.36, 1.45))
  elif "concrete" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("stone", Color(0.56, 0.55, 0.50), 0.35, 1.30))
  elif "old_oak" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("wood", Color(0.46, 0.32, 0.20), 0.40, 1.25))
  elif "verdigris" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("slate", Color(0.18, 0.34, 0.30), 0.45, 1.10, 0.65, 0.48))
  elif "clock_brass" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("stone", Color(0.85, 0.68, 0.32), 0.50, 0.60, 0.88, 0.28))
  elif "tower_iron" in mname:
   mi.set_surface_override_material(s, block_script._pbr_mat("stone", Color(0.16, 0.16, 0.15), 0.50, 0.85, 0.80, 0.40))
