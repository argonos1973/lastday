extends StaticBody3D
class_name Shelter

@export var shelter_action := "save"
@export var display_name := "Refugio"

func setup(action: String, label: String, size: Vector3, color: Color) -> void:
	shelter_action = action
	display_name = label
	_make_box(size, color)
	add_to_group("shelter_objects")

func interact(player) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	match shelter_action:
		"bed":
			if main.has_method("sleep_at_shelter"):
				main.sleep_at_shelter()
		"save":
			if main.has_method("save_current_game"):
				main.save_current_game()
		"stash":
			if main.has_method("toggle_stash_item"):
				main.toggle_stash_item()
		"radio":
			if main.has_method("listen_radio"):
				main.listen_radio()

func get_interaction_text(_player = null) -> String:
	return "%s - E" % display_name

func _make_box(size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position.y = size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
