extends SceneTree
const G = preload("res://scripts/GraphicsSettings.gd")
const S = preload("res://scripts/ShadowQuality.gd")
var errors := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	G.config_path = "res://build/tmp/graphics_effective.cfg"
	G.invalidate_cache()
	var readback := OS.get_cmdline_user_args().has("--readback")
	if not readback:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(G.config_path))
		G.invalidate_cache()
		var c := ConfigFile.new()
		c.set_value("other", "keep", 17)
		c.set_value("graphics", "detail", {"invalid":true})
		c.save(G.config_path)
		G.invalidate_cache()
		check(G.detail_index() == 1, "Invalid value uses safe default")
		var sun := DirectionalLight3D.new()
		root.add_child(sun)
		for i in range(3):
			check(G.apply_profile(i) == OK, "Save profile")
			G.invalidate_cache()
			check(G.profile_index() == i, "Profile survives disk reload")
			G.apply_detail(root)
			check(root.mesh_lod_threshold == [4.0,2.0,1.0][i], "Effective LOD threshold")
			S.apply(sun, root, S.selected())
			check(sun.shadow_enabled and sun.directional_shadow_max_distance == S.PRESETS[i].distance, "Effective shadows")
			check(root.positional_shadow_atlas_size == (512 if i == 0 else 1024), "Effective local atlas")
			G.save_render_scale_index(i)
			G.apply_render_scale(root)
			check(is_equal_approx(root.scaling_3d_scale, G.RENDER_SCALES[i]), "Effective render scale")
			if RenderingServer.get_current_rendering_method() == "gl_compatibility":
				check(root.scaling_3d_mode == Viewport.SCALING_3D_MODE_BILINEAR, "Compatibility uses bilinear")
		c.load(G.config_path)
		check(c.get_value("other","keep") == 17, "Other sections preserved")
		G.write_values({"fullscreen":false,"resolution":0,"render_scale":1,"vsync":false})
		sun.free()
	check(G.resolution_index() == 0 and G.render_scale_index() == 1 and not G.vsync(), "Saved 720p/75%/VSync off")
	G.apply_window()
	G.apply_render_scale(root)
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.window_get_size() == Vector2i(1280,720), "Actual 720p window")
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "Actual disabled VSync")
		if not readback:
			G.save_fullscreen(true)
			G.apply_window()
			await create_timer(2.0).timeout
			check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Actual fullscreen")
			G.save_fullscreen(false)
			G.apply_window()
			await create_timer(2.0).timeout
			check(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "Actual windowed mode restored")
			check(DisplayServer.window_get_size() == Vector2i(1280,720), "Window resolution restored")
	check(is_equal_approx(root.scaling_3d_scale,0.75), "Actual 75% after reload")
	print("GRAPHICS_EFFECTIVE errors=",errors," readback=",readback," display=",DisplayServer.get_name()," effective=",G.effective_snapshot(root))
	quit(errors)
