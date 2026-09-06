@tool
extends EditorPlugin

const AUTOLOAD_NAME := "TrailerDirector"
const AUTOLOAD_PATH := "res://addons/trailer_capture/TrailerDirector.gd"
const MENU_TEXT := "Capturar tráiler automáticamente"

var _capture_pid: int = -1
var _output_directory: String = ""

func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		var save_error: Error = ProjectSettings.save()
		if save_error != OK:
			push_warning("No se pudo guardar el autoload del capturador.")
	add_tool_menu_item(MENU_TEXT, _start_capture)
	set_process(false)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_TEXT)
	if ProjectSettings.has_setting("autoload/" + AUTOLOAD_NAME):
		remove_autoload_singleton(AUTOLOAD_NAME)
	set_process(false)

func _start_capture() -> void:
	if _capture_pid > 0 and OS.is_process_running(_capture_pid):
		push_warning("La captura del tráiler ya está en marcha.")
		return

	var settings_error: Error = ProjectSettings.save()
	if settings_error != OK:
		push_warning("Godot no ha podido guardar los ajustes antes de capturar.")
	var project_directory: String = ProjectSettings.globalize_path("res://")
	_output_directory = project_directory.path_join("trailer_captures")
	var arguments := PackedStringArray([
		"--path", project_directory,
		"--resolution", "1280x720",
		"--windowed",
		"--", "--trailer-capture"
	])
	_capture_pid = OS.create_process(OS.get_executable_path(), arguments, false)
	if _capture_pid <= 0:
		push_error("No se ha podido iniciar la captura automática.")
		return

	print("[TRÁILER] Captura iniciada. No cierres la segunda ventana.")
	set_process(true)

func _process(_delta: float) -> void:
	if _capture_pid <= 0:
		set_process(false)
		return
	if OS.is_process_running(_capture_pid):
		return

	_capture_pid = -1
	set_process(false)
	print("[TRÁILER] Captura terminada: ", _output_directory)
	if DirAccess.dir_exists_absolute(_output_directory):
		var open_error: Error = OS.shell_open(_output_directory)
		if open_error != OK:
			push_warning("Las capturas están en: %s" % _output_directory)
