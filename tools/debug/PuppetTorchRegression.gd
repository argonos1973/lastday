extends SceneTree

const PlayerScript = preload("res://scripts/PlayerController.gd")

class FakeWorld extends Node3D:
	# The puppet's _ready runs the local-player path which touches main.hud.
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
	var puppet = PlayerScript.new()
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
	world.free()
	if failures == 0:
		print("PASS: remote players show lit torch (model + light + flames) and flashlight")
	quit(1 if failures else 0)
