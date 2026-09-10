extends SceneTree
var failed := 0
var checks := 0
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func _initialize(): call_deferred("run")
func run():
	var light := OmniLight3D.new()
	root.add_child(light)
	var effect := preload("res://scripts/FireVisuals.gd").new()
	light.add_child(effect)
	await process_frame
	check(effect._flame.mesh != null and effect._smoke.mesh != null, "Fire and smoke have drawable meshes")
	check(not effect._smoke.mesh.material.no_depth_test, "Smoke respects occlusion")
	check(effect._smoke.color_ramp.get_color(3).a == 0.0, "Smoke fades out")
	check(effect._smoke.emitting and effect._flame.emitting, "Lit fire emits both effects")
	light.visible = false
	await process_frame
	await process_frame
	check(not effect._smoke.emitting and not effect._flame.emitting, "Extinguished held torch stops emission")
	light.visible = true
	await process_frame
	await process_frame
	check(effect._smoke.emitting, "Relighting restarts smoke")
	light.queue_free()
	await process_frame
	check(not is_instance_valid(effect), "Removing fire removes particles")
	print("FIRE VISUALS: %d checks, %d failures" % [checks, failed])
	quit(1 if failed else 0)
