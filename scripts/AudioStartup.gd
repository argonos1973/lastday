extends Node

# CoreAudio tears down output too when input initialization fails. Recover
# once, before joining a game, using a per-machine override read at engine boot.
const CONFIG_PATH := "user://audio_device_override.cfg"
var input_enabled_at_boot := false

static func needs_output_recovery(platform: String, driver: String, input_enabled: bool, headless: bool, forced_dummy: bool) -> bool:
	return platform == "macOS" and driver == "Dummy" and input_enabled and not headless and not forced_dummy

static func save_input_preference(enabled: bool, path: String = CONFIG_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	config.set_value("audio", "driver/enable_input", enabled)
	return config.save(path)

func _ready() -> void:
	input_enabled_at_boot = bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	var args := OS.get_cmdline_args()
	# Tests/tools must never rewrite a real user's preferences or relaunch.
	if Engine.is_editor_hint() or OS.has_feature("dedicated_server") or args.has("--script") or args.has("-s"):
		return
	var forced_dummy := false
	for i in range(args.size() - 1):
		if args[i] == "--audio-driver" and args[i + 1] == "Dummy":
			forced_dummy = true
	if not needs_output_recovery(OS.get_name(), AudioServer.get_driver_name(), input_enabled_at_boot, DisplayServer.get_name() == "headless", forced_dummy):
		return
	if save_input_preference(false) != OK:
		push_error("No se pudo guardar la recuperación de audio. Revisa los permisos de la carpeta de configuración.")
		return
	print("[AUDIO] Falló la entrada CoreAudio; reiniciando una vez con salida de audio y recepción de voz activas.")
	OS.set_restart_on_exit(true, args)
	get_tree().quit()

func microphone_unavailable_reason() -> String:
	if AudioServer.get_driver_name() == "Dummy":
		return "No hay salida de audio disponible. Revisa el dispositivo de sonido y reinicia el juego."
	if OS.get_name() == "macOS":
		if AudioServer.get_input_device_list().size() <= 1:
			return "No se detecta un micrófono. Puedes seguir escuchando el juego y a los demás jugadores."
		if not input_enabled_at_boot:
			if save_input_preference(true) != OK:
				return "No se pudo activar el micrófono: no se puede guardar la configuración de audio."
			return "Micrófono preparado. Sal y vuelve a abrir el juego para activarlo. Mientras tanto puedes escuchar a los demás."
	return ""
