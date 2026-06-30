extends StaticBody3D
class_name DoorInteractable

@export var is_open := false
@export var closed_yaw := 0.0
@export var open_yaw := -95.0

var _tween: Tween
var _collision: CollisionShape3D

func _ready() -> void:
	add_to_group("interactable")

func interact(player) -> void:
	is_open = not is_open
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation_degrees:y", open_yaw if is_open else closed_yaw, 0.28)
	if player != null and player.has_signal("notice"):
		player.notice.emit("Puerta abierta." if is_open else "Puerta cerrada.")

func get_interaction_text(_player = null) -> String:
	return "Cerrar puerta" if is_open else "Abrir puerta"

func register_collision(collision: CollisionShape3D) -> void:
	_collision = collision
