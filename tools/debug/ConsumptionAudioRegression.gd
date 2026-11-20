extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _sync_held_item(): pass
	func play_action_animation(_a: String, _d: float = 1.1): pass
class VisualActor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _sync_held_item(): pass
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func check_bottle_timeline():
	var actor := VisualActor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.stats.set_process(false)
	actor.setup_as_puppet()
	var ap: AnimationPlayer = actor.third_person_animation_player
	check(not actor.third_person_eat_animation.is_empty(), "Eating take is installed")
	check(ap.get_animation(actor.third_person_eat_animation) != ap.get_animation(actor.third_person_drink_animation),
		"Food and bottle use different animation resources")
	for remote in [false, true]:
		actor.is_puppet = remote
		actor._consumption_pending = not remote
		actor._consumption_is_drink = true
		ap.play(actor.third_person_drink_animation, 0.0)
		ap.speed_scale = 0.0
		ap.seek(0.0, true)
		if remote:
			actor._sync_puppet_action_audio("drink")
		else:
			actor._play_consumption_audio(true, actor._drink_animation_length, actor._mark_action_started())
		ap.seek(2.8, true)
		await process_frame
		await process_frame
		check(not actor._consumption_audio.playing, "Bottle lift is silent, remote=" + str(remote))
		ap.seek(3.4, true)
		await process_frame
		await process_frame
		check(actor._consumption_audio.playing, "Sip sounds at mouth contact, remote=" + str(remote))
		ap.seek(5.1, true)
		await process_frame
		await process_frame
		check(not actor._consumption_audio.playing, "Lowered bottle is silent, remote=" + str(remote))
		ap.seek(0.0, true)
		await process_frame
		await process_frame
		ap.seek(3.4, true)
		await process_frame
		await process_frame
		check(actor._consumption_audio.playing, "A new animation cycle can sip, remote=" + str(remote))
		if remote: actor._sync_puppet_action_audio("idle")
		else: actor.cancel_active_action()
		await process_frame
		check(not actor._consumption_audio.playing, "Cancellation stops the synchronized sip")
		actor._consumption_pending = not remote
		actor._consumption_is_drink = false
		actor.puppet_apply_visuals("", "Naranja", "")
		actor._build_eating_prop()
		check(actor.third_person_hand_item_root.visible, "Fruit stays visible in the right hand")
		check(actor._drink_hand_root.get_child_count() == 0, "Eating does not build a left-hand bottle")
		ap.play(actor.third_person_eat_animation, 0.0)
		ap.speed_scale = 0.0
		ap.seek(0.0, true)
		if remote: actor._sync_puppet_action_audio("eat")
		else: actor._play_consumption_audio(false, 2.0, actor._mark_action_started())
		await process_frame
		await process_frame
		check(not actor._consumption_audio.playing, "Fruit lift is silent")
		ap.seek(0.75, true)
		await process_frame
		await process_frame
		check(actor._consumption_audio.playing, "Bite sounds when fruit reaches the mouth")
		if remote: actor._sync_puppet_action_audio("idle")
		else: actor.cancel_active_action()
		await process_frame
		check(not actor._consumption_audio.playing, "Cancelling food stops its bite recording")
	actor.set_meta("is_ai_bot", true)
	actor.puppet_apply_visuals("", "Botella de agua", "")
	actor.puppet_apply(Vector3.ZERO, 0.0, "drink")
	ap.speed_scale = 0.0
	check(absf(ap.current_animation_position - (actor.DRINK_SIP_START - 0.15)) < 0.001,
		"The bot's 1.6-second action enters the useful part of the drinking take")
	await process_frame
	await process_frame
	check(not actor._consumption_audio.playing, "Bot hand blend precedes the sip sound")
	ap.seek(actor.DRINK_SIP_START + 0.1, true)
	await process_frame
	await process_frame
	check(actor._consumption_audio.playing, "Short bot action reaches the audible sip")
	actor.puppet_apply(Vector3.ZERO, 0.0, "idle")
	check(not actor._consumption_audio.playing, "Bot resuming its activity stops consumption audio")
	actor.queue_free()
	await process_frame
func run():
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	for kind in ["eat", "drink"]:
		var item = preload("res://scripts/Item.gd").create("Naranja","food",.1,2,10)
		actor.inventory.add_item(item)
		actor._start_consumption(item,kind,2.0)
		check(actor._get_current_anim() == kind, "Network intent distinguishes eating from planting")
		await create_timer(.4).timeout
		check(is_instance_valid(actor._consumption_audio), "Own consumption audio player exists")
		if is_instance_valid(actor._consumption_audio):
			check(actor._consumption_audio.stream != null and actor._consumption_audio.stream.get_length() > .05, "Decodable consumption recording")
		actor.cancel_active_action()
		check(actor._get_current_anim() == "idle", "Cancellation clears consumption intent")
		check(not actor._consumption_audio.playing, "Cancellation stops sound")
		await create_timer(1.8).timeout
		check(not actor._consumption_audio.playing, "Cancelled timers cannot restart sound")
	actor._is_reloading = true
	actor._play_reload_sound()
	check(actor._reload_audio_player != null and actor._reload_audio_player.playing, "Reload starts its own recording")
	actor.cancel_active_action()
	check(not actor._reload_audio_player.playing, "Cancelling reload stops its recording")
	actor.is_puppet = true
	actor._sync_puppet_action_audio("reload")
	var stamp: int = actor._last_reload_audio_msec
	await create_timer(.05).timeout
	actor._play_reload_sound()
	check(actor._last_reload_audio_msec==stamp, "Reliable reload event and animation share one playback")
	actor._sync_puppet_action_audio("idle")
	check(not actor._reload_audio_player.playing, "Remote cancelled reload stops its recording")
	actor._sync_puppet_action_audio("reload")
	check(actor._reload_audio_player.playing, "New reload after cancellation is not lost to duplicate-event guard")
	actor._sync_puppet_action_audio("dead")
	check(not actor._reload_audio_player.playing, "Death silences reload")
	actor.queue_free()
	await process_frame
	await check_bottle_timeline()
	# Canceled reload recordings retain their bounded timers until expiry.
	# Let those callbacks retire before the test SceneTree is destroyed.
	await create_timer(2.3).timeout
	print("CONSUMPTION_AUDIO_ERRORS=",errors)
	quit(1 if errors else 0)
