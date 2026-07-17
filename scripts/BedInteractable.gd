extends Area3D
class_name BedInteractable

var bed_position: Vector3 = Vector3.ZERO

func _ready() -> void:
	add_to_group("interactable")

func get_interaction_text(_player = null) -> String:
	return "Pulsa E para dormir en la cama"

func interact(player: Node) -> void:
	if player == null or not player is Node3D:
		return
	if player.has_method("start_sleep"):
		player.call("start_sleep", bed_position, true)
	if player.has_signal("notice"):
		player.call("emit_signal", "notice", "Durmiendo en la cama... pulsa D para despertar.")
