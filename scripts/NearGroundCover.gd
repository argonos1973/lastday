extends Node3D
## Bounded local detail. No saved state, collision or gameplay RNG.
const CELL := 6.0
const RADIUS := 4
const CANDIDATES_PER_CELL := 144
var world: Node3D
var chunks: Dictionary = {}
var pending: Array[Vector2i] = []
# Nodos+MultiMesh reciclados de chunks liberados: al cruzar el mapa andando se
# liberan/crean varios chunks por segundo; reutilizarlos evita alloc/free en
# el hilo principal. Tope pequeno: el coste del chunk es muestreo, no el nodo.
const POOL_MAX := 24
var _pool: Array[MultiMeshInstance3D] = []
var last_cell := Vector2i(2147483647,2147483647)
var last_quality := -1.0
var material: ShaderMaterial
var rock_surface: Dictionary = {}
var job: Dictionary = {}

func setup(source: Node3D) -> void:
	world = source
	world._ensure_grass_batches()
	material = world.grass_batch_material.duplicate()
	# Local detail has its own distance fade and uses engine time for wind.
	var shader := Shader.new()
	shader.code = world._wind_shader.code.replace("time_var *", "TIME *").replace("smoothstep(48.0, 68.0", "smoothstep(17.0, 23.0")
	material.shader = shader
	rock_surface = world._lake_granite_surface_grid()

func update_focus(focus: Vector3, quality: float) -> void:
	var cell := Vector2i(floori(focus.x/CELL),floori(focus.z/CELL))
	if cell != last_cell or not is_equal_approx(quality,last_quality):
		if not is_equal_approx(quality,last_quality):
			for chunk in chunks.values(): _release_chunk(chunk)
			chunks.clear()
		last_cell = cell
		last_quality = quality
		var wanted: Dictionary = {}
		var active_radius := 3 if quality < 0.8 else RADIUS
		for x in range(-active_radius,active_radius+1):
			for z in range(-active_radius,active_radius+1):
				if x*x+z*z > active_radius*active_radius: continue
				wanted[cell+Vector2i(x,z)] = true
		for key in chunks.keys():
			if not wanted.has(key):
				_release_chunk(chunks[key])
				chunks.erase(key)
		job.clear()
		pending.clear()
		for key: Vector2i in wanted:
			if not chunks.has(key): pending.append(key)
		pending.sort_custom(func(a: Vector2i,b: Vector2i): return (a-cell).length_squared() < (b-cell).length_squared())
	# One small chunk per frame: bounded work even after teleporting.
	if not pending.is_empty() and _build_chunk(pending[0],quality):
		pending.pop_front()

func _build_chunk(cell: Vector2i, quality: float) -> bool:
	if job.is_empty():
		var local_rng := RandomNumberGenerator.new()
		local_rng.seed = hash(cell) ^ 0x6A455
		job = {"rng":local_rng,"transforms":[],"colors":[],"next":0}
	var rng: RandomNumberGenerator = job.rng
	var transforms: Array = job.transforms
	var colors: Array = job.colors
	var origin := Vector3((cell.x+.5)*CELL,0,(cell.y+.5)*CELL)
	var started := Time.get_ticks_usec()

	# Presupuesto adaptativo: cola grande = prisa por rellenar (1.5 ms), cola
	# corta = repartir fino (0.7 ms) — mismo trabajo total, picos menores.
	var budget_us := 1500 if pending.size() > 4 else 700
	for i in range(int(job.next),CANDIDATES_PER_CELL):
		if Time.get_ticks_usec()-started > budget_us:
			break
		job.next = i+1
		var pos := origin + Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3))
		var density_sample := rng.randf()
		var quality_sample := rng.randf()
		var height := rng.randf_range(.12,.32)
		var radius := rng.randf_range(.16,.32)
		var yaw := rng.randf_range(0,TAU)
		var density: float = world._ground_patch_density(pos)
		if density_sample > lerpf(.18,.9,density) or quality_sample > clampf(quality/1.35,0.0,1.0): continue
		if not world._can_place_ground_vegetation(pos, .8, true): continue
		if preload("res://scripts/HighMountainZone.gd").blocks_vegetation(pos, -.22): continue
		var verge: float = world._road_verge_growth(pos)
		if verge <= 0.0 or density_sample > lerpf(.65,1.0,verge): continue
		pos.y = world._get_ground_height(pos)+.008
		var rock_cell := Vector2i((Vector2(pos.x,pos.z)/world.LAKE_ROCK_GRID).floor())
		if float(rock_surface.get(rock_cell,-INF)) > pos.y+.04: continue
		height *= lerpf(.45,1.0,verge)
		radius *= lerpf(.55,1.0,verge)
		transforms.append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3(radius,height,radius)),pos-origin))
		colors.append(Color(.20,.29,.105).lerp(Color(.32,.35,.17),density*.6))
	if int(job.next) < CANDIDATES_PER_CELL: return false
	var node: MultiMeshInstance3D = _pool.pop_back() if not _pool.is_empty() else MultiMeshInstance3D.new()
	if node.multimesh == null:
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.use_colors = true
	node.position = origin
	node.multimesh.mesh = world.grass_batch_meshes[posmod(hash(cell),world.grass_batch_meshes.size())]
	node.multimesh.instance_count = transforms.size()
	for i in range(transforms.size()):
		node.multimesh.set_instance_transform(i,transforms[i])
		node.multimesh.set_instance_color(i,colors[i])
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.layers = 1 << 18
	node.visible = true
	if node.get_parent() == null:
		add_child(node)
	chunks[cell] = node
	job.clear()
	return true

func _release_chunk(node: MultiMeshInstance3D) -> void:
	if _pool.size() >= POOL_MAX:
		node.queue_free()
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.multimesh.instance_count = 0
	_pool.append(node)
