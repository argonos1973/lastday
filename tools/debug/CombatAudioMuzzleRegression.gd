extends SceneTree
const Player = preload("res://scripts/PlayerController.gd")
const Flash = preload("res://scripts/CombatMuzzleFlash.gd")
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
	for path in [Player.M4_SHOOT_SOUND,"res://assets/audio/disparo.wav","res://assets/audio/recibirdisparo.mp3"]:
		var start := Time.get_ticks_usec()
		var stream := Player._load_audio_stream(path)
		var cold := Time.get_ticks_usec()-start
		start = Time.get_ticks_usec()
		var same := Player._load_audio_stream(path)
		print("AUDIO_CACHE ",path," first_us=",cold," cached_us=",Time.get_ticks_usec()-start)
		check(stream != null and same == stream,"shared audio stream cache")
	var flashes := []
	for i in 16:
		var flash := Flash.new()
		world.add_child(flash)
		flashes.append(flash)
		flash.warm_up()
		check(flash.light.light_energy == 0 and flash.particles.amount_ratio == 0,"warmup is invisible")
	var nodes := root.get_child_count()+world.get_child_count()
	var ids := []
	for flash in flashes: ids.append(flash.particles.get_instance_id())
	for wave in 100:
		for flash in flashes:
			flash.burst(Vector3.ZERO,Vector3.FORWARD)
			flash._process(.05)
			flash.burst(Vector3.ONE,Vector3.RIGHT)
			flash._process(.1)
			check(flash.light.light_energy > 0,"new round extends light lifetime")
	for i in flashes.size():
		var flash = flashes[i]
		check(flash.particles.get_instance_id() == ids[i] and flash.get_child_count() == 2,"stable light and particles across bursts")
		flash._process(.1)
		check(flash.light.light_energy == 0 and not flash.is_processing(),"idle flash stops CPU updates")
	check(nodes == root.get_child_count()+world.get_child_count(),"no per-shot nodes accumulate")
	var muzzle := Node3D.new()
	world.add_child(muzzle)
	flashes[0].burst(Vector3.ZERO,Vector3.FORWARD,muzzle)
	muzzle.position = Vector3(3,2,1)
	flashes[0]._process(.01)
	check(flashes[0].position == muzzle.position,"flash follows moving barrel")
	muzzle.free()
	flashes[0]._process(.2)
	world.free()
	print("COMBAT_AUDIO_MUZZLE errors=",errors," flashes=16 shots=3200")
	quit(errors)
