extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
class World extends "res://scripts/Main.gd":
	func _ready(): set_process(false);set_physics_process(false)
	func _exit_tree(): pass
class Avatar extends Node3D:
	var third_person_model: Node3D
	var third_person_ground_offset := 0.0
	var setups := 0
	func setup_as_puppet(): setups+=1
func _initialize():call_deferred("run")
func run():
	var world:=World.new()
	root.add_child(world)
	current_scene=world
	var actor:=Actor.new()
	world.add_child(actor)
	var pool=actor._prepare_impact_effects()
	var ids:Array=[]
	for n in pool.get_children(): ids.append(n.get_instance_id())
	var errors:=0
	pool.burst("dust",Vector3(0,1,0),Vector3.UP,Color.RED)
	var first_color:Color=pool.groups.dust[0].pair[0].process_material.color
	pool.burst("dust",Vector3(2,1,0),Vector3.RIGHT,Color.BLUE)
	if pool.groups.dust[0].pair[0].process_material.color!=first_color:errors+=1
	if pool.groups.dust[0].pair[0].process_material==pool.groups.dust[1].pair[0].process_material:errors+=1
	for wave in range(20):
		for kind in pool.groups:
			for slot in pool.groups[kind]:slot.available_at=0
			for i in range(16):pool.burst(kind,Vector3.UP,Vector3.UP,Color.WHITE)
	var after:Array=[]
	for n in pool.get_children():after.append(n.get_instance_id())
	if ids!=after or ids.size()!=32:errors+=1
	world.player=actor
	actor.third_person_model=Node3D.new()
	actor.add_child(actor.third_person_model)
	var avatars:Array=[]
	for i in range(5):
		var avatar:=Avatar.new()
		world.add_child(avatar)
		avatars.append(avatar)
		world._pending_puppets.append(avatar)
	await process_frame
	for i in range(5):
		world._process_pending_puppets()
		world._process_pending_puppets()
		var total:=0
		for avatar in avatars:total+=avatar.setups
		if total!=i+1:
			errors+=1
			print("SETUP_FRAME i=",i," total=",total," frame=",Engine.get_process_frames())
		await process_frame
	if not world._pending_puppets.is_empty():errors+=1
	world.queue_free()
	for i in range(4):await process_frame
	print("CLIENT_EFFECTS errors=",errors," reused_emitters=",after.size()," avatars=",avatars.size())
	quit(0 if errors==0 else 1)
