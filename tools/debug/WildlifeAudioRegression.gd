extends SceneTree
const Bank = preload("res://scripts/WildlifeAudio.gd")
class World extends "res://scripts/Main.gd":
	func _ready(): set_process(false); set_physics_process(false)
	func _exit_tree(): pass
class Actor extends "res://scripts/PlayerController.gd":
	var rebuilds := 0
	func _ready():
		set_process(false); set_physics_process(false)
		stats = SurvivalStats.new(); add_child(stats)
		stats.set_process(false); stats.set_physics_process(false)
		inventory = Inventory.new(); add_child(inventory)
		inventory.changed.connect(_on_inventory_changed)
	func _sync_held_item(): rebuilds += 1
class Animal extends "res://scripts/WildlifeController.gd":
	func _ready(): set_process(false); set_physics_process(false)
	func _build_animal(): pass
class Net extends Node:
	func get_my_id() -> int: return 42
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; push_error(label)
func run():
	print("AUDIO_OUTPUT driver=", AudioServer.get_driver_name(), " device=", AudioServer.output_device, " input=", ProjectSettings.get_setting("audio/driver/enable_input"))
	if OS.get_cmdline_user_args().has("--require-output") and AudioServer.get_driver_name() == "Dummy":
		push_error("Real output required: an internal Dummy mix cannot prove audible playback")
		quit(1)
		return
	var world := World.new(); root.add_child(world); current_scene = world
	world.net = Net.new(); world.add_child(world.net)
	var actor := Actor.new(); actor.name = "Player"; world.add_child(actor); world.player = actor
	Bank.prepare()
	for path in Bank.PAW_SOFT + Bank.PAW_HARD + Bank.HOOF + Bank.WOLF_WALK + Bank.WOLF_RUN + Bank.WOLF_EAT + Bank.WOLF_GROWL + Bank.WOLF_ATTACK + [Bank.BEAR_ATTACK, Bank.BEAR_GROWL, Bank.BITE]:
		var sample := Bank.stream(path)
		check(sample is AudioStreamWAV and sample.loop_mode == AudioStreamWAV.LOOP_DISABLED, path+" non-looping PCM")
		check(sample != null and sample.get_length() > .08 and sample.get_length() < 4.0, path+" bounded clip")
		check(sample == Bank.stream(path), path+" cached")
	check(Bank.step("wolf",false,0) != Bank.step("deer",false,0),"paws and hooves have distinct recordings")
	var wolf_run_streams := Bank.WOLF_RUN.map(func(p): return Bank.stream(p))
	check(Bank.step("wolf",true,0,true) in wolf_run_streams,"running wolf uses its own gallop bank")
	check(Bank.step("wolf",true,0,false) in Bank.WOLF_WALK.map(func(p): return Bank.stream(p)),"walking wolf uses LOBOS walking recording")
	check(Bank.step("fox",true,0,true) in Bank.PAW_HARD.map(func(p): return Bank.stream(p)),"wolf run bank does not leak to fox")
	var camera := Camera3D.new(); world.add_child(camera); camera.position = Vector3(0,1.5,4); camera.make_current()
	test_wolf_actions(world)
	var audio := AudioSystem.new(); world.add_child(audio); audio.set_process(false)
	audio._create_players(); audio._load_footstep_audio(); audio.player = actor
	var species_samples := {}
	for species in ["wolf","deer","fox","bear"]:
		var animal := Animal.new(); animal.animal_type = species; animal.is_puppet = true
		world.add_child(animal)
		var key: String = "a:"+species
		for i in 60:
			animal.position.x += .05
			audio._remote_actor_steps({},key,animal,"walk",1.0/60,Vector3.ZERO,true)
			# Let this simulated mixer retire short voices between iterations.
			for voice in audio._remote_step_players:
				if voice.stream != null: species_samples[species] = voice.stream
				voice.stop()
				voice.stream = null
		check(int(audio._remote_step_phase.get(key,0)) > 1,species+" contacts follow displacement")
		check(species_samples.get(species) in [Bank.step(species,false,0),Bank.step(species,false,1),Bank.step(species,false,2)],species+" uses its own step bank")
		var phase := int(audio._remote_step_phase.get(key,0))
		for i in 30: audio._remote_actor_steps({},key,animal,"run",1.0/60,Vector3.ZERO,true)
		check(int(audio._remote_step_phase.get(key,0)) <= phase,species+" stationary stale run cannot make steps")
		animal.position.x += 50
		audio._remote_actor_steps({},key,animal,"run",1.0/60,animal.position,true)
		check(int(audio._remote_step_phase.get(key,0)) <= phase,species+" teleport does not create steps")
		animal._play_wolf_sound("attack") if species in ["wolf","bear"] else animal._play_pain_sound()
		if species == "wolf":
			check(animal._wolf_audio_player.stream in Bank.WOLF_ATTACK.map(func(p): return Bank.stream(p)),"wolf attack uses the supplied fight bank")
		if species == "bear":
			check(animal._wolf_audio_player.stream == Bank.stream(Bank.BEAR_ATTACK),"bear no longer uses a pitched wolf growl")
		if species in ["deer","fox"]:
			check(animal._wolf_pain_player is AudioStreamPlayer3D,"prey pain is spatial, not global 2D")
		animal._is_dead = true
		if animal._wolf_audio_player != null: animal._wolf_audio_player.stop()
		animal._play_wolf_sound("growl")
		check(animal._wolf_audio_player == null or not animal._wolf_audio_player.playing,"dead "+species+" stays silent")
		animal.free()
	# Measure actual emitted contacts with a free mixer voice. Without retiring
	# voices, a synthetic loop can fill the pool and falsely pass a rate check.
	for sprint_case in [["wolf", 8.0], ["bear", 6.5]]:
		var species_s: String = sprint_case[0]; var spd_s: float = sprint_case[1]
		for fps in [30, 60, 144]:
			var sprinter := Animal.new(); sprinter.animal_type = species_s; sprinter.is_puppet = true
			world.add_child(sprinter)
			var skey := "a:sprint_%s_%d" % [species_s, fps]
			var contacts: Array[float] = []
			audio._remote_actor_steps({}, skey, sprinter, "run", 1.0/fps, sprinter.position, true)
			for i in 4*fps:
				for voice in audio._remote_step_players: voice.stop()
				sprinter.position.x += spd_s/fps
				var before := int(audio._remote_step_phase.get(skey, 0))
				audio._remote_actor_steps({}, skey, sprinter, "run", 1.0/fps, sprinter.position, true)
				if int(audio._remote_step_phase.get(skey, 0)) > before: contacts.append(float(i+1)/fps)
			var expected := 4.0 / float(Bank.SPECIES[species_s].run_cycle)
			check(absf(contacts.size()-expected) <= 1.0, species_s+" sprint rate at "+str(fps)+" FPS: "+str(contacts.size()/4.0)+" contacts/s")
			var short_gap := INF; var long_gap := 0.0
			for i in range(1, contacts.size()):
				var gap := contacts[i]-contacts[i-1]
				short_gap = minf(short_gap, gap); long_gap = maxf(long_gap, gap)
			check(long_gap > short_gap*1.5, species_s+" alternates short/long contacts instead of a uniform roll")
			print("SPRINT_CADENCE species=",species_s," fps=",fps," contacts_per_second=",contacts.size()/4.0," gaps=",short_gap,"/",long_gap)
			sprinter.free()
	# Bite is a reliable victim effect, even without an animal puppet loaded.
	for cause in ["wolf_bite","bear_bite"]:
		actor.stats.health = 100
		actor._last_bite_audio_msec = -10000
		world._net_apply_damage(12,cause)
		check(actor.stats.health == 88,"one damage application for "+cause)
		check(actor._bite_audio_player != null and actor._bite_audio_player.playing,"victim hears "+cause+" without animal sound RPC")
		check(actor._impact_audio_player == null,"bite does not use punch audio")
	var stamp := actor._last_bite_audio_msec
	world._net_player_hit_event(42,"wolf_bite",Vector3.ZERO)
	check(actor._last_bite_audio_msec==stamp,"duplicate impact feedback cannot restart bite audio")
	var observer := Actor.new(); observer.is_puppet = true; world.add_child(observer); world.remote_players[901] = observer
	world._net_player_hit_event(901,"bear_bite",Vector3.ZERO)
	check(observer._bite_audio_player is AudioStreamPlayer3D and observer._bite_audio_player.playing,"observers hear positional confirmed bite")
	# Breaking clothing previously rebuilt the held rifle and sling in the hit callback.
	var shirt = Item.create("Camiseta","clothing",.3,1,0)
	shirt.durability = .2
	actor._equipped_slots["torso"] = "Camiseta"
	actor.inventory.items.append(shirt)
	var notifications := [0]
	actor.inventory.condition_changed.connect(func(): notifications[0] += 1)
	var before := actor.rebuilds
	actor.stats.health = 100
	world._net_apply_damage(12,"wolf_bite")
	check(shirt.is_broken() and notifications[0]==1,"broken garment still notifies inventory UI")
	check(actor.rebuilds==before,"bite breaking clothing does not rebuild rifle/sling/IK")
	actor.inventory.changed.emit()
	check(actor.rebuilds==before+1,"real inventory changes still update hand equipment")
	# Hurt feedback reuses bounded effects and voice nodes, no growing allocation.
	for slot in actor._prepare_blood_effects().slots: slot.available_at = 0
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var times: Array[float] = []
	for i in 150:
		actor.stats.health = 100
		actor._last_bite_audio_msec = -10000
		var start := Time.get_ticks_usec()
		world._net_apply_damage(12,"wolf_bite")
		times.append(float(Time.get_ticks_usec()-start)/1000)
	times.sort()
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)==nodes,"150 bites reuse the same effects and sound players")
	print("BITE_CPU_MS p95=",times[142]," max=",times.back())
	if DisplayServer.get_name() != "headless": await verify_mix(actor, audio)
	world.queue_free()
	for i in 4: await process_frame
	print("WILDLIFE_AUDIO checks=",checks," failures=",failures)
	quit(1 if failures else 0)

func test_wolf_actions(world: World) -> void:
	var animal := Animal.new()
	animal.animal_type = "wolf"
	animal.is_puppet = true
	world.add_child(animal)
	# The same packet/application path works for a join during an existing meal.
	animal.puppet_apply(Vector3.ZERO, 0.0, "eat", false, false)
	animal._sync_wolf_eating_audio()
	check(animal._wolf_audio_player != null and animal._wolf_audio_player.playing, "eat snapshot starts spatial chewing")
	var voice := animal._wolf_audio_player
	check(voice.stream in Bank.WOLF_EAT.map(func(p): return Bank.stream(p)), "chewing uses LOBO_COMIENDO")
	var clip := voice.stream
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for frame in 100:
		animal._sync_wolf_eating_audio()
	check(voice == animal._wolf_audio_player and voice.stream == clip and Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == nodes, "meal reuses one voice without restarting/allocating every frame")
	animal._play_wolf_sound("growl")
	check(voice.stream == clip, "ambient growl cannot overwrite a meal")
	animal.puppet_apply(Vector3.ZERO, 0.0, "walk", false, false)
	animal._sync_wolf_eating_audio()
	check(not voice.playing, "leaving the eat pose stops chewing")
	animal.puppet_apply(Vector3.ZERO, 0.0, "eat", false, false)
	animal._sync_wolf_eating_audio()
	world.puppet_animals["audio_test"] = animal
	world._net_animal_sound("audio_test", "attack")
	animal._sync_wolf_eating_audio()
	check(animal.current_anim_keyword == "attack" and voice.stream in Bank.WOLF_ATTACK.map(func(p): return Bank.stream(p)), "network attack interrupts chewing with actual attack audio")
	animal._puppet_attack_timer = 0.0
	animal._puppet_combat_active = false
	animal.puppet_apply(Vector3.ZERO, 0.0, "eat", false, false)
	animal._sync_wolf_eating_audio()
	animal.position = Vector3(100, 0, 0)
	animal._sync_wolf_eating_audio()
	check(not voice.playing, "distant meals stay silent")
	animal.position = Vector3.ZERO
	animal._sync_wolf_eating_audio()
	check(voice.playing, "nearby ongoing meal becomes audible")
	animal.puppet_apply(Vector3.ZERO, 0.0, "idle", true, false, 240.0)
	animal._sync_wolf_eating_audio()
	check(not voice.playing, "death cancels the meal sound")
	world.puppet_animals.erase("audio_test")
	animal.free()
	var server_wolf := Animal.new()
	world.add_child(server_wolf)
	server_wolf.animal_type = "wolf"
	server_wolf._is_dedicated = true
	server_wolf.current_anim_keyword = "eat"
	server_wolf._wolf_eating_timer = 8.0
	server_wolf._sync_wolf_eating_audio()
	check(server_wolf._wolf_audio_player == null, "dedicated wolf allocates no eating voice")
	server_wolf.free()

func verify_mix(actor: Actor, audio: AudioSystem):
	var bus := AudioServer.bus_count
	AudioServer.add_bus(); AudioServer.set_bus_name(bus,"WildlifeTest")
	var capture := AudioEffectCapture.new(); capture.buffer_length = 1.0
	AudioServer.add_bus_effect(bus,capture)
	root.audio_listener_enable_3d = true
	actor._bite_audio_player.bus = "WildlifeTest"
	var vocal := Animal.new()
	current_scene.add_child(vocal)
	vocal.animal_type = "wolf"
	vocal.is_puppet = true
	vocal._prepare_animal_voice()
	vocal._wolf_audio_player.bus = "WildlifeTest"
	await process_frame
	for label in ["wolf_bite","bear_bite","wolf_step","deer_step","fox_step","bear_step","wolf_run","wolf_growl","wolf_eat"]:
		capture.clear_buffer()
		if label.ends_with("bite"):
			actor._last_bite_audio_msec = -10000
			actor._play_animal_bite_sound(label)
		elif label in ["wolf_growl", "wolf_eat"]:
			vocal.current_anim_keyword = "eat" if label == "wolf_eat" else "idle"
			if label == "wolf_eat": vocal._sync_wolf_eating_audio()
			else: vocal._play_wolf_sound("growl")
		else:
			var species: String = label.trim_suffix("_step")
			if label == "wolf_run": species = "wolf"
			audio._animal_step_species[label] = species
			for voice in audio._remote_step_players: voice.bus = "WildlifeTest"
			audio._play_remote_step(label,Vector3.ZERO,"run" if label == "wolf_run" else "walk",true)
		await create_timer(.7).timeout
		var samples := capture.get_buffer(capture.get_frames_available())
		var peak := 0.0
		for sample in samples: peak = maxf(peak,maxf(absf(sample.x),absf(sample.y)))
		check(peak > .005 and peak < .95,label+" produces audible audio with headroom")
		print("ANIMAL_OUTPUT ",label," peak=",peak)
		vocal._wolf_audio_player.stop()
	vocal.free()
	actor._bite_audio_player.bus = "Master"
	for voice in audio._remote_step_players: voice.bus = "Master"
	AudioServer.remove_bus(bus)
