extends Node3D

# Observer location: Barcelona (used to compute the real visible night sky).
const BCN_LAT_DEG := 41.3874
const BCN_LON_DEG := 2.1686
const STAR_DOME_RADIUS := 380.0

# Real bright-star catalogue: [right ascension (hours), declination (deg), apparent magnitude].
const BRIGHT_STAR_CATALOG := [
	[6.7525, -16.7161, -1.46], [14.2610, 19.1825, -0.05], [18.6156, 38.7837, 0.03],
	[5.2782, 45.9980, 0.08], [5.2423, -8.2016, 0.13], [7.6550, 5.2250, 0.34],
	[5.9195, 7.4071, 0.42], [19.8464, 8.8683, 0.77], [4.5987, 16.5093, 0.85],
	[13.4199, -11.1613, 1.04], [16.4901, -26.4320, 1.09], [7.7553, 28.0262, 1.14],
	[22.9608, -29.6222, 1.16], [20.6905, 45.2803, 1.25], [10.1395, 11.9672, 1.35],
	[6.9770, -28.9721, 1.50], [7.5766, 31.8883, 1.58], [5.4188, 6.3497, 1.64],
	[5.4382, 28.6076, 1.65], [5.6036, -1.2019, 1.69], [5.6793, -1.9426, 1.74],
	[12.9005, 55.9598, 1.76], [11.0621, 61.7510, 1.79], [3.4054, 49.8612, 1.79],
	[7.1399, -26.3932, 1.83], [18.4029, -34.3846, 1.85], [13.7923, 49.3133, 1.85],
	[5.9924, 44.9474, 1.90], [6.6285, 16.3993, 1.93], [2.5303, 89.2641, 1.98],
	[6.3783, -17.9559, 1.98], [9.4597, -8.6586, 1.98], [2.1195, 23.4624, 2.00],
	[0.7265, -17.9866, 2.04], [18.9211, -26.2967, 2.05], [0.1398, 29.0904, 2.06],
	[1.1622, 35.6206, 2.05], [5.7959, -9.6696, 2.06], [14.8451, 74.1555, 2.08],
	[17.5822, 12.5600, 2.08], [3.1361, 40.9556, 2.09], [2.0650, 42.3297, 2.10],
	[11.8177, 14.5720, 2.11], [5.5334, -0.2991, 2.23], [15.5781, 26.7147, 2.22],
	[13.3987, 54.9254, 2.23], [20.3705, 40.2567, 2.23], [0.6751, 56.5373, 2.24],
	[17.9434, 51.4889, 2.24], [0.1529, 59.1498, 2.28], [11.0307, 56.3824, 2.37],
	[14.7498, 27.0742, 2.35], [21.7364, 9.8750, 2.39], [11.8972, 53.6948, 2.44],
	[23.0629, 28.0828, 2.44], [21.3097, 62.5856, 2.45], [23.0793, 15.2053, 2.49],
	[0.9451, 60.7167, 2.47], [3.0380, 4.0897, 2.53], [1.4304, 60.2353, 2.68],
	[12.2570, 57.0326, 3.31], [1.9066, 63.6701, 3.35], [15.3455, 71.8340, 3.05],
	[3.7914, 24.1051, 2.87], [5.6274, 21.1425, 2.97], [19.5121, 27.9597, 3.05],
	[19.7495, 45.1308, 2.87], [20.7702, 33.9703, 2.46], [19.7710, 10.6133, 2.72],
	[17.2442, 14.3903, 3.37], [17.1729, -15.7249, 2.43], [16.0056, -22.6217, 2.29],
	[1.9107, 20.8080, 2.64], [14.0731, 64.3758, 3.65], [13.4204, 54.9880, 3.99],
	[10.3328, 19.8415, 2.08], [11.2351, 20.5237, 2.56], [0.2206, 15.1836, 2.83],
	[18.8347, 33.3627, 3.52], [18.9824, 32.6896, 3.24], [19.9219, 6.4066, 3.71],
	[17.5601, -37.1038, 1.62], [7.4014, -29.3032, 2.45], [7.4527, 8.2893, 2.89],
	[15.0323, 40.3906, 3.49], [9.7141, -1.1426, 3.11], [10.8227, 41.4995, 3.45],
	[4.9484, 33.1661, 3.17], [3.4131, 24.3671, 3.42], [4.4767, 15.6276, 3.53],
]

var _real_star_nodes: Array = []
var _real_star_radec: Array = []
var _star_update_accum := 0.0
var star_field: Node3D = null
var moon_field: Node3D = null

func _julian_date_now() -> float:
	return Time.get_unix_time_from_system() / 86400.0 + 2440587.5

func _local_sidereal_deg() -> float:
	var d := _julian_date_now() - 2451545.0
	var gmst := 280.46061837 + 360.98564736629 * d
	return fposmod(gmst + BCN_LON_DEG, 360.0)

func _radec_to_world_dir(ra_rad: float, dec_rad: float, lst_rad: float, lat_rad: float) -> Vector3:
	var ha := lst_rad - ra_rad
	var sin_alt: float = clamp(sin(dec_rad) * sin(lat_rad) + cos(dec_rad) * cos(lat_rad) * cos(ha), -1.0, 1.0)
	var alt := asin(sin_alt)
	var cos_alt := cos(alt)
	var az := 0.0
	if cos_alt > 0.0001:
		var sin_az := -cos(dec_rad) * sin(ha) / cos_alt
		var cos_az := (sin(dec_rad) - sin_alt * sin(lat_rad)) / (cos_alt * cos(lat_rad))
		az = atan2(sin_az, cos_az)
	return Vector3(cos_alt * sin(az), sin_alt, -cos_alt * cos(az))

func create_star_field() -> void:
	star_field = Node3D.new()
	star_field.name = "StarField"
	star_field.visible = false
	star_field.position = Vector3.ZERO
	add_child(star_field)
	_real_star_nodes.clear()
	_real_star_radec.clear()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.97, 0.98, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.90, 0.93, 1.0)
	material.emission_energy_multiplier = 6.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var star_mesh := QuadMesh.new()
	star_mesh.size = Vector2(0.32, 0.32)
	var lat_rad := deg_to_rad(BCN_LAT_DEG)
	var lst_rad := deg_to_rad(_local_sidereal_deg())
	for entry in BRIGHT_STAR_CATALOG:
		var ra_rad: float = deg_to_rad(float(entry[0]) * 15.0)
		var dec_rad: float = deg_to_rad(float(entry[1]))
		var mag: float = float(entry[2])
		var star := MeshInstance3D.new()
		star.name = "RealStar"
		star.mesh = star_mesh
		star.material_override = material
		var size_factor: float = clamp(2.6 - mag * 0.55, 0.5, 3.4)
		star.scale = Vector3.ONE * size_factor
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := _radec_to_world_dir(ra_rad, dec_rad, lst_rad, lat_rad)
		star.position = dir * STAR_DOME_RADIUS
		star.visible = dir.y > 0.02
		star_field.add_child(star)
		_real_star_nodes.append(star)
		_real_star_radec.append(Vector2(ra_rad, dec_rad))

func update_real_star_positions() -> void:
	if _real_star_nodes.is_empty():
		return
	var lat_rad := deg_to_rad(BCN_LAT_DEG)
	var lst_rad := deg_to_rad(_local_sidereal_deg())
	for i in range(_real_star_nodes.size()):
		var node = _real_star_nodes[i]
		if not is_instance_valid(node):
			continue
		var rd: Vector2 = _real_star_radec[i]
		var dir := _radec_to_world_dir(rd.x, rd.y, lst_rad, lat_rad)
		node.position = dir * STAR_DOME_RADIUS
		node.visible = dir.y > 0.02

func create_moon_field() -> void:
	moon_field = Node3D.new()
	moon_field.name = "MoonField"
	moon_field.visible = false
	add_child(moon_field)

	var phase := get_real_moon_phase_data()
	var disc_radius := 4.8
	var moon_pos := Vector3(-38.0, 62.0, -72.0)

	var moon := MeshInstance3D.new()
	moon.name = "RealPhaseMoonDisc"
	moon.position = moon_pos
	moon.mesh = _make_disc_mesh(disc_radius, 96)
	moon.material_override = _make_celestial_material(Color(0.90, 0.88, 0.76, 0.98), Color(0.92, 0.88, 0.70), 3.2)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_field.add_child(moon)

	var shadow := MeshInstance3D.new()
	shadow.name = "RealPhaseMoonShadow"
	var illumination: float = phase["illumination"]
	var waxing: bool = phase["waxing"]
	var offset := disc_radius * 2.0 * illumination * (-1.0 if waxing else 1.0)
	shadow.position = moon_pos + Vector3(offset, 0.0, 0.035)
	shadow.mesh = _make_disc_mesh(disc_radius * 1.02, 96)
	shadow.material_override = _make_celestial_material(Color(0.012, 0.016, 0.035, 0.96), Color(0.0, 0.0, 0.0), 0.0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_field.add_child(shadow)

	var glow := MeshInstance3D.new()
	glow.name = "MoonGlow"
	glow.position = moon_pos + Vector3(0.0, 0.0, -0.02)
	glow.mesh = _make_disc_mesh(disc_radius * 1.42, 96)
	glow.material_override = _make_celestial_material(Color(0.62, 0.68, 0.86, 0.16), Color(0.40, 0.48, 0.78), 0.75)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon_field.add_child(glow)

func get_real_moon_phase_data() -> Dictionary:
	var unix_time: float = Time.get_unix_time_from_system()
	var julian_date: float = unix_time / 86400.0 + 2440587.5
	var synodic_month: float = 29.530588853
	var known_new_moon_jd: float = 2451550.1
	var age: float = fposmod(julian_date - known_new_moon_jd, synodic_month)
	var phase_angle: float = TAU * age / synodic_month
	var illumination: float = clamp((1.0 - cos(phase_angle)) * 0.5, 0.0, 1.0)
	return {
		"age": age,
		"illumination": illumination,
		"waxing": age < synodic_month * 0.5
	}

func _make_disc_mesh(radius: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.5))
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var point := Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		vertices.append(point)
		uvs.append(Vector2(point.x / (radius * 2.0) + 0.5, point.y / (radius * 2.0) + 0.5))
	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append(1 if i == segments - 1 else i + 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _make_celestial_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material
