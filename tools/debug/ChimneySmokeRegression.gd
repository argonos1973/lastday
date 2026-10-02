extends SceneTree

# Chimney smoke regression: a fire lit inside a house footprint must emit its
# smoke from that house's chimney top instead of rising through the roof.
# - _chimney_top_for resolves the chimney record only for points inside the
#   house footprint rect (registered by _create_house_details)
# - _create_campfire_fire/_create_torch_fire pass the chimney top to
#   FireVisuals.smoke_origin, which relocates the smoke emitter while flames
#   and light stay at the fire
# - Outdoor fires keep emitting smoke at the fire position

const MainScript = preload("res://scripts/Main.gd")

class FakeWorld extends Node3D:
	var hud = null

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := FakeWorld.new()
	root.add_child(world)
	current_scene = world
	var main = MainScript.new()
	world.add_child(main)

	# Chimney lookup: only points inside the footprint rect resolve a top.
	var top := Vector3(12.3, 6.5, 16.2)
	main._house_chimneys.append({
		"bounds": Rect2(Vector2(5, 16), Vector2(10, 8)),
		"top": top,
	})
	var found: Variant = main._chimney_top_for(Vector3(8, 0.1, 20))
	check(found is Vector3 and (found as Vector3).is_equal_approx(top), "fire inside footprint resolves chimney top")
	check(main._chimney_top_for(Vector3(50, 0, 50)) == null, "far outdoor fire resolves no chimney")
	check(main._chimney_top_for(Vector3(8, 0.1, 30)) == null, "fire beyond footprint resolves no chimney")

	# Campfire inside the house: smoke emitter relocates to the chimney top
	# while flames stay at the fire.
	var fire_pos := Vector3(8, 0.0, 20)
	main._create_campfire_fire(fire_pos + Vector3(0, 0.15, 0), "TestFireA")
	var fx = main.get_node_or_null("TestFireALight/FireVisuals")
	check(fx != null, "indoor campfire creates FireVisuals")
	await process_frame
	check(fx._smoke.global_position.is_equal_approx(top), "indoor campfire smoke emits at chimney top")
	check(fx._flame.global_position.distance_to(fire_pos) < 0.6, "flames stay at the indoor fire")

	# Placed torch inside the house: same redirect.
	main._create_torch_fire("TestTorch", fire_pos + Vector3(0, 0.7, 0), 60.0)
	var fx_torch = main.get_node_or_null("TestTorchLight/FireVisuals")
	check(fx_torch != null, "indoor torch creates FireVisuals")
	await process_frame
	check(fx_torch._smoke.global_position.is_equal_approx(top), "indoor torch smoke emits at chimney top")

	# Campfire outdoors: smoke emits at the fire itself (smoke offset 0.35).
	var out_pos := Vector3(50, 0, 50)
	main._create_campfire_fire(out_pos, "TestFireB")
	var fx2 = main.get_node_or_null("TestFireBLight/FireVisuals")
	check(fx2 != null, "outdoor campfire creates FireVisuals")
	await process_frame
	check(fx2._smoke.global_position.distance_to(out_pos + Vector3(0, 0.35, 0)) < 0.2, "outdoor campfire smoke stays at fire")

	world.free()
	if failures == 0:
		print("PASS: indoor fire smoke exits through the house chimney")
	quit(1 if failures else 0)
