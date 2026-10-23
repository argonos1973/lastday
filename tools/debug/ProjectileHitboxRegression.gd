extends SceneTree
# Physics check: does RifleProjectile's swept ray (mask 5, collide_with_areas)
# actually stop on a puppet-style Area3D hitbox (layer 1, monitoring=false)?
var _hits: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	# Victim: plain Node3D in remote_player group with a BodyHitbox Area3D
	var victim := Node3D.new()
	victim.name = "Victim"
	victim.add_to_group("remote_player")
	world.add_child(victim)
	var body := Area3D.new()
	body.name = "BodyHitbox"
	body.collision_layer = 1
	body.collision_mask = 0
	body.monitorable = true
	body.monitoring = false
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.42
	cap.height = 1.55
	col.shape = cap
	col.position.y = 0.82
	body.add_child(col)
	victim.add_child(body)
	victim.global_position = Vector3(0, 0, -8)
	# Projectile fired straight at the torso
	var proj = preload("res://scripts/RifleProjectile.gd").new()
	proj.velocity = Vector3(0, 0, -50.0)
	proj.max_distance = 100.0
	proj.impact.connect(func(c, p, d, n):
		_hits.append([c, p, d])
		print("IMPACT collider=", c, " pos=", p, " dist=", d))
	world.add_child(proj)
	proj.global_position = Vector3(0, 0.82, 0)
	var frames := 0
	while frames < 60 and _hits.is_empty():
		await physics_frame
		frames += 1
	var errors := 0
	if _hits.is_empty():
		errors += 1
		print("FAIL: projectile never emitted impact on BodyHitbox")
	else:
		var c = _hits[0][0]
		if c != body:
			errors += 1
			print("FAIL: impact collider is ", c, " not BodyHitbox")
		else:
			print("PASS: projectile stopped on BodyHitbox at dist ", _hits[0][2])
	print("PROJ_HITBOX_ERRORS=", errors)
	quit(1 if errors else 0)
