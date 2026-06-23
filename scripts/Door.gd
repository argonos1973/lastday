extends StaticBody3D
class_name Door

@export var display_name := "Puerta"
@export var is_open := false
@export var closed_yaw := 0.0
@export var open_yaw := -95.0

var _tween: Tween
var _collision: CollisionShape3D

func setup(label: String, size: Vector3, color: Color, open_angle: float) -> void:
	display_name = label
	open_yaw = open_angle
	_make_door(size, color)
	add_to_group("doors")
	add_to_group("interactable")

func interact(player) -> void:
	is_open = not is_open
	if _collision != null:
		_collision.set_deferred("disabled", is_open)
	var target_yaw := open_yaw if is_open else closed_yaw
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees:y", target_yaw, 0.28)
	player.notice.emit("Puerta abierta." if is_open else "Puerta cerrada.")

func get_interaction_text(_player = null) -> String:
	return "Cerrar puerta" if is_open else "Abrir puerta"

func _make_door(size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = Vector3(size.x * 0.5, size.y * 0.5, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = mesh_instance.position
	add_child(collision)
	_collision = collision

	var handle := MeshInstance3D.new()
	handle.name = "Handle"
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.08, 0.10, 0.08)
	handle.mesh = handle_mesh
	handle.position = Vector3(size.x * 0.84, size.y * 0.52, -size.z * 0.58)
	var handle_material := StandardMaterial3D.new()
	handle_material.albedo_color = Color(0.42, 0.31, 0.16)
	handle_material.roughness = 0.75
	handle.material_override = handle_material
	add_child(handle)
