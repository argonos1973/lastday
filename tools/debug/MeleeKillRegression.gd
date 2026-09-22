extends SceneTree

const WildlifeScript = preload("res://scripts/WildlifeController.gd")
const BirdScript = preload("res://scripts/BirdController.gd")

class TestAnimal extends WildlifeScript:
	var blood_calls := 0
	var pain_calls := 0
	func _spawn_blood_splatter() -> void:
		blood_calls += 1
	func _play_pain_sound() -> void:
		pain_calls += 1

class TestBird extends BirdScript:
	var feedback_calls := 0
	func _spawn_hit_feedback() -> void:
		feedback_calls += 1

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	# Damage sources must match PlayerController._melee_attack values.
	var axe := 65.0
	var knife := 60.0
	# Wolves (240 HP): exactly 4 hits with either weapon.
	_test_wildlife("wolf", 240.0, axe, 4, "wolf/axe")
	_test_wildlife("wolf", 240.0, knife, 4, "wolf/knife")
	# The rest of the wildlife dies in fewer than 4 hits.
	_test_wildlife("deer", 80.0, axe, 2, "deer/axe")
	_test_wildlife("deer", 80.0, knife, 2, "deer/knife")
	_test_wildlife("fox", 50.0, axe, 1, "fox/axe")
	_test_wildlife("fox", 50.0, knife, 1, "fox/knife")
	_test_wildlife("boar", 100.0, axe, 2, "boar/axe")
	# Birds (25 HP) die in one hit and show hit feedback.
	var bird = TestBird.new()
	world.add_child(bird)
	bird.take_damage(knife, true)
	check(bird._is_dead, "bird dies to a single knife hit")
	check(bird.feedback_calls == 1, "bird hit shows blood + squawk feedback")
	world.free()
	if failures == 0:
		print("PASS: axe/knife kill all animals — wolf 4 hits, the rest fewer, blood+groan on every hit")
	quit(1 if failures else 0)

func _test_wildlife(kind: String, hp: float, dmg: float, hits_to_kill: int, label: String) -> void:
	var animal = TestAnimal.new()
	current_scene.add_child(animal)
	animal.animal_type = kind
	animal.health = hp
	animal.max_health = hp
	for i in range(hits_to_kill - 1):
		animal.take_damage(dmg, false)
	check(not animal._is_dead, "%s must survive %d hit(s)" % [label, hits_to_kill - 1])
	animal.take_damage(dmg, false)
	check(animal._is_dead, "%s must die on hit %d" % [label, hits_to_kill])
	check(animal.blood_calls == hits_to_kill, "%s must splatter blood on every hit" % label)
	check(animal.pain_calls == hits_to_kill, "%s must groan on every hit" % label)
	animal.free()
