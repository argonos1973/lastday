extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _sync_held_item(): pass
	func play_action_animation(_a: String, _d: float = 1.1): pass
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	for kind in ["plant", "drink"]:
		var item = preload("res://scripts/Item.gd").create("Naranja","food",.1,2,10)
		actor.inventory.add_item(item)
		actor._start_consumption(item,kind,2.0)
		check(actor._get_current_anim() == ("drink" if kind=="drink" else "plant_eat"), "Network intent distinguishes eating from planting")
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
	print("CONSUMPTION_AUDIO_ERRORS=",errors)
	quit(1 if errors else 0)
