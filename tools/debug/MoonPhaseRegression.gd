extends SceneTree

# Moon phase regression: the in-game moon must track the REAL moon —
# phase from the system clock, position updates, and a clean full disc
# at full moon. Run: Godot --headless --path . --script tools/debug/MoonPhaseRegression.gd

const CelestialSystemScript = preload("res://scripts/CelestialSystem.gd")

var _failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var cel := CelestialSystemScript.new()
	root.add_child(cel)
	cel.create_moon_field()

	# 1. Phase math against known lunar dates.
	# New moon epoch used by the game: JD 2451550.1 (2000-01-06 ~18:14 UTC).
	var new_phase := cel.get_real_moon_phase_data(2451550.1)
	check(absf(float(new_phase["illumination"])) < 0.02, "New moon epoch -> ~0 illumination")
	var full_phase := cel.get_real_moon_phase_data(2451550.1 + 29.530588853 * 0.5)
	check(float(full_phase["illumination"]) > 0.98, "Half synodic later -> ~full illumination")
	var quarter_phase := cel.get_real_moon_phase_data(2451550.1 + 29.530588853 * 0.25)
	check(absf(float(quarter_phase["illumination"]) - 0.5) < 0.02, "Quarter -> ~0.5 illumination")
	check(bool(new_phase["waxing"]) == true, "Day after new moon is waxing")
	var waning := cel.get_real_moon_phase_data(2451550.1 + 29.530588853 * 0.75)
	check(bool(waning["waxing"]) == false, "Third-quarter age is waning")

	# 2. Today's real phase is computable and sane.
	var today := cel.get_real_moon_phase_data()
	var illum := float(today["illumination"])
	check(illum >= 0.0 and illum <= 1.0, "Current real illumination in [0,1] = %.2f (age %.1f d)" % [illum, float(today["age"])])

	# 3. update_moon_position repositions discs and clears shadow at full moon.
	var disc: MeshInstance3D = null
	var shadow: MeshInstance3D = null
	for c in cel.moon_field.get_children():
		if c.name == "RealPhaseMoonDisc":
			disc = c
		elif c.name == "RealPhaseMoonShadow":
			shadow = c
	check(disc != null and shadow != null, "Moon disc + shadow exist")
	var disc_pos_before: Vector3 = disc.position
	cel.update_moon_position()
	var moon_dir := cel.get_real_moon_direction()
	var expected := moon_dir * CelestialSystemScript.STAR_DOME_RADIUS
	check(disc.position.distance_to(expected) < 0.001, "update_moon_position moves disc to real direction")
	if moon_dir.y > 0.02:
		check(disc.visible, "Moon visible when above horizon")
	# Full-moon shadow must not overlap the disc: offset > r_moon + r_shadow.
	var r_moon := 4.8
	var r_shadow := 4.8 * 1.02
	var full_offset: float = (disc.position - shadow.position).length()
	# offset now reflects TODAY's phase; verify the helper for full moon instead.
	var off_full := absf(cel._phase_shadow_offset(r_moon, 1.0, true))
	check(off_full > r_moon + r_shadow, "Full-moon shadow offset clears the disc (%.2f > %.2f)" % [off_full, r_moon + r_shadow])
	var off_new := cel._phase_shadow_offset(r_moon, 0.0, true)
	check(absf(off_new) < 0.001, "New-moon shadow centered on disc")
	var off_wax := cel._phase_shadow_offset(r_moon, 0.5, true)
	var off_wan := cel._phase_shadow_offset(r_moon, 0.5, false)
	check(signf(off_wax) != signf(off_wan), "Waxing/waning shadow on opposite sides")

	# 4. Direction sanity: returns a unit vector.
	check(absf(moon_dir.length() - 1.0) < 0.01, "Moon direction is normalized")
	print("disc moved from ", disc_pos_before, " to ", disc.position)
	print("RESULT: %s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(0 if _failures == 0 else 1)
