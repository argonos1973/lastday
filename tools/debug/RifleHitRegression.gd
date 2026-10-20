extends SceneTree
# Rifle hit regression: point-blank shots must not whiff. The muzzle ray can
# start inside the victim's hitbox at ~1 m — PhysicsRayQueryParameters3D
# skips colliders containing the origin unless hit_from_inside is set. Also
# covers head/body location damage: headshot notices differ from body hits
# and rifle hits trigger the shot-received reaction, not the melee flinch.
# Run:
#   work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/RifleHitRegression.gd

class TestWorld extends Node3D:
	# _hit_marker reaches for current_scene.hud — stub it to keep output clean.
	var hud = null

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("OK: " + msg)
	else:
		failures += 1
		print("FAIL: " + msg)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var PlayerScript := preload("res://scripts/PlayerController.gd")
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	var puppet = PlayerScript.new()
	puppet.is_puppet = true
	world.add_child(puppet)
	puppet.setup_as_puppet()

	var body_area: Area3D = null
	var head_area: Area3D = null
	for n in puppet.find_children("*", "Area3D", true, false):
		if n.name == "BodyHitbox":
			body_area = n
		elif n.name == "HeadHitbox":
			head_area = n
	check(body_area != null, "puppet has a BodyHitbox")
	check(head_area != null, "puppet has a HeadHitbox")

	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	if body_area != null:
		# A ray whose origin sits inside the body capsule — the point-blank
		# case that whiffed before hit_from_inside was set on the shot ray.
		var inside_origin: Vector3 = body_area.global_position + Vector3(0.0, 0.8, 0.0)
		var q_no := PhysicsRayQueryParameters3D.create(inside_origin, inside_origin + Vector3.FORWARD * 2.0, 5)
		q_no.collide_with_areas = true
		var r_no := space.intersect_ray(q_no)
		var q_yes := PhysicsRayQueryParameters3D.create(inside_origin, inside_origin + Vector3.FORWARD * 2.0, 5)
		q_yes.collide_with_areas = true
		q_yes.hit_from_inside = true
		var r_yes := space.intersect_ray(q_yes)
		check(r_no.is_empty(), "inside-origin ray whiffs without hit_from_inside (the old bug)")
		check(not r_yes.is_empty() and r_yes.get("collider") == body_area,
			"inside-origin ray registers the hitbox with hit_from_inside")

	# --- Location damage through the real _apply_rifle_damage path ---
	var shooter = PlayerScript.new()
	world.add_child(shooter)
	var notices: Array[String] = []
	shooter.notice.connect(func(m: String) -> void: notices.append(m))

	if body_area != null:
		shooter._apply_rifle_damage(body_area, body_area.global_position, 1.0)
		check("¡Impacto al jugador!" in notices, "body hit reports '¡Impacto al jugador!'")
		check(puppet.third_person_action_animation.is_empty(),
			"unconfirmed client-side hit does not fake a victim reaction before server validation")
		puppet._play_shot_reaction() # same callback the server's reliable hit event invokes
		check(puppet.third_person_action_animation == puppet.third_person_shot_animation,
			"server-confirmed rifle hit plays the shot-received reaction on the victim")
	if head_area != null:
		notices.clear()
		shooter._apply_rifle_damage(head_area, head_area.global_position, 1.0)
		check("¡Disparo en la cabeza!" in notices, "head hit reports '¡Disparo en la cabeza!'")

	world.free()
	if failures == 0:
		print("PASS: rifle point-blank and location damage verified")
	quit(1 if failures else 0)
