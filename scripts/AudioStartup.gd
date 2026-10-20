extends Node

# CoreAudio tears down output too when input initialization fails. Recover
# once, before joining a game, using a per-machine override read at engine boot.
const CONFIG_PATH := "user://audio_device_override.cfg"
var input_enabled_at_boot := false

static func needs_output_recovery(platform: String, driver: String, input_enabled: bool, headless: bool, forced_dummy: bool) -> bool:
	# With input enabled, some desktop backends fail as a whole when there is
	# no capture device. One output-only relaunch repairs that startup mode on
	# CoreAudio and PulseAudio; the saved override prevents a restart loop.
	return platform in ["macOS", "Linux"] and driver == "Dummy" and input_enabled and not headless and not forced_dummy

static func save_input_preference(enabled: bool, path: String = CONFIG_PATH) -> Error:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		return error
	config.set_value("audio", "driver/enable_input", enabled)
	return config.save(path)

static func preferred_local_output_device(devices: PackedStringArray) -> String:
	# Chrome Remote Desktop injects PULSE_SINK=chrome_remote_desktop_session
	# into apps it launches. Prefer the laptop's ALSA/SOF sink so game audio
	# stays on the machine's speakers instead of disappearing into CRD.
	for device in devices:
		var normalized := device.to_lower()
		if "chrome_remote" in normalized or "remote_desktop" in normalized or "crd_audio" in normalized:
			continue
		if "sofhdadsp" in normalized or "speaker" in normalized or "headphone" in normalized:
			return device
	return ""

static func needs_local_audio_route_restart(platform: String, runtime_path: String, pulse_server: String, pulse_sink: String) -> bool:
	if platform != "Linux":
		return false
	var route := (runtime_path + " " + pulse_server + " " + pulse_sink).to_lower()
	return "crd_audio" in route or "chrome_remote_desktop" in route

func _ready() -> void:
	input_enabled_at_boot = bool(ProjectSettings.get_setting("audio/driver/enable_input", false))
	var args := OS.get_cmdline_args()
	# Tests/tools must never rewrite a real user's preferences or relaunch.
	if Engine.is_editor_hint() or OS.has_feature("dedicated_server") or args.has("--script") or args.has("-s"):
		return
	var pulse_runtime := OS.get_environment("PULSE_RUNTIME_PATH")
	var pulse_server := OS.get_environment("PULSE_SERVER")
	var pulse_sink := OS.get_environment("PULSE_SINK")
	if needs_local_audio_route_restart(OS.get_name(), pulse_runtime, pulse_server, pulse_sink):
		# CRD launches applications against a private PipeWire instance. Re-exec
		# once against the laptop's normal user PipeWire socket before Godot's
		# audio driver reinitializes, so playback reaches the built-in speakers.
		var runtime_dir := OS.get_environment("XDG_RUNTIME_DIR")
		if runtime_dir.is_empty():
			var uid_output: Array[String] = []
			OS.execute("/usr/bin/id", ["-u"], uid_output)
			if not uid_output.is_empty():
				runtime_dir = "/run/user/%s" % uid_output[0].strip_edges()
		if runtime_dir.is_empty():
			push_error("No se pudo resolver el socket local de PipeWire; se mantiene la salida actual.")
			return
		OS.set_environment("PULSE_RUNTIME_PATH", runtime_dir)
		OS.set_environment("PULSE_SERVER", "unix:%s/pulse/native" % runtime_dir)
		OS.set_environment("PULSE_SINK", "")
		print("[AUDIO] CRD enviaba el audio a la sesión remota; reiniciando con PipeWire local.")
		OS.set_restart_on_exit(true, args)
		get_tree().quit()
		return
	if OS.get_name() == "Linux":
		var local_output := preferred_local_output_device(AudioServer.get_output_device_list())
		if not local_output.is_empty() and AudioServer.get_output_device() != local_output:
			AudioServer.set_output_device(local_output)
			print("[AUDIO] Salida local seleccionada: %s" % local_output)
	var forced_dummy := false
	for i in range(args.size() - 1):
		if args[i] == "--audio-driver" and args[i + 1] == "Dummy":
			forced_dummy = true
	if not needs_output_recovery(OS.get_name(), AudioServer.get_driver_name(), input_enabled_at_boot, DisplayServer.get_name() == "headless", forced_dummy):
		return
	if save_input_preference(false) != OK:
		push_error("No se pudo guardar la recuperación de audio. Revisa los permisos de la carpeta de configuración.")
		return
	print("[AUDIO] El controlador de audio inició como Dummy con entrada activada; reiniciando una vez con salida de audio activa.")
	OS.set_restart_on_exit(true, args)
	get_tree().quit()

func microphone_unavailable_reason() -> String:
	if AudioServer.get_driver_name() == "Dummy":
		return "No hay salida de audio disponible. Revisa el dispositivo de sonido y reinicia el juego."
	if OS.get_name() == "Linux" and AudioServer.get_input_device_list().size() <= 1:
		return "No se detecta un micrófono. Puedes seguir escuchando el juego y a los demás jugadores."
	if OS.get_name() == "macOS":
		if AudioServer.get_input_device_list().size() <= 1:
			return "No se detecta un micrófono. Puedes seguir escuchando el juego y a los demás jugadores."
		if not input_enabled_at_boot:
			if save_input_preference(true) != OK:
				return "No se pudo activar el micrófono: no se puede guardar la configuración de audio."
			return "Micrófono preparado. Sal y vuelve a abrir el juego para activarlo. Mientras tanto puedes escuchar a los demás."
	return ""
