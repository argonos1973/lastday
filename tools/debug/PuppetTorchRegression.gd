extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _play_consumption_audio(_drinking: bool, _duration: float, _serial: int) -> void:
		pass

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
	var puppet = TestPlayer.new()
	puppet.is_puppet = true
	world.add_child(puppet)
	puppet.setup_as_puppet()
	# The puppet must own a torch light before any sync packet arrives.
	check(puppet.torch_light != null, "puppet has a torch light")
	if failures > 0:
		quit(1)
		return
	# Remote player equips a torch -> the torch model appears in its hand socket.
	puppet.puppet_apply_visuals("", "Antorcha", "")
	var torch_node = puppet._torch_hand_root.get_node_or_null("HeldTorch") if puppet._torch_hand_root != null else null
	check(torch_node != null, "remote torch model built in torch hand socket")
	# Remote lights the torch -> light on, flame visuals exist, light follows the tip.
	puppet.puppet_set_torch(true)
	check(puppet.torch_light.visible, "puppet_set_torch(true) lights the remote torch")
	check(puppet.torch_light.get_node_or_null("FireVisuals") != null, "lit remote torch shows flame visuals")
	var tip = torch_node.get_node_or_null("TorchFlameTip") if torch_node != null else null
	check(tip != null and puppet.torch_light.get_parent() == tip, "remote torch light attached to flame tip")
	# Remote switches to a knife -> torch visual and light are gone (queue_free
	# is deferred, so wait one frame).
	puppet.puppet_apply_visuals("", "Cuchillo", "")
	await process_frame
	check(not puppet.torch_light.visible, "switching items turns the remote torch light off")
	check(puppet._torch_hand_root.get_node_or_null("HeldTorch") == null, "torch model removed from hand socket")
	# Remote turns on the flashlight -> a spotlight appears on the puppet.
	puppet.puppet_set_flashlight(true)
	check(puppet.flashlight != null and puppet.flashlight.visible, "puppet flashlight spot light works")
	puppet.puppet_set_flashlight(false)
	check(not puppet.flashlight.visible, "puppet flashlight turns off")
	puppet.puppet_apply_visuals("Casco militar,Linterna frontal", "", "")
	puppet.puppet_set_flashlight(true)
	var housing := puppet._headlamp_housing as Node3D
	check(is_instance_valid(housing) and puppet._headlamp_spill_light.visible and puppet.flashlight.global_position.distance_to(housing.global_position) < 0.15, "replicated beam originates at the helmet")
	puppet._toggle_flashlight()
	check(not puppet.flashlight.visible and not puppet._headlamp_glow.visible, "L switches off beam and lens together")
	puppet.puppet_apply_visuals("Casco militar", "", "")
	check(not puppet.has_headlamp_equipped() and puppet._equipped_slots.has("head"), "removing headlamp preserves helmet")
	puppet.puppet_apply_visuals("", "Botella de agua", "")
	check(puppet._generic_hand_grip, "remote bottle uses the local palm grip")
	puppet._sync_puppet_action_audio("drink/DrinkExternal")
	check(puppet._drink_hand_root != null and puppet._drink_hand_root.get_child_count() == 1, "drinking builds one left-hand bottle")
	check(not puppet.third_person_hand_item_root.visible, "drinking hides the carry bottle")
	var bottle = puppet._drink_hand_root.get_child(0)
	puppet._sync_puppet_action_audio("drink/DrinkExternal")
	check(puppet._drink_hand_root.get_child(0) == bottle, "repeated snapshots reuse the bottle")
	puppet._sync_puppet_action_audio("idle")
	check(puppet._drink_hand_root.get_child_count() == 0 and puppet.third_person_hand_item_root.visible, "cancelling drink restores carry")
	puppet.puppet_apply_visuals("", "", "")
	puppet._sync_puppet_action_audio("drink")
	check(puppet._drink_hand_root.get_child_count() == 0, "drinking from the world does not invent a bottle")
	puppet.puppet_apply_visuals("", "Naranja", "")
	var fruit = puppet.third_person_hand_item_root.get_node_or_null("PalmGripVisual")
	puppet._sync_puppet_action_audio("eat")
	check(fruit != null and fruit == puppet.third_person_hand_item_root.get_node_or_null("PalmGripVisual") and puppet.third_person_hand_item_root.visible and puppet._drink_hand_root.get_child_count() == 0, "the eating hand raises the original fruit, not a left-hand duplicate")
	puppet._sync_puppet_action_audio("idle")
	check(puppet._drink_hand_root.get_child_count() == 0 and puppet.third_person_hand_item_root.visible and puppet._generic_hand_grip, "eating ends with the original carry grip")
	puppet.puppet_apply_visuals("", "Botella de agua", "")
	puppet._sync_puppet_action_audio("drink")
	puppet.is_dead = true
	puppet._sync_puppet_action_audio("dead")
	check(puppet._drink_hand_root.get_child_count() == 0, "death clears the drink prop")
	world.free()
	if failures == 0:
		print("PASS: remote torch, flashlight and consumption props")
	quit(1 if failures else 0)
