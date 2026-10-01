extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")

# Cross Punch melee regression: the converted GLB loads into the character
# animation player, bare fists pick "punch/PunchExternal" while weapons keep
# the swing clip, each valid click lands one damage event on a facing target,
# and the cooldown blocks immediate repeats.

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass
	func _update_crosshair(_a) -> void:
		pass
	func _update_crosshair_spread(_d: float) -> void:
		pass

class TestScene extends Node:
	var hud = null
	var remote_players := {}

class PunchTarget extends Node3D:
	var damage_calls := 0
	var total_damage := 0.0
	func take_damage(amount: float, _from_knife: bool = false, _weapon: String = "melee") -> void:
		damage_calls += 1
		total_damage += amount

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	print("=== PunchRegression ===")
	await process_frame
	var scene := TestScene.new()
	root.add_child(scene)
	current_scene = scene

	var player := TestPlayer.new()
	root.add_child(player)
	await process_frame
	player.set_process(false)
	player.set_physics_process(false)
	player.stats.energy = 100.0
	player.notice.connect(func(_t): pass)

	# Mount the real character model so the animation setup and retarget run
	# against the same skeleton used in game.
	var model: Node3D = load("res://assets/animations/inicio.glb").instantiate()
	player.add_child(model)
	player.third_person_model = model
	player._setup_third_person_animation(model)
	await process_frame

	var ap: AnimationPlayer = player.third_person_animation_player
	check(ap != null, "third_person_animation_player exists")
	check(not player.third_person_punch_animation.is_empty(), "punch animation resolved (got '')")
	check(player.third_person_punch_animation == "punch/PunchExternal",
		"punch animation name (got '%s')" % player.third_person_punch_animation)
	check(ap.has_animation("punch/PunchExternal"), "player has punch/PunchExternal")
	var punch: Animation = ap.get_animation("punch/PunchExternal")
	check(punch != null and punch.length > 0.5, "punch clip has length (got %.2f)" % (punch.length if punch != null else -1.0))
	check(punch != null and punch.loop_mode == Animation.LOOP_NONE, "punch does not loop")

	# Retargeted: every track must resolve to a bone of the character skeleton.
	var skel := player._find_skeleton(model)
	var unresolved := 0
	for t in punch.get_track_count():
		var p := str(punch.track_get_path(t))
		var colon := p.rfind(":")
		if colon < 0:
			continue
		var bone := p.substr(colon + 1)
		if bone.begins_with("mixamorig") and skel.find_bone(bone) == -1:
			unresolved += 1
	check(unresolved == 0, "all punch tracks resolve on the character skeleton (%d left)" % unresolved)

	# Bare fists -> punch animation.
	var target := PunchTarget.new()
	scene.remote_players = {7: target}
	target.set_meta("peer_id", 7)
	target.position = player.global_position + Vector3(0, 0, -2.0)  # in front
	scene.add_child(target)
	player.held_index = -1
	check(player.get_held_item() == null, "player starts bare-handed")
	player._melee_attack()
	check(player.third_person_action_animation == player.third_person_punch_animation,
		"bare-fist attack plays the punch (got '%s')" % player.third_person_action_animation)
	check(ap.current_animation == "punch/PunchExternal",
		"animation player is playing the punch (got '%s')" % ap.current_animation)
	check(target.damage_calls == 1, "facing target takes one damage event (got %d)" % target.damage_calls)
	check(absf(target.total_damage - 10.0) < 0.01, "bare-fist punch deals 10 damage (got %.1f)" % target.total_damage)

	# Cooldown: a second immediate click must not re-hit.
	player._melee_attack()
	check(target.damage_calls == 1, "cooldown blocks an immediate second punch (got %d)" % target.damage_calls)

	# After the cooldown each punch lands again.
	player._attack_cooldown = 0.0
	player._melee_attack()
	check(target.damage_calls == 2, "each valid punch deals damage (got %d)" % target.damage_calls)
	check(absf(target.total_damage - 20.0) < 0.01, "two punches deal 20 damage (got %.1f)" % target.total_damage)

	# Behind the target => no hit (facing check).
	player._attack_cooldown = 0.0
	target.position = player.global_position + Vector3(0, 0, 2.0)
	player._melee_attack()
	check(target.damage_calls == 2, "target behind the player is not hit")

	# With a knife the swing animation is preserved (not the punch).
	target.position = player.global_position + Vector3(0, 0, -2.0)
	var knife: Item = ItemScript.create("Cuchillo", "weapon", 0.5, 1, 0.0)
	player.inventory.items.append(knife)
	player._held_item_reference = knife
	check(player.get_held_item() == knife, "knife is held")
	player._attack_cooldown = 0.0
	player._melee_attack()
	check(player.third_person_action_animation == player.third_person_attack_animation,
		"knife keeps the swing animation (got '%s')" % player.third_person_action_animation)
	check(target.damage_calls == 3, "knife hit still damages the facing target")

	if failures == 0:
		print("PASS: cross punch loads, retargets, plays on bare-fist clicks and each punch deals damage")
	quit(1 if failures else 0)
