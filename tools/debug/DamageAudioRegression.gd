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

	# --- Wildlife bite sound routes to mordedura.mp3 ---
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var WcScript := preload("res://scripts/WildlifeController.gd")
	var wolf = WcScript.new()
	wolf.animal_type = "wolf"
	scene.add_child(wolf)
	wolf._play_wolf_sound("bite")
	check(wolf._wolf_audio_player is AudioStreamPlayer3D,
		"wolf bite sound player is positional")
	check(wolf._wolf_audio_player != null and wolf._wolf_audio_player.stream != null,
		"mordedura.mp3 loads through _play_wolf_sound('bite')")

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
