extends Node3D

const PlayerControllerScript = preload("res://scripts/PlayerController.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const DayNightCycleScript = preload("res://scripts/DayNightCycle.gd")
const RadioSystemScript = preload("res://scripts/RadioSystem.gd")
const SaveSystemScript = preload("res://scripts/SaveSystem.gd")
const NPCControllerScript = preload("res://scripts/NPCController.gd")
const LootContainerScript = preload("res://scripts/LootContainer.gd")
const DoorScript = preload("res://scripts/Door.gd")
const ItemScript = preload("res://scripts/Item.gd")
const AudioSystemScript = preload("res://scripts/AudioSystem.gd")
const WorldActionScript = preload("res://scripts/WorldAction.gd")
const RiverWaterScript = preload("res://scripts/RiverWater.gd")
const FishControllerScript = preload("res://scripts/FishController.gd")
const WildlifeControllerScript = preload("res://scripts/WildlifeController.gd")
const SimpleObjLoaderScript = preload("res://scripts/SimpleObjLoader.gd")

var player
var hud
var day_cycle
var radio
var audio_system
var containers_by_id := {}
var world_actions_by_id := {}
var material_cache := {}
var billboard_texture_cache := {}
var texture_path_cache := {}
var external_scene_cache := {}
var _shared_sphere_mesh: SphereMesh = null
var _shared_visual_sphere_mesh: SphereMesh = null
var _shared_box_mesh: BoxMesh = null
var _shared_cylinder_mesh: CylinderMesh = null
var _shared_trunk_cylinder_mesh: CylinderMesh = null
var _snap_offset_cache := {}
var _shared_foliage_green_mat: StandardMaterial3D = null
var _display_props_stripped := {}
var river_segments_data: Array = []
var wildlife_blockers: Array = []
var _nav_grid: Dictionary = {}
var _nav_grid_size := 76
var _nav_cell_size := 2.0
var _nav_grid_built := false
var game_over := false
var _drink_hold_actor = null
var _drink_hold_timer := 0.0
const _DRINK_HOLD_TIME := 1.5

const GRASS_BATCH_VARIANTS := 10
var grass_batch_meshes: Array = []
var grass_batch_transforms: Array = []
var grass_batch_colors: Array = []
var grass_batch_material: StandardMaterial3D = null
var _tall_grass_meshes: Array = []
var _tall_grass_transforms: Array = []
var _tall_grass_colors: Array = []
var _tall_grass_material: StandardMaterial3D = null

const SAVE_BALANCE_VERSION := 6
const Q_NATURE := "res://assets/external/quaternius_stylized_nature_megakit/glTF/"
const K_SURVIVAL := "res://assets/external/kenney_survival_kit/Models/GLB format/"
const REAL_LIVING_TREE_MODELS := [
	Q_NATURE + "TwistedTree_1.gltf",
	Q_NATURE + "TwistedTree_2.gltf",
	Q_NATURE + "TwistedTree_3.gltf",
	Q_NATURE + "TwistedTree_4.gltf",
	Q_NATURE + "TwistedTree_5.gltf"
]
const REAL_DEAD_TREE_MODELS := [
	Q_NATURE + "DeadTree_1.gltf",
	Q_NATURE + "DeadTree_2.gltf",
	Q_NATURE + "DeadTree_3.gltf",
	Q_NATURE + "DeadTree_4.gltf",
	Q_NATURE + "DeadTree_5.gltf"
]
const TREE_BILLBOARD_TEXTURES := [
	"res://assets/external/tree_billboards/png/lake_pine_01.png",
	"res://assets/external/tree_billboards/png/lake_pine_02.png",
	"res://assets/external/tree_billboards/png/lake_pine_03.png",
	"res://assets/external/tree_billboards/png/lake_pine_04.png",
	"res://assets/external/tree_billboards/png/lake_pine_05.png",
	"res://assets/external/tree_billboards/png/pine_01.png",
	"res://assets/external/tree_billboards/png/pine_02.png",
	"res://assets/external/tree_billboards/png/pine_03.png",
	"res://assets/external/tree_billboards/png/pine_04.png",
	"res://assets/external/tree_billboards/png/pine_05.png",
	"res://assets/external/tree_billboards/png/flare_broadleaf_04.png",
	"res://assets/external/tree_billboards/png/flare_broadleaf_05.png",
	"res://assets/external/tree_billboards/png/flare_broadleaf_06.png"
]
const DEAD_TREE_BILLBOARD_TEXTURES := [
	"res://assets/external/tree_billboards/png/flare_pine_01.png",
	"res://assets/external/tree_billboards/png/flare_pine_02.png",
	"res://assets/external/tree_billboards/png/flare_pine_03.png"
]
const UNDERBRUSH_BILLBOARD_TEXTURES := [
	"res://assets/external/tree_billboards/png/flare_broadleaf_04.png",
	"res://assets/external/tree_billboards/png/flare_broadleaf_05.png",
	"res://assets/external/tree_billboards/png/flare_broadleaf_06.png",
	"res://assets/external/tree_billboards/png/flare_pine_01.png",
	"res://assets/external/tree_billboards/png/flare_pine_02.png",
	"res://assets/external/tree_billboards/png/flare_pine_03.png"
]
const POLY_GRASS_DIFF := "res://assets/external/polyhaven/grass_bermuda_01/textures/grass_bermuda_01_diff_4k.jpg"
const POLY_GRASS_BERMUDA_ALPHA := "res://assets/external/polyhaven/grass_bermuda_01/textures/grass_bermuda_01_alpha_4k.png"
const POLY_GRASS_BERMUDA_BLEND := "res://assets/external/polyhaven/grass_bermuda_01/grass_bermuda_01_4k.blend"
const POLY_GRASS_MEDIUM_DIFF := "res://assets/external/polyhaven/grass_medium_01/textures/grass_medium_01_diff_4k.jpg"
const POLY_GRASS_DRY_DIFF := "res://assets/external/polyhaven/grass_medium_01/textures/grass_medium_01_dry_diff_4k.png"
const POLY_GRASS_CUTOUT := "res://assets/external/polyhaven/grass_medium_01/textures/grass_medium_01_cutout_1024.png"
const POLY_GRASS_MEDIUM_02_DIFF := "res://assets/external/polyhaven/grass_medium_02/textures/grass_medium_02_diff_4k.jpg"
const POLY_GRASS_MEDIUM_02_ALPHA := "res://assets/external/polyhaven/grass_medium_02/textures/grass_medium_02_alpha_4k.png"
const POLY_FERN_DIFF := "res://assets/external/polyhaven/fern_02/textures/fern_02_diff_4k.jpg"
const POLY_FERN_ALPHA := "res://assets/external/polyhaven/fern_02/textures/fern_02_alpha_4k.png"
const POLY_SHRUB_DIFF := "res://assets/external/polyhaven/shrub_02/textures/shrub_02_diff_4k.jpg"
const POLY_SHRUB_ALPHA := "res://assets/external/polyhaven/shrub_02/textures/shrub_02_alpha_4k.png"
const POLY_PERIWINKLE_CUTOUT := "res://assets/external/polyhaven/periwinkle_plant/textures/periwinkle_plant_cutout_1024.png"
const POLY_PINE_BARK_DIFF := "res://assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_bark_diff_4k.png"
const POLY_PINE_TWIG_DIFF := "res://assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_twig_diff_4k.png"
const POLY_PINE_TWIG_ALPHA := "res://assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_twig_alpha_4k.png"
const POLY_FIR_BARK_DIFF := "res://assets/external/polyhaven/fir_tree_01/textures/fir_tree_01_bark_diff_4k.png"
const POLY_FIR_TWIG_DIFF := "res://assets/external/polyhaven/fir_tree_01/textures/fir_tree_01_twig_diff_4k.png"
const POLY_FIR_TWIG_ALPHA := "res://assets/external/polyhaven/fir_tree_01/textures/fir_tree_01_twig_alpha_4k.png"
const POLY_ROCKY_TERRAIN_DIFF := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_diff_4k.jpg"
const POLY_ROCKY_TERRAIN_DISP := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_disp_4k.png"
const POLY_ROCKY_TERRAIN_SPEC := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_spec_4k.png"
const POLY_RIVER_PEBBLES_DIFF := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_diff_4k.jpg"
const POLY_RIVER_PEBBLES_DISP := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_disp_4k.png"
const POLY_RIVER_PEBBLES_NOR := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_nor_gl_4k.exr"
const POLY_RIVER_PEBBLES_ROUGH := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_rough_4k.exr"
const POLY_BOULDER_DIFF := "res://assets/external/polyhaven/namaqualand_boulder_02/textures/namaqualand_boulder_02_diff_4k.jpg"
const POLY_ROCK_07_DIFF := "res://assets/external/polyhaven/rock_07/textures/rock_07_diff_4k.jpg"
const POLY_CABINET_DIFF := "res://assets/external/polyhaven/painted_wooden_cabinet/textures/painted_wooden_cabinet_diff_4k.jpg"
const POLY_EQUIPMENT_DIR := "res://assets/external/polyhaven/"
const POLY_RUBBER_BOOTS_MODEL := POLY_EQUIPMENT_DIR + "rubber_boots/rubber_boots_1k.gltf"
const POLY_GARDEN_GLOVES_MODEL := POLY_EQUIPMENT_DIR + "garden_gloves_01/garden_gloves_01_1k.gltf"
const POLY_FISHERMANS_HAT_MODEL := POLY_EQUIPMENT_DIR + "fishermans_hat/fishermans_hat_1k.gltf"
const POLY_LIFE_JACKET_MODEL := POLY_EQUIPMENT_DIR + "life_jacket/life_jacket_1k.gltf"
const POLY_VINTAGE_SUITCASE_MODEL := POLY_EQUIPMENT_DIR + "vintage_suitcase/vintage_suitcase_1k.gltf"
const ROOT_GLB_DIR := "res://assets/external/realistic/root_glb/"
const TEX_DIR := "res://assets/external/textures/"
const TEX_PLASTER_DIFF := TEX_DIR + "plaster_brick_01/plaster_brick_01_diff_4k.jpg"
const TEX_PLASTER_ROUGH := TEX_DIR + "plaster_brick_01/plaster_brick_01_rough_4k.jpg"
const TEX_PLASTER_NOR := TEX_DIR + "plaster_brick_01/plaster_brick_01_nor_gl_4k.exr"
const TEX_RUST_DIFF := TEX_DIR + "rusty_metal_03/rusty_metal_03_diff_4k.jpg"
const TEX_RUST_ROUGH := TEX_DIR + "rusty_metal_03/rusty_metal_03_rough_4k.exr"
const TEX_RUST_NOR := TEX_DIR + "rusty_metal_03/rusty_metal_03_nor_gl_4k.exr"
const TEX_WOOD_FLOOR_DIFF := TEX_DIR + "wood_floor_deck/wood_floor_deck_diff_4k.jpg"
const TEX_CONCRETE_DIFF := TEX_DIR + "concrete_floor_02/concrete_floor_02_diff_4k.jpg"
const TEX_BRICK_DIFF := TEX_DIR + "red_brick_03/red_brick_03_diff_4k.jpg"
const BACKPACK_ITEM_SCENE := "res://scenes/items/BackpackItem.tscn"
const WATER_BOTTLE_ITEM_SCENE := "res://scenes/items/WaterBottleItem.tscn"
const ROOT_CANNED_FOOD_MODEL := ROOT_GLB_DIR + "canned_food_pack_opened__low_poly_game_asset.glb"
const ROOT_BACKPACK_MODEL := ROOT_GLB_DIR + "low_poly_game_ready_military_tactical_backpack.glb"
const ROOT_KNIFE_MODEL := ROOT_GLB_DIR + "knife.glb"
const ROOT_WEAPON_KNIFE_MODEL := ROOT_GLB_DIR + "call_of_duty_black_ops_cold_war_-_america_knife.glb"
const ROOT_VEST_MODEL := ROOT_GLB_DIR + "vest_armor_holster_lowpoly_gameready_pack.glb"
const ROOT_BARRIER_MODEL := ROOT_GLB_DIR + "concrete_road_barrier.glb"
const ROOT_BENCH_MODEL := ROOT_GLB_DIR + "city_bench.glb"
const ROOT_JUNK_MODEL := ROOT_GLB_DIR + "junk_props.glb"
const ROOT_RUSTY_CAR_MODEL := ROOT_GLB_DIR + "old_rusty_car.glb"
const ROOT_CONTAINER_MODEL := ROOT_GLB_DIR + "shipping_container_anos.glb"
const ROOT_FURNITURE_MODEL := ROOT_GLB_DIR + "tinylivingpack.glb"
const ROOT_AXE_CS2_MODEL := ROOT_GLB_DIR + "tool__axe_weapon_model_cs2.glb"
const ROOT_SOFA_MODEL := ROOT_GLB_DIR + "trashy_backyard_sofa.glb"
const ROOT_FRIDGE_MODEL := ROOT_GLB_DIR + "old_rusty_fridge.glb"
const ROOT_GASSTOVE_MODEL := ROOT_GLB_DIR + "old_russian_gasstove.glb"
const ROOT_POWER_POLE_MODEL := "res://assets/external/power_pole.glb"
const POLY_MODEL_DIR := "res://assets/external/polyhaven/models/"
const POLY_TREE_MODELS := [
	POLY_MODEL_DIR + "tree_small_02/tree_small_02_1k.gltf",
	POLY_MODEL_DIR + "jacaranda_tree/jacaranda_tree_1k.gltf",
	POLY_MODEL_DIR + "pine_tree_01/pine_tree_01_1k.gltf",
	POLY_MODEL_DIR + "fir_tree_01/fir_tree_01_1k.gltf",
	POLY_MODEL_DIR + "island_tree_01/island_tree_01_1k.gltf",
	POLY_MODEL_DIR + "island_tree_02/island_tree_02_1k.gltf",
	POLY_MODEL_DIR + "island_tree_03/island_tree_03_1k.gltf"
]
const POLY_FURNITURE_DIR := "res://assets/external/polyhaven/furniture/"
const POLY_FURNITURE_MODELS := [
	POLY_MODEL_DIR + "Sofa_01/Sofa_01_1k.gltf",
	POLY_MODEL_DIR + "sofa_02/sofa_02_1k.gltf",
	POLY_MODEL_DIR + "painted_wooden_sofa/painted_wooden_sofa_1k.gltf",
	POLY_MODEL_DIR + "painted_wooden_cabinet/painted_wooden_cabinet_1k.gltf",
	POLY_MODEL_DIR + "painted_wooden_cabinet_02/painted_wooden_cabinet_02_1k.gltf",
	POLY_MODEL_DIR + "painted_wooden_chair_02/painted_wooden_chair_02_1k.gltf",
	POLY_MODEL_DIR + "metal_office_desk/metal_office_desk_1k.gltf",
	POLY_MODEL_DIR + "WoodenTable_01/WoodenTable_01_1k.gltf",
	POLY_MODEL_DIR + "wooden_picnic_table/wooden_picnic_table_1k.gltf",
	POLY_FURNITURE_DIR + "Sofa_01.glb",
	POLY_FURNITURE_DIR + "sofa_02.glb",
	POLY_FURNITURE_DIR + "ArmChair_01.glb",
	POLY_FURNITURE_DIR + "CoffeeTable_01.glb",
	POLY_FURNITURE_DIR + "wood_cabinet_worn_long.glb",
	POLY_FURNITURE_DIR + "vintage_cabinet_01.glb",
	POLY_FURNITURE_DIR + "side_table_01.glb"
]
const SKY_HDRI_CANDIDATES := [
	"res://kloofendal_48d_partly_cloudy_4k.exr",
	"res://assets/external/polyhaven/skies/rogland_overcast_1k.hdr",
	"res://assets/external/polyhaven/skies/misty_farm_road_1k.hdr",
	"res://assets/external/polyhaven/skies/quarry_cloudy_1k.hdr",
	"res://assets/external/polyhaven/skies/overcast_soil_1k.hdr",
	"res://assets/external/polyhaven/skies/kiara_9_dusk_1k.hdr",
	"res://assets/external/polyhaven/skies/spruit_dawn_1k.hdr",
	"res://rogland_overcast_1k.hdr",
	"res://misty_farm_road_1k.hdr",
	"res://quarry_cloudy_1k.hdr",
	"res://overcast_soil_1k.hdr",
	"res://kiara_9_dusk_1k.hdr",
	"res://spruit_dawn_1k.hdr"
]
const UPRIGHT_GRASS_ASSET_MODELS := [
	Q_NATURE + "Grass_Wispy_Tall.gltf",
	Q_NATURE + "Grass_Common_Tall.gltf",
	Q_NATURE + "Grass_Wispy_Short.gltf",
	Q_NATURE + "Grass_Common_Short.gltf"
]
const SURVIVAL_TOOL_MODELS := {
	"axe": K_SURVIVAL + "tool-axe.glb",
	"hoe": K_SURVIVAL + "tool-hoe.glb",
	"shovel": K_SURVIVAL + "tool-shovel.glb",
	"hammer": K_SURVIVAL + "tool-hammer.glb",
	"pickaxe": K_SURVIVAL + "tool-pickaxe.glb",
	"wood": K_SURVIVAL + "resource-wood.glb",
	"planks": K_SURVIVAL + "resource-planks.glb",
	"stone": K_SURVIVAL + "resource-stone.glb",
	"backpack": K_SURVIVAL + "bedroll-packed.glb"
}
const REAL_ROCK_MODELS := [
	POLY_MODEL_DIR + "boulder_01/boulder_01_1k.gltf",
	POLY_MODEL_DIR + "rock_07/rock_07_1k.gltf",
	POLY_MODEL_DIR + "rock_09/rock_09_1k.gltf",
	POLY_MODEL_DIR + "rock_face_01/rock_face_01_1k.gltf",
	POLY_MODEL_DIR + "rock_face_02/rock_face_02_1k.gltf",
	POLY_MODEL_DIR + "rock_moss_set_01/rock_moss_set_01_1k.gltf",
	POLY_MODEL_DIR + "namaqualand_boulder_03/namaqualand_boulder_03_1k.gltf",
	POLY_MODEL_DIR + "namaqualand_boulder_05/namaqualand_boulder_05_1k.gltf",
	POLY_MODEL_DIR + "namaqualand_boulder_06/namaqualand_boulder_06_1k.gltf",
	Q_NATURE + "Rock_Medium_1.gltf",
	Q_NATURE + "Rock_Medium_2.gltf",
	Q_NATURE + "Rock_Medium_3.gltf",
	Q_NATURE + "RockPath_Round_Wide.gltf",
	Q_NATURE + "RockPath_Round_Thin.gltf",
	Q_NATURE + "RockPath_Square_Wide.gltf",
	"res://assets/external/kenney_survival_kit/Models/GLB format/rock-a.glb",
	"res://assets/external/kenney_survival_kit/Models/GLB format/rock-b.glb",
	"res://assets/external/kenney_survival_kit/Models/GLB format/rock-c.glb"
]
const REAL_BUSH_MODELS := [
	POLY_MODEL_DIR + "fern_02/fern_02_1k.gltf",
	POLY_MODEL_DIR + "nettle_plant/nettle_plant_1k.gltf",
	POLY_MODEL_DIR + "shrub_01/shrub_01_1k.gltf",
	POLY_MODEL_DIR + "shrub_02/shrub_02_1k.gltf",
	POLY_MODEL_DIR + "shrub_03/shrub_03_1k.gltf",
	POLY_MODEL_DIR + "shrub_04/shrub_04_1k.gltf",
	POLY_MODEL_DIR + "shrub_sorrel_01/shrub_sorrel_01_1k.gltf",
	POLY_MODEL_DIR + "weed_plant_02/weed_plant_02_1k.gltf",
	POLY_MODEL_DIR + "tree_stump_01/tree_stump_01_1k.gltf",
	POLY_MODEL_DIR + "tree_stump_02/tree_stump_02_1k.gltf",
	Q_NATURE + "Bush_Common.gltf",
	Q_NATURE + "Bush_Common_Flowers.gltf",
	Q_NATURE + "Plant_1.gltf",
	Q_NATURE + "Plant_1_Big.gltf",
	Q_NATURE + "Plant_7.gltf",
	Q_NATURE + "Plant_7_Big.gltf",
	Q_NATURE + "Clover_1.gltf",
	Q_NATURE + "Clover_2.gltf"
]
const REAL_CAR_MODELS := [
	"res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Pickup_Armored.gltf",
	"res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Truck_Armored.gltf",
	"res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Sports_Armored.gltf",
	"res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Pickup.gltf",
	"res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Truck.gltf",
	"res://assets/external/realistic/abandoned_car.glb",
	"res://assets/external/realistic/rusty_car.glb",
	"res://assets/external/realistic/wrecked_car.glb"
]
const REAL_VAN_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Truck.gltf"
const REAL_HOUSE_MODELS := [
	"res://assets/external/realistic/abandoned_house_01.glb",
	"res://assets/external/realistic/abandoned_house_02.glb",
	"res://assets/external/realistic/ruined_house.glb"
]
const REAL_SHELTER_MODEL := "res://assets/external/realistic/player_shelter.glb"
const REAL_GAS_STATION_MODEL := "res://assets/external/realistic/gas_station.glb"
const REAL_POLICE_STATION_MODEL := "res://assets/external/realistic/police_station.glb"
const REAL_RADIO_POINT_MODEL := "res://assets/external/realistic/radio_point.glb"

const Q_ENV := "res://assets/external/quaternius_zombie_apocalypse/Environment/glTF/"
const HOUSE_BUILDING_PROPS := [
	K_SURVIVAL + "structure.glb",
	K_SURVIVAL + "structure-metal.glb",
	K_SURVIVAL + "structure-canvas.glb",
	K_SURVIVAL + "structure-metal-doorway.glb",
	K_SURVIVAL + "structure-metal-wall.glb",
	K_SURVIVAL + "structure-metal-floor.glb",
	K_SURVIVAL + "structure-roof.glb",
	K_SURVIVAL + "structure-metal-roof.glb",
	K_SURVIVAL + "floor-old.glb",
	K_SURVIVAL + "floor-hole.glb",
	K_SURVIVAL + "resource-planks.glb",
	K_SURVIVAL + "metal-panel.glb",
	K_SURVIVAL + "metal-panel-screws.glb",
	K_SURVIVAL + "metal-panel-narrow.glb",
	K_SURVIVAL + "fence-doorway.glb",
	K_SURVIVAL + "fence.glb",
	K_SURVIVAL + "fence-fortified.glb"
]
const HOUSE_INTERIOR_PROPS := [
	Q_ENV + "Couch.gltf",
	Q_ENV + "Chest.gltf",
	Q_ENV + "Barrel.gltf",
	Q_ENV + "Pallet.gltf",
	Q_ENV + "Pallet_Broken.gltf",
	Q_ENV + "Pipes.gltf",
	Q_ENV + "TrashBag_1.gltf",
	Q_ENV + "TrashBag_2.gltf",
	Q_ENV + "CinderBlock.gltf",
	K_SURVIVAL + "chest.glb",
	K_SURVIVAL + "box-open.glb",
	K_SURVIVAL + "box-large-open.glb"
]
const NO_GRASS_AREAS := [
	{"center": Vector3(0, 0, 0), "half": Vector2(6.0, 5.6)},
	{"center": Vector3(-25, 0, -18), "half": Vector2(7.4, 6.6)},
	{"center": Vector3(-38, 0, 18), "half": Vector2(7.4, 6.6)},
	{"center": Vector3(23, 0, 18), "half": Vector2(7.4, 6.6)},
	{"center": Vector3(42, 0, 26), "half": Vector2(7.4, 6.6)},
	{"center": Vector3(-12, 0, 42), "half": Vector2(7.4, 6.6)},
	{"center": Vector3(33, 0, -30), "half": Vector2(6.6, 5.2)},
	{"center": Vector3(45, 0, 0), "half": Vector2(6.8, 5.6)},
	{"center": Vector3(-42, 0, -42), "half": Vector2(4.2, 4.2)},
	{"center": Vector3(14, 0, -50), "half": Vector2(4.0, 7.0)},
	{"center": Vector3(56, 0, 38), "half": Vector2(4.0, 7.0)},
	{"center": Vector3(58, 0, -52), "half": Vector2(4.0, 7.0)}
]

func _ready() -> void:
	randomize()
	_create_environment()
	_create_day_night()
	_create_map()
	_create_player()
	_create_audio()
	_create_hud()
	hud.show_notice("Haz clic en la ventana para capturar el raton. Empiezas en la carretera.")

func _exit_tree() -> void:
	for cached_scene in external_scene_cache.values():
		if cached_scene is Node:
			(cached_scene as Node).free()
	external_scene_cache.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q and event.shift_pressed:
		get_tree().quit()
		return
	if game_over:
		return
	if hud != null and hud.inventory_visible and event is InputEventMouseButton and event.pressed:
		if hud.handle_context_menu_click(event.position, event.button_index):
			return
		hud.handle_slot_click(event.position, event.button_index)
		return
	var tab_pressed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	if hud != null and (event.is_action_pressed("toggle_inventory") or tab_pressed):
		hud.toggle_inventory()

func _input(event: InputEvent) -> void:
	pass

func _process(delta: float) -> void:
	if player == null or day_cycle == null:
		return
	if game_over:
		return
	player.in_shelter = player.global_position.distance_to(Vector3.ZERO) < 8.5
	player.stats.tick(delta, player.is_sprinting, day_cycle.get_cold_factor(), player.in_shelter)
	_update_water_night_amount()
	_tick_world_actions(delta)
	_tick_drink_hold(delta)

func _tick_drink_hold(delta: float) -> void:
	if _drink_hold_actor == null:
		return
	if not Input.is_action_pressed("interact"):
		_drink_hold_actor = null
		_drink_hold_timer = 0.0
		return
	_drink_hold_timer += delta
	if _drink_hold_timer >= 1.0:
		_drink_hold_timer -= 1.0
		_drink_hold_actor.stats.thirst = min(_drink_hold_actor.stats.max_stat, _drink_hold_actor.stats.thirst + 5.0)
		_drink_hold_actor.stats.changed.emit()
		_drink_hold_actor.notice.emit("Bebes agua del rio.")
		_play_actor_action(_drink_hold_actor, "plant", 1.2)

func _tick_world_actions(delta: float) -> void:
	for action in world_actions_by_id.values():
		if action != null and action.has_method("tick_growth"):
			action.tick_growth(delta)

func _update_celestial_follow() -> void:
	return

func _update_water_night_amount() -> void:
	if day_cycle == null:
		return
	var day_amount: float = clamp(sin((day_cycle.time_of_day - 6.0) / 14.0 * PI), 0.0, 1.0)
	var night_amount := 1.0 - day_amount
	for node in get_tree().get_nodes_in_group("river_water"):
		if node is RiverWater and node.has_method("set_night_amount"):
			node.set_night_amount(night_amount)
	if day_cycle.star_field != null:
		day_cycle.star_field.visible = night_amount > 0.38
	if day_cycle.moon_field != null:
		day_cycle.moon_field.visible = night_amount > 0.34

func save_current_game() -> void:
	pass

func _build_save_data() -> Dictionary:
	return {
		"balance_version": SAVE_BALANCE_VERSION,
		"player": player.to_dict(),
		"day_cycle": day_cycle.to_dict(),
		"radio": radio.to_dict(),
		"containers": _containers_to_array(),
		"world_actions": _world_actions_to_array()
	}

func _save_world_change_silent() -> void:
	SaveSystemScript.save_game(_build_save_data())

func sleep_at_shelter() -> void:
	player.stats.rest(6.0)
	day_cycle.skip_to_morning()
	save_current_game()
	hud.show_notice("Duermes unas horas. Amanece frio y silencioso.")

func listen_radio() -> void:
	var message: String = radio.listen()
	hud.show_notice("Radio: \"%s\"" % message)

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var environment := Environment.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.34, 0.62, 0.95)
	sky_material.sky_horizon_color = Color(0.78, 0.90, 1.0)
	sky_material.ground_bottom_color = Color(0.20, 0.30, 0.16)
	sky_material.ground_horizon_color = Color(0.38, 0.52, 0.28)
	sky_material.sun_angle_max = 4.0
	sky_material.sun_curve = 0.12
	var sky := Sky.new()
	var hdri_sky_material = _make_hdri_sky_material()
	if hdri_sky_material != null:
		sky.sky_material = hdri_sky_material
	else:
		sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color(0.56, 0.76, 0.96)
	environment.ambient_light_color = Color(0.86, 0.90, 0.92)
	environment.ambient_light_energy = 0.95
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.78, 0.86, 0.90)
	environment.fog_density = 0.0025
	environment.glow_enabled = true
	environment.glow_intensity = 0.08
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.shadow_enabled = true
	# Shorter shadow distance massively reduces per-frame shadow draw cost in the
	# gl_compatibility renderer while keeping shadows near the player.
	sun.directional_shadow_max_distance = 55.0
	add_child(sun)
	_create_star_field()
	_create_moon_field()

func _create_day_night() -> void:
	day_cycle = DayNightCycleScript.new()
	day_cycle.name = "DayNightCycle"
	add_child(day_cycle)
	day_cycle.sun = get_node("Sun") as DirectionalLight3D
	day_cycle.world_environment = get_node("WorldEnvironment") as WorldEnvironment
	day_cycle.star_field = get_node_or_null("StarField") as Node3D
	day_cycle.moon_field = get_node_or_null("MoonField") as Node3D

	radio = RadioSystemScript.new()
	radio.name = "RadioSystem"
	add_child(radio)
	day_cycle.night_started.connect(func() -> void:
		var message: String = radio.emit_night_message()
		if hud != null:
			hud.show_notice("La radio crepita: \"%s\"" % message)
	)

func _create_star_field() -> void:
	var root := Node3D.new()
	root.name = "StarField"
	root.visible = false
	root.position = Vector3.ZERO
	add_child(root)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.98, 1.0, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.86, 0.90, 1.0)
	material.emission_energy_multiplier = 7.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var star_count := 420
	var star_mesh := QuadMesh.new()
	star_mesh.size = Vector2(0.22, 0.22)
	for i in range(star_count):
		var angle := randf_range(0.0, TAU)
		var radius := randf_range(105.0, 148.0)
		var height := randf_range(34.0, 82.0)
		var star := MeshInstance3D.new()
		star.name = "NightStar"
		star.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)
		var star_size := randf_range(0.7, 1.7)
		if randf() < 0.10:
			star_size *= 2.2
		star.scale = Vector3.ONE * star_size
		star.mesh = star_mesh
		star.material_override = material
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(star)

func _create_moon_field() -> void:
	var root := Node3D.new()
	root.name = "MoonField"
	root.visible = false
	add_child(root)

	var phase := _get_real_moon_phase_data()
	var disc_radius := 4.8
	var moon_pos := Vector3(-38.0, 62.0, -72.0)

	var moon := MeshInstance3D.new()
	moon.name = "RealPhaseMoonDisc"
	moon.position = moon_pos
	moon.mesh = _make_disc_mesh(disc_radius, 96)
	moon.material_override = _make_celestial_material(Color(0.90, 0.88, 0.76, 0.98), Color(0.92, 0.88, 0.70), 3.2)
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(moon)

	var shadow := MeshInstance3D.new()
	shadow.name = "RealPhaseMoonShadow"
	var illumination: float = phase["illumination"]
	var waxing: bool = phase["waxing"]
	var offset := disc_radius * 2.0 * illumination * (-1.0 if waxing else 1.0)
	shadow.position = moon_pos + Vector3(offset, 0.0, 0.035)
	shadow.mesh = _make_disc_mesh(disc_radius * 1.02, 96)
	shadow.material_override = _make_celestial_material(Color(0.012, 0.016, 0.035, 0.96), Color(0.0, 0.0, 0.0), 0.0)
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(shadow)

	var glow := MeshInstance3D.new()
	glow.name = "MoonGlow"
	glow.position = moon_pos + Vector3(0.0, 0.0, -0.02)
	glow.mesh = _make_disc_mesh(disc_radius * 1.42, 96)
	glow.material_override = _make_celestial_material(Color(0.62, 0.68, 0.86, 0.16), Color(0.40, 0.48, 0.78), 0.75)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)

func _get_real_moon_phase_data() -> Dictionary:
	var unix_time: float = Time.get_unix_time_from_system()
	var julian_date: float = unix_time / 86400.0 + 2440587.5
	var synodic_month: float = 29.530588853
	var known_new_moon_jd: float = 2451550.1
	var age: float = fposmod(julian_date - known_new_moon_jd, synodic_month)
	var phase_angle: float = TAU * age / synodic_month
	var illumination: float = clamp((1.0 - cos(phase_angle)) * 0.5, 0.0, 1.0)
	return {
		"age": age,
		"illumination": illumination,
		"waxing": age < synodic_month * 0.5
	}

func _make_disc_mesh(radius: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.5))
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var point := Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
		vertices.append(point)
		uvs.append(Vector2(point.x / (radius * 2.0) + 0.5, point.y / (radius * 2.0) + 0.5))
	for i in range(segments):
		indices.append(0)
		indices.append(i + 1)
		indices.append(1 if i == segments - 1 else i + 2)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _make_celestial_material(albedo: Color, emission: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = energy > 0.0
	material.emission = emission
	material.emission_energy_multiplier = energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return material

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.position = Vector3(8.0, 0.4, 2.5)
	add_child(player)
	player.stats.died.connect(_on_player_died)
	player.item_dropped.connect(_on_item_dropped)

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if player != null and player.has_method("die"):
		player.die()
	SaveSystemScript.delete_save()
	if hud != null:
		hud.show_notice("Has muerto. Todo vuelve a empezar.")
		var death_timer := get_tree().create_timer(3.0)
		var tw := create_tween()
		tw.tween_await(death_timer.timeout)
		tw.tween_callback(func(): get_tree().reload_current_scene())
		await tw.finished

func _on_item_dropped(item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3) -> void:
	var drop_id := "drop_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	var visual_name := "Pickup_" + drop_id
	var paths: Array = _get_drop_model_paths(item_name, item_type)
	var scale_value := _get_drop_scale(item_name, item_type)
	if not paths.is_empty():
		_try_instance_external_scene(paths, visual_name, pos, Vector3.ONE * scale_value, Vector3(0, randf_range(0, 360), 0), true, 0.06)
		_mark_world_action_visual(visual_name)
	var action_kind := "eat_food" if item_type == "food" else "pickup_item"
	var action = _create_world_action(drop_id, action_kind, item_name, pos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
	action.set_meta("visual_name", visual_name)
	action.set_meta("item_name", item_name)
	action.set_meta("item_type", item_type)
	action.set_meta("item_weight", item_weight)
	action.set_meta("item_quantity", item_quantity)
	action.set_meta("item_use_value", item_use_value)

func _get_drop_model_paths(item_name: String, item_type: String) -> Array:
	match item_type:
		"water":
			return [K_SURVIVAL + "bottle-large.glb", K_SURVIVAL + "bottle.glb"]
		"resource":
			if item_name == "Piedra":
				return [SURVIVAL_TOOL_MODELS["stone"]]
			return [SURVIVAL_TOOL_MODELS["planks"], SURVIVAL_TOOL_MODELS["wood"]]
		"weapon":
			return [ROOT_KNIFE_MODEL, ROOT_WEAPON_KNIFE_MODEL, "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/Knife.gltf"]
		"food":
			return [ROOT_CANNED_FOOD_MODEL]
		"backpack":
			return [ROOT_BACKPACK_MODEL, SURVIVAL_TOOL_MODELS["backpack"]]
		"tool_axe":
			return [ROOT_GLB_DIR + "axe_survival.glb", SURVIVAL_TOOL_MODELS["axe"]]
		"tool_hoe":
			return [SURVIVAL_TOOL_MODELS["hoe"]]
		"tool_shovel":
			return [SURVIVAL_TOOL_MODELS["shovel"]]
		"tool_hammer":
			return [SURVIVAL_TOOL_MODELS["hammer"]]
		"tool_pickaxe":
			return [SURVIVAL_TOOL_MODELS["pickaxe"]]
		"clothing":
			match item_name:
				"Botas de goma":
					return [POLY_RUBBER_BOOTS_MODEL]
				"Guantes de trabajo":
					return [POLY_GARDEN_GLOVES_MODEL]
				"Sombrero de pescador":
					return [POLY_FISHERMANS_HAT_MODEL]
				"Chaleco salvavidas":
					return [POLY_LIFE_JACKET_MODEL]
				"Chaleco tactico":
					return [ROOT_VEST_MODEL]
				"Chaqueta de abrigo":
					return [POLY_LIFE_JACKET_MODEL]
				_:
					return [POLY_VINTAGE_SUITCASE_MODEL]
		"seed":
			return [K_SURVIVAL + "grass.glb"]
		_:
			return [POLY_VINTAGE_SUITCASE_MODEL]

func _get_drop_scale(item_name: String, item_type: String) -> float:
	match item_type:
		"water":
			return 1.0
		"resource":
			return 1.0
		"weapon":
			return 0.8
		"food":
			return 1.0
		"backpack":
			return 1.2
		"tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe":
			return 1.0
		"clothing":
			match item_name:
				"Chaleco tactico":
					return 0.05
				"Chaleco salvavidas":
					return 0.8
				"Chaqueta de abrigo":
					return 0.8
				_:
					return 0.7
		"seed":
			return 1.0
		_:
			return 0.8

func _create_audio() -> void:
	audio_system = AudioSystemScript.new()
	audio_system.name = "AudioSystem"
	add_child(audio_system)
	audio_system.setup(player, day_cycle)

func _create_hud() -> void:
	hud = HUDScript.new()
	add_child(hud)
	hud.setup(player, day_cycle)

func _create_npc() -> void:
	var npc = NPCControllerScript.new()
	npc.name = "HostileHuman"
	npc.position = Vector3(36, 0.3, -8)
	add_child(npc)
	npc.setup(player, [Vector3(36, 0, -8), Vector3(49, 0, -8), Vector3(48, 0, 5), Vector3(34, 0, 6)])
	npc.npc_notice.connect(func(text: String) -> void:
		if hud != null:
			hud.show_notice(text)
	)

func _create_map() -> void:
	var _tm := Time.get_ticks_msec()
	river_segments_data = _default_river_segments()
	_create_invisible_collision_box("GroundCollision", Vector3(0, -0.2, 0), Vector3(150, 0.2, 150))
	_create_visual_plane("TerrainSurface", Vector3(0, 0.003, 0), Vector2(150, 150), Color(0.17, 0.20, 0.145))
	_create_grass_ground_cover()
	print("TIME grass_ground_cover: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_terrain_variation()
	print("TIME terrain_variation: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_mountain_backdrop()
	print("TIME mountain_backdrop: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_mountain_river()
	print("TIME mountain_river: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_static_box("Road", Vector3(8, 0.01, 0), Vector3(7, 0.06, 125), Color(0.034, 0.036, 0.034))
	_create_static_box("RoadCenterLineA", Vector3(8, 0.055, -32), Vector3(0.18, 0.025, 12), Color(0.62, 0.58, 0.38))
	_create_static_box("RoadCenterLineB", Vector3(8, 0.055, -8), Vector3(0.18, 0.025, 12), Color(0.62, 0.58, 0.38))
	_create_static_box("RoadCenterLineC", Vector3(8, 0.055, 16), Vector3(0.18, 0.025, 12), Color(0.62, 0.58, 0.38))
	_create_static_box("RoadCenterLineD", Vector3(8, 0.055, 40), Vector3(0.18, 0.025, 12), Color(0.62, 0.58, 0.38))
	_create_static_box("RoadShoulderA", Vector3(3.9, 0.015, 0), Vector3(0.5, 0.05, 125), Color(0.22, 0.20, 0.17))
	_create_static_box("RoadShoulderB", Vector3(12.1, 0.015, 0), Vector3(0.5, 0.05, 125), Color(0.22, 0.20, 0.17))
	_create_broken_road_details()
	_create_label("Carretera", Vector3(8, 1.0, -28))
	_create_house(Vector3(-25, 0, -18), "Casa abandonada 1", "house_1")
	_create_house(Vector3(-38, 0, 18), "Casa abandonada 2", "house_2")
	_create_house(Vector3(23, 0, 18), "Casa abandonada 3", "house_3")
	_create_house(Vector3(42, 0, 26), "Casa abandonada 4", "house_4")
	_create_house(Vector3(-12, 0, 42), "Casa abandonada 5", "house_5")
	_create_radio_point(Vector3(-42, 0, -42))
	print("TIME structures: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_world_details()
	print("TIME world_details: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_ground_clutter()
	print("TIME ground_clutter: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_tall_grass_fields()
	print("TIME tall_grass_fields: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_dense_vegetation_zones()
	print("TIME dense_vegetation: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_forest()
	print("TIME forest: %dms" % (Time.get_ticks_msec() - _tm))
	_tm = Time.get_ticks_msec()
	_create_survival_objectives()
	_create_river_drink_zones()
	_build_nav_grid()
	_create_wildlife()
	_flush_grass_batches()
	print("TIME objectives+nav+wildlife+flush: %dms" % (Time.get_ticks_msec() - _tm))

func _create_house(origin: Vector3, label: String, id_prefix: String) -> void:
	_register_wildlife_blocker(origin, 8.2)
	_create_label(label, origin + Vector3(0, 4.05, -4.65))
	_create_house_overgrowth(origin, label)
	_create_house_foundation(origin, label)
	_create_house_floor(origin, label)
	_create_textured_wall(label + " Back", origin + Vector3(0, 0, -4.7), Vector3(11.4, 3.65, 0.35), Vector3.ZERO)
	_create_textured_wall(label + " Left", origin + Vector3(-5.7, 0, 0), Vector3(0.35, 3.65, 9.4), Vector3.ZERO)
	_create_textured_wall(label + " Right", origin + Vector3(5.7, 0, 0), Vector3(0.35, 3.65, 9.4), Vector3.ZERO)
	_create_textured_wall(label + " FrontA", origin + Vector3(-4.35, 0, 4.7), Vector3(2.7, 3.65, 0.35), Vector3.ZERO)
	_create_textured_wall(label + " FrontB", origin + Vector3(4.35, 0, 4.7), Vector3(2.7, 3.65, 0.35), Vector3.ZERO)
	_create_textured_wall(label + " FrontLeftReturn", origin + Vector3(-1.95, 0, 4.7), Vector3(1.05, 3.65, 0.35), Vector3.ZERO)
	_create_textured_wall(label + " FrontRightReturn", origin + Vector3(1.95, 0, 4.7), Vector3(1.05, 3.65, 0.35), Vector3.ZERO)
	_create_house_details(origin, label)

func _create_house_foundation(origin: Vector3, label: String) -> void:
	# Concrete skirting (perimeter beams) under the brick walls, so the houses
	# read as "brick over a concrete base" without covering the wooden floor.
	# Front is split (FrontLeft/FrontRight) to leave the doorway gap clear.
	var beams := [
		{"pos": Vector3(0, 0, -4.78), "size": Vector3(12.3, 0.5, 0.6)},
		{"pos": Vector3(-4.35, 0, 4.78), "size": Vector3(3.6, 0.5, 0.6)},
		{"pos": Vector3(4.35, 0, 4.78), "size": Vector3(3.6, 0.5, 0.6)},
		{"pos": Vector3(-5.78, 0, 0), "size": Vector3(0.6, 0.5, 10.2)},
		{"pos": Vector3(5.78, 0, 0), "size": Vector3(0.6, 0.5, 10.2)}
	]
	for i in range(beams.size()):
		var beam: Dictionary = beams[i]
		var beam_size: Vector3 = beam["size"]
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = label + " Foundation_%d" % i
		mesh_instance.position = origin + Vector3(beam["pos"].x, -0.14 + beam_size.y * 0.5, beam["pos"].z)
		mesh_instance.mesh = _get_shared_box_mesh()
		mesh_instance.scale = beam_size
		var uv_scale := Vector3(max(beam_size.x, beam_size.z) / 2.0, beam_size.y / 2.0, 1.0)
		mesh_instance.material_override = _make_textured_material("ConcreteBase" + TEX_CONCRETE_DIFF, TEX_CONCRETE_DIFF, Color(0.55, 0.54, 0.52), uv_scale)
		add_child(mesh_instance)

func _create_house_floor(origin: Vector3, label: String) -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.28, 0.20, 0.10)
	floor_mat.roughness = 0.9
	floor_mat.uv1_scale = Vector3(4.0, 3.3, 1.0)
	var floor_tex = _load_texture_from_path(TEX_WOOD_FLOOR_DIFF)
	if floor_tex != null:
		floor_mat.albedo_texture = floor_tex
		floor_mat.albedo_color = Color(0.78, 0.70, 0.58)
	var body := StaticBody3D.new()
	body.name = label + " Floor"
	body.position = origin
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _get_shared_box_mesh()
	mesh_instance.scale = Vector3(11.0, 0.08, 9.0)
	mesh_instance.position.y = 0.04
	mesh_instance.material_override = floor_mat
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(11.0, 0.08, 9.0)
	collision.shape = shape
	collision.position.y = 0.04
	body.add_child(collision)
	add_child(body)

func _create_house_overgrowth(origin: Vector3, label: String) -> void:
	var spots := [
		Vector3(-5.25, 0.055, 5.55), Vector3(-3.65, 0.055, 5.85), Vector3(3.55, 0.055, 5.70), Vector3(5.20, 0.055, 5.45),
		Vector3(-5.65, 0.055, 2.9), Vector3(5.75, 0.055, 2.4), Vector3(-5.85, 0.055, -2.4), Vector3(5.85, 0.055, -2.9),
		Vector3(-4.75, 0.055, -5.35), Vector3(-1.7, 0.055, -5.55), Vector3(1.85, 0.055, -5.45), Vector3(4.85, 0.055, -5.30)
	]
	for spot in spots:
		_create_house_grass_asset(label + " OvergrownGrass", origin + spot, randf_range(0.24, 0.46))
	for i in range(10):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := origin + Vector3(side * randf_range(5.9, 6.55), 0.055, randf_range(-4.2, 4.6))
		_create_house_grass_asset(label + " SideGrass", pos, randf_range(0.20, 0.38))

func _create_house_grass_asset(node_name: String, pos: Vector3, scale_value: float) -> void:
	_create_grass_clump(pos, scale_value * 1.6, Color(0.17, 0.33, 0.10).lerp(Color(0.35, 0.43, 0.15), randf()))

func _create_gas_station(origin: Vector3) -> void:
	_register_wildlife_blocker(origin, 10.5)
	_register_wildlife_blocker(origin + Vector3(0.0, 0.0, 7.0), 6.8)
	_create_label("Gasolinera", origin + Vector3(0, 3.3, 0))
	if _try_instance_external_scene([REAL_GAS_STATION_MODEL], "RealGasStation", origin, Vector3.ONE, Vector3.ZERO):
		_create_loot_container("gas_car", "Coche abandonado", origin + Vector3(8, 0, 7), Vector3(2.4, 1.2, 4.0), Color(0.12, 0.16, 0.16), [ROOT_RUSTY_CAR_MODEL])
		_create_loot_container("gas_crate", "Caja de gasolinera", origin + Vector3(-2, 0, -1), Vector3(1.2, 0.8, 1.0), Color(0.18, 0.13, 0.09), [K_SURVIVAL + "box-open.glb", K_SURVIVAL + "box-large-open.glb"])
		return
	_create_static_box("GasStationFloor", origin, Vector3(9, 0.2, 6), Color(0.16, 0.14, 0.11))
	_create_static_box("GasStationBack", origin + Vector3(0, 0, -3), Vector3(9, 2.6, 0.35), Color(0.27, 0.24, 0.19))
	_create_static_box("GasStationLeft", origin + Vector3(-4.5, 0, 0), Vector3(0.35, 2.6, 6), Color(0.25, 0.22, 0.18))
	_create_static_box("GasStationRight", origin + Vector3(4.5, 0, 0), Vector3(0.35, 2.6, 6), Color(0.25, 0.22, 0.18))
	_create_static_box("GasStationFrontA", origin + Vector3(-3, 0, 3), Vector3(3, 2.6, 0.35), Color(0.26, 0.23, 0.18))
	_create_static_box("GasStationFrontB", origin + Vector3(3, 0, 3), Vector3(3, 2.6, 0.35), Color(0.26, 0.23, 0.18))
	_create_visual_box("GasWindowLeft", origin + Vector3(-2.6, 1.35, 3.21), Vector3(1.2, 0.72, 0.06), Color(0.05, 0.07, 0.08), Vector3.ZERO)
	_create_visual_box("GasWindowRight", origin + Vector3(2.6, 1.35, 3.21), Vector3(1.2, 0.72, 0.06), Color(0.05, 0.07, 0.08), Vector3.ZERO)
	_create_visual_box("GasDirtyStripe", origin + Vector3(0, 2.05, 3.22), Vector3(7.2, 0.18, 0.055), Color(0.42, 0.10, 0.07), Vector3.ZERO)
	_create_static_box("PumpA", origin + Vector3(-3.2, 0, 7), Vector3(0.8, 1.8, 0.8), Color(0.36, 0.08, 0.06))
	_create_static_box("PumpB", origin + Vector3(2.5, 0, 7), Vector3(0.8, 1.8, 0.8), Color(0.36, 0.08, 0.06))
	_create_static_box("GasStationCanopy", origin + Vector3(-0.4, 2.6, 7), Vector3(9.5, 0.25, 5.5), Color(0.19, 0.16, 0.12))
	_create_static_box("GasStationSign", origin + Vector3(-5.8, 0, 4.7), Vector3(0.35, 3.4, 1.8), Color(0.39, 0.09, 0.06))
	_create_loot_container("gas_car", "Coche abandonado", origin + Vector3(8, 0, 7), Vector3(2.4, 1.2, 4.0), Color(0.12, 0.16, 0.16), [ROOT_RUSTY_CAR_MODEL])
	_create_loot_container("gas_crate", "Caja de gasolinera", origin + Vector3(-2, 0, -1), Vector3(1.2, 0.8, 1.0), Color(0.18, 0.13, 0.09), [K_SURVIVAL + "box-open.glb", K_SURVIVAL + "box-large-open.glb"])
	_create_scrap_pile(origin + Vector3(-6.5, 0, -4.8))

func _create_police_station(origin: Vector3) -> void:
	_register_wildlife_blocker(origin, 8.7)
	_create_label("Comisaria", origin + Vector3(0, 3.5, 0))
	if _try_instance_external_scene([REAL_POLICE_STATION_MODEL], "RealPoliceStation", origin, Vector3.ONE, Vector3.ZERO):
		_create_loot_container("police_locker", "Taquilla", origin + Vector3(-3, 0, -2), Vector3(1.0, 1.9, 0.65), Color(0.13, 0.16, 0.17), [ROOT_FURNITURE_MODEL, K_SURVIVAL + "box-large-open.glb"])
		_create_loot_container("police_bag", "Mochila abandonada", origin + Vector3(2.3, 0, 1.7), Vector3(1.0, 0.75, 0.8), Color(0.10, 0.13, 0.09), [ROOT_BACKPACK_MODEL])
		return
	_create_static_box("PoliceFloor", origin, Vector3(10, 0.2, 7), Color(0.12, 0.13, 0.14))
	_create_static_box("PoliceBack", origin + Vector3(0, 0, -3.5), Vector3(10, 3.0, 0.35), Color(0.18, 0.20, 0.22))
	_create_static_box("PoliceLeft", origin + Vector3(-5, 0, 0), Vector3(0.35, 3.0, 7), Color(0.18, 0.20, 0.22))
	_create_static_box("PoliceRight", origin + Vector3(5, 0, 0), Vector3(0.35, 3.0, 7), Color(0.18, 0.20, 0.22))
	_create_static_box("PoliceFrontA", origin + Vector3(-3.3, 0, 3.5), Vector3(3.4, 3.0, 0.35), Color(0.17, 0.19, 0.21))
	_create_static_box("PoliceFrontB", origin + Vector3(3.3, 0, 3.5), Vector3(3.4, 3.0, 0.35), Color(0.17, 0.19, 0.21))
	_create_static_box("PoliceFlatRoof", origin + Vector3(0, 3.0, 0), Vector3(10.6, 0.35, 7.6), Color(0.09, 0.10, 0.105))
	_create_visual_box("PoliceWindowA", origin + Vector3(-3.0, 1.45, 3.72), Vector3(1.25, 0.82, 0.06), Color(0.035, 0.045, 0.055), Vector3.ZERO)
	_create_visual_box("PoliceWindowB", origin + Vector3(3.0, 1.45, 3.72), Vector3(1.25, 0.82, 0.06), Color(0.035, 0.045, 0.055), Vector3.ZERO)
	_create_static_box("PoliceDesk", origin + Vector3(-1.2, 0, 0.8), Vector3(2.0, 0.8, 0.9), Color(0.13, 0.12, 0.10))
	_create_static_box("PoliceBars", origin + Vector3(3.2, 0, -1.1), Vector3(0.25, 2.2, 2.6), Color(0.08, 0.09, 0.10))
	_create_loot_container("police_locker", "Taquilla", origin + Vector3(-3, 0, -2), Vector3(1.0, 1.9, 0.65), Color(0.13, 0.16, 0.17), [ROOT_FURNITURE_MODEL, K_SURVIVAL + "box-large-open.glb"])
	_create_loot_container("police_bag", "Mochila abandonada", origin + Vector3(2.3, 0, 1.7), Vector3(1.0, 0.75, 0.8), Color(0.10, 0.13, 0.09), [ROOT_BACKPACK_MODEL])

func _create_radio_point(origin: Vector3) -> void:
	_register_wildlife_blocker(origin, 6.0)
	_register_wildlife_blocker(origin + Vector3(3.6, 0.0, -1.5), 2.8)
	_create_label("Punto de radio", origin + Vector3(0, 4.0, 0))
	if _try_instance_external_scene([REAL_RADIO_POINT_MODEL], "RealRadioPoint", origin, Vector3.ONE, Vector3.ZERO):
		_create_loot_container("radio_crate", "Caja tecnica", origin + Vector3(-1.3, 0, -1.2), Vector3(1.2, 0.75, 1.0), Color(0.10, 0.12, 0.10), [K_SURVIVAL + "box-open.glb", ROOT_JUNK_MODEL])
		return
	_create_static_box("RadioShedFloor", origin, Vector3(5, 0.2, 5), Color(0.11, 0.11, 0.10))
	_create_static_box("RadioShedBack", origin + Vector3(0, 0, -2.5), Vector3(5, 2.4, 0.3), Color(0.17, 0.17, 0.15))
	_create_static_box("RadioShedLeft", origin + Vector3(-2.5, 0, 0), Vector3(0.3, 2.4, 5), Color(0.16, 0.16, 0.14))
	_create_static_box("RadioShedRight", origin + Vector3(2.5, 0, 0), Vector3(0.3, 2.4, 5), Color(0.16, 0.16, 0.14))
	_create_static_box("RadioShedFrontA", origin + Vector3(-1.7, 0, 2.5), Vector3(1.6, 2.4, 0.3), Color(0.15, 0.15, 0.13))
	_create_static_box("RadioShedFrontB", origin + Vector3(1.7, 0, 2.5), Vector3(1.6, 2.4, 0.3), Color(0.15, 0.15, 0.13))
	_create_static_box("RadioMast", origin + Vector3(3.6, 0, -1.5), Vector3(0.35, 8, 0.35), Color(0.12, 0.12, 0.12))
	_create_loot_container("radio_crate", "Caja tecnica", origin + Vector3(-1.3, 0, -1.2), Vector3(1.2, 0.75, 1.0), Color(0.10, 0.12, 0.10), [K_SURVIVAL + "box-open.glb", ROOT_JUNK_MODEL])

func _create_new_world_props() -> void:
	var car_s := Vector3.ONE * 0.013
	var car_positions := [
		{"pos": Vector3(-22.0, 0.0, -8.0), "rot": Vector3(0, 35, 0)},
		{"pos": Vector3(38.0, 0.0, 18.0), "rot": Vector3(0, -60, 0)},
		{"pos": Vector3(-48.0, 0.0, -32.0), "rot": Vector3(0, 110, 0)}
	]
	for i in range(car_positions.size()):
		var cp = car_positions[i]
		if _try_instance_external_scene([ROOT_RUSTY_CAR_MODEL], "RustyCar%d" % i, cp["pos"], car_s, cp["rot"], true, 0.0):
			var rusty_node := get_node_or_null("RustyCar%d" % i)
			var rusty_height := 2.5
			if rusty_node != null and rusty_node is Node3D:
				rusty_height = _get_node_world_aabb_height(rusty_node as Node3D)
				rusty_height += 0.15
				if rusty_height < 0.5:
					rusty_height = 2.5
			_create_invisible_collision_box_rotated("RustyCarCollision%d" % i, cp["pos"], Vector3(3.0, rusty_height, 5.0), float(cp["rot"].y))
	var cont_s := Vector3.ONE * 1.0
	var cont_positions := [
		{"pos": Vector3(14.0, 0.0, -50.0), "rot": Vector3(0, 0, 0)},
		{"pos": Vector3(56.0, 0.0, 38.0), "rot": Vector3(0, 180, 0)},
		{"pos": Vector3(58.0, 0.0, -52.0), "rot": Vector3(0, 90, 0)}
	]
	for i in range(cont_positions.size()):
		var cp = cont_positions[i]
		if _try_instance_external_scene([ROOT_CONTAINER_MODEL], "Container%d" % i, cp["pos"], cont_s, cp["rot"], true, 0.0):
			var yaw_f: float = float(cp["rot"].y)
			var cont_node := get_node_or_null("Container%d" % i)
			var box_w := 6.0
			var box_h := 2.5
			var box_d := 12.0
			if cont_node != null and cont_node is Node3D:
				var cn := cont_node as Node3D
				var saved_rot := cn.rotation_degrees
				cn.rotation_degrees = Vector3.ZERO
				cn.force_update_transform()
				var meshes := []
				_collect_mesh_instances(cn, meshes)
				var min_v := Vector3(999999, 999999, 999999)
				var max_v := Vector3(-999999, -999999, -999999)
				for mesh_node in meshes:
					var mi := mesh_node as MeshInstance3D
					if mi.mesh == null:
						continue
					mi.force_update_transform()
					var wa: AABB = mi.global_transform * mi.get_aabb()
					min_v.x = min(min_v.x, wa.position.x)
					min_v.y = min(min_v.y, wa.position.y)
					min_v.z = min(min_v.z, wa.position.z)
					max_v.x = max(max_v.x, wa.position.x + wa.size.x)
					max_v.y = max(max_v.y, wa.position.y + wa.size.y)
					max_v.z = max(max_v.z, wa.position.z + wa.size.z)
				cn.rotation_degrees = saved_rot
				box_h = (max_v.y - min_v.y) + 0.1
				box_w = max_v.x - min_v.x
				box_d = max_v.z - min_v.z
				if box_h < 0.5:
					box_h = 2.5
			_create_invisible_collision_box_rotated("ContainerCollision%d" % i, cp["pos"], Vector3(box_w, box_h, box_d), yaw_f)
			_register_wildlife_blocker(cp["pos"], 7.0)
	var sofa_s := Vector3.ONE * 0.009
	_try_instance_external_scene([ROOT_SOFA_MODEL], "BackyardSofaA", Vector3(-24.0, 0.0, -5.0), sofa_s, Vector3(0, 45, 0), true, 0.0)
	_try_instance_external_scene([ROOT_SOFA_MODEL], "BackyardSofaB", Vector3(30.0, 0.0, -35.0), sofa_s, Vector3(0, -20, 0), true, 0.0)

func _create_world_details() -> void:
	_create_road_checkpoint(Vector3(8, 0, -4))
	_create_concrete_barrier("RootConcreteBarrierA", Vector3(4.3, 0.0, -5.7), Vector3(0, 12, 0))
	_create_concrete_barrier("RootConcreteBarrierB", Vector3(11.8, 0.0, -2.2), Vector3(0, -18, 0))
	_try_instance_external_scene([ROOT_JUNK_MODEL], "RootJunkPile", Vector3(-30.5, 0.05, -8.7), Vector3.ONE * 0.72, Vector3(0, 37, 0), true, 0.02)
	_create_new_world_props()
	_create_power_line(Vector3(15, 0, -40), Vector3(15, 0, 40))
	_create_fence_line(Vector3(-8, 0, -9), Vector3(-8, 0, 8), 5)
	_create_fence_line(Vector3(19, 0, 12), Vector3(19, 0, 32), 6)
	_create_scrap_pile(Vector3(14, 0, -17))
	_create_scrap_pile(Vector3(-31, 0, -10))
	_create_abandoned_camp(Vector3(-56, 0, 28))
	_create_military_leftovers(Vector3(25, 0, -12))
	_create_dayz_interaction_examples()
	_create_static_box("RoadSignNorth", Vector3(14.6, 0, -24), Vector3(0.18, 2.4, 0.18), Color(0.10, 0.10, 0.09))
	_create_static_box("RoadSignBoard", Vector3(14.6, 2.0, -24), Vector3(1.5, 0.75, 0.16), Color(0.36, 0.32, 0.22))
	_create_visual_box("RoadSignScratch", Vector3(14.6, 2.05, -23.9), Vector3(1.2, 0.09, 0.05), Color(0.08, 0.075, 0.05), Vector3(0, 0, 8))
	_create_static_box("BusStopFrame", Vector3(14.5, 0, 35), Vector3(0.25, 2.2, 3.0), Color(0.11, 0.12, 0.12))
	_create_static_box("BusStopBench", Vector3(13.8, 0, 35), Vector3(1.6, 0.45, 0.55), Color(0.16, 0.10, 0.07))
	for z in [-54, -38, -21, -6, 12, 27, 48]:
		_create_road_crack(Vector3(8, 0.055, z), randf_range(-18.0, 18.0))

func _create_dayz_interaction_examples() -> void:
	_spawn_interaction_item(BACKPACK_ITEM_SCENE, Vector3(8.35, 0.05, 2.5), Vector3(0, -18, 0))
	_spawn_interaction_item(WATER_BOTTLE_ITEM_SCENE, Vector3(7.55, 0.05, 2.85), Vector3(0, 22, 0))

func _spawn_interaction_item(scene_path: String, pos: Vector3, rot: Vector3) -> void:
	if not ResourceLoader.exists(scene_path):
		return
	var loaded = load(scene_path)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var node := instance as Node3D
	node.position = pos
	node.rotation_degrees = rot
	add_child(node)

func _create_survival_objectives() -> void:
	_create_label("Objetivo: construir una cabana", Vector3(-54, 2.8, 48))
	_create_world_action("cabin_site", "build_cabin", "Base de cabana", Vector3(-54, 0.02, 48), Vector3(3.8, 0.65, 3.0), Color(0.28, 0.22, 0.13), false, false)
	_create_static_box_rotated("CabinFoundationLogsA", Vector3(-54, 0.12, 46.45), Vector3(4.2, 0.22, 0.22), Color(0.18, 0.11, 0.055), Vector3(0, 0, 0))
	_create_static_box_rotated("CabinFoundationLogsB", Vector3(-54, 0.12, 49.55), Vector3(4.2, 0.22, 0.22), Color(0.18, 0.11, 0.055), Vector3(0, 0, 0))
	_create_static_box_rotated("CabinFoundationLogsC", Vector3(-56.1, 0.12, 48), Vector3(0.22, 0.22, 3.3), Color(0.18, 0.11, 0.055), Vector3(0, 0, 0))
	_create_static_box_rotated("CabinFoundationLogsD", Vector3(-51.9, 0.12, 48), Vector3(0.22, 0.22, 3.3), Color(0.18, 0.11, 0.055), Vector3(0, 0, 0))
	for i in range(5):
		var wood_pos := Vector3(randf_range(-62, -28), 0.04, randf_range(12, 62))
		var log_a_name := "HarvestableLogA_%d" % i
		var log_b_name := "HarvestableLogB_%d" % i
		var wood_spawned_a := _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], log_a_name, wood_pos + Vector3(-0.25, 0.04, 0.0), Vector3.ONE * 0.72, Vector3(0, randf_range(0, 180), 0), true, 0.04)
		var wood_spawned_b := _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], log_b_name, wood_pos + Vector3(0.25, 0.04, 0.08), Vector3.ONE * 0.58, Vector3(0, randf_range(0, 180), 0), true, 0.04)
		if not wood_spawned_a or not wood_spawned_b:
			continue
		_mark_world_action_visual(log_a_name)
		_mark_world_action_visual(log_b_name)
		var wood_action = _create_world_action("wood_%d" % i, "wood", "Troncos aprovechables", wood_pos, Vector3(1.9, 0.8, 1.2), Color(0.20, 0.12, 0.055), false, false)
		wood_action.set_meta("visual_name", log_a_name + "|" + log_b_name)
	var stone_bank_segments := [0, 4, 9, 13]
	for i in range(4):
		var seg: Dictionary = river_segments_data[stone_bank_segments[i % stone_bank_segments.size()]]
		var seg_center: Vector3 = seg["center"]
		var seg_size: Vector2 = seg["size"]
		var seg_angle := deg_to_rad(float(seg["yaw"]))
		var seg_along := Vector3(cos(seg_angle), 0.0, -sin(seg_angle))
		var seg_across := Vector3(sin(seg_angle), 0.0, cos(seg_angle))
		var end_sign := 1.0 if i < 2 else -1.0
		var along_off := seg_along * (seg_size.x * 0.5 - randf_range(1.2, 3.0)) * end_sign
		var bank_dist := seg_size.y * 0.5 + randf_range(0.7, 1.4)
		var pos_in := seg_center + along_off + seg_across * bank_dist
		var pos_out := seg_center + along_off - seg_across * bank_dist
		# Place on the land side that is closer to the map centre (playable interior).
		var stone_pos: Vector3 = pos_in if Vector2(pos_in.x, pos_in.z).length() < Vector2(pos_out.x, pos_out.z).length() else pos_out
		stone_pos.y = 0.04
		var stone_visual_name := "StonePickup_%d" % i
		if not _try_instance_external_scene([SURVIVAL_TOOL_MODELS["stone"]], stone_visual_name, stone_pos, Vector3.ONE * randf_range(0.65, 0.92), Vector3(0, randf_range(0, 180), 0), true, 0.04):
			continue
		_mark_world_action_visual(stone_visual_name)
		var stone_action = _create_world_action("stone_%d" % i, "stone", "Piedras utiles", stone_pos, Vector3(1.2, 0.75, 1.1), Color(0.31, 0.30, 0.26), false, false)
		stone_action.set_meta("visual_name", stone_visual_name)
		# Cover the pile with grass tufts so it blends into the river bank.
		for g in range(5 + randi() % 4):
			var grass_pos := stone_pos + seg_along * randf_range(-0.95, 0.95) + seg_across * randf_range(-0.30, 0.95)
			grass_pos.y = 0.05
			_create_grass_clump(grass_pos, randf_range(0.85, 1.45), Color(0.13, 0.30, 0.09).lerp(Color(0.34, 0.42, 0.13), randf()))
	_create_world_action("fish_north", "fish", "Zona de pesca", Vector3(-35, 0.05, -57), Vector3(2.8, 0.7, 1.6), Color(0.09, 0.16, 0.14), true, false)
	_create_world_action("fish_south", "fish", "Zona de pesca", Vector3(22, 0.05, 64), Vector3(2.8, 0.7, 1.6), Color(0.09, 0.16, 0.14), true, false)
	_create_world_action("hunt_trail", "hunt", "Rastro de animal", Vector3(-50, 0.04, 28), Vector3(1.8, 0.65, 1.2), Color(0.16, 0.11, 0.055), true, false)
	_create_tool_pickup("axe_pickup", "axe_tool", "Hacha vieja", SURVIVAL_TOOL_MODELS["axe"], Vector3(-48.2, 0.05, 43.0), 0.9, Vector3(0, -25, 78))
	_create_tool_pickup("hoe_pickup", "hoe_tool", "Azada vieja", SURVIVAL_TOOL_MODELS["hoe"], Vector3(-50.1, 0.05, 44.4), 0.9, Vector3(0, 32, 78))
	_create_tool_pickup("shovel_pickup", "shovel_tool", "Pala vieja", SURVIVAL_TOOL_MODELS["shovel"], Vector3(-52.0, 0.05, 43.5), 0.9, Vector3(0, 12, 78))
	_create_tool_pickup("hammer_pickup", "hammer_tool", "Martillo viejo", SURVIVAL_TOOL_MODELS["hammer"], Vector3(-49.0, 0.05, 46.1), 0.88, Vector3(0, -44, 82))
	_create_tool_pickup("pickaxe_pickup", "pickaxe_tool", "Pico viejo", SURVIVAL_TOOL_MODELS["pickaxe"], Vector3(-53.2, 0.05, 45.3), 0.9, Vector3(0, 18, 82))
	_create_backpack_pickup("small_backpack_pickup", Vector3(9.5, 0.05, 3.5))
	_create_loose_survival_pickups()
	for i in range(4):
		var plot_pos := Vector3(-58.0 + float(i % 2) * 2.7, 0.045, 40.5 + float(i / 2) * 2.5)
		_create_world_action("farm_plot_%d" % i, "farm_plot", "Parcela de cultivo", plot_pos, Vector3(2.0, 0.16, 1.8), Color(0.20, 0.12, 0.055), true, true)
	for i in range(10):
		var tree_pos := Vector3(randf_range(-66, -28), 0.0, randf_range(16, 62))
		if not _can_place_ground_vegetation(tree_pos, 3.2):
			continue
		_create_choppable_tree("fell_tree_%d" % i, tree_pos)

func _create_river_drink_zones() -> void:
	var segments := _default_river_segments()
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		var center: Vector3 = seg["center"]
		var size: Vector2 = seg["size"]
		var yaw: float = float(seg["yaw"])
		var zone_size := Vector3(size.x + 2.0, 0.5, size.y + 2.0)
		var action = _create_world_action(
			"drink_%d" % i, "drink_water", "Orilla del rio",
			center, zone_size, Color(0.08, 0.22, 0.48, 0.0), true, false
		)
		if action != null:
			action.rotation_degrees.y = yaw
			action.disable_collision()

func _create_wildlife() -> void:
	_create_deer_pair([
		Vector3(-35, 0.0, -30),
		Vector3(-35, 0.0, -10),
		Vector3(-35, 0.0, 10),
		Vector3(-35, 0.0, 30),
		Vector3(-20, 0.0, 38),
		Vector3(-15, 0.0, 20),
		Vector3(-15, 0.0, -15),
		Vector3(-25, 0.0, -25)
	])
	_create_deer_pair([
		Vector3(35, 0.0, -30),
		Vector3(35, 0.0, -10),
		Vector3(35, 0.0, 10),
		Vector3(35, 0.0, 30),
		Vector3(20, 0.0, 38),
		Vector3(15, 0.0, 20),
		Vector3(15, 0.0, -15),
		Vector3(25, 0.0, -25)
	])
	_create_deer_pair([
		Vector3(-30, 0.0, -35),
		Vector3(-10, 0.0, -38),
		Vector3(0, 0.0, -40),
		Vector3(10, 0.0, -38),
		Vector3(30, 0.0, -35),
		Vector3(30, 0.0, -20),
		Vector3(10, 0.0, -15),
		Vector3(-10, 0.0, -15),
		Vector3(-30, 0.0, -20)
	])
	_create_wildlife_animal("fox", [
		Vector3(-20, 0.0, 35),
		Vector3(-5, 0.0, 38),
		Vector3(10, 0.0, 35),
		Vector3(20, 0.0, 28),
		Vector3(15, 0.0, 15),
		Vector3(0, 0.0, 12),
		Vector3(-12, 0.0, 20),
		Vector3(-18, 0.0, 28)
	])
	_create_wildlife_animal("fox", [
		Vector3(20, 0.0, 35),
		Vector3(5, 0.0, 38),
		Vector3(-10, 0.0, 35),
		Vector3(-20, 0.0, 28),
		Vector3(-15, 0.0, 15),
		Vector3(0, 0.0, 12),
		Vector3(12, 0.0, 20),
		Vector3(18, 0.0, 28)
	])

func _create_deer_pair(route: Array) -> void:
	var offsets := [Vector3(-2.4, 0.0, -1.6), Vector3(2.4, 0.0, 1.6)]
	for offset in offsets:
		var shifted: Array = []
		for point in route:
			shifted.append((point as Vector3) + offset)
		_create_wildlife_animal("deer", shifted)

func _create_wildlife_animal(kind: String, points: Array) -> void:
	var animal = WildlifeControllerScript.new()
	animal.name = "Wildlife_" + kind
	add_child(animal)
	animal.setup(kind, points)

func _create_world_action(id: String, action_type: String, label: String, pos: Vector3, size: Vector3, color: Color, repeatable: bool, marker_visible := true):
	var action = WorldActionScript.new()
	action.name = "WorldAction_" + id
	action.position = pos
	action.setup(id, action_type, label, size, color, repeatable, marker_visible)
	add_child(action)
	world_actions_by_id[id] = action
	return action

func _create_tool_pickup(id: String, action_type: String, label: String, model_path: String, pos: Vector3, scale_value: float, rot: Vector3) -> void:
	var visual_name := "Pickup_" + id
	var spawned := _try_instance_external_scene([model_path], visual_name, pos, Vector3.ONE * scale_value, rot, true, 0.05)
	if not spawned:
		push_warning("No se crea %s porque falta/carga mal el asset: %s" % [label, model_path])
		return
	var action = _create_world_action(id, action_type, label, pos, Vector3(1.2, 0.75, 1.2), Color(0.10, 0.095, 0.07), false, false)
	action.set_meta("visual_name", visual_name)

func _create_loose_survival_pickups() -> void:
	var Q_WEAPONS := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/"
	var pickups := [
		{"id": "loose_water_0", "name": "Botella de agua", "type": "water", "weight": 0.6, "qty": 1, "use": 38.0, "pos": Vector3(26.4, 0.06, 21.5), "paths": [K_SURVIVAL + "bottle-large.glb", K_SURVIVAL + "bottle.glb"], "color": Color(0.18, 0.32, 0.38)},
		{"id": "loose_water_1", "name": "Botella de agua", "type": "water", "weight": 0.6, "qty": 1, "use": 38.0, "pos": Vector3(35.6, 0.06, -27.2), "paths": [K_SURVIVAL + "bottle-large.glb", K_SURVIVAL + "bottle.glb"], "color": Color(0.18, 0.32, 0.38)},
		{"id": "loose_planks_0", "name": "Madera", "type": "resource", "weight": 0.65, "qty": 2, "use": 0.0, "pos": Vector3(-52.6, 0.06, 49.5), "paths": [SURVIVAL_TOOL_MODELS["planks"], SURVIVAL_TOOL_MODELS["wood"]], "color": Color(0.20, 0.12, 0.055)},
		{"id": "loose_boots_0", "name": "Botas de goma", "type": "clothing", "weight": 1.1, "qty": 1, "use": 0.18, "pos": Vector3(-18.6, 0.06, -11.9), "paths": [POLY_RUBBER_BOOTS_MODEL], "scale": 0.85, "rot": Vector3(0, 25, 0), "color": Color(0.10, 0.12, 0.08)},
		{"id": "loose_gloves_0", "name": "Guantes de trabajo", "type": "clothing", "weight": 0.25, "qty": 1, "use": 0.08, "pos": Vector3(-49.2, 0.06, 41.0), "paths": [POLY_GARDEN_GLOVES_MODEL], "scale": 0.62, "rot": Vector3(0, -20, 0), "color": Color(0.18, 0.14, 0.06)},
		{"id": "loose_hat_0", "name": "Sombrero de pescador", "type": "clothing", "weight": 0.2, "qty": 1, "use": 0.06, "pos": Vector3(-34.2, 0.06, -55.1), "paths": [POLY_FISHERMANS_HAT_MODEL], "scale": 0.68, "rot": Vector3(0, 74, 0), "color": Color(0.20, 0.17, 0.11)},
		{"id": "loose_life_jacket_0", "name": "Chaleco salvavidas", "type": "clothing", "weight": 0.8, "qty": 1, "use": 0.10, "pos": Vector3(17.6, 0.06, 60.2), "paths": [POLY_LIFE_JACKET_MODEL], "scale": 0.72, "rot": Vector3(0, -62, 0), "color": Color(0.55, 0.20, 0.04)},
		{"id": "loose_armor_vest_0", "name": "Chaleco tactico", "type": "clothing", "weight": 1.4, "qty": 1, "use": 0.12, "pos": Vector3(44.0, 0.06, 1.8), "paths": [ROOT_VEST_MODEL], "scale": 0.014, "rot": Vector3(0, 98, 0), "color": Color(0.08, 0.09, 0.07)},
		{"id": "loose_knife_0", "name": "Cuchillo", "type": "weapon", "weight": 0.35, "qty": 1, "use": 0.0, "pos": Vector3(-43.6, 0.06, -39.1), "paths": [Q_WEAPONS + "Knife.gltf"], "scale": 0.55, "rot": Vector3(0, 38, 82), "color": Color(0.20, 0.20, 0.18)},
		{"id": "loose_knife_1", "name": "Cuchillo", "type": "weapon", "weight": 0.35, "qty": 1, "use": 0.0, "pos": Vector3(10.5, 0.06, -15.0), "paths": [Q_WEAPONS + "Knife.gltf"], "scale": 0.55, "rot": Vector3(0, -20, 82), "color": Color(0.20, 0.20, 0.18)},
		{"id": "surv_jacket_0", "name": "Chaqueta survival", "type": "clothing", "weight": 1.6, "qty": 1, "use": 0.22, "pos": Vector3(6.4, 0.06, 3.6), "paths": ["res://assets/characters/adapted/pickup_cloth_torso.glb"], "scale": 0.5, "rot": Vector3(0, 30, 0), "flat": true, "color": Color(0.20, 0.16, 0.10)},
		{"id": "surv_jeans_0", "name": "Vaqueros survival", "type": "clothing", "weight": 1.1, "qty": 1, "use": 0.16, "pos": Vector3(5.2, 0.06, 4.4), "paths": ["res://assets/characters/adapted/pickup_cloth_legs.glb"], "scale": 0.5, "rot": Vector3(0, -15, 0), "flat": true, "color": Color(0.14, 0.18, 0.26)},
		{"id": "surv_gloves_0", "name": "Guantes survival", "type": "clothing", "weight": 0.3, "qty": 1, "use": 0.08, "pos": Vector3(7.1, 0.06, 4.6), "paths": [POLY_GARDEN_GLOVES_MODEL], "scale": 0.55, "rot": Vector3(0, 60, 0), "color": Color(0.16, 0.12, 0.08)},
		{"id": "surv_boots_0", "name": "Botas survival", "type": "clothing", "weight": 1.2, "qty": 1, "use": 0.18, "pos": Vector3(6.0, 0.06, 5.2), "paths": ["res://assets/characters/adapted/pickup_cloth_feet.glb"], "scale": 0.9, "rot": Vector3(0, -40, 0), "flat": true, "color": Color(0.10, 0.09, 0.07)}
	]
	for pickup in pickups:
		_create_pickup_item(pickup)

func _create_pickup_item(data: Dictionary) -> void:
	var id := str(data["id"])
	var item_name := str(data["name"])
	var item_type := str(data["type"])
	var pos: Vector3 = data["pos"]
	var visual_name := "Pickup_" + id
	var paths: Array = data.get("paths", [])
	var color: Color = data.get("color", Color(0.42, 0.38, 0.28))
	var scale_value: float = float(data.get("scale", 0.42))
	var rotation_degrees: Vector3 = data.get("rot", Vector3(0, randf_range(0, 360), 0))
	# Garments baked from the standing T-pose are tipped onto their back so they
	# read as clothing dropped on the ground (rot.x=90, then spun by yaw).
	var lay_flat: bool = bool(data.get("flat", false))
	if lay_flat:
		rotation_degrees.x += 90.0
	var spawned := false
	if not paths.is_empty():
		spawned = _try_instance_external_scene(paths, visual_name, pos, Vector3.ONE * scale_value, rotation_degrees, true, 0.06)
	if not spawned:
		push_warning("No se crea %s porque falta/carga mal el asset .glb" % item_name)
		return
	# The cached ground-snap assumes the mesh is unrotated; after laying a garment
	# flat its real lowest point changes, so re-snap from the actual world AABB.
	if lay_flat:
		var laid := get_node_or_null(NodePath(visual_name))
		if laid is Node3D:
			_snap_node_bottom_to_y(laid as Node3D, 0.06)
	_mark_world_action_visual(visual_name)
	var action_kind := "eat_food" if item_type == "food" else "pickup_item"
	var action = _create_world_action(id, action_kind, item_name, pos, Vector3(1.0, 0.72, 1.0), color, false, false)
	var stored_visual_name := visual_name
	action.set_meta("visual_name", stored_visual_name)
	action.set_meta("item_name", item_name)
	action.set_meta("item_type", item_type)
	action.set_meta("item_weight", float(data.get("weight", 0.1)))
	action.set_meta("item_quantity", int(data.get("qty", 1)))
	action.set_meta("item_use_value", float(data.get("use", 0.0)))

func _mark_world_action_visual(node_name: String) -> void:
	var node := get_node_or_null(NodePath(node_name))
	if node != null:
		node.add_to_group("world_action_visual")

func _create_backpack_pickup(id: String, pos: Vector3) -> void:
	var visual_name := "Pickup_" + id
	if not _try_instance_external_scene([ROOT_BACKPACK_MODEL, SURVIVAL_TOOL_MODELS["backpack"]], visual_name, pos, Vector3.ONE * 1.2, Vector3(0.0, -18.0, 0.0), true, 0.05):
		push_warning("No se crea mochila porque falta/carga mal el asset real.")
		return
	_mark_world_action_visual(visual_name)

	var action = _create_world_action(id, "backpack_pickup", "Mochila pequena", pos, Vector3(1.25, 0.85, 1.25), Color(0.06, 0.075, 0.055), false, false)
	action.set_meta("visual_name", visual_name)

func _create_choppable_tree(id: String, pos: Vector3) -> void:
	var visual_name := "ChoppableTree_" + id
	var collision_name := visual_name + "_Collision"
	var scale_value := Vector3.ONE * randf_range(1.05, 1.75)
	if not _try_instance_external_scene(_shuffled_paths(POLY_TREE_MODELS), visual_name, pos, scale_value, Vector3(0, randf_range(0, 360), 0), true, 0.0):
		if not _try_instance_external_scene(_shuffled_paths(REAL_LIVING_TREE_MODELS), visual_name, pos, scale_value, Vector3(0, randf_range(0, 360), 0), true, 0.0):
			push_warning("No se crea arbol talable %s porque falta/carga mal el asset .glb" % id)
			return
	_override_tree_foliage_green(visual_name)
	var collision := _create_tree_collision(collision_name, pos)
	collision.add_to_group("world_action_visual")
	var action = _create_world_action(id, "fell_tree", "Arbol talable", pos, Vector3(1.35, 3.2, 1.35), Color(0.12, 0.08, 0.035), false, false)
	action.set_meta("visual_name", visual_name)
	action.set_meta("collision_name", collision_name)


func _hide_action_visual(action) -> void:
	var visual_name := str(action.get_meta("visual_name")) if action.has_meta("visual_name") else ""
	var collision_name := str(action.get_meta("collision_name")) if action.has_meta("collision_name") else ""
	if visual_name.is_empty() and collision_name.is_empty():
		return
	var visual_names := visual_name.split("|", false)
	for node in get_tree().get_nodes_in_group("world_action_visual"):
		if not node is Node3D:
			continue
		if not visual_names.is_empty() and visual_names.has(String(node.name)):
			(node as Node3D).visible = false
		if not collision_name.is_empty() and node.name == collision_name:
			node.queue_free()

func handle_world_action(action, actor) -> void:
	match action.action_type:
		"pickup_item":
			var item = ItemScript.create(
				str(action.get_meta("item_name")),
				str(action.get_meta("item_type")),
				float(action.get_meta("item_weight")),
				int(action.get_meta("item_quantity")),
				float(action.get_meta("item_use_value"))
			)
			_finish_pickup_action(action, actor, item, "Recoges %s." % item.item_name)
		"eat_food":
			_play_actor_action(actor, "plant", 1.2)
			var food_value := float(action.get_meta("item_use_value")) if action.has_meta("item_use_value") else 18.0
			actor.stats.hunger = min(actor.stats.max_stat, actor.stats.hunger + food_value)
			actor.stats.changed.emit()
			actor.notice.emit("Comes %s." % str(action.get_meta("item_name")) if action.has_meta("item_name") else "Comes algo.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
		"forage":
			_play_actor_action(actor, "forage", 0.9)
			if not actor.inventory.add_item(ItemScript.create("Bayas silvestres", "food", 0.08, 2, 12.0)):
				return
			_equip_actor_item(actor, "Bayas silvestres")
			if randf() < 0.65:
				actor.inventory.add_item(ItemScript.create("Semillas", "seed", 0.02, 2, 0.0))
			actor.notice.emit("Recolectas bayas silvestres.")
			action.mark_depleted()
			_save_world_change_silent()
		"wood":
			_play_actor_action(actor, "collect", 0.8)
			if not actor.inventory.add_item(ItemScript.create("Tronco", "resource", 1.2, 2, 0.0)):
				return
			_equip_actor_item(actor, "Tronco")
			actor.notice.emit("Recoges troncos para construir.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
		"stone":
			_play_actor_action(actor, "collect", 0.8)
			if not actor.inventory.add_item(ItemScript.create("Piedra", "resource", 0.45, 2, 0.0)):
				return
			_equip_actor_item(actor, "Piedra")
			actor.notice.emit("Recoges piedras utiles.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
		"fish":
			if not actor.inventory.has_item_name("Cuchillo"):
				actor.notice.emit("Necesitas el cuchillo para preparar el pez.")
				return
			_play_actor_action(actor, "fish", 1.6)
			actor.stats.energy = max(0.0, actor.stats.energy - 6.0)
			if randf() < 0.72:
				if actor.inventory.add_item(ItemScript.create("Pez crudo", "food", 0.55, 1, 24.0)):
					_equip_actor_item(actor, "Pez crudo")
					actor.notice.emit("Pescas un pez pequeno.")
			else:
				actor.notice.emit("No pica nada.")
		"drink_water":
			if _drink_hold_actor != null:
				return
			_play_actor_action(actor, "plant", _DRINK_HOLD_TIME)
			_drink_hold_actor = actor
			_drink_hold_timer = 0.0
			actor.notice.emit("Mantén E para beber...")
		"hunt":
			if actor.stats.energy < 14.0:
				actor.notice.emit("Estas demasiado cansado para cazar.")
				return
			_play_actor_action(actor, "interact", 1.0)
			actor.stats.energy = max(0.0, actor.stats.energy - 14.0)
			if randf() < 0.48:
				if actor.inventory.add_item(ItemScript.create("Carne cruda", "food", 0.75, 1, 30.0)):
					_equip_actor_item(actor, "Carne cruda")
					actor.notice.emit("Sigues el rastro y consigues carne.")
			else:
				actor.notice.emit("El animal escapa entre la maleza.")
		"coat":
			_finish_pickup_action(action, actor, ItemScript.create("Chaqueta de abrigo", "clothing", 1.1, 1, 0.65), "Encuentras una chaqueta vieja. Usala desde el inventario.")
		"axe_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Hacha", "tool_axe", 1.2, 1, 0.0), "Recoges un hacha. Ya puedes talar arboles.")
		"hoe_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Azada", "tool_hoe", 0.9, 1, 0.0), "Recoges una azada para cultivar.")
		"shovel_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Pala", "tool_shovel", 1.0, 1, 0.0), "Recoges una pala.")
		"hammer_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Martillo", "tool_hammer", 1.0, 1, 0.0), "Recoges un martillo.")
		"pickaxe_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Pico", "tool_pickaxe", 1.35, 1, 0.0), "Recoges un pico.")
		"backpack_pickup":
			_play_actor_action(actor, "pickup", 0.3)
			if not actor.inventory.add_item(ItemScript.create("Mochila pequena", "backpack", 0.8, 1, 0.0)):
				return
			if actor.has_method("equip_backpack"):
				actor.equip_backpack("Mochila pequena")
			elif actor.has_method("_sync_held_item"):
				actor._sync_held_item()
			actor.notice.emit("Recoges una mochila pequena. Puedes cargar mas.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
		"farm_plot":
			_handle_farm_plot(action, actor)
		"fell_tree":
			if not actor.inventory.has_item_name("Hacha"):
				actor.notice.emit("Necesitas un hacha para talar este arbol.")
				return
			if actor.stats.energy < 10.0:
				actor.notice.emit("Estas demasiado cansado para talar.")
				return
			_play_actor_action(actor, "chop", 1.1)
			if audio_system != null and audio_system.has_method("play_chop_at"):
				audio_system.play_chop_at(action.position)
			if not actor.inventory.add_item(ItemScript.create("Tronco", "resource", 1.2, 3, 0.0)):
				return
			_equip_actor_item(actor, "Tronco")
			actor.stats.energy = max(0.0, actor.stats.energy - 10.0)
			_hide_action_visual(action)
			actor.inventory.add_item(ItemScript.create("Madera", "resource", 0.65, 1, 0.0))
			if randf() < 0.45:
				actor.inventory.add_item(ItemScript.create("Ramas", "resource", 0.18, 3, 0.0))
			_create_cut_tree_remains(action.position)
			actor.notice.emit("Talas el arbol y consigues troncos.")
			action.mark_depleted()
			_save_world_change_silent()
		"build_cabin":
			if not actor.inventory.has_item_name("Tronco", 6) or not actor.inventory.has_item_name("Piedra", 4):
				actor.notice.emit("Faltan materiales: 6 troncos y 4 piedra.")
				return
			_play_actor_action(actor, "interact", 1.2)
			actor.inventory.consume_item_name("Tronco", 6)
			actor.inventory.consume_item_name("Piedra", 4)
			_build_player_cabin(action.position)
			actor.notice.emit("Levantas una cabana basica. Ya tienes un refugio propio.")
			action.mark_depleted()
			_save_world_change_silent()

func _play_actor_action(actor, action_name: String, duration: float) -> void:
	if actor != null and actor.has_method("play_action_animation"):
		actor.play_action_animation(action_name, duration)

func _equip_actor_item(actor, item_name: String) -> void:
	if actor != null and actor.has_method("equip_item_by_name"):
		actor.equip_item_by_name(item_name)

func _finish_pickup_action(action, actor, item, message: String, action_name := "pickup", duration := 0.8, hide_visual := true) -> void:
	_play_actor_action(actor, action_name, duration)
	if not actor.inventory.add_item(item):
		return
	if str(item.item_type) == "clothing" and actor.has_method("equip_clothing"):
		actor.equip_clothing(item.item_name)
	else:
		_equip_actor_item(actor, item.item_name)
	if actor.has_method("refresh_carry_capacity"):
		actor.refresh_carry_capacity()
	actor.notice.emit(message)
	if hide_visual:
		_hide_action_visual(action)
	action.mark_depleted()
	_save_world_change_silent()

func _handle_farm_plot(action, actor) -> void:
	match action.action_state:
		"planted":
			actor.notice.emit("El cultivo aun esta creciendo.")
		"ready":
			_play_actor_action(actor, "plant", 1.25)
			if not actor.inventory.add_item(ItemScript.create("Verduras", "food", 0.22, 3, 16.0)):
				return
			_equip_actor_item(actor, "Verduras")
			if randf() < 0.55:
				actor.inventory.add_item(ItemScript.create("Semillas", "seed", 0.02, 1, 0.0))
			action.set_crop_state("empty", 0.0)
			actor.notice.emit("Cosechas verduras y recuperas algunas semillas.")
			_save_world_change_silent()
		_:
			if not actor.inventory.has_item_name("Azada") and not actor.inventory.has_item_name("Pala"):
				actor.notice.emit("Necesitas una azada o una pala para preparar la tierra.")
				return
			if not actor.inventory.consume_item_name("Semillas", 1):
				actor.notice.emit("Necesitas semillas. Recolecta bayas o busca comida.")
				return
			_play_actor_action(actor, "plant", 1.35)
			actor.stats.energy = max(0.0, actor.stats.energy - 5.0)
			action.set_crop_state("planted", 0.0)
			actor.notice.emit("Plantas semillas. Vuelve cuando hayan crecido.")
			_save_world_change_silent()

func _build_player_cabin(origin: Vector3) -> void:
	_create_static_box("PlayerCabinFloor", origin + Vector3(0, 0.02, 0), Vector3(4.4, 0.22, 3.4), Color(0.16, 0.10, 0.045))
	_create_static_box("PlayerCabinBack", origin + Vector3(0, 0, -1.7), Vector3(4.4, 2.4, 0.22), Color(0.20, 0.13, 0.06))
	_create_static_box("PlayerCabinLeft", origin + Vector3(-2.2, 0, 0), Vector3(0.22, 2.4, 3.4), Color(0.18, 0.11, 0.05))
	_create_static_box("PlayerCabinRight", origin + Vector3(2.2, 0, 0), Vector3(0.22, 2.4, 3.4), Color(0.18, 0.11, 0.05))
	_create_static_box("PlayerCabinFrontA", origin + Vector3(-1.45, 0, 1.7), Vector3(1.5, 2.4, 0.22), Color(0.19, 0.12, 0.055))
	_create_static_box("PlayerCabinFrontB", origin + Vector3(1.45, 0, 1.7), Vector3(1.5, 2.4, 0.22), Color(0.19, 0.12, 0.055))
	_create_visual_gable_roof("PlayerCabinRoof", origin + Vector3(0, 2.45, 0), 4.9, 3.9, 1.0, Color(0.10, 0.065, 0.035))

func _create_quaternius_environment_props() -> void:
	_spawn_external(Q_ENV + "WaterTower.gltf", "QWaterTower", Vector3(-43, 0, -48), Vector3.ONE, Vector3.ZERO, Vector3(2.0, 7.0, 2.0))
	_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightA", Vector3(3.0, 0, -22), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
	_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightB", Vector3(3.0, 0, 14), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
	_spawn_external(Q_ENV + "TrafficLight_1.gltf", "QTrafficLight", Vector3(13.0, 0, -5.0), Vector3.ONE, Vector3(0, 180, 0), Vector3(0.6, 3.5, 0.6))
	_spawn_external(Q_ENV + "TownSign.gltf", "QTownSign", Vector3(14.8, 0, -28.5), Vector3.ONE, Vector3(0, 180, 0), Vector3(1.6, 1.8, 0.5))
	_spawn_external(Q_ENV + "TrafficBarrier_1.gltf", "QBarrierA", Vector3(6.0, 0, -4.2), Vector3.ONE, Vector3(0, 18, 0), Vector3(2.2, 1.0, 0.6))
	_spawn_external(Q_ENV + "TrafficBarrier_2.gltf", "QBarrierB", Vector3(10.4, 0, -2.8), Vector3.ONE, Vector3(0, -14, 0), Vector3(2.2, 1.0, 0.6))
	for i in range(8):
		var pos := Vector3(randf_range(3.5, 13.2), 0, randf_range(-54, 52))
		_spawn_external(Q_ENV + ("TrafficCone_1.gltf" if i % 2 == 0 else "TrafficCone_2.gltf"), "QTrafficCone", pos, Vector3.ONE, Vector3(0, randf_range(0, 360), 0), Vector3(0.35, 0.7, 0.35))
	for i in range(12):
		var pos := Vector3(randf_range(-58, 58), 0, randf_range(-58, 58))
		if abs(pos.x - 8.0) < 5.0:
			pos.x += 8.0
		var prop_names := ["TrashBag_1.gltf", "TrashBag_2.gltf", "Pallet_Broken.gltf", "Wheel.gltf", "Wheels_Stack.gltf", "Barrel.gltf"]
		var path: String = Q_ENV + str(prop_names[i % prop_names.size()])
		_spawn_external(path, "QWorldProp", pos, Vector3.ONE, Vector3(0, randf_range(0, 360), 0), Vector3(1.0, 1.0, 1.0))

func _create_terrain_variation() -> void:
	for i in range(26):
		var rock_pos := Vector3(randf_range(-70, 70), 0.04, randf_range(-70, 70))
		if not _can_place_ground_vegetation(rock_pos, 1.6):
			continue
		var rock_scale := randf_range(0.7, 1.35)
		if _try_instance_external_scene(_shuffled_paths(REAL_ROCK_MODELS), "RealRock", rock_pos, Vector3.ONE * rock_scale, Vector3(0, randf_range(0, 360), 0), true, 0.0):
			pass
		else:
			_create_polyhaven_boulder(rock_pos, Vector3(randf_range(0.32, 0.74), randf_range(0.16, 0.34), randf_range(0.28, 0.62)))
	for i in range(16):
		var boulder_pos := Vector3(randf_range(-68, 68), 0.04, randf_range(-68, 68))
		if not _can_place_ground_vegetation(boulder_pos, 1.8):
			continue
		_create_polyhaven_boulder(boulder_pos, Vector3(randf_range(0.7, 1.7), randf_range(0.35, 0.8), randf_range(0.6, 1.5)))

func _create_mountain_backdrop() -> void:
	var mountain_color := Color(0.19, 0.20, 0.18)
	var shadow_color := Color(0.11, 0.12, 0.11)
	var snow_color := Color(0.70, 0.72, 0.68)
	var ridges := [
		{"center": Vector3(-58, -0.35, -82), "count": 7, "step": Vector3(18, 0, 0), "yaw": 4.0},
		{"center": Vector3(58, -0.35, -82), "count": 7, "step": Vector3(18, 0, 0), "yaw": -5.0},
		{"center": Vector3(-86, -0.35, -38), "count": 6, "step": Vector3(0, 0, 20), "yaw": 88.0},
		{"center": Vector3(86, -0.35, -34), "count": 6, "step": Vector3(0, 0, 20), "yaw": -88.0},
		{"center": Vector3(-38, -0.35, 84), "count": 5, "step": Vector3(22, 0, 0), "yaw": 184.0},
		{"center": Vector3(54, -0.35, 84), "count": 5, "step": Vector3(22, 0, 0), "yaw": 176.0}
	]
	for ridge in ridges:
		var center: Vector3 = ridge["center"]
		var count: int = int(ridge["count"])
		var step: Vector3 = ridge["step"]
		var yaw: float = float(ridge["yaw"])
		for i in range(count):
			var offset := step * (float(i) - float(count - 1) * 0.5)
			var pos := center + offset + Vector3(randf_range(-4.0, 4.0), 0.0, randf_range(-3.0, 3.0))
			var peak_height := randf_range(12.0, 25.0)
			var radius_x := randf_range(13.0, 23.0)
			var radius_z := randf_range(9.0, 17.0)
			var base_color := shadow_color.lerp(mountain_color, randf_range(0.35, 0.95))
			_create_mountain_peak("MountainPeak", pos, radius_x, radius_z, peak_height, yaw + randf_range(-14.0, 14.0), base_color)
			if peak_height > 18.0:
				_create_mountain_peak("MountainSnowCap", pos + Vector3(0, peak_height * 0.58, 0), radius_x * 0.28, radius_z * 0.24, peak_height * 0.22, yaw, snow_color)
	_create_rocky_foothills()

func _create_rocky_foothills() -> void:
	for i in range(70):
		var side := randi() % 4
		var pos := Vector3.ZERO
		match side:
			0:
				pos = Vector3(randf_range(-74, 74), 0.04, randf_range(-74, -61))
			1:
				pos = Vector3(randf_range(-74, 74), 0.04, randf_range(61, 74))
			2:
				pos = Vector3(randf_range(-74, -61), 0.04, randf_range(-74, 74))
			_:
				pos = Vector3(randf_range(61, 74), 0.04, randf_range(-74, 74))
		if not _can_place_ground_vegetation(pos, 1.8):
			continue
		var rock_scale := randf_range(1.0, 2.4)
		if _try_instance_external_scene(_shuffled_paths(REAL_ROCK_MODELS), "FoothillRock", pos, Vector3.ONE * rock_scale, Vector3(0, randf_range(0, 360), 0), true, 0.0):
			continue
		_create_polyhaven_boulder(pos, Vector3(randf_range(0.8, 2.1), randf_range(0.25, 0.8), randf_range(0.7, 1.9)))

func _create_polyhaven_boulder(pos: Vector3, scale_value: Vector3) -> void:
	if abs(pos.x - 8.0) < 5.4 or _is_in_no_grass_area(pos, 1.4):
		return
	var base_color := Color(0.26, 0.24, 0.20)
	var rock_texture := POLY_ROCK_07_DIFF if randf() < 0.55 else POLY_BOULDER_DIFF
	_create_textured_visual_sphere("PolyhavenBoulder", pos + Vector3(0, scale_value.y * 0.55, 0), scale_value, rock_texture, base_color)
	if randf() < 0.45:
		_create_textured_visual_sphere("PolyhavenBoulderLobe", pos + Vector3(scale_value.x * randf_range(-0.35, 0.35), scale_value.y * 0.42, scale_value.z * randf_range(-0.35, 0.35)), scale_value * Vector3(randf_range(0.45, 0.72), randf_range(0.45, 0.72), randf_range(0.45, 0.72)), rock_texture, base_color.darkened(0.05))
	if scale_value.x > 0.65 or scale_value.z > 0.65:
		_create_invisible_collision_box("PolyhavenBoulderCollision", pos, Vector3(max(scale_value.x, 0.6), max(scale_value.y, 0.35), max(scale_value.z, 0.6)))

func _create_mountain_river() -> void:
	var segments := _default_river_segments()
	river_segments_data = segments.duplicate(true)
	for segment in segments:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = float(segment["yaw"])
		_create_river_segment(center, size, yaw)
		_decorate_river_area(center, size, yaw)
		_create_dense_river_bank_vegetation(center, size, yaw)
		_create_river_seam_cover(center, size, yaw)
		if randf() < 0.72:
			_create_fish_school(center, size, yaw)

func _default_river_segments() -> Array:
	return [
		{"center": Vector3(-60, 0.085, -58), "size": Vector2(25, 6), "yaw": -8.0},
		{"center": Vector3(-36, 0.085, -61), "size": Vector2(25, 6), "yaw": 5.0},
		{"center": Vector3(-12, 0.085, -58), "size": Vector2(25, 5.5), "yaw": -6.0},
		{"center": Vector3(16, 0.085, -61), "size": Vector2(30, 6.5), "yaw": 4.0},
		{"center": Vector3(47, 0.085, -59), "size": Vector2(27, 6.5), "yaw": -7.0},
		{"center": Vector3(63, 0.085, -36), "size": Vector2(25, 6), "yaw": 86.0},
		{"center": Vector3(66, 0.085, -10), "size": Vector2(25, 6.5), "yaw": 93.0},
		{"center": Vector3(63, 0.085, 18), "size": Vector2(29, 6), "yaw": 88.0},
		{"center": Vector3(65, 0.085, 47), "size": Vector2(27, 6.5), "yaw": 94.0},
		{"center": Vector3(40, 0.085, 64), "size": Vector2(29, 6), "yaw": 176.0},
		{"center": Vector3(10, 0.085, 66), "size": Vector2(30, 6.5), "yaw": 184.0},
		{"center": Vector3(-21, 0.085, 63), "size": Vector2(30, 6), "yaw": 178.0},
		{"center": Vector3(-52, 0.085, 65), "size": Vector2(27, 6.5), "yaw": 186.0},
		{"center": Vector3(-66, 0.085, 42), "size": Vector2(27, 6), "yaw": 92.0},
		{"center": Vector3(-63, 0.085, 15), "size": Vector2(26, 6), "yaw": 85.0},
		{"center": Vector3(-66, 0.085, -14), "size": Vector2(30, 6.5), "yaw": 93.0},
		{"center": Vector3(-64, 0.085, -40), "size": Vector2(25, 6), "yaw": 88.0}
	]

func get_river_segments_for_minimap() -> Array:
	return _default_river_segments()

func get_structures_for_minimap() -> Array:
	return [
		{"pos": Vector3(-25, 0, -18), "color": Color(0.5, 0.4, 0.3)},
		{"pos": Vector3(-38, 0, 18), "color": Color(0.5, 0.4, 0.3)},
		{"pos": Vector3(23, 0, 18), "color": Color(0.5, 0.4, 0.3)},
		{"pos": Vector3(42, 0, 26), "color": Color(0.5, 0.4, 0.3)},
		{"pos": Vector3(-12, 0, 42), "color": Color(0.5, 0.4, 0.3)},
		{"pos": Vector3(-42, 0, -42), "color": Color(0.3, 0.5, 0.6)},
		{"pos": Vector3(-54, 0, 48), "color": Color(0.4, 0.3, 0.2)}
	]

func get_river_depth_at(world_pos: Vector3) -> float:
	for segment in river_segments_data:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = float(segment["yaw"])
		var angle := deg_to_rad(yaw)
		var along := Vector3(cos(angle), 0.0, -sin(angle))
		var across := Vector3(sin(angle), 0.0, cos(angle))
		var offset := world_pos - center
		var local_forward := offset.dot(along)
		var local_side := offset.dot(across)
		var half_length := size.x * 0.5
		var half_width := size.y * 0.5
		if absf(local_forward) <= half_length and absf(local_side) <= half_width:
			var side_depth: float = 1.0 - absf(local_side) / max(0.01, half_width)
			var length_depth: float = 1.0 - absf(local_forward) / max(0.01, half_length)
			return clamp(min(side_depth, length_depth) * 1.65, 0.18, 1.0)
	return 0.0

func get_nearest_river_audio_point(world_pos: Vector3) -> Dictionary:
	var best_pos := Vector3.ZERO
	var best_distance := 999999.0
	for segment in river_segments_data:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = float(segment["yaw"])
		var angle := deg_to_rad(yaw)
		var along := Vector3(cos(angle), 0.0, -sin(angle))
		var across := Vector3(sin(angle), 0.0, cos(angle))
		var offset := world_pos - center
		var local_forward: float = clamp(offset.dot(along), -size.x * 0.5, size.x * 0.5)
		var local_side: float = clamp(offset.dot(across), -size.y * 0.5, size.y * 0.5)
		var candidate := center + along * local_forward + across * local_side
		candidate.y = 0.20
		var distance := Vector2(world_pos.x - candidate.x, world_pos.z - candidate.z).length()
		if distance < best_distance:
			best_distance = distance
			best_pos = candidate
	return {
		"position": best_pos,
		"distance": best_distance
	}

func get_forest_audio_point(world_pos: Vector3) -> Dictionary:
	var forest_center := Vector3(-43.0, 0.0, 31.0)
	var distance := Vector2(world_pos.x - forest_center.x, world_pos.z - forest_center.z).length()
	return {
		"position": forest_center,
		"distance": distance
	}

func _create_river_segment(center: Vector3, size: Vector2, yaw: float) -> void:
	var mesh_instance = RiverWaterScript.new()
	mesh_instance.name = "MountainRiverWater"
	mesh_instance.position = center
	mesh_instance.rotation_degrees = Vector3(0, yaw, 0)
	mesh_instance.mesh = _make_irregular_river_mesh(size)
	mesh_instance.material_override = _make_river_water_material()
	mesh_instance.add_to_group("river_water")
	add_child(mesh_instance)
	_create_river_edge_blend(center, size, yaw)
	_create_river_end_blend(center, size, yaw)

func _make_irregular_river_mesh(size: Vector2) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var length_steps := 18
	var width_steps := 8
	var half_length: float = size.x * 0.5
	var half_width: float = size.y * 0.5
	var previous_left: float = -half_width
	var previous_right: float = half_width
	for i in range(length_steps + 1):
		var t: float = float(i) / float(length_steps)
		var base_x: float = lerp(-half_length, half_length, t)
		var edge_strength: float = sin(t * PI)
		var left_edge: float = -half_width + randf_range(-0.52, 0.36) * (0.35 + edge_strength)
		var right_edge: float = half_width + randf_range(-0.36, 0.52) * (0.35 + edge_strength)
		left_edge = lerp(previous_left, left_edge, 0.55)
		right_edge = lerp(previous_right, right_edge, 0.55)
		previous_left = left_edge
		previous_right = right_edge
		var end_round: float = pow(1.0 - edge_strength, 2.0)
		var end_side: float = -1.0 if t < 0.5 else 1.0
		for j in range(width_steps + 1):
			var s: float = float(j) / float(width_steps)
			var side_curve: float = pow(absf(s - 0.5) * 2.0, 2.0)
			var x: float = base_x - end_side * side_curve * end_round * half_width * 0.62
			var z: float = lerp(left_edge, right_edge, s)
			z += sin(t * PI * 4.0 + s * TAU) * 0.08 * edge_strength
			vertices.append(Vector3(x, 0.0, z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(t * 2.4, s))
	for i in range(length_steps):
		for j in range(width_steps):
			var base := i * (width_steps + 1) + j
			var next := base + width_steps + 1
			indices.append(base)
			indices.append(base + 1)
			indices.append(next)
			indices.append(base + 1)
			indices.append(next + 1)
			indices.append(next)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _create_river_edge_blend(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		for i in range(58):
			var edge_pos: Vector3 = center + along * randf_range(-size.x * 0.53, size.x * 0.53) + across * side * randf_range(size.y * 0.42, size.y * 0.86)
			edge_pos.y = 0.041 + randf_range(0.0, 0.006)
			if not _can_place_ground_vegetation(edge_pos, -1.0):
				continue
			if i % 2 == 0:
				_create_river_pebble_cluster(edge_pos, along, across, side)
			if randf() < 0.94:
				var grass_pos: Vector3 = edge_pos + across * side * randf_range(0.10, 1.15) + along * randf_range(-0.70, 0.70)
				grass_pos.y = 0.052
				_create_grass_clump(grass_pos, randf_range(0.92, 1.68), Color(0.13, 0.30, 0.09).lerp(Color(0.36, 0.44, 0.12), randf()))
			if randf() < 0.68:
				var reed_pos: Vector3 = edge_pos + across * side * randf_range(0.18, 1.05)
				reed_pos.y = 0.052
				_create_river_reed_cluster(reed_pos, randf_range(1.15, 2.05), side)

func _create_river_end_blend(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for end_value in [-1.0, 1.0]:
		var end: float = end_value
		for i in range(72):
			var side := -1.0 if randf() < 0.5 else 1.0
			var cap_pos: Vector3 = center + along * end * randf_range(size.x * 0.36, size.x * 0.66) + across * randf_range(-size.y * 0.92, size.y * 0.92)
			cap_pos += across * side * randf_range(0.0, 0.68)
			cap_pos.y = 0.052
			if not _can_place_ground_vegetation(cap_pos, -1.0):
				continue
			if i % 6 == 0:
				_create_polyhaven_boulder(cap_pos + across * side * randf_range(0.15, 0.55), Vector3(randf_range(0.30, 0.78), randf_range(0.12, 0.36), randf_range(0.30, 0.78)))
			elif i % 3 == 0:
				_create_river_pebble_cluster(cap_pos, along, across, side)
			else:
				_create_river_reed_cluster(cap_pos, randf_range(1.25, 2.25), side)
				_create_grass_clump(cap_pos + along * end * randf_range(0.05, 0.95), randf_range(1.05, 1.85), Color(0.13, 0.30, 0.09).lerp(Color(0.32, 0.40, 0.13), randf()))
		for corner_side in [-1.0, 1.0]:
			var corner_center: Vector3 = center + along * end * size.x * 0.50 + across * corner_side * size.y * 0.50
			corner_center.y = 0.052
			for j in range(15):
				var corner_pos: Vector3 = corner_center + along * end * randf_range(-0.85, 1.15) + across * corner_side * randf_range(-0.35, 1.15)
				if not _can_place_ground_vegetation(corner_pos, -1.0):
					continue
				_create_river_pebble_cluster(corner_pos, along, across, corner_side)
				if randf() < 0.82:
					_create_river_reed_cluster(corner_pos + across * corner_side * randf_range(0.15, 0.55), randf_range(1.15, 1.95), corner_side)

func _create_river_seam_cover(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for end_value in [-1.0, 1.0]:
		var end: float = end_value
		var seam_center: Vector3 = center + along * end * size.x * 0.50
		for i in range(44):
			var side := -1.0 if i % 2 == 0 else 1.0
			var seam_pos: Vector3 = seam_center + across * randf_range(-size.y * 0.58, size.y * 0.58) + along * end * randf_range(-0.35, 1.20)
			seam_pos.y = 0.054
			if not _can_place_ground_vegetation(seam_pos, -1.0):
				continue
			if i % 4 == 0:
				_create_polyhaven_boulder(seam_pos + across * side * randf_range(0.0, 0.45), Vector3(randf_range(0.24, 0.62), randf_range(0.10, 0.28), randf_range(0.24, 0.62)))
			elif i % 3 == 0:
				_create_river_pebble_cluster(seam_pos, along, across, side)
			else:
				_create_river_reed_cluster(seam_pos + across * side * randf_range(0.05, 0.50), randf_range(1.35, 2.35), side)
				_create_grass_clump(seam_pos + along * end * randf_range(0.0, 0.75), randf_range(1.10, 1.95), Color(0.12, 0.28, 0.08).lerp(Color(0.34, 0.43, 0.13), randf()))

func _create_river_pebble_cluster(pos: Vector3, along: Vector3, across: Vector3, side: float) -> void:
	for i in range(3 + randi() % 4):
		var pebble_pos: Vector3 = pos + along * randf_range(-0.65, 0.65) + across * side * randf_range(-0.22, 0.56)
		pebble_pos.y = 0.055
		var pebble_scale: Vector3 = Vector3(randf_range(0.12, 0.34), randf_range(0.035, 0.09), randf_range(0.10, 0.30))
		var texture_path: String = POLY_RIVER_PEBBLES_DIFF if randf() < 0.62 else POLY_ROCK_07_DIFF
		_create_textured_visual_sphere("RiverPebbleClusterStone", pebble_pos, pebble_scale, texture_path, Color(0.30, 0.29, 0.25))

func _create_fish_school(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	var count := 2 + randi() % 3
	for i in range(count):
		var fish = FishControllerScript.new()
		fish.name = "RiverFish"
		var fish_center := center + along * randf_range(-size.x * 0.36, size.x * 0.36) + across * randf_range(-size.y * 0.22, size.y * 0.22)
		fish_center.y = center.y + 0.035
		fish.setup(fish_center, along, across, randf_range(size.x * 0.22, size.x * 0.55), randf_range(size.y * 0.18, size.y * 0.45))
		add_child(fish)

func _decorate_river_area(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for i in range(38):
		var side := -1.0 if i % 2 == 0 else 1.0
		var bank_pos := center + along * randf_range(-size.x * 0.48, size.x * 0.48) + across * side * randf_range(size.y * 0.54, size.y * 1.08)
		bank_pos.y = 0.045
		if not _can_place_ground_vegetation(bank_pos, -1.0):
			continue
		if i % 5 == 0:
			_create_polyhaven_boulder(bank_pos, Vector3(randf_range(0.35, 1.15), randf_range(0.18, 0.55), randf_range(0.35, 1.05)))
		elif i % 5 == 1:
			_create_river_pebble_cluster(bank_pos, along, across, side)
		else:
			_create_river_reed_cluster(bank_pos, randf_range(0.75, 1.35), side)
			_create_grass_clump(bank_pos + along * randf_range(-0.55, 0.55) + across * side * randf_range(0.25, 0.75), randf_range(0.62, 1.05), Color(0.14, 0.29, 0.10).lerp(Color(0.34, 0.42, 0.14), randf()))
		if randf() < 0.45:
			var pebble_pos := center + along * randf_range(-size.x * 0.48, size.x * 0.48) + across * side * randf_range(size.y * 0.35, size.y * 0.72)
			pebble_pos.y = 0.041
			_create_river_pebble_cluster(pebble_pos, along, across, side)
	for i in range(28):
		var side := -1.0 if i % 2 == 0 else 1.0
		var plant_pos := center + along * randf_range(-size.x * 0.48, size.x * 0.48) + across * side * randf_range(size.y * 0.82, size.y * 1.55)
		plant_pos.y = 0.05
		if _can_place_ground_vegetation(plant_pos, -1.0):
			_create_river_reed_cluster(plant_pos, randf_range(0.85, 1.55), side)
			if randf() < 0.35:
				_create_bush(plant_pos + across * side * randf_range(0.4, 1.2), randf_range(0.45, 0.72))

func _create_dense_river_bank_vegetation(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		for i in range(54):
			var bank_pos := center + along * randf_range(-size.x * 0.56, size.x * 0.56) + across * side * randf_range(size.y * 0.58, size.y * 1.50)
			bank_pos.y = 0.052
			if not _can_place_ground_vegetation(bank_pos, -1.0):
				continue
			_create_grass_clump(bank_pos, randf_range(0.95, 1.85), Color(0.14, 0.31, 0.09))
			if randf() < 0.62:
				_create_river_reed_cluster(bank_pos + along * randf_range(-0.75, 0.75), randf_range(1.15, 2.20), side)
			if randf() < 0.28:
				_create_bush(bank_pos + across * side * randf_range(0.25, 0.9), randf_range(0.44, 0.74))

func _create_mountain_peak(node_name: String, pos: Vector3, radius_x: float, radius_z: float, height: float, yaw: float, color: Color) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 18
	var rings := 5
	var ring_points: Array = []
	for r in range(rings + 1):
		var t := float(r) / float(rings)
		var ring_radius_x := radius_x * (1.0 - t)
		var ring_radius_z := radius_z * (1.0 - t)
		var y := height * pow(t, 0.85)
		var points := []
		for s in range(segments):
			var angle := TAU * float(s) / float(segments)
			var noise := randf_range(0.78, 1.18)
			var slope_cut := 1.0 - 0.18 * sin(angle * 3.0 + radius_x)
			var x := cos(angle) * ring_radius_x * noise * slope_cut
			var z := sin(angle) * ring_radius_z * noise
			points.append(Vector3(x, y, z))
		ring_points.append(points)
	for r in range(rings):
		var current: Array = ring_points[r]
		var next: Array = ring_points[r + 1]
		for s in range(segments):
			var a: Vector3 = current[s]
			var b: Vector3 = current[(s + 1) % segments]
			var c: Vector3 = next[s]
			var d: Vector3 = next[(s + 1) % segments]
			st.add_vertex(a)
			st.add_vertex(c)
			st.add_vertex(b)
			st.add_vertex(b)
			st.add_vertex(c)
			st.add_vertex(d)
	st.generate_normals()
	var mesh := st.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(0, yaw, 0)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

func _create_house_details(origin: Vector3, label: String) -> void:
	_create_visual_gable_roof(label + " Roof", origin + Vector3(0, 3.55, 0), 12.6, 10.2, 1.85, Color(0.14, 0.065, 0.035))
	_create_house_exterior_assets(origin, label)
	_create_static_box(label + " Chimney", origin + Vector3(3.45, 4.0, -1.8), Vector3(0.62, 1.25, 0.62), Color(0.11, 0.08, 0.065))
	_create_house_doorway(origin, label)
	_create_house_windows(origin, label)
	_create_visual_box(label + " BrokenGlassA", origin + Vector3(-3.35, 1.6, 5.00), Vector3(0.12, 0.32, 0.035), Color(0.50, 0.62, 0.66, 0.72), Vector3(0, 0, -18))
	_create_visual_box(label + " RoofHole", origin + Vector3(-2.35, 4.05, 1.8), Vector3(1.2, 0.08, 0.75), Color(0.035, 0.025, 0.02), Vector3(0, 22, -12))
	_create_visual_box(label + " BigRustRoofPatch", origin + Vector3(2.1, 4.28, 1.35), Vector3(2.25, 0.09, 1.15), Color(0.34, 0.13, 0.055), Vector3(0, -13, 10))
	_create_visual_box(label + " WallStainA", origin + Vector3(-4.2, 1.35, -4.92), Vector3(1.35, 1.55, 0.055), Color(0.11, 0.10, 0.075), Vector3.ZERO)
	_create_visual_box(label + " MissingPlasterA", origin + Vector3(-5.92, 1.3, 1.45), Vector3(0.055, 1.25, 1.15), Color(0.105, 0.10, 0.082), Vector3.ZERO)
	_create_static_box(label + " FallenShelf", origin + Vector3(-2.65, 0, 0.95), Vector3(1.5, 0.20, 0.42), Color(0.13, 0.08, 0.045))
	_create_visual_box(label + " OldCurtain", origin + Vector3(-3.9, 1.45, 5.01), Vector3(0.18, 0.92, 0.035), Color(0.26, 0.18, 0.14), Vector3(0, 0, 5))

func _create_house_doorway(origin: Vector3, label: String) -> void:
	_create_visual_box(label + " DoorFrameLeft", origin + Vector3(-1.34, 1.35, 5.08), Vector3(0.18, 2.75, 0.20), Color(0.20, 0.12, 0.065), Vector3.ZERO)
	_create_visual_box(label + " DoorFrameRight", origin + Vector3(1.34, 1.35, 5.08), Vector3(0.18, 2.75, 0.20), Color(0.20, 0.12, 0.065), Vector3.ZERO)
	_create_visual_box(label + " DoorFrameTop", origin + Vector3(0.0, 2.7, 5.08), Vector3(2.86, 0.18, 0.20), Color(0.18, 0.10, 0.055), Vector3.ZERO)
	_create_interactive_door(label + " Door", origin + Vector3(-0.92, 0.0, 5.23), Vector3(1.84, 2.36, 0.11), Color(0.13, 0.075, 0.04), -96.0)

func _create_interactive_door(node_name: String, hinge_pos: Vector3, size: Vector3, color: Color, open_angle: float) -> void:
	var door = DoorScript.new()
	door.name = node_name
	door.position = hinge_pos
	door.setup("Puerta", size, color, open_angle)
	add_child(door)

func _create_house_windows(origin: Vector3, label: String) -> void:
	_create_front_window(label + " FrontWindowLeft", origin + Vector3(-3.65, 1.75, 5.08), 1.25, 0.95)
	_create_front_window(label + " FrontWindowRight", origin + Vector3(3.65, 1.75, 5.08), 1.25, 0.95)
	_create_front_window(label + " BackWindowA", origin + Vector3(-3.2, 1.68, -5.08), 1.18, 0.88)
	_create_front_window(label + " BackWindowB", origin + Vector3(3.2, 1.68, -5.08), 1.18, 0.88)
	_create_side_window(label + " LeftSideWindow", origin + Vector3(-5.95, 1.68, -1.55), 1.18, 0.88)
	_create_side_window(label + " RightSideWindow", origin + Vector3(5.95, 1.68, -1.55), 1.18, 0.88)

func _create_front_window(node_name: String, center: Vector3, width: float, height: float) -> void:
	var frame := Color(0.19, 0.12, 0.065)
	var glass := Color(0.075, 0.13, 0.145)
	_create_visual_box(node_name + " Glass", center, Vector3(width, height, 0.075), glass, Vector3.ZERO)
	_create_visual_box(node_name + " FrameTop", center + Vector3(0, height * 0.5 + 0.06, 0.055), Vector3(width + 0.22, 0.10, 0.13), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameBottom", center + Vector3(0, -height * 0.5 - 0.06, 0.055), Vector3(width + 0.22, 0.10, 0.13), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameLeft", center + Vector3(-width * 0.5 - 0.06, 0, 0.055), Vector3(0.10, height + 0.22, 0.13), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameRight", center + Vector3(width * 0.5 + 0.06, 0, 0.055), Vector3(0.10, height + 0.22, 0.13), frame, Vector3.ZERO)
	_create_visual_box(node_name + " CrossVertical", center + Vector3(0, 0, 0.075), Vector3(0.06, height + 0.05, 0.12), frame.darkened(0.12), Vector3.ZERO)
	_create_visual_box(node_name + " CrossHorizontal", center + Vector3(0, 0, 0.075), Vector3(width + 0.05, 0.055, 0.12), frame.darkened(0.12), Vector3.ZERO)

func _create_side_window(node_name: String, center: Vector3, width: float, height: float) -> void:
	var frame := Color(0.19, 0.12, 0.065)
	var glass := Color(0.075, 0.13, 0.145)
	_create_visual_box(node_name + " Glass", center, Vector3(0.075, height, width), glass, Vector3.ZERO)
	_create_visual_box(node_name + " FrameTop", center + Vector3(0.055, height * 0.5 + 0.06, 0), Vector3(0.13, 0.10, width + 0.22), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameBottom", center + Vector3(0.055, -height * 0.5 - 0.06, 0), Vector3(0.13, 0.10, width + 0.22), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameLeft", center + Vector3(0.055, 0, -width * 0.5 - 0.06), Vector3(0.13, height + 0.22, 0.10), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameRight", center + Vector3(0.055, 0, width * 0.5 + 0.06), Vector3(0.13, height + 0.22, 0.10), frame, Vector3.ZERO)
	_create_visual_box(node_name + " CrossVertical", center + Vector3(0.075, 0, 0), Vector3(0.12, height + 0.05, 0.06), frame.darkened(0.12), Vector3.ZERO)
	_create_visual_box(node_name + " CrossHorizontal", center + Vector3(0.075, 0, 0), Vector3(0.12, 0.055, width + 0.05), frame.darkened(0.12), Vector3.ZERO)

func _create_house_exterior_assets(origin: Vector3, label: String) -> void:
	_create_house_grass_asset(label + " FrontGrassLeft", origin + Vector3(-1.75, 0.055, 5.75), 0.34)
	_create_house_grass_asset(label + " FrontGrassRight", origin + Vector3(1.75, 0.055, 5.65), 0.30)
	_create_house_grass_asset(label + " FrontGrassSide", origin + Vector3(0.0, 0.055, 6.65), 0.26)
	_create_visual_box(label + " RoofEaveFront", origin + Vector3(0, 3.58, 5.22), Vector3(12.9, 0.16, 0.32), Color(0.095, 0.055, 0.035), Vector3.ZERO)
	_create_visual_box(label + " RoofEaveBack", origin + Vector3(0, 3.58, -5.22), Vector3(12.9, 0.16, 0.32), Color(0.085, 0.05, 0.035), Vector3.ZERO)
	_create_visual_box(label + " PorchStep", origin + Vector3(0, 0.18, 6.05), Vector3(2.8, 0.22, 0.62), Color(0.12, 0.105, 0.085), Vector3.ZERO)
	_create_visual_box(label + " VisibleRustPlateDoor", origin + Vector3(1.12, 1.38, 5.15), Vector3(0.72, 1.85, 0.10), Color(0.42, 0.15, 0.055), Vector3(0, 0, 2))
	_create_visual_box(label + " VisibleRustPlateRoofA", origin + Vector3(-2.8, 4.32, 1.2), Vector3(2.2, 0.10, 1.05), Color(0.38, 0.15, 0.06), Vector3(0, 18, -10))
	return
	_try_instance_external_scene([K_SURVIVAL + "structure-metal-wall.glb"], label + " ExteriorMetalWallLeft", origin + Vector3(-4.28, 1.15, -1.2), Vector3(1.8, 1.8, 1.8), Vector3(0, 90, 0))
	_try_instance_external_scene([K_SURVIVAL + "structure-metal-wall.glb"], label + " ExteriorMetalWallRight", origin + Vector3(4.28, 1.12, 1.15), Vector3(1.55, 1.55, 1.55), Vector3(0, -90, 0))
	_try_instance_external_scene([K_SURVIVAL + "structure-canvas.glb"], label + " TornCanvasBack", origin + Vector3(-2.0, 1.25, -3.78), Vector3(1.6, 1.55, 1.6), Vector3(0, 0, 0))
	_try_instance_external_scene([K_SURVIVAL + "structure.glb"], label + " ExteriorWoodPatch", origin + Vector3(2.5, 1.05, -3.82), Vector3(1.45, 1.45, 1.45), Vector3(0, 0, 0))
	_try_instance_external_scene([K_SURVIVAL + "metal-panel-screws.glb"], label + " BigRustPanelFrontA", origin + Vector3(-3.0, 1.2, 3.92), Vector3(1.25, 1.45, 1.25), Vector3(0, 180, 3))
	_try_instance_external_scene([K_SURVIVAL + "metal-panel-narrow.glb"], label + " BigRustPanelFrontB", origin + Vector3(3.25, 1.15, 3.92), Vector3(1.1, 1.5, 1.1), Vector3(0, 180, -5))
	_try_instance_external_scene([K_SURVIVAL + "fence.glb"], label + " BrokenPorchFenceA", origin + Vector3(-3.05, 0.04, 4.55), Vector3(0.95, 1.0, 0.95), Vector3(0, 6, 0), true, origin.y)
	_try_instance_external_scene([K_SURVIVAL + "fence-fortified.glb"], label + " BrokenPorchFenceB", origin + Vector3(3.05, 0.04, 4.5), Vector3(0.9, 0.95, 0.9), Vector3(0, -10, 0), true, origin.y)
	_create_visual_box(label + " ClearEntryPath", origin + Vector3(0.0, 0.031, 2.35), Vector3(2.2, 0.035, 2.9), Color(0.10, 0.095, 0.075), Vector3.ZERO)
	_create_visual_box(label + " ExteriorPlankA", origin + Vector3(-2.55, 1.74, 3.98), Vector3(1.45, 0.16, 0.08), Color(0.26, 0.16, 0.08), Vector3(0, 0, 17))
	_create_visual_box(label + " ExteriorPlankB", origin + Vector3(2.55, 1.61, 3.98), Vector3(1.35, 0.16, 0.08), Color(0.22, 0.13, 0.07), Vector3(0, 0, -14))
	_create_visual_box(label + " RoofEaveFront", origin + Vector3(0, 2.72, 4.05), Vector3(9.4, 0.16, 0.28), Color(0.095, 0.055, 0.035), Vector3.ZERO)
	_create_visual_box(label + " RoofEaveBack", origin + Vector3(0, 2.72, -4.05), Vector3(9.4, 0.16, 0.28), Color(0.085, 0.05, 0.035), Vector3.ZERO)
	_create_visual_box(label + " PorchStep", origin + Vector3(0, 0.18, 4.95), Vector3(2.2, 0.22, 0.55), Color(0.12, 0.105, 0.085), Vector3.ZERO)
	_create_visual_box(label + " FrontDirtMat", origin + Vector3(0.0, 0.025, 4.1), Vector3(1.3, 0.035, 0.75), Color(0.065, 0.055, 0.04), Vector3.ZERO)
	_create_visual_box(label + " VisibleRustPlateDoor", origin + Vector3(1.00, 1.15, 3.96), Vector3(0.82, 1.62, 0.10), Color(0.42, 0.15, 0.055), Vector3(0, 0, 2))
	_create_visual_box(label + " VisibleRustPlateRoofA", origin + Vector3(-2.15, 3.36, 0.9), Vector3(2.2, 0.10, 1.05), Color(0.38, 0.15, 0.06), Vector3(0, 18, -10))
	_create_visual_box(label + " VisibleRustPlateRoofB", origin + Vector3(2.35, 3.26, -1.05), Vector3(1.75, 0.10, 0.9), Color(0.25, 0.26, 0.23), Vector3(0, -16, 8))
	_create_visual_box(label + " PeeledPlasterFrontA", origin + Vector3(-3.15, 1.05, 3.955), Vector3(1.25, 1.55, 0.06), Color(0.10, 0.095, 0.075), Vector3(0, 0, 0))
	_create_visual_box(label + " PeeledPlasterFrontB", origin + Vector3(3.05, 1.35, 3.955), Vector3(1.1, 1.25, 0.06), Color(0.115, 0.105, 0.08), Vector3(0, 0, 0))

func _create_house_interior(origin: Vector3, label: String, id_prefix: String) -> void:
	pass

func _create_visible_house_interior_details(_origin: Vector3, _label: String) -> void:
	pass

func _create_extra_house_furniture(origin: Vector3, label: String) -> void:
	pass

func _create_house_living_room(origin: Vector3, label: String) -> void:
	pass

func _create_house_bedroom(origin: Vector3, label: String) -> void:
	pass

func _create_house_warehouse(origin: Vector3, label: String) -> void:
	pass

func _create_simple_chair(node_name: String, pos: Vector3, yaw: float) -> void:
	_create_visual_box(node_name + " Seat", pos + Vector3(0, 0.42, 0), Vector3(0.48, 0.12, 0.44), Color(0.16, 0.09, 0.04), Vector3(0, yaw, 0))
	_create_visual_box(node_name + " Back", pos + Vector3(0, 0.78, -0.18), Vector3(0.50, 0.60, 0.10), Color(0.13, 0.075, 0.035), Vector3(0, yaw, -3))
	_create_visual_box(node_name + " LegA", pos + Vector3(-0.18, 0.22, -0.15), Vector3(0.07, 0.40, 0.07), Color(0.10, 0.055, 0.025), Vector3(0, yaw, 0))
	_create_visual_box(node_name + " LegB", pos + Vector3(0.18, 0.22, -0.15), Vector3(0.07, 0.40, 0.07), Color(0.10, 0.055, 0.025), Vector3(0, yaw, 0))
	_create_visual_box(node_name + " LegC", pos + Vector3(-0.18, 0.22, 0.15), Vector3(0.07, 0.40, 0.07), Color(0.10, 0.055, 0.025), Vector3(0, yaw, 0))
	_create_visual_box(node_name + " LegD", pos + Vector3(0.18, 0.22, 0.15), Vector3(0.07, 0.40, 0.07), Color(0.10, 0.055, 0.025), Vector3(0, yaw, 0))

func _create_road_checkpoint(origin: Vector3) -> void:
	_register_wildlife_blocker(origin, 5.7)
	_create_static_box("CheckpointBarrierA", origin + Vector3(-2.2, 0, 0), Vector3(3.4, 0.75, 0.45), Color(0.34, 0.31, 0.24))
	_create_static_box("CheckpointBarrierB", origin + Vector3(2.4, 0, 1.1), Vector3(3.2, 0.75, 0.45), Color(0.34, 0.31, 0.24))
	_create_static_box("CheckpointSandbagA", origin + Vector3(-3.6, 0, -1.0), Vector3(1.3, 0.55, 0.8), Color(0.30, 0.27, 0.20))
	_create_static_box("CheckpointSandbagB", origin + Vector3(3.7, 0, 2.1), Vector3(1.3, 0.55, 0.8), Color(0.30, 0.27, 0.20))
	_create_static_cylinder("CheckpointDrumA", origin + Vector3(-0.3, 0, -1.0), 0.33, 0.85, Color(0.18, 0.08, 0.06))
	_create_static_cylinder("CheckpointDrumB", origin + Vector3(1.0, 0, 2.0), 0.33, 0.85, Color(0.12, 0.13, 0.12))

func _create_broken_road_details() -> void:
	for z in range(-58, 62, 7):
		if randf() < 0.82:
			var crack_pos := Vector3(randf_range(5.0, 11.0), 0.084, float(z) + randf_range(-2.2, 2.2))
			_create_road_crack(crack_pos, randf_range(-28.0, 28.0))
	for i in range(34):
		var patch_pos := Vector3(randf_range(4.8, 11.2), 0.086, randf_range(-60.0, 60.0))
		var patch_color := Color(0.018, 0.020, 0.018).lerp(Color(0.09, 0.075, 0.055), randf())
		_create_visual_box("RoadOilDirtPatch", patch_pos, Vector3(randf_range(0.7, 2.8), 0.018, randf_range(0.28, 1.35)), patch_color, Vector3(0, randf_range(-18.0, 18.0), 0))
	for i in range(22):
		var hole_pos := Vector3(randf_range(4.9, 11.1), 0.091, randf_range(-58.0, 58.0))
		_create_visual_box("RoadBrokenGroundHole", hole_pos, Vector3(randf_range(0.45, 1.35), 0.020, randf_range(0.30, 1.05)), Color(0.15, 0.17, 0.11), Vector3(0, randf_range(0.0, 180.0), 0))
		if randf() < 0.45:
			_create_grass_clump(hole_pos + Vector3(randf_range(-0.25, 0.25), 0.02, randf_range(-0.25, 0.25)), randf_range(0.22, 0.42), Color(0.11, 0.22, 0.07))
	for z in [-48, -36, -19, -2, 13, 31, 49]:
		_create_visual_box("FadedRoadLineBreak", Vector3(8, 0.096, z + randf_range(-2.0, 2.0)), Vector3(0.34, 0.020, randf_range(1.2, 3.0)), Color(0.035, 0.036, 0.032), Vector3(0, randf_range(-5.0, 5.0), 0))

func _create_wrecked_car(pos: Vector3, yaw: float, color: Color) -> void:
	if not _is_vehicle_spawn_clear(pos):
		return
	_register_wildlife_blocker(pos, 3.8)
	if _try_instance_external_scene(_shuffled_paths(REAL_CAR_MODELS), "RealAbandonedCar", pos + Vector3(0, 0.05, 0), Vector3(1.45, 1.45, 1.45), Vector3(0, yaw, 0), true, 0.0):
		var car_node := get_node_or_null("RealAbandonedCar")
		var car_height := 2.3
		if car_node != null and car_node is Node3D:
			car_height = _get_node_world_aabb_height(car_node as Node3D)
			car_height += 0.15
			if car_height < 0.5:
				car_height = 2.3
		_create_invisible_collision_box("RealCarCollision", pos, Vector3(2.7, car_height, 4.5))
		_add_vehicle_visibility_overlays(pos, yaw, color)
		return
	_create_static_box_rotated("WreckBody", pos + Vector3(0, 0, 0), Vector3(2.4, 0.9, 4.2), color, Vector3(0, yaw, 0))
	_create_static_box_rotated("WreckCabin", pos + Vector3(0, 0.75, -0.25), Vector3(1.8, 0.65, 1.7), color.darkened(0.15), Vector3(0, yaw, 0))
	_create_static_box_rotated("WreckHoodRust", pos + Vector3(0, 0.55, 1.35), Vector3(2.0, 0.18, 1.0), Color(0.28, 0.13, 0.06), Vector3(0, yaw + 4.0, 0))
	_create_static_cylinder("WreckWheelA", pos + Vector3(-1.25, 0, -1.35), 0.28, 0.28, Color(0.02, 0.02, 0.02))
	_create_static_cylinder("WreckWheelB", pos + Vector3(1.25, 0, 1.25), 0.28, 0.28, Color(0.02, 0.02, 0.02))

func _create_visible_vehicle_asset(pos: Vector3, yaw: float, model_index: int) -> void:
	if not _is_vehicle_spawn_clear(pos):
		return
	_register_wildlife_blocker(pos, 4.1)
	var path: String = str(REAL_CAR_MODELS[model_index % REAL_CAR_MODELS.size()])
	if _try_instance_external_scene([path], "ExternalVehicleVisible", pos + Vector3(0, 0.05, 0), Vector3(1.75, 1.75, 1.75), Vector3(0, yaw, 0), true, 0.0):
		var vis_node := get_node_or_null("ExternalVehicleVisible")
		var vis_height := 2.8
		if vis_node != null and vis_node is Node3D:
			vis_height = _get_node_world_aabb_height(vis_node as Node3D)
			vis_height += 0.15
			if vis_height < 0.5:
				vis_height = 2.8
		_create_invisible_collision_box("ExternalVehicleVisibleCollision", pos, Vector3(3.0, vis_height, 5.0))
		_add_vehicle_visibility_overlays(pos, yaw, Color(0.18, 0.11, 0.075))
		return
	_create_wrecked_car(pos, yaw, Color(0.18, 0.11, 0.075))

func _add_vehicle_visibility_overlays(pos: Vector3, yaw: float, color: Color) -> void:
	_create_static_box_rotated("VehicleDarkWindows", pos + Vector3(0, 1.02, -0.35), Vector3(1.75, 0.38, 1.15), Color(0.025, 0.035, 0.04), Vector3(0, yaw, 0))
	_create_static_box_rotated("VehicleRustHood", pos + Vector3(0, 0.82, 1.45), Vector3(1.95, 0.08, 1.0), Color(0.36, 0.12, 0.045), Vector3(0, yaw + 3.0, 0))
	_create_static_box_rotated("VehicleRustDoorPatch", pos + Vector3(-1.05, 0.72, -0.15), Vector3(0.08, 0.72, 0.85), color.lightened(0.18), Vector3(0, yaw, 0))
	_apply_clearcoat_to_children("RealAbandonedCar", pos)
	_apply_clearcoat_to_children("ExternalVehicleVisible", pos)
	_apply_clearcoat_to_children("RealAbandonedVan", pos)

func _apply_clearcoat_to_children(node_name: String, pos: Vector3) -> void:
	var node := get_node_or_null(node_name)
	if node == null:
		return
	var dist := global_position.distance_to(pos)
	if dist > 40.0:
		return
	_apply_clearcoat_recursive(node)

func _apply_clearcoat_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in range(mi.get_surface_override_material_count()):
			var mat := mi.get_surface_override_material(i)
			if mat is StandardMaterial3D:
				(mat as StandardMaterial3D).clearcoat_enabled = true
				(mat as StandardMaterial3D).clearcoat = 0.8
				(mat as StandardMaterial3D).clearcoat_roughness = 0.3
	for child in node.get_children():
		_apply_clearcoat_recursive(child)

func _is_vehicle_spawn_clear(pos: Vector3) -> bool:
	var blocked_centers := [
		Vector3(0, 0, 0),
		Vector3(-25, 0, -18),
		Vector3(-38, 0, 18),
		Vector3(23, 0, 18),
		Vector3(42, 0, 26),
		Vector3(-12, 0, 42),
		Vector3(33, 0, -30),
		Vector3(45, 0, 0),
		Vector3(-42, 0, -42)
	]
	for center in blocked_centers:
		if absf(pos.x - center.x) < 9.0 and absf(pos.z - center.z) < 8.0:
			return false
	return true

func _create_wrecked_van(pos: Vector3, yaw: float) -> void:
	_register_wildlife_blocker(pos, 4.4)
	if _try_instance_external_scene([REAL_VAN_MODEL], "RealAbandonedVan", pos + Vector3(0, 0.05, 0), Vector3(1.55, 1.55, 1.55), Vector3(0, yaw, 0), true, 0.0):
		var van_node := get_node_or_null("RealAbandonedVan")
		var van_height := 2.8
		if van_node != null and van_node is Node3D:
			van_height = _get_node_world_aabb_height(van_node as Node3D)
			van_height += 0.15
			if van_height < 0.5:
				van_height = 2.8
		_create_invisible_collision_box("RealVanCollision", pos, Vector3(3.0, van_height, 5.2))
		return
	_create_static_box_rotated("WreckVanBody", pos, Vector3(2.8, 1.6, 5.0), Color(0.17, 0.18, 0.15), Vector3(0, yaw, 0))
	_create_static_box_rotated("WreckVanCabinDark", pos + Vector3(0, 1.0, -1.0), Vector3(2.3, 0.6, 1.8), Color(0.06, 0.07, 0.065), Vector3(0, yaw, 0))
	_create_static_box_rotated("WreckVanOpenDoor", pos + Vector3(1.55, 0.5, 1.0), Vector3(0.12, 1.2, 1.0), Color(0.12, 0.13, 0.11), Vector3(0, yaw + 34.0, 0))
	_create_static_cylinder("VanWheelA", pos + Vector3(-1.45, 0, -1.6), 0.32, 0.32, Color(0.015, 0.015, 0.015))
	_create_static_cylinder("VanWheelB", pos + Vector3(1.45, 0, 1.6), 0.32, 0.32, Color(0.015, 0.015, 0.015))

func _create_road_crack(pos: Vector3, yaw: float) -> void:
	_create_visual_box("RoadCrack", pos, Vector3(randf_range(1.2, 2.7), 0.025, 0.08), Color(0.018, 0.018, 0.018), Vector3(0, yaw, 0))
	_create_visual_box("RoadCrackBranch", pos + Vector3(randf_range(-0.4, 0.4), 0.01, randf_range(-0.4, 0.4)), Vector3(0.8, 0.025, 0.06), Color(0.015, 0.015, 0.015), Vector3(0, yaw + randf_range(35, 70), 0))

func _create_power_line(start: Vector3, end: Vector3) -> void:
	var count := 4
	var pole_height := 6.0
	var pole_thickness := 0.28
	var crossbar_len := 2.8
	var crossbar_y := pole_height - 0.8
	var wire_y := crossbar_y + 0.15
	var positions: Array = []
	for i in range(count):
		var t := float(i) / float(count - 1)
		var pos := start.lerp(end, t)
		positions.append(pos)
		_create_static_box("PowerPole_%d" % i, pos, Vector3(pole_thickness, pole_height, pole_thickness), Color(0.13, 0.09, 0.055))
		_create_static_box("PowerCrossbar_%d" % i, pos + Vector3(0, crossbar_y, 0), Vector3(crossbar_len, 0.16, 0.16), Color(0.12, 0.08, 0.05))
		_create_static_box("PowerInsulatorA_%d" % i, pos + Vector3(-crossbar_len * 0.4, crossbar_y - 0.15, 0), Vector3(0.12, 0.25, 0.12), Color(0.35, 0.32, 0.28))
		_create_static_box("PowerInsulatorB_%d" % i, pos + Vector3(crossbar_len * 0.4, crossbar_y - 0.15, 0), Vector3(0.12, 0.25, 0.12), Color(0.35, 0.32, 0.28))
		_register_wildlife_blocker(pos, 1.2)
	for i in range(count - 1):
		var a: Vector3 = positions[i]
		var b: Vector3 = positions[i + 1]
		var wire_len := a.distance_to(b)
		var sag := wire_len * 0.06
		var yaw_deg := rad_to_deg(atan2((b - a).x, (b - a).z))
		var mid_a := a.lerp(b, 0.5) + Vector3(-crossbar_len * 0.4, wire_y, 0)
		_create_visual_box("PowerWireA_%d" % i, mid_a, Vector3(0.04, 0.04, wire_len), Color(0.02, 0.02, 0.02), Vector3(0, yaw_deg, 0))
		var mid_b := a.lerp(b, 0.5) + Vector3(crossbar_len * 0.4, wire_y, 0)
		_create_visual_box("PowerWireB_%d" % i, mid_b, Vector3(0.04, 0.04, wire_len), Color(0.02, 0.02, 0.02), Vector3(0, yaw_deg, 0))

func _create_fence_line(start: Vector3, end: Vector3, posts: int) -> void:
	for i in range(posts):
		var t := float(i) / float(max(posts - 1, 1))
		var pos := start.lerp(end, t)
		_create_static_box("FencePost", pos, Vector3(0.22, 1.7, 0.22), Color(0.12, 0.09, 0.06))
	for i in range(posts - 1):
		var t0 := float(i) / float(max(posts - 1, 1))
		var t1 := float(i + 1) / float(max(posts - 1, 1))
		var a := start.lerp(end, t0)
		var b := start.lerp(end, t1)
		var mid := a.lerp(b, 0.5) + Vector3(0, 0.9, 0)
		var length := a.distance_to(b)
		var yaw := rad_to_deg(atan2((b - a).x, (b - a).z))
		_create_static_box_rotated("FenceRail", mid, Vector3(0.12, 0.14, length), Color(0.12, 0.09, 0.06), Vector3(0, yaw, 0))

func _create_scrap_pile(pos: Vector3) -> void:
	_register_wildlife_blocker(pos, 3.0)
	_create_static_box_rotated("ScrapSheetA", pos + Vector3(0, 0, 0), Vector3(1.8, 0.14, 0.9), Color(0.25, 0.24, 0.22), Vector3(0, 23, 12))
	_create_static_box_rotated("ScrapSheetB", pos + Vector3(0.7, 0.05, 0.4), Vector3(1.4, 0.12, 0.75), Color(0.18, 0.11, 0.07), Vector3(0, -18, -7))
	_create_static_box("ScrapCrate", pos + Vector3(-0.6, 0, -0.5), Vector3(0.75, 0.55, 0.75), Color(0.12, 0.10, 0.08))
	_create_static_cylinder("ScrapTire", pos + Vector3(0.1, 0, 0.85), 0.35, 0.28, Color(0.015, 0.015, 0.015))

func _create_abandoned_camp(pos: Vector3) -> void:
	_register_wildlife_blocker(pos, 5.6)
	_create_label("Campamento abandonado", pos + Vector3(0, 2.1, 0))
	_spawn_external(K_SURVIVAL + "tent-canvas.glb", "KCampTent", pos + Vector3(-1.1, 0, 0.6), Vector3.ONE * 1.2, Vector3(0, -25, 0), Vector3(2.3, 1.6, 2.2))
	_spawn_external(K_SURVIVAL + "bedroll.glb", "KCampBedroll", pos + Vector3(1.0, 0, 0.8), Vector3.ONE, Vector3(0, 18, 0), Vector3(1.8, 0.25, 0.8))
	_spawn_external(K_SURVIVAL + "campfire-pit.glb", "KCampfirePit", pos + Vector3(0.9, 0, -0.8), Vector3.ONE, Vector3(0, 0, 0), Vector3(0.9, 0.2, 0.9))
	_spawn_external(K_SURVIVAL + "box-large.glb", "KCampBox", pos + Vector3(1.65, 0, -0.25), Vector3.ONE, Vector3(0, 45, 0), Vector3(1.0, 0.8, 1.0))
	_create_static_box_rotated("CampTarpPoleA", pos + Vector3(-1.9, 0, -1.3), Vector3(0.12, 1.6, 0.12), Color(0.10, 0.08, 0.055), Vector3(0, 0, 0))
	_create_static_box_rotated("CampTarpPoleB", pos + Vector3(1.9, 0, 1.3), Vector3(0.12, 1.35, 0.12), Color(0.10, 0.08, 0.055), Vector3(0, 0, 0))
	_create_visual_box("CampTarp", pos + Vector3(0, 1.45, 0), Vector3(4.6, 0.08, 3.1), Color(0.10, 0.14, 0.10), Vector3(0, -18, -8))
	_create_static_box("CampBedroll", pos + Vector3(-0.8, 0, 0.3), Vector3(1.8, 0.18, 0.75), Color(0.17, 0.18, 0.13))
	_create_static_cylinder("CampFireRingA", pos + Vector3(0.9, 0, -0.8), 0.48, 0.08, Color(0.05, 0.045, 0.04))
	_create_visual_box("CampColdAsh", pos + Vector3(0.9, 0.08, -0.8), Vector3(0.55, 0.025, 0.35), Color(0.09, 0.085, 0.075), Vector3(0, 25, 0))
	_create_loot_container("camp_backpack", "Mochila abandonada", pos + Vector3(1.6, 0, -0.2), Vector3(0.9, 0.65, 0.75), Color(0.08, 0.12, 0.07), [ROOT_BACKPACK_MODEL])

func _create_military_leftovers(pos: Vector3) -> void:
	_register_wildlife_blocker(pos, 4.5)
	_create_static_box_rotated("SandbagLineA", pos + Vector3(-1.1, 0, 0), Vector3(2.4, 0.42, 0.72), Color(0.31, 0.29, 0.21), Vector3(0, 10, 0))
	_create_static_box_rotated("SandbagLineB", pos + Vector3(1.3, 0, 0.3), Vector3(2.0, 0.42, 0.72), Color(0.28, 0.26, 0.19), Vector3(0, -12, 0))
	_create_static_cylinder("OldOilDrumA", pos + Vector3(-2.2, 0, -1.1), 0.34, 0.9, Color(0.12, 0.14, 0.12))
	_create_static_cylinder("OldOilDrumB", pos + Vector3(-1.65, 0, -1.35), 0.30, 0.78, Color(0.15, 0.08, 0.055))
	_create_static_box_rotated("WarningBoard", pos + Vector3(1.7, 0.5, -1.2), Vector3(1.4, 0.72, 0.10), Color(0.30, 0.25, 0.11), Vector3(0, -24, -5))

func _can_place_ground_vegetation(pos: Vector3, river_margin := 0.45) -> bool:
	if abs(pos.x - 8.0) < 5.4:
		return false
	if river_margin >= 0.0 and _is_inside_river_band(pos, river_margin):
		return false
	return not _is_in_no_grass_area(pos, 0.65)

func _is_inside_river_band(pos: Vector3, margin: float) -> bool:
	for segment in river_segments_data:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = float(segment["yaw"])
		var angle := deg_to_rad(yaw)
		var along := Vector3(cos(angle), 0.0, -sin(angle))
		var across := Vector3(sin(angle), 0.0, cos(angle))
		var offset := pos - center
		var local_forward := offset.dot(along)
		var local_side := offset.dot(across)
		if absf(local_forward) <= size.x * 0.5 + margin * 0.55 and absf(local_side) <= size.y * 0.5 + margin:
			return true
	return false

func _is_in_no_grass_area(pos: Vector3, extra_margin := 0.0) -> bool:
	for area in NO_GRASS_AREAS:
		var center: Vector3 = area["center"]
		var half: Vector2 = area["half"]
		if abs(pos.x - center.x) <= half.x + extra_margin and abs(pos.z - center.z) <= half.y + extra_margin:
			return true
	return false

func is_wildlife_allowed_at(pos: Vector3) -> bool:
	if _is_near_wildlife_blocker(pos, 0.0):
		return false
	return true

func get_wildlife_avoidance_vector_at(pos: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var p := Vector2(pos.x, pos.z)
	for blocker in wildlife_blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var radius := float(blocker.get("radius", 1.8)) + 2.1
		var offset := p - Vector2(blocker_pos.x, blocker_pos.z)
		var distance := offset.length()
		if distance <= 0.001:
			push += Vector3.RIGHT * radius
		elif distance < radius:
			var strength := (radius - distance) / radius
			push += Vector3(offset.x, 0.0, offset.y).normalized() * strength
	if push.length() > 0.01:
		return push.normalized()
	return Vector3.ZERO

func _register_wildlife_blocker(pos: Vector3, radius := 1.8) -> void:
	wildlife_blockers.append({
		"pos": Vector3(pos.x, 0.0, pos.z),
		"radius": radius
	})

func _is_near_wildlife_blocker(pos: Vector3, extra_margin := 0.0) -> bool:
	var p := Vector2(pos.x, pos.z)
	for blocker in wildlife_blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var radius := float(blocker.get("radius", 1.8)) + extra_margin
		if p.distance_to(Vector2(blocker_pos.x, blocker_pos.z)) <= radius:
			return true
	return false

func _create_ground_clutter() -> void:
	for i in range(360):
		var pos := Vector3(randf_range(-70, 70), 0.02, randf_range(-70, 70))
		if not _can_place_ground_vegetation(pos):
			continue
		if i % 5 < 4:
			_create_grass_clump(pos, randf_range(0.18, 0.42), Color(0.20, 0.36, 0.12).lerp(Color(0.38, 0.50, 0.17), randf()))
		else:
			_create_static_box_rotated("LooseDebris", pos, Vector3(randf_range(0.35, 0.8), 0.08, randf_range(0.25, 0.6)), Color(0.13, 0.12, 0.10), Vector3(0, randf_range(0, 180), 0))

func _create_tall_grass_fields() -> void:
	var fields := [
		{"center": Vector3(-48, 0, 18), "radius": Vector2(31, 37), "count": 240},
		{"center": Vector3(36, 0, 48), "radius": Vector2(34, 28), "count": 195},
		{"center": Vector3(-20, 0, -52), "radius": Vector2(35, 22), "count": 165},
		{"center": Vector3(58, 0, -44), "radius": Vector2(23, 31), "count": 155},
		{"center": Vector3(-2, 0, 10), "radius": Vector2(55, 48), "count": 240}
	]
	for field in fields:
		var center: Vector3 = field["center"]
		var radius: Vector2 = field["radius"]
		var count: int = int(field["count"])
		for i in range(count):
			var angle := randf_range(0.0, TAU)
			var dist := sqrt(randf()) 
			var pos := center + Vector3(cos(angle) * radius.x * dist, 0.02, sin(angle) * radius.y * dist)
			if not _can_place_ground_vegetation(pos):
				continue
			_create_grass_clump(pos, randf_range(0.34, 0.72), Color(0.18, 0.32, 0.11).lerp(Color(0.32, 0.42, 0.14), randf()))

func _create_dense_vegetation_zones() -> void:
	var zones := [
		{"center": Vector3(-56, 0, -8), "radius": Vector2(16, 24), "count": 120},
		{"center": Vector3(-48, 0, 44), "radius": Vector2(20, 16), "count": 115},
		{"center": Vector3(48, 0, 48), "radius": Vector2(18, 18), "count": 125},
		{"center": Vector3(58, 0, -18), "radius": Vector2(14, 22), "count": 105},
		{"center": Vector3(-18, 0, -62), "radius": Vector2(28, 10), "count": 110}
	]
	for zone in zones:
		var center: Vector3 = zone["center"]
		var radius: Vector2 = zone["radius"]
		var count: int = int(zone["count"])
		for i in range(count):
			var angle := randf_range(0.0, TAU)
			var dist := sqrt(randf())
			var pos := center + Vector3(cos(angle) * radius.x * dist, 0.02, sin(angle) * radius.y * dist)
			if not _can_place_ground_vegetation(pos):
				continue
			_create_grass_clump(pos, randf_range(0.48, 1.05), Color(0.13, 0.27, 0.09).lerp(Color(0.30, 0.44, 0.14), randf()))
			if randf() < 0.30:
				_create_bush(pos + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)), randf_range(0.55, 0.95))

func _create_grass_ground_cover() -> void:
	var patches := [
		{"center": Vector3(-42, 0, 22), "radius": Vector2(50, 54), "count": 300},
		{"center": Vector3(38, 0, 38), "radius": Vector2(44, 42), "count": 220},
		{"center": Vector3(-26, 0, -42), "radius": Vector2(52, 37), "count": 220},
		{"center": Vector3(50, 0, -42), "radius": Vector2(32, 40), "count": 160},
		{"center": Vector3(-6, 0, 20), "radius": Vector2(44, 42), "count": 230},
		{"center": Vector3(8, 0, 0), "radius": Vector2(68, 66), "count": 310}
	]
	for patch in patches:
		var center: Vector3 = patch["center"]
		var radius: Vector2 = patch["radius"]
		var count: int = int(patch["count"])
		for i in range(count):
			var angle := randf_range(0.0, TAU)
			var dist := sqrt(randf())
			var pos := center + Vector3(cos(angle) * radius.x * dist, 0.018, sin(angle) * radius.y * dist)
			if not _can_place_ground_vegetation(pos):
				continue
			_create_grass_clump(pos, randf_range(0.22, 0.48), Color(0.18, 0.32, 0.12).lerp(Color(0.34, 0.44, 0.16), randf()))

func _create_grass_carpet() -> void:
	_ensure_grass_batches()
	var coverage := 60.0
	var spacing := 4.0
	var cells_x := int(coverage * 2.0 / spacing)
	var cells_z := int(coverage * 2.0 / spacing)
	var base_color := Color(0.20, 0.34, 0.12)
	var color_var := Color(0.34, 0.46, 0.16)
	for cx in range(cells_x):
		for cz in range(cells_z):
			if randf() < 0.5:
				continue
			var px := -coverage + float(cx) * spacing + randf_range(-0.8, 0.8)
			var pz := -coverage + float(cz) * spacing + randf_range(-0.8, 0.8)
			var pos := Vector3(px, 0.012, pz)
			if abs(pos.x - 8.0) < 5.4:
				continue
			if _is_in_no_grass_area(pos, 0.65):
				continue
			var h := randf_range(0.10, 0.22)
			var r := randf_range(0.28, 0.45)
			var c := base_color.lerp(color_var, randf()).darkened(randf_range(0.0, 0.12))
			_queue_grass_instance(pos, h, r, c)

func _create_billboard_underbrush_fields() -> void:
	for i in range(8):
		var pos := Vector3(randf_range(-68, 68), 0.03, randf_range(-68, 68))
		if not _can_place_ground_vegetation(pos):
			continue
		if randf() < 0.55 and pos.distance_to(Vector3(-48, 0, 20)) > 34.0:
			continue
		_create_billboard_underbrush(pos, randf_range(0.55, 1.05))

func _create_billboard_underbrush(pos: Vector3, height: float) -> bool:
	var texture_paths := _get_billboard_textures("underbrush")
	if texture_paths.is_empty():
		return false
	var texture_path := ""
	for candidate in _shuffled_paths(texture_paths):
		if _resource_path_exists(candidate):
			texture_path = candidate
			break
	if texture_path.is_empty():
		return false
	var material := _make_tree_billboard_material(texture_path)
	if material.albedo_texture == null:
		return false
	var width := height * randf_range(0.95, 1.55)
	var yaw := randf_range(0.0, 360.0)
	for i in range(2):
		var plane := MeshInstance3D.new()
		plane.name = "BillboardUnderbrush"
		plane.position = pos + Vector3(0.0, height * 0.5, 0.0)
		plane.rotation_degrees = Vector3(90.0, yaw + 90.0 * float(i), 0.0)
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(width, height)
		plane.mesh = mesh
		plane.material_override = material
		add_child(plane)
	return true

func _create_clouds() -> void:
	var cloud_textures := _get_cloud_billboard_textures()
	if cloud_textures.is_empty():
		for i in range(10):
			var base := Vector3(randf_range(-88, 88), randf_range(32, 44), randf_range(-92, 70))
			_create_cloud_layer(base, randf_range(13.0, 24.0), randf_range(5.0, 11.0), randf_range(0, 180))
		return
	for i in range(7):
		var base := Vector3(randf_range(-95, 95), randf_range(42, 55), randf_range(-95, 85))
		_create_cloud_billboard(base, _shuffled_paths(cloud_textures), randf_range(15.0, 28.0), randf_range(6.0, 12.0), randf_range(0, 180))

func _create_forest() -> void:
	_create_label("Bosque", Vector3(-48, 2.2, 20))
	for i in range(210):
		var x := randf_range(-68, -18)
		var z := randf_range(-4, 66)
		if not _can_place_ground_vegetation(Vector3(x, 0, z), 2.8):
			continue
		if Vector3(x, 0, z).distance_to(Vector3(-38, 0, 18)) < 9.0:
			continue
		if Vector3(x, 0, z).distance_to(Vector3(-42, 0, -42)) < 8.0:
			continue
		_create_tree(Vector3(x, 0, z))
	for i in range(70):
		var x := randf_range(17, 68)
		var z := randf_range(34, 68)
		if not _can_place_ground_vegetation(Vector3(x, 0, z), 2.8):
			continue
		_create_tree(Vector3(x, 0, z))
	for i in range(52):
		var x := randf_range(-6, 66)
		var z := randf_range(-68, -49)
		if not _can_place_ground_vegetation(Vector3(x, 0, z), 2.8):
			continue
		_create_tree(Vector3(x, 0, z))

func _create_tree(pos: Vector3) -> void:
	if not _can_place_ground_vegetation(pos, 2.8):
		return
	_register_wildlife_blocker(pos, 1.0)
	if randf() < 0.0:
		if _create_billboard_tree(pos, _get_billboard_textures("dead"), randf_range(4.8, 7.2), "DeadBillboardTree"):
			return
		_create_dead_tree_fallback(pos)
		_create_tree_collision("RealTreeCollision", pos)
		return
	if _try_instance_external_scene(_shuffled_paths(POLY_TREE_MODELS), "PolyhavenTree", pos, Vector3.ONE * randf_range(1.15, 2.15), Vector3(0, randf_range(0, 360), 0), true, 0.0):
		_create_tree_collision("PolyhavenTreeCollision", pos)
		_override_tree_foliage_green("PolyhavenTree")
		return
	_create_living_tree_fallback(pos)

func _create_cut_tree_remains(pos: Vector3) -> void:
	var stump := _create_static_cylinder("CutTreeStump", pos, 0.32, 0.55, Color(0.18, 0.105, 0.045))
	stump.add_to_group("cut_tree_remains")
	_create_visual_cylinder("CutTreeStumpTop", pos + Vector3(0, 0.585, 0), 0.33, 0.035, Color(0.36, 0.24, 0.12), Vector3.ZERO)
	var yaw_a := randf_range(0.0, 180.0)
	var yaw_b := yaw_a + randf_range(42.0, 86.0)
	if not _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], "CutTreeLogAssetA", pos + Vector3(0.72, 0.12, 0.18), Vector3.ONE * 0.75, Vector3(0, yaw_a, 0), true, 0.06):
		_create_visual_cylinder("CutTreeLogA", pos + Vector3(0.72, 0.22, 0.18), 0.18, 2.2, Color(0.20, 0.12, 0.055), Vector3(90, yaw_a, 0))
	if not _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], "CutTreeLogAssetB", pos + Vector3(-0.58, 0.12, -0.28), Vector3.ONE * 0.62, Vector3(0, yaw_b, 0), true, 0.06):
		_create_visual_cylinder("CutTreeLogB", pos + Vector3(-0.58, 0.20, -0.28), 0.15, 1.65, Color(0.16, 0.09, 0.04), Vector3(90, yaw_b, 0))
	for i in range(3):
		var branch_pos := pos + Vector3(randf_range(-0.7, 0.7), 0.10, randf_range(-0.7, 0.7))
		_create_visual_cylinder("CutTreeBranch", branch_pos, randf_range(0.035, 0.06), randf_range(0.7, 1.15), Color(0.13, 0.075, 0.035), Vector3(90, randf_range(0, 180), randf_range(-12, 12)))
	_spawn_wood_chips(pos + Vector3(0, 1.5, 0))

func _spawn_wood_chips(origin: Vector3) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "WoodChips"
	particles.position = origin
	particles.amount = 24
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 35.0
	mat.initial_velocity_min = 2.5
	mat.initial_velocity_max = 5.0
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.3
	mat.scale_max = 1.0
	mat.hue_variation_min = -0.05
	mat.hue_variation_max = 0.05
	mat.color = Color(0.42, 0.26, 0.12)
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 1.0))
	scale_curve.add_point(Vector2(0.5, 0.6))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	var rot_curve := Curve.new()
	rot_curve.add_point(Vector2(0, 0.0))
	rot_curve.add_point(Vector2(1.0, 12.0))
	var rot_tex := CurveTexture.new()
	rot_tex.curve = rot_curve
	mat.rotation_curve = rot_tex
	particles.process_material = mat
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.06, 0.12)
	particles.draw_pass_1 = mesh
	add_child(particles)
	get_tree().create_timer(2.5).timeout.connect(particles.queue_free)

func _create_billboard_tree(pos: Vector3, texture_paths: Array, height: float, node_name: String) -> bool:
	var texture_path := ""
	for candidate in texture_paths:
		if _resource_path_exists(candidate):
			texture_path = candidate
			break
	if texture_path.is_empty():
		return false
	var material := _make_tree_billboard_material(texture_path)
	if material.albedo_texture == null:
		return false
	var width := height * randf_range(0.42, 0.56)
	var yaw := randf_range(0.0, 360.0)
	for i in range(3):
		var plane := MeshInstance3D.new()
		plane.name = node_name
		plane.position = pos + Vector3(0.0, height * 0.5, 0.0)
		plane.rotation_degrees = Vector3(90.0, yaw + 60.0 * float(i), 0.0)
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(width, height)
		mesh.subdivide_width = 1
		mesh.subdivide_depth = 1
		plane.mesh = mesh
		plane.material_override = material
		add_child(plane)
	_create_tree_collision(node_name + "Collision", pos)
	return true

func _create_living_tree_fallback(pos: Vector3) -> void:
	if _try_instance_external_scene(_shuffled_paths(REAL_LIVING_TREE_MODELS), "ExternalLivingTree", pos, Vector3.ONE * randf_range(1.15, 1.9), Vector3(0, randf_range(0, 360), 0), true, 0.0):
		_create_tree_collision("ExternalLivingTreeCollision", pos)
		_override_tree_foliage_green("ExternalLivingTree")
		return
	var height := randf_range(6.4, 10.2)
	var trunk_radius := randf_range(0.18, 0.34)
	var use_fir := randf() < 0.45
	var bark_texture := POLY_FIR_BARK_DIFF if use_fir else POLY_PINE_BARK_DIFF
	var twig_texture := POLY_FIR_TWIG_DIFF if use_fir else POLY_PINE_TWIG_DIFF
	var twig_alpha := POLY_FIR_TWIG_ALPHA if use_fir else POLY_PINE_TWIG_ALPHA
	_create_textured_cylinder("PolyTexturedTreeTrunk", pos, trunk_radius, height * 0.82, bark_texture, Color(0.18, 0.12, 0.075), Vector3(2.0, 6.0, 1.0))
	var branch_count := 18 + randi() % 9
	for i in range(branch_count):
		var t: float = float(i) / float(max(branch_count - 1, 1))
		var branch_y: float = lerp(height * 0.26, height * 0.93, t)
		var ring_scale: float = 1.0 - t * 0.72
		var angle: float = randf_range(0.0, TAU)
		var side := Vector3(cos(angle), 0, sin(angle))
		var branch_pos := pos + side * randf_range(0.06, 0.20) + Vector3(0, branch_y, 0)
		var branch_width := randf_range(1.2, 2.4) * ring_scale
		var branch_height := randf_range(0.62, 1.15) * ring_scale
		_create_tree_twig_plane(branch_pos, Vector2(branch_width, branch_height), rad_to_deg(angle), twig_texture, twig_alpha)
	_create_tree_collision("TreeCollision", pos)

func _create_dead_tree_fallback(pos: Vector3) -> void:
	if _try_instance_external_scene(_shuffled_paths(REAL_DEAD_TREE_MODELS), "ExternalDeadTree", pos, Vector3.ONE * randf_range(1.05, 1.75), Vector3(0, randf_range(0, 360), 0), true, 0.0):
		_create_tree_collision("ExternalDeadTreeCollision", pos)
		return
	var height := randf_range(4.2, 7.2)
	var trunk_color := Color(0.14, 0.10, 0.07).lerp(Color(0.24, 0.20, 0.15), randf())
	_create_static_cylinder("DeadFallbackTrunk", pos, randf_range(0.16, 0.28), height * 0.82, trunk_color)
	for i in range(5 + randi() % 4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var y := height * randf_range(0.34, 0.78)
		var branch_length := randf_range(0.85, 1.75)
		var branch_pos := pos + Vector3(side * randf_range(0.18, 0.46), y, randf_range(-0.22, 0.22))
		var branch_rot := Vector3(randf_range(54.0, 76.0), randf_range(-70.0, 70.0), side * randf_range(18.0, 42.0))
		_create_visual_cylinder("DeadFallbackBranch", branch_pos, randf_range(0.025, 0.055), branch_length, trunk_color.darkened(randf_range(0.04, 0.18)), branch_rot)
	if randf() < 0.35:
		_create_visual_sphere("DeadFallbackSparseLeaves", pos + Vector3(randf_range(-0.25, 0.25), height * 0.74, randf_range(-0.25, 0.25)), Vector3(randf_range(0.55, 0.9), randf_range(0.24, 0.42), randf_range(0.45, 0.78)), Color(0.055, 0.095, 0.042))

func _create_grass_clump(pos: Vector3, height: float, color: Color) -> void:
	if not _can_place_ground_vegetation(pos):
		return
	var clump_height: float = clamp(height, 0.16, 1.35)
	var tuft_color := color.lerp(Color(0.42, 0.52, 0.18), randf_range(0.0, 0.22)).darkened(randf_range(0.0, 0.08))
	_create_grass_tuft("VerticalGrassTuft", pos, clump_height * randf_range(0.80, 1.18), randf_range(0.12, 0.24), tuft_color)

func _create_river_reed_cluster(pos: Vector3, height: float, side: float) -> void:
	for i in range(3 + randi() % 4):
		var reed_pos := pos + Vector3(randf_range(-0.55, 0.55), 0.0, randf_range(-0.55, 0.55))
		if not _can_place_ground_vegetation(reed_pos, -1.0):
			continue
		var reed_color := Color(0.12, 0.25, 0.08).lerp(Color(0.18, 0.32, 0.10), randf())
		_queue_tall_grass_instance(reed_pos, height * randf_range(0.72, 1.08) * 0.45, reed_color)

func _create_grass_tuft(_node_name: String, pos: Vector3, height: float, radius: float, color: Color) -> void:
	_queue_grass_instance(pos, height, radius, color)

# Builds a normalized grass tuft mesh (height 1.0, radius 1.0) used as a shared
# MultiMesh source. Variants give a bit of visual variety without per-clump meshes.
func _build_grass_variant_mesh(variant_seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = variant_seed
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var blade_count := 14 + rng.randi() % 9
	for i in range(blade_count):
		var angle := rng.randf_range(0.0, TAU)
		var spread := rng.randf_range(0.05, 1.0)
		var base := Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
		var blade_height := rng.randf_range(0.55, 1.25)
		var blade_width := rng.randf_range(0.12, 0.32)
		var lean_x := cos(angle + rng.randf_range(-0.55, 0.55)) * rng.randf_range(0.08, 0.28)
		var lean_z := sin(angle + rng.randf_range(-0.55, 0.55)) * rng.randf_range(0.08, 0.28)
		var right := Vector3(cos(angle + PI * 0.5), 0.0, sin(angle + PI * 0.5)) * blade_width
		var mid := base + Vector3(lean_x * 0.4, blade_height * 0.5, lean_z * 0.4)
		var tip := base + Vector3(lean_x, blade_height, lean_z)
		var mid_right := right * 0.65
		var start_index := vertices.size()
		vertices.append(base - right)
		vertices.append(base + right)
		vertices.append(mid - mid_right)
		vertices.append(mid + mid_right)
		vertices.append(tip)
		indices.append_array(PackedInt32Array([
			start_index, start_index + 1, start_index + 2,
			start_index + 1, start_index + 3, start_index + 2,
			start_index + 2, start_index + 3, start_index + 4
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ensure_grass_batches() -> void:
	if not grass_batch_meshes.is_empty():
		return
	for i in range(GRASS_BATCH_VARIANTS):
		grass_batch_meshes.append(_build_grass_variant_mesh(0x9E37 + i * 1013))
		grass_batch_transforms.append([])
		grass_batch_colors.append([])
	grass_batch_material = StandardMaterial3D.new()
	grass_batch_material.roughness = 0.96
	grass_batch_material.metallic = 0.0
	grass_batch_material.vertex_color_use_as_albedo = true
	grass_batch_material.no_culling = true
	grass_batch_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.085
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 96
	texture.height = 96
	texture.noise = noise
	grass_batch_material.albedo_texture = texture

func _queue_grass_instance(pos: Vector3, height: float, radius: float, color: Color) -> void:
	_ensure_grass_batches()
	var variant := randi() % GRASS_BATCH_VARIANTS
	var basis := Basis(Vector3.UP, randf_range(0.0, TAU)).scaled(Vector3(radius, height, radius))
	(grass_batch_transforms[variant] as Array).append(Transform3D(basis, pos))
	(grass_batch_colors[variant] as Array).append(color)

func _ensure_tall_grass_batches() -> void:
	if not _tall_grass_meshes.is_empty():
		return
	var paths := [
		Q_NATURE + "Grass_Wispy_Tall.gltf",
		Q_NATURE + "Grass_Common_Tall.gltf"
	]
	for path in paths:
		var node: Node3D = _load_gltf_scene_from_file(path)
		if node == null:
			continue
		var meshes: Array = []
		_collect_mesh_instances(node, meshes)
		for m in meshes:
			var mi := m as MeshInstance3D
			if mi.mesh != null:
				_tall_grass_meshes.append(mi.mesh)
				_tall_grass_transforms.append([])
				_tall_grass_colors.append([])
		node.queue_free()
	if _tall_grass_meshes.is_empty():
		return
	_tall_grass_material = StandardMaterial3D.new()
	_tall_grass_material.roughness = 0.95
	_tall_grass_material.metallic = 0.0
	_tall_grass_material.vertex_color_use_as_albedo = true
	_tall_grass_material.no_culling = true
	_tall_grass_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX

func _queue_tall_grass_instance(pos: Vector3, scale_val: float, color: Color) -> void:
	_ensure_tall_grass_batches()
	if _tall_grass_meshes.is_empty():
		_queue_grass_instance(pos, scale_val, scale_val * 0.5, color)
		return
	var variant := randi() % _tall_grass_meshes.size()
	var s := scale_val * randf_range(0.85, 1.15)
	var basis := Basis(Vector3.UP, randf_range(0.0, TAU)).scaled(Vector3(s, s, s))
	(_tall_grass_transforms[variant] as Array).append(Transform3D(basis, pos))
	(_tall_grass_colors[variant] as Array).append(color)

# Collapses every queued grass tuft into a handful of MultiMeshInstance3D nodes
# (one per variant) instead of thousands of individual MeshInstance3D draw calls.
func _flush_grass_batches() -> void:
	if grass_batch_meshes.is_empty():
		return
	for variant in range(grass_batch_meshes.size()):
		var transforms: Array = grass_batch_transforms[variant]
		var colors: Array = grass_batch_colors[variant]
		if transforms.is_empty():
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = grass_batch_meshes[variant]
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
			multimesh.set_instance_color(i, colors[i])
		var mm_instance := MultiMeshInstance3D.new()
		mm_instance.name = "GrassBatch_%d" % variant
		mm_instance.multimesh = multimesh
		mm_instance.material_override = grass_batch_material
		mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mm_instance)
		transforms.clear()
		colors.clear()
	if not _tall_grass_meshes.is_empty():
		for variant in range(_tall_grass_meshes.size()):
			var t_transforms: Array = _tall_grass_transforms[variant]
			var t_colors: Array = _tall_grass_colors[variant]
			if t_transforms.is_empty():
				continue
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = _tall_grass_meshes[variant]
			multimesh.instance_count = t_transforms.size()
			for i in range(t_transforms.size()):
				multimesh.set_instance_transform(i, t_transforms[i])
				multimesh.set_instance_color(i, t_colors[i])
			var mm_instance := MultiMeshInstance3D.new()
			mm_instance.name = "TallGrassBatch_%d" % variant
			mm_instance.multimesh = multimesh
			mm_instance.material_override = _tall_grass_material
			mm_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mm_instance)
			t_transforms.clear()
			t_colors.clear()

func _create_bush(pos: Vector3, radius: float) -> void:
	if not _can_place_ground_vegetation(pos):
		return
	if _try_instance_external_scene(_shuffled_paths(REAL_BUSH_MODELS), "RealBush", pos, Vector3.ONE * randf_range(radius * 0.22, radius * 0.42), Vector3(0, randf_range(0, 360), 0), true, 0.0):
		return
	var base_color := Color(0.05, 0.12, 0.045).lerp(Color(0.10, 0.17, 0.075), randf())
	_create_visual_sphere("BushCore", pos + Vector3(0, radius * 0.25, 0), Vector3(radius, radius * 0.48, radius * 0.82), base_color)
	_create_visual_sphere("BushLobeA", pos + Vector3(radius * 0.30, radius * 0.35, -radius * 0.12), Vector3(radius * 0.55, radius * 0.36, radius * 0.50), base_color.darkened(0.10))
	_create_visual_sphere("BushLobeB", pos + Vector3(-radius * 0.28, radius * 0.28, radius * 0.18), Vector3(radius * 0.48, radius * 0.34, radius * 0.52), base_color.lightened(0.06))

func _create_cutout_plant(node_name: String, pos: Vector3, height: float, texture_path: String, alpha_path: String, width_factor: float) -> bool:
	if not _resource_path_exists(texture_path):
		return false
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees.y = randf_range(0.0, 360.0)
	add_child(root)
	var plane_count := 2 + randi() % 2
	for i in range(plane_count):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = node_name + "Plane"
		mesh_instance.rotation_degrees = Vector3(90.0, 90.0 * i / max(1.0, float(plane_count - 1)), 0.0)
		mesh_instance.position.y = height * 0.5
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(height * width_factor, height)
		mesh_instance.mesh = mesh
		mesh_instance.material_override = _make_cutout_material(node_name + texture_path + alpha_path, texture_path, alpha_path)
		root.add_child(mesh_instance)
	return true

func _create_cloud_billboard(pos: Vector3, texture_paths: Array, width: float, depth: float, yaw: float) -> bool:
	var texture_path := ""
	for candidate in texture_paths:
		if _resource_path_exists(candidate):
			texture_path = candidate
			break
	if texture_path.is_empty():
		return false
	var material := _make_cloud_billboard_material(texture_path)
	if material.albedo_texture == null:
		return false
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "CloudBillboard"
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(0, yaw, 0)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(width, depth)
	mesh.subdivide_width = 1
	mesh.subdivide_depth = 1
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	add_child(mesh_instance)
	return true

func _create_cloud_layer(pos: Vector3, width: float, depth: float, yaw: float) -> void:
	for i in range(5):
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = "SoftCloud"
		mesh_instance.position = pos + Vector3(randf_range(-width * 0.35, width * 0.35), randf_range(-0.35, 0.45), randf_range(-depth * 0.55, depth * 0.55))
		mesh_instance.rotation_degrees = Vector3(randf_range(-2.0, 2.0), yaw + randf_range(-10.0, 10.0), randf_range(-3.0, 3.0))
		mesh_instance.scale = Vector3(width * randf_range(0.12, 0.24), randf_range(0.28, 0.52), depth * randf_range(0.24, 0.48))
		mesh_instance.mesh = _get_shared_visual_sphere_mesh()
		mesh_instance.material_override = _make_cloud_material()
		add_child(mesh_instance)

func _create_static_box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _get_shared_box_mesh()
	mesh_instance.scale = size
	mesh_instance.position.y = size.y * 0.5
	mesh_instance.material_override = _make_material(color, true)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	add_child(body)
	return body

func _create_textured_wall(node_name: String, pos: Vector3, size: Vector3, rot: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = rot
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _get_shared_box_mesh()
	mesh_instance.scale = size
	mesh_instance.position.y = size.y * 0.5
	var uv_scale := Vector3(max(size.x, size.z) / 1.4, size.y / 1.4, 1.0)
	mesh_instance.material_override = _make_textured_material(node_name + TEX_BRICK_DIFF, TEX_BRICK_DIFF, Color(0.62, 0.46, 0.38), uv_scale)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	add_child(body)
	return body

func _create_invisible_collision_box(node_name: String, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	add_child(body)
	return body

func _create_invisible_collision_box_rotated(node_name: String, pos: Vector3, size: Vector3, rot_y: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees.y = rot_y
	body.collision_layer = 1
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	body.add_child(collision)
	add_child(body)
	return body

func _create_tree_collision(node_name: String, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 1

	var trunk_collision := CollisionShape3D.new()
	var trunk_shape := CylinderShape3D.new()
	trunk_shape.radius = 0.92
	trunk_shape.height = 6.8
	trunk_collision.shape = trunk_shape
	trunk_collision.position.y = trunk_shape.height * 0.5
	body.add_child(trunk_collision)

	var root_collision := CollisionShape3D.new()
	var root_shape := CylinderShape3D.new()
	root_shape.radius = 1.35
	root_shape.height = 1.15
	root_collision.shape = root_shape
	root_collision.position.y = root_shape.height * 0.5
	body.add_child(root_collision)

	add_child(body)
	return body

func _create_static_box_rotated(node_name: String, pos: Vector3, size: Vector3, color: Color, rot: Vector3) -> StaticBody3D:
	var body := _create_static_box(node_name, pos, size, color)
	body.rotation_degrees = rot
	return body

func _create_static_cylinder(node_name: String, pos: Vector3, radius: float, height: float, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _get_shared_cylinder_mesh()
	mesh_instance.scale = Vector3(radius, height, radius)
	mesh_instance.position.y = height * 0.5
	mesh_instance.material_override = _make_material(color, true)
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	add_child(body)
	return body

func _create_visual_cylinder(node_name: String, pos: Vector3, radius: float, height: float, color: Color, rot: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rot
	mesh_instance.mesh = _get_shared_cylinder_mesh()
	mesh_instance.scale = Vector3(radius, height, radius)
	mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

func _create_textured_cylinder(node_name: String, pos: Vector3, radius: float, height: float, texture_path: String, fallback_color: Color, uv_scale: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos + Vector3(0, height * 0.5, 0)
	mesh_instance.mesh = _get_shared_trunk_cylinder_mesh()
	mesh_instance.scale = Vector3(radius, height, radius)
	mesh_instance.material_override = _make_textured_material(node_name + texture_path, texture_path, fallback_color, uv_scale)
	add_child(mesh_instance)

func _create_tree_twig_plane(pos: Vector3, size: Vector2, yaw: float, texture_path: String, alpha_path: String) -> void:
	return
	if not _resource_path_exists(texture_path):
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PolyTreeTwig"
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(randf_range(-10.0, 7.0), yaw, randf_range(-8.0, 8.0))
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_cutout_material("tree_twig_" + texture_path + alpha_path, texture_path, alpha_path)
	add_child(mesh_instance)

func _create_visual_box(node_name: String, pos: Vector3, size: Vector3, color: Color, rot: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rot
	mesh_instance.mesh = _get_shared_box_mesh()
	mesh_instance.scale = size
	mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

func _create_area_light(node_name: String, pos: Vector3, light_size: Vector2, color: Color, energy: float, rot_deg: Vector3) -> void:
	var light := AreaLight3D.new()
	light.name = node_name
	light.position = pos
	light.rotation_degrees = rot_deg
	light.size = light_size
	light.color = color
	light.energy = energy
	light.shadow_enabled = true
	add_child(light)

func _create_textured_visual_box(node_name: String, pos: Vector3, size: Vector3, texture_path: String, fallback_color: Color, rot: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rot
	mesh_instance.mesh = _get_shared_box_mesh()
	mesh_instance.scale = size
	mesh_instance.material_override = _make_textured_material(node_name + texture_path, texture_path, fallback_color, Vector3(1.8, 1.8, 1.0))
	add_child(mesh_instance)

func _create_visual_plane(node_name: String, pos: Vector3, size: Vector2, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 12
	mesh.subdivide_depth = 12
	mesh_instance.mesh = mesh
	if node_name == "TerrainSurface":
		mesh_instance.material_override = _make_main_ground_material(color)
	else:
		mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

func _create_textured_ground_patch(node_name: String, pos: Vector3, size: Vector2, texture_path: String, yaw: float, fallback_color: Color) -> void:
	if node_name.find("River") >= 0 or node_name.find("Pebble") >= 0 or node_name.find("Shore") >= 0:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(0, yaw, 0)
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = 2
	mesh.subdivide_depth = 2
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_textured_material(node_name + texture_path, texture_path, fallback_color, Vector3(2.8, 2.8, 1.0))
	add_child(mesh_instance)

func _create_irregular_textured_ground_patch(node_name: String, pos: Vector3, size: Vector2, texture_path: String, yaw: float, fallback_color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(0, yaw, 0)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	uvs.append(Vector2(0.5, 0.5))
	var segments := 16
	for i in range(segments):
		var angle := TAU * float(i) / float(segments)
		var ripple := randf_range(0.68, 1.18)
		if i % 3 == 0:
			ripple *= randf_range(0.76, 1.04)
		var local_x := cos(angle) * size.x * 0.5 * ripple
		var local_z := sin(angle) * size.y * 0.5 * ripple
		vertices.append(Vector3(local_x, 0.0, local_z))
		uvs.append(Vector2(local_x / max(0.01, size.x) + 0.5, local_z / max(0.01, size.y) + 0.5))
	for i in range(segments):
		var a := i + 1
		var b := 1 if i == segments - 1 else i + 2
		indices.append(0)
		indices.append(a)
		indices.append(b)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_textured_material(node_name + texture_path, texture_path, fallback_color, Vector3(2.25, 2.25, 1.0))
	add_child(mesh_instance)

func _create_visual_sphere(node_name: String, pos: Vector3, scale_value: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.scale = scale_value
	mesh_instance.mesh = _get_shared_visual_sphere_mesh()
	mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

func _create_textured_visual_sphere(node_name: String, pos: Vector3, scale_value: Vector3, texture_path: String, fallback_color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(randf_range(-4.0, 4.0), randf_range(0.0, 360.0), randf_range(-4.0, 4.0))
	mesh_instance.scale = scale_value
	mesh_instance.mesh = _get_shared_sphere_mesh()
	mesh_instance.material_override = _make_textured_material(node_name + texture_path, texture_path, fallback_color, Vector3(1.6, 1.6, 1.0))
	add_child(mesh_instance)

func _get_shared_sphere_mesh() -> SphereMesh:
	if _shared_sphere_mesh == null:
		_shared_sphere_mesh = SphereMesh.new()
		_shared_sphere_mesh.radius = 1.0
		_shared_sphere_mesh.height = 2.0
		_shared_sphere_mesh.radial_segments = 18
		_shared_sphere_mesh.rings = 9
	return _shared_sphere_mesh

func _get_shared_visual_sphere_mesh() -> SphereMesh:
	if _shared_visual_sphere_mesh == null:
		_shared_visual_sphere_mesh = SphereMesh.new()
		_shared_visual_sphere_mesh.radius = 1.0
		_shared_visual_sphere_mesh.height = 2.0
		_shared_visual_sphere_mesh.radial_segments = 12
		_shared_visual_sphere_mesh.rings = 6
	return _shared_visual_sphere_mesh

func _get_shared_box_mesh() -> BoxMesh:
	if _shared_box_mesh == null:
		_shared_box_mesh = BoxMesh.new()
		_shared_box_mesh.size = Vector3.ONE
	return _shared_box_mesh

func _get_shared_cylinder_mesh() -> CylinderMesh:
	if _shared_cylinder_mesh == null:
		_shared_cylinder_mesh = CylinderMesh.new()
		_shared_cylinder_mesh.top_radius = 1.0
		_shared_cylinder_mesh.bottom_radius = 1.0
		_shared_cylinder_mesh.height = 1.0
		_shared_cylinder_mesh.radial_segments = 14
	return _shared_cylinder_mesh

func _get_shared_trunk_cylinder_mesh() -> CylinderMesh:
	if _shared_trunk_cylinder_mesh == null:
		_shared_trunk_cylinder_mesh = CylinderMesh.new()
		_shared_trunk_cylinder_mesh.top_radius = 0.55
		_shared_trunk_cylinder_mesh.bottom_radius = 1.0
		_shared_trunk_cylinder_mesh.height = 1.0
		_shared_trunk_cylinder_mesh.radial_segments = 14
	return _shared_trunk_cylinder_mesh

func _create_visual_gable_roof(node_name: String, pos: Vector3, width: float, depth: float, height: float, color: Color) -> void:
	var half_width := width * 0.5
	var half_depth := depth * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width, 0, -half_depth),
		Vector3(half_width, 0, -half_depth),
		Vector3(0, height, -half_depth),
		Vector3(-half_width, 0, half_depth),
		Vector3(half_width, 0, half_depth),
		Vector3(0, height, half_depth)
	])
	var indices := PackedInt32Array([
		0, 2, 1,
		3, 4, 5,
		0, 3, 5,
		0, 5, 2,
		1, 2, 5,
		1, 5, 4,
		0, 1, 4,
		0, 4, 3
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

func _make_material(color: Color, noisy: bool) -> StandardMaterial3D:
	var key := "%0.2f_%0.2f_%0.2f_%s" % [color.r, color.g, color.b, str(noisy)]
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	material.metallic = 0.0
	if noisy:
		var noise := FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.085
		noise.fractal_octaves = 3
		var texture := NoiseTexture2D.new()
		texture.width = 96
		texture.height = 96
		texture.noise = noise
		material.albedo_texture = texture
	material_cache[key] = material
	return material

func _make_textured_material(key: String, texture_path: String, fallback_color: Color, uv_scale: Vector3, cutout := false) -> StandardMaterial3D:
	var cache_key := "textured_%s_%s_%s" % [key, texture_path, str(cutout)]
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.albedo_color = fallback_color
	material.roughness = 0.92
	material.metallic = 0.0
	material.uv1_scale = uv_scale
	var tex = _load_texture_from_path(texture_path)
	if tex != null:
		material.albedo_texture = tex
		material.albedo_color = Color(1, 1, 1)
	if texture_path == POLY_RIVER_PEBBLES_DIFF:
		material.roughness = 1.0
	if cutout:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.18
	material_cache[cache_key] = material
	return material

func _make_rocky_ground_material(fallback_color: Color) -> StandardMaterial3D:
	if material_cache.has("rocky_ground"):
		return material_cache["rocky_ground"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.31, 0.30, 0.25).lerp(fallback_color, 0.18)
	material.roughness = 1.0
	material.metallic = 0.0
	material.uv1_scale = Vector3(30.0, 30.0, 1.0)
	var rocky_texture = _load_texture_from_path(POLY_ROCKY_TERRAIN_DIFF)
	if rocky_texture != null:
		material.albedo_texture = rocky_texture
	else:
		var noise := FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.18
		noise.fractal_octaves = 5
		var texture := NoiseTexture2D.new()
		texture.width = 256
		texture.height = 256
		texture.noise = noise
		material.albedo_texture = texture
	material_cache["rocky_ground"] = material
	return material

func _make_main_ground_material(fallback_color: Color) -> StandardMaterial3D:
	if material_cache.has("main_ground"):
		return material_cache["main_ground"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.46, 0.62, 0.32)
	material.roughness = 1.0
	material.metallic = 0.0
	material.uv1_scale = Vector3(44.0, 44.0, 1.0)
	var ground_texture = _load_texture_from_path(POLY_ROCKY_TERRAIN_DIFF)
	if ground_texture != null:
		material.albedo_texture = ground_texture
	else:
		var fallback_texture = _load_texture_from_path(POLY_GRASS_DRY_DIFF)
		if fallback_texture != null:
			material.albedo_texture = fallback_texture
	material_cache["main_ground"] = material
	return material

func _make_grass_blade_material() -> StandardMaterial3D:
	if material_cache.has("grass_blade"):
		return material_cache["grass_blade"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.19, 0.42, 0.12)
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_cache["grass_blade"] = material
	return material

func _make_river_water_material() -> Material:
	if material_cache.has("river_water"):
		return material_cache["river_water"]
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, unshaded;

uniform vec4 shallow_color : source_color = vec4(0.03, 0.48, 0.92, 0.93);
uniform vec4 deep_color : source_color = vec4(0.00, 0.24, 0.74, 0.96);
uniform vec4 night_shallow_color : source_color = vec4(0.035, 0.085, 0.12, 0.90);
uniform vec4 night_deep_color : source_color = vec4(0.012, 0.035, 0.060, 0.94);
uniform float night_amount = 0.0;
uniform float wave_height = 0.045;
uniform float flow_speed = 0.42;

void vertex() {
	float long_wave = sin(UV.x * 24.0 + TIME * 1.55);
	float cross_wave = sin(UV.y * 18.0 + UV.x * 10.0 - TIME * 2.10);
	float small_wave = sin((UV.x + UV.y) * 46.0 + TIME * 3.20);
	VERTEX.y += (long_wave * 0.55 + cross_wave * 0.32 + small_wave * 0.13) * wave_height;
}

void fragment() {
	float current = sin((UV.x + TIME * flow_speed) * 44.0 + UV.y * 8.0) * 0.5 + 0.5;
	float ripple = sin((UV.x * 90.0 - TIME * 3.0) + sin(UV.y * 20.0)) * 0.5 + 0.5;
	vec3 day_color = mix(shallow_color.rgb, deep_color.rgb, smoothstep(0.05, 0.95, UV.y));
	vec3 night_color = mix(night_shallow_color.rgb, night_deep_color.rgb, smoothstep(0.05, 0.95, UV.y));
	vec3 water_color = mix(day_color, night_color, clamp(night_amount, 0.0, 1.0));
	water_color += vec3(0.010, 0.030, 0.085) * current * (1.0 - night_amount * 0.82);
	water_color += vec3(0.006, 0.018, 0.060) * ripple * (1.0 - night_amount * 0.78);
	ALBEDO = water_color;
	ALPHA = mix(mix(shallow_color.a, deep_color.a, smoothstep(0.0, 1.0, UV.y)), mix(night_shallow_color.a, night_deep_color.a, smoothstep(0.0, 1.0, UV.y)), night_amount);
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.55;
	EMISSION = water_color * mix(0.18, 0.015, night_amount);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material_cache["river_water"] = material
	return material

func _make_hdri_sky_material() -> PanoramaSkyMaterial:
	for texture_path in SKY_HDRI_CANDIDATES:
		if not _resource_path_exists(texture_path):
			continue
		var panorama = _load_texture_from_path(texture_path)
		if panorama == null:
			continue
		var material := PanoramaSkyMaterial.new()
		material.panorama = panorama
		material.energy_multiplier = 0.82
		return material
	return null

func _get_billboard_textures(kind: String) -> Array:
	if billboard_texture_cache.has(kind):
		return billboard_texture_cache[kind].duplicate()
	var textures := []
	var dir := DirAccess.open("res://assets/external/tree_billboards/png")
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "png":
				var lower := file_name.to_lower()
				var include_file := kind == "tree" and (lower.begins_with("pine_") or lower.begins_with("lake_pine_"))
				if kind == "dead":
					include_file = lower.begins_with("flare_pine")
				elif kind == "underbrush":
					include_file = lower.find("broadleaf") >= 0
				if include_file:
					textures.append("res://assets/external/tree_billboards/png/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	if textures.is_empty():
		if kind == "dead":
			textures = DEAD_TREE_BILLBOARD_TEXTURES.duplicate()
		elif kind == "underbrush":
			textures = UNDERBRUSH_BILLBOARD_TEXTURES.duplicate()
		else:
			textures = TREE_BILLBOARD_TEXTURES.duplicate()
	textures.sort()
	billboard_texture_cache[kind] = textures
	return textures.duplicate()

func _get_cloud_billboard_textures() -> Array:
	if billboard_texture_cache.has("cloud"):
		return billboard_texture_cache["cloud"].duplicate()
	var textures := []
	for folder in ["res://assets/external/clouds", "res://assets/external/clouds/png"]:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var extension := file_name.get_extension().to_lower()
				if extension == "png" or extension == "webp" or extension == "jpg" or extension == "jpeg":
					textures.append(folder + "/" + file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	textures.sort()
	billboard_texture_cache["cloud"] = textures
	return textures.duplicate()

func _resource_path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if FileAccess.file_exists(path):
		return true
	if path.begins_with("res://"):
		return FileAccess.file_exists(ProjectSettings.globalize_path(path))
	return false

func _load_texture_from_path(texture_path: String):
	if texture_path_cache.has(texture_path):
		return texture_path_cache[texture_path]
	var result = null
	if ResourceLoader.exists(texture_path):
		var loaded_texture = load(texture_path)
		if loaded_texture is Texture2D:
			result = loaded_texture
	if result == null:
		var disk_path := ProjectSettings.globalize_path(texture_path) if texture_path.begins_with("res://") else texture_path
		var image := Image.load_from_file(disk_path)
		if image != null and not image.is_empty():
			image.generate_mipmaps()
			result = ImageTexture.create_from_image(image)
	texture_path_cache[texture_path] = result
	return result

func _make_tree_billboard_material(texture_path: String) -> StandardMaterial3D:
	var key := "tree_billboard_" + texture_path
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 1)
	material.roughness = 0.92
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.06
	material.albedo_texture = _load_texture_from_path(texture_path)
	material_cache[key] = material
	return material

func _make_cutout_material(key: String, texture_path: String, alpha_path: String) -> StandardMaterial3D:
	var cache_key := "cutout_" + key
	if material_cache.has(cache_key):
		return material_cache[cache_key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 1)
	material.roughness = 0.92
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.12
	material.albedo_texture = _load_texture_from_path(texture_path)
	material_cache[cache_key] = material
	return material

func _make_cloud_billboard_material(texture_path: String) -> StandardMaterial3D:
	var key := "cloud_billboard_" + texture_path
	if material_cache.has(key):
		return material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1, 1, 1, 0.88)
	material.roughness = 1.0
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material.albedo_texture = _load_texture_from_path(texture_path)
	material_cache[key] = material
	return material

func _make_cloud_material() -> StandardMaterial3D:
	if material_cache.has("cloud_layer"):
		return material_cache["cloud_layer"]
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.88, 0.91, 0.91, 0.22)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	material_cache["cloud_layer"] = material
	return material

func _create_loot_container(id: String, label: String, pos: Vector3, size: Vector3, color: Color, model_paths: Array = []):
	var visual_name := "LootContainer_" + id
	var spawned := false
	if not model_paths.is_empty():
		spawned = _try_instance_external_scene(model_paths, visual_name, pos, Vector3.ONE, Vector3(0, randf_range(0, 360), 0), true, 0.0)
	if not spawned:
		push_warning("No se crea contenedor %s porque falta/carga mal el asset .glb" % label)
		return null
	_mark_world_action_visual(visual_name)
	var container = LootContainerScript.new()
	container.name = id
	container.position = pos
	container.setup(id, label, size, color)
	container.set_meta("visual_name", visual_name)
	add_child(container)
	containers_by_id[id] = container
	return container

func _try_instance_external_scene(paths: Array, node_name: String, pos: Vector3, scale_value: Vector3, rot: Vector3, snap_to_ground := false, ground_y := 0.0) -> bool:
	for path in paths:
		if not _resource_path_exists(path):
			continue
		var path_str := str(path)
		var scene_resource = _get_external_scene_resource(path_str)
		var instance: Node = null
		if scene_resource is PackedScene:
			instance = (scene_resource as PackedScene).instantiate()
		elif scene_resource is Node3D:
			instance = (scene_resource as Node3D).duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION)
		if instance is Node3D:
			var node := instance as Node3D
			if not _display_props_stripped.has(path_str):
				_strip_display_props(node)
				_display_props_stripped[path_str] = true
			node.name = node_name
			node.add_to_group("world_action_visual")
			node.position = pos
			node.scale = scale_value
			node.rotation_degrees = rot
			add_child(node)
			if snap_to_ground:
				_snap_node_bottom_to_y_cached(node, ground_y, path_str, scale_value)
			return true
	return false

# Removes the turntable/display "Circle" plane and any baked lights that some
# downloaded Sketchfab models ship with (e.g. the concrete road barrier showed a
# big white disc on the ground).
func _strip_display_props(root: Node) -> void:
	var to_remove: Array = []
	_collect_display_props(root, to_remove)
	for node in to_remove:
		if is_instance_valid(node):
			var parent := (node as Node).get_parent()
			if parent != null:
				parent.remove_child(node)
			(node as Node).queue_free()

func _collect_display_props(node: Node, result: Array) -> void:
	if node is Light3D:
		result.append(node)
		return
	var lower := node.name.to_lower()
	if lower.begins_with("circle") or lower == "sun" or lower.begins_with("turntable") or lower.begins_with("ground_plane"):
		result.append(node)
		return
	for child in node.get_children():
		_collect_display_props(child, result)

func _get_external_scene_resource(path: String):
	if external_scene_cache.has(path):
		return external_scene_cache[path]
	var scene_resource = null
	if ResourceLoader.exists(path):
		var loaded_resource = load(path)
		if loaded_resource is PackedScene:
			scene_resource = loaded_resource
	if scene_resource == null and path.get_extension().to_lower() == "obj":
		scene_resource = SimpleObjLoaderScript.new().load_node3d(path, _external_obj_color(path))
	if scene_resource == null and (path.get_extension().to_lower() == "gltf" or path.get_extension().to_lower() == "glb"):
		scene_resource = _load_gltf_scene_from_file(path)
	if scene_resource != null:
		if scene_resource is Node3D:
			_precompute_snap_offset(path, scene_resource as Node3D)
		external_scene_cache[path] = scene_resource
	return scene_resource

func _precompute_snap_offset(path: String, node: Node3D) -> void:
	var min_y := _compute_hierarchy_min_y(node, Transform3D.IDENTITY)
	if min_y < 999999.0:
		_snap_offset_cache[path] = min_y

func _compute_hierarchy_min_y(root: Node, parent_xform: Transform3D) -> float:
	var min_y := 1000000.0
	if root is MeshInstance3D:
		var mi := root as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.get_aabb()
			var world_aabb := parent_xform * mi.transform * aabb
			min_y = min(min_y, world_aabb.position.y)
	for child in root.get_children():
		if child is Node3D:
			var child_xform := parent_xform * (child as Node3D).transform
			min_y = min(min_y, _compute_hierarchy_min_y(child, child_xform))
	return min_y

func _external_obj_color(path: String) -> Color:
	var file_name := path.get_file().to_lower()
	if file_name.find("apple") >= 0:
		return Color(0.56, 0.08, 0.05)
	if file_name.find("orange") >= 0:
		return Color(0.82, 0.34, 0.05)
	if file_name.find("steak") >= 0:
		return Color(0.44, 0.12, 0.08)
	if file_name.find("fish") >= 0:
		return Color(0.18, 0.24, 0.22)
	return Color(0.68, 0.64, 0.52)

func _load_gltf_scene_from_file(path: String):
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(disk_path, state)
	if error != OK:
		return null
	var generated_scene := document.generate_scene(state)
	if generated_scene is Node3D:
		return generated_scene
	if generated_scene != null:
		generated_scene.queue_free()
	return null

func _create_concrete_barrier(node_name: String, pos: Vector3, rot: Vector3) -> void:
	if not _try_instance_external_scene([ROOT_BARRIER_MODEL], node_name, pos, Vector3.ONE * 0.0042, rot, true, 0.0):
		return
	var node := get_node_or_null(NodePath(node_name)) as Node3D
	if node != null:
		_add_convex_collision_to_meshes(node)

func _add_convex_collision_to_meshes(root: Node) -> void:
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh != null:
			mesh_instance.create_convex_collision()

func _override_tree_foliage_green(_node_name: String) -> void:
	if get_child_count() == 0:
		return
	var node := get_child(get_child_count() - 1) as Node3D
	if node == null:
		return
	call_deferred("_apply_foliage_green_to_node", node)

func _apply_foliage_green_to_node(node: Node3D) -> void:
	var meshes: Array = []
	_collect_mesh_instances(node, meshes)
	if _shared_foliage_green_mat == null:
		_shared_foliage_green_mat = StandardMaterial3D.new()
		_shared_foliage_green_mat.albedo_color = Color(0.15, 0.42, 0.10)
		_shared_foliage_green_mat.roughness = 0.9
		_shared_foliage_green_mat.metallic = 0.0
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.material_override = _shared_foliage_green_mat

func _snap_node_bottom_to_y(node: Node3D, ground_y: float) -> void:
	node.force_update_transform()
	var meshes := []
	_collect_mesh_instances(node, meshes)
	var min_y := 1000000.0
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.force_update_transform()
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		min_y = min(min_y, world_aabb.position.y)
	if min_y < 999999.0:
		node.global_position.y += ground_y - min_y
		node.force_update_transform()

func _snap_node_bottom_to_y_cached(node: Node3D, ground_y: float, path: String, scale_value: Vector3) -> void:
	if _snap_offset_cache.has(path):
		var unit_offset: float = float(_snap_offset_cache[path])
		node.position.y += ground_y - unit_offset * scale_value.y
		return
	node.force_update_transform()
	var meshes := []
	_collect_mesh_instances(node, meshes)
	var min_local_y := 1000000.0
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.force_update_transform()
		var local_aabb: AABB = mesh_instance.get_aabb()
		var world_aabb: AABB = mesh_instance.global_transform * local_aabb
		var local_bottom := world_aabb.position.y - node.global_position.y
		min_local_y = min(min_local_y, local_bottom)
	if min_local_y < 999999.0:
		var unit_offset := min_local_y / scale_value.y
		_snap_offset_cache[path] = unit_offset
		node.position.y += ground_y - min_local_y

func _collect_mesh_instances(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		_collect_mesh_instances(child, result)

func _get_node_world_aabb_height(node: Node3D) -> float:
	node.force_update_transform()
	var meshes := []
	_collect_mesh_instances(node, meshes)
	var min_y := 1000000.0
	var max_y := -1000000.0
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		min_y = min(min_y, world_aabb.position.y)
		max_y = max(max_y, world_aabb.position.y + world_aabb.size.y)
	if max_y > min_y:
		return max_y - min_y
	return 0.0

func _shuffled_paths(paths: Array) -> Array:
	var shuffled := paths.duplicate()
	shuffled.shuffle()
	return shuffled

func _spawn_external(path: String, node_name: String, pos: Vector3, scale_value: Vector3, rot: Vector3, collision_size: Vector3 = Vector3.ZERO) -> bool:
	if not _try_instance_external_scene([path], node_name, pos, scale_value, rot, true, 0.0):
		return false
	if collision_size != Vector3.ZERO:
		var node := get_node_or_null(node_name)
		if node != null and node is Node3D:
			var dyn_h := _get_node_world_aabb_height(node as Node3D) + 0.3
			if dyn_h > 0.5:
				collision_size.y = dyn_h
		_create_invisible_collision_box_rotated(node_name + "Collision", pos, collision_size, rot.y)
	return true

func _create_label(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.modulate = Color(0.82, 0.80, 0.70)
	label.outline_modulate = Color(0.02, 0.02, 0.02)
	label.outline_size = 8
	label.position = pos
	add_child(label)

func _containers_to_array() -> Array:
	var data := []
	for id in containers_by_id:
		data.append(containers_by_id[id].to_dict())
	return data

func _world_actions_to_array() -> Array:
	var data := []
	for id in world_actions_by_id:
		data.append(world_actions_by_id[id].to_dict())
	return data

func _load_if_available() -> void:
	var data = SaveSystemScript.load_game()
	if data.is_empty():
		return
	if int(data.get("balance_version", 0)) < SAVE_BALANCE_VERSION:
		_migrate_old_starting_inventory(data)
	if data.get("player", null) is Dictionary:
		player.from_dict(data["player"])
	if data.get("day_cycle", null) is Dictionary:
		day_cycle.from_dict(data["day_cycle"])
	if data.get("radio", null) is Dictionary:
		radio.from_dict(data["radio"])
	if data.get("containers", null) is Array:
		for raw_container in data["containers"]:
			if raw_container is Dictionary:
				var id := str(raw_container.get("id", ""))
				if containers_by_id.has(id):
					containers_by_id[id].from_dict(raw_container)
	if data.get("world_actions", null) is Array:
		for raw_action in data["world_actions"]:
			if raw_action is Dictionary:
				var id := str(raw_action.get("id", ""))
				if world_actions_by_id.has(id):
					world_actions_by_id[id].from_dict(raw_action)
					if world_actions_by_id[id].depleted:
						_hide_action_visual(world_actions_by_id[id])
						if world_actions_by_id[id].action_type == "fell_tree":
							_create_cut_tree_remains(world_actions_by_id[id].position)
	hud.show_notice("Partida cargada.")

func _migrate_old_starting_inventory(data: Dictionary) -> void:
	if not (data.get("player", null) is Dictionary):
		return
	var player_data := data["player"] as Dictionary
	player_data["position"] = [8.0, 0.4, 2.5]
	if not (player_data.get("inventory", null) is Array):
		data["balance_version"] = SAVE_BALANCE_VERSION
		return
	var old_inventory := player_data["inventory"] as Array
	var legacy_names := {
		"Lata de comida": true,
		"Botella de agua": true,
		"Venda": true,
		"Linterna": true,
		"Pilas": true,
		"Cuchillo": true,
		"Mochila pequena": true
	}
	var migrated_inventory := []
	for raw_item in old_inventory:
		if raw_item is Dictionary:
			var item_name := str(raw_item.get("name", ""))
			if legacy_names.has(item_name):
				continue
		migrated_inventory.append(raw_item)
	player_data["inventory"] = migrated_inventory

func _world_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(int(round(pos.x / _nav_cell_size)) + _nav_grid_size / 2, int(round(pos.z / _nav_cell_size)) + _nav_grid_size / 2)

func _grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x - _nav_grid_size / 2) * _nav_cell_size, 0.0, float(cell.y - _nav_grid_size / 2) * _nav_cell_size)

func _build_nav_grid() -> void:
	_nav_grid.clear()
	for blocker in wildlife_blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var radius: float = float(blocker.get("radius", 1.8))
		var center_cell := _world_to_grid(blocker_pos)
		var cell_radius := int(ceil(radius / _nav_cell_size)) + 1
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
				if cell.x < 0 or cell.x >= _nav_grid_size or cell.y < 0 or cell.y >= _nav_grid_size:
					continue
				var world_pos := _grid_to_world(cell)
				if Vector2(world_pos.x - blocker_pos.x, world_pos.z - blocker_pos.z).length() <= radius:
					_nav_grid[cell] = true
	_nav_grid_built = true

func is_nav_cell_blocked(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.x >= _nav_grid_size - 1 or cell.y < 1 or cell.y >= _nav_grid_size - 1:
		return true
	return _nav_grid.has(cell)

func find_path_wildlife(start: Vector3, goal: Vector3) -> Array:
	if not _nav_grid_built:
		return [goal]
	var start_cell := _world_to_grid(start)
	var goal_cell := _world_to_grid(goal)
	if start_cell == goal_cell:
		return [goal]
	if is_nav_cell_blocked(goal_cell):
		goal_cell = _nearest_free_cell(goal_cell)
		if goal_cell == start_cell:
			return [goal]
	if is_nav_cell_blocked(start_cell):
		start_cell = _nearest_free_cell(start_cell)
		if start_cell == goal_cell:
			return [goal]
	return _astar(start_cell, goal_cell, start)

func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	for radius in range(1, 10):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var candidate := Vector2i(cell.x + dx, cell.y + dy)
				if not is_nav_cell_blocked(candidate):
					return candidate
	return cell

func _astar(start_cell: Vector2i, goal_cell: Vector2i, start_world: Vector3) -> Array:
	var came_from: Dictionary = {}
	var visited: Dictionary = {}
	var queue: Array = [start_cell]
	visited[start_cell] = true
	var head := 0
	var max_iterations := 4000
	var iterations := 0
	while head < queue.size() and iterations < max_iterations:
		iterations += 1
		var current: Vector2i = queue[head]
		head += 1
		if current == goal_cell:
			return _reconstruct_path(came_from, current, start_world)
		for neighbor in _get_neighbors(current):
			if visited.has(neighbor):
				continue
			if is_nav_cell_blocked(neighbor):
				continue
			visited[neighbor] = true
			came_from[neighbor] = current
			queue.append(neighbor)
	return [_grid_to_world(goal_cell)]

func _get_neighbors(cell: Vector2i) -> Array:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x + 1, cell.y + 1),
		Vector2i(cell.x + 1, cell.y - 1),
		Vector2i(cell.x - 1, cell.y + 1),
		Vector2i(cell.x - 1, cell.y - 1)
	]

func _reconstruct_path(came_from: Dictionary, current: Vector2i, start_world: Vector3) -> Array:
	var cells: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
	var path: Array = []
	for i in range(cells.size()):
		if i == 0:
			continue
		path.append(_grid_to_world(cells[i]))
	if path.is_empty():
		path.append(_grid_to_world(cells[0]))
	return path
