extends Node3D
## Standalone walking prototype. Never starts Main or reads/writes player saves.
class PilotAvatar extends "res://scripts/PlayerController.gd":
 func _ready(): pass
 func _process(_delta): pass
 func _physics_process(_delta): pass
var avatar: PilotAvatar
var third_person := false
var walker: CharacterBody3D
var camera: Camera3D
var district: Node3D
var pitch := 0.0
var hud: Label
var _capture_frames := 0
var _capture_preset := ""

func _ready() -> void:
 var environment := WorldEnvironment.new()
 var env := Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color(.22,.26,.30)
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color(.75,.82,.9)
 env.ambient_light_energy = .32
 env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
 environment.environment = env
 add_child(environment)
 var sun := DirectionalLight3D.new()
 sun.rotation_degrees = Vector3(-48,-30,0)
 sun.light_energy = .85
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = 180
 add_child(sun)
 _box("Ground",Vector3(0,-.15,0),Vector3(340,.3,340),Color(.25,.30,.20))
 add_child(preload("res://scripts/CityRoad.gd").new())
 add_child(preload("res://scripts/CityDecay.gd").new())
 district = preload("res://scripts/CityBlock.gd").new()
 district.name = "CityBlock"
 add_child(district)
 walker = CharacterBody3D.new()
 walker.name = "PilotWalker"
 walker.position = Vector3(0,.05,32)
 walker.floor_snap_length = .4
 var shape := CollisionShape3D.new()
 var capsule := CapsuleShape3D.new()
 capsule.radius = .3
 capsule.height = 1.8
 shape.shape = capsule
 shape.position.y = .9
 walker.add_child(shape)
 camera = Camera3D.new()
 camera.position.y = 1.65
 camera.far = 400
 walker.add_child(camera)
 add_child(walker)
 district.observer = walker
 var layer := CanvasLayer.new()
 hud = Label.new()
 hud.position = Vector2(20,20)
 hud.add_theme_font_size_override("font_size",18)
 hud.text = "MANZANA PILOTO · 4 viviendas / 2 plantas\nWASD: caminar · Ratón: mirar · F: puerta · V: tercera persona · Esc: liberar cursor\nPrototipo independiente: no modifica tu partida."
 layer.add_child(hud)
 add_child(layer)
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-city"):
   _capture(arg.get_slice("=",1) if "=" in arg else "overview")
 if _capture_preset == "":
  Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
  avatar=PilotAvatar.new()
  add_child(avatar)
  avatar.stats=preload("res://scripts/SurvivalStats.gd").new()
  avatar.add_child(avatar.stats)
  avatar.inventory=preload("res://scripts/Inventory.gd").new()
  avatar.add_child(avatar.inventory)
  avatar.setup_as_puppet()
  avatar.equip_clothing("Camiseta")
  avatar.collision_layer=0
  avatar.collision_mask=0
  avatar.visible=false

## Presets de captura (debug): posiciona el walker y encuadra la camara.
## --capture-city (overview) o --capture-city=door|interior|stairs|upper
func _capture(preset: String) -> void:
 _capture_preset = preset
 camera.near = .3
 _capture_frames = -300 # margen: ~5 s para que el streaming cargue todo
 match preset:
  "overview":
   walker.position = Vector3(30,18,42)
   camera.look_at(Vector3(0,2,0))
  "door":
   walker.position = Vector3(-16.8,0,-9.4)
   camera.look_at(Vector3(-16.9,1.3,-10.9))
  "interior":
   walker.position = Vector3(-16.6,0,-11.6)
   camera.look_at(Vector3(-18.5,0.6,-22.5))
  "kitchen":
   walker.position = Vector3(-17.2,0,-18.4)
   camera.look_at(Vector3(-11,0.9,-21.8))
  "bedroom":
   walker.position = Vector3(-15.6,3.92,-18.6)
   camera.look_at(Vector3(-20.4,4.4,-22.4))
  "stairs":
   walker.position = Vector3(-11.2,0,-12.6)
   camera.look_at(Vector3(-11.5,3.7,-19))
  "upper":
   walker.position = Vector3(-20,3.85,-20.5)
   camera.look_at(Vector3(-15,5.1,-15))
  "roofstair":
   walker.position = Vector3(-19,0,-30.5)
   camera.look_at(Vector3(-16.5,5.2,-23.2))
  "roofview":
   walker.position = Vector3(-14.5,8.02,-20.2)
   camera.look_at(Vector3(-10.8,7.9,-23.5))
  _: walker.position = Vector3(30,18,42)

func _box(label: String, pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> void:
 var mesh := MeshInstance3D.new()
 mesh.name = label
 var box := BoxMesh.new()
 box.size = size
 mesh.mesh = box
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.roughness = .9
 if label in ["Street","CrossStreet","Pavement"]:
  mat.albedo_texture = load("res://assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg")
  mat.uv1_scale = Vector3(size.x/3.0,size.z/3.0,1)
 mesh.material_override = mat
 if label == "Ground": mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 mesh.position = pos
 add_child(mesh)
 if solid: mesh.create_trimesh_collision()

func _unhandled_input(event: InputEvent) -> void:
 if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
  walker.rotate_y(-event.relative.x*.0025)
  pitch = clampf(pitch-event.relative.y*.0025,-1.4,1.4)
  camera.rotation.x = pitch
 if event is InputEventKey and event.pressed:
  if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
  if event.keycode == KEY_F: _door()
  if event.keycode == KEY_V and is_instance_valid(avatar):
   third_person=not third_person
   avatar.visible=third_person
   camera.position=Vector3(0,2.4,3.4) if third_person else Vector3(0,1.65,0)
   pitch=-.2 if third_person else 0.0
   camera.rotation.x=pitch
 if event is InputEventMouseButton and event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _door() -> void:
 var query := PhysicsRayQueryParameters3D.create(camera.global_position,camera.global_position-camera.global_basis.z*3)
 query.exclude = [walker.get_rid()]
 var hit := get_world_3d().direct_space_state.intersect_ray(query)
 if not hit.is_empty() and hit.collider is Door:
  var door: Door = hit.collider
  door.is_open = not door.is_open
  var target := door.open_yaw if door.is_open else door.closed_yaw
  if door._tween != null: door._tween.kill()
  door._tween = door.create_tween()
  door._tween.tween_property(door,"rotation_degrees:y",target,.28)

func _physics_process(delta: float) -> void:
 if walker == null: return
 if _capture_preset != "":
  _capture_frames += 1
  if _capture_frames == 1:
   get_viewport().get_texture().get_image().save_png("res://outputs/city_pilot_%s.png" % _capture_preset)
   get_tree().quit()
  return
 var input := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
 var direction := walker.basis*Vector3(input.x,0,input.y).normalized()
 walker.velocity.x = direction.x*4.5
 walker.velocity.z = direction.z*4.5
 if not walker.is_on_floor(): walker.velocity.y -= 18*delta
 walker.move_and_slide()
 if is_instance_valid(avatar):
  avatar.global_transform=walker.global_transform
  avatar._walk_intensity=1.0 if direction.length()>.1 else 0.0
  avatar._update_third_person_animation(direction.length()>.1,delta)


