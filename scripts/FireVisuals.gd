extends Node3D
## Shared fire/smoke for placed fires and the held torch. Parent owns lifetime.
var small := false
var flicker := true
## World-space point where smoke is emitted (house chimney top). null = at the fire.
var smoke_origin: Variant = null
var _flame: CPUParticles3D
var _smoke: CPUParticles3D
var _embers: CPUParticles3D
var _glow: MeshInstance3D
var _coals: Array[MeshInstance3D] = []
var _phase := 0.0
var _base_energy := 1.0
var _flicker_value := 1.0
var _flicker_target := 1.0
var _flicker_timer := 0.0

func _ready() -> void:
	if get_parent() is Light3D:
		_base_energy = get_parent().light_energy
	_flame = _make_particles(false)
	_smoke = _make_particles(true)
	_embers = _make_embers()
	add_child(_flame)
	add_child(_smoke)
	add_child(_embers)
	_glow = _make_glow()
	add_child(_glow)
	if not small:
		_make_coal_bed()
	if smoke_origin is Vector3:
		_smoke.global_position = smoke_origin

func _radial_texture(inner: Color, outer_alpha: float = 0.0) -> GradientTexture2D:
	var texture_gradient := Gradient.new()
	texture_gradient.set_color(0, inner)
	texture_gradient.set_color(1, Color(1, 1, 1, outer_alpha))
	var texture := GradientTexture2D.new()
	texture.gradient = texture_gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	return texture

func _make_particles(smoke: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Smoke" if smoke else "Flames"
	particles.amount = (16 if small else 32) if smoke else (24 if small else 46)
	particles.lifetime = 3.8 if smoke else 0.75
	particles.preprocess = 1.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.04 if small else 0.14
	particles.randomness = 0.6
	particles.direction = Vector3.UP
	particles.spread = 14.0 if smoke else 11.0
	particles.initial_velocity_min = 0.35 if small else 0.7
	particles.initial_velocity_max = 0.7 if small else 1.35
	particles.gravity = Vector3(0.12, 0.15, 0.05) if smoke else Vector3(0, 0.55, 0)
	particles.damping_min = 0.0 if smoke else 0.15
	particles.damping_max = 0.1 if smoke else 0.5
	if not smoke:
		particles.angle_min = -25.0
		particles.angle_max = 25.0
		particles.angular_velocity_min = -70.0
		particles.angular_velocity_max = 70.0
	particles.position.y = (0.12 if small else 0.35) if smoke else 0.0
	particles.scale_amount_min = 0.3 if small else 0.6
	particles.scale_amount_max = 0.6 if small else 1.15
	var scale_curve := Curve.new()
	if smoke:
		scale_curve.add_point(Vector2(0, 0.35))
		scale_curve.add_point(Vector2(0.55, 1.0))
		scale_curve.add_point(Vector2(1, 1.35))
	else:
		scale_curve.add_point(Vector2(0, 0.45))
		scale_curve.add_point(Vector2(0.3, 1.05))
		scale_curve.add_point(Vector2(0.7, 0.75))
		scale_curve.add_point(Vector2(1, 0.05))
	particles.scale_amount_curve = scale_curve
	var colors := Gradient.new()
	if smoke:
		colors.offsets = PackedFloat32Array([0, 0.15, 0.65, 1])
		colors.colors = PackedColorArray([Color(0.30,0.28,0.26,0), Color(0.34,0.33,0.31,0.4), Color(0.46,0.46,0.46,0.16), Color(0.55,0.55,0.55,0)])
	else:
		# White-hot core -> bright orange -> deep red -> charred fade.
		colors.offsets = PackedFloat32Array([0, 0.12, 0.45, 0.78, 1])
		colors.colors = PackedColorArray([Color(1,0.92,0.55,0), Color(1,0.72,0.22,1), Color(0.95,0.38,0.05,0.85), Color(0.55,0.09,0.02,0.5), Color(0.15,0.01,0.0,0)])
	particles.color_ramp = colors
	var material := StandardMaterial3D.new()
	material.albedo_texture = _radial_texture(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.no_depth_test = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if smoke else BaseMaterial3D.SHADING_MODE_UNSHADED
	if not smoke:
		material.emission_enabled = true
		material.emission = Color(1,0.3,0.03)
		material.emission_energy_multiplier = 1.8
	var quad := QuadMesh.new()
	quad.size = Vector2(1,1) if smoke else Vector2(0.6,1.25)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

# Fast bright sparks that shoot up through the flame and wink out.
func _make_embers() -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Embers"
	particles.amount = 6 if small else 18
	particles.lifetime = 0.9 if small else 1.5
	particles.preprocess = 0.8
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.03 if small else 0.11
	particles.randomness = 0.75
	particles.direction = Vector3.UP
	particles.spread = 22.0
	particles.initial_velocity_min = 1.1 if small else 1.6
	particles.initial_velocity_max = 2.0 if small else 3.0
	particles.gravity = Vector3(0, -0.9, 0)
	particles.damping_min = 0.4
	particles.damping_max = 1.1
	particles.position.y = 0.05 if small else 0.18
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.0
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(1, 0.15))
	particles.scale_amount_curve = scale_curve
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0, 0.55, 1])
	colors.colors = PackedColorArray([Color(1,0.88,0.5,1), Color(1,0.45,0.08,0.9), Color(0.6,0.05,0.0,0)])
	particles.color_ramp = colors
	var material := StandardMaterial3D.new()
	material.albedo_texture = _radial_texture(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.no_depth_test = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1,0.5,0.1)
	material.emission_energy_multiplier = 4.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07) if small else Vector2(0.10, 0.10)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

# Pulsing billboard glow at the flame base — the bright heart of the fire.
func _make_glow() -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "GlowCore"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.30, 0.34) if small else Vector2(0.62, 0.72)
	var material := StandardMaterial3D.new()
	material.albedo_texture = _radial_texture(Color(1, 0.58, 0.18, 0.7))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(1, 0.45, 0.10)
	material.emission_energy_multiplier = 2.2
	quad.material = material
	mesh_instance.mesh = quad
	mesh_instance.position.y = 0.07 if small else 0.19
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh_instance

# Cluster of glowing coals under the campfire logs (not used for torches).
func _make_coal_bed() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.07, 0.045, 0.035)
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color(1.0, 0.30, 0.04)
	material.emission_energy_multiplier = 2.0
	var lumps := [
		[Vector3(0.00, -0.07, 0.00), 0.14],
		[Vector3(0.09, -0.08, -0.05), 0.10],
		[Vector3(-0.08, -0.08, 0.06), 0.09],
		[Vector3(0.02, -0.075, 0.09), 0.08],
		[Vector3(-0.09, -0.085, -0.07), 0.08],
	]
	for entry in lumps:
		var coal := MeshInstance3D.new()
		coal.name = "CoalBed"
		var sphere := SphereMesh.new()
		sphere.radius = entry[1]
		sphere.height = entry[1] * 1.1
		coal.mesh = sphere
		coal.material_override = material
		coal.position = entry[0]
		coal.scale.y = 0.55
		coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(coal)
		_coals.append(coal)

func _process(delta: float) -> void:
	_phase += delta
	var active := is_visible_in_tree()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		active = active and global_position.distance_squared_to(camera.global_position) < 120.0 * 120.0
	_flame.emitting = active
	_smoke.emitting = active
	_embers.emitting = active
	# Organic flicker: random energy target every ~0.1 s with fast attack,
	# plus two soft sine waves so it never feels mechanical.
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = randf_range(0.05, 0.15)
		_flicker_target = randf_range(0.82, 1.18)
	_flicker_value = lerpf(_flicker_value, _flicker_target, 1.0 - exp(-delta * 14.0))
	var wave := 1.0 + sin(_phase * 11.0) * 0.05 + sin(_phase * 17.3) * 0.03
	var pulse := _flicker_value * wave
	if flicker and get_parent() is Light3D:
		get_parent().light_energy = _base_energy * pulse
	if _glow != null:
		var glow_mat := _glow.mesh.material as StandardMaterial3D
		if glow_mat != null:
			glow_mat.emission_energy_multiplier = 2.2 * pulse
		var glow_scale := 0.92 + 0.16 * pulse
		_glow.scale = Vector3(glow_scale, glow_scale, glow_scale)
	if not _coals.is_empty():
		var coal_mat := _coals[0].material_override as StandardMaterial3D
		if coal_mat != null:
			coal_mat.emission_energy_multiplier = 1.7 + 0.9 * pulse
