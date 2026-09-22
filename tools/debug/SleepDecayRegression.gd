extends SceneTree

const StatsScript = preload("res://scripts/SurvivalStats.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# Day: sleep must drain noticeably slower than before (was 0.15/s).
	var day := StatsScript.new()
	for i in range(300):
		_keep_alive(day)
		day.tick(1.0, false, 20.0, false, 0.0, false)
	var day_rate := (100.0 - day.sleep) / 300.0
	check(day_rate < 0.10, "Day sleep drain too fast: %f/s" % day_rate)
	check(day_rate > 0.05, "Day sleep drain must still be felt: %f/s" % day_rate)
	# Night: stronger urge to sleep than during the day.
	var night := StatsScript.new()
	for i in range(300):
		_keep_alive(night)
		night.tick(1.0, false, 20.0, false, 0.0, true)
	var night_rate := (100.0 - night.sleep) / 300.0
	check(night_rate > day_rate * 2.5, "Night must feel much sleepier: day=%f night=%f" % [day_rate, night_rate])
	check(night_rate < 0.30, "Night sleep drain must also be slower overall: %f/s" % night_rate)
	if failures == 0:
		print("PASS: sleep drains slower — day %.4f/s, night %.4f/s (3x day)" % [day_rate, night_rate])
	quit(1 if failures else 0)

func _keep_alive(s) -> void:
	s.hunger = 100.0
	s.thirst = 100.0
	s.energy = 85.0
	s.body_temperature = 36.6
