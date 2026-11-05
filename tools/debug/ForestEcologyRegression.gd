extends SceneTree
const WorldTest = preload("res://tools/debug/NaturalGroundCoverRegression.gd")
var errors := 0
func check(ok: bool,label: String) -> void:
	if not ok: errors += 1
	print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := WorldTest.TestWorld.new()
	root.add_child(world)
	world.river_segments_data = [{"center":Vector3.ZERO,"size":Vector2(20,10),"yaw":0.0}]
	var image: Image = world._make_water_channel_mask().get_image()
	var pixel := 1000.0/4096.0
	var center := image.get_pixel(2048,2048)
	var near_bank := image.get_pixel(2048,int(2048+7.0/pixel))
	var far_bank := image.get_pixel(2048,int(2048+9.0/pixel))
	var dry := image.get_pixel(2048,int(2048+12.0/pixel))
	check(center.r>.9 and near_bank.r<.1,"Water cutout remains separate from wet soil")
	check(near_bank.g>far_bank.g and far_bank.g>dry.g and dry.g==0.0,"Bank dampness decreases gradually")
	preload("res://scripts/ForestFloorCover.gd").apply(world,[Vector3(100,0,100)])
	var mat := preload("res://scripts/MaterialFactory.gd").make_forest_ground_material()
	var mask: Image = mat.get_shader_parameter("canopy_mask").get_image()
	var tree_pixel := Vector2i(Vector2(600,600)/Vector2(1000,1400)*Vector2(512,704))
	check(mask.get_pixelv(tree_pixel).r>.7 and mask.get_pixel(0,0).r==0.0,"Litter follows real tree positions")
	var cycle := preload("res://scripts/DayNightCycle.gd").new()
	cycle.sun = DirectionalLight3D.new()
	cycle.world_environment = WorldEnvironment.new()
	cycle.world_environment.environment = Environment.new()
	cycle.time_of_day = 12.0
	cycle._update_lighting()
	check(cycle.world_environment.environment.fog_density>0.0 and cycle.world_environment.environment.fog_density<.001,"Clear-weather aerial perspective stays subtle")
	cycle.weather_fog_density = .008
	cycle._update_lighting()
	check(is_equal_approx(cycle.world_environment.environment.fog_density,.008),"Weather fog takes precedence")
	cycle.sun.free()
	cycle.world_environment.free()
	cycle.free()
	world.queue_free()
	await process_frame
	print("FOREST_ECOLOGY errors=",errors)
	quit(0 if errors==0 else 1)
