extends SceneTree
const TestWorld = preload("res://tools/debug/NaturalGroundCoverRegression.gd").TestWorld
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	var tree := Node3D.new()
	tree.name="FruitTree_test"
	tree.position=Vector3(150,0,150)
	world.add_child(tree)
	var chopped := Node3D.new()
	chopped.name="ChoppableTree_test"
	chopped.position=Vector3(152,0,150)
	world.add_child(chopped)
	world._register_tree_in_grid({"pos":Vector3(154,0,150),"id":1})
	var errors := 0
	var positions: Array = world._forest_floor_positions([Vector3(154,0,150)])
	if positions.size()!=3: errors+=1
	var dense: Array=[]
	for i in range(40): dense.append(Vector3(150+float(i)*.01,0,150))
	var rng_state := world._world_rng.state
	await preload("res://scripts/ForestLeafLitter.gd").build(world,dense)
	var count := 0
	for node in world.get_children():
		if not str(node.name).begins_with("ForestLeafLitter_"): continue
		count+=node.multimesh.instance_count
	if count!=2560 or world._world_rng.state!=rng_state: errors+=1
	print("LEAF_COVERAGE sources=",positions.size()," clusters=",count," leaves=",count*7," errors=",errors)
	world.queue_free()
	await process_frame
	quit(0 if errors==0 else 1)
