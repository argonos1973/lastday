extends SceneTree

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# A healthy player knocked to 0 HP by external damage (wolf bites) must die.
	# Before the fix, the passive regen ran before the death check and revived
	# them every tick, leaving them immortal at 0 HP while fed and rested.
	var stats := SurvivalStats.new()
	root.add_child(stats)
	var died_count := [0]
	stats.died.connect(func() -> void: died_count[0] += 1)
	stats.hunger = 80.0
	stats.thirst = 80.0
	stats.sleep = 90.0
	stats.body_temperature = 36.6
	stats.health = 0.0  # set by apply_damage between ticks
	for frame in range(10):
		stats.tick(1.0 / 60.0, false, 21.0, false)
		if stats.dead:
			break
	check(stats.dead and died_count[0] == 1, "Player at 0 HP must die on the next tick, even when fed and rested")
	check(stats.health <= 0.0, "Regen must not revive a dead player")
	# A living player still regenerates normally
	var stats2 := SurvivalStats.new()
	root.add_child(stats2)
	stats2.hunger = 80.0
	stats2.thirst = 80.0
	stats2.sleep = 90.0
	stats2.body_temperature = 36.6
	stats2.health = 50.0
	stats2.tick(1.0, false, 21.0, false)
	check(stats2.health > 50.0 and not stats2.dead, "Living player still regenerates health")
	# Starvation death still works
	var stats3 := SurvivalStats.new()
	root.add_child(stats3)
	var died3 := [0]
	stats3.died.connect(func() -> void: died3[0] += 1)
	stats3.hunger = 0.0
	stats3.thirst = 80.0
	stats3.sleep = 90.0
	stats3.body_temperature = 36.6
	stats3.health = 0.01
	for frame in range(120):
		stats3.tick(1.0 / 60.0, false, 21.0, false)
		if stats3.dead:
			break
	check(stats3.dead and died3[0] == 1, "Starvation damage still kills")
	stats.free()
	stats2.free()
	stats3.free()
	if failures == 0:
		print("PASS: 0 HP kills even with passive regen conditions met")
	quit(1 if failures else 0)
