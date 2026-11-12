extends Node3D
## Fixed buffers for surface impacts; individual materials preserve concurrent
## surface colors/directions while meshes and gradient textures are shared.
const CAPACITY := 8
var groups: Dictionary = {}

func configure(factory: Node) -> void:
	if not groups.is_empty(): return
	var templates := {"dust":_create_dust(factory), "chips":[_create_chips(factory,false)], "sparks":[_create_chips(factory,true)]}
	for kind in templates:
		groups[kind] = []
		for i in range(CAPACITY):
			var pair: Array[GPUParticles3D] = []
			for template: GPUParticles3D in templates[kind]:
				var particles := template.duplicate() as GPUParticles3D
				particles.process_material = template.process_material.duplicate()
				particles.emitting = false
				particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(particles)
				pair.append(particles)
			groups[kind].append({"pair":pair,"available_at":0})
		for template: GPUParticles3D in templates[kind]: template.free()

func warm_up() -> void:
	for kind in groups:
		for slot in groups[kind]:
			slot.available_at = Time.get_ticks_msec() + (2300 if kind=="dust" else 700)
			for particles: GPUParticles3D in slot.pair:
				particles.amount_ratio = 0.0
				particles.restart()
				particles.emitting = true

func burst(kind: String, at: Vector3, normal: Vector3, color: Color) -> bool:
	var now := Time.get_ticks_msec()
	for slot in groups[kind]:
		if now < int(slot.available_at): continue
		slot.available_at = now + (2300 if kind=="dust" else 700)
		for i in range(slot.pair.size()):
			var particles: GPUParticles3D = slot.pair[i]
			var mat := particles.process_material as ParticleProcessMaterial
			mat.direction = (normal+Vector3(0,.35,0)).normalized() if i==1 else normal
			if kind=="dust":
				var tint := Vector3(.16,.15,.12) if i==1 else Vector3.ONE*.08
				mat.color = Color(minf(1,color.r+tint.x),minf(1,color.g+tint.y),minf(1,color.b+tint.z),.95 if i==1 else .92)
			else:
				mat.color = Color(1,.65,.18,1) if kind=="sparks" else Color(color.r+.08,color.g+.08,color.b+.08,.95)
			particles.global_position = at+normal*(.025 if kind!="dust" else (.04 if i==1 else .05))
			particles.amount_ratio = 1.0
			particles.restart()
			particles.emitting = true
		return true
	return false

func _create_dust(factory: Node) -> Array:
	var hit_normal := Vector3.UP
	var color := Color.WHITE
	var particles := GPUParticles3D.new()
	particles.name = "BulletDust"
	particles.amount = 36
	particles.lifetime = 1.65
	particles.explosiveness = 0.82
	particles.randomness = 0.92
	particles.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = hit_normal
	mat.spread = 68.0
	mat.initial_velocity_min = 0.9
	mat.initial_velocity_max = 3.8
	mat.gravity = Vector3(0, -0.35, 0)
	mat.damping_min = 2.2
	mat.damping_max = 4.8
	mat.scale_min = 0.32
	mat.scale_max = 0.88
	mat.color = Color(minf(1.0, color.r + 0.08), minf(1.0, color.g + 0.08), minf(1.0, color.b + 0.08), 0.92)
	mat.hue_variation_min = -0.02
	mat.hue_variation_max = 0.02
	mat.color_ramp = factory._make_fade_ramp(0.08, 0.55)
	var scale_tex := CurveTexture.new()
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.35, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.85))
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	particles.process_material = mat
	particles.draw_pass_1 = factory._make_soft_mesh(Vector2(0.16, 0.16), Color.WHITE)
	# Motas finas de polvo en suspensión alrededor del punto de impacto
	var motes := GPUParticles3D.new()
	motes.name = "BulletDustMotes"
	motes.amount = 28
	motes.lifetime = 2.1
	motes.explosiveness = 0.92
	motes.randomness = 0.95
	motes.one_shot = true
	var mmat := ParticleProcessMaterial.new()
	mmat.direction = (hit_normal + Vector3(0, 0.35, 0)).normalized()
	mmat.spread = 78.0
	mmat.initial_velocity_min = 0.45
	mmat.initial_velocity_max = 2.4
	mmat.gravity = Vector3(0, -0.65, 0)
	mmat.damping_min = 1.2
	mmat.damping_max = 2.6
	mmat.scale_min = 0.35
	mmat.scale_max = 0.95
	mmat.color = Color(minf(1.0, color.r + 0.16), minf(1.0, color.g + 0.15), minf(1.0, color.b + 0.12), 0.95)
	mmat.color_ramp = factory._make_fade_ramp(0.04, 0.65)
	motes.process_material = mmat
	motes.draw_pass_1 = factory._make_soft_mesh(Vector2(0.032, 0.032), Color.WHITE)

	return [particles,motes]

func _create_chips(factory: Node, sparks: bool) -> GPUParticles3D:
	var hit_normal := Vector3.UP
	var color := Color.WHITE
	var particles := GPUParticles3D.new()
	particles.name = "BulletChips"
	particles.amount = 22
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.randomness = 0.75
	particles.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = hit_normal
	mat.spread = 70.0
	mat.initial_velocity_min = 3.5
	mat.initial_velocity_max = 9.0
	mat.gravity = Vector3(0, -16.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	mat.color = Color(color.r + 0.08, color.g + 0.08, color.b + 0.08, 0.95)
	mat.color_ramp = factory._make_fade_ramp(0.05, 0.7)
	particles.process_material = mat
	particles.draw_pass_1 = factory._make_soft_mesh(Vector2(.012,.045) if sparks else Vector2(.025,.025), Color.WHITE)
	if sparks:
		mat.color = Color(1.0,.65,.18,1.0)
		var spark_material := particles.draw_pass_1.material as StandardMaterial3D
		if spark_material != null:
			spark_material.emission_enabled = true
			spark_material.emission = Color(1,.35,.06)
			spark_material.emission_energy_multiplier = 3.0

	return particles
