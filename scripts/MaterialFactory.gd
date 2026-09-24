class_name MaterialFactory
extends RefCounted

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
static var _camo_cache: Dictionary = {}

const POLY_GRASS_DRY_DIFF := "res://assets/external/polyhaven/grass_medium_01/textures/grass_medium_01_dry_diff_4k.png"
const POLY_ROCKY_TERRAIN_DIFF := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_diff_4k.jpg"
const POLY_RIVER_PEBBLES_DIFF := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_diff_4k.jpg"
const POLY_ROCK_07_DIFF := "res://assets/external/polyhaven/rock_07/textures/rock_07_diff_4k.jpg"
const CLOTH_DIR := "res://assets/textures/clothing/"
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

static func forest_variation_texture() -> Texture2D:
	if _tex_cache.has("forest_variation"):
		return _tex_cache["forest_variation"]
	var noise := FastNoiseLite.new()
	noise.seed = 1337
	noise.frequency = 0.035
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	_tex_cache["forest_variation"] = texture
	return texture

static func make_forest_ground_material() -> ShaderMaterial:
	if _mat_cache.has("forest_ground"):
		return _mat_cache["forest_ground"]
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/forest_ground.gdshader")
	var base := "res://assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_"
	material.set_shader_parameter("leaf_albedo", load_texture(base + "diffuse_2k.jpg"))
	material.set_shader_parameter("leaf_normal", load_texture(base + "nor_gl_2k.jpg"))
	material.set_shader_parameter("leaf_roughness", load_texture(base + "rough_2k.jpg"))
	material.set_shader_parameter("soil_albedo", load_texture(POLY_ROCKY_TERRAIN_DIFF))
	material.set_shader_parameter("variation", forest_variation_texture())
	_mat_cache["forest_ground"] = material
	return material

static func make_forest_rock_material(tint := Vector3(1.0, 1.0, 1.0)) -> ShaderMaterial:
	var key := "forest_rock" if tint == Vector3.ONE else "forest_rock_%s" % tint
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/forest_rock.gdshader")
	material.set_shader_parameter("rock_albedo", load_texture(POLY_ROCK_07_DIFF))
	material.set_shader_parameter("rock_height", load_texture("res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_disp_4k.png"))
	material.set_shader_parameter("variation", forest_variation_texture())
	material.set_shader_parameter("tint", tint)
	_mat_cache[key] = material
	return material

static func make_forest_foliage_material(source: StandardMaterial3D) -> ShaderMaterial:
	var key := "forest_foliage_%d" % source.get_instance_id()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/forest_foliage.gdshader")
	material.set_shader_parameter("albedo_texture", source.albedo_texture)
	material.set_shader_parameter("albedo_tint", source.albedo_color)
	material.set_shader_parameter("uv_scale", source.uv1_scale)
	material.set_shader_parameter("uv_offset", source.uv1_offset)
	material.set_shader_parameter("alpha_cutoff", source.alpha_scissor_threshold)
	_mat_cache[key] = material
	return material

static func _cloth_prefix(kind: String) -> String:
	if kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots"]:
		return "garment_" + kind
	return "cloth_" + kind

static func cloth_detail(m: StandardMaterial3D, kind: String, unit_scale: float = 1.0) -> void:
	var prefix := _cloth_prefix(kind)
	m.normal_enabled = true
	m.normal_texture = load_texture(CLOTH_DIR + prefix + "_normal.png")
	# Leather has broader grain; woven fabric needs subtler relief at game distance.
	m.normal_scale = 0.4 if kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots"] else 0.25
	m.roughness_texture = load_texture(CLOTH_DIR + prefix + "_roughness.png")
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.35 if kind in ["shoes", "boots", "gloves", "leather"] else 0.2
	# Baked AO darkens pockets, seams and folds; a touch of parallax lets the
	# garment relief shift with the view angle.
	var baked := kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots"]
	if baked:
		m.ao_enabled = true
		m.ao_texture = load_texture(CLOTH_DIR + prefix + "_ao.png")
		m.ao_light_affect = 0.1
		m.heightmap_enabled = true
		m.heightmap_texture = load_texture(CLOTH_DIR + prefix + "_height.png")
		m.heightmap_scale = 0.001
		m.heightmap_deep_parallax = false
		# The garment mesh hugs the skinned body; inflate it so the
		# Body_*/Desnudo_* surfaces can't poke through during animation.
		# Values are tuned for the player_with_clothes bind space (1.0 ≈ 1 cm);
		# meter-space models (Remy.glb previews, loose pickups) must pass
		# unit_scale=0.01 or the garment explodes metres off the body.
		m.grow = true
		m.grow_amount = {"top": 3.0, "bottom": 1.0, "soldier": 0.0, "shoes": 2.5, "boots": 1.0, "gloves": 0.6}.get(kind, 0.5) * unit_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

static func make_clothing_material(kind: String, color: Color, grow_override: float = -999.0, unit_scale: float = 1.0) -> StandardMaterial3D:
	var key := "cloth_%s_%s_%s_%s" % [kind, color.to_html(), grow_override, unit_scale]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var prefix := _cloth_prefix(kind)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load_texture(CLOTH_DIR + prefix + "_albedo.png")
	m.albedo_color = color
	cloth_detail(m, kind, unit_scale)
	if grow_override > -900.0:
		m.grow = true
		m.grow_amount = grow_override * unit_scale
	_mat_cache[key] = m
	return m

static func clothing_kind_for_mesh(mesh_name: String) -> String:
	var mesh_id := mesh_name.to_lower()
	if "soldier" in mesh_id:
		return "soldier"
	if mesh_id == "cloth_hands":
		return "gloves"
	if mesh_id == "cloth_feet":
		return "boots"
	if "shoes" in mesh_id:
		return "shoes"
	if "bottoms" in mesh_id:
		return "bottom"
	if "tops" in mesh_id:
		return "top"
	return ""

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
		mat.set_shader_parameter("mirror_color", Color(0.62, 0.78, 0.97))
		mat.set_shader_parameter("mirror_strength", 0.35)
		mat.set_shader_parameter("mirror_fresnel_power", 3.0)
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
			mat.set_shader_parameter("mirror_color", Color(0.62, 0.78, 0.97))
			mat.set_shader_parameter("mirror_strength", 0.35)
			mat.set_shader_parameter("mirror_fresnel_power", 3.0)
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

static func make_overgrowth_material(key: String, tp: String, scissor: float = 0.4, soft: bool = false) -> StandardMaterial3D:
	var ck := "overgrowth_" + key
	if _mat_cache.has(ck):
		return _mat_cache[ck]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 1)
	m.roughness = 0.95
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = load_texture(tp)
	if soft:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = scissor
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
