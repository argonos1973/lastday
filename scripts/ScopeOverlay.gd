extends Control

# Telescopic scope overlay. Masks the screen corners with black leaving a
# clear circular view in the center, and draws a reticle (crosshair + dot).
# Also shows wind direction/strength and breath hold status.

var scope_color := Color(0.0, 0.0, 0.0, 1.0)
var reticle_color := Color(0.0, 0.0, 0.0, 0.85)
var center_dot_color := Color(0.85, 0.0, 0.0, 0.95)
var _wind_label: Label = null
var _breath_label: Label = null
var _flash := 0.0   # destello del fogonazo visible a traves de la mira
var _hud_update_accum := 0.0
var _scope_fov := 15.0
var _magnification := 4.0
var _iron_sights := false
var _ads_viewport_container: SubViewportContainer = null
var _ads_viewport: SubViewport = null
var _ads_gun_rig: Node3D = null
var _ads_flash_light: OmniLight3D = null
var _ads_recoil := 0.0

func muzzle_flash() -> void:
	_flash = 1.0
	_ads_recoil = 1.0
	if _ads_flash_light != null and is_instance_valid(_ads_flash_light):
		_ads_flash_light.light_energy = 5.5
	queue_redraw()

func _sync_from_player() -> void:
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene == null:
		return
	var player = scene.get_node_or_null("Player")
	if player != null and is_instance_valid(player) and player.has_method("get_rifle_info"):
		var ri: Dictionary = player.get_rifle_info()
		_scope_fov = float(ri.get("scope_fov", 15.0))
		_magnification = float(ri.get("magnification", 4.0))
		_iron_sights = bool(ri.get("iron_sights", false))

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_viewport().size_changed.connect(_on_vp_size_changed)
	_sync_from_player()
	_ensure_ads_viewport()
	# Wind indicator label
	_wind_label = Label.new()
	_wind_label.name = "WindIndicator"
	_wind_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_wind_label.offset_left = -410.0
	_wind_label.offset_top = 20.0
	_wind_label.offset_right = -10.0
	_wind_label.offset_bottom = 60.0
	_wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_wind_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6, 0.9))
	_wind_label.add_theme_font_size_override("font_size", 14)
	add_child(_wind_label)
	# Breath hold status label
	_breath_label = Label.new()
	_breath_label.name = "BreathStatus"
	_breath_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_breath_label.offset_left = -120.0
	_breath_label.offset_top = -40.0
	_breath_label.offset_right = -10.0
	_breath_label.offset_bottom = -10.0
	_breath_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_breath_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 0.9))
	_breath_label.add_theme_font_size_override("font_size", 13)
	add_child(_breath_label)

func _process(_delta: float) -> void:
	_ensure_ads_viewport()
	if _flash > 0.0 or _ads_recoil > 0.0:
		_flash = maxf(0.0, _flash - _delta * 7.0)
		_ads_recoil = maxf(0.0, _ads_recoil - _delta * 11.0)
		if _ads_gun_rig != null and is_instance_valid(_ads_gun_rig):
			_ads_gun_rig.position = Vector3(0.0, -0.005 * _ads_recoil, -0.042 * _ads_recoil)
			_ads_gun_rig.rotation_degrees = Vector3(-0.65 * _ads_recoil, 0.0, 0.0)
		if _ads_flash_light != null and is_instance_valid(_ads_flash_light):
			_ads_flash_light.light_energy = 5.5 * _flash
		queue_redraw()
	_hud_update_accum += _delta
	var refresh_hud := _hud_update_accum >= 0.10
	if refresh_hud:
		_hud_update_accum = 0.0
	if not refresh_hud:
		return
	var cur_scene := get_tree().current_scene if get_tree() != null else null
	if cur_scene == null:
		return
	var player = cur_scene.get_node_or_null("Player")
	if player == null or not is_instance_valid(player):
		return
	if not player.has_method("get_wind_info"):
		return
	var wind: Dictionary = player.get_wind_info()
	var strength: float = wind.get("strength", 0.0)
	var dir: Vector3 = wind.get("direction", Vector3.ZERO)
	# Convert wind direction to compass bearing
	var bearing := rad_to_deg(atan2(dir.x, dir.z))
	if bearing < 0.0:
		bearing += 360.0
	var compass: String = "N"
	if bearing < 22.5 or bearing >= 337.5:
		compass = "N"
	elif bearing < 67.5:
		compass = "NE"
	elif bearing < 112.5:
		compass = "E"
	elif bearing < 157.5:
		compass = "SE"
	elif bearing < 202.5:
		compass = "S"
	elif bearing < 247.5:
		compass = "SW"
	elif bearing < 292.5:
		compass = "W"
	else:
		compass = "NW"
	var wind_text := "Viento: %.1f m/s %s" % [strength, compass]
	if player.has_method("get_rifle_info"):
		var ri: Dictionary = player.get_rifle_info()
		_scope_fov = float(ri.get("scope_fov", 15.0))
		_magnification = float(ri.get("magnification",4.0))
		_iron_sights = bool(ri.get("iron_sights", false))
		var zoom_label := "%.0f× · Cero 100 m · Rueda: aumentos\n" % _magnification
		if _iron_sights:
			zoom_label = "Punto de mira · Cero 100 m\n"
		elif bool(ri.get("zoom_fixed", false)):
			zoom_label = "%.0f× fija · Cero 100 m\n" % _magnification
		wind_text = zoom_label + wind_text
		queue_redraw()
		var mags_left: int = int(ri.get("magazines_left", 0))
		wind_text += "\nMunición: %d/%d · Cargadores: %d (%d) [R]" % [int(ri.get("magazine", 0)), int(ri.get("mag_size", 5)), mags_left, int(ri.get("reserve", 0))]
	if _wind_label != null:
		_wind_label.text = wind_text
	# Breath hold status
	if player.has_method("_is_breath_held"):
		pass
	if player.get("_breath_hold_active") == true:
		var hold_t: float = player.get("_breath_hold_timer")
		var remaining := maxf(0.0, PlayerController.BREATH_HOLD_DURATION - hold_t)
		_breath_label.text = "Aguantando: %.1fs" % remaining
		_breath_label.add_theme_color_override("font_color", Color(0.7, 0.85, 0.7, 0.9))
	elif player.get("_breath_hold_recover") > 0.0:
		_breath_label.text = "Recuperando..."
		_breath_label.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6, 0.9))
	else:
		_breath_label.text = "Shift: aguantar"
	_ensure_ads_viewport()

func _on_vp_size_changed() -> void:
	if _ads_viewport != null and is_instance_valid(_ads_viewport):
		var sz := get_viewport_rect().size
		if sz.x > 1.0 and sz.y > 1.0:
			_ads_viewport.size = Vector2i(int(sz.x), int(sz.y))
	queue_redraw()

func _ensure_ads_viewport() -> void:
	if not _iron_sights:
		if _ads_viewport_container != null and is_instance_valid(_ads_viewport_container):
			_ads_viewport_container.visible = false
		return
	var vp_sz := get_viewport_rect().size
	if vp_sz.x < 2.0 or vp_sz.y < 2.0:
		vp_sz = Vector2(1280.0, 720.0)
	if _ads_viewport_container != null and is_instance_valid(_ads_viewport_container):
		_ads_viewport_container.visible = true
		_ads_viewport_container.size = vp_sz
		if _ads_viewport != null and is_instance_valid(_ads_viewport) and _ads_viewport.size != Vector2i(int(vp_sz.x), int(vp_sz.y)):
			_ads_viewport.size = Vector2i(int(vp_sz.x), int(vp_sz.y))
		return
	_ads_viewport_container = SubViewportContainer.new()
	_ads_viewport_container.name = "M4AdsViewportContainer"
	_ads_viewport_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ads_viewport_container.size = vp_sz
	_ads_viewport_container.stretch = true
	_ads_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ads_viewport_container)
	move_child(_ads_viewport_container, 0)

	_ads_viewport = SubViewport.new()
	_ads_viewport.name = "M4AdsViewport"
	_ads_viewport.size = Vector2i(int(vp_sz.x), int(vp_sz.y))
	_ads_viewport.transparent_bg = true
	_ads_viewport.own_world_3d = true
	_ads_viewport.msaa_3d = Viewport.MSAA_4X
	_ads_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_ads_viewport_container.add_child(_ads_viewport)

	var root3d := Node3D.new()
	root3d.name = "AdsRoot3D"
	_ads_viewport.add_child(root3d)

	var ads_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.90, 0.95)
	env.ambient_light_energy = 1.0
	ads_env.environment = env
	root3d.add_child(ads_env)

	# Key + rim directional lights for realistic anodized gunmetal speculars
	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-48.0, 28.0, 0.0)
	key_light.light_color = Color(1.0, 0.97, 0.92)
	key_light.light_energy = 1.65
	root3d.add_child(key_light)

	var rim_light := DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(-22.0, -145.0, 0.0)
	rim_light.light_color = Color(0.75, 0.82, 0.95)
	rim_light.light_energy = 0.75
	root3d.add_child(rim_light)

	# Soft fill from the shooter's side so the sights are readable
	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(0.0, 0.72, -0.55)
	fill_light.light_color = Color(1.0, 0.98, 0.95)
	fill_light.light_energy = 0.5
	fill_light.omni_range = 1.6
	root3d.add_child(fill_light)

	_ads_gun_rig = Node3D.new()
	_ads_gun_rig.name = "M4AdsRig"
	root3d.add_child(_ads_gun_rig)

	# Scale the internal M4 hierarchy by 10x so vertices live in normal meter
	# units (~1.8 m long) instead of 0.01x centimeters (avoids near-clip plane culling).
	var gun_scale_root := Node3D.new()
	gun_scale_root.name = "GunScaleRoot"
	gun_scale_root.scale = Vector3.ONE * 10.0
	_ads_gun_rig.add_child(gun_scale_root)

	var m4_scene := load("res://assets/models/weapons/m4_carbine_rifle.glb") as PackedScene
	if m4_scene != null:
		var m4_inst := m4_scene.instantiate() as Node3D
		if m4_inst != null:
			for node in m4_inst.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if "Bullets" in str(mi.name):
					mi.visible = false
				if mi.mesh != null:
					for s_idx in range(mi.mesh.get_surface_count()):
						var mat := mi.get_active_material(s_idx) as StandardMaterial3D
						if mat != null and mat.metallic > 0.85:
							var m_dup := mat.duplicate() as StandardMaterial3D
							m_dup.metallic = 0.35
							m_dup.roughness = 0.48
							mi.set_surface_override_material(s_idx, m_dup)
			gun_scale_root.add_child(m4_inst)

	# Rear peep aperture on the rail's last slot, centered on the real sight
	# line (same height as the real front post tip). The GLB has no rear
	# sight mesh, so the aperture is built at the exact measured position.
	_build_3d_rear_aperture(gun_scale_root)

	# Warm muzzle flash light ahead of the front sight base
	_ads_flash_light = OmniLight3D.new()
	_ads_flash_light.position = Vector3(0.0, 0.060, 0.085)
	_ads_flash_light.light_color = Color(1.0, 0.72, 0.32)
	_ads_flash_light.light_energy = 0.0
	_ads_flash_light.omni_range = 3.0
	gun_scale_root.add_child(_ads_flash_light)

	# First-person camera ON the M4's real sight line: eye ~19 cm behind the
	# rear aperture, looking straight through it to the tip of the real A2
	# front post (Iron_Sight top vertex y=0.0621, z=0.0464 in model units,
	# x10 here), so the real post tip projects to the exact screen center.
	var cam := Camera3D.new()
	cam.name = "AdsCamera3D"
	cam.near = 0.02
	cam.far = 20.0
	cam.fov = 18.0
	root3d.add_child(cam)
	var cam_pos := Vector3(0.0, 0.621, -0.62)
	var target_pos := Vector3(0.0, 0.621, 0.464)
	cam.look_at_from_position(cam_pos, target_pos, Vector3.UP)

func _build_3d_rear_aperture(parent: Node3D) -> void:
	# M4 carry-handle style rear aperture (peep sight) mounted on the last
	# rail slot. Real M4 sight line is horizontal: rear aperture center sits
	# at the exact height of the real front post tip (y=0.0621 model units).
	# Large aperture = real 5 mm CQB aperture; all dims in model units (x10).
	var rear := Node3D.new()
	rear.name = "RearAperture3D"
	parent.add_child(rear)

	var mat_body := StandardMaterial3D.new()
	mat_body.albedo_color = Color(0.16, 0.165, 0.175)
	mat_body.metallic = 0.45
	mat_body.roughness = 0.45

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color(0.10, 0.105, 0.11)
	mat_dark.metallic = 0.35
	mat_dark.roughness = 0.5

	var mat_brass := StandardMaterial3D.new()
	mat_brass.albedo_color = Color(0.30, 0.31, 0.32)
	mat_brass.metallic = 0.75
	mat_brass.roughness = 0.34

	# Picatinny clamp base straddling the rail top (rail top y=0.055)
	var base_mi := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(0.0014, 0.0007, 0.0014)
	base_mi.mesh = base_box
	base_mi.position = Vector3(0.0, 0.0554, -0.043)
	base_mi.material_override = mat_body
	rear.add_child(base_mi)

	# Aperture housing stem rising from the base to the ring bottom
	var stem_mi := MeshInstance3D.new()
	var stem_box := BoxMesh.new()
	stem_box.size = Vector3(0.0008, 0.0058, 0.0010)
	stem_mi.mesh = stem_box
	stem_mi.position = Vector3(0.0, 0.0586, -0.043)
	stem_mi.material_override = mat_body
	rear.add_child(stem_mi)

	# Peep ring: real ~5 mm large aperture centered on the sight line y=0.0621
	var ring_mi := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.00024
	torus.outer_radius = 0.00042
	torus.rings = 48
	torus.ring_segments = 16
	ring_mi.mesh = torus
	ring_mi.position = Vector3(0.0, 0.0621, -0.043)
	ring_mi.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring_mi.material_override = mat_dark
	rear.add_child(ring_mi)

	# Protective ears flanking the aperture (A2 rear sight wings)
	for side in [-1.0, 1.0]:
		var s: float = side
		var ear_mi := MeshInstance3D.new()
		var ear_box := BoxMesh.new()
		ear_box.size = Vector3(0.00022, 0.0019, 0.0010)
		ear_mi.mesh = ear_box
		ear_mi.position = Vector3(s * 0.00062, 0.0619, -0.043)
		ear_mi.material_override = mat_body
		rear.add_child(ear_mi)

	# Windage drum on the right ear (-x renders right: the camera faces +Z)
	var knob_mi := MeshInstance3D.new()
	var knob_cyl := CylinderMesh.new()
	knob_cyl.top_radius = 0.00045
	knob_cyl.bottom_radius = 0.00045
	knob_cyl.height = 0.0005
	knob_mi.mesh = knob_cyl
	knob_mi.position = Vector3(-0.00105, 0.0610, -0.043)
	knob_mi.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	knob_mi.material_override = mat_brass
	rear.add_child(knob_mi)

func _draw_iron_sights(vp_size: Vector2, center: Vector2) -> void:
	# Subtle edge vignette to focus the eye when aiming down sights while the
	# 3D SubViewport renders the actual M4 receiver, rail, rear peep & front post.
	var h := minf(vp_size.x, vp_size.y)
	var vig_r := vp_size.length() * 0.46
	for i in range(6):
		var t := float(i) / 5.0
		var r := vig_r + t * h * 0.22
		draw_arc(center, r, 0.0, TAU, 96, Color(0.0, 0.0, 0.0, 0.06 * (t + 0.3)), h * 0.09, true)
	if _flash > 0.0:
		for i in range(3):
			var t := float(i) / 3.0
			draw_circle(center + Vector2(0.0, h * 0.02), h * (0.04 + t * 0.08) * _flash, Color(1.0, 0.78, 0.36, 0.14 * _flash * (1.0 - t)))

func _draw() -> void:
	var vp_size := get_viewport_rect().size
	var center := vp_size * 0.5
	if _iron_sights:
		_draw_iron_sights(vp_size, center)
		return
	var radius: float = min(vp_size.x, vp_size.y) * 0.4
	# Mask the area outside the circle by drawing a very thick ring that
	# reaches beyond the screen corners. The inside of the ring stays clear.
	var screen_diag: float = vp_size.length()
	var ring_width: float = screen_diag
	draw_arc(center, radius + ring_width * 0.5, 0.0, TAU, 128, scope_color, ring_width, true)
	# Thin dark rim just inside the clear circle to suggest the scope tube.
	draw_arc(center, radius, 0.0, TAU, 128, Color(0.0, 0.0, 0.0, 0.9), 4.0, true)
	# Crosshair lines (clipped to the circle radius).
	draw_line(Vector2(center.x, center.y - radius), Vector2(center.x, center.y + radius), reticle_color, 1.5, true)
	draw_line(Vector2(center.x - radius, center.y), Vector2(center.x + radius, center.y), reticle_color, 1.5, true)
	# Center aim dot.
	draw_circle(center, 1.3, center_dot_color)
	# Destello del fogonazo: brillo calido en la parte baja del visor
	if _flash > 0.0:
		var glow_pos := center + Vector2(0.0, radius * 0.45)
		for i in range(4):
			var t := float(i) / 4.0
			var gr := radius * (0.18 + t * 0.4) * _flash
			var ga := 0.12 * _flash * (1.0 - t)
			draw_circle(glow_pos, gr, Color(1.0, 0.8, 0.45, ga))
	# First-focal-plane reticle: ticks subtend 1 mrad at every zoom.
	var pixels_per_mrad := vp_size.y * .5 / tan(deg_to_rad(_scope_fov)*.5) * .001
	for i in range(1, 11):
		var offset := i*pixels_per_mrad
		if offset > radius*.88: break
		var half_tick := 5.0 if i%5==0 else 2.5
		for side in [-1,1]:
			draw_line(center+Vector2(offset*side,-half_tick),center+Vector2(offset*side,half_tick),reticle_color,1.0,true)
			draw_line(center+Vector2(-half_tick,offset*side),center+Vector2(half_tick,offset*side),reticle_color,1.0,true)
	# Soft inner edge around the lens, without tinting the aiming area.
	for i in range(8):
		draw_arc(center,radius-i*1.8,0,TAU,128,Color(0,0,0,.24*(1.0-i/8.0)),2.0,true)
