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
   for body in mi.get_children():
    if body is StaticBody3D:body.add_to_group("stair_surface")
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
