extends Node3D
## Pilot district: assets stream independently; door state outlives their nodes.
const BUILDINGS := [
 {"id":"city_01", "position":Vector3(-16,0,-17), "yaw":0.0},
 {"id":"city_02", "position":Vector3(16,0,-17), "yaw":0.0},
 {"id":"city_03", "position":Vector3(-16,0,17), "yaw":PI},
 {"id":"city_04", "position":Vector3(16,0,17), "yaw":PI},
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
## Furniture scale vs a 1.75 m character — the kit pieces model ~70% of real
## furniture size. Scaled pieces can sink a few cm into walls (backs are never
## visible); fronts gain presence instead. Colliders inherit node.scale.
const MODEL_SCALES := {
 "bed": 1.15, "fridge": 1.2, "gas_stove": 1.15, "stove": 1.15,
 "sink_cabinet": 1.2, "toilet": 1.15, "bath_sink": 1.2,
 "armchair": 1.25, "chair_a": 1.25, "chair_b": 1.25,
 "bookshelf": 1.3, "cabinet": 1.25, "tall_dresser": 1.35,
 "dresser_hutch": 1.15, "tv_stand": 1.2, "desk_table": 1.15,
 "side_table": 1.15, "floor_lamp": 1.1, "picture": 1.15,
 "cardboard_box_0": 1.15, "cardboard_box_1": 1.15,
 "garbage_bag_0": 1.1, "garbage_bag_1": 1.1, "rug": 1.1,
}
## [model, x, z, level, yaw_deg, collide, y_offset] in building-local metres.
## Clear zones: entrance (|x|<1.1, z>3.5), stair run (x>3.4, z>-2.0 on the
## ground floor) and the upper landing (x>3.1, z<-1.9).
const FURNITURE := [
 # Ground floor — living room (front).
 ["sofa", -5.2, 2.6, 0, 90.0, true, 0.0],
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
 ["fridge", 5.1, -5.2, 0, -90.0, true, 0.0],
 ["sink_cabinet", 5.55, -4.1, 0, -90.0, true, 0.0],
 ["stove", 5.5, -3.3, 0, -90.0, true, 0.0],
 ["desk_table", 1.0, -3.6, 0, 0.0, true, 0.0],
 ["chair_a", 1.0, -2.8, 0, 180.0, false, 0.0],
 ["chair_b", 0.0, -4.4, 0, 60.0, false, 0.0],
 ["dresser_hutch", -5.62, -3.4, 0, 90.0, true, 0.0],
 ["cabinet", -2.8, -5.58, 0, 0.0, true, 0.0],
 ["garbage_bag_1", 3.9, -2.6, 0, 0.0, false, 0.0],
 ["garbage_bag_0", -4.6, -5.2, 0, 70.0, false, 0.0],
 ["cardboard_box_1", -1.2, -5.3, 0, -15.0, false, 0.0],
 # Upper floor — bedroom (back).
 ["bed", -4.4, -5.42, 1, 0.0, true, 0.0],
 ["side_table", -3.0, -5.5, 1, 0.0, false, 0.0],
 ["tall_dresser", 1.9, -5.6, 1, 0.0, true, 0.0],
 ["picture", -4.4, -5.76, 1, 0.0, false, 1.25],
 ["chair_b", -1.2, -4.6, 1, 30.0, false, 0.0],
 ["cardboard_box_0", 0.4, -2.0, 1, 20.0, false, 0.0],
 # Upper floor — front room with the bathroom corner.
 ["toilet", -5.52, 5.1, 1, 90.0, true, 0.0],
 ["bath_sink", -5.62, 3.9, 1, 90.0, false, 0.0],
 ["sofa", 0.6, -0.5, 1, 0.0, true, 0.0],
 ["armchair", -1.6, 2.4, 1, 200.0, false, 0.0],
 ["floor_lamp", 2.2, 0.4, 1, 0.0, false, 0.0],
 ["garbage_bag_1", -3.4, 5.2, 1, 0.0, false, 0.0],
]
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
 door.setup("Puerta de vivienda",Vector3(1.7,2.8,.12),Color.SADDLE_BROWN,-100)
 door.is_open = bool(door_states.get(str(door.name), false))
 door.rotation_degrees.y = door.open_yaw if door.is_open else door.closed_yaw
 _furnish(building, i)
 _dress_facade(building, i)
 buildings[i] = building
 return building

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
  _place(root, model, Vector3(item[1], FLOOR_Y[item[3]] + item[6], item[2]), yaw, tilt, item[5])
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

func _place(parent: Node3D, model: String, pos: Vector3, yaw_deg: float, tilt: Vector3, collide: bool, grounded := true) -> void:
 var packed: PackedScene = load(KIT_DIR + model + ".glb")
 if packed == null: return
 var node: Node3D = packed.instantiate()
 node.name = model
 var scale: float = MODEL_SCALES.get(model, 1.0)
 node.scale = Vector3.ONE * scale
 var basis := Basis.from_euler(Vector3(0, deg_to_rad(yaw_deg), 0)) * Basis.from_euler(tilt)
 var aabb := _local_aabb(node)
 if grounded:
  # Knocked-over pieces pivot on their base: lift them back onto the floor.
  var saabb := AABB(aabb.position * scale, aabb.size * scale)
  pos.y -= (Transform3D(basis) * saabb).position.y
 node.transform = Transform3D(basis, pos)
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
    openings.append(Rect2(-5.7, -.05, 11.5, 8.45)) # exterior roof stair zone
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

func unload_building(i: int) -> void:
 if not buildings.has(i): return
 var building: Node3D = buildings[i]
 var door: Door = building.get_node(str(BUILDINGS[i].id)+"_door")
 door_states[str(door.name)] = door.is_open
 remove_child(building)
 building.queue_free()
 buildings.erase(i)
