extends MeshInstance3D
# World-space wave ribbons: samples stay on the lake while the hull turns.
const LIFETIME := 6.0
const SAMPLE_INTERVAL := 0.08
var samples: Array[Dictionary] = []
var clock := 0.0
var sample_timer := 0.0
var distance_along := 0.0
var last_sample := Vector3.ZERO

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layers = 1 << 17
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/rowboat_wake.gdshader")
	material_override = material
	mesh = ImmediateMesh.new()

func advance(delta: float, stern: Vector3, right: Vector3, strength: float, teleported: bool) -> void:
	if delta <= 0.0:
		return
	clock += delta
	sample_timer += delta
	if teleported:
		samples.clear()
		distance_along = 0.0
		last_sample = stern
	while not samples.is_empty() and clock - float(samples[0].born) > LIFETIME:
		samples.pop_front()
	if strength > 0.06 and sample_timer >= SAMPLE_INTERVAL and not teleported:
		var distance := stern.distance_to(last_sample)
		if samples.is_empty() or distance > 0.07:
			distance_along += minf(distance, 1.0)
			samples.append({"pos": stern, "right": right.normalized(), "born": clock, "strength": strength, "distance": distance_along})
			last_sample = stern
		sample_timer = 0.0
	_rebuild()

func _rebuild() -> void:
	var surface := mesh as ImmediateMesh
	surface.clear_surfaces()
	if samples.size() < 2:
		return
	# Two expanding wave crests on either side of the track.
	for side in [-1.0, 1.0]:
		surface.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for sample in samples:
			var age: float = clock - float(sample.born)
			var fade := smoothstep(0.0, 0.2, age) * (1.0 - smoothstep(1.2, LIFETIME, age))
			var width := 0.18 + age * 0.075
			var expansion := 0.55 + age * (0.28 + float(sample.strength) * 0.12)
			var center: Vector3 = sample.pos + sample.right * side * expansion
			for edge in [-1.0, 1.0]:
				surface.surface_set_normal(Vector3.UP)
				surface.surface_set_color(Color(1, 1, 1, fade * float(sample.strength)))
				surface.surface_set_uv(Vector2((edge + 1.0) * 0.5, float(sample.distance)))
				surface.surface_add_vertex(center + sample.right * edge * width)
		surface.surface_end()
