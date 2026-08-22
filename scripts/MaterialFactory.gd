class_name MaterialFactory
extends RefCounted

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _camo_cache: Dictionary = {}

const POLY_GRASS_DRY_DIFF := "res://assets/external/polyhaven/grass_medium_01/textures/grass_medium_01_dry_diff_4k.png"
const POLY_ROCKY_TERRAIN_DIFF := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_diff_4k.jpg"
const POLY_RIVER_PEBBLES_DIFF := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_diff_4k.jpg"
const SKY_HDRI_CANDIDATES := ["res://assets/hdri/kloofendal_48d_partly_cloudy_4k.exr"]
const REALISTIC_SKY_SHADER := "res://shaders/realistic_sky.gdshader"

static func resource_path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if FileAccess.file_exists(path):
		return true
	if path.begins_with("res://"):
		return FileAccess.file_exists(ProjectSettings.globalize_path(path))
	return false

static func load_texture(tp: String):
	if _tex_cache.has(tp):
		return _tex_cache[tp]
	var r = null
	if ResourceLoader.exists(tp):
		var lt = load(tp)
		if lt is Texture2D:
			r = lt
	if r == null:
		var dp := ProjectSettings.globalize_path(tp) if tp.begins_with("res://") else tp
		var img := Image.load_from_file(dp)
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			r = ImageTexture.create_from_image(img)
	_tex_cache[tp] = r
	return r

static func make_material(color: Color, noisy: bool) -> StandardMaterial3D:
	var key := "%0.2f_%0.2f_%0.2f_%s" % [color.r, color.g, color.b, str(noisy)]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.96
	m.metallic = 0.0
	if noisy:
		var n := FastNoiseLite.new()
		n.seed = randi()
		n.frequency = 0.085
		n.fractal_octaves = 3
		var t := NoiseTexture2D.new()
		t.width = 96
		t.height = 96
		t.noise = n
		m.albedo_texture = t
	_mat_cache[key] = m
	return m

static func make_textured_material(key: String, tp: String, fc: Color, uvs: Vector3, cutout := false) -> StandardMaterial3D:
	var ck := "textured_%s_%s_%s" % [key, tp, str(cutout)]
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = fc
	m.roughness = 0.92
	m.metallic = 0.0
	m.uv1_scale = uvs
	var tex = load_texture(tp)
	if tex != null:
		m.albedo_texture = tex
		m.albedo_color = Color(1, 1, 1)
	if tp == POLY_RIVER_PEBBLES_DIFF:
		m.roughness = 1.0
	if cutout:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.18
	_mat_cache[ck] = m
	return m

static func make_rocky_ground_material(fc: Color) -> StandardMaterial3D:
	if _mat_cache.has("rocky_ground"):
		return _mat_cache["rocky_ground"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.31, 0.30, 0.25).lerp(fc, 0.18)
	m.roughness = 1.0
	m.metallic = 0.0
	m.uv1_scale = Vector3(30.0, 30.0, 1.0)
	var rt = load_texture(POLY_ROCKY_TERRAIN_DIFF)
	if rt != null:
		m.albedo_texture = rt
	else:
		var n := FastNoiseLite.new()
		n.seed = randi()
		n.frequency = 0.18
		n.fractal_octaves = 5
		var t := NoiseTexture2D.new()
		t.width = 256
		t.height = 256
		t.noise = n
		m.albedo_texture = t
	_mat_cache["rocky_ground"] = m
	return m

static func make_main_ground_material(_fc: Color) -> StandardMaterial3D:
	if _mat_cache.has("main_ground"):
		return _mat_cache["main_ground"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.46, 0.62, 0.32)
	m.roughness = 1.0
	m.metallic = 0.0
	m.uv1_scale = Vector3(44.0, 44.0, 1.0)
	var gt = load_texture(POLY_ROCKY_TERRAIN_DIFF)
	if gt != null:
		m.albedo_texture = gt
	else:
		var ft = load_texture(POLY_GRASS_DRY_DIFF)
		if ft != null:
			m.albedo_texture = ft
	_mat_cache["main_ground"] = m
	return m

static func make_grass_blade_material() -> StandardMaterial3D:
	if _mat_cache.has("grass_blade"):
		return _mat_cache["grass_blade"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.19, 0.42, 0.12)
	m.roughness = 1.0
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache["grass_blade"] = m
	return m

static func make_river_water_material() -> Material:
	if _mat_cache.has("river_water"):
		return _mat_cache["river_water"]
	var mat: ShaderMaterial = null
	var tres = load("res://shaders/river_water.tres")
	if tres is ShaderMaterial:
		mat = (tres as ShaderMaterial).duplicate()
		mat.set_shader_parameter("wave_height", 0.06)
		mat.set_shader_parameter("wave_speed", 0.15)
		mat.set_shader_parameter("wave_scale", 6.0)
		mat.set_shader_parameter("flow_speed", 0.35)
		mat.set_shader_parameter("foam_scale", 3.0)
		mat.set_shader_parameter("foam_falloff_distance", 0.35)
		mat.set_shader_parameter("night_amount", 0.0)
		mat.set_shader_parameter("night_water_color", Color(0.012, 0.035, 0.060))
	if mat == null:
		var shader = load("res://shaders/water.gdshader")
		if shader is Shader:
			mat = ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("water_color", Color(0.08, 0.304, 0.5, 1.0))
			mat.set_shader_parameter("use_vertex_waves", true)
			mat.set_shader_parameter("wave_height", 1.0)
			mat.set_shader_parameter("wave_speed", 0.01)
			mat.set_shader_parameter("use_river_flow", true)
			mat.set_shader_parameter("flow_speed", 0.1)
			mat.set_shader_parameter("flow_direction_multiplier", -1.0)
			mat.set_shader_parameter("uv1_scale", Vector2(20, 1))
			mat.set_shader_parameter("use_foam", true)
			mat.set_shader_parameter("foam_uv_scale", 0.5)
			mat.set_shader_parameter("foam_scale", 6.0)
			mat.set_shader_parameter("foam_speed", 0.2)
			mat.set_shader_parameter("foam_falloff_distance", 0.1)
			mat.set_shader_parameter("foam_edge_distance", 0.1)
			mat.set_shader_parameter("foam_edge_bias", 1.0)
			mat.set_shader_parameter("night_amount", 0.0)
			mat.set_shader_parameter("night_water_color", Color(0.012, 0.035, 0.060))
			mat.set_shader_parameter("double_sided", true)
			mat.set_shader_parameter("surface_bottom", Color(0.045, 0.125, 0.170, 0.65))
			mat.set_shader_parameter("depth_distance", 0.6)
			mat.set_shader_parameter("water_color_ratio", 0.1)
			mat.set_shader_parameter("beers_law", 1.0)
			mat.set_shader_parameter("normal_scale", 1.0)
			mat.set_shader_parameter("roughness_scale", 0.0)
	_mat_cache["river_water"] = mat
	return mat

static func make_shader_sky_material() -> ShaderMaterial:
	if not ResourceLoader.exists(REALISTIC_SKY_SHADER):
		return null
	var s = load(REALISTIC_SKY_SHADER)
	if s == null or not (s is Shader):
		return null
	var m := ShaderMaterial.new()
	m.shader = s
	return m

static func make_hdri_sky_material() -> PanoramaSkyMaterial:
	for tp in SKY_HDRI_CANDIDATES:
		if not resource_path_exists(tp):
			continue
		var p = load_texture(tp)
		if p == null:
			continue
		var m := PanoramaSkyMaterial.new()
		m.panorama = p
		m.energy_multiplier = 0.82
		return m
	return null

static func make_tree_billboard_material(tp: String) -> StandardMaterial3D:
	var key := "tree_billboard_" + tp
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 1)
	m.roughness = 0.92
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.06
	m.albedo_texture = load_texture(tp)
	_mat_cache[key] = m
	return m

static func make_cutout_material(key: String, tp: String, _ap: String) -> StandardMaterial3D:
	var ck := "cutout_" + key
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 1)
	m.roughness = 0.92
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.12
	m.albedo_texture = load_texture(tp)
	_mat_cache[ck] = m
	return m

static func make_camo_texture(bc: Color = Color(0.2, 0.25, 0.15)) -> ImageTexture:
	var ck := str(bc)
	if _camo_cache.has(ck):
		return _camo_cache[ck]
	var sz := 128
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var cc := [bc, bc.darkened(0.3), bc.lightened(0.2), bc.darkened(0.5)]
	img.fill(cc[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _b in range(40):
		var cx := rng.randi_range(0, sz - 1)
		var cy := rng.randi_range(0, sz - 1)
		var rad := rng.randi_range(8, 25)
		var col: Color = cc[rng.randi() % cc.size()]
		for x in range(maxi(0, cx - rad), mini(sz, cx + rad)):
			for y in range(maxi(0, cy - rad), mini(sz, cy + rad)):
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy <= rad * rad:
					img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_camo_cache[ck] = tex
	return tex

static func make_fire_ramp() -> GradientTexture1D:
	var g := Gradient.new()
	g.add_point(0.0, Color(1.0, 0.9, 0.3, 1.0))
	g.add_point(0.3, Color(1.0, 0.5, 0.1, 0.9))
	g.add_point(0.7, Color(0.8, 0.15, 0.02, 0.5))
	g.add_point(1.0, Color(0.2, 0.05, 0.0, 0.0))
	var t := GradientTexture1D.new()
	t.gradient = g
	return t

static func make_fire_gradient() -> Gradient:
	var g := Gradient.new()
	g.add_point(0.0, Color(1.0, 0.9, 0.3, 1.0))
	g.add_point(0.3, Color(1.0, 0.5, 0.1, 0.9))
	g.add_point(0.7, Color(0.8, 0.15, 0.02, 0.5))
	g.add_point(1.0, Color(0.2, 0.05, 0.0, 0.0))
	return g
