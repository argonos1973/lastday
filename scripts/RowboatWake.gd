extends MeshInstance3D
# World-space wave ribbons: samples stay on the lake while the hull turns.
const LIFETIME := 8.0
const SAMPLE_INTERVAL := 0.08
var samples: Array[Dictionary] = []
var clock := 0.0
var sample_timer := 0.0
var distance_along := 0.0
var last_sample := Vector3.ZERO
var last_strength := 0.0
var track := 0

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
		track += 1
	# A restart or reversal must not connect two unrelated trails across the hull.
	if strength > 0.06 and last_strength <= 0.06:
		track += 1
	if not samples.is_empty() and stern.distance_to(last_sample) > 2.0:
		track += 1
	last_strength = strength
	while not samples.is_empty() and clock - float(samples[0].born) > LIFETIME:
		samples.pop_front()
	if strength > 0.06 and sample_timer >= SAMPLE_INTERVAL and not teleported:
		var distance := stern.distance_to(last_sample)
		if samples.is_empty() or distance > 0.07:
			distance_along += minf(distance, 1.0)
			var flat_right := Vector3(right.x, 0.0, right.z).normalized()
			samples.append({"pos": stern, "right": flat_right, "born": clock, "strength": strength, "distance": distance_along, "track": track})
			last_sample = stern
		sample_timer = 0.0
	_rebuild()

func _rebuild() -> void:
	var surface := mesh as ImmediateMesh
	surface.clear_surfaces()
	if samples.size() < 2:
		return
	# Two widening pairs of crests plus broken turbulence down the middle.
	# Vertices stay in world space; turning the hull cannot rotate old water.
	for band in [-2.0, -1.0, 0.0, 1.0, 2.0]:
		var begun := false
		for index in range(1, samples.size()):
			if samples[index].track != samples[index - 1].track:
				continue
			if not begun:
				surface.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				begun = true
			for vertex in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(1, -1), Vector2i(1, -1), Vector2i(0, 1), Vector2i(1, 1)]:
				_append_vertex(surface, samples[index - 1 + vertex.x], band, float(vertex.y))
		if begun:
			surface.surface_end()

func _append_vertex(surface: ImmediateMesh, sample: Dictionary, band: float, edge: float) -> void:
	var age: float = clock - float(sample.born)
	var fade := smoothstep(0.0, 0.18, age) * (1.0 - smoothstep(0.8, LIFETIME, age))
	var width := 0.13 + age * 0.055
	var expansion := 0.48 + age * (0.32 + float(sample.strength) * 0.18)
	if absf(band) == 2.0:
		expansion *= 1.48
		fade *= 0.32
	if band == 0.0:
		width = 0.4 + age * 0.1
		fade *= 0.65 * (1.0 - smoothstep(1.0, 5.0, age))
	var center: Vector3 = sample.pos + sample.right * signf(band) * expansion
	surface.surface_set_normal(Vector3.UP)
	surface.surface_set_color(Color(1 if band != 0.0 else 0, 1, 1, fade * sqrt(float(sample.strength))))
	surface.surface_set_uv(Vector2((edge + 1.0) * 0.5, float(sample.distance)))
	surface.surface_add_vertex(center + sample.right * edge * width)
