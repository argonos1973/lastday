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
	actor._is_aiming=true
	actor._update_breath_hold(0.0, true)
	actor._update_breath_hold(14.99, false)
	check(actor._breath_hold_active, "Shift steadies aim for the full 15 seconds")
	actor._update_breath_hold(.02, false)
	check(not actor._breath_hold_active and actor._breath_hold_recover > 0, "Breath hold expires after 15 seconds")
	actor._update_breath_hold(4.1, true)
	check(actor._breath_hold_active, "New Shift press after recovery starts another hold")
	actor._update_breath_hold(15.1, true)
	actor._update_breath_hold(5.0, true)
	check(not actor._breath_hold_active, "Keeping Shift held must not automatically repeat the hold")
	actor._update_breath_hold(0.0, false)
	actor._update_breath_hold(0.0, true)
	actor._cancel_aim()
	check(not actor._breath_hold_active, "Leaving aim cancels breath hold")
	actor._spawn_bullet_impact(wall.global_position, Vector3.UP, wall)
	var mark=wall.get_node_or_null("BulletHole")
	check(mark != null, "Horizontal solid surfaces retain a bullet mark")
	if mark != null:
		var before=mark.global_position
		wall.position.x+=1
		check(mark.global_position.distance_to(before+Vector3.RIGHT)<.001, "Impact marks follow their hit object")
	check(world.get_node_or_null("BulletDustMotes") != null, "Solid impacts produce dust")
	# --- Fusil de asalto M4: perfil propio por nombre de item ---
	actor.is_puppet = true
	actor._puppet_held = "Fusil de asalto"
	check(actor._held_is_m4(), "M4 profile resolves from the held item name")
	check(actor._rifle_scope_mags() == [1.35], "M4 uses 1.35x iron sights, not a telescopic scope")
	check(bool(actor.get_rifle_info().get("iron_sights", false)), "M4 rifle_info reports iron_sights=true")
	actor._scope_zoom_index = 3
	actor._update_scope_zoom()
	var m4_fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(55.0) * 0.5) / 1.35))
	check(absf(actor.camera.fov - m4_fov) < 0.01, "M4 wheel cannot exceed its iron-sight FOV")
	var m4_overlay := preload("res://scripts/ScopeOverlay.gd").new()
	world.add_child(m4_overlay)
	check(m4_overlay._iron_sights == true, "ScopeOverlay switches to M4 iron sights instead of telescopic tube")
	m4_overlay.free()
	check(absf(actor._rifle_cooldown_time() - actor.M4_COOLDOWN) < 0.001, "M4 fires semi-auto, not bolt cadence")
	actor._m4_magazine = 12
	actor._m4_reserve_ammo = 40
	check(actor._loaded_rounds() == 12 and actor._reserve_rounds() == 40, "M4 reads its own ammo pools")
	actor._set_loaded_rounds(7)
	actor._set_reserve_rounds(35)
	check(actor._m4_magazine == 7 and actor._m4_reserve_ammo == 35 and actor._rifle_magazine == 0, "M4 pool writes stay in the M4 pool")
	check(actor._rifle_mag_size() == 30 and actor.M4_MAG_SIZE == 30, "M4 magazine holds 30 5.56x45mm NATO cartridges")
	check(actor.M4_AMMO_TYPE == "5,56 × 45 mm NATO", "M4 reports 5,56 × 45 mm NATO caliber")
	check(actor._rifle_model_path_for("Fusil de asalto") == actor.M4_MODEL, "M4 resolves its own model")
	actor._play_shoot_sound(true)
	check(actor._shoot_audio_player != null and actor._shoot_audio_player.stream != null, "M4 trimmed burst sound stream loads")
	if actor._shoot_audio_player != null and actor._shoot_audio_player.stream != null:
		var dur: float = actor._shoot_audio_player.stream.get_length()
		check(dur > 0.8 and dur < 2.2, "M4 sound is trimmed to the active audio segment (%.2f s)" % dur)
	actor._launch_rifle_projectile(Vector3.ZERO, Vector3(0, 0, -1), Vector3.ZERO, [], true, true)
	var m4_bullet: Node3D = null
	for c in world.get_children():
		if c.get("velocity") is Vector3 and absf(c.velocity.length() - 880.0) < 0.5:
			m4_bullet = c
	check(m4_bullet != null, "M4 projectile leaves at its own muzzle velocity")
	if m4_bullet != null:
		m4_bullet.free()
	actor._puppet_held = "Rifle francotirador"
	check(not actor._held_is_m4(), "Sniper keeps the default profile")
	actor.is_puppet = false
	actor._puppet_held = ""
	# Impact marks on ground, walls and trees (including BulletHoleCore so
	# curved trunks and uneven terrain never bury the mark).
	var holes_before := actor._bullet_holes.size()
	var tree_body := StaticBody3D.new()
	tree_body.name = "Tree_TestTrunk"
	world.add_child(tree_body)
	actor._apply_rifle_damage(world, Vector3(0, 0, -10), 10.0, Vector3.UP, true)
	actor._apply_rifle_damage(tree_body, Vector3(1, 1.5, -12), 12.0, Vector3.BACK, true)
	check(actor._bullet_holes.size() >= holes_before + 2, "M4 impacts leave bullet holes on ground and trees")
	var last_hole: Node3D = actor._bullet_holes.back()
	check(last_hole != null and last_hole.get_node_or_null("BulletHoleCore") != null, "Bullet holes include volumetric 3D core")
	tree_body.free()
	if "--preview" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		root.size=Vector2i(1280,800)
		var bg := ColorRect.new()
		bg.color = Color(0.52, 0.63, 0.72, 1.0)
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.add_child(bg)
		var overlay:=preload("res://scripts/ScopeOverlay.gd").new()
		root.add_child(overlay)
		actor._scope_zoom_index=3;actor._update_scope_zoom()
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rifle_scope_preview.png")
		actor.is_puppet = true
		actor._puppet_held = "Fusil de asalto"
		actor._update_scope_zoom()
		overlay._sync_from_player()
		overlay._process(0.15)
		overlay.queue_redraw()
		await create_timer(.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/m4_iron_sight_preview.png")
		actor.is_puppet = false
		actor._puppet_held = ""
		overlay.free()
		bg.free()
	if is_instance_valid(actor._shoot_audio_player):
		actor._shoot_audio_player.stop()
		actor._shoot_audio_player.stream = null
	await create_timer(.1).timeout
	world.free()
	print("RIFLE_BALLISTICS_ERRORS=",failures)
	quit(1 if failures else 0)
