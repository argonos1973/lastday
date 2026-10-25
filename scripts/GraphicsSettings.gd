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

static func _config() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(CONFIG_PATH)
	return c

static func _read(c: ConfigFile, key: String, fallback: Variant) -> Variant:
	return c.get_value("graphics", key, fallback)

static func _write(key: String, value: Variant) -> void:
	var c := _config()
	c.set_value("graphics", key, value)
	c.save(CONFIG_PATH)

static func fullscreen() -> bool:
	return bool(_read(_config(), "fullscreen", false))

static func save_fullscreen(v: bool) -> void:
	_write("fullscreen", v)

static func resolution_index() -> int:
	return clampi(int(_read(_config(), "resolution", 2)), 0, RESOLUTIONS.size() - 1)

static func save_resolution_index(i: int) -> void:
	_write("resolution", clampi(i, 0, RESOLUTIONS.size() - 1))

static func render_scale_index() -> int:
	return clampi(int(_read(_config(), "render_scale", 0)), 0, RENDER_SCALES.size() - 1)

static func save_render_scale_index(i: int) -> void:
	_write("render_scale", clampi(i, 0, RENDER_SCALES.size() - 1))

static func render_scale() -> float:
	return RENDER_SCALES[render_scale_index()]

static func detail_index() -> int:
	return clampi(int(_read(_config(), "detail", 1)), 0, DETAIL_FACTORS.size() - 1)

static func save_detail_index(i: int) -> void:
	_write("detail", clampi(i, 0, DETAIL_FACTORS.size() - 1))

# Multiplica los radios de visibilidad de bosque/hierba. Se lee en cada
# tick, asi que el cambio aplica sin reiniciar la partida.
static func detail_factor() -> float:
	return DETAIL_FACTORS[detail_index()]

static func vsync() -> bool:
	return bool(_read(_config(), "vsync", true))

static func save_vsync(v: bool) -> void:
	_write("vsync", v)

# Ventana/pantalla completa/resolucion: aplica al instante y al arrancar.
static func apply_window() -> void:
	if fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var size: Vector2i = RESOLUTIONS[resolution_index()]
		DisplayServer.window_set_size(size)
		var screen := DisplayServer.screen_get_size()
		DisplayServer.window_set_position((screen - size) / 2)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync() else DisplayServer.VSYNC_DISABLED)

# Escala de render: reduce la carga de GPU sin tocar el tamano de ventana.
static func apply_render_scale(viewport: Viewport) -> void:
	var s := render_scale()
	if s < 0.999:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		viewport.scaling_3d_scale = s
	else:
		viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		viewport.scaling_3d_scale = 1.0
