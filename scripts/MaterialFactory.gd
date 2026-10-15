class_name MaterialFactory
extends RefCounted

static var _mat_cache: Dictionary = {}
static var _tex_cache: Dictionary = {}
const CAMO_WOODLAND: Texture2D = preload("res://assets/textures/clothing/camouflage_woodland.png")
const CAMO_DESERT: Texture2D = preload("res://assets/textures/clothing/camouflage_desert.png")

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

# Fur of the hunted species projected over a garment mesh. The clothing UVs
# were authored for cloth prints, so the hide goes through the triplanar
# shader — the jacket reads as wolf/deer/fox/bear/bird fur on any mesh.
static var _pelt_mat_cache: Dictionary = {}

static func pelt_fur_material(species: String) -> Material:
	if species.is_empty():
		return null
	if _pelt_mat_cache.has(species):
		return _pelt_mat_cache[species]
	var tex := _pelt_fur_texture(species)
	if tex == null:
		_pelt_mat_cache[species] = null
		return null
	var sm := ShaderMaterial.new()
	var sh: Shader = load("res://shaders/pelt_fur.gdshader")
	if sh == null:
		_pelt_mat_cache[species] = null
		return null
	sm.shader = sh
	sm.set_shader_parameter("fur_tex", tex)
	_pelt_mat_cache[species] = sm
	return sm

static func _pelt_fur_texture(species: String) -> Texture2D:
	var path := str(GameConst.PELT_FUR_TEXTURES.get(species, ""))
	if path.is_empty():
		return null
	return load_texture(path) as Texture2D

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
	material.set_shader_parameter("rock_albedo", load_texture("res://assets/models/props/lake/lake_boulder_0_lake_granite.jpg"))
	material.set_shader_parameter("rock_height", load_texture("res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_disp_4k.png"))
	material.set_shader_parameter("variation", forest_variation_texture())
	material.set_shader_parameter("tint", tint)
	_mat_cache[key] = material
	return material

static func make_lake_rock_material(source: StandardMaterial3D, ground_y: float, center: Vector3, size: Vector2, yaw: float) -> ShaderMaterial:
	var key := "lake_rock_%d_%s_%s_%s_%s" % [source.get_instance_id(), ground_y, center, size, yaw]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var material := make_forest_rock_material().duplicate() as ShaderMaterial
	var ground := make_forest_ground_material()
	material.set_shader_parameter("shore_blend", true)
	material.set_shader_parameter("rock_albedo", source.albedo_texture)
	material.set_shader_parameter("shore_normal", source.normal_texture)
	material.set_shader_parameter("shore_roughness", source.roughness_texture)
	material.set_shader_parameter("shore_roughness_channel", source.roughness_texture_channel)
	material.set_shader_parameter("leaf_albedo", ground.get_shader_parameter("leaf_albedo"))
	material.set_shader_parameter("soil_albedo", ground.get_shader_parameter("soil_albedo"))
	material.set_shader_parameter("shore_ground_y", ground_y)
	material.set_shader_parameter("shore_water_y", center.y)
	material.set_shader_parameter("shore_center", Vector2(center.x, center.z))
	material.set_shader_parameter("shore_radii", size * .425)
	material.set_shader_parameter("shore_yaw", deg_to_rad(yaw))
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
	if kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots", "mboots"]:
		return "garment_" + kind
	return "cloth_" + kind

static func cloth_detail(m: StandardMaterial3D, kind: String, unit_scale: float = 1.0) -> void:
	var prefix := _cloth_prefix(kind)
	m.normal_enabled = true
	m.normal_texture = load_texture(CLOTH_DIR + prefix + "_normal.png")
	# Leather has broader grain; woven fabric needs subtler relief at game distance.
	m.normal_scale = 0.4 if kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots", "mboots"] else 0.25
	m.roughness_texture = load_texture(CLOTH_DIR + prefix + "_roughness.png")
	m.roughness = 1.0
	m.metallic = 0.0
	m.metallic_specular = 0.35 if kind in ["shoes", "boots", "mboots", "gloves", "leather"] else 0.2
	# Baked AO darkens pockets, seams and folds; a touch of parallax lets the
	# garment relief shift with the view angle.
	var baked := kind in ["top", "bottom", "shoes", "soldier", "gloves", "boots", "mboots"]
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
		m.grow_amount = {"top": 3.0, "bottom": 1.0, "soldier": 0.0, "shoes": 2.5, "boots": 1.0, "mboots": 0.6, "gloves": 0.6}.get(kind, 0.5) * unit_scale
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
	if mesh_id == "military_boots":
		return "mboots"
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
		mat.set_shader_parameter("flow_speed", 0.35)
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
			mat.set_shader_parameter("water_color", Color(0.055, 0.105, 0.085))
			mat.set_shader_parameter("use_vertex_waves", true)
			mat.set_shader_parameter("use_river_flow", true)
			mat.set_shader_parameter("flow_direction_multiplier", -1.0)
			mat.set_shader_parameter("use_foam", true)
			mat.set_shader_parameter("night_amount", 0.0)
			mat.set_shader_parameter("night_water_color", Color(0.012, 0.035, 0.060))
			mat.set_shader_parameter("beers_law", 0.8)
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

static func make_camo_texture(bc: Color = Color(0.2, 0.25, 0.15)) -> Texture2D:
	# The Blender-baked woodland and desert prints share the same stitched
	# fabric scale across the character, preview, and inventory thumbnail.
	return CAMO_DESERT if bc.r > 0.27 and bc.g > 0.25 else CAMO_WOODLAND

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

static func build_pelt_hide_mesh(pelt_species: String) -> MeshInstance3D:
	var sp := pelt_species.strip_edges().to_lower()
	if sp.begins_with("piel de "):
		sp = sp.trim_prefix("piel de ").strip_edges()
	var fur_color := Color(0.38, 0.27, 0.16)
	match sp:
		"zorro": fur_color = Color(0.55, 0.25, 0.10)
		"oso": fur_color = Color(0.22, 0.15, 0.10)
		"lobo": fur_color = Color(0.42, 0.41, 0.38)
		"ave": fur_color = Color(0.46, 0.41, 0.30)
	# Realistic stretched animal hide silhouette (neck, front legs, waist, hind legs, tail)
	var outline := PackedVector3Array([
		Vector3(0.0, 0.022, -0.38),     # Neck tip
		Vector3(0.09, 0.020, -0.33),    # Right shoulder
		Vector3(0.28, 0.012, -0.28),    # Right front paw out
		Vector3(0.25, 0.014, -0.18),    # Right front armpit
		Vector3(0.18, 0.024, -0.02),    # Right flank waist
		Vector3(0.29, 0.012, 0.20),     # Right hind paw out
		Vector3(0.19, 0.015, 0.28),     # Right hind inner
		Vector3(0.06, 0.018, 0.33),     # Tail base right
		Vector3(0.0, 0.010, 0.42),      # Tail tip
		Vector3(-0.06, 0.018, 0.33),    # Tail base left
		Vector3(-0.19, 0.015, 0.28),    # Left hind inner
		Vector3(-0.29, 0.012, 0.20),    # Left hind paw out
		Vector3(-0.18, 0.024, -0.02),   # Left flank waist
		Vector3(-0.25, 0.014, -0.18),   # Left front armpit
		Vector3(-0.28, 0.012, -0.28),   # Left front paw out
		Vector3(-0.09, 0.020, -0.33),   # Left shoulder
	])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var spine := [
		Vector3(0.0, 0.036, -0.18),
		Vector3(0.0, 0.040, 0.0),
		Vector3(0.0, 0.034, 0.18),
	]
	var center: Vector3 = spine[1]
	var n_pts := outline.size()
	for i in range(n_pts):
		var a: Vector3 = outline[i]
		var b: Vector3 = outline[(i + 1) % n_pts]
		var shade := 0.90 + float((i * 5) % 4) * 0.035
		var col := Color(fur_color.r * shade, fur_color.g * shade, fur_color.b * shade, 1.0)
		# Top fur face
		st.set_color(col)
		st.set_uv(Vector2(0.5, 0.5))
		st.add_vertex(center)
		st.set_color(col)
		st.set_uv(Vector2(a.x + 0.5, a.z + 0.5))
		st.add_vertex(a)
		st.set_color(col)
		st.set_uv(Vector2(b.x + 0.5, b.z + 0.5))
		st.add_vertex(b)
		# Underside leather face so thickness reads from any angle
		var a_low := a - Vector3(0.0, 0.014, 0.0)
		var b_low := b - Vector3(0.0, 0.014, 0.0)
		st.set_color(col.darkened(0.25))
		st.set_uv(Vector2(a.x + 0.5, a.z + 0.5))
		st.add_vertex(a)
		st.add_vertex(a_low)
		st.add_vertex(b_low)
		st.add_vertex(a)
		st.add_vertex(b_low)
		st.add_vertex(b)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "PeltHideMesh"
	mi.mesh = st.commit()
	var pelt_mat := pelt_fur_material(sp) if not sp.is_empty() else null
	if pelt_mat != null:
		mi.material_override = pelt_mat
	else:
		var fallback := StandardMaterial3D.new()
		fallback.vertex_color_use_as_albedo = true
		fallback.roughness = 0.94
		fallback.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = fallback
	return mi

static func make_log_bark_material() -> StandardMaterial3D:
	if _mat_cache.has("realistic_log_bark"):
		return _mat_cache["realistic_log_bark"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load_texture("res://assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_bark_diff_4k.png")
	m.albedo_color = Color(0.76, 0.68, 0.58)
	m.normal_enabled = true
	m.normal_texture = load_texture("res://assets/textures/overgrowth/village_wood_normal.png")
	m.normal_scale = 1.65
	m.roughness_texture = load_texture("res://assets/textures/overgrowth/village_wood_roughness.png")
	m.roughness = 0.96
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3(1.8, 1.8, 1.8)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat_cache["realistic_log_bark"] = m
	return m

static func make_log_end_material() -> ShaderMaterial:
	if _mat_cache.has("realistic_log_end"):
		return _mat_cache["realistic_log_end"]
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 lpos;
void vertex() {
	lpos = VERTEX;
}
void fragment() {
	vec2 p = lpos.xz * 6.5;
	float r = length(p);
	float a = atan(p.y, p.x);
	float wobble = sin(a * 5.0) * 0.04 + cos(a * 11.0) * 0.02;
	float rings = sin((r + wobble) * 42.0) * 0.5 + 0.5;
	float fine = sin((r + wobble * 0.5) * 110.0) * 0.5 + 0.5;
	// Radial drying cracks from pith
	float crack = smoothstep(0.96, 0.995, cos(a * 3.0 + 0.7)) * smoothstep(0.05, 0.65, r) * smoothstep(0.95, 0.4, r);
	vec3 heartwood = vec3(0.46, 0.30, 0.16);
	vec3 sapwood = vec3(0.74, 0.58, 0.36);
	vec3 col = mix(heartwood, sapwood, smoothstep(0.22, 0.78, r));
	col *= mix(0.78, 1.08, rings * 0.7 + fine * 0.3);
	col = mix(col, vec3(0.14, 0.09, 0.05), crack * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.88;
	METALLIC = 0.0;
}
"""
	sm.shader = sh
	_mat_cache["realistic_log_end"] = sm
	return sm

static func apply_realistic_log_materials(root: Node) -> void:
	if root == null:
		return
	var bark_mat := make_log_bark_material()
	var end_mat := make_log_end_material()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back() as Node
		for ch in n.get_children():
			stack.append(ch)
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var scount := mi.mesh.get_surface_count()
		if scount <= 1:
			mi.material_override = bark_mat
		else:
			mi.material_override = null
			for s in range(scount):
				var smat := mi.mesh.surface_get_material(s)
				var mname := str(smat.resource_name).to_lower() if smat != null else ""
				var is_end := ("tan" in mname or "wood" in mname or "inner" in mname or "top" in mname or s == 1) and not ("bark" in mname or "brown" in mname)
				mi.set_surface_override_material(s, end_mat if is_end else bark_mat)

static func apply_realistic_shelter_materials(root: Node) -> void:
	if root == null:
		return
	var bark_mat := make_log_bark_material()
	var litter_tex: Texture2D = load_texture("res://assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_diffuse_2k.jpg") as Texture2D
	var litter_nor: Texture2D = load_texture("res://assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_nor_gl_2k.jpg") as Texture2D
	var rope_tex: Texture2D = load_texture("res://assets/textures/overgrowth/village_ochre_albedo.png") as Texture2D
	var rope_nor: Texture2D = load_texture("res://assets/textures/overgrowth/village_ochre_normal.png") as Texture2D
	var rock_mat := make_forest_rock_material(Vector3(0.28, 0.32, 0.24))
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n := stack.pop_back() as Node
		for ch in n.get_children():
			stack.append(ch)
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var smat := mi.mesh.surface_get_material(s)
			var mname := str(smat.resource_name).to_lower() if smat != null else ""
			if "bark" in mname:
				mi.set_surface_override_material(s, bark_mat)
			elif "stone" in mname or "rock" in mname:
				mi.set_surface_override_material(s, rock_mat)
			elif "fibre" in mname or "lashing" in mname or "rope" in mname:
				var rkey := "shelter_rope_pbr"
				if not _mat_cache.has(rkey):
					var rm := StandardMaterial3D.new()
					rm.albedo_texture = rope_tex
					rm.albedo_color = Color(0.62, 0.48, 0.30)
					rm.normal_enabled = true
					rm.normal_texture = rope_nor
					rm.normal_scale = 1.4
					rm.roughness = 0.92
					rm.uv1_triplanar = true
					rm.uv1_scale = Vector3(4.0, 4.0, 4.0)
					_mat_cache[rkey] = rm
				mi.set_surface_override_material(s, _mat_cache[rkey])
			elif "litter" in mname or "leaf" in mname or "foliage" in mname:
				var lkey := "shelter_" + mname
				if not _mat_cache.has(lkey):
					var lm := StandardMaterial3D.new()
					lm.albedo_texture = litter_tex
					if "foliage" in mname:
						lm.albedo_color = Color(0.42, 0.56, 0.26)
					elif "dry leaf" in mname:
						lm.albedo_color = Color(0.66, 0.52, 0.28)
					else:
						lm.albedo_color = Color(0.54, 0.45, 0.26)
					lm.normal_enabled = true
					lm.normal_texture = litter_nor
					lm.normal_scale = 1.35
					lm.roughness = 0.94
					lm.cull_mode = BaseMaterial3D.CULL_DISABLED
					lm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					_mat_cache[lkey] = lm
				mi.set_surface_override_material(s, _mat_cache[lkey])
