extends SceneTree
# Regresión de las opciones de rendimiento: defaults, round-trip en disco y
# clamps de índices. No toca DisplayServer (headless).
const GraphicsSettings = preload("res://scripts/GraphicsSettings.gd")

var failures := 0

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GraphicsSettings.CONFIG_PATH))
	_check(not GraphicsSettings.fullscreen(), "fullscreen por defecto = false")
	_check(GraphicsSettings.resolution_index() == 2, "resolucion por defecto = 1920x1080")
	_check(GraphicsSettings.render_scale() == 1.0, "escala por defecto = 100%")
	_check(GraphicsSettings.detail_factor() == 1.0, "detalles por defecto = normales")
	_check(GraphicsSettings.vsync(), "vsync por defecto = on")
	GraphicsSettings.save_fullscreen(true)
	GraphicsSettings.save_resolution_index(0)
	GraphicsSettings.save_render_scale_index(2)
	GraphicsSettings.save_detail_index(0)
	GraphicsSettings.save_vsync(false)
	_check(GraphicsSettings.fullscreen(), "fullscreen persiste")
	_check(GraphicsSettings.resolution_index() == 0, "resolucion persiste")
	_check(absf(GraphicsSettings.render_scale() - 0.5) < 0.001, "escala 50% persiste")
	_check(absf(GraphicsSettings.detail_factor() - 0.6) < 0.001, "detalles bajos persisten")
	_check(not GraphicsSettings.vsync(), "vsync off persiste")
	GraphicsSettings.save_detail_index(99)
	_check(GraphicsSettings.detail_index() == GraphicsSettings.DETAIL_FACTORS.size() - 1, "indice detalle clampea")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GraphicsSettings.CONFIG_PATH))
	if failures == 0:
		print("PASS: graphics settings defaults, persistence and clamps")
	else:
		print("GraphicsSettingsRegression failures=%d" % failures)
	quit(failures)
