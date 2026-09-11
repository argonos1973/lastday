extends SceneTree
const Player = preload("res://scripts/PlayerController.gd")

class TestPlayer extends Player:
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := TestPlayer.new()
	root.add_child(player)
	player.third_person_model = Node3D.new()
	player.add_child(player.third_person_model)
	player._torch_hand_root = Node3D.new()
	player.third_person_model.add_child(player._torch_hand_root)
	player.torch_light = OmniLight3D.new()
	player.third_person_model.add_child(player.torch_light)
	var torch := Node3D.new()
	var mesh := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.04
	stick.bottom_radius = 0.05
	stick.height = 1.2
	mesh.mesh = stick
	torch.add_child(mesh)
	player._torch_hand_root.add_child(torch)
	player._attach_torch_light_to_tip(torch)
	var tip := torch.get_node_or_null("TorchFlameTip") as Marker3D
	check(tip != null, "Torch visual creates a flame tip marker")
	check(player.torch_light.get_parent() == tip, "Torch light is parented to the flame tip")
	check(tip.position.y > 0.6, "Flame marker is placed at the upper end of the torch")
	check(player.torch_light.position.is_zero_approx(), "Light and particles share the exact tip position")
	player._detach_torch_light_from_tip()
	check(player.torch_light.get_parent() == player.third_person_model, "Rebuilding the torch preserves the light node")
	player.queue_free()
	await process_frame
	print("TORCH TIP: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
