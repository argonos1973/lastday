extends Node
class_name PlayerInteractor

signal prompt_changed(text: String)

@export var interaction_distance := 3.0
@export var collision_mask := 0xFFFFFFFF

var camera: Camera3D
var current_target: Object

func setup(player_camera: Camera3D) -> void:
	camera = player_camera

func update_prompt(owner_player: Node) -> void:
	current_target = _find_target()
	if current_target != null and current_target.has_method("get_interaction_text"):
		prompt_changed.emit(str(current_target.call("get_interaction_text", owner_player)))
	else:
		prompt_changed.emit("")

func interact(owner_player: Node) -> bool:
	if current_target == null:
		current_target = _find_target()
	if current_target == null or not current_target.has_method("interact"):
		return false
	current_target.call("interact", owner_player)
	return true

func _find_target() -> Object:
	if camera == null or not is_instance_valid(camera):
		return null
	var viewport := camera.get_viewport()
	if viewport == null:
		return null
	var screen_center := viewport.get_visible_rect().size * 0.5
	var origin := camera.project_ray_origin(screen_center)
	var end := origin + camera.project_ray_normal(screen_center) * interaction_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider", null)
