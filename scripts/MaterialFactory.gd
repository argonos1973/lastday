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
	if mesh_id == "military_boots" or mesh_id == "boots_pickup":
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

static func build_rag_mesh() -> MeshInstance3D:
	# Crumpled pile of cut rags: several folded cloth strips with ragged
	# edges, stacked at odd yaws. The survival kit has no cloth model and the
	# old flat cylinder read wrong on the ground and in thumbnails.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7311
	var light := Color(0.80, 0.72, 0.55)
	var dark := Color(0.42, 0.36, 0.27)
	var strips := [
		{"yaw": 0.15, "y": 0.004, "hw": 0.150, "hd": 0.085, "h": 0.038},
		{"yaw": 1.85, "y": 0.016, "hw": 0.135, "hd": 0.075, "h": 0.030},
		{"yaw": 3.60, "y": 0.028, "hw": 0.120, "hd": 0.070, "h": 0.026},
		{"yaw": 4.90, "y": 0.012, "hw": 0.110, "hd": 0.060, "h": 0.022},
	]
	for spec in strips:
		var col := light.lerp(dark, rng.randf() * 0.55)
		var fold_col := col.lightened(0.12)
		var hw: float = spec["hw"]
		var hd: float = spec["hd"]
		var h: float = spec["h"]
		var y0: float = spec["y"]
		var p := [
			Vector3(-hw + rng.randf_range(-0.02, 0.02), y0, -hd + rng.randf_range(-0.015, 0.015)),
			Vector3( hw + rng.randf_range(-0.02, 0.02), y0, -hd + rng.randf_range(-0.015, 0.015)),
			Vector3( hw * 0.92, y0 + h, rng.randf_range(-0.02, 0.02)),
			Vector3(-hw * 0.92, y0 + h, rng.randf_range(-0.02, 0.02)),
			Vector3( hw + rng.randf_range(-0.02, 0.02), y0,  hd + rng.randf_range(-0.015, 0.015)),
			Vector3(-hw + rng.randf_range(-0.02, 0.02), y0,  hd + rng.randf_range(-0.015, 0.015)),
		]
		var rot := Transform3D(Basis(Vector3.UP, spec["yaw"]), Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.03, 0.03)))
		for i in range(p.size()):
			p[i] = rot * p[i]
		for t in [[0, 1, 2], [0, 2, 3], [3, 2, 4], [3, 4, 5]]:
			for vi in t:
				st.set_color(fold_col if vi == 2 or vi == 3 else col)
				st.add_vertex(p[vi])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "RagPileMesh"
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi

static func make_log_bark_material() -> StandardMaterial3D:
	if _mat_cache.has("realistic_log_bark"):
		return _mat_cache["realistic_log_bark"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load_texture("res://assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_bark_diff_4k.png")
	m.albedo_color = Color(0.92, 0.78, 0.62)
	m.normal_enabled = true
	m.normal_texture = load_texture("res://assets/textures/overgrowth/village_wood_normal.png")
	m.normal_scale = 1.45
	m.roughness_texture = load_texture("res://assets/textures/overgrowth/village_wood_roughness.png")
	m.roughness = 0.88
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
	vec3 heartwood = vec3(0.56, 0.37, 0.20);
	vec3 sapwood = vec3(0.84, 0.68, 0.44);
	vec3 col = mix(heartwood, sapwood, smoothstep(0.22, 0.78, r));
	col *= mix(0.82, 1.12, rings * 0.7 + fine * 0.3);
	col = mix(col, vec3(0.18, 0.11, 0.06), crack * 0.85);
	ALBEDO = col;
	EMISSION = col * 0.06;
	ROUGHNESS = 0.84;
	METALLIC = 0.0;
}
"""
	sm.shader = sh
	_mat_cache["realistic_log_end"] = sm
	return sm

static func _get_unified_log_shader() -> Shader:
	if _mat_cache.has("unified_log_shader_res"):
		return _mat_cache["unified_log_shader_res"]
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D bark_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark_nor : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int axis_mode = 2;
uniform vec2 cross_center = vec2(0.0, 0.0);
uniform float cross_radius = 0.125;
uniform vec3 bark_tint = vec3(0.94, 0.78, 0.60);
varying vec3 lpos;
varying vec3 lnorm;

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	float axial_n = abs(lnorm.z);
	vec2 cross_p = lpos.xy;
	vec2 bark_uv = vec2(atan(lpos.y - cross_center.y, lpos.x - cross_center.x) * 0.45, lpos.z * 1.6);
	if (axis_mode == 0) {
		axial_n = abs(lnorm.x);
		cross_p = lpos.yz;
		bark_uv = vec2(atan(lpos.z - cross_center.y, lpos.y - cross_center.x) * 0.45, lpos.x * 4.5);
	} else if (axis_mode == 1) {
		axial_n = abs(lnorm.y);
		cross_p = lpos.xz;
		bark_uv = vec2(atan(lpos.z - cross_center.y, lpos.x - cross_center.x) * 0.45, lpos.y * 1.6);
	}
	float cap_mask = smoothstep(0.52, 0.68, axial_n);
	vec2 p = (cross_p - cross_center) / max(cross_radius, 0.015);
	float r = length(p);
	float a = atan(p.y, p.x);
	float wobble = sin(a * 5.0) * 0.04 + cos(a * 11.0) * 0.02;
	float rings = sin((r + wobble) * 28.0) * 0.5 + 0.5;
	float fine = sin((r + wobble * 0.5) * 76.0) * 0.5 + 0.5;
	float crack = smoothstep(0.95, 0.995, cos(a * 3.0 + 0.7)) * smoothstep(0.06, 0.65, r) * smoothstep(0.92, 0.4, r);
	vec3 heartwood = vec3(0.58, 0.38, 0.20);
	vec3 sapwood = vec3(0.86, 0.71, 0.46);
	vec3 end_col = mix(heartwood, sapwood, smoothstep(0.20, 0.76, r));
	end_col *= mix(0.82, 1.12, rings * 0.72 + fine * 0.28);
	end_col = mix(end_col, vec3(0.20, 0.12, 0.06), crack * 0.85);
	// Outer bark collar around the cut face
	float collar = smoothstep(0.84, 0.96, r);
	end_col = mix(end_col, vec3(0.34, 0.23, 0.14), collar);

	vec3 btex = texture(bark_tex, bark_uv).rgb;
	// Warm amber-brown bark with bright ridge contrast so logs stand out on dark floors
	vec3 bark_col = mix(vec3(0.36, 0.24, 0.14), vec3(0.72, 0.54, 0.35), smoothstep(0.15, 0.82, dot(btex, vec3(0.333)))) * bark_tint;
	vec3 n_sample = texture(bark_nor, bark_uv * 1.4).rgb * 2.0 - 1.0;

	vec3 final_col = mix(bark_col, end_col, cap_mask);
	ALBEDO = final_col;
	EMISSION = final_col * 0.07;
	NORMAL = normalize(NORMAL + n_sample * (1.0 - cap_mask) * 0.45);
	ROUGHNESS = mix(0.86, 0.80, cap_mask);
	METALLIC = 0.0;
	SPECULAR = 0.28;
}
"""
	_mat_cache["unified_log_shader_res"] = sh
	return sh

static func apply_realistic_log_materials(root: Node) -> void:
	if root == null:
		return
	var bark_tex: Texture2D = load_texture("res://assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_bark_diff_4k.png") as Texture2D
	var bark_nor: Texture2D = load_texture("res://assets/textures/overgrowth/village_wood_normal.png") as Texture2D
	var sh := _get_unified_log_shader()
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
		var aabb := mi.get_aabb()
		var sx := aabb.size.x
		var sy := aabb.size.y
		var sz := aabb.size.z
		var axis_mode := 2
		var c_center := Vector2(aabb.position.x + sx * 0.5, aabb.position.y + sy * 0.5)
		var c_radius := maxf(sx, sy) * 0.5
		if sx >= sy and sx >= sz:
			axis_mode = 0
			c_center = Vector2(aabb.position.y + sy * 0.5, aabb.position.z + sz * 0.5)
			c_radius = maxf(sy, sz) * 0.5
		elif sy >= sx and sy >= sz:
			axis_mode = 1
			c_center = Vector2(aabb.position.x + sx * 0.5, aabb.position.z + sz * 0.5)
			c_radius = maxf(sx, sz) * 0.5
		var is_stick := ("cylinder" in str(mi.name).to_lower()) or ("stick" in str(mi.name).to_lower()) or ("stick" in str(root.name).to_lower())
		var cache_key := "unified_log_%d_%.3f_%.3f_%.3f_%d" % [axis_mode, c_center.x, c_center.y, c_radius, 1 if is_stick else 0]
		var sm: ShaderMaterial = _mat_cache.get(cache_key)
		if sm == null:
			sm = ShaderMaterial.new()
			sm.shader = sh
			sm.set_shader_parameter("bark_tex", bark_tex)
			sm.set_shader_parameter("bark_nor", bark_nor)
			sm.set_shader_parameter("axis_mode", axis_mode)
			sm.set_shader_parameter("cross_center", c_center)
			sm.set_shader_parameter("cross_radius", maxf(c_radius, 0.02))
			sm.set_shader_parameter("bark_tint", Vector3(1.10, 0.94, 0.72) if is_stick else Vector3(0.96, 0.82, 0.64))
			_mat_cache[cache_key] = sm
		mi.material_override = sm

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

static func build_primitive_item_mesh(item_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = "PrimitiveVisual"
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.28, 0.15)
	wood_mat.roughness = 0.88
	var bone_mat := StandardMaterial3D.new()
	bone_mat.albedo_color = Color(0.86, 0.83, 0.75)
	bone_mat.roughness = 0.72
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.46, 0.45, 0.42)
	stone_mat.roughness = 0.92
	var granite_diff_path := "res://assets/models/props/lake/lake_boulder_0_lake_granite.jpg"
	var stone_tex: Texture2D = load_texture(granite_diff_path) as Texture2D
	if stone_tex == null:
		stone_tex = load_texture(POLY_ROCKY_TERRAIN_DIFF) as Texture2D
	if stone_tex != null:
		stone_mat.albedo_texture = stone_tex
		stone_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
		stone_mat.uv1_offset = Vector3(0.25, 0.25, 0.0)
	var cord_mat := StandardMaterial3D.new()
	cord_mat.albedo_color = Color(0.62, 0.50, 0.34)
	cord_mat.roughness = 0.88
	var wrap_mat := StandardMaterial3D.new()
	wrap_mat.albedo_color = Color(0.36, 0.25, 0.14)
	wrap_mat.roughness = 0.90
	var feather_mat := StandardMaterial3D.new()
	feather_mat.albedo_color = Color(0.78, 0.76, 0.72)
	feather_mat.roughness = 0.80
	feather_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	match item_name:
		"Arco de madera", "Arco reforzado":
			var is_reinf := item_name == "Arco reforzado"
			var segs := 8
			for i in range(segs):
				var t0 := -0.52 + float(i) / float(segs) * 1.04
				var t1 := -0.52 + float(i + 1) / float(segs) * 1.04
				var tm := (t0 + t1) * 0.5
				var z_curve := (0.27 - tm * tm) * 0.75
				var seg := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.014 - absf(tm) * 0.012
				cyl.bottom_radius = 0.016 - absf(tm) * 0.012
				cyl.height = 0.145
				seg.mesh = cyl
				seg.position = Vector3(0.0, tm, -z_curve)
				seg.rotation.x = -tm * 0.65
				seg.material_override = bone_mat if (is_reinf and (i == 0 or i == segs - 1 or i == 3 or i == 4)) else wood_mat
				root.add_child(seg)
			var string_mi := MeshInstance3D.new()
			var scyl := CylinderMesh.new()
			scyl.top_radius = 0.0025
			scyl.bottom_radius = 0.0025
			scyl.height = 1.02
			string_mi.mesh = scyl
			string_mi.position = Vector3(0.0, 0.0, 0.01)
			string_mi.material_override = cord_mat
			root.add_child(string_mi)
		"Flecha improvisada":
			# Bare sharpened stick: no stone tip, no fletching — crude but
			# craftable from a single stick and any edged tool.
			var ishaft := MeshInstance3D.new()
			var icyl := CylinderMesh.new()
			icyl.top_radius = 0.006
			icyl.bottom_radius = 0.0075
			icyl.height = 0.60
			ishaft.mesh = icyl
			ishaft.rotation_degrees.x = 90.0
			ishaft.material_override = wood_mat
			root.add_child(ishaft)
			var itip := MeshInstance3D.new()
			var itip_cyl := CylinderMesh.new()
			itip_cyl.top_radius = 0.001
			itip_cyl.bottom_radius = 0.0075
			itip_cyl.height = 0.12
			itip.mesh = itip_cyl
			itip.position = Vector3(0.0, 0.0, -0.355)
			itip.rotation_degrees.x = -90.0
			itip.material_override = wood_mat
			root.add_child(itip)
		"Flecha de madera", "Flecha de piedra", "Flecha de hueso":
			var shaft := MeshInstance3D.new()
			var scyl := CylinderMesh.new()
			scyl.top_radius = 0.0045
			scyl.bottom_radius = 0.0045
			scyl.height = 0.68
			shaft.mesh = scyl
			shaft.rotation_degrees.x = 90.0
			shaft.material_override = wood_mat
			root.add_child(shaft)
			var tip := MeshInstance3D.new()
			var tip_cyl := CylinderMesh.new()
			tip_cyl.top_radius = 0.001
			tip_cyl.bottom_radius = 0.011
			tip_cyl.height = 0.065
			tip.mesh = tip_cyl
			tip.position = Vector3(0.0, 0.0, -0.36)
			tip.rotation_degrees.x = -90.0
			tip.material_override = bone_mat if item_name == "Flecha de hueso" else (stone_mat if item_name == "Flecha de piedra" else wood_mat)
			root.add_child(tip)
			for f_ang in [0.0, 120.0, 240.0]:
				var van := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(0.002, 0.022, 0.085)
				van.mesh = box
				van.position = Vector3(0.0, 0.0, 0.28)
				van.rotation_degrees.z = f_ang
				van.material_override = feather_mat
				root.add_child(van)
		"Lanza", "Lanza de hueso", "Palo afilado":
			var shaft := MeshInstance3D.new()
			var scyl := CylinderMesh.new()
			scyl.top_radius = 0.016
			scyl.bottom_radius = 0.018
			scyl.height = 1.65
			shaft.mesh = scyl
			shaft.material_override = wood_mat
			root.add_child(shaft)
			var tip := MeshInstance3D.new()
			var tip_cyl := CylinderMesh.new()
			tip_cyl.top_radius = 0.002
			tip_cyl.bottom_radius = 0.024
			tip_cyl.height = 0.18
			tip.mesh = tip_cyl
			tip.position = Vector3(0.0, 0.90, 0.0)
			tip.material_override = bone_mat if item_name == "Lanza de hueso" else (stone_mat if item_name == "Lanza" else wood_mat)
			root.add_child(tip)
		"Boleadoras":
			var knot := MeshInstance3D.new()
			var k_sph := SphereMesh.new()
			k_sph.radius = 0.014
			k_sph.height = 0.024
			knot.mesh = k_sph
			knot.material_override = wrap_mat
			root.add_child(knot)
			for idx in range(3):
				var ang := TAU * float(idx) / 3.0
				var dir := Vector3(cos(ang), 0.0, sin(ang))
				var cord := MeshInstance3D.new()
				var ccyl := CylinderMesh.new()
				ccyl.top_radius = 0.0045
				ccyl.bottom_radius = 0.0045
				ccyl.height = 0.20
				cord.mesh = ccyl
				cord.position = dir * 0.10
				cord.rotation.z = PI * 0.5
				cord.rotation.y = -ang
				cord.material_override = cord_mat
				root.add_child(cord)
				var ball := MeshInstance3D.new()
				var sph := SphereMesh.new()
				sph.radius = 0.038
				sph.height = 0.068
				sph.radial_segments = 12
				sph.rings = 6
				ball.mesh = sph
				ball.position = dir * 0.20
				ball.scale = Vector3(1.18, 0.84, 0.96)
				ball.rotation = Vector3(0.2 * float(idx), ang, 0.15)
				ball.material_override = stone_mat
				root.add_child(ball)
				var strap := MeshInstance3D.new()
				var storus := TorusMesh.new()
				storus.inner_radius = 0.030
				storus.outer_radius = 0.039
				strap.mesh = storus
				strap.position = dir * 0.20
				strap.rotation.z = PI * 0.5
				strap.rotation.y = -ang
				strap.material_override = wrap_mat
				root.add_child(strap)
		"Hueso":
			var shaft := MeshInstance3D.new()
			var bcyl := CylinderMesh.new()
			bcyl.top_radius = 0.016
			bcyl.bottom_radius = 0.016
			bcyl.height = 0.28
			shaft.mesh = bcyl
			shaft.rotation_degrees.z = 90.0
			shaft.material_override = bone_mat
			root.add_child(shaft)
			for sx in [-0.14, 0.14]:
				for sy in [-0.012, 0.012]:
					var knob := MeshInstance3D.new()
					var ksph := SphereMesh.new()
					ksph.radius = 0.022
					ksph.height = 0.044
					knob.mesh = ksph
					knob.position = Vector3(sx, sy, 0.0)
					knob.material_override = bone_mat
					root.add_child(knob)
		"Tendón":
			var loop := MeshInstance3D.new()
			var tor := TorusMesh.new()
			tor.inner_radius = 0.055
			tor.outer_radius = 0.075
			loop.mesh = tor
			loop.material_override = cord_mat
			root.add_child(loop)
		"Pluma":
			var quill := MeshInstance3D.new()
			var qbox := BoxMesh.new()
			qbox.size = Vector3(0.05, 0.004, 0.22)
			quill.mesh = qbox
			quill.material_override = feather_mat
			root.add_child(quill)
		"Piedra afilada":
			stone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var flint_edge_mat := StandardMaterial3D.new()
			flint_edge_mat.albedo_color = Color(0.76, 0.75, 0.71)
			flint_edge_mat.roughness = 0.58
			flint_edge_mat.metallic = 0.10
			flint_edge_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			if stone_tex != null:
				flint_edge_mat.albedo_texture = stone_tex
				flint_edge_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
				flint_edge_mat.uv1_offset = Vector3(0.25, 0.25, 0.0)
			var biface := MeshInstance3D.new()
			biface.name = "KnappedStoneBiface"
			biface.mesh = _build_knapped_stone_mesh(stone_mat, flint_edge_mat)
			root.add_child(biface)
		"Cuchillo de piedra", "Cuchillo de hueso":
			var handle := MeshInstance3D.new()
			var hcyl := CylinderMesh.new()
			hcyl.top_radius = 0.013
			hcyl.bottom_radius = 0.015
			hcyl.height = 0.11
			handle.mesh = hcyl
			handle.position = Vector3(0.0, -0.055, 0.0)
			handle.material_override = wood_mat
			root.add_child(handle)
			var lashing := MeshInstance3D.new()
			var lcyl := CylinderMesh.new()
			lcyl.top_radius = 0.0155
			lcyl.bottom_radius = 0.0155
			lcyl.height = 0.026
			lashing.mesh = lcyl
			lashing.position = Vector3(0.0, -0.004, 0.0)
			lashing.material_override = wrap_mat
			root.add_child(lashing)
			var blade := MeshInstance3D.new()
			if item_name == "Cuchillo de piedra":
				stone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				var flint_mat := StandardMaterial3D.new()
				flint_mat.albedo_color = Color(0.76, 0.75, 0.71)
				flint_mat.roughness = 0.60
				flint_mat.metallic = 0.08
				flint_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				if stone_tex != null:
					flint_mat.albedo_texture = stone_tex
					flint_mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
					flint_mat.uv1_offset = Vector3(0.25, 0.25, 0.0)
				blade.mesh = _build_knapped_stone_mesh(stone_mat, flint_mat, true)
				blade.scale = Vector3(0.46, 0.95, 0.44)
				blade.position = Vector3(0.0, 0.058, 0.0)
			else:
				var prism := PrismMesh.new()
				prism.size = Vector3(0.038, 0.14, 0.012)
				blade.mesh = prism
				blade.position = Vector3(0.0, 0.06, 0.0)
				blade.material_override = bone_mat
			root.add_child(blade)
	return root

static func _build_knapped_stone_mesh(core_mat: Material, edge_mat: Material, tang_base: bool = false) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	# Anillos de un bifaz/lasca de piedra tallada: talón redondeado para la palma
	# (abajo, y=-0.064..0.0) y filo/punta lascada arriba (y=0.0..0.072).
	var ring_y := [-0.056, -0.036, -0.006, 0.022, 0.048, 0.068]
	var ring_rx := [0.016, 0.028, 0.042, 0.036, 0.022, 0.004] if tang_base else [0.024, 0.041, 0.046, 0.038, 0.023, 0.0035]
	var ring_rz := [0.010, 0.016, 0.020, 0.014, 0.008, 0.0015] if tang_base else [0.016, 0.025, 0.024, 0.016, 0.008, 0.0015]
	var ring_shift_x := [0.000, 0.000, 0.000, 0.002, 0.003, 0.001] if tang_base else [-0.001, -0.002, 0.000, 0.002, 0.003, 0.002]
	var segs := 12
	var rings := ring_y.size()
	var ring_pts: Array = []
	for r in range(rings):
		var pts: Array[Vector3] = []
		var y: float = ring_y[r]
		var rx: float = ring_rx[r]
		var rz: float = ring_rz[r]
		var sx: float = ring_shift_x[r]
		var edge_t := clampf(float(r - 1) / float(rings - 2), 0.0, 1.0)
		for s in range(segs):
			var a := TAU * float(s) / float(segs)
			var ca := cos(a)
			var sa := sin(a)
			var facet := 1.0 + 0.04 * cos(a * 2.0 + float(r) * 0.9) - 0.03 * sin(a * 3.0 - float(r) * 0.6)
			# Sección lenticular suave hacia los filos (+X / -X) en la mitad superior
			var lens := 1.0 - 0.34 * edge_t * ca * ca
			var px := sx + ca * rx * facet
			var pz := sa * rz * facet * lens
			pts.append(Vector3(px, y, pz))
		ring_pts.append(pts)

	var st_core := SurfaceTool.new()
	st_core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_edge := SurfaceTool.new()
	st_edge.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tapa inferior redondeada (talón de roca)
	var bottom_center := Vector3(ring_shift_x[0], -0.062, 0.0)
	for s in range(segs):
		var sn := (s + 1) % segs
		var p0: Vector3 = ring_pts[0][s]
		var p1: Vector3 = ring_pts[0][sn]
		var n := ((p0 + p1) * 0.5 - Vector3(ring_shift_x[0], -0.015, 0.0)).normalized()
		st_core.set_normal(n)
		st_core.set_uv(Vector2(0.5, 0.5)); st_core.add_vertex(bottom_center)
		st_core.set_uv(Vector2(float(sn) / float(segs), 0.0)); st_core.add_vertex(p1)
		st_core.set_uv(Vector2(float(s) / float(segs), 0.0)); st_core.add_vertex(p0)

	# Bandas entre anillos: el núcleo/talón usa core_mat; el bisel cortante y punta usan edge_mat
	for r in range(rings - 1):
		var v0 := float(r) / float(rings - 1)
		var v1 := float(r + 1) / float(rings - 1)
		for s in range(segs):
			var sn := (s + 1) % segs
			var a_mid := TAU * (float(s) + 0.5) / float(segs)
			var is_flaked_edge: bool = (r >= 3) or (r >= 2 and absf(cos(a_mid)) > 0.38) or (r >= 0 and cos(a_mid) > 0.52)
			var st: SurfaceTool = st_edge if is_flaked_edge else st_core
			var p00: Vector3 = ring_pts[r][s]
			var p01: Vector3 = ring_pts[r][sn]
			var p10: Vector3 = ring_pts[r + 1][s]
			var p11: Vector3 = ring_pts[r + 1][sn]
			var u0 := float(s) / float(segs)
			var u1 := float(s + 1) / float(segs)
			var n1 := (p10 - p00).cross(p01 - p00).normalized()
			if n1.y < 0.18:
				n1 = Vector3(n1.x, 0.18, n1.z).normalized()
			st.set_normal(n1)
			st.set_uv(Vector2(u0, v0)); st.add_vertex(p00)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(p01)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(p10)
			var n2 := (p10 - p01).cross(p11 - p01).normalized()
			if n2.y < 0.18:
				n2 = Vector3(n2.x, 0.18, n2.z).normalized()
			st.set_normal(n2)
			st.set_uv(Vector2(u1, v0)); st.add_vertex(p01)
			st.set_uv(Vector2(u1, v1)); st.add_vertex(p11)
			st.set_uv(Vector2(u0, v1)); st.add_vertex(p10)

	# Cierre de la punta superior
	var tip_vertex := Vector3(0.002, 0.072, 0.0)
	var top_ring: Array = ring_pts[rings - 1]
	for s in range(segs):
		var sn := (s + 1) % segs
		var p0: Vector3 = top_ring[s]
		var p1: Vector3 = top_ring[sn]
		var n := (tip_vertex - p0).cross(p1 - p0).normalized()
		st_edge.set_normal(n)
		st_edge.set_uv(Vector2(float(s) / float(segs), 0.92)); st_edge.add_vertex(p0)
		st_edge.set_uv(Vector2(float(sn) / float(segs), 0.92)); st_edge.add_vertex(p1)
		st_edge.set_uv(Vector2(0.5, 1.0)); st_edge.add_vertex(tip_vertex)

	st_core.commit(mesh)
	if mesh.get_surface_count() > 0:
		mesh.surface_set_material(0, core_mat)
	st_edge.commit(mesh)
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, edge_mat)
	return mesh
