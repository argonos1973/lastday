extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
func _initialize(): call_deferred("run")
func run():
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var actors: Array[Actor] = []
	for i in range(16):
		var actor := Actor.new()
		world.add_child(actor)
		actors.append(actor)
	actors[0].prepare_combat_effects()
	var pool = world.get_node("CombatBloodEffects")
	var ids: Array = []
	for node in pool.get_children(): ids.append(node.get_instance_id())
	for wave in range(10):
		for actor in actors: actor._spawn_blood_splatter(Vector3(0,1,0))
		# Simulate the end of particle lifetime, without sleeping in a regression.
		for slot in pool.slots: slot.available_at = 0
	var errors := 0
	var after: Array = []
	for node in pool.get_children(): after.append(node.get_instance_id())
	if ids != after or after.size() != 16: errors += 1
	# All emitters share the same pool; full slots drop cosmetic bursts only.
	for slot in pool.slots: slot.available_at = Time.get_ticks_msec()+10000
	if pool.burst(Vector3.ZERO,1): errors += 1
	world.queue_free()
	await process_frame
	var next_world := Node3D.new()
	root.add_child(next_world)
	current_scene = next_world
	var next_actor := Actor.new()
	next_world.add_child(next_actor)
	next_actor._spawn_blood_splatter()
	if next_world.get_node_or_null("CombatBloodEffects") == null: errors += 1
	next_world.queue_free()
	await process_frame
	print("COMBAT_EFFECTS errors=",errors," reused_particle_nodes=",after.size())
	quit(0 if errors==0 else 1)
