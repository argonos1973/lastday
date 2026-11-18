extends SceneTree
# Damage audio/animation regression: the user-provided mordedura/malo/
# saltardano/recibirdisparo assets load through the real code paths, the
# shot-reaction clip is trimmed to the impact only (no fall to the ground),
# and remote puppets play every new damage sound positionally.
# Run:
#   work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/DamageAudioRegression.gd

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
	# --- Assets exist and load ---
	for p in ["res://assets/audio/mordedura.mp3", "res://assets/audio/malo.mp3",
			"res://assets/audio/saltardano.mp3", "res://assets/audio/recibirdisparo.mp3",
			"res://assets/animations/RecibirDisparo.glb"]:
		check(ResourceLoader.exists(p), "resource exists: " + p)
	var bite_stream: AudioStream = load("res://assets/audio/mordedura.mp3")
	check(bite_stream != null and bite_stream.get_length() < 2.2,
		"mordedura.mp3 has leading/trailing silence trimmed (len=%.2fs)" % (bite_stream.get_length() if bite_stream != null else -1.0))

	var shot_scene: PackedScene = load("res://assets/animations/RecibirDisparo.glb")
	check(shot_scene != null, "RecibirDisparo.glb loads as PackedScene")
	if shot_scene != null:
		var inst := shot_scene.instantiate()
		var best_len := 0.0
		var found := false
		for n in inst.get_children():
			var ap := _find_anim_player(n)
			if ap == null:
				continue
			for an in ap.get_animation_list():
				found = true
				best_len = maxf(best_len, ap.get_animation(an).length)
		check(found, "RecibirDisparo.glb contains an AnimationPlayer clip")
		# The donor clip must only cover the impact (frames 1-14 @30fps =
		# 0.467 s); anything near the original ~2 s means the fall is back.
		check(best_len > 0.1 and best_len < 0.6,
			"shot clip is trimmed to the impact only (len=%.3f)" % best_len)
		inst.free()

	# --- Real PlayerController wiring ---
	var PlayerScript := preload("res://scripts/PlayerController.gd")
	var world := Node3D.new()
	root.add_child(world)

	var puppet = PlayerScript.new()
	puppet.is_puppet = true
	world.add_child(puppet)
	puppet.setup_as_puppet()

	# The shot clip must be retargeted into the "shot" library on puppets too
	# (remote victims flinch through the synced action-anim slot).
	check(not puppet.third_person_shot_animation.is_empty(),
		"puppet shot animation loaded (got '%s')" % puppet.third_person_shot_animation)
	check(puppet.third_person_shot_animation == "shot/ShotReceivedExternal",
		"shot animation resolves to shot/ShotReceivedExternal")
	if not puppet.third_person_shot_animation.is_empty():
		check(puppet.third_person_animation_player.has_animation(puppet.third_person_shot_animation),
			"puppet animation player has the shot clip")
		var retargeted: Animation = puppet.third_person_animation_player.get_animation(puppet.third_person_shot_animation)
		check(retargeted != null and retargeted.length < 0.6,
			"retargeted shot clip stays under 0.6 s (no fall segment)")
		check(retargeted != null and retargeted.loop_mode == Animation.LOOP_NONE,
			"shot clip does not loop")

	# The synced action-anim name must route to the shot clip on puppets.
	puppet.puppet_apply(puppet.global_position, 0.0, "shot/ShotReceivedExternal")
	check(puppet._puppet_current_anim == "shot/ShotReceivedExternal",
		"puppet maps synced shot clip name to the shot animation")
	puppet._play_shot_reaction()
	check(puppet.third_person_action_animation == puppet.third_person_shot_animation,
		"shot reaction travels through the synced action-anim slot")

	# Every new damage sound must be positional on puppets, 2D on the local
	# player — same rule as the other action sounds.
	puppet._play_shot_received_sound()
	puppet._play_fall_damage_sound()
	puppet._play_unwell_sound()
	puppet._play_pain_sound()
	await create_timer(1.6).timeout
	check(puppet._pain_sound_timer <= 0.0, "puppet pain cooldown expires for subsequent hits")
	puppet._play_pain_sound()
	check(puppet._pain_sound_timer > 0.0, "a second remote hit plays pain again")
	puppet._play_shoot_sound()
	for pl in [puppet._shot_audio_player, puppet._fall_audio_player, puppet._unwell_audio_player]:
		check(pl is AudioStreamPlayer3D, "puppet damage sound '%s' is positional" % (str(pl.name) if pl != null else "null"))
	# Gunshots must carry much farther than melee/pain sounds — a distant
	# rifle report is audible across the map, a punch is not.
	check(puppet._shoot_audio_player is AudioStreamPlayer3D
			and (puppet._shoot_audio_player as AudioStreamPlayer3D).max_distance >= 300.0,
		"gunshot carries far (max_distance=%.0f)" % (
			(puppet._shoot_audio_player as AudioStreamPlayer3D).max_distance if puppet._shoot_audio_player is AudioStreamPlayer3D else -1.0))
	check(puppet._shot_audio_player is AudioStreamPlayer3D
			and (puppet._shot_audio_player as AudioStreamPlayer3D).max_distance <= 100.0,
		"shot-received grunt stays short-range")

	var local_pc = PlayerScript.new()
	root.add_child(local_pc)
	local_pc._play_shot_received_sound()
	local_pc._play_fall_damage_sound()
	local_pc._play_unwell_sound()
	for pl in [local_pc._shot_audio_player, local_pc._fall_audio_player, local_pc._unwell_audio_player]:
		check(pl != null and not pl is AudioStreamPlayer3D,
			"local damage sound '%s' stays 2D" % (str(pl.name) if pl != null else "null"))
	check(local_pc._shot_audio_player != null and local_pc._shot_audio_player.stream != null,
		"recibirdisparo.mp3 loads through _play_shot_received_sound")
	check(local_pc._fall_audio_player != null and local_pc._fall_audio_player.stream != null,
		"saltardano.mp3 loads through _play_fall_damage_sound")
	check(local_pc._unwell_audio_player != null and local_pc._unwell_audio_player.stream != null,
		"malo.mp3 loads through _play_unwell_sound")
	local_pc.free()

	# --- El mordisco usa dentellada seca (<0.8s, sin "bong" ni puñetazo) ---
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var WcScript := preload("res://scripts/WildlifeController.gd")
	var wolf = WcScript.new()
	wolf.animal_type = "wolf"
	scene.add_child(wolf)
	wolf._play_wolf_sound("bite")
	var b_stream: AudioStream = (wolf._wolf_audio_player as AudioStreamPlayer3D).stream if wolf._wolf_audio_player is AudioStreamPlayer3D else null
	check(wolf._wolf_audio_player is AudioStreamPlayer3D
			and b_stream is AudioStreamWAV
			and b_stream.get_length() > 0.35 and b_stream.get_length() < 0.85
			and (wolf._wolf_audio_player as AudioStreamPlayer3D).playing,
		"la mordida reproduce dentellada WAV corta sin bong (len=%.2fs)" % (b_stream.get_length() if b_stream != null else -1.0))
	wolf._play_wolf_sound("growl")
	check(wolf._wolf_audio_player is AudioStreamPlayer3D
			and (wolf._wolf_audio_player as AudioStreamPlayer3D).stream != null
			and (wolf._wolf_audio_player as AudioStreamPlayer3D).playing,
		"los gruñidos del lobo siguen sonando")
	# Mordisco recibido en Main._net_apply_damage NO dispara punch_impact.wav
	var pc_bite = PlayerScript.new()
	root.add_child(pc_bite)
	pc_bite._play_hit_reaction(false, true)
	check(pc_bite._impact_audio_player == null or not pc_bite._impact_audio_player.playing,
		"mordedura en víctima no reproduce sonido de puñetazo")
	# Flechas fuera de la cabeza nunca bajan de 1 HP; en la cabeza sí matan
	pc_bite.stats.health = 25.0
	pc_bite.apply_damage(55.0, "arco")
	check(is_equal_approx(pc_bite.stats.health, 1.0) and not pc_bite.is_dead,
		"flecha fuera de la cabeza deja 1 HP y no mata (hp=%.1f)" % pc_bite.stats.health)
	pc_bite.apply_damage(55.0, "arco")
	check(is_equal_approx(pc_bite.stats.health, 1.0) and not pc_bite.is_dead,
		"segunda flecha en el cuerpo tampoco mata (hp=%.1f)" % pc_bite.stats.health)
	pc_bite.stats.health = 0.25
	pc_bite.apply_damage(55.0, "arco")
	check(is_equal_approx(pc_bite.stats.health, 0.25) and not pc_bite.is_dead,
		"flecha corporal no cura al jugador con menos de 1 HP")
	pc_bite.apply_damage(120.0, "arco_head")
	check(is_equal_approx(pc_bite.stats.health, 0.0),
		"flecha en la cabeza (arco_head) sí reduce salud a 0 (hp=%.1f)" % pc_bite.stats.health)
	pc_bite.free()

	world.free()
	scene.free()
	if failures == 0:
		print("PASS: damage audio and shot reaction verified")
	quit(1 if failures else 0)

func _find_anim_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var found := _find_anim_player(c)
		if found != null:
			return found
	return null
