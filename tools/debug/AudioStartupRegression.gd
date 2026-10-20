extends SceneTree
const Startup = preload("res://scripts/AudioStartup.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ", label)
func _initialize() -> void:
	check(Startup.needs_output_recovery("macOS", "Dummy", true, false, false), "failed macOS input triggers output recovery")
	check(not Startup.needs_output_recovery("macOS", "Dummy", false, false, false), "output-only retry cannot loop")
	check(not Startup.needs_output_recovery("macOS", "CoreAudio", true, false, false), "working microphone/output remain enabled")
	check(not Startup.needs_output_recovery("macOS", "Dummy", true, true, false), "headless server never restarts")
	check(not Startup.needs_output_recovery("macOS", "Dummy", true, false, true), "explicit Dummy choice is respected")
	check(not Startup.needs_output_recovery("Windows", "Dummy", true, false, false), "CoreAudio recovery is platform-specific")
	var path := OS.get_temp_dir().path_join("lastday_audio_settings_%d.cfg" % OS.get_process_id())
	var cfg := ConfigFile.new()
	cfg.set_value("other", "preserved", 42)
	cfg.save(path)
	check(Startup.save_input_preference(false, path) == OK, "output-only override is writable")
	cfg.load(path)
	check(cfg.get_value("audio", "driver/enable_input") == false and cfg.get_value("other", "preserved") == 42, "override changes input only")
	check(Startup.save_input_preference(true, path) == OK, "user can enable microphone for next boot")
	cfg.load(path)
	check(cfg.get_value("audio", "driver/enable_input") == true, "microphone opt-in persists")
	DirAccess.remove_absolute(path)
	print("failures=", failures)
	quit(1 if failures else 0)
