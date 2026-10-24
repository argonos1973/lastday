extends SceneTree

# Renders the real shelter prompt through a Label configured exactly like
# HUD.prompt_label to check it shows on separate lines.
# Saves build/tmp/shelter_prompt.png

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _save_world_change_silent() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var world := World.new()
	root.add_child(world)
	current_scene = world
	world._spawn_player_shelter_with_id("test", Vector3.ZERO)
	var sh_action = world.world_actions_by_id.get("test")
	sh_action.set_meta("camo_covered", true)
	sh_action.set_meta("pelt_lined", true)
	var prompt_text := str(sh_action.get_interaction_text())
	print("PROMPT TEXT >>>")
	print(prompt_text)
	print("<<<")

	var canvas := CanvasLayer.new()
	root.add_child(canvas)
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(panel)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(bg)

	# Replica exacta de HUD._build_center_messages prompt_label
	var prompt_label := Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_left = -320
	prompt_label.offset_top = 8
	prompt_label.offset_right = 320
	prompt_label.offset_bottom = 128
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.82))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(prompt_label)
	prompt_label.text = prompt_text

	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/tmp")
	root.get_texture().get_image().save_png("res://build/tmp/shelter_prompt.png")
	print("saved build/tmp/shelter_prompt.png")
	quit()
