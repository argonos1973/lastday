extends Node3D
## Temporary construction preview. Materials are consumed only on confirmation.
var actor
var world
var recipe: Dictionary
var from_ground := false
var yaw := 0.0
var distance := 4.0
var check_timer := 0.0
var valid := false
var reason := ""
var tint := StandardMaterial3D.new()
var hint: Label

func _ready() -> void:
	tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var model = load("res://assets/models/props/branch_shelter.glb").instantiate()
	add_child(model)
	_style(model)
	var layer := CanvasLayer.new()
	add_child(layer)
	hint = Label.new()
	hint.position = Vector2(24, 130)
	hint.add_theme_font_size_override("font_size", 20)
	layer.add_child(hint)
	yaw = actor.rotation.y

func _style(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_override = tint
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for child in node.get_children():
		_style(child)

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or actor.is_dead:
		queue_free()
		return
	global_position = actor.global_position - actor.global_basis.z * distance
	global_position.y = world._get_exact_ground_y(global_position.x, global_position.z, actor.global_position.y + 3.0)
	rotation.y = yaw
	check_timer -= delta
	if check_timer > 0.0:
		return
	check_timer = 0.1
	reason = world.shelter_placement_error(global_position, yaw, actor)
	valid = reason.is_empty()
	tint.albedo_color = Color(0.2, 0.9, 0.35, 0.38) if valid else Color(1, 0.15, 0.1, 0.42)
	hint.text = "Refugio: Enter construir · R girar · rueda acercar/alejar · Esc cancelar\n" + ("Terreno válido" if valid else reason)

func handle_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			queue_free()
		elif event.keycode == KEY_R:
			yaw += PI / 12.0
		elif event.keycode == KEY_ENTER:
			confirm()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = clampf(distance + 0.5, 3.0, 6.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = clampf(distance - 0.5, 3.0, 6.0)

func confirm() -> void:
	if is_queued_for_deletion():
		return
	reason = world.shelter_placement_error(global_position, yaw, actor)
	if not reason.is_empty():
		actor.notice.emit(reason)
		return
	actor.set_meta("shelter_placement_position", global_position)
	actor.set_meta("shelter_placement_yaw", yaw)
	var built := false
	if from_ground:
		built = world.craft_ground_recipe(actor, recipe)
	elif actor.inventory.has_item_name("Palo", 11):
		actor.inventory.consume_item_name("Palo", 11)
		world._on_item_dropped("shelter", "shelter", 0.0, 1, 0.0, global_position)
		built = true
	actor.remove_meta("shelter_placement_position")
	actor.remove_meta("shelter_placement_yaw")
	if built:
		actor.play_action_animation("plant", 3.0)
		actor.notice.emit("Refugio construido. [K] abre su alijo.")
		world._save_world_change_silent()
		queue_free()
	else:
		actor.notice.emit("Faltan materiales. Acerca los palos o cancela la colocación.")
