extends Node3D
## Shared fire/smoke for placed fires and the held torch. Parent owns lifetime.
var small := false
var flicker := true
var _flame: CPUParticles3D
var _smoke: CPUParticles3D
var _phase := 0.0
var _base_energy := 1.0

func _ready() -> void:
	if get_parent() is Light3D:
		_base_energy = get_parent().light_energy
	_flame = _make_particles(false)
	_smoke = _make_particles(true)
	add_child(_flame)
	add_child(_smoke)

func _make_particles(smoke: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "Smoke" if smoke else "Flames"
	particles.amount = (14 if small else 28) if smoke else (20 if small else 40)
	particles.lifetime = 3.5 if smoke else 0.7
	particles.preprocess = 1.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.04 if small else 0.16
	particles.randomness = 0.6
	particles.direction = Vector3.UP
	particles.spread = 14.0 if smoke else 8.0
	particles.initial_velocity_min = 0.35 if small else 0.65
	particles.initial_velocity_max = 0.7 if small else 1.25
	particles.gravity = Vector3(0.12, 0.15, 0.05) if smoke else Vector3(0, 0.5, 0)
	particles.position.y = (0.12 if small else 0.35) if smoke else 0.0
	particles.scale_amount_min = 0.3 if small else 0.6
	particles.scale_amount_max = 0.6 if small else 1.1
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.3 if smoke else 0.7))
	if not smoke:
		scale_curve.add_point(Vector2(0.35, 1.0))
	scale_curve.add_point(Vector2(1, 1.0 if smoke else 0.05))
	particles.scale_amount_curve = scale_curve
	var colors := Gradient.new()
	colors.offsets = PackedFloat32Array([0, 0.15, 0.65, 1])
	colors.colors = PackedColorArray([Color(0.35,0.33,0.30,0), Color(0.4,0.39,0.37,0.35), Color(0.5,0.5,0.5,0.16), Color(0.55,0.55,0.55,0)]) if smoke else PackedColorArray([Color(1,0.85,0.35,0), Color(1,0.65,0.15,1), Color(0.9,0.15,0.025,0.7), Color(0.3,0.02,0.005,0)])
	particles.color_ramp = colors
	var texture_gradient := Gradient.new()
	texture_gradient.set_color(0, Color.WHITE)
	texture_gradient.set_color(1, Color(1,1,1,0))
	var texture := GradientTexture2D.new()
	texture.gradient = texture_gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.no_depth_test = false
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if smoke else BaseMaterial3D.SHADING_MODE_UNSHADED
	if not smoke:
		material.emission_enabled = true
		material.emission = Color(1,0.25,0.025)
		material.emission_energy_multiplier = 1.5
	var quad := QuadMesh.new()
	quad.size = Vector2(1,1) if smoke else Vector2(0.65,1.3)
	quad.material = material
	particles.mesh = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles

func _process(delta: float) -> void:
	_phase += delta
	var active := is_visible_in_tree()
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		active = active and global_position.distance_squared_to(camera.global_position) < 120.0 * 120.0
	_flame.emitting = active
	_smoke.emitting = active
	if flicker and get_parent() is Light3D:
		get_parent().light_energy = _base_energy * (1.0 + sin(_phase * 11.0) * 0.06 + sin(_phase * 17.3) * 0.035)
