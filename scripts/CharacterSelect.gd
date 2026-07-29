extends Control

const DATA_DIR := "res://characters/data"

var _definitions: Array[CharacterDefinition] = []
var _current_index: int = 0

var _name_label: Label = null
var _confirm_button: Button = null
var _preview_anchor: Node3D = null
var _preview_cam: Camera3D = null

func _ready() -> void:
	_load_definitions()
	_build_ui()
	_update_view()

func _load_definitions() -> void:
	_definitions.clear()
	var dir := DirAccess.open(DATA_DIR)
	if dir == null:
		push_warning("No se pudo abrir el directorio de personajes: %s" % DATA_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var path := DATA_DIR.path_join(file)
			var res := load(path)
			if res is CharacterDefinition:
				_definitions.append(res)
		file = dir.get_next()
	dir.list_dir_end()
	_definitions.sort_custom(func(a: CharacterDefinition, b: CharacterDefinition) -> bool:
		return a.character_id < b.character_id
	)

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	var center := CenterContainer.new()
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(vbox)

	var title := Label.new()
	title.text = "SELECCIONA PERSONAJE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(title)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_name_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(300, 400)
	viewport_container.stretch = false
	vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.25)
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.position = Vector3(2.0, 3.0, 2.0)
	light.look_at_from_position(light.position, Vector3.ZERO)
	viewport.add_child(light)

	_preview_cam = Camera3D.new()
	_preview_cam.position = Vector3(0.0, 1.0, 3.5)
	_preview_cam.fov = 35.0
	viewport.add_child(_preview_cam)
	_preview_cam.look_at_from_position(_preview_cam.position, Vector3(0.0, 1.0, 0.0))

	_preview_anchor = Node3D.new()
	_preview_anchor.name = "PreviewAnchor"
	viewport.add_child(_preview_anchor)

	var nav_hbox := HBoxContainer.new()
	vbox.add_child(nav_hbox)

	var prev_btn := Button.new()
	prev_btn.text = "< Anterior"
	prev_btn.pressed.connect(_on_prev)
	nav_hbox.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "Siguiente >"
	next_btn.pressed.connect(_on_next)
	next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	nav_hbox.add_child(next_btn)

	var action_hbox := HBoxContainer.new()
	vbox.add_child(action_hbox)

	var back_btn := Button.new()
	back_btn.text = "Volver"
	back_btn.pressed.connect(_on_back)
	action_hbox.add_child(back_btn)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirmar"
	_confirm_button.pressed.connect(_on_confirm)
	_confirm_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	action_hbox.add_child(_confirm_button)

func _update_view() -> void:
	if _definitions.is_empty():
		_name_label.text = "No hay personajes"
		if _confirm_button != null:
			_confirm_button.disabled = true
		return

	_current_index = clampi(_current_index, 0, _definitions.size() - 1)
	var def := _definitions[_current_index]
	_name_label.text = def.character_name
	if _confirm_button != null:
		_confirm_button.disabled = false

	if _preview_anchor == null or def.character_scene == null:
		return

	for child in _preview_anchor.get_children():
		child.queue_free()

	var instance := def.character_scene.instantiate()
	if not (instance is Node3D):
		instance.queue_free()
		return

	var model := instance as Node3D
	model.position = Vector3.ZERO
	model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	model.scale = Vector3.ONE
	_preview_anchor.add_child(model)
	await _fit_preview_model(model)

func _fit_preview_model(model: Node3D) -> void:
	await get_tree().process_frame
	if not is_instance_valid(model):
		return

	var meshes: Array = []
	_collect_meshes(model, meshes)

	var min_y := 999999.0
	var max_y := -999999.0
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var mesh: MeshInstance3D = mi as MeshInstance3D
		var aabb: AABB = mesh.get_aabb()
		var world_aabb: AABB = mesh.global_transform * aabb
		min_y = min(min_y, world_aabb.position.y)
		max_y = max(max_y, world_aabb.end.y)

	if min_y < 999999.0 and max_y > -999999.0:
		var height := max_y - min_y
		if height > 0.01:
			var s := 2.0 / height
			model.scale = Vector3.ONE * s
			await get_tree().process_frame
			if not is_instance_valid(model):
				return
			min_y = 999999.0
			max_y = -999999.0
			for mi2 in meshes:
				if not is_instance_valid(mi2):
					continue
				var mesh2: MeshInstance3D = mi2 as MeshInstance3D
				var aabb2: AABB = mesh2.get_aabb()
				var world_aabb2: AABB = mesh2.global_transform * aabb2
				min_y = min(min_y, world_aabb2.position.y)
				max_y = max(max_y, world_aabb2.end.y)
			if min_y < 999999.0:
				model.position.y = -min_y

	if _preview_cam != null:
		_preview_cam.look_at_from_position(_preview_cam.position, Vector3(0.0, 1.0, 0.0))

func _collect_meshes(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for c in root.get_children():
		_collect_meshes(c, result)

func _on_next() -> void:
	if _definitions.is_empty():
		return
	_current_index = (_current_index + 1) % _definitions.size()
	_update_view()

func _on_prev() -> void:
	if _definitions.is_empty():
		return
	_current_index = (_current_index - 1 + _definitions.size()) % _definitions.size()
	_update_view()

func _on_confirm() -> void:
	if _definitions.is_empty():
		return
	var def := _definitions[_current_index]
	GameSession.select_character(def)
	if not GameSession.has_selection():
		return
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/Inicio.tscn")
