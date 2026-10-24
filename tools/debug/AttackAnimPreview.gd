extends SceneTree

## Renders the spear-throw wind-up: the AttackExternal clip frozen at the
## G-charge hold point (0.4s) with a Lanza in hand — what the player now sees
## while aiming a throwable.

class Actor extends "res://scripts/PlayerController.gd":
	var _saved_last_drink_ms := 0
	func _get_hud(): return null
	func _get_stats(): return null
	func _setup_multiplayer_role() -> void: pass
	func _enter_net_role() -> void: pass
	func _init_net_role() -> void: pass
	func _setup_camera() -> void: pass
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		setup_as_puppet()

var actor: Actor = null

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	actor = Actor.new()
	root.add_child(actor)
	for i in 10:
		await process_frame
	actor._update_puppet_held_item("Lanza de hueso")
	actor._is_aiming = true

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.16, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.68
	root.add_child(env)

	var camera := Camera3D.new()
	camera.fov = 50.0
	root.add_child(camera)
	camera.make_current()

	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	DirAccess.make_dir_recursive_absolute("res://build/tmp")
	var ap: AnimationPlayer = actor.third_person_animation_player
	var anim_name := "external/AttackExternal"
	print("HAS attack=", ap.has_animation(anim_name))

	# Freeze the clip at the wind-up hold point (same as G charge at 0.4s)
	# and also render the release frame further along.
	for clip_info in [
		["windup", 0.40],
		["release", 0.62],
		["follow", 0.95],
	]:
		var tag: String = clip_info[0]
		var seek_t: float = clip_info[1]
		ap.play(anim_name, 0.0)
		ap.seek(seek_t, true)
		ap.advance(0.0)
		ap.pause()
		for i in range(6):
			skel.force_update_all_bone_transforms()
			actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
			actor._update_hand_socket()
			await process_frame

		var focus := actor.global_position + Vector3(0.0, 1.42, -0.22)
		var views := {
			"side": [focus + Vector3(2.55, 0.10, 0.0), focus],
			"three_quarter": [focus + Vector3(1.85, 0.16, -1.75), focus],
			"over_shoulder": [actor.global_position + Vector3(0.36, 1.50, 1.45), actor.global_position + Vector3(-0.04, 1.48, -6.5)],
		}
		for vname in views:
			camera.global_position = views[vname][0]
			camera.look_at(views[vname][1], Vector3.UP)
			for f in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var out_path := "res://build/tmp/spear_%s_%s.png" % [tag, vname]
			root.get_texture().get_image().save_png(out_path)
			print("Saved ", out_path)
	print("DONE")
	quit(0)
