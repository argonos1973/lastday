extends Node3D
class_name FishController

const SimpleObjLoaderScript = preload("res://scripts/SimpleObjLoader.gd")

var center := Vector3.ZERO
var along := Vector3.FORWARD
var across := Vector3.RIGHT
var length := 8.0
var width := 1.5
var speed := 0.6
var phase := 0.0
var _local_forward := 0.0
var _local_side := 0.0
var _heading := 0.0
var _wander_seed := 0.0
var _last_position := Vector3.ZERO
var _side_target := 0.0

func setup(new_center: Vector3, new_along: Vector3, new_across: Vector3, swim_length: float, swim_width: float) -> void:
	center = new_center
	along = new_along.normalized()
	across = new_across.normalized()
	length = swim_length
	width = swim_width
	speed = randf_range(0.85, 1.55)
	phase = randf_range(0.0, TAU)
	_local_forward = randf_range(-length * 0.28, length * 0.28)
	_local_side = randf_range(-width * 0.24, width * 0.24)
	_heading = randf_range(-0.18, 0.18)
	_wander_seed = randf_range(0.0, TAU)
	_side_target = _local_side
	position = center + along * _local_forward + across * _local_side + Vector3(0.0, 0.012, 0.0)
	_last_position = position
	_build_fish()

func _process(delta: float) -> void:
	phase += delta * speed
	var previous_side := _local_side
	_local_forward += speed * delta
	var wrapped := false
	if _local_forward > length * 0.48:
		_local_forward = -length * 0.48
		_side_target = randf_range(-width * 0.24, width * 0.24)
		wrapped = true
	else:
		_side_target = sin(phase * 0.72 + _wander_seed) * width * 0.25 + sin(phase * 1.21 + _wander_seed * 0.7) * width * 0.08
	_local_side = lerp(_local_side, clamp(_side_target, -width * 0.35, width * 0.35), delta * 0.85)
	position = center + along * _local_forward + across * _local_side + Vector3(0.0, 0.012, 0.0)
	var side_velocity: float = (_local_side - previous_side) / max(0.001, delta)
	var move_dir: Vector3 = along * speed + across * side_velocity
	if wrapped:
		move_dir = along
	if move_dir.length() > 0.01:
		rotation.y = atan2(move_dir.x, move_dir.z)
	rotation.z = lerp_angle(rotation.z, sin(phase * 3.2 + _wander_seed) * 0.055, delta * 5.0)
	_last_position = position

func _build_fish() -> void:
	if _try_build_external_fish():
		return
	var body := MeshInstance3D.new()
	body.name = "FishBody"
	var mesh := SphereMesh.new()
	mesh.radius = randf_range(0.09, 0.15)
	mesh.height = randf_range(0.22, 0.34)
	mesh.radial_segments = 10
	mesh.rings = 5
	body.mesh = mesh
	body.scale = Vector3(0.75, 0.42, 1.45)
	body.material_override = _make_material(Color(0.16, 0.22, 0.20).lerp(Color(0.32, 0.34, 0.28), randf()))
	add_child(body)

	var tail := MeshInstance3D.new()
	tail.name = "FishTail"
	var tail_mesh := PrismMesh.new()
	tail_mesh.size = Vector3(0.16, 0.12, 0.06)
	tail.mesh = tail_mesh
	tail.position = Vector3(0.0, 0.0, -0.22)
	tail.rotation_degrees.x = 90.0
	tail.material_override = body.material_override
	add_child(tail)

func _try_build_external_fish() -> bool:
	var candidates := [
		"res://assets/external/quaternius_fish_obj/OBJ/Fish1.obj",
		"res://assets/external/quaternius_fish_obj/OBJ/Fish2.obj",
		"res://assets/external/quaternius_fish_obj/OBJ/Fish3.obj"
	]
	for path in candidates:
		var node := _load_external_node3d(path)
		if node == null:
			continue
		node.name = "ExternalFishModel"
		node.scale = Vector3.ONE * randf_range(0.10, 0.18)
		node.rotation_degrees = Vector3.ZERO
		add_child(node)
		return true
	return false

func _load_external_node3d(path: String) -> Node3D:
	var instance: Node = null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
			instance = (loaded as PackedScene).instantiate()
	if instance == null and path.get_extension().to_lower() == "obj":
		instance = SimpleObjLoaderScript.new().load_node3d(path, Color(0.16, 0.22, 0.20).lerp(Color(0.32, 0.34, 0.28), randf()))
	if instance == null and (path.get_extension().to_lower() == "gltf" or path.get_extension().to_lower() == "glb"):
		instance = _load_gltf_node3d(path)
	if instance is Node3D:
		return instance as Node3D
	if instance != null:
		instance.queue_free()
	return null

func _load_gltf_node3d(path: String) -> Node3D:
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(disk_path, state)
	if error != OK:
		return null
	var generated_scene := document.generate_scene(state)
	if generated_scene is Node3D:
		return generated_scene as Node3D
	if generated_scene != null:
		generated_scene.queue_free()
	return null

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material
