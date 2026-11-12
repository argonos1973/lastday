extends Node3D
## One bounded pool per world, shared by local/remote players and animals.
## Recycling keeps particle buffers alive instead of allocating on every hit.
const CAPACITY := 8
var slots: Array[Dictionary] = []

func configure(drop_material: Material, drop_mesh: Mesh, mist_material: Material, mist_mesh: Mesh) -> void:
	if not slots.is_empty(): return
	for i in range(CAPACITY):
		var pair: Array[GPUParticles3D] = []
		for is_mist in [false,true]:
			var particles := GPUParticles3D.new()
			particles.name = ("BloodMist" if is_mist else "BloodDrops") + str(i)
			particles.emitting = false
			particles.one_shot = true
			particles.amount = 26 if is_mist else 72
			particles.lifetime = .7 if is_mist else .8
			particles.explosiveness = .8 if is_mist else 1.0
			particles.randomness = 1.0 if is_mist else .9
			particles.process_material = mist_material if is_mist else drop_material
			particles.draw_pass_1 = mist_mesh if is_mist else drop_mesh
			particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(particles)
			pair.append(particles)
		slots.append({"pair":pair,"available_at":0})

func warm_up() -> void:
	# Compile/allocate the particle pipeline while the loading screen is up.
	# Zero emission keeps this invisible; reserve slots until that cycle ends.
	for slot in slots:
		slot.available_at = Time.get_ticks_msec()+1100
		for particles: GPUParticles3D in slot.pair:
			particles.amount_ratio = 0.0
			particles.restart()
			particles.emitting = true

func burst(at: Vector3, strength: float) -> bool:
	var now := Time.get_ticks_msec()
	for slot in slots:
		if now < int(slot.available_at): continue
		slot.available_at = now + 1100
		for i in range(2):
			var particles: GPUParticles3D = slot.pair[i]
			particles.global_position = at
			var desired := maxf(2 if i else 4, (14 if i else 40)*strength)
			particles.amount_ratio = clampf(desired/float(particles.amount),0.0,1.0)
			particles.restart()
			particles.emitting = true
		return true
	return false
