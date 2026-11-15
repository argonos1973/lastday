extends RefCounted
## Opciones de rendimiento persistidas (user://graphics.cfg, seccion
## "graphics", compartida con ShadowQuality). Pantalla/escala/vsync se
## aplican al instante; sombras y detalles se leen al entrar en partida.
const CONFIG_PATH := "user://graphics.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)
]
const RESOLUTION_LABELS := ["1280 x 720", "1600 x 900", "1920 x 1080", "2560 x 1440"]
const RENDER_SCALES := [1.0, 0.75, 0.5]
const RENDER_SCALE_LABELS := ["100%", "75%", "50%"]
const DETAIL_FACTORS := [0.6, 1.0, 1.35]
const DETAIL_LABELS := ["Detalles: bajos", "Detalles: normales", "Detalles: altos"]

static var config_path := CONFIG_PATH # Overridable by isolated regression tests.
static var _cached_config: ConfigFile = null
static var _cached_file_saved: bool = false

static func invalidate_cache() -> void:
	_cached_config = null
	_cached_file_saved = false

static func _config() -> ConfigFile:
	if _cached_config != null and (not _cached_file_saved or FileAccess.file_exists(config_path)):
		return _cached_config
	var c := ConfigFile.new()
	_cached_file_saved = c.load(config_path) == OK
	_cached_config = c
	return c

static func _read(c: ConfigFile, key: String, fallback: Variant) -> Variant:
	return c.get_value("graphics", key, fallback)

static func _write(key: String, value: Variant) -> Error:
	return write_values({key: value})

static func write_values(values: Dictionary) -> Error:
	# Read fresh so another settings owner cannot be lost to a stale cache.
	var c := ConfigFile.new()
	var loaded := c.load(config_path)
	if loaded != OK and loaded != ERR_FILE_NOT_FOUND:
		push_warning("No se pueden guardar preferencias: archivo dañado (%s)." % error_string(loaded))
		return loaded
	var changed := false
	for key in values:
		if not c.has_section_key("graphics", key) or typeof(c.get_value("graphics", key)) != typeof(values[key]) or c.get_value("graphics", key) != values[key]:
			c.set_value("graphics", key, values[key])
			changed = true
	if changed:
		var err := c.save(config_path)
		if err != OK:
			push_warning("No se pudo guardar la configuración gráfica: %s" % error_string(err))
			return err
		var verify := ConfigFile.new()
		if verify.load(config_path) != OK or verify.encode_to_text() != c.encode_to_text():
			push_warning("No se pudo verificar la configuración gráfica guardada.")
			return ERR_FILE_CORRUPT
	_cached_config = c
	_cached_file_saved = true
	return OK

static func index_value(key: String, fallback: int, count: int) -> int:
	var v = _read(_config(), key, fallback)
	if not (v is int):
		return fallback
	return clampi(v, 0, count - 1)

static func apply_profile(index: int) -> Error:
	if index < 0 or index > 2:
		return ERR_INVALID_PARAMETER
	# VSync and window mode remain explicit user preferences.
	return write_values({"resolution": [0, 1, 2][index], "render_scale": 0,
		"shadows": index, "detail": index})

static func profile_index() -> int:
	for i in range(3):
		if index_value("resolution", 2, RESOLUTIONS.size()) == [0, 1, 2][i] and render_scale_index() == 0 and index_value("shadows", 1, 3) == i and detail_index() == i:
			return i
	return 3

static func fullscreen() -> bool:
	var v = _read(_config(), "fullscreen", false)
	return v if v is bool else false

static func save_fullscreen(v: bool) -> void:
	_write("fullscreen", v)

# Indices de RESOLUTIONS que caben en el area usable de la pantalla
# actual (sin barra de tareas/dock). Una ventana mayor que el monitor no
# se ajusta — esas resoluciones no se ofrecen ni se aplican. En headless
# se devuelven todas.
static func supported_resolution_indexes() -> Array[int]:
	var out: Array[int] = []
	if DisplayServer.get_name() == "headless":
		for i in range(RESOLUTIONS.size()):
			out.append(i)
		return out
	var scr := DisplayServer.window_get_current_screen()
	if scr < 0:
		scr = DisplayServer.get_primary_screen()
	var usable: Vector2i = DisplayServer.screen_get_usable_rect(scr).size
	for i in range(RESOLUTIONS.size()):
		var r: Vector2i = RESOLUTIONS[i]
		if r.x <= usable.x and r.y <= usable.y:
			out.append(i)
	if out.is_empty():
		out.append(0)
	return out

static func resolution_index() -> int:
	var idx := index_value("resolution", 2, RESOLUTIONS.size())
	# Si la guardada no cabe en esta pantalla, se usa la mayor que si
	# quepa — nunca se abre una ventana mayor que el monitor.
	var supported := supported_resolution_indexes()
	if not supported.has(idx):
		idx = supported[supported.size() - 1]
	return idx

static func save_resolution_index(i: int) -> void:
	_write("resolution", clampi(i, 0, RESOLUTIONS.size() - 1))

static func render_scale_index() -> int:
	return index_value("render_scale", 0, RENDER_SCALES.size())

static func save_render_scale_index(i: int) -> void:
	_write("render_scale", clampi(i, 0, RENDER_SCALES.size() - 1))

static func render_scale() -> float:
	return RENDER_SCALES[render_scale_index()]

static func detail_index() -> int:
	return index_value("detail", 1, DETAIL_FACTORS.size())

static func save_detail_index(i: int) -> void:
	_write("detail", clampi(i, 0, DETAIL_FACTORS.size() - 1))

# Multiplica los radios de visibilidad de bosque/hierba. Se lee en cada
# tick, asi que el cambio aplica sin reiniciar la partida.
static func detail_factor() -> float:
	return DETAIL_FACTORS[detail_index()]

static func vsync() -> bool:
	var v = _read(_config(), "vsync", true)
	return v if v is bool else true

static func save_vsync(v: bool) -> void:
	_write("vsync", v)

# Ventana/pantalla completa/resolucion: aplica al instante y al arrancar.
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Desbloquear temporalmente RESIZE_DISABLED antes de cambiar modo o tamano:
	# en macOS/X11 una ventana no redimensionable puede ignorar FULLSCREEN o set_size.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, false)
	if fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = RESOLUTIONS[resolution_index()]
		DisplayServer.window_set_size(size)
		var scr := DisplayServer.window_get_current_screen()
		if scr < 0:
			scr = DisplayServer.get_primary_screen()
		var usable := DisplayServer.screen_get_usable_rect(scr)
		size = size.min(usable.size)
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_RESIZE_DISABLED, true)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync() else DisplayServer.VSYNC_DISABLED)

# Escala de render: reduce la carga de GPU sin tocar el tamano de ventana.
static func apply_render_scale(viewport: Viewport) -> void:
	var s := render_scale()
	var method := RenderingServer.get_current_rendering_method()
	if s < 0.999 and method == "forward_plus":
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = s
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = s if s < 0.999 else 1.0

# Geometry LOD keeps objects/collisions visible, unlike shorter tree culling.
static func apply_detail(viewport: Viewport) -> void:
	viewport.mesh_lod_threshold = [4.0, 2.0, 1.0][detail_index()]

static func splash_density() -> float:
	return [0.45, 0.75, 1.0][detail_index()]

static func effective_snapshot(viewport: Viewport) -> Dictionary:
	return {"window": DisplayServer.window_get_size(), "mode": DisplayServer.window_get_mode(),
		"vsync": DisplayServer.window_get_vsync_mode(), "scale": viewport.scaling_3d_scale,
		"scaling_mode": viewport.scaling_3d_mode, "lod_threshold": viewport.mesh_lod_threshold,
		"detail": detail_factor(), "renderer": RenderingServer.get_current_rendering_method()}
