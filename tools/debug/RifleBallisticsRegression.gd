extends SceneTree
const Bullet = preload("res://scripts/RifleProjectile.gd")
class World extends Node3D:
	var distant_wall := false
	var water := false
	var splashes := 0
	func get_river_surface_y_at(_p): return 9.0
	func get_river_depth_at(_p): return 2.0 if water else 0.0
	func _play_water_drop_effect(_p): splashes += 1
	func raycast_distant_props(a: Vector3, b: Vector3) -> Dictionary:
		if distant_wall and a.z > -15.0 and b.z <= -15.0:
			return {"position":a.lerp(b,(-15.0-a.z)/(b.z-a.z)),"normal":Vector3.BACK,"collider":self}
		return {}
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _physics_process(_d): pass
	func _process(_d): pass
var failures := 0
func check(ok: bool, label: String):
	if not ok:
		failures+=1
		push_error(label)
func bullet(world: Node3D, speed: float = 750.0):
	var b=Bullet.new()
	b.velocity=Vector3(0,0,-speed)
	b.max_distance=1000
	world.add_child(b)
	b.global_position=Vector3(0,10,0)
	b.set_physics_process(false)
	return b
func _initialize(): call_deferred("run")
func run():
	var world:=World.new();root.add_child(world);current_scene=world
	var a=bullet(world);var b=bullet(world)
	a.wind_velocity=Vector3(10,0,0);b.wind_velocity=a.wind_velocity
	for i in 60:a._physics_process(1.0/60.0)
	for i in 30:b._physics_process(1.0/30.0)
	check(a.global_position.distance_to(b.global_position)<.01,"Trajectory must not depend on frame rate")
	check(a.global_position.y<5.4 and a.global_position.y>5.1,"Gravity must cause drop during flight")
	check(a.global_position.x>.4,"Crosswind must cause drift")
	check(a.velocity.length()<750,"Drag must reduce speed")
	a.free();b.free()
	var trigger:=Area3D.new();trigger.name="InteractionTrigger";trigger.collision_layer=1
	var shape:=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(8,8,1)
	trigger.add_child(shape);world.add_child(trigger);trigger.position=Vector3(0,10,-5)
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var collision:=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(10,10,.1)
	wall.add_child(collision);world.add_child(wall);wall.position=Vector3(0,10,-20)
	await physics_frame;await physics_frame
	var impacts: Array=[]
	var shot=bullet(world,100)
	shot.impact.connect(func(c,p,d,n):impacts.append([c,p,d,n]))
	shot._physics_process(.05)
	check(impacts.is_empty(),"No instantaneous impact before the bullet arrives")
	shot._physics_process(.2)
	check(impacts.size()==1 and impacts[0][0]==wall,"Swept bullet passes triggers and stops at thin cover")
	world.distant_wall=true
	var distant=bullet(world)
	var distant_hits:Array=[]
	distant.impact.connect(func(c,p,d,n):distant_hits.append([c,p,d,n]))
	distant._physics_process(.04)
	check(distant_hits.size()==1 and distant_hits[0][0]==world,"Distant props stop the bullet before a farther physics collider")
	var limited=bullet(world);limited.max_distance=3;limited._physics_process(.05)
	check(limited.is_queued_for_deletion() and limited.traveled<=3.001,"Finite range cleans up projectiles")
	world.water=true;world.distant_wall=false
	var wet=bullet(world);wet.velocity=Vector3(0,-100,0);wet._physics_process(.02)
	check(wet.is_queued_for_deletion() and world.splashes==1,"Water stops the bullet and creates one splash")
	var actor:=Actor.new();actor.name="Player";world.add_child(actor)
	actor.camera=Camera3D.new();actor.add_child(actor.camera)
	actor._camera_fov=55
	for zoom in 4:
		actor._scope_zoom_index=zoom;actor._update_scope_zoom()
		var actual:=tan(deg_to_rad(55.0)*.5)/tan(deg_to_rad(actor.camera.fov)*.5)
		check(absf(actual-actor.SCOPE_MAGNIFICATIONS[zoom])<.01,"Scope must match its advertised magnification")
	actor._is_aiming=true;actor._scope_zoom_index=3;actor._update_scope_zoom()
	var scoped_fov:=actor.camera.fov
	actor._sync_camera_lens()
	check(is_equal_approx(actor.camera.fov,scoped_fov),"Frame camera sync must not stomp the scoped FOV")
	check(actor.camera.far>=actor.RIFLE_RANGE,"Scoped far plane must cover the full rifle range")
	actor._is_aiming=false;actor._sync_camera_lens()
	check(is_equal_approx(actor.camera.fov,55.0) and actor.camera.far==500.0,"Unscoping restores base FOV and far plane")
	actor._is_aiming=true;actor._cancel_aim()
	check(is_equal_approx(actor.camera.fov,55.0),"Leaving the scope restores normal FOV")
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		root.size=Vector2i(1280,800)
		var overlay:=preload("res://scripts/ScopeOverlay.gd").new()
		root.add_child(overlay)
		actor._scope_zoom_index=3;actor._update_scope_zoom()
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rifle_scope_preview.png")
		overlay.free()
	await process_frame
	world.free()
	print("RIFLE_BALLISTICS_ERRORS=",failures)
	quit(1 if failures else 0)
