extends Node3D
## Pilot district: assets stream independently; door state outlives their nodes.
const BUILDINGS := [
 {"id":"city_01", "position":Vector3(-16,0,-17), "yaw":0.0, "label":"VIVIENDAS · 01"},
 {"id":"city_02", "position":Vector3(16,0,-17), "yaw":0.0, "label":"VIVIENDAS · 02"},
 {"id":"city_03", "position":Vector3(-16,0,17), "yaw":PI, "label":"VIVIENDAS · 03"},
 {"id":"city_04", "position":Vector3(16,0,17), "yaw":PI, "label":"VIVIENDAS · 04"},
]
const LOAD_DISTANCE := 100.0
const UNLOAD_DISTANCE := 135.0
var observer: Node3D
var buildings: Dictionary = {}
var door_states: Dictionary = {}
var _requested: Dictionary = {}
var _failed: Dictionary = {}
var _tick := 0.0

func _ready() -> void:
 if DisplayServer.get_name() == "headless": return
 for i in range(BUILDINGS.size()):
  var path := asset_path(i)
  ResourceLoader.load_threaded_request(path)
  _requested[i] = true

static func asset_path(i: int) -> String:
 return "res://assets/models/environment/city/building_%d.glb" % (i+1)

func _process(delta: float) -> void:
 if not is_instance_valid(observer): return
 _tick += delta
 if _tick < .15: return
 _tick = 0
 update_observer(to_local(observer.global_position))

func update_observer(local_position: Vector3) -> void:
 # At most one building instantiated per update; hysteresis avoids edge thrash.
 var loaded_one := false
 for i in range(BUILDINGS.size()):
  var distance: float = Vector2(local_position.x-BUILDINGS[i].position.x, local_position.z-BUILDINGS[i].position.z).length()
  if buildings.has(i):
   if distance > UNLOAD_DISTANCE: unload_building(i)
  elif distance < LOAD_DISTANCE and not loaded_one and not _failed.has(i):
   if not _requested.has(i) or ResourceLoader.load_threaded_get_status(asset_path(i)) == ResourceLoader.THREAD_LOAD_LOADED:
    load_building(i)
    loaded_one = true

func load_building(i: int) -> Node3D:
 if buildings.has(i): return buildings[i]
 var packed: PackedScene = ResourceLoader.load_threaded_get(asset_path(i)) if _requested.has(i) else load(asset_path(i))
 if packed == null:
  push_error("CityBlock: no se pudo cargar %s" % asset_path(i))
  _failed[i] = true
  return null
 var building: Node3D = packed.instantiate()
 building.name = BUILDINGS[i].id
 building.position = BUILDINGS[i].position
 building.rotation.y = BUILDINGS[i].yaw
 add_child(building)
 _collisions(building)
 var door := Door.new()
 door.name = str(BUILDINGS[i].id)+"_door"
 door.position = Vector3(-.85,.12,6.08)
 building.add_child(door)
 door.setup("Puerta de vivienda",Vector3(1.7,2.4,.12),Color.SADDLE_BROWN,-100)
 door.is_open = bool(door_states.get(str(door.name), false))
 door.rotation_degrees.y = door.open_yaw if door.is_open else door.closed_yaw
 var label := Label3D.new()
 label.text = BUILDINGS[i].label
 label.font_size = 38
 label.pixel_size = .009
 label.position = Vector3(0,2.88,6.19)
 label.modulate = Color(.85,.8,.62)
 building.add_child(label)
 buildings[i] = building
 return building

func _collisions(node: Node) -> void:
 if node is MeshInstance3D:
  var mesh_node := node as MeshInstance3D
  if str(node.name).begins_with("Solid_") or str(node.name).begins_with("Collision_"):
   mesh_node.create_trimesh_collision()
  if str(node.name).begins_with("Collision_"):
   mesh_node.visible = false
   if "StairRamp" in str(node.name):
    for body in mesh_node.get_children():
     if body is StaticBody3D: body.add_to_group("stair_surface")
 for child in node.get_children(): _collisions(child)

func unload_building(i: int) -> void:
 if not buildings.has(i): return
 var building: Node3D = buildings[i]
 var door: Door = building.get_node(str(BUILDINGS[i].id)+"_door")
 door_states[str(door.name)] = door.is_open
 remove_child(building)
 building.queue_free()
 buildings.erase(i)
