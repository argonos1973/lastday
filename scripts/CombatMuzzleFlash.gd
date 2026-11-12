extends Node3D
## Reused per actor. No per-round nodes, materials or SceneTree timers.
var particles: GPUParticles3D
var light: OmniLight3D
var material: ParticleProcessMaterial
var remaining := 0.0
var marker: WeakRef

func _ready() -> void:
	top_level = true
	light = OmniLight3D.new()
	light.light_color = Color(1,.72,.3)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	add_child(light)
	particles = GPUParticles3D.new()
	particles.emitting = false
	particles.amount = 10
	particles.lifetime = .09
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ParticleProcessMaterial.new()
	material.spread = 12.0
	material.initial_velocity_min = 6.0
	material.initial_velocity_max = 14.0
	material.gravity = Vector3.ZERO
	material.scale_min = .05
	material.scale_max = .12
	material.color = Color(1,.75,.3,.9)
	particles.process_material = material
	var quad := QuadMesh.new()
	quad.size = Vector2(.1,.1)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1,.72,.25,.9)
	mat.emission_enabled = true
	mat.emission = Color(1,.6,.2)
	mat.emission_energy_multiplier = 3.0
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	particles.draw_pass_1 = quad
	add_child(particles)
	set_process(false)

func warm_up() -> void:
	particles.amount_ratio = 0.0
	particles.restart()
	particles.emitting = true

func burst(at: Vector3, direction: Vector3, muzzle: Node3D = null) -> void:
	marker = weakref(muzzle) if is_instance_valid(muzzle) else null
	global_position = muzzle.global_position if is_instance_valid(muzzle) else at
	material.direction = -muzzle.global_basis.z.normalized() if is_instance_valid(muzzle) else direction
	remaining = .15
	light.light_energy = 5.0
	particles.amount_ratio = 1.0
	particles.restart()
	particles.emitting = true
	set_process(true)

func _process(delta: float) -> void:
	var muzzle = marker.get_ref() if marker != null else null
	if is_instance_valid(muzzle):
		global_position = muzzle.global_position
	remaining -= delta
	if remaining <= 0.0:
		light.light_energy = 0.0
		marker = null
		set_process(false)
