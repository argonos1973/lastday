extends SceneTree

class Shooter extends "res://scripts/PlayerController.gd":
	var lethal_marker := false
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	func _spawn_blood_splatter(_pos = Vector3.ZERO): pass
	func _hit_marker(lethal = false): lethal_marker = lethal

class Animal extends "res://scripts/WildlifeController.gd":
	func _ready(): add_to_group("wildlife")
	func _process(_delta): pass
	func _spawn_blood_splatter(): pass
	func _play_wolf_pain_sound(): pass
	func _lie_corpse_flat(): pass

class Bird extends "res://scripts/BirdController.gd":
	func _ready(): add_to_group("wildlife")
	func _process(_delta): pass

func _initialize(): call_deferred("run")

func run():
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var shooter := Shooter.new()
	scene.add_child(shooter)
	for species in ["wolf", "deer", "fox", "bird"]:
		var animal = Bird.new() if species == "bird" else Animal.new()
		if species != "bird": animal.animal_type = species
		scene.add_child(animal)
		animal.health = 10000.0
		var hitbox := Area3D.new()
		hitbox.name = "BodyHitbox"
		animal.add_child(hitbox)
		shooter._apply_rifle_damage(hitbox, Vector3.ZERO, 20.0)
		var body_damage: float = 10000.0 - animal.health
		assert(body_damage > 0.0 and not animal._is_dead and not shooter.lethal_marker)
		animal.health = 10000.0
		hitbox.name = "HeadHitbox"
		shooter._apply_rifle_damage(hitbox, Vector3.ZERO, 20.0)
		assert(is_equal_approx(10000.0 - animal.health, body_damage * 3.0))
		animal.health = 1.0
		shooter._apply_rifle_damage(hitbox, Vector3.ZERO, 20.0)
		assert(animal._is_dead and shooter.lethal_marker)
		animal.free()
	var surface := StaticBody3D.new()
	scene.add_child(surface)
	shooter._apply_rifle_damage(surface, Vector3.ZERO, 5.0, Vector3.UP)
	assert(surface.get_node_or_null("BulletHole") != null)
	assert(not shooter.lethal_marker)
	surface.position.x = 2.0
	assert(is_equal_approx(surface.get_node("BulletHole").global_position.x, 2.0))
	print("PASS: wolf, deer, fox, bird body/head damage, death marker and attached surface impact")
	await create_timer(2.0).timeout
	scene.free()
	quit()
