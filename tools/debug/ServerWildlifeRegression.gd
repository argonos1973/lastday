extends SceneTree

const NetScript = preload("res://scripts/NetworkManager.gd")
const MainScript = preload("res://scripts/Main.gd")

class FakeWolfPuppet extends Node3D:
	var pain := 0
	var blood := 0
	var sounds: Array = []
	func _play_pain_sound() -> void:
		pain += 1
	func _spawn_blood_splatter() -> void:
		blood += 1
	func _play_wolf_sound(t: String) -> void:
		sounds.append(t)

class FakeBirdPuppet extends Node3D:
	var feedback := 0
	func _spawn_hit_feedback() -> void:
		feedback += 1

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# --- sync_animals: gen-tagged chunks merge and prune stale animals ---
	var net = NetScript.new()
	root.add_child(net)
	var chunk1 := {"wolf_0": {"t": "wolf"}, "deer_0": {"t": "deer"}, "_gen": 1, "_total": 3}
	var chunk2 := {"fox_0": {"t": "fox"}, "_gen": 1, "_total": 3}
	net.sync_animals(chunk1)
	net.sync_animals(chunk2)
	check(net.animals.size() == 3, "all animals merged after full batch")
	# Next broadcast drops fox_0 -> it must be pruned once the batch completes.
	net.sync_animals({"wolf_0": {"t": "wolf"}, "_gen": 2, "_total": 2})
	net.sync_animals({"deer_0": {"t": "deer"}, "_gen": 2, "_total": 2})
	check(net.animals.size() == 2 and not net.animals.has("fox_0"), "removed animals are pruned client-side")
	# Incomplete batch (lost packet) must not prune.
	net.sync_animals({"wolf_0": {"t": "wolf"}, "_gen": 3, "_total": 2})
	check(net.animals.size() == 2, "incomplete batch keeps previous state")
	net.free()

	# --- _net_animal_hit: remote hits show blood + pain on puppets ---
	# Main is NOT added to the tree: its _ready would generate the whole world.
	# get_node_or_null still resolves children of an off-tree node.
	var scene = MainScript.new()
	var wolf := FakeWolfPuppet.new()
	wolf.name = "Puppet_Wildlife_wolf_0"
	scene.add_child(wolf)
	var bird := FakeBirdPuppet.new()
	bird.name = "Puppet_Wildlife_bird_0"
	scene.add_child(bird)
	scene._net_animal_hit("Wildlife_wolf_0")
	check(wolf.pain == 1 and wolf.blood == 1, "remote wolf hit shows blood + groan")
	scene._net_animal_hit("Wildlife_bird_0")
	check(bird.feedback == 1, "remote bird hit shows blood + squawk")
	# --- _net_animal_sound: server relays wolf sounds to puppets ---
	scene._net_animal_sound("Wildlife_wolf_0", "howl")
	check(wolf.sounds == ["howl"], "remote wolf howl reaches the puppet")
	scene.free()
	if failures == 0:
		print("PASS: animal sync prunes stale entries, remote hits play blood+groan, wolf sounds relayed")
	quit(1 if failures else 0)
