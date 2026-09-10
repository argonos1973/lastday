extends SceneTree
const Stats = preload("res://scripts/SurvivalStats.gd")
const MainScript = preload("res://scripts/Main.gd")
var checks := 0
var failed := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func simulate(ambient: float, shelter := false, clothes := 0.0, wet := 0.0, wind := 0.0, retention := 0.0, sun := 0.0):
	var stats := Stats.new()
	stats.warmth_bonus = clothes
	stats.heat_retention_bonus = retention
	stats.wetness = wet
	for i in range(300):
		stats.tick(0.1, false, ambient, shelter, 0.0, false, false, false, 0.0, false, false, sun, wind)
	return stats
func _initialize():
	var neutral = simulate(22.0)
	var cold = simulate(-5.0)
	var warm_clothes = simulate(-5.0, false, 1.2)
	var shelter = simulate(-5.0, true)
	var windy = simulate(8.0, false, 0.5, 0.0, 15.0)
	var calm = simulate(8.0, false, 0.5)
	var wet = simulate(8.0, false, 0.5, 1.0)
	var hot = simulate(42.0)
	var heavy = simulate(42.0, false, 0.0, 0.0, 0.0, 0.8)
	var sun = simulate(35.0, false, 0.0, 0.0, 0.0, 0.0, 1.0)
	var shade = simulate(35.0, true)
	check(is_equal_approx(neutral.body_temperature, 36.6), "Comfortable environment maintains core temperature")
	check(cold.body_temperature < 35.4 and cold.health < neutral.health, "Cold lowers temperature and damages health")
	check(warm_clothes.body_temperature > cold.body_temperature, "Insulation protects from cold")
	check(shelter.body_temperature > cold.body_temperature, "Shelter moderates cold")
	check(windy.body_temperature < calm.body_temperature, "Wind increases cooling")
	check(wet.body_temperature < calm.body_temperature, "Wet clothes increase cooling")
	check(hot.body_temperature > 37.8 and hot.health < neutral.health, "Ambient heat alone heats the character and damages health")
	check(hot.thirst < neutral.thirst, "Heat increases thirst")
	check(cold.hunger < neutral.hunger, "Cold increases hunger")
	check(heavy.body_temperature > hot.body_temperature, "Heavy clothing retains heat")
	check(shade.body_temperature < sun.body_temperature, "Shade helps reduce heat")
	check(cold.get_thermal_speed_multiplier() < 1.0 and hot.get_thermal_speed_multiplier() < 1.0, "Both extremes reduce mobility")
	check(hot.get_thermal_recovery_multiplier() < 1.0, "Heat reduces stamina recovery")
	var before: float = hot.body_temperature
	for i in range(100): hot.tick(0.1, false, 22, true, 0.0, true)
	check(hot.body_temperature < before, "Comfortable shelter permits gradual recovery")
	neutral.tick(100.0, false, 42.0, false)
	check(neutral.body_temperature <= 43.0, "Long ticks cannot overshoot target temperature")
	neutral.dead = false
	neutral.body_temperature = 40.0
	neutral.apply_external_heat(2.0, 37.5)
	check(neutral.body_temperature == 40.0, "Fire never cools an overheated character")
	neutral.body_temperature = 34.0
	neutral.apply_external_heat(0.5, 37.5)
	check(neutral.body_temperature == 34.5, "Fire warms a cold character gradually")
	for stat in [neutral, cold, warm_clothes, shelter, windy, calm, wet, hot, heavy, sun, shade]: stat.free()
	print("TEMPERATURE: %d checks, %d failures" % [checks, failed])
	quit(1 if failed else 0)
