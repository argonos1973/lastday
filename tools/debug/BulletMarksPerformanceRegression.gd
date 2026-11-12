extends SceneTree
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _physics_process(_d): pass
	func _process(_d): pass
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var actors := []
	var mesh_ids := {}
	var core_ids := {}
	for n in 2:
		var actor := Actor.new()
		world.add_child(actor)
		actors.append(actor)
		for i in 180:
			actor._spawn_bullet_hole_decal(Vector3(i,n,0),Vector3.UP if i%2==0 else Vector3.RIGHT)
		check(actor._bullet_holes.size() == actor.MAX_BULLET_HOLES,"marks remain bounded per actor")
		for hole in actor._bullet_holes:
			mesh_ids[hole.mesh.get_instance_id()] = true
			core_ids[hole.get_node("BulletHoleCore").mesh.get_instance_id()] = true
	check(mesh_ids.size() == 2 and core_ids.size() == 2,"both actors share surface and core geometry")
	var moving := Node3D.new()
	world.add_child(moving)
	actors[0]._spawn_bullet_hole_decal(Vector3(1,1,1),Vector3.RIGHT,moving)
	var mark = actors[0]._bullet_holes.back()
	var before: Vector3 = mark.global_position
	moving.position = Vector3(4,0,0)
	check(mark.global_position.is_equal_approx(before+Vector3(4,0,0)),"mark follows a movable collider")
	world.free()
	print("BULLET_MARKS errors=",errors)
	quit(errors)
