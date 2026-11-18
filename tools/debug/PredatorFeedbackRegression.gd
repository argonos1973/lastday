extends SceneTree
# Exercise frames after a confirmed hit, not just AnimationPlayer.play().
const Fixture = preload("res://tools/debug/WildlifeAudioRegression.gd")
var checks := 0
var errors := 0

func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: errors += 1; push_error(label)

func actor_with_rig(world, puppet: bool):
	var actor := Fixture.Actor.new()
	actor.is_puppet = puppet
	world.add_child(actor)
	actor.third_person_model = Node3D.new(); actor.add_child(actor.third_person_model)
	actor.camera = Camera3D.new(); actor.add_child(actor.camera)
	actor.third_person_animation_player = AnimationPlayer.new(); actor.add_child(actor.third_person_animation_player)
	var library := AnimationLibrary.new()
	for name in ["hit", "run", "attack", "idle", "shot"]:
		var clip := Animation.new(); clip.length = .5
		library.add_animation(name, clip)
	actor.third_person_animation_player.add_animation_library("test", library)
	actor.third_person_hit_animation = "test/hit"
	actor.third_person_run_animation = "test/run"
	actor.third_person_idle_animation = "test/idle"
	actor.third_person_attack_animation = "test/attack"
	actor.third_person_shot_animation = "test/shot"
	return actor

func run():
	var world := Fixture.World.new(); root.add_child(world); current_scene = world
	world.net = Fixture.Net.new(); world.add_child(world.net)
	for bite in ["wolf_bite", "bear_bite"]:
		var actor = actor_with_rig(world, false); world.player = actor
		actor.is_moving = true; actor.is_sprinting = true; actor._is_aiming = true
		actor.velocity = Vector3(0, 0, -6)
		actor.third_person_action_start_offset = .45
		world._net_apply_damage(12, bite)
		actor._update_third_person_animation(true, 1.0 / 60.0)
		check(actor.third_person_action_timer > .15, bite+" flinch survives the next moving frame")
		check(actor.third_person_animation_player.current_animation == "test/hit", bite+" flinch is not replaced by run")
		check(actor.third_person_action_start_offset == 0.0, bite+" cannot inherit a previous action's seek offset")
		check(actor.velocity == Vector3(0, 0, -6), bite+" does not freeze escape movement")
		check(not actor._is_aiming, bite+" breaks ADS")
		actor._mounted_rifle_is_m4 = true
		actor.is_sprinting = false
		check(not actor._m4_camera_ready(), bite+" cannot be masked by automatic M4 camera aiming")
		actor._mounted_rifle_is_m4 = false; actor.is_sprinting = true
		actor._recoil_yaw = .04 # deterministic side impulse, no probabilistic assertion
		actor._update_walk_motion(1.0 / 60.0, 0)
		check(is_equal_approx(actor.camera.rotation.x, actor._pitch+actor._recoil_pitch), bite+" reaches the camera pitch")
		check(is_equal_approx(actor.camera.rotation.y, .04), bite+" reaches the camera yaw")
		for i in 20: actor._update_third_person_animation(true, 1.0 / 60.0)
		check(actor.third_person_animation_player.current_animation == "test/run", bite+" returns to running after the short flinch")
		actor._recoil_pitch = 0; actor._recoil_yaw = 0
		actor._update_walk_motion(1.0 / 60.0, 0)
		check(is_zero_approx(actor.camera.rotation.y), bite+" camera recovers without a mouse event")
		world.player = null; actor.free()
		var observer = actor_with_rig(world, true); world.remote_players[901] = observer
		observer.puppet_set_aiming(true)
		observer._throw_aim_hold = true; observer._throw_aim_frozen = true
		world._net_player_hit_event(901, bite, Vector3.ZERO)
		observer.puppet_set_aiming(true) # stale state snapshot after the reliable impact
		observer.puppet_apply(Vector3.ZERO, 0, "test/attack")
		observer._process(1.0 / 60.0)
		check(observer.third_person_animation_player.current_animation == "test/hit", bite+" survives an old attack snapshot")
		check(not observer._is_aiming and not observer._throw_aim_hold, bite+" observer cannot reapply aiming over the flinch")
		check(observer.stats.health == 100 and observer._recoil_pitch == 0, bite+" observer remains presentation-only")
		for i in 20:
			observer.puppet_apply(Vector3.ZERO, 0, "test/run")
			observer._process(1.0 / 60.0)
		observer.puppet_apply(Vector3.ZERO, 0, "test/run")
		observer.puppet_set_aiming(true)
		check(observer.third_person_animation_player.current_animation == "test/run" and observer._is_aiming, bite+" observer resumes current state after impact")
		world._net_player_hit_event(901, bite, Vector3.ZERO)
		observer.puppet_apply(Vector3.ZERO, 0, "dead")
		check(observer.is_dead and observer.third_person_action_timer == 0, bite+" does not hide an authoritative death snapshot")
		world.remote_players.erase(901); observer.free()
	world.queue_free()
	for i in 4: await process_frame
	print("PREDATOR_FEEDBACK checks=", checks, " errors=", errors)
	quit(1 if errors else 0)
