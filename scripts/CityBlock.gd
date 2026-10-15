extends Node3D
## Pilot district: assets stream independently; door state outlives their nodes.
const BUILDINGS := [
 {"id":"city_01", "position":Vector3(-16,0,-17), "yaw":0.0},
 {"id":"city_02", "position":Vector3(16,0,-17), "yaw":0.0},
 {"id":"city_03", "position":Vector3(-16,0,17), "yaw":PI},
 {"id":"city_04", "position":Vector3(16,0,17), "yaw":PI},
 {"id":"city_05", "position":Vector3(48,0,-17), "yaw":0.0},
 {"id":"city_06", "position":Vector3(80,0,-17), "yaw":0.0},
 {"id":"city_07", "position":Vector3(48,0,17), "yaw":PI},
 {"id":"city_08", "position":Vector3(80,0,17), "yaw":PI},
 {"id":"city_09", "position":Vector3(-16,0,79), "yaw":0.0},
 {"id":"city_10", "position":Vector3(16,0,79), "yaw":0.0},
 {"id":"city_11", "position":Vector3(-16,0,113), "yaw":PI},
 {"id":"city_12", "position":Vector3(16,0,113), "yaw":PI},
 {"id":"city_13", "position":Vector3(48,0,79), "yaw":0.0},
 {"id":"city_14", "position":Vector3(80,0,79), "yaw":0.0},
 {"id":"city_15", "position":Vector3(48,0,113), "yaw":PI},
 {"id":"city_16", "position":Vector3(80,0,113), "yaw":PI},
 {"id":"city_17", "position":Vector3(117,0,48), "yaw":-PI/2.0,
  "asset":"res://assets/models/environment/city/building_highrise_1.glb",
  "floors":4, "interior_height":15.6, "footprint":Vector2(6.4,6.4),
  "loot_floor_values":[.16,4.02,7.92,11.82],
  "door_position":Vector3(-1.35,.02,6.08), "door_size":Vector3(2.7,3.1,.12), "door_label":"Puerta del bloque"},
]
const LOAD_DISTANCE := 100.0
const UNLOAD_DISTANCE := 135.0
## Interior kit (tools/blender/create_city_interior_kit.py): village-house props
## and aged tinylivingpack pieces, normalised so front = +Z, origin = floor centre.
const KIT_DIR := "res://assets/models/environment/city/interior_kit/"
## Same overgrowth sheets the village houses wear (Main._create_house_ivy).
const TEX_OVERGROWTH_DIR := "res://assets/textures/overgrowth/"
const TEX_IVY_SHEET := TEX_OVERGROWTH_DIR + "ivy_sheet.png"
const TEX_IVY_DRAPE := TEX_OVERGROWTH_DIR + "ivy_drape.png"
const TEX_BASE_MOSS := TEX_OVERGROWTH_DIR + "village_base_moss_albedo.png"
const FLOOR_Y := [.12, 3.92]
## Furniture scale vs a 1.75 m character — sized to match the VILLAGE houses'
## placed props (Main._create_house_interior): bed 4.1x1.6x1.7, hutch 2.8 tall,
## fridge 1.9, stove/sink 1.4-1.5, toilet 1.4, bath sink 1.8. Pieces with no
## village counterpart (sofas, chairs, tables, shelves) share the same chunky
## ~1.4x proportion so rooms read like the village. Colliders inherit node.scale.
const MODEL_SCALES := {
 "bed": 2.07, "fridge": 1.2, "gas_stove": 1.55, "stove": 1.52,
 "sink_cabinet": 1.67, "toilet": 1.78, "bath_sink": 2.0,
 "sofa_old": 1.4, "sofa_wrecked": 1.4,
 "armchair": 1.4, "chair_a": 1.4, "chair_b": 1.4,
 "bookshelf": 1.4, "cabinet": 1.4, "tall_dresser": 1.92,
 "dresser_hutch": 1.43, "tv_stand": 1.4, "desk_table": 1.4,
 "side_table": 1.3, "floor_lamp": 1.2, "picture": 1.15,
 "cardboard_box_0": 1.15, "cardboard_box_1": 1.15,
 "garbage_bag_0": 1.1, "garbage_bag_1": 1.1, "rug": 1.1,
}
## [model, x, z, level, yaw_deg, collide, y_offset] in building-local metres.
## Clear zones: entrance (|x|<1.1, z>3.5), stair run (x>3.4, z>-2.0 on the
## ground floor) and the upper landing (x>3.1, z<-1.9).
const FURNITURE := [
 # Ground floor — living room (front).
 ["sofa", -5.1, 2.6, 0, 90.0, true, 0.0],
 ["tv_stand", 2.9, 2.6, 0, -90.0, true, 0.0],
 ["rug", -2.6, 2.6, 0, 90.0, false, 0.003],
 ["side_table", -3.3, 2.6, 0, 0.0, false, 0.0],
 ["armchair", -3.4, 4.9, 0, 150.0, false, 0.0],
 ["floor_lamp", -5.3, 5.3, 0, 0.0, false, 0.0],
 ["bookshelf", 2.2, -0.66, 0, 0.0, true, 0.0],
 ["picture", .4, -0.86, 0, 0.0, false, 1.3],
 ["picture", -5.76, 2.6, 0, 90.0, false, 1.35],
 ["garbage_bag_0", 2.4, 5.1, 0, 30.0, false, 0.0],
 ["cardboard_box_0", -1.7, 0.1, 0, 20.0, false, 0.0],
 # Ground floor — kitchen (back).
 ["fridge", 4.75, -5.05, 0, -90.0, true, 0.0],
 ["sink_cabinet", 5.1, -4.1, 0, -90.0, true, 0.0],
 ["stove", 5.15, -3.3, 0, -90.0, true, 0.0],
 ["desk_table", 1.0, -3.6, 0, 0.0, true, 0.0],
 ["chair_a", 1.0, -2.8, 0, 180.0, false, 0.0],
 ["chair_b", 0.0, -4.4, 0, 60.0, false, 0.0],
 ["dresser_hutch", -5.3, -3.4, 0, 90.0, true, 0.0],
 ["cabinet", -2.8, -5.28, 0, 0.0, true, 0.0],
 ["garbage_bag_1", 3.9, -2.6, 0, 0.0, false, 0.0],
 ["garbage_bag_0", -4.6, -5.2, 0, 70.0, false, 0.0],
 ["cardboard_box_1", -1.2, -5.3, 0, -15.0, false, 0.0],
 # Upper floor — bedroom (back). The bed carries no generic collider:
 # _make_bed_sleepable adds a low frame body plus the sleep area.
 ["bed", -3.55, -4.75, 1, 0.0, false, 0.0],
 ["side_table", -0.75, -5.3, 1, 0.0, false, 0.0],
 ["tall_dresser", 1.9, -5.15, 1, 0.0, true, 0.0],
 ["picture", -3.55, -5.76, 1, 0.0, false, 1.7],
 ["chair_b", -1.2, -4.6, 1, 30.0, false, 0.0],
 ["cardboard_box_0", 0.4, -2.0, 1, 20.0, false, 0.0],
 # Upper floor — front room with the bathroom corner.
 ["toilet", -5.05, 5.1, 1, 90.0, true, 0.0],
 ["bath_sink", -5.2, 3.9, 1, 90.0, false, 0.0],
 ["sofa", 0.6, -0.5, 1, 0.0, true, 0.0],
 ["armchair", -1.6, 2.4, 1, 200.0, false, 0.0],
 ["floor_lamp", 2.2, 0.4, 1, 0.0, false, 0.0],
 ["garbage_bag_1", -3.4, 5.2, 1, 0.0, false, 0.0],
]
## Building-local XZ footprints of the bulky pieces — loot placement in
## Main._find_pos_inside_city_building rejects points inside these so a drop
## can never spawn hidden inside a wardrobe, the bed or the sofa.
const LOOT_BLOCK_RECTS := {
 0: [
  Rect2(-5.8, 1.1, 1.4, 3.0), # sofa
  Rect2(2.55, 1.95, 0.7, 1.3), # tv stand
  Rect2(1.7, -1.0, 1.0, 0.7), # bookshelf
  Rect2(3.8, -5.65, 1.9, 1.2), # fridge
  Rect2(4.55, -4.7, 1.1, 1.2), # sink cabinet
  Rect2(4.6, -3.8, 1.1, 1.0), # stove
  Rect2(0.4, -4.0, 1.2, 0.8), # table
  Rect2(-5.65, -4.2, 0.75, 1.6), # dresser hutch
  Rect2(-3.3, -5.65, 1.0, 0.8), # cabinet
 ],
 1: [
  Rect2(-5.7, -5.65, 4.35, 1.85), # bed
  Rect2(1.4, -5.65, 1.0, 1.0), # tall dresser
  Rect2(-5.65, 4.65, 1.2, 0.95), # toilet
  Rect2(-0.85, -1.1, 2.9, 1.2), # sofa
 ],
}
var observer: Node3D
var buildings: Dictionary = {}
var door_states: Dictionary = {}
var _requested: Dictionary = {}
var _failed: Dictionary = {}
var _tick := 0.0

func _ready() -> void:
 if DisplayServer.get_name() == "headless": return
 var requested_paths: Dictionary = {}
 for i in range(BUILDINGS.size()):
  var path := asset_path(i)
  if not requested_paths.has(path):
   ResourceLoader.load_threaded_request(path)
   requested_paths[path] = true
  _requested[i] = true

static func asset_path(i: int) -> String:
 if BUILDINGS[i].has("asset"):
  return str(BUILDINGS[i].asset)
 return "res://assets/models/environment/city/building_%d.glb" % (i%4+1)

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
  # Threaded get can return null when the request was issued inside a
  # deferred/ready context (harnesses); a blocking load still works.
  packed = load(asset_path(i))
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
 var definition: Dictionary = BUILDINGS[i]
 if not definition.has("asset"):
  _add_stair_landing_supports(building, i % 4 == 1 or i % 4 == 2)
 var door := Door.new()
 door.name = str(BUILDINGS[i].id)+"_door"
 door.position = definition.get("door_position", Vector3(-.85,.12,6.08))
 building.add_child(door)
 door.setup(str(definition.get("door_label", "Puerta de vivienda")), definition.get("door_size", Vector3(1.7,2.8,.12)), Color.SADDLE_BROWN,-100)
 door.is_open = bool(door_states.get(str(door.name), false))
 door.rotation_degrees.y = door.open_yaw if door.is_open else door.closed_yaw
 if int(definition.get("floors", 2)) > 2:
  _furnish_highrise(building, i, int(definition.floors))
  _dress_highrise_facade(building, i)
 else:
  _furnish(building, i)
  _dress_facade(building, i)
 _upgrade_building_materials(building, i)
 # Keep physics and doors resident; small interior props need not draw across town.
 var interior:Node3D=building.get_node("Interior")
 for mesh in interior.find_children("*","GeometryInstance3D",true,false):
  mesh.visibility_range_end=48.0
  mesh.visibility_range_end_margin=6.0
 for mesh in building.find_children("Decals_*","MeshInstance3D",true,false):
  mesh.visibility_range_end=85.0
 buildings[i] = building
 return building

func _furnish_highrise(building: Node3D, i: int, floor_count: int) -> void:
 var root := Node3D.new()
 root.name = "Interior"
 building.add_child(root)
 var floors: Array = BUILDINGS[i].get("loot_floor_values", [.16, 4.02, 7.92, 11.82])
 for level in range(floor_count):
  var floor_y := float(floors[level])
  if level == 0:
   # Large ground-floor shop: two broad counters and shelves along the
   # back wall; keep the entrance, stair lane and centre aisle open.
   # Keep the doorway and centre aisle clear; the previous oversized counter
   # sat directly in the entrance sightline and made the facade read sealed.
   _place(root, "desk_table", Vector3(3.55, floor_y, 3.0), 0.0, Vector3.ZERO, true, true, 1.3)
   _place(root, "cabinet", Vector3(4.8, floor_y, -4.7), 0.0, Vector3.ZERO, true, true, 1.2)
   _place(root, "bookshelf", Vector3(4.8, floor_y, -1.8), 0.0, Vector3.ZERO, true, true, 1.25)
   _place(root, "desk_table", Vector3(2.7, floor_y, -4.8), 0.0, Vector3.ZERO, true, true, 1.3)
  else:
   var bed := _place(root, "bed", Vector3(2.4, floor_y, -3.45), 0.0, Vector3.ZERO, false, true)
   if bed != null:
    _make_bed_sleepable(building, bed, floor_y)
   _place(root, "tall_dresser", Vector3(4.8, floor_y, -.9), 0.0, Vector3.ZERO, true, true, 1.2)
   _place(root, "side_table", Vector3(0.0, floor_y, -3.45), 0.0, Vector3.ZERO, true, true, 1.15)
   _place(root, "sofa_old", Vector3(2.7, floor_y, 3.25), 180.0, Vector3.ZERO, true, true, 1.05)
   _place(root, "bookshelf", Vector3(4.8, floor_y, 1.0), 0.0, Vector3.ZERO, true, true, 1.0)
  # Rubble and floor litter add variation without occupying the stair/corridor.
  var rng := RandomNumberGenerator.new()
  rng.seed = 8841 + level * 67
  for k in range(3):
   var patch := MeshInstance3D.new()
   var plane := PlaneMesh.new()
   plane.size = Vector2.ONE * rng.randf_range(1.0, 1.8)
   patch.mesh = plane
   patch.material_override = _litter_material()
   patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   patch.position = Vector3(rng.randf_range(-.8, 4.8), floor_y + .005 + k * .001, rng.randf_range(-4.4, 4.4))
   patch.rotation.y = rng.randf() * TAU
   root.add_child(patch)

func _furnish(building: Node3D, i: int) -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 5200 + i * 97
 var root := Node3D.new()
 root.name = "Interior"
 building.add_child(root)
 for item in FURNITURE:
  var model: String = item[0]
  if model == "sofa": model = "sofa_wrecked" if (i + 1) % 2 == 0 else "sofa_old"
  elif model == "stove": model = "stove" if i < 2 else "gas_stove"
  var tilt := Vector3.ZERO
  # Looted houses: some light pieces knocked over (never the blocking ones).
  if not item[5] and model in ["chair_a", "chair_b", "armchair", "floor_lamp", "side_table"] and rng.randf() < .45:
   tilt = Vector3(0, 0, deg_to_rad(rng.randf_range(80, 95)))
  var yaw: float = item[4] + rng.randf_range(-6.0, 6.0)
  var placed := _place(root, model, Vector3(item[1], FLOOR_Y[item[3]] + item[6], item[2]), yaw, tilt, item[5])
  if item[0] == "bed" and placed != null:
   _make_bed_sleepable(building, placed, FLOOR_Y[item[3]])
 for level in [0, 1]:
  # Torn curtains on some windows (front windows face -Z into the room).
  for wz in [5.74, -5.74]:
   for wx in [-3.5, 3.5]:
    if rng.randf() < .35: continue
    for side in ([-1, 1] if rng.randf() < .6 else [[-1, 1][rng.randi() % 2]]):
     _place(root, "curtain", Vector3(wx + side * .5, level * 3.9 + 2.62, wz), 180.0 if wz > 0 else 0.0, Vector3.ZERO, false, false)
  # Litter: papers, plaster flakes, leaves and grime over the boards.
  for k in range(5):
   var patch := MeshInstance3D.new()
   var plane := PlaneMesh.new()
   plane.size = Vector2.ONE * rng.randf_range(1.8, 2.8)
   patch.mesh = plane
   patch.material_override = _litter_material()
   patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   patch.position = Vector3(rng.randf_range(-4.6, 2.4), FLOOR_Y[level] + .004 + k * .0015, rng.randf_range(-4.8, 4.8))
   patch.rotation.y = rng.randf() * TAU
   root.add_child(patch)

func _place(parent: Node3D, model: String, pos: Vector3, yaw_deg: float, tilt: Vector3, collide: bool, grounded := true, scale_override := 0.0) -> Node3D:
 var packed: PackedScene = load(KIT_DIR + model + ".glb")
 if packed == null: return null
 var node: Node3D = packed.instantiate()
 node.name = model
 var scale: float = scale_override if scale_override > 0.0 else MODEL_SCALES.get(model, 1.0)
 var basis := Basis.from_euler(Vector3(0, deg_to_rad(yaw_deg), 0)) * Basis.from_euler(tilt)
 var aabb := _local_aabb(node)
 if grounded:
  # Knocked-over pieces pivot on their base: lift them back onto the floor.
  var saabb := AABB(aabb.position * scale, aabb.size * scale)
  pos.y -= (Transform3D(basis) * saabb).position.y
 # The scale must live in the basis — assigning node.scale first and then a
 # plain Transform3D(basis, pos) silently resets it to 1.
 node.transform = Transform3D(basis.scaled(Vector3.ONE * scale), pos)
 parent.add_child(node)
 if collide:
  var body := StaticBody3D.new()
  var shape := CollisionShape3D.new()
  var box := BoxShape3D.new()
  box.size = aabb.size
  shape.shape = box
  shape.position = aabb.get_center()
  body.add_child(shape)
  node.add_child(body)
 return node

## Village beds are sleepable through a BedInteractable Area3D (the player aims
## with `collide_with_areas`). The area must fully enclose the frame collider so
## the aim ray always hits it first; the low frame body still stops the player
## from walking through the mattress.
func _make_bed_sleepable(building: Node3D, node: Node3D, floor_y: float) -> void:
 var aabb := _local_aabb(node)
 var scale := node.scale.x
 var body := StaticBody3D.new()
 body.name = "BedFrame"
 var shape := CollisionShape3D.new()
 var box := BoxShape3D.new()
 var frame_h := 0.85 / scale
 box.size = Vector3(aabb.size.x, frame_h, aabb.size.z)
 shape.shape = box
 shape.position = Vector3(aabb.get_center().x, frame_h * 0.5, aabb.get_center().z)
 body.add_child(shape)
 node.add_child(body)
 var area := Area3D.new()
 area.name = "BedInteractable"
 var acol := CollisionShape3D.new()
 var abox := BoxShape3D.new()
 abox.size = aabb.size + Vector3(0.25 / scale, 0.35 / scale, 0.25 / scale)
 acol.shape = abox
 acol.position = aabb.get_center() + Vector3(0, 0.1 / scale, 0)
 area.add_child(acol)
 area.set_script(load("res://scripts/BedInteractable.gd"))
 node.add_child(area)
 # World-space point on top of the mattress (same +0.9 the village uses).
 area.set("bed_position", building.to_global(Vector3(node.position.x, floor_y + 0.95, node.position.z)))

static func _local_aabb(node: Node3D) -> AABB:
 var result := AABB()
 var first := true
 for mi in node.find_children("*", "MeshInstance3D", true, false):
  var a: AABB = (mi as MeshInstance3D).transform * (mi as MeshInstance3D).get_aabb()
  result = a if first else result.merge(a)
  first = false
 return result

## Village-house overgrowth on the four facades: damp grime + moss patches at
## the base, ivy sheets climbing the walls (carved around the real window and
## door openings) and ivy drapes hanging from the eave line. Same materials
## and textures as Main._create_house_ivy so the block ages like the village.
func _dress_facade(building: Node3D, i: int) -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 9100 + i * 131
 var ivy_mat := MaterialFactory.make_overgrowth_material("ivy_sheet", TEX_IVY_SHEET, 0.28)
 var drape_mat := MaterialFactory.make_overgrowth_material("ivy_drape", TEX_IVY_DRAPE, 0.3)
 var grime_mat := MaterialFactory.make_overgrowth_material("base_damp", TEX_BASE_MOSS, 0.0, true)
 grime_mat.albedo_color = Color(0.55, 0.48, 0.35, 0.65)
 var moss_mat := MaterialFactory.make_overgrowth_material("base_moss", TEX_BASE_MOSS, 0.0, true)
 var height := 7.8
 var extent := 6.0 # half the 12 m facade
 var face_off := 6.0 + .28 * .5 + .03
 var base_height := minf(preload("res://scripts/VillageArchitecture.gd").MOSS_MAX_HEIGHT, height * 0.24)
 var faces := [
  {"u_axis": "x", "side": -1.0, "is_front": false},
  {"u_axis": "x", "side": 1.0, "is_front": true},
  {"u_axis": "z", "side": -1.0, "is_front": false},
  {"u_axis": "z", "side": 1.0, "is_front": false},
 ]
 for face in faces:
  var u_axis: String = face["u_axis"]
  var side: float = face["side"]
  var is_front: bool = face["is_front"]
  # Real openings in wall()-space: windows on front/back, the jagged upper
  # breach on the side walls, the entrance door on the front face.
  var openings: Array[Rect2] = []
  if u_axis == "x":
   var clearance := 0.58 if is_front else 0.2
   for level in range(2):
    for wu in [-3.5, 3.5]:
     openings.append(Rect2(wu - 0.75 - clearance, level * 3.9 + .75, 1.5 + clearance * 2.0, 2.0))
   if is_front:
    openings.append(Rect2(-1.9, -.05, 3.8, 2.9)) # doorway + swing clearance
  else:
   openings.append(Rect2(-2.15, 4.75, 3.6, 3.0)) # upper side breach
  # Damp grime rising from the ground; split on the front so the doorway stays clear.
  if is_front:
   for edge in [-1.0, 1.0]:
    var gw := extent - 1.0
    var gu: float = edge * (1.0 + gw * 0.5)
    _wall_decal(building, "Grime", u_axis, side, face_off, gu, -0.05, gw, base_height, grime_mat, false)
  else:
   _wall_decal(building, "Grime", u_axis, side, face_off, 0.0, -0.05, extent * 2.0 + 0.4, base_height, grime_mat, false)
  for k in range(ceili(extent) * 3):
   var mw := rng.randf_range(1.3, 2.8)
   var mu := rng.randf_range(-extent + mw * 0.5, extent - mw * 0.5)
   if is_front and absf(mu) - mw * 0.5 < 1.0: continue
   _wall_decal(building, "BaseMoss", u_axis, side, face_off + 0.01, mu, 0.0, mw, base_height * rng.randf_range(0.75, 1.0), moss_mat, rng.randf() < 0.5)
  # Tall climbing sheets anchored at the ground near both corners.
  for anchor_u in [-(extent - 0.55), extent - 0.55]:
   var pw := rng.randf_range(1.1, 1.8)
   var ph := rng.randf_range(height * 0.82, height - 0.10)
   var au := clampf(anchor_u + rng.randf_range(-0.5, 0.5), -extent + pw * 0.5, extent - pw * 0.5)
   if is_front and absf(au) - pw * 0.5 < 1.0: continue
   _wall_growth(building, "Ivy", u_axis, side, face_off + 0.02, Rect2(au - pw * 0.5, 0.0, pw, ph), openings, ivy_mat, rng.randf() < 0.5)
  # Extra climbers thicken the wall; openings carve them around the glass.
  var climbers := 2 + rng.randi() % 2
  for k in range(climbers):
   var cw := rng.randf_range(1.3, 2.2)
   var ch := rng.randf_range(height * 0.55, height - 0.15)
   var u := rng.randf_range(-extent + cw * 0.5, extent - cw * 0.5)
   if is_front and absf(u) - cw * 0.5 < 1.0: continue
   _wall_growth(building, "Ivy", u_axis, side, face_off + 0.02, Rect2(u - cw * 0.5, 0.0, cw, ch), openings, ivy_mat, rng.randf() < 0.5)
  var panels := 2 + rng.randi() % 3
  for k in range(panels):
   var pw := rng.randf_range(1.6, 3.0)
   var ph := rng.randf_range(1.8, minf(3.6, height - 0.15))
   var u := rng.randf_range(-extent + pw * 0.5, extent - pw * 0.5)
   if is_front and absf(u) - pw * 0.5 < 1.0: continue
   _wall_growth(building, "Ivy", u_axis, side, face_off + 0.02, Rect2(u - pw * 0.5, 0.0, pw, ph), openings, ivy_mat, rng.randf() < 0.5)
  # Mid-height patches and low bushy growth spread the cover across the face.
  var patches := 2 + rng.randi() % 2
  for k in range(patches):
   var pw := rng.randf_range(1.2, 2.4)
   var ph := rng.randf_range(1.2, 2.0)
   var y0 := rng.randf_range(1.0, maxf(1.05, height - 0.35 - ph))
   var u := rng.randf_range(-extent + pw * 0.5, extent - pw * 0.5)
   if is_front and absf(u) - pw * 0.5 < 1.0: continue
   _wall_growth(building, "Ivy", u_axis, side, face_off + 0.04, Rect2(u - pw * 0.5, y0, pw, ph), openings, ivy_mat, rng.randf() < 0.5)
  var bushes := 5 + rng.randi() % 3
  for k in range(bushes):
   var bw := rng.randf_range(1.4, 2.4)
   var bh := rng.randf_range(0.9, 1.6)
   var u := rng.randf_range(-extent + bw * 0.5, extent - bw * 0.5)
   if is_front and absf(u) - bw * 0.5 < 1.0: continue
   _wall_growth(building, "Ivy", u_axis, side, face_off + 0.03, Rect2(u - bw * 0.5, 0.0, bw, bh), openings, ivy_mat, rng.randf() < 0.5)
  # Strands hanging from the eave line.
  var drapes := 3 + rng.randi() % 2
  for k in range(drapes):
   var dw := rng.randf_range(0.6, 1.4)
   var dh := rng.randf_range(0.5, 1.2)
   var u := rng.randf_range(-extent + dw * 0.5, extent - dw * 0.5)
   if is_front and absf(u) - dw * 0.5 < 1.0: continue
   var top := height - 0.15 - rng.randf_range(0.0, 0.8)
   _wall_growth(building, "Drape", u_axis, side, face_off + 0.02, Rect2(u - dw * 0.5, top - dh, dw, dh), openings, drape_mat, false)
 _emit_decals(building)

## Facade decals are merged into one ArrayMesh per texture (ivy sheet, drape,
## base moss, damp): ~60 wall quads per building would otherwise cost a mesh
## instance + draw call each. The split-region UV remap that used to live in
## duplicated materials is baked straight into each quad's UVs.
var _decal_groups := {} # building instance id -> { material : quads }

# Cuts `area` around the openings and emits one quad per surviving region,
# remapping UVs so each piece keeps its share of the sheet (village logic).
func _wall_growth(building: Node3D, label: String, u_axis: String, side: float, face_off: float, area: Rect2, openings: Array[Rect2], material: StandardMaterial3D, mirror: bool) -> void:
 var regions: Array[Rect2] = [area]
 for opening in openings:
  var free: Array[Rect2] = []
  for region in regions:
   var overlap := region.intersection(opening)
   if not overlap.has_area():
    free.append(region)
    continue
   free.append(Rect2(region.position, Vector2(overlap.position.x - region.position.x, region.size.y)))
   free.append(Rect2(Vector2(overlap.end.x, region.position.y), Vector2(region.end.x - overlap.end.x, region.size.y)))
   free.append(Rect2(Vector2(overlap.position.x, region.position.y), Vector2(overlap.size.x, overlap.position.y - region.position.y)))
   free.append(Rect2(Vector2(overlap.position.x, overlap.end.y), Vector2(overlap.size.x, region.end.y - overlap.end.y)))
  regions = free.filter(func(rect: Rect2): return rect.size.x > 0.12 and rect.size.y > 0.12)
 var tangent_sign := side if u_axis == "x" else -side
 if mirror: tangent_sign = -tangent_sign
 for region in regions:
  var u_start := region.position.x - area.position.x if tangent_sign > 0.0 else area.end.x - region.end.x
  var u0 := u_start / area.size.x
  var u1 := u0 + region.size.x / area.size.x
  var v0 := (area.end.y - region.end.y) / area.size.y
  var v1 := v0 + region.size.y / area.size.y
  _wall_decal(building, label, u_axis, side, face_off, region.get_center().x, region.position.y, region.size.x, region.size.y, material, mirror, Rect2(u0, v0, u1 - u0, v1 - v0))

func _wall_decal(building: Node3D, node_name: String, u_axis: String, side: float, face_off: float, u: float, y_bottom: float, w: float, h: float, mat: Material, mirror: bool, uv_rect := Rect2(0.0, 0.0, 1.0, 1.0)) -> void:
 # Baking the orientation into world-space corners lets every quad share one
 # merged mesh; mirroring becomes a U swap (all overgrowth mats are cull-off).
 var right := Vector3(1 if side > 0.0 else -1, 0, 0) if u_axis == "x" else Vector3(0, 0, -1 if side > 0.0 else 1)
 var center := Vector3(u, y_bottom + h * 0.5, side * face_off) if u_axis == "x" else Vector3(side * face_off, y_bottom + h * 0.5, u)
 var u0 := uv_rect.position.x
 var u1 := uv_rect.end.x
 if mirror:
  var t := u0; u0 = u1; u1 = t
 var groups: Dictionary = _decal_groups.get_or_add(building.get_instance_id(), {})
 (groups.get_or_add(mat, []) as Array).append({
  "a": center - right * w * 0.5 + Vector3.UP * h * 0.5,
  "b": center + right * w * 0.5 + Vector3.UP * h * 0.5,
  "c": center + right * w * 0.5 - Vector3.UP * h * 0.5,
  "d": center - right * w * 0.5 - Vector3.UP * h * 0.5,
  "uv": [Vector2(u0, uv_rect.position.y), Vector2(u1, uv_rect.position.y), Vector2(u1, uv_rect.end.y), Vector2(u0, uv_rect.end.y)],
  "n": node_name})

func _emit_decals(building: Node3D) -> void:
 var groups: Dictionary = _decal_groups.get(building.get_instance_id(), {})
 for mat in groups:
  var quads: Array = groups[mat]
  var st := SurfaceTool.new()
  st.begin(Mesh.PRIMITIVE_TRIANGLES)
  for quad in quads:
   var normal: Vector3 = (quad["b"] - quad["a"]).cross(quad["d"] - quad["a"]).normalized()
   st.set_normal(normal)
   var uv: Array = quad["uv"]
   st.set_uv(uv[0]); st.add_vertex(quad["a"])
   st.set_uv(uv[1]); st.add_vertex(quad["b"])
   st.set_uv(uv[2]); st.add_vertex(quad["c"])
   st.set_uv(uv[0]); st.add_vertex(quad["a"])
   st.set_uv(uv[2]); st.add_vertex(quad["c"])
   st.set_uv(uv[3]); st.add_vertex(quad["d"])
  var mesh_instance := MeshInstance3D.new()
  mesh_instance.name = "Decals_%s" % str(quads[0]["n"])
  mesh_instance.mesh = st.commit()
  mesh_instance.material_override = mat
  mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  building.add_child(mesh_instance)
 _decal_groups.erase(building.get_instance_id())

static var _city_pbr_cache: Dictionary = {}

static func _pbr_mat(kind: String, tint: Color, uv_scale: float = 0.34, normal_str: float = 1.25, metallic_val: float = 0.0, rough_mult: float = 1.0) -> StandardMaterial3D:
 var key := "%s|%s|%.2f|%.2f|%.2f|%.2f" % [kind, tint.to_html(), uv_scale, normal_str, metallic_val, rough_mult]
 if _city_pbr_cache.has(key):
  return _city_pbr_cache[key]
 var base_dir := "res://assets/textures/overgrowth/village_"
 var m := StandardMaterial3D.new()
 m.albedo_texture = MaterialFactory.load_texture(base_dir + kind + "_albedo.png")
 m.normal_enabled = true
 m.normal_texture = MaterialFactory.load_texture(base_dir + kind + "_normal.png")
 m.normal_scale = normal_str
 m.roughness_texture = MaterialFactory.load_texture(base_dir + kind + "_roughness.png")
 m.roughness = rough_mult
 m.metallic = metallic_val
 m.albedo_color = tint
 m.uv1_triplanar = true
 m.uv1_world_triplanar = false
 m.uv1_scale = Vector3.ONE * uv_scale
 m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 _city_pbr_cache[key] = m
 return m

const BUILDING_PALETTES := [
 {"wall": "ochre", "tint": Color(0.88, 0.80, 0.68), "brick": Color(0.76, 0.54, 0.44)},
 {"wall": "lime", "tint": Color(0.78, 0.82, 0.79), "brick": Color(0.68, 0.52, 0.46)},
 {"wall": "clay", "tint": Color(0.86, 0.68, 0.58), "brick": Color(0.72, 0.46, 0.38)},
 {"wall": "stone", "tint": Color(0.78, 0.80, 0.82), "brick": Color(0.65, 0.50, 0.44)},
 {"wall": "brick", "tint": Color(0.84, 0.64, 0.54), "brick": Color(0.78, 0.52, 0.42)},
 {"wall": "lime", "tint": Color(0.86, 0.84, 0.76), "brick": Color(0.74, 0.54, 0.44)},
 {"wall": "ochre", "tint": Color(0.82, 0.72, 0.60), "brick": Color(0.70, 0.48, 0.38)},
 {"wall": "clay", "tint": Color(0.80, 0.74, 0.68), "brick": Color(0.68, 0.50, 0.42)},
]

func _upgrade_building_materials(building: Node3D, index: int) -> void:
 var pal: Dictionary = BUILDING_PALETTES[index % BUILDING_PALETTES.size()]
 var wall_mat := _pbr_mat(str(pal["wall"]), pal["tint"], 0.30, 1.35)
 var brick_mat := _pbr_mat("brick", pal["brick"], 0.38, 1.45)
 var stone_mat := _pbr_mat("stone", Color(0.64, 0.65, 0.62), 0.36, 1.35)
 var wood_mat := _pbr_mat("wood", Color(0.48, 0.34, 0.22), 0.42, 1.20)
 var roof_mat := _pbr_mat("slate", Color(0.46, 0.48, 0.50), 0.40, 1.30)
 var iron_mat := _pbr_mat("stone", Color(0.18, 0.19, 0.18), 0.50, 0.90, 0.78, 0.42)
 var glass_mat: StandardMaterial3D = _city_pbr_cache.get("city_glass")
 if glass_mat == null:
  glass_mat = StandardMaterial3D.new()
  glass_mat.albedo_color = Color(0.36, 0.48, 0.54, 0.72)
  glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  glass_mat.roughness = 0.08
  glass_mat.metallic = 0.25
  glass_mat.metallic_specular = 0.85
  _city_pbr_cache["city_glass"] = glass_mat
 for node in building.find_children("*", "MeshInstance3D", true, false):
  var mi := node as MeshInstance3D
  if mi == null or mi.mesh == null:
   continue
  var nname := str(mi.name)
  if nname.begins_with("Collision_") or nname.begins_with("Decals_"):
   continue
  if mi.get_parent() != null and mi.get_parent().name == "Interior":
   continue
  for s in range(mi.mesh.get_surface_count()):
   var smat := mi.mesh.surface_get_material(s)
   var mname := str(smat.resource_name).to_lower() if smat != null else ""
   if "plaster" in mname or "lime" in mname:
    mi.set_surface_override_material(s, wall_mat)
   elif "brick" in mname:
    mi.set_surface_override_material(s, brick_mat)
   elif "foundation" in mname or "concrete" in mname or "stone" in mname:
    mi.set_surface_override_material(s, stone_mat)
   elif "wood" in mname or "timber" in mname:
    mi.set_surface_override_material(s, wood_mat)
   elif "iron" in mname or "metal" in mname:
    mi.set_surface_override_material(s, iron_mat)
   elif "glass" in mname:
    mi.set_surface_override_material(s, glass_mat)
   elif "roof" in nname.to_lower() or "slate" in mname:
    mi.set_surface_override_material(s, roof_mat)

func _dress_highrise_facade(building: Node3D, i: int) -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 9700 + i * 131
 var ivy_mat := MaterialFactory.make_overgrowth_material("ivy_sheet", TEX_IVY_SHEET, 0.28)
 var drape_mat := MaterialFactory.make_overgrowth_material("ivy_drape", TEX_IVY_DRAPE, 0.3)
 var grime_mat := MaterialFactory.make_overgrowth_material("base_damp", TEX_BASE_MOSS, 0.0, true)
 grime_mat.albedo_color = Color(0.55, 0.48, 0.35, 0.65)
 var moss_mat := MaterialFactory.make_overgrowth_material("base_moss", TEX_BASE_MOSS, 0.0, true)
 var height := 15.6
 var extent := 6.0
 var face_off := 6.0 + 0.17
 var base_height := 1.35
 for face in [
  {"u_axis": "x", "side": -1.0, "is_front": false},
  {"u_axis": "x", "side": 1.0, "is_front": true},
  {"u_axis": "z", "side": -1.0, "is_front": false},
  {"u_axis": "z", "side": 1.0, "is_front": false},
 ]:
  var u_axis: String = face["u_axis"]
  var side: float = face["side"]
  var is_front: bool = face["is_front"]
  var openings: Array[Rect2] = []
  if is_front:
   openings.append(Rect2(-2.9, -0.05, 3.2, 3.2))
  for level in range(4):
   for wu in [-3.5, 0.0, 3.5]:
    openings.append(Rect2(wu - 0.85, level * 3.9 + 0.75, 1.7, 2.2))
  if not is_front:
   _wall_decal(building, "Grime", u_axis, side, face_off, 0.0, -0.05, extent * 2.0 + 0.2, base_height, grime_mat, false)
  for k in range(8):
   var mw := rng.randf_range(1.4, 2.8)
   var mu := rng.randf_range(-extent + mw * 0.5, extent - mw * 0.5)
   if is_front and mu < 0.5 and mu > -3.2:
    continue
   _wall_decal(building, "BaseMoss", u_axis, side, face_off + 0.01, mu, 0.0, mw, base_height * rng.randf_range(0.75, 1.0), moss_mat, rng.randf() < 0.5)
  for anchor_u in [-(extent - 0.65), extent - 0.65]:
   var pw := rng.randf_range(1.2, 2.0)
   var ph := rng.randf_range(height * 0.55, height * 0.88)
   _wall_growth(building, "Ivy", u_axis, side, face_off + 0.02, Rect2(anchor_u - pw * 0.5, 0.0, pw, ph), openings, ivy_mat, rng.randf() < 0.5)
  for k in range(3):
   var dw := rng.randf_range(0.7, 1.5)
   var dh := rng.randf_range(0.7, 1.5)
   var u := rng.randf_range(-extent + dw * 0.5, extent - dw * 0.5)
   var top := height - 0.15
   _wall_growth(building, "Drape", u_axis, side, face_off + 0.02, Rect2(u - dw * 0.5, top - dh, dw, dh), openings, drape_mat, false)
 _emit_decals(building)

static var _litter_mat: StandardMaterial3D
static func _litter_material() -> StandardMaterial3D:
 if _litter_mat == null:
  _litter_mat = StandardMaterial3D.new()
  _litter_mat.albedo_texture = load("res://assets/textures/city_interior/floor_litter.png")
  _litter_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
  _litter_mat.alpha_scissor_threshold = .5
  _litter_mat.roughness = 1.0
 return _litter_mat

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

func _add_stair_landing_supports(building: Node3D, roof_access: bool) -> void:
 # Keep the switch-back stairs walkable when descending as well as ascending.
 # The imported house collision is a single merged trimesh; tiny seams around
 # its upper landing/bridge can let a full-size player capsule fall through.
 _add_stair_landing_box(building, "UpperLandingSupport", Vector3(4.55, 3.855, -4.4), Vector3(2.72, 0.09, 3.08))
 _add_stair_landing_box(building, "LandingBridgeSupport", Vector3(4.48, 3.855, -2.35), Vector3(2.64, 0.09, 0.82))
 if roof_access:
  _add_stair_landing_box(building, "UpperStairBaseSupport", Vector3(3.81, 3.855, 1.3), Vector3(1.3, 0.09, 6.16))

func _add_stair_landing_box(building: Node3D, node_name: String, at: Vector3, size: Vector3) -> void:
 var body := StaticBody3D.new()
 body.name = node_name
 body.collision_layer = 1
 body.collision_mask = 1
 body.position = at
 var collision := CollisionShape3D.new()
 var shape := BoxShape3D.new()
 shape.size = size
 collision.shape = shape
 body.add_child(collision)
 building.add_child(body)

func unload_building(i: int) -> void:
 if not buildings.has(i): return
 var building: Node3D = buildings[i]
 var door: Door = building.get_node(str(BUILDINGS[i].id)+"_door")
 door_states[str(door.name)] = door.is_open
 remove_child(building)
 building.queue_free()
 buildings.erase(i)
