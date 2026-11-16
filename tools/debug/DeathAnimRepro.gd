extends SceneTree

# Repro: muerte letal por "arco" vs "m4" — misma ruta force_death→die(""), el
# clip melee_death debe terminar reproduciéndose en AMBOS casos, con y sin
# reacción de impacto previa.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass

var failures := 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)

func _make_player() -> Node:
	var player := TestPlayer.new()
	root.add_child(player)
	return player

func _mount(player: Node) -> void:
	player.notice.connect(func(_t): pass)
	if player.flashlight == null:
		player.flashlight = SpotLight3D.new()
		player.add_child(player.flashlight)
	var model: Node3D = load("res://assets/animations/inicio.glb").instantiate()
	player.add_child(model)
	player.third_person_model = model
	player._setup_third_person_animation(model)

func _report(label: String, player: Node) -> void:
	var ap: AnimationPlayer = player.third_person_animation_player
	check(player._beaten_death, label + ": beaten_death visual selected")
	check(ap != null and ap.current_animation == "melee_death/MeleeDeathExternal" and ap.is_playing(),
		label + ": death clip playing (got '%s')" % (ap.current_animation if ap != null else "none"))

func _initialize() -> void:
	print("=== DeathAnimRepro ===")
	await process_frame

	# A) Letal directo con arco (una sola flecha — sin apply_damage previo).
	var a := _make_player()
	_mount(a)
	await process_frame
	a.die("")
	_report("arco lethal", a)

	# B) Arco no letal + arco letal (hit reaction antes de la muerte).
	var b := _make_player()
	_mount(b)
	await process_frame
	b.apply_damage(30.0, "arco")
	b._play_hit_reaction(true)
	await process_frame
	b.die("")
	_report("arco hit+lethal", b)

	# C) M4 no letal + letal (shot reaction antes de la muerte).
	var c := _make_player()
	_mount(c)
	await process_frame
	c.apply_damage(30.0, "m4")
	c._play_shot_reaction()
	await process_frame
	c.die("")
	_report("m4 hit+lethal", c)

	# D) Muerte durmiendo (fade de HUD + sleep flag).
	var d := _make_player()
	_mount(d)
	await process_frame
	d.is_sleeping = true
	d.die("")
	_report("sleeping lethal", d)
	check(not d.is_sleeping, "die() wakes the sleep state (HUD fade clears)")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
