extends SceneTree
class World extends Node3D:
	var hud = null
class Shooter extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _spawn_blood_splatter(_p := Vector3.ZERO, _s := 1.0): pass
	func _hit_marker(_lethal): pass
class Animal extends "res://scripts/WildlifeController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _spawn_blood_splatter(): pass
	func _play_pain_sound(): pass
	func _play_wolf_sound(_s: String): pass
	func _note_attack(_a: Node): pass
	func _lie_corpse_flat(): pass
	func _release_owner_record(): pass
class Victim extends Node3D:
	var is_dead := false
	var amounts: Array[float] = []
	func take_damage(amount: float, _knife := false, weapon := "melee"):
		assert(weapon == "rifle")
		amounts.append(amount)
var errors := 0
func check(ok: bool, message: String):
	if not ok: errors+=1;push_error(message)
func _initialize(): call_deferred("run")
func run():
	var world:=World.new();root.add_child(world);current_scene=world
	var shooter:=Shooter.new();world.add_child(shooter)
	var victim:=Victim.new();victim.add_to_group("remote_player");world.add_child(victim)
	var body:=Area3D.new();body.name="BodyHitbox";victim.add_child(body)
	var head:=Area3D.new();head.name="HeadHitbox";victim.add_child(head)
	for i in 3: shooter._apply_rifle_damage(body,Vector3.ZERO,10,Vector3.UP,true)
	check(victim.amounts.size()==3,"Each bullet reports one PvP hit")
	check(absf(victim.amounts.reduce(func(a,b):return a+b,0.0)-84.0*exp(-.002))<.01,"Three M4 body hits accumulate without dropping damage")
	shooter._apply_rifle_damage(head,Vector3.ZERO,10,Vector3.UP,true)
	check(absf(victim.amounts.back()-60*exp(-.002))<.01,"M4 head hit uses its own profile")
	shooter._apply_rifle_damage(body,Vector3.ZERO,500,Vector3.UP,true)
	check(victim.amounts.back()<victim.amounts[0],"Distant PvP impacts lose damage")
	for kind in {"deer":80.0,"fox":50.0,"wolf":240.0,"bear":650.0}:
		var animal:=Animal.new();animal.animal_type=kind;animal.health={"deer":80.0,"fox":50.0,"wolf":240.0,"bear":650.0}[kind];animal.max_health=animal.health
		animal.add_to_group("wildlife");world.add_child(animal)
		var initial:=animal.health
		for i in 3: shooter._apply_rifle_damage(animal,Vector3.ZERO,10,Vector3.UP,true)
		check(absf(animal.health-maxf(0,initial-285*exp(-.002)))<.01,"M4 burst damage accumulates correctly on "+kind)
		check(animal._is_dead==(animal.health<=0),"Only lethal damage kills "+kind)
		animal.free()
	var animal:=Animal.new();world.add_child(animal);animal.animal_type="deer"
	animal.flee_from_gunshot(Vector3(2,0,0),120)
	animal._current_path=[Vector3(10,0,0)]
	animal.flee_from_gunshot(Vector3(2.1,0,0),120)
	check(animal._current_path.size()==1,"Burst rounds preserve the animal escape path")
	animal.flee_from_gunshot(Vector3(-20,0,0),120)
	check(animal._current_path.is_empty(),"A different nearby threat updates the escape route")
	animal.is_puppet=true;animal.health=80
	animal.take_damage(95,false,shooter)
	check(animal.health==80 and not animal._is_dead,"Client must wait for server death confirmation")
	shooter._recoil_pitch=0
	for i in 3: shooter._apply_rifle_recoil(true)
	check(absf(shooter._recoil_pitch+deg_to_rad(3*shooter.M4_RECOIL))<.001,"Every round adds recoil")
	world.free();print("M4_DAMAGE_ERRORS=",errors);quit(1 if errors else 0)
