extends SceneTree
const Banks = preload("res://scripts/RiverbankDetails.gd")

class World extends Node3D:
	var blocked := false
	func get_river_depth_at(_pos: Vector3) -> float:
		return 1.0 if blocked else 0.0
	func _can_place_ground_vegetation(_pos: Vector3, _margin: float) -> bool:
		return true
	func _get_ground_height(_pos: Vector3) -> float:
		return 0.0

var errors := 0
func check(ok: bool, msg: String) -> void:
	if not ok:
		errors += 1
		push_error(msg)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	for yaw in [0.0, 48.0, 180.0]:
		var center := Vector3(150,0,-130)
		var bank := Banks.create(world, center, Vector2(30,8), yaw)
		var batches := Banks.placements(world, center, Vector2(30,8), yaw)
		var across := Vector3(sin(deg_to_rad(yaw)),0,cos(deg_to_rad(yaw)))
		var sides := [0,0]
		for node in bank.get_children():
			var mm: MultiMesh = node.multimesh
			check(mm.mesh.get_aabb().size.x < 6.5, "Imported module uses metre scale")
		for batch in batches:
			for t: Transform3D in batch:
				var side := (t.origin-center).dot(across)
				sides[0 if side < 0 else 1] += 1
				check(t.basis.z.dot(across)*side > 0, "Grass side faces land on both banks")
		check(sides[0] > 0 and sides[1] > 0, "Both river banks receive modules")
		bank.free()
	var lake := Banks.create(world, Vector3.ZERO, Vector2(150,90), 0)
	var count := 0
	for batch in Banks.placements(world, Vector3.ZERO, Vector2(150,90), 0):
		for t: Transform3D in batch:
			check(t.origin.dot(t.basis.z) > 0, "Lake grass points out of water")
			count += 1
	check(count > 40 and count < 90, "Lake coverage is bounded and surrounds the lake")
	world.blocked = true
	var joint := Banks.create(world, Vector3.ZERO, Vector2(30,8), 0)
	check(joint.get_child_count() == 0, "Overlapping water at a junction suppresses bank props")
	world.free()
	if errors == 0:
		print("PASS: scale, both banks, rotated segments, lake coverage, open river junctions")
	quit(1 if errors else 0)
