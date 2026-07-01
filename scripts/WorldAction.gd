extends StaticBody3D
class_name WorldAction

@export var action_id := ""
@export var action_type := ""
@export var display_name := ""
@export var depleted := false
@export var repeatable := false
@export var action_state := ""
@export var growth := 0.0
@export var grow_time := 45.0

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _visual_children: Array[Node] = []

func setup(id: String, type: String, label: String, size: Vector3, color: Color, can_repeat := false, marker_visible := true) -> void:
	action_id = id
	action_type = type
	display_name = label
	repeatable = can_repeat
	_make_box(size, color)
	if _mesh_instance != null:
		_mesh_instance.visible = false
	add_to_group("world_actions")
	add_to_group("interactable")

func disable_collision() -> void:
	if _collision != null:
		collision_layer = 2
		collision_mask = 0

func interact(player) -> void:
	if depleted and not repeatable:
		player.notice.emit("%s ya no tiene nada util." % display_name)
		return
	var main := get_tree().current_scene
	if main != null and main.has_method("handle_world_action"):
		main.handle_world_action(self, player)

func collect(player) -> void:
	if depleted and not repeatable:
		player.notice.emit("%s ya no tiene nada util." % display_name)
		return
	var main := get_tree().current_scene
	if main != null and main.has_method("handle_world_action_collect"):
		main.handle_world_action_collect(self, player)

func mark_depleted() -> void:
	depleted = true
	if _mesh_instance != null:
		_mesh_instance.visible = false
	if _collision != null:
		_collision.disabled = true
	_clear_visual_children()

func set_crop_state(state: String, new_growth := 0.0) -> void:
	action_state = state
	growth = new_growth
	_update_crop_visual()

func tick_growth(delta: float) -> void:
	if action_type != "farm_plot" or action_state != "planted":
		return
	growth += delta
	if growth >= grow_time:
		action_state = "ready"
		_update_crop_visual()

func get_interaction_text(_player = null) -> String:
	if action_type == "farm_plot":
		match action_state:
			"planted":
				return "%s creciendo - E" % display_name
			"ready":
				return "%s listo para cosechar - E" % display_name
			_:
				return "%s plantar semillas - E" % display_name
	match action_type:
		"gut_wolf":
			if get_meta("gutted", false):
				return "Lobo vacio"
			return "Destripar lobo - E (cuchillo) | Coger - C (mochila)"
		"wolf_meat_raw":
			return "Carne cruda de lobo - [E] Recoger | [C] Comer (cruda)"
		"fell_tree":
			return "%s - talar con hacha - E" % display_name
		"build_cabin":
			return "%s - construir cabana - E" % display_name
		"pickup_item", "axe_tool", "hoe_tool", "shovel_tool", "hammer_tool", "pickaxe_tool", "backpack_pickup", "coat":
			if _is_clothing():
				return "%s - [E] Equipar | [C] Coger" % display_name
			return "%s - recoger - E" % display_name
		"eat_food":
			return "%s - comer - E" % display_name
		"wood", "stone":
			return "%s - recoger - E" % display_name
		"forage":
			return "%s - recolectar - E" % display_name
		"fish":
			return "%s - pescar - E" % display_name
		"hunt":
			return "%s - rastrear - E" % display_name
		"drink_water":
			return "Beber agua del rio - E"
	return "%s - E" % display_name

func to_dict() -> Dictionary:
	return {
		"id": action_id,
		"depleted": depleted,
		"state": action_state,
		"growth": growth
	}

func from_dict(data: Dictionary) -> void:
	depleted = bool(data.get("depleted", depleted))
	action_state = str(data.get("state", action_state))
	growth = float(data.get("growth", growth))
	if depleted and not repeatable:
		mark_depleted()
	else:
		_update_crop_visual()

func _make_box(size: Vector3, color: Color) -> void:
	_mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	_mesh_instance.mesh = box
	_mesh_instance.position.y = size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_mesh_instance.material_override = material
	add_child(_mesh_instance)

	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	_collision.position.y = size.y * 0.5
	add_child(_collision)

func _update_crop_visual() -> void:
	if action_type != "farm_plot":
		return
	_clear_visual_children()
	if _mesh_instance != null:
		_mesh_instance.visible = true
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	match action_state:
		"planted":
			material.albedo_color = Color(0.14, 0.24, 0.08)
			_add_crop_blades(0.28, material)
		"ready":
			material.albedo_color = Color(0.26, 0.36, 0.09)
			_add_crop_blades(0.58, material)
		_:
			material.albedo_color = Color(0.20, 0.12, 0.055)
	if _mesh_instance != null:
		_mesh_instance.material_override = material

func _add_crop_blades(height: float, material: StandardMaterial3D) -> void:
	for x in [-0.55, 0.0, 0.55]:
		for z in [-0.45, 0.15, 0.55]:
			var blade := MeshInstance3D.new()
			blade.name = "CropShoot"
			blade.position = Vector3(x, height * 0.5 + 0.06, z)
			blade.rotation_degrees = Vector3(randf_range(-7, 7), randf_range(0, 180), randf_range(-6, 6))
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.08, height, 0.08)
			blade.mesh = mesh
			blade.material_override = material
			add_child(blade)
			_visual_children.append(blade)

func _clear_visual_children() -> void:
	for child in _visual_children:
		if is_instance_valid(child):
			child.queue_free()
	_visual_children.clear()

func _is_clothing() -> bool:
	if action_type == "pickup_item" and has_meta("item_type"):
		return str(get_meta("item_type")) == "clothing"
	return false
