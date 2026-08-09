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
const CelestialSystemScript = preload("res://scripts/CelestialSystem.gd")

const MAP_EXTENT := 250.0

var player
var hud
var day_cycle
var radio
var audio_system
var celestial: Node3D = null
var containers_by_id := {}

# Multiplayer
var net = null
var remote_players: Dictionary = {}  # peer_id -> Node3D (remote player avatar)
var server_proxies: Dictionary = {}  # peer_id -> Node3D (server-side proxy for wildlife AI)
var proxy_by_client_id: Dictionary = {}  # client_id -> Node3D (persistent proxy)
var pending_client_ids: Dictionary = {}  # peer_id -> client_id (until proxy is created)
var _net_sync_timer := 0.0
var _inv_sync_timer := 0.0
var _animal_sync_timer := 0.0
var _water_night_timer := 0.0
var _shelter_check_timer := 0.0
var _cached_in_house := false
var _cached_near_shelter := false
var _door_cache_timer := 0.0
var _campfire_emit_timer := 0.0
var _animal_debug_timer := 0
var _client_animal_debug_timer := 0
var puppet_animals: Dictionary = {}  # animal_id -> WildlifeController (puppet)
var world_actions_by_id := {}
var _depleted_action_ids: Array = []
var _dropped_items: Array = []
var _built_campfires: Array = []
var _built_shelters: Array = []
var _lit_campfires: Array = []
var _server_door_states: Dictionary = {}
var _pending_open_doors: Array = []
var _pending_restore_data: Array = []
var _tree_id_counter := 0
var _tree_registry: Array = [] # {pos, visual_name, id, active}
var _tree_activation_radius := 60.0
var _tree_deactivation_radius := 80.0
var _tree_check_timer := 0.0
var _bush_id_counter := 0
var material_cache := {}
var billboard_texture_cache := {}
var texture_path_cache := {}
var external_scene_cache := {}
var _forest_tree_meshes: Array = []
var _cached_leafy_material: StandardMaterial3D = null
var _mountain_shared_material: StandardMaterial3D = null
var _generated_hills: Array = []
var _roof_texture: Texture2D = null
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
var _wildlife_respawn_timer := 0.0
var campfire_positions: Array = []
var campfire_fire_timers: Dictionary = {}
var _nav_grid: Dictionary = {}
var _nav_grid_size := 182
var _nav_cell_size := 2.0
var _door_open_cache: Dictionary = {}
var _nav_grid_built := false
var game_over := false
var _drink_hold_actor = null
var _drink_hold_timer := 0.0
const _DRINK_HOLD_TIME := 1.5

var world_streaming_mgr: WorldStreamingManager = null
var sector_persistence_mgr: SectorPersistenceManager = null
var _debug_overlay: CanvasLayer = null
var _debug_label: Label = null
var _debug_visible: bool = false
var _streaming_positions: Array[Vector3] = []

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
const LEAFY_FLOOR_MODEL := "res://assets/models/environment/leafy_floor.glb"
const POLY_ROCKY_TERRAIN_DIFF := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_diff_4k.jpg"
const POLY_ROCKY_TERRAIN_DISP := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_disp_4k.png"
const POLY_ROCKY_TERRAIN_SPEC := "res://assets/external/polyhaven/rocky_terrain_02/textures/rocky_terrain_02_spec_4k.png"
const POLY_RIVER_PEBBLES_DIFF := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_diff_4k.jpg"
const POLY_RIVER_PEBBLES_DISP := "res://assets/external/polyhaven/ganges_river_pebbles/textures/ganges_river_pebbles_disp_4k.png"
const POLY_BOULDER_DIFF := "res://assets/external/polyhaven/namaqualand_boulder_02/textures/namaqualand_boulder_02_diff_4k.jpg"
const POLY_ROCK_07_DIFF := "res://assets/external/polyhaven/rock_07/textures/rock_07_diff_4k.jpg"
const POLY_CABINET_DIFF := "res://assets/external/polyhaven/painted_wooden_cabinet/textures/painted_wooden_cabinet_diff_4k.jpg"
const POLY_EQUIPMENT_DIR := "res://assets/external/polyhaven/"
const POLY_GARDEN_GLOVES_MODEL := POLY_EQUIPMENT_DIR + "garden_gloves_01/garden_gloves_01_1k.gltf"
const POLY_FISHERMANS_HAT_MODEL := POLY_EQUIPMENT_DIR + "fishermans_hat/fishermans_hat_1k.gltf"
const ROOT_GLB_DIR := "res://assets/external/realistic/root_glb/"
const TEX_DIR := "res://assets/external/textures/"
const TEX_PLASTER_DIFF := TEX_DIR + "plaster_brick_01/plaster_brick_01_diff_4k.jpg"
const TEX_PLASTER_ROUGH := TEX_DIR + "plaster_brick_01/plaster_brick_01_rough_4k.jpg"
const TEX_RUST_DIFF := TEX_DIR + "rusty_metal_03/rusty_metal_03_diff_4k.jpg"
const TEX_WOOD_FLOOR_DIFF := TEX_DIR + "wood_floor_deck/wood_floor_deck_diff_4k.jpg"
const TEX_CONCRETE_DIFF := TEX_DIR + "concrete_floor_02/concrete_floor_02_diff_4k.jpg"
const TEX_BRICK_DIFF := TEX_DIR + "red_brick_03/red_brick_03_diff_4k.jpg"
const BED_MODEL_PATH := "res://assets/models/props/post_apocalyptic_bed.glb"
const BACKPACK_ITEM_SCENE := "res://scenes/items/BackpackItem.tscn"
const WATER_BOTTLE_ITEM_SCENE := "res://scenes/items/WaterBottleItem.tscn"
const PLASTIC_BOTTLE_MODEL := "res://assets/models/props/plastic_water_bottle.glb"
const CANNED_FOOD_LOW_MODEL := "res://assets/models/props/canned_food_low.glb"
const FOOD_CAN_415G_MODEL := "res://assets/models/props/food_can_415g.glb"
const ROOT_BACKPACK_MODEL := ROOT_GLB_DIR + "low_poly_game_ready_military_tactical_backpack.glb"
const ABANDONED_JUNK_CAR_MODEL := ROOT_GLB_DIR + "abandoned_junk_car.glb"
const SCRAP_BARRICADE_CAR_MODEL := ROOT_GLB_DIR + "scrap_barricade_car_free_raw_scan.glb"
const SCRAP_CAR_Y_CORRECTION := -0.6
const ROOT_CONTAINER_MODEL := ROOT_GLB_DIR + "shipping_container_anos.glb"
const ROOT_FURNITURE_MODEL := ROOT_GLB_DIR + "tinylivingpack.glb"
const POST_APO_FURNITURE_MODEL := "res://assets/models/props/post_apocalyptic_furniture.glb"
const POST_APO_FRIDGE_MODEL := "res://assets/models/props/post_apocalyptic_fridge.glb"
const TOILET_MODEL := "res://assets/models/props/souce_toilet_dirty_2.glb"
const BATHROOM_SINK_MODEL := "res://assets/models/props/source_bathroom_sink.glb"
const KITCHEN_STOVE_MODEL := "res://assets/models/props/old_rusty_kitchen_stove__dirty_damaged.glb"
const SINK_CABINET_MODEL := "res://assets/models/props/clogged_old_sink_cabinet.glb"
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
const FOREST_TREE_PACK_MODEL := "res://assets/models/environment/low_poly_forest_tree_pack.glb"
const MODULAR_ROOF_MODEL := "res://assets/models/environment/modular_roof.glb"
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
	"res://assets/hdri/kloofendal_48d_partly_cloudy_4k.exr",
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
]
const REAL_VAN_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Vehicles/glTF/Vehicle_Truck.gltf"

const DOOR_MODELS := [
	"res://assets/external/doors/simple_room_door.glb",
]

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
	{"center": Vector3(-25, 0, -18), "half": Vector2(3.0, 2.5)},
	{"center": Vector3(-38, 0, 18), "half": Vector2(3.0, 2.5)},
	{"center": Vector3(23, 0, 18), "half": Vector2(3.0, 2.5)},
	{"center": Vector3(42, 0, 26), "half": Vector2(3.0, 2.5)},
	{"center": Vector3(-12, 0, 42), "half": Vector2(3.0, 2.5)},
	{"center": Vector3(33, 0, -30), "half": Vector2(2.0, 1.5)},
	{"center": Vector3(45, 0, 0), "half": Vector2(2.0, 1.5)},
	{"center": Vector3(-42, 0, -42), "half": Vector2(1.5, 1.5)},
	{"center": Vector3(14, 0, -50), "half": Vector2(1.5, 2.0)},
	{"center": Vector3(56, 0, 38), "half": Vector2(1.5, 2.0)},
	{"center": Vector3(58, 0, -52), "half": Vector2(1.5, 2.0)}
]

const WORLD_SEED := 1337

var _world_rng := RandomNumberGenerator.new()

var _loading_overlay: CanvasLayer = null
var _loading_label: Label = null
var _loading_countdown: float = 0.0


#region INICIALIZACIÓN Y CICLO DE VIDA
func _ready() -> void:
	seed(WORLD_SEED)
	_world_rng.seed = WORLD_SEED
	
	world_streaming_mgr = WorldStreamingManager.new()
	add_child(world_streaming_mgr)
	world_streaming_mgr.setup(self)

	sector_persistence_mgr = SectorPersistenceManager.new()
	add_child(sector_persistence_mgr)

	_create_debug_overlay()
	# Get NetworkManager (autoload)
	net = get_node("/root/NetworkManager")
	if net != null:
		net.player_connected.connect(_on_remote_player_connected)
		net.player_disconnected.connect(_on_remote_player_disconnected)
		if not net.is_dedicated_server:
			# Spawn any already-connected players
			for pid in net.players.keys():
				if pid != net.get_my_id():
					_spawn_remote_player(pid)
	if net != null and net.is_dedicated_server:
		# Server only needs collision + nav grid + wildlife AI — skip all visuals
		_create_map()
		return
	# Loading overlay with countdown: show it BEFORE heavy world generation
	_loading_overlay = CanvasLayer.new()
	_loading_overlay.name = "LoadingOverlay"
	_loading_overlay.layer = 100
	var _loading_rect := ColorRect.new()
	_loading_rect.color = Color(0.02, 0.02, 0.03)
	_loading_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(_loading_rect)
	_loading_label = Label.new()
	_loading_label.text = "Generando mundo..."
	_loading_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 72)
	_loading_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_loading_overlay.add_child(_loading_label)
	add_child(_loading_overlay)
	# Force a render of the overlay before heavy world generation
	await get_tree().process_frame
	_create_environment()
	_create_day_night()
	await _create_map()
	_create_player()
	if net != null and net.is_host and not net.is_dedicated_server:
		_send_character_appearance()
	if net == null or not net.is_dedicated_server:
		_create_audio()
		_create_hud()
	_apply_pending_doors()
	_apply_pending_restore()
	# Remove loading overlay immediately — everything is loaded
	if _loading_overlay != null:
		_loading_overlay.queue_free()
		_loading_overlay = null
		_loading_label = null
	if hud != null:
		hud.show_notice("Haz clic en la ventana para capturar el raton. Sobrevive.")

func _start_loading_countdown() -> void:
	_loading_countdown = 3.0

func _process_loading_countdown(delta: float) -> void:
	if _loading_overlay == null:
		return
	if _loading_countdown <= 0.0:
		return
	_loading_countdown -= delta
	if _loading_countdown <= 0.0:
		_loading_overlay.queue_free()
		_loading_overlay = null
		_loading_label = null
		return
	var secs := ceili(_loading_countdown)
	if _loading_label != null:
		_loading_label.text = "Iniciando... %d" % secs

func _exit_tree() -> void:
	# Force final state + inventory sync before disconnecting
	if net != null and net.is_connected and not net.is_dedicated_server:
		if not _quit_final_sent:
			_send_final_state()
	for cached_scene in external_scene_cache.values():
		if cached_scene is Node:
			(cached_scene as Node).free()
	external_scene_cache.clear()

func _send_final_state() -> void:
	if net == null or not net.is_connected:
		return
	if net.is_dedicated_server:
		return
	if player == null or not is_instance_valid(player):
		return
	var pos: Vector3 = player.global_position
	var rot: float = player.rotation.y
	var anim: String = "idle"
	if player.has_method("_get_current_anim"):
		anim = player._get_current_anim()
	var clothing: String = ""
	if player._equipped_slots != null and not player._equipped_slots.is_empty():
		var clothing_items: Array = []
		for slot in player._equipped_slots.keys():
			var item_name: String = str(player._equipped_slots[slot])
			if not item_name.is_empty():
				clothing_items.append(item_name)
		clothing = ",".join(clothing_items)
	var held: String = ""
	if player.inventory != null and player.inventory.items.size() > 0:
		var hi: int = clampi(player.held_index, 0, player.inventory.items.size() - 1)
		if player.inventory.items[hi] != null:
			held = player.inventory.items[hi].item_name
	var backpack: String = player.equipped_backpack
	var sleeping: bool = player.is_sleeping
	var sitting: bool = player.is_sitting
	var prone: bool = player.is_prone
	var crouching: bool = player.is_crouching
	# Send reliable final position and state to server
	net.final_player_state.rpc_id(1, pos, rot, anim, clothing, held, backpack, sleeping, sitting, prone, crouching)
	# Also send final inventory
	_sync_local_player_inventory()


var _quit_countdown := 0.0
var _quit_active := false
var _quit_final_sent := false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_0:
		_toggle_debug_overlay()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q and event.shift_pressed:
		if not _quit_active:
			_quit_active = true
			_quit_countdown = 5.0
			_quit_final_sent = false
			if hud != null:
				hud.show_notice("Saliendo en 5...")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _quit_active:
		_quit_active = false
		_quit_countdown = 0.0
		_quit_final_sent = false
		if hud != null:
			hud.show_notice("Salida cancelada.")
		return
	if game_over:
		return
	if hud != null and hud.inventory_visible and event is InputEventMouseButton and event.pressed:
		if hud.handle_context_menu_click(event.position, event.button_index):
			return
		if hud.is_click_on_slot(event.position):
			hud.handle_slot_click(event.position, event.button_index)
			return
	var tab_pressed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB
	if hud != null and (event.is_action_pressed("toggle_inventory") or tab_pressed):
		hud.toggle_inventory()

# _input manejado por el HUD y el PlayerController; Main no procesa input directo
func _input(_event: InputEvent) -> void:
	return

func _process(delta: float) -> void:
	_tree_check_timer += delta
	if _tree_check_timer > 0.5:
		_tree_check_timer = 0.0
		_update_tree_interactions()
	if world_streaming_mgr != null:
		_streaming_positions.clear()
		if player != null and is_instance_valid(player):
			_streaming_positions.append(player.global_position)
		for r_player in remote_players.values():
			if r_player != null and is_instance_valid(r_player):
				_streaming_positions.append(r_player.global_position)
		world_streaming_mgr.update_player_positions(_streaming_positions)

	if _debug_visible and _debug_label != null:
		_update_debug_overlay_text()

	if _loading_overlay != null:
		_process_loading_countdown(delta)
	if _quit_active:
		_quit_countdown -= delta
		if not _quit_final_sent and _quit_countdown <= 1.0:
			_quit_final_sent = true
			_send_final_state()
		if _quit_countdown <= 0.0:
			_quit_active = false
			get_tree().quit()
			return
		if hud != null:
			hud.show_notice("Saliendo en %d..." % int(ceil(_quit_countdown)))
	if net != null and net.is_dedicated_server:
		# Update proxy positions from client sync data
		_update_server_proxies(delta)
		# Server broadcasts animal state to clients
		_animal_sync_timer += delta
		if _animal_sync_timer >= 0.1:
			_animal_sync_timer = 0.0
			_broadcast_animals()
		# Tick campfire fires on server
		_tick_campfire_fires()
		# Respawn wildlife periodically
		_wildlife_respawn_timer += delta
		if _wildlife_respawn_timer >= 30.0:
			_wildlife_respawn_timer = 0.0
			_check_wildlife_respawn()
		return
	if net != null and net.is_connected and not net.is_host:
		_update_puppet_animals()
		if _client_animal_debug_timer < 100:
			_client_animal_debug_timer += 1
	if player == null or day_cycle == null:
		_process_pending_puppets()
		return
	if game_over:
		return
	_process_pending_puppets()
	# Keep the star/moon dome centered on the player and refresh the real
	# star positions periodically so the sky slowly rotates like the real one.
	if day_cycle != null and player != null:
		if day_cycle.star_field != null:
			day_cycle.star_field.global_position = player.global_position
		if day_cycle.moon_field != null:
			day_cycle.moon_field.global_position = player.global_position
	if celestial != null:
		celestial._star_update_accum += delta
		if celestial._star_update_accum >= 2.0:
			celestial._star_update_accum = 0.0
			celestial.update_real_star_positions()
	_shelter_check_timer += delta
	if _shelter_check_timer >= 0.5:
		_shelter_check_timer = 0.0
		_cached_near_shelter = _is_near_built_shelter(player.global_position)
		_cached_in_house = _is_player_in_house(player.global_position)
	var near_built_shelter := _cached_near_shelter
	player.in_shelter = player.global_position.distance_to(Vector3.ZERO) < 8.5 or near_built_shelter
	var in_house := _cached_in_house
	player.set_meta("in_house", in_house)
	player.set_meta("in_built_shelter", near_built_shelter)
	var is_sheltered: bool = player.in_shelter or in_house
	var ambient_temp: float = day_cycle.get_ambient_temperature()
	# Use real weather temperature when available
	if hud != null and hud._real_temp_parsed != -999.0:
		ambient_temp = hud._real_temp_parsed
	# Houses protect from extreme temperatures
	if in_house:
		ambient_temp = clamp(ambient_temp, 12.0, 28.0)
	# Built shelters protect from extreme temperatures
	if near_built_shelter:
		ambient_temp = clamp(ambient_temp, 10.0, 30.0)
	player.stats.tick(delta, player.is_sprinting, ambient_temp, is_sheltered, 0.0, day_cycle.is_night(), player.is_moving, player.is_sleeping)
	_apply_campfire_effect(player, delta)
	_door_cache_timer += delta
	if _door_cache_timer >= 0.5:
		_door_cache_timer = 0.0
		_update_door_open_cache()
	_apply_pending_doors()
	_water_night_timer += delta
	if _water_night_timer >= 2.0:
		_water_night_timer = 0.0
		_update_water_night_amount()
	_tick_world_actions(delta)
	_tick_drink_hold(delta)
	_tick_campfire_fires()
	# Network sync
	if net != null and net.is_connected:
		_net_sync_timer += delta
		if _net_sync_timer >= 0.05:
			_net_sync_timer = 0.0
			_sync_local_player_state()
		_inv_sync_timer += delta
		if _inv_sync_timer >= 2.0:
			_inv_sync_timer = 0.0
			_sync_local_player_inventory()
		_update_remote_players()

func _tick_campfire_fires() -> void:
	if campfire_fire_timers.is_empty():
		return
	var now := Time.get_ticks_msec()
	var expired := []
	for fire_name in campfire_fire_timers.keys():
		if now >= campfire_fire_timers[fire_name]:
			expired.append(fire_name)
	for fire_name in expired:
		campfire_fire_timers.erase(fire_name)
		# Remove light, particles and smoke
		var light_node := get_node_or_null(fire_name + "Light")
		if light_node != null:
			light_node.queue_free()
		var particles_node := get_node_or_null(fire_name + "Particles")
		if particles_node != null:
			particles_node.queue_free()
		var smoke_node := get_node_or_null(fire_name + "Smoke")
		if smoke_node != null:
			smoke_node.queue_free()
		# Find and remove the WorldAction and visual structure for this campfire
		var expired_action_id := ""
		for action_id in world_actions_by_id.keys():
			var action = world_actions_by_id[action_id]
			if action != null and is_instance_valid(action) and action.get_meta("fire_name", "") == fire_name:
				expired_action_id = action_id
				var visual_name := str(action.get_meta("visual_name", ""))
				if not visual_name.is_empty():
					var vis_node := get_node_or_null(visual_name)
					if vis_node != null:
						vis_node.queue_free()
				# Remove fallback stones/ash
				var cf_id := str(action_id)
				var ash_node := get_node_or_null("PlayerCampfireAsh_" + cf_id)
				if ash_node != null:
					ash_node.queue_free()
				for i in range(8):
					var stone := get_node_or_null("PlayerCampfireStone_%s_%d" % [cf_id, i])
					if stone != null:
						stone.queue_free()
				action.queue_free()
				world_actions_by_id.erase(action_id)
				break
		# Remove from campfire_positions
		for i in range(campfire_positions.size() - 1, -1, -1):
			if campfire_positions[i] is Vector3:
				campfire_positions.remove_at(i)
				break
		# Remove from _lit_campfires and _built_campfires
		for i in range(_lit_campfires.size() - 1, -1, -1):
			if _lit_campfires[i] is Dictionary and _lit_campfires[i].get("fire_name", "") == fire_name:
				_lit_campfires.remove_at(i)
		if not expired_action_id.is_empty():
			for i in range(_built_campfires.size() - 1, -1, -1):
				if _built_campfires[i] is Dictionary and _built_campfires[i].get("id", "") == expired_action_id:
					_built_campfires.remove_at(i)
		if player != null:
			player.notice.emit("La fogata se ha apagado.")
		_save_world_change_silent()

func get_lit_campfire_positions() -> Array:
	var positions := []
	var now := Time.get_ticks_msec()
	for fire_name in campfire_fire_timers.keys():
		if now < campfire_fire_timers[fire_name]:
			var light_node := get_node_or_null(fire_name + "Light")
			if light_node != null and light_node is Node3D:
				positions.append((light_node as Node3D).global_position)
	return positions

func _apply_campfire_effect(player_node: Node3D, delta: float) -> void:
	if campfire_positions.is_empty():
		return
	var ppos := player_node.global_position
	var emit_stats := false
	for fire_pos in campfire_positions:
		var dist := ppos.distance_to(Vector3(fire_pos.x, ppos.y, fire_pos.z))
		if dist < 1.2:
			player_node.stats.health -= 5.0 * delta
			emit_stats = true
			if randf() < delta * 2.0:
				player_node.notice.emit("Te quemas al estar demasiado cerca del fuego.")
		elif dist < 4.0:
			var warmth_factor: float = 1.0 - (dist - 1.2) / 2.8
			player_node.stats.body_temperature = min(38.0, player_node.stats.body_temperature + warmth_factor * 3.0 * delta)
			player_node.stats.wetness = max(0.0, player_node.stats.wetness - warmth_factor * 0.05 * delta)
			emit_stats = true
	if emit_stats:
		_campfire_emit_timer += delta
		if _campfire_emit_timer >= 0.25:
			_campfire_emit_timer = 0.0
			player_node.stats.changed.emit()

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

# Sistema celestial (sol/luna) sigue al jugador; actualmente deshabilitado
func _update_celestial_follow() -> void:
	return

func _update_water_night_amount() -> void:
	if day_cycle == null:
		return
	var day_amount: float = clamp(sin((day_cycle.time_of_day - 6.0) / 15.5 * PI), 0.0, 1.0)
	var night_amount := 1.0 - day_amount
	for node in get_tree().get_nodes_in_group("river_water"):
		if node is RiverWater and node.has_method("set_night_amount"):
			node.set_night_amount(night_amount)

# Guardado de partida: pendiente de implementar (actualmente no persiste)
func save_current_game() -> void:
	return

func _build_save_data() -> Dictionary:
	var data := {
		"balance_version": SAVE_BALANCE_VERSION,
		"day_cycle": day_cycle.to_dict() if day_cycle != null else {},
		"containers": _containers_to_array(),
		"world_actions": _world_actions_to_array()
	}
	if player != null:
		data["player"] = player.to_dict()
	if radio != null:
		data["radio"] = radio.to_dict()
	return data

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
	var shader_sky_material := _make_shader_sky_material()
	if shader_sky_material != null:
		sky.sky_material = shader_sky_material
		sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
		sky.radiance_size = Sky.RADIANCE_SIZE_128
	else:
		var hdri_sky_material = _make_hdri_sky_material()
		if hdri_sky_material != null:
			sky.sky_material = hdri_sky_material
		else:
			sky.sky_material = sky_material
	environment.sky = sky
	environment.background_mode = Environment.BG_SKY
	environment.background_color = Color(0.56, 0.76, 0.96)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.86, 0.90, 0.92)
	environment.ambient_light_energy = 0.95
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.78, 0.86, 0.90)
	environment.fog_density = 0.0025
	environment.glow_enabled = false
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.rotation_degrees = Vector3(-45, -25, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_normal_bias = 1.5
	add_child(sun)

	celestial = CelestialSystemScript.new()
	celestial.name = "CelestialSystem"
	add_child(celestial)
	celestial.create_star_field()
	celestial.create_moon_field()

#endregion


#region DÍA/NOCHE Y ENTORNO
func _create_day_night() -> void:
	day_cycle = DayNightCycleScript.new()
	day_cycle.name = "DayNightCycle"
	add_child(day_cycle)
	day_cycle.sun = get_node("Sun") as DirectionalLight3D
	day_cycle.world_environment = get_node("WorldEnvironment") as WorldEnvironment
	if celestial != null:
		day_cycle.star_field = celestial.star_field
		day_cycle.moon_field = celestial.moon_field

	radio = RadioSystemScript.new()
	radio.name = "RadioSystem"
	add_child(radio)
	day_cycle.night_started.connect(func() -> void:
		var message: String = radio.emit_night_message()
		if hud != null:
			hud.show_notice("La radio crepita: \"%s\"" % message)
	)

func _create_player() -> void:
	player = PlayerControllerScript.new()
	player.name = "Player"
	player.position = _get_random_spawn_pos()
	add_child(player)
	player.stats.died.connect(_on_player_died)
	player.item_dropped.connect(_on_item_dropped)
	# Apply pending spawn position if received before player was ready
	if _has_pending_spawn_pos:
		player.global_position = _pending_spawn_pos
		_has_pending_spawn_pos = false

#endregion


#region RED Y MULTIPLAYER (MultiplayerSync)
func _on_remote_player_connected(id: int) -> void:
	if net == null:
		return
	if id == net.get_my_id():
		return
	# Server: create a proxy node for wildlife AI to target (no visual avatar needed)
	if net.is_dedicated_server:
		_spawn_server_proxy(id)
		call_deferred("_delayed_send_world_state", id)
	else:
		_spawn_remote_player(id)

func _on_remote_player_disconnected(id: int) -> void:
	# On client: don't remove puppet if player is still in list as offline
	if net != null and not net.is_host and net.players.has(id) and net.players[id].get("offline", false):
		# Player is offline but kept in list — update puppet position and keep it
		if remote_players.has(id):
			var rp: Node3D = remote_players[id]
			var target_pos: Vector3 = net.players[id].get("pos", rp.global_position)
			if rp.has_method("puppet_apply"):
				rp.puppet_apply(target_pos, net.players[id].get("rot", 0.0), net.players[id].get("anim", "idle"))
			else:
				rp.global_position = target_pos
		return
	if remote_players.has(id):
		var rp: Node3D = remote_players[id]
		rp.queue_free()
		remote_players.erase(id)
	# Keep server proxy alive so character persists in the world
	if server_proxies.has(id):
		var sp: Node3D = server_proxies[id]
		sp.set_meta("disconnected", true)
		sp.set_meta("peer_id", id)
		sp.set_meta("protection_timer", 300.0)
		# Keep in net_player_proxy group so wolves can still attack
		if not sp.is_in_group("net_player_proxy"):
			sp.add_to_group("net_player_proxy")
		var cid: String = sp.get_meta("client_id", "")
		# Update net.players with proxy position and equipment for other clients to see
		if net != null and net.is_host and net.players.has(id):
			net.players[id]["pos"] = sp.global_position
			net.players[id]["offline"] = true
			# Include saved equipment
			net.players[id]["equipped_clothing"] = sp.get_meta("saved_clothing", "")
			net.players[id]["equipped_backpack"] = sp.get_meta("saved_backpack", "")
			net.players[id]["held_item"] = sp.get_meta("saved_held_item", "")
			# Keep last anim (don't force idle — player may be sitting/sleeping)
		server_proxies.erase(id)
		if not cid.is_empty():
			proxy_by_client_id[cid] = sp
		else:
			pass
	# Always sync player list to all remaining clients (even if no proxy)
	if net != null and net.is_host:
		net._sync_player_list.rpc(net.players.duplicate(true))

func _delayed_send_world_state(peer_id: int) -> void:
	# Wait a bit for the client to load the scene before sending world state
	await get_tree().create_timer(2.0).timeout
	_send_world_state_to_client(peer_id)

func _delayed_send_reconnect_state(peer_id: int, pos: Vector3, inv: Array, hp: float, hunger: float, thirst: float, clothing: String, backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float, prone: bool = false, crouching: bool = false) -> void:
	await get_tree().create_timer(2.0).timeout
	if net != null and net.peer != null:
		net.set_client_spawn_pos.rpc_id(peer_id, pos)
		net.restore_player_inventory.rpc_id(peer_id, inv, hp, hunger, thirst, clothing, backpack, held_item, held_idx, sleeping, sitting, rot, prone, crouching)
		# Also sync world state (open doors, depleted resources, etc.) to reconnecting client
		_send_world_state_to_client(peer_id)
		# Clear reconnecting flag so server accepts position updates from this client
		if server_proxies.has(peer_id):
			server_proxies[peer_id].set_meta("reconnecting", false)

var _spawn_zones: Array = [
	Vector3(15.0, 0.4, -35.0),
	Vector3(-55.0, 0.4, -40.0),
	Vector3(55.0, 0.4, 45.0),
	Vector3(-50.0, 0.4, 50.0),
	Vector3(110.0, 0.4, -120.0),
	Vector3(-120.0, 0.4, -110.0),
	Vector3(130.0, 0.4, 110.0),
	Vector3(-110.0, 0.4, 120.0),
	Vector3(0.0, 0.4, -160.0),
	Vector3(0.0, 0.4, 160.0),
	Vector3(-160.0, 0.4, 0.0),
	Vector3(160.0, 0.4, 0.0),
	Vector3(85.0, 0.4, -60.0),
	Vector3(-85.0, 0.4, 60.0),
	Vector3(60.0, 0.4, 130.0),
	Vector3(-60.0, 0.4, -130.0)
]

func _get_random_spawn_pos() -> Vector3:
	var base_pos = _spawn_zones[randi() % _spawn_zones.size()]
	var h = _get_ground_height(base_pos)
	return Vector3(base_pos.x, h + 0.4, base_pos.z)

func _delayed_send_new_player_state(peer_id: int) -> void:
	await get_tree().create_timer(2.0).timeout
	if net != null and net.peer != null:
		net.set_client_spawn_pos.rpc_id(peer_id, _get_random_spawn_pos())
		# Clear reconnecting flag so server accepts position updates from this client
		if server_proxies.has(peer_id):
			server_proxies[peer_id].set_meta("reconnecting", false)

# Match reconnecting client to their persisted proxy by client_id
func _match_proxy_to_client(peer_id: int, cid: String) -> void:
	if proxy_by_client_id.has(cid):
		var existing: Node3D = proxy_by_client_id[cid]
		proxy_by_client_id.erase(cid)
		var was_dead: bool = existing.get_meta("proxy_dead", false)
		if was_dead:
			# Read saved metadata before freeing the dead proxy
			var dead_inv: Array = existing.get_meta("saved_inventory", [])
			var dead_hp: float = 100.0  # Reset HP on respawn after death
			var dead_hunger: float = existing.get_meta("saved_hunger", 100.0)
			var dead_thirst: float = existing.get_meta("saved_thirst", 100.0)
			var dead_clothing: String = existing.get_meta("saved_clothing", "")
			var dead_backpack: String = existing.get_meta("saved_backpack", "")
			var dead_held: String = existing.get_meta("saved_held_item", "")
			var dead_held_idx: int = existing.get_meta("saved_held_idx", 0)
			var dead_rot: float = existing.get_meta("saved_rot", 0.0)
			existing.queue_free()
			pending_client_ids[peer_id] = cid
			# Set client_id on the freshly-created proxy so it persists for next disconnect
			if server_proxies.has(peer_id):
				server_proxies[peer_id].set_meta("client_id", cid)
			# Send spawn position with restored inventory (not sitting/prone/crouching since player died)
			var spawn_pos: Vector3 = _get_random_spawn_pos()
			call_deferred("_delayed_send_reconnect_state", peer_id, spawn_pos, dead_inv, dead_hp, dead_hunger, dead_thirst, dead_clothing, dead_backpack, dead_held, dead_held_idx, false, false, dead_rot, false, false)
		else:
			# Remove the freshly-created proxy for this peer_id if it exists
			if server_proxies.has(peer_id):
				var fresh: Node3D = server_proxies[peer_id]
				fresh.queue_free()
				server_proxies.erase(peer_id)
			# Rebind persisted proxy to new peer_id
			existing.set_meta("peer_id", peer_id)
			existing.set_meta("client_id", cid)
			existing.set_meta("disconnected", false)
			existing.set_meta("reconnecting", true)
			existing.set_meta("protection_timer", 30.0)
			existing.add_to_group("net_player_proxy")
			server_proxies[peer_id] = existing
			# Send position and inventory to reconnecting client (delayed so scene is loaded)
			var saved_pos: Vector3 = existing.get_meta("saved_pos", existing.global_position)
			var saved_inv: Array = existing.get_meta("saved_inventory", [])
			var saved_hp: float = existing.get_meta("saved_health", 100.0)
			var saved_hunger: float = existing.get_meta("saved_hunger", 100.0)
			var saved_thirst: float = existing.get_meta("saved_thirst", 100.0)
			var saved_clothing: String = existing.get_meta("saved_clothing", "")
			var saved_backpack: String = existing.get_meta("saved_backpack", "")
			var saved_held: String = existing.get_meta("saved_held_item", "")
			var saved_held_idx: int = existing.get_meta("saved_held_idx", 0)
			var saved_sleeping: bool = existing.get_meta("saved_sleeping", false)
			var saved_sitting: bool = existing.get_meta("saved_sitting", false)
			var saved_prone: bool = existing.get_meta("saved_prone", false)
			var saved_crouching: bool = existing.get_meta("saved_crouching", false)
			var saved_rot: float = existing.get_meta("saved_rot", 0.0)
			call_deferred("_delayed_send_reconnect_state", peer_id, saved_pos, saved_inv, saved_hp, saved_hunger, saved_thirst, saved_clothing, saved_backpack, saved_held, saved_held_idx, saved_sleeping, saved_sitting, saved_rot, saved_prone, saved_crouching)
	else:
		# No existing proxy — set client_id on the freshly created proxy if it exists
		if server_proxies.has(peer_id):
			server_proxies[peer_id].set_meta("client_id", cid)
		else:
			pending_client_ids[peer_id] = cid
		# Send spawn position to new player too (so client knows when to start sending position)
		call_deferred("_delayed_send_new_player_state", peer_id)

func _spawn_server_proxy(id: int) -> void:
	if server_proxies.has(id):
		return
	var proxy := Node3D.new()
	proxy.name = "ServerProxy_%d" % id
	proxy.position = _get_random_spawn_pos()
	# Store peer_id as metadata
	proxy.set_meta("peer_id", id)
	# Spawn protection: wolves won't target this proxy for 20 seconds
	proxy.set_meta("protection_timer", 30.0)
	proxy.set_meta("has_real_pos", false)
	proxy.set_meta("disconnected", false)
	proxy.set_meta("reconnecting", true)
	proxy.set_meta("proxy_health", 100.0)
	proxy.set_meta("proxy_dead", false)
	# Set client_id from pending if available (for persistence across reconnects)
	if pending_client_ids.has(id):
		proxy.set_meta("client_id", pending_client_ids[id])
		pending_client_ids.erase(id)
	add_child(proxy)
	# Add to group after adding to scene tree so get_nodes_in_group finds it
	proxy.add_to_group("net_player_proxy")
	server_proxies[id] = proxy
	# Set chase cooldown on all wolves so they don't immediately chase
	var wolves := get_tree().get_nodes_in_group("wildlife_wolf")
	for w in wolves:
		if w is Node3D and w.has_method("_wolf_ai"):
			w.set("_chase_cooldown", 8.0)

# Called by RPC from server on client to apply wolf damage
func _net_apply_damage(amount: float) -> void:
	if player != null and player.has_method("apply_damage"):
		player.apply_damage(amount)

func _net_force_death() -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.get("is_dead") == true:
		return
	if game_over:
		return
	if player.has_method("die"):
		player.die()
	# Trigger death handler to notify server and close game
	# (game_over guard in _on_player_died prevents double call if stats.died already triggered it)
	_on_player_died()

# Called by RPC from server on client to set position on reconnect
var _has_received_spawn_pos := false
var _pending_spawn_pos: Vector3 = Vector3.ZERO
var _has_pending_spawn_pos := false

func _apply_net_spawn_pos(pos: Vector3) -> void:
	_has_received_spawn_pos = true
	if player != null:
		player.global_position = pos
	else:
		_pending_spawn_pos = pos
		_has_pending_spawn_pos = true
	_send_character_appearance()

func _send_character_appearance() -> void:
	if net == null or not net.is_connected or net.is_dedicated_server:
		return
	var gs := get_node_or_null("/root/GameSession")
	if gs == null:
		return
	var char_name_str: String = gs.selected_character_id
	if gs.has_meta("char_name"):
		char_name_str = str(gs.get_meta("char_name"))
	var top_camo: bool = gs.has_meta("top_camo") and bool(gs.get_meta("top_camo", false))
	var bottom_camo: bool = gs.has_meta("bottom_camo") and bool(gs.get_meta("bottom_camo", false))
	net.sync_character_appearance.rpc(char_name_str, gs.selected_top_color, gs.selected_bottom_color, gs.selected_shoes_color, gs.selected_hair_color, gs.selected_skin_color, top_camo, bottom_camo)

# Server: store player inventory/stats/equipment on their proxy
func _store_player_inventory(peer_id: int, items_data: Array, health: float, hunger: float, thirst: float, equipped_clothing: String, equipped_backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float, prone: bool = false, crouching: bool = false) -> void:
	var proxy: Node3D = null
	if server_proxies.has(peer_id):
		proxy = server_proxies[peer_id]
	else:
		for cid in proxy_by_client_id:
			var p: Node3D = proxy_by_client_id[cid]
			if p != null and p.get_meta("peer_id", -1) == peer_id:
				proxy = p
				break
	if proxy == null:
		return
	proxy.set_meta("saved_inventory", items_data)
	proxy.set_meta("saved_health", health)
	proxy.set_meta("saved_hunger", hunger)
	proxy.set_meta("saved_thirst", thirst)
	proxy.set_meta("saved_clothing", equipped_clothing)
	proxy.set_meta("saved_backpack", equipped_backpack)
	proxy.set_meta("saved_held_item", held_item)
	proxy.set_meta("saved_held_idx", held_idx)
	proxy.set_meta("saved_sleeping", sleeping)
	proxy.set_meta("saved_sitting", sitting)
	proxy.set_meta("saved_prone", prone)
	proxy.set_meta("saved_crouching", crouching)
	proxy.set_meta("saved_rot", rot)
	proxy.set_meta("saved_pos", proxy.global_position)

func _apply_pending_restore() -> void:
	if _pending_restore_data.is_empty():
		return
	var d = _pending_restore_data
	_pending_restore_data = []
	_apply_restored_inventory(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], d[10], d[11], d[12])

# Client: restore inventory/stats/equipment from server on reconnect
func _apply_restored_inventory(items_data: Array, health: float, hunger: float, thirst: float, equipped_clothing: String, equipped_backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float, prone: bool = false, crouching: bool = false) -> void:
	if player == null:
		_pending_restore_data = [items_data, health, hunger, thirst, equipped_clothing, equipped_backpack, held_item, held_idx, sleeping, sitting, rot, prone, crouching]
		return
	var ItemScript = load("res://scripts/Item.gd")
	if player.has_node("Inventory"):
		var inv = player.get_node("Inventory")
		if inv != null and "items" in inv:
			inv.items.clear()
			for d in items_data:
				var item = ItemScript.from_dict(d)
				if item != null:
					inv.items.append(item)
	if player.get("stats") != null:
		player.stats.health = health
		player.stats.hunger = hunger
		player.stats.thirst = thirst
		player.stats.changed.emit()
	# Restore rotation
	player.rotation.y = rot
	# Reset velocity to prevent floating/jumping on reconnect
	player.velocity = Vector3.ZERO
	if "_is_falling_from_height" in player:
		player._is_falling_from_height = false
	if "_fall_height" in player:
		player._fall_height = 0.0
	if "_max_fall_height" in player:
		player._max_fall_height = 0.0
	if "is_jumping" in player:
		player.is_jumping = false
	if "_jump_velocity" in player:
		player._jump_velocity = 0.0
	if "_jump_apex" in player:
		player._jump_apex = false
	# Restore sleeping state
	if sleeping and not player.is_sleeping:
		player.start_sleep(player.global_position, true)
	# Restore equipped items
	if not equipped_backpack.is_empty():
		player.equip_backpack(equipped_backpack)
	if not equipped_clothing.is_empty():
		# Unequip all default clothing first to clear their meshes
		if "_equipped_slots" in player:
			var old_slots: Dictionary = player._equipped_slots.duplicate()
			player._equipped_slots.clear()
			for old_item in old_slots.values():
				var oitem := str(old_item)
				if not oitem.is_empty():
					player.unequip_clothing(oitem)
		# Also unequip any default items that were equipped at _ready
		for default_item in ["Camiseta", "Pantalones", "Zapatillas"]:
			player.unequip_clothing(default_item)
		var slots := equipped_clothing.split(",")
		for slot_name in slots:
			if not slot_name.is_empty():
				player.equip_clothing(slot_name)
	player.held_index = clampi(held_idx, 0, max(0, player.inventory.items.size() - 1))
	player._sync_held_item()
	# Restore sitting/prone/crouching state AFTER equipment so animations are correct
	if prone and not player.is_prone:
		player.is_prone = true
		player.is_sitting = false
		player._sit_cooldown = 0.3
		if player._has_rifle_equipped() and not player._rifle_prone_animation.is_empty():
			player.third_person_animation_player.play(player._rifle_prone_animation, 0.1)
		elif not player.third_person_sit_animation.is_empty():
			player.third_person_animation_player.play(player.third_person_sit_animation, 0.1)
	elif sitting and not player.is_sitting:
		player.is_sitting = true
		player._sit_cooldown = 0.3
		if player._has_rifle_equipped() and not player._rifle_sit_animation.is_empty():
			player.third_person_animation_player.play(player._rifle_sit_animation, 0.1)
		elif not player.third_person_sit_animation.is_empty():
			player.third_person_animation_player.play(player.third_person_sit_animation, 0.1)
	if crouching and not player.is_crouching and not prone and not sitting and not sleeping:
		player._force_crouch = true
		player.is_crouching = true
		player._update_crouch_collision()

# Called by RPC from client on server to damage a real animal
func _send_world_state_to_client(peer_id: int) -> void:
	if net == null:
		return
	var open_doors: Array = []
	# On dedicated server, doors don't exist as nodes — use the tracked state dictionary
	if net.is_dedicated_server:
		for door_name in _server_door_states.keys():
			if _server_door_states[door_name]:
				open_doors.append(door_name)
	else:
		for door in get_tree().get_nodes_in_group("doors"):
			if door is Door and door.is_open:
				open_doors.append(door.name)
	net.sync_world_state.rpc_id(peer_id, _depleted_action_ids, _dropped_items, _built_campfires, _lit_campfires, open_doors, _built_shelters)

func _net_sync_world_state(depleted_ids: Array, dropped_items: Array, campfires: Array, lit_campfires: Array, open_doors: Array, shelters: Array = []) -> void:
	for action_id in depleted_ids:
		if world_actions_by_id.has(action_id):
			var action = world_actions_by_id[action_id]
			_hide_action_visual(action)
			action.mark_depleted()
			world_actions_by_id.erase(action_id)
	for drop in dropped_items:
		if not world_actions_by_id.has(str(drop["id"])):
			var drop_at := str(drop.get("action_type", ""))
			if drop_at == "wolf_meat_raw":
				var mpos_arr = drop.get("pos", [0.0, 0.06, 0.0])
				var mpos := Vector3(float(mpos_arr[0]), float(mpos_arr[1]), float(mpos_arr[2])) if mpos_arr is Array else Vector3(drop["pos"].x, drop["pos"].y, drop["pos"].z)
				_spawn_raw_meat_visual(str(drop["id"]), str(drop["name"]), mpos)
			else:
				var dpos_raw = drop["pos"]
				var dpos: Vector3
				if dpos_raw is Array:
					dpos = Vector3(float(dpos_raw[0]), float(dpos_raw[1]), float(dpos_raw[2]))
				else:
					dpos = dpos_raw
				_spawn_dropped_item_visual(str(drop["id"]), str(drop["name"]), str(drop["type"]), float(drop["weight"]), int(drop["qty"]), float(drop["use"]), dpos)
	for cf in campfires:
		if not world_actions_by_id.has(str(cf["id"])):
			_spawn_player_campfire_with_id(str(cf["id"]), cf["pos"])
	for lc in lit_campfires:
		if world_actions_by_id.has(str(lc["id"])):
			var action = world_actions_by_id[str(lc["id"])]
			if not action.get_meta("lit", false):
				_create_campfire_fire(action.position + Vector3(0, 0.15, 0), str(lc["fire_name"]))
				action.set_meta("lit", true)
				action.action_type = "cook"
				action.display_name = "Fogata encendida"
				action.repeatable = true
	# Apply open door states
	_pending_open_doors = open_doors.duplicate()
	_apply_pending_doors()
	# Spawn shelters built by other players
	for sh in shelters:
		if not world_actions_by_id.has(str(sh["id"])):
			_spawn_player_shelter_with_id(str(sh["id"]), sh["pos"])

func _apply_pending_doors() -> void:
	if _pending_open_doors.is_empty():
		return
	var applied: Array = []
	for door_name in _pending_open_doors:
		var found := false
		for d in get_tree().get_nodes_in_group("doors"):
			if d is Door and d.name == door_name:
				if not d.is_open:
					d.is_open = true
					d.rotation_degrees.y = d.open_yaw
				found = true
				break
		if found:
			applied.append(door_name)
	for door_name in applied:
		_pending_open_doors.erase(door_name)

func _net_item_picked_up(action_id: String) -> void:
	if net != null and net.is_dedicated_server:
		if not _depleted_action_ids.has(action_id):
			_depleted_action_ids.append(action_id)
		# Remove from _dropped_items so it doesn't sync to new clients
		for i in range(_dropped_items.size() - 1, -1, -1):
			if str(_dropped_items[i].get("id", "")) == action_id:
				_dropped_items.remove_at(i)
				break
	# Remove the picked up item from this client's world
	if world_actions_by_id.has(action_id):
		var action = world_actions_by_id[action_id]
		_hide_action_visual(action)
		action.mark_depleted()
		world_actions_by_id.erase(action_id)

func _net_player_shot_rifle(shooter_id: int, origin: Vector3, dir: Vector3) -> void:
	if remote_players.has(shooter_id):
		var rp: Node3D = remote_players[shooter_id]
		if is_instance_valid(rp) and rp.has_method("play_rifle_shot_remote"):
			rp.play_rifle_shot_remote(origin, dir)

func _net_door_state_changed(door_name: String, is_open: bool) -> void:
	_server_door_states[door_name] = is_open
	# Also update the visual door if it exists (non-dedicated server or client)
	var door: Door = null
	for d in get_tree().get_nodes_in_group("doors"):
		if d is Door and d.name == door_name:
			door = d
			break
	if door != null:
		if door.is_open != is_open:
			door.is_open = is_open
			var target_yaw: float = door.open_yaw if is_open else door.closed_yaw
			if door._tween != null:
				door._tween.kill()
			door._tween = door.create_tween()
			door._tween.set_trans(Tween.TRANS_SINE)
			door._tween.set_ease(Tween.EASE_OUT)
			door._tween.tween_property(door, "rotation_degrees:y", target_yaw, 0.28)

func _net_damage_animal(animal_name: String, amount: float, from_knife: bool) -> void:
	# The animal_name from puppet is "Puppet_Wildlife_wolf_0" — extract the real name
	var real_name := animal_name.replacen("Puppet_", "")
	var animal := get_node_or_null(real_name)
	if animal != null and animal.has_method("take_damage"):
		animal.take_damage(amount, from_knife)
	# Server broadcasts hit to all clients so puppets play pain sound
	if net != null and net.is_host and net.peer != null:
		for pid in net.players.keys():
			if pid != net.get_my_id() and not net.players[pid].get("offline", false):
				if net.peer.get_peer(pid) != null:
					net.animal_hit.rpc_id(pid, real_name)

func _net_animal_hit(animal_name: String) -> void:
	# Find the puppet for this animal and play pain sound
	var puppet_name := "Puppet_" + animal_name
	var puppet := get_node_or_null(puppet_name)
	if puppet != null and puppet.has_method("_play_wolf_pain_sound"):
		puppet._play_wolf_pain_sound()

func _net_gut_animal(animal_name: String, sender: int, collect_mode: bool = false) -> void:
	if net == null or not net.is_host:
		return
	# Extract real animal name from puppet name
	var real_name := animal_name.replacen("Puppet_", "")
	var animal := get_node_or_null(real_name)
	if animal == null or not is_instance_valid(animal):
		return
	if not animal.get("_is_dead"):
		return
	if animal.get("_gutted"):
		return
	# Verify sender is close enough (anti-cheat)
	if server_proxies.has(sender):
		var sender_proxy: Node3D = server_proxies[sender]
		var dist := sender_proxy.global_position.distance_to(animal.global_position)
		if dist > 5.0:
			return
	# Mark as gutted
	animal.set("_gutted", true)
	var meat_drops: Array = []
	var meat_name := "Carne cruda de lobo"
	var meat_qty := 4
	if not collect_mode:
		var animal_type: String = animal.get("animal_type")
		match animal_type:
			"deer":
				meat_name = "Carne cruda de ciervo"
				meat_qty = 8
			"fox":
				meat_name = "Carne cruda de zorro"
				meat_qty = 3
			_:
				meat_name = "Carne cruda de lobo"
				meat_qty = 4
	# Spawn meat immediately on server and notify clients - clients delay puppet removal to match animation
	if not collect_mode:
		var base_pos: Vector3 = animal.global_position
		for i in range(meat_qty):
			var angle := TAU * float(i) / float(meat_qty) + randf_range(-0.3, 0.3)
			var offset := Vector3(cos(angle) * randf_range(0.4, 0.9), 0.0, sin(angle) * randf_range(0.4, 0.9))
			var mpos := base_pos + offset
			mpos.y = 0.06
			var mid := "gut_meat_%d_%d" % [Time.get_ticks_msec(), i]
			_spawn_ground_pickup(meat_name, "food", mpos, 0.3, 1, 15.0, mid, "wolf_meat_raw")
			meat_drops.append({"id": mid, "name": meat_name, "type": "food", "pos": [mpos.x, mpos.y, mpos.z], "weight": 0.3, "qty": 1, "use": 15.0, "action_type": "wolf_meat_raw"})
			_dropped_items.append({"id": mid, "name": meat_name, "type": "food", "weight": 0.3, "qty": 1, "use": 15.0, "pos": [mpos.x, mpos.y, mpos.z], "action_type": "wolf_meat_raw"})
	# Remove the animal from server
	if animal.has_method("_remove_corpse"):
		animal._remove_corpse()
	else:
		animal.queue_free()
	_save_world_change_silent()
	# Notify all clients to remove the animal and spawn meat (clients delay to match animation)
	if net.peer != null:
		for pid in net.players.keys():
			if pid == multiplayer.get_unique_id():
				continue
			if net.players[pid].get("offline", false):
				continue
			if net.peer.get_peer(pid) == null:
				continue
			net.animal_gutted.rpc_id(pid, animal_name, meat_drops)

func _net_animal_gutted(animal_name: String, meat_drops: Array) -> void:
	# Fix key: animal_name may be "Puppet_X" but puppet_animals is keyed by "X"
	var puppet_key := animal_name.replacen("Puppet_", "")
	# Delay removal and meat spawning by 5s to match the gutting animation
	var meat_drops_ref: Array = meat_drops
	var t := get_tree().create_timer(5.0)
	t.timeout.connect(func():
		# Remove the puppet animal
		if puppet_animals.has(puppet_key):
			var puppet: Node3D = puppet_animals[puppet_key]
			if is_instance_valid(puppet):
				puppet.queue_free()
			puppet_animals.erase(puppet_key)
		# Also remove from net.animals so it doesn't respawn
		if net != null and net.animals.has(puppet_key):
			net.animals.erase(puppet_key)
		# Spawn meat drops on this client
		for drop in meat_drops_ref:
			var mid: String = str(drop.get("id", ""))
			var mname: String = str(drop.get("name", "Carne cruda"))
			var mpos_arr = drop.get("pos", [0.0, 0.06, 0.0])
			var mpos := Vector3(float(mpos_arr[0]), float(mpos_arr[1]), float(mpos_arr[2]))
			if not world_actions_by_id.has(mid):
				_spawn_raw_meat_visual(mid, mname, mpos)
	)

func _net_damage_player(target_peer_id: int, amount: float, sender: int) -> void:
	if net == null or not net.is_host:
		return
	# Find target proxy: check active proxies first, then disconnected ones
	var proxy: Node3D = null
	if server_proxies.has(target_peer_id):
		proxy = server_proxies[target_peer_id]
	else:
		for cid in proxy_by_client_id.keys():
			var dp: Node3D = proxy_by_client_id[cid]
			if dp.get_meta("peer_id", 0) == target_peer_id:
				proxy = dp
				break
	if proxy == null:
		return
	var is_dead: bool = proxy.get_meta("proxy_dead", false)
	if is_dead:
		return
	# Check distance if sender has a proxy
	var sender_proxy: Node3D = null
	if server_proxies.has(sender):
		sender_proxy = server_proxies[sender]
	else:
		for cid2 in proxy_by_client_id.keys():
			var sp2: Node3D = proxy_by_client_id[cid2]
			if sp2.get_meta("peer_id", 0) == sender:
				sender_proxy = sp2
				break
	if sender_proxy != null:
		var dist := sender_proxy.global_position.distance_to(proxy.global_position)
		if dist > 5.0:
			return
	var hp: float = proxy.get_meta("proxy_health", 100.0)
	hp = max(0.0, hp - amount)
	proxy.set_meta("proxy_health", hp)
	if hp <= 0.0:
		proxy.set_meta("proxy_dead", true)
		proxy.remove_from_group("net_player_proxy")
		proxy.add_to_group("interactable")
		# Drop loot immediately on server using saved inventory
		_drop_player_loot(target_peer_id, proxy)
		proxy.set_meta("death_broadcasted", true)
		_broadcast_player_death(target_peer_id, proxy)
		# Force death on the target client if connected
		if net.peer != null and net.peer.get_peer(target_peer_id) != null:
			net.force_death_to_client.rpc_id(target_peer_id)
	else:
		# Send damage to the target client if still connected
		if net.peer != null and net.peer.get_peer(target_peer_id) != null:
			net.apply_damage_to_client.rpc_id(target_peer_id, amount)

func _net_player_died(peer_id: int, inventory_data: Array = []) -> void:
	if net == null or not net.is_host:
		return
	if not server_proxies.has(peer_id):
		return
	var proxy: Node3D = server_proxies[peer_id]
	# Update saved inventory from the death notification if provided
	if not inventory_data.is_empty():
		proxy.set_meta("saved_inventory", inventory_data)
	if proxy.get_meta("loot_dropped", false):
		return
	if not proxy.get_meta("proxy_dead", false):
		proxy.set_meta("proxy_dead", true)
		proxy.remove_from_group("net_player_proxy")
		proxy.add_to_group("interactable")
	_drop_player_loot(peer_id, proxy)
	if not proxy.get_meta("death_broadcasted", false):
		proxy.set_meta("death_broadcasted", true)
		_broadcast_player_death(peer_id, proxy)

func _drop_player_loot(peer_id: int, proxy: Node3D) -> void:
	if proxy.get_meta("loot_dropped", false):
		return
	proxy.set_meta("loot_dropped", true)
	var pos: Vector3 = proxy.global_position
	var saved_inv: Array = proxy.get_meta("saved_inventory", [])
	# Drop each item as a pickup on the server and notify all clients
	var drops: Array = []
	for i in range(saved_inv.size()):
		var d: Dictionary = saved_inv[i]
		var iname: String = str(d.get("name", d.get("item_name", "")))
		var itype: String = str(d.get("type", d.get("item_type", "")))
		var iweight: float = float(d.get("weight", 0.1))
		var iqty: int = int(d.get("quantity", 1))
		var iuse: float = float(d.get("use_value", 0.0))
		if iname.is_empty():
			continue
		var angle := TAU * float(i) / float(max(1, saved_inv.size())) + randf_range(-0.3, 0.3)
		var offset := Vector3(cos(angle) * randf_range(1.5, 3.0), 0.0, sin(angle) * randf_range(1.5, 3.0))
		var dpos := pos + offset
		dpos.y = 0.06
		var did := "death_loot_%d_%d" % [Time.get_ticks_msec(), i]
		_spawn_ground_pickup(iname, itype, dpos, iweight, iqty, iuse, did)
		drops.append({"id": did, "name": iname, "type": itype, "pos": [dpos.x, dpos.y, dpos.z], "weight": iweight, "qty": iqty, "use": iuse})
		_dropped_items.append({"id": did, "name": iname, "type": itype, "weight": iweight, "qty": iqty, "use": iuse, "pos": [dpos.x, dpos.y, dpos.z]})
	_save_world_change_silent()
	# Notify all clients to spawn the loot
	if net.peer != null:
		for pid in net.players.keys():
			if pid == multiplayer.get_unique_id():
				continue
			if net.players[pid].get("offline", false):
				continue
			if net.peer.get_peer(pid) == null:
				continue
			for drop in drops:
				var dpos_arr = drop["pos"]
				var dpos := Vector3(float(dpos_arr[0]), float(dpos_arr[1]), float(dpos_arr[2]))
				net.item_dropped.rpc_id(pid, drop["id"], drop["name"], drop["type"], drop["weight"], drop["qty"], drop["use"], dpos)
	# Clear saved inventory so reconnecting player doesn't get items back
	proxy.set_meta("saved_inventory", [])
	# Clear saved clothing and strip the proxy's visual clothing
	var dead_clothing: String = proxy.get_meta("saved_clothing", "")
	if not dead_clothing.is_empty():
		proxy.set_meta("saved_clothing", "")
		if net.players.has(peer_id):
			net.players[peer_id]["equipped_clothing"] = ""
		var rp: Node = proxy.get_node_or_null("PlayerController")
		if rp == null:
			for child in proxy.get_children():
				if child is CharacterBody3D and child.has_method("puppet_apply_visuals"):
					rp = child
					break
		if rp != null and rp.has_method("puppet_apply_visuals"):
			rp.puppet_apply_visuals("", rp.get("_puppet_held") if rp.get("_puppet_held") != null else "", proxy.get_meta("saved_backpack", ""))

func _broadcast_player_death(peer_id: int, proxy: Node3D) -> void:
	if net == null or net.peer == null:
		return
	# Update player list entry
	if net.players.has(peer_id):
		net.players[peer_id]["anim"] = "dead"
	var pos: Vector3 = proxy.global_position
	var rot: float = proxy.rotation.y
	# Send reliable death broadcast to all clients
	for pid in net.players.keys():
		if pid == multiplayer.get_unique_id():
			continue
		if net.players[pid].get("offline", false):
			continue
		if net.peer.get_peer(pid) == null:
			continue
		net.broadcast_player_death.rpc_id(pid, peer_id, pos, rot)
	# Also send via sync_player_state as backup
	var clothing := ""
	var held := ""
	var backpack := ""
	for pid in net.players.keys():
		if pid == multiplayer.get_unique_id():
			continue
		if net.players[pid].get("offline", false):
			continue
		if net.peer.get_peer(pid) == null:
			continue
		net.sync_player_state.rpc_id(pid, peer_id, pos, rot, "dead", clothing, held, backpack)

func _net_player_death_broadcast(peer_id: int, pos: Vector3, rot: float) -> void:
	# Reliable death notification from server — apply immediately to puppet
	if not remote_players.has(peer_id):
		return
	var rp: Node3D = remote_players[peer_id]
	if not is_instance_valid(rp):
		return
	if rp.has_method("puppet_apply"):
		rp.puppet_apply(pos, rot, "dead")
		rp.puppet_apply_visuals("", "", "")

func _net_request_loot(requester_id: int, dead_peer_id: int) -> void:
	if net == null or not net.is_host:
		return
	if not server_proxies.has(dead_peer_id):
		return
	var proxy: Node3D = server_proxies[dead_peer_id]
	if not proxy.get_meta("proxy_dead", false):
		return
	var saved_inv: Array = proxy.get_meta("saved_inventory", [])
	if net.peer != null and net.peer.get_peer(requester_id) != null:
		net.send_loot.rpc_id(requester_id, dead_peer_id, saved_inv)

func _net_take_loot(taker_id: int, dead_peer_id: int, item_index: int) -> void:
	if net == null or not net.is_host:
		return
	if not server_proxies.has(dead_peer_id):
		return
	var proxy: Node3D = server_proxies[dead_peer_id]
	if not proxy.get_meta("proxy_dead", false):
		return
	var saved_inv: Array = proxy.get_meta("saved_inventory", [])
	if item_index < 0 or item_index >= saved_inv.size():
		return
	# Verify taker is close enough to the corpse
	if server_proxies.has(taker_id):
		var taker_proxy: Node3D = server_proxies[taker_id]
		var dist := taker_proxy.global_position.distance_to(proxy.global_position)
		if dist > 5.0:
			return
	var item_data: Dictionary = saved_inv[item_index]
	saved_inv.remove_at(item_index)
	proxy.set_meta("saved_inventory", saved_inv)
	# Notify the taker's client to add the item to their inventory
	if net.peer != null and net.peer.get_peer(taker_id) != null:
		net.add_looted_item.rpc_id(taker_id, item_data)

func _update_server_proxies(delta: float) -> void:
	if net == null or not net.is_dedicated_server:
		return
	# Update proxy positions from net.players data
	for pid in net.players.keys():
		if pid == net.get_my_id():
			continue
		if not server_proxies.has(pid):
			_spawn_server_proxy(pid)
			continue
		var data: Dictionary = net.players[pid]
		var proxy: Node3D = server_proxies[pid]
		# Only update proxy position if client has sent real position data
		if data.has("pos"):
			proxy.set_meta("has_real_pos", true)
			proxy.global_position = data["pos"]
			proxy.set_meta("in_built_shelter", _is_near_built_shelter(proxy.global_position))
		# Decrement spawn protection timer using real delta
		var pt: float = proxy.get_meta("protection_timer", 0.0)
		if pt > 0.0:
			proxy.set_meta("protection_timer", max(0.0, pt - delta))
		# Tick survival stats for active connected players (server-authoritative)
		if not data.get("offline", false) and not proxy.get_meta("proxy_dead", false):
			var proxy_in_shelter: bool = proxy.get_meta("in_built_shelter", false) or _is_player_in_house(proxy.global_position)
			var proxy_ambient: float = 20.0
			if day_cycle != null:
				proxy_ambient = day_cycle.get_ambient_temperature()
			if hud != null and hud._real_temp_parsed != -999.0:
				proxy_ambient = hud._real_temp_parsed
			if _is_player_in_house(proxy.global_position):
				proxy_ambient = clamp(proxy_ambient, 12.0, 28.0)
			if proxy.get_meta("in_built_shelter", false):
				proxy_ambient = clamp(proxy_ambient, 10.0, 30.0)
			var p_hunger: float = proxy.get_meta("saved_hunger", 100.0)
			var p_thirst: float = proxy.get_meta("saved_thirst", 100.0)
			var p_hp: float = proxy.get_meta("proxy_health", 100.0)
			var p_sleeping: bool = data.get("sleeping", false)
			var p_sprinting: bool = data.get("anim", "").find("sprint") >= 0
			var p_moving: bool = data.get("anim", "idle") != "idle"
			var sleep_factor := 0.3 if p_sleeping else 1.0
			p_hunger = max(0.0, p_hunger - 0.12 * delta * (2.0 if p_moving else 1.0) * sleep_factor)
			p_thirst = max(0.0, p_thirst - 0.22 * delta * (3.0 if p_sprinting else 1.0) * (2.0 if p_moving else 1.0) * sleep_factor)
			if p_hunger <= 0.0:
				p_hp = max(0.0, p_hp - 1.0 * delta)
			if p_thirst <= 0.0:
				p_hp = max(0.0, p_hp - 1.5 * delta)
			proxy.set_meta("saved_hunger", p_hunger)
			proxy.set_meta("saved_thirst", p_thirst)
			proxy.set_meta("proxy_health", p_hp)
			if p_hp <= 0.0:
				proxy.set_meta("proxy_dead", true)
				proxy.remove_from_group("net_player_proxy")
				proxy.add_to_group("interactable")
				_drop_player_loot(pid, proxy)
				_broadcast_player_death(pid, proxy)
	# Broadcast offline proxies to all connected clients
	# Check both server_proxies (just disconnected) and proxy_by_client_id (fully offline)
	var offline_proxies: Dictionary = {}
	for pid in net.players.keys():
		if pid == net.get_my_id():
			continue
		if net.players[pid].get("offline", false) and server_proxies.has(pid):
			offline_proxies[pid] = server_proxies[pid]
	for cid in proxy_by_client_id.keys():
		var op: Node3D = proxy_by_client_id[cid]
		var op_pid: int = op.get_meta("peer_id", 0)
		if op_pid != 0 and net.players.has(op_pid):
			offline_proxies[op_pid] = op
	for pid in offline_proxies.keys():
		var offline_proxy: Node3D = offline_proxies[pid]
		var off_clothing: String = offline_proxy.get_meta("saved_clothing", net.players[pid].get("equipped_clothing", ""))
		var off_backpack: String = offline_proxy.get_meta("saved_backpack", net.players[pid].get("equipped_backpack", ""))
		var off_held: String = offline_proxy.get_meta("saved_held_item", net.players[pid].get("held_item", ""))
		for connected_pid in net.players.keys():
			if connected_pid == net.get_my_id() or connected_pid == pid:
				continue
			if net.players[connected_pid].get("offline", false):
				continue
			# Check if peer is actually still connected before sending RPC
			if net.peer != null and net.peer.get_peer(connected_pid) == null:
				continue
			net.sync_player_state.rpc_id(connected_pid, pid, offline_proxy.global_position, net.players[pid].get("rot", 0.0), net.players[pid].get("anim", "idle"), off_clothing, off_held, off_backpack, false, false, net.players[pid].get("sleeping", false), net.players[pid].get("sitting", false), net.players[pid].get("prone", false), net.players[pid].get("crouching", false))
	# Tick survival stats for disconnected proxies (hunger, thirst, health decay)
	for cid in proxy_by_client_id.keys():
		var dp: Node3D = proxy_by_client_id[cid]
		if dp.get_meta("proxy_dead", false):
			continue
		# Update shelter meta so wolf AI protects disconnected players inside shelters
		dp.set_meta("in_built_shelter", _is_near_built_shelter(dp.global_position))
		var d_hunger: float = dp.get_meta("saved_hunger", 100.0)
		var d_thirst: float = dp.get_meta("saved_thirst", 100.0)
		var d_hp: float = dp.get_meta("proxy_health", 100.0)
		# Decay rates: hunger -0.5/s, thirst -0.7/s (slower than active player)
		d_hunger = max(0.0, d_hunger - 0.5 * delta)
		d_thirst = max(0.0, d_thirst - 0.7 * delta)
		# Health damage from starvation/dehydration
		if d_hunger <= 0.0:
			d_hp = max(0.0, d_hp - 1.0 * delta)
		if d_thirst <= 0.0:
			d_hp = max(0.0, d_hp - 1.5 * delta)
		dp.set_meta("saved_hunger", d_hunger)
		dp.set_meta("saved_thirst", d_thirst)
		dp.set_meta("proxy_health", d_hp)
		if d_hp <= 0.0:
			dp.set_meta("proxy_dead", true)
			dp.remove_from_group("net_player_proxy")
			dp.add_to_group("interactable")
			_drop_player_loot(dp.get_meta("peer_id", 0), dp)
			_broadcast_player_death(dp.get_meta("peer_id", 0), dp)

func _spawn_remote_player(id: int) -> void:
	if remote_players.has(id):
		return
	# PlayerController puppet — model loads from cache (instant if local player already loaded)
	var avatar = PlayerControllerScript.new()
	avatar.name = "RemotePlayer_%d" % id
	# Use position from net.players if available (e.g. offline character)
	var spawn_pos: Vector3 = Vector3(8.0, 0.4, 2.5)
	if net != null and net.players.has(id):
		spawn_pos = net.players[id].get("pos", spawn_pos)
	avatar.position = spawn_pos
	avatar.is_puppet = true
	avatar.set_meta("peer_id", id)
	add_child(avatar)
	remote_players[id] = avatar
	# Defer setup — if local player hasn't loaded model yet, _pending_puppets will retry
	_pending_puppets.append(avatar)

var _pending_puppets: Array = []

func _process_pending_puppets() -> void:
	if _pending_puppets.is_empty():
		return
	var ready := []
	for avatar in _pending_puppets:
		if not is_instance_valid(avatar):
			ready.append(avatar)
			continue
		# Check if local player model is cached
		if player != null and player.third_person_model != null:
			avatar.setup_as_puppet()
			# Copy ground offset from local player (same model, same offset)
			avatar.third_person_ground_offset = player.third_person_ground_offset
			if avatar.third_person_model != null:
				avatar.third_person_model.position.y = player.third_person_ground_offset
			# Apply pending appearance if available
			var pid: int = avatar.get_meta("peer_id", -1)
			if pid >= 0 and net != null and net.players.has(pid):
				var pdata2: Dictionary = net.players[pid]
				if pdata2.has("top_color") and avatar.has_method("puppet_apply_appearance"):
					avatar.puppet_apply_appearance(pdata2.get("char_name", ""), pdata2.get("top_color", Color(0.5,0.5,0.5)), pdata2.get("bottom_color", Color(0.3,0.3,0.3)), pdata2.get("shoes_color", Color(0.15,0.15,0.15)), pdata2.get("hair_color", Color(0.2,0.15,0.1)), pdata2.get("skin_color", Color(0.8,0.7,0.6)), pdata2.get("top_camo", false), pdata2.get("bottom_camo", false))
			ready.append(avatar)
	for avatar in ready:
		_pending_puppets.erase(avatar)

func _sync_local_player_state() -> void:
	if net == null or player == null or not net.is_connected:
		return
	if not _has_received_spawn_pos:
		return
	var my_id: int = net.get_my_id()
	var pos: Vector3 = player.global_position
	var rot: float = player.rotation.y
	var anim: String = "idle"
	if player.has_method("_get_current_anim"):
		anim = player._get_current_anim()
	var clothing: String = ""
	if player._equipped_slots != null and not player._equipped_slots.is_empty():
		var clothing_items: Array = []
		for slot in player._equipped_slots.keys():
			var item_name: String = str(player._equipped_slots[slot])
			if not item_name.is_empty():
				clothing_items.append(item_name)
		clothing = ",".join(clothing_items)
	var held: String = ""
	if player.inventory != null and player.inventory.items.size() > 0:
		var hi: int = clampi(player.held_index, 0, player.inventory.items.size() - 1)
		if player.inventory.items[hi] != null:
			held = player.inventory.items[hi].item_name
	var backpack: String = player.equipped_backpack
	var aim_flag := bool(player._is_aiming)
	var rifle_flag := bool(player._has_rifle_equipped())
	var sleeping_flag := bool(player.is_sleeping)
	var sitting_flag := bool(player.is_sitting)
	var prone_flag := bool(player.is_prone)
	var crouching_flag := bool(player.is_crouching)
	net.sync_player_state.rpc(my_id, pos, rot, anim, clothing, held, backpack, aim_flag, rifle_flag, sleeping_flag, sitting_flag, prone_flag, crouching_flag)

func _sync_local_player_inventory() -> void:
	if net == null or player == null or not net.is_connected:
		return
	if net.is_dedicated_server:
		return
	var items_data: Array = []
	if player.inventory != null:
		for item in player.inventory.items:
			if item != null:
				items_data.append(item.to_dict())
	var hp := 100.0
	var hunger := 100.0
	var thirst := 100.0
	if player.stats != null:
		hp = player.stats.health
		hunger = player.stats.hunger
		thirst = player.stats.thirst
	var clothing: String = ""
	if player._equipped_slots != null and not player._equipped_slots.is_empty():
		var clothing_items: Array = []
		for slot in player._equipped_slots.keys():
			var item_name: String = str(player._equipped_slots[slot])
			if not item_name.is_empty():
				clothing_items.append(item_name)
		clothing = ",".join(clothing_items)
	var backpack: String = player.equipped_backpack
	var held: String = ""
	if player.inventory != null and player.inventory.items.size() > 0:
		var hi: int = clampi(player.held_index, 0, player.inventory.items.size() - 1)
		if player.inventory.items[hi] != null:
			held = player.inventory.items[hi].item_name
	var sleeping: bool = player.is_sleeping
	var sitting: bool = player.is_sitting
	var prone: bool = player.is_prone
	var crouching: bool = player.is_crouching
	var rot: float = player.rotation.y
	net.sync_player_inventory.rpc(items_data, hp, hunger, thirst, clothing, backpack, held, player.held_index, sleeping, sitting, rot, prone, crouching)

func _update_remote_players() -> void:
	if net == null:
		return
	# Remove remote players no longer in the player list
	var stale_pids: Array = []
	for pid in remote_players.keys():
		if not net.players.has(pid):
			stale_pids.append(pid)
	for pid in stale_pids:
		var stale: Node3D = remote_players[pid]
		if is_instance_valid(stale):
			stale.queue_free()
		remote_players.erase(pid)
	for pid in net.players.keys():
		if pid == net.get_my_id():
			continue
		if not remote_players.has(pid):
			_spawn_remote_player(pid)
			continue
		var data: Dictionary = net.players[pid]
		var rp: Node3D = remote_players[pid]
		if not is_instance_valid(rp):
			remote_players.erase(pid)
			_spawn_remote_player(pid)
			continue
		var target_pos: Vector3 = data.get("pos", Vector3(8.0, 0.4, 2.5))
		var target_rot: float = data.get("rot", 0.0)
		var anim: String = data.get("anim", "idle")
		var clothing: String = data.get("equipped_clothing", "")
		var held: String = data.get("held_item", "")
		var backpack: String = data.get("equipped_backpack", "")
		var is_offline: bool = data.get("offline", false)
		var remote_aiming: bool = data.get("is_aiming", false)
		var remote_has_rifle: bool = data.get("has_rifle", false)
		var remote_sleeping: bool = data.get("sleeping", false)
		var remote_sitting: bool = data.get("sitting", false)
		var remote_prone: bool = data.get("prone", false)
		var remote_crouching: bool = data.get("crouching", false)
		# Apply character appearance if available and not yet applied
		if data.has("top_color") and rp.has_method("puppet_apply_appearance") and not rp.get("_applied_appearance"):
			rp.puppet_apply_appearance(data.get("char_name", ""), data.get("top_color", Color(0.5,0.5,0.5)), data.get("bottom_color", Color(0.3,0.3,0.3)), data.get("shoes_color", Color(0.15,0.15,0.15)), data.get("hair_color", Color(0.2,0.15,0.1)), data.get("skin_color", Color(0.8,0.7,0.6)), data.get("top_camo", false), data.get("bottom_camo", false))
		if rp.has_method("puppet_set_aiming"):
			rp.puppet_set_aiming(remote_aiming)
		if rp.has_method("puppet_set_rifle"):
			rp.puppet_set_rifle(remote_has_rifle)
		if rp.has_method("puppet_set_state_flags"):
			rp.puppet_set_state_flags(remote_sleeping, remote_sitting, remote_prone, remote_crouching)
		if is_offline:
			# Snap to exact position for offline characters
			if anim == "dead":
				if rp.has_method("puppet_apply"):
					rp.puppet_apply(target_pos, target_rot, anim)
					rp.puppet_apply_visuals("", "", "")
				else:
					rp.global_position = target_pos
					rp.rotation.y = target_rot
			elif rp.has_method("puppet_apply"):
				rp.puppet_apply(target_pos, target_rot, anim)
				rp.puppet_apply_visuals(clothing, held, backpack)
			else:
				rp.global_position = target_pos
				rp.rotation.y = target_rot
		else:
			# Smooth interpolation for active players
			if rp.get("is_dead") == true or anim == "dead":
				if rp.has_method("puppet_apply"):
					rp.puppet_apply(target_pos, target_rot, anim)
					rp.puppet_apply_visuals("", "", "")
				else:
					rp.global_position = target_pos
					rp.rotation.y = target_rot
			else:
				var smooth_pos: Vector3 = rp.global_position.lerp(target_pos, 0.15)
				var smooth_rot: float = lerp_angle(rp.rotation.y, target_rot, 0.15)
				if rp.has_method("puppet_apply"):
					rp.puppet_apply(smooth_pos, smooth_rot, anim)
					rp.puppet_apply_visuals(clothing, held, backpack)
				else:
					rp.global_position = smooth_pos
					rp.rotation.y = smooth_rot

# Server: collect all wildlife states and broadcast to clients
func _broadcast_animals() -> void:
	if net == null or not net.is_connected:
		return
	var data := {}
	for node in get_tree().get_nodes_in_group("wildlife"):
		if not (node is Node3D):
			continue
		var animal := node as Node3D
		var aid := str(animal.name)
		var pos := animal.global_position
		var hunger_val = animal.get("_wolf_hunger")
		var threshold_val = animal.get("_wolf_hunger_threshold")
		data[aid] = {
			"t": str(animal.get("animal_type")),
			"x": round(pos.x * 100.0) / 100.0,
			"y": round(pos.y * 100.0) / 100.0,
			"z": round(pos.z * 100.0) / 100.0,
			"r": round(animal.rotation.y * 100.0) / 100.0,
			"a": str(animal.get("current_anim_keyword")),
			"d": bool(animal.get("_is_dead")),
			"g": bool(animal.get("_gutted")),
			"h": round(float(hunger_val) * 10.0) / 10.0 if hunger_val != null else 0.0,
			"ht": round(float(threshold_val) * 10.0) / 10.0 if threshold_val != null else 0.0
		}
	net.animals = data
	_animal_debug_timer += 1
	if _animal_debug_timer >= 50:
		_animal_debug_timer = 0
	# Split into chunks to stay under MTU
	var keys := data.keys()
	var half := int(ceil(float(keys.size()) / 2.0))
	var chunk1 := {}
	var chunk2 := {}
	for i in range(keys.size()):
		if i < half:
			chunk1[keys[i]] = data[keys[i]]
		else:
			chunk2[keys[i]] = data[keys[i]]
	if not chunk1.is_empty():
		net.sync_animals.rpc(chunk1)
	if not chunk2.is_empty():
		net.sync_animals.rpc(chunk2)

# Client: spawn/update visual-only puppet animals from server data
func _update_puppet_animals() -> void:
	if net == null:
		return
	if net.animals.is_empty():
		return
	for aid in net.animals.keys():
		var d: Dictionary = net.animals[aid]
		if not puppet_animals.has(aid):
			var puppet = WildlifeControllerScript.new()
			puppet.name = "Puppet_" + str(aid)
			add_child(puppet)
			puppet.setup_puppet(str(d.get("t", "deer")))
			puppet.global_position = Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0))
			puppet_animals[aid] = puppet
		var p = puppet_animals[aid]
		if is_instance_valid(p):
			p.puppet_apply(Vector3(d.get("x", 0.0), d.get("y", 0.0), d.get("z", 0.0)), d.get("r", 0.0), str(d.get("a", "walk")), bool(d.get("d", false)), bool(d.get("g", false)))
			if p.animal_type == "wolf":
				p._wolf_hunger = float(d.get("h", p._wolf_hunger))
				p._wolf_hunger_threshold = float(d.get("ht", p._wolf_hunger_threshold))
	# Remove puppets that no longer exist on the server (unless dead/gutted - those are removed by _net_animal_gutted after animation)
	var stale := []
	for aid in puppet_animals.keys():
		if not net.animals.has(aid):
			var puppet_node = puppet_animals[aid]
			if is_instance_valid(puppet_node) and (puppet_node.get("_is_dead") or puppet_node.get("_gutted")):
				continue
			stale.append(aid)
	for aid in stale:
		if is_instance_valid(puppet_animals[aid]):
			puppet_animals[aid].queue_free()
		puppet_animals.erase(aid)

func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if player != null and is_instance_valid(player) and not player.get("is_dead"):
		if player.has_method("die"):
			player.die()
	# Notify server with inventory data so it can drop loot
	if net != null and net.is_connected and not net.is_host:
		var items_data: Array = []
		if player != null and player.inventory != null:
			for item in player.inventory.items:
				if item != null:
					items_data.append(item.to_dict())
		var hp := 0.0
		var hunger := 0.0
		var thirst := 0.0
		if player != null and player.stats != null:
			hp = player.stats.health
			hunger = player.stats.hunger
			thirst = player.stats.thirst
		var clothing := ""
		if player != null and player._equipped_slots != null and not player._equipped_slots.is_empty():
			var clothing_items: Array = []
			for slot in player._equipped_slots.keys():
				var item_name: String = str(player._equipped_slots[slot])
				if not item_name.is_empty():
					clothing_items.append(item_name)
			clothing = ",".join(clothing_items)
		var backpack := ""
		var held := ""
		var held_idx := 0
		if player != null:
			backpack = player.equipped_backpack
			held_idx = player.held_index
			if player.inventory != null and player.inventory.items.size() > 0:
				held = player.inventory.items[held_idx].item_name
		var rot_y: float = player.rotation.y if player != null else 0.0
		net.notify_death.rpc_id(1, items_data, hp, hunger, thirst, clothing, backpack, held, held_idx, false, false, rot_y)
	SaveSystemScript.delete_save()
	if hud != null:
		hud.show_notice("Has muerto. El juego se cerrara...")
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()

var _loot_dead_peer_id := -1
var _loot_items: Array = []
var _loot_panel: PanelContainer = null

func _net_receive_loot(dead_peer_id: int, items_data: Array) -> void:
	_loot_dead_peer_id = dead_peer_id
	_loot_items = items_data
	_show_loot_ui()

func _show_loot_ui() -> void:
	if hud == null:
		return
	_close_loot_ui()
	_loot_panel = PanelContainer.new()
	_loot_panel.custom_minimum_size = Vector2(360, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.04, 0.96)
	style.border_color = Color(0.72, 0.74, 0.40, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	_loot_panel.add_theme_stylebox_override("panel", style)
	_loot_panel.position = Vector2(280, 120)
	_loot_panel.z_index = 50
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_loot_panel.add_child(vbox)
	var title := Label.new()
	title.text = "Cuerpo del jugador - [I] para cerrar"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.85, 0.82, 0.5))
	vbox.add_child(title)
	if _loot_items.is_empty():
		var empty := Label.new()
		empty.text = "No hay nada que coger."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
		vbox.add_child(empty)
	else:
		for i in range(_loot_items.size()):
			var item_data: Dictionary = _loot_items[i]
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			vbox.add_child(row)
			var name_label := Label.new()
			var iname := str(item_data.get("item_name", "???"))
			var iqty := int(item_data.get("quantity", 1))
			name_label.text = "%s x%d" % [iname, iqty]
			name_label.custom_minimum_size = Vector2(220, 24)
			name_label.add_theme_color_override("font_color", Color(0.82, 0.80, 0.72))
			row.add_child(name_label)
			var take_btn := Button.new()
			take_btn.text = "Coger"
			take_btn.custom_minimum_size = Vector2(80, 28)
			var idx := i
			take_btn.pressed.connect(func(): _take_loot_item(idx))
			row.add_child(take_btn)
	hud.add_child(_loot_panel)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _close_loot_ui() -> void:
	if _loot_panel != null:
		_loot_panel.queue_free()
		_loot_panel = null
	_loot_dead_peer_id = -1
	_loot_items = []
	if player != null and not player.is_dead:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _take_loot_item(item_index: int) -> void:
	if _loot_dead_peer_id < 0:
		return
	if net != null and net.is_connected:
		net.take_loot.rpc_id(1, _loot_dead_peer_id, item_index)
	# Remove from local list
	if item_index >= 0 and item_index < _loot_items.size():
		_loot_items.remove_at(item_index)
	# Refresh UI
	_show_loot_ui()

func _net_add_looted_item(item_data: Dictionary) -> void:
	if player == null:
		return
	var ItemScript = load("res://scripts/Item.gd")
	var item = ItemScript.from_dict(item_data)
	if item == null:
		return
	if player.inventory != null and player.inventory.has_method("add_item"):
		var added: bool = player.inventory.add_item(item)
		if added:
			if hud != null:
				hud.show_notice("Has cogido: %s" % item.item_name)
		else:
			if hud != null:
				hud.show_notice("No puedes cargar mas peso.")
	else:
		if player.has_node("Inventory"):
			var inv = player.get_node("Inventory")
			if inv != null and inv.has_method("add_item"):
				inv.add_item(item)

func _on_item_dropped(item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3) -> void:
	if item_name == "campfire":
		var cf_id := "player_campfire_%d" % randi()
		_spawn_player_campfire_with_id(cf_id, pos)
		if net != null and net.is_connected and not net.is_host:
			net.campfire_built.rpc_id(1, cf_id, pos)
		return
	if item_name == "shelter":
		var sh_id := "player_shelter_%d" % randi()
		_spawn_player_shelter_with_id(sh_id, pos)
		if net != null and net.is_connected and not net.is_host:
			net.shelter_built.rpc_id(1, sh_id, pos)
		return
	# Dropping a whole animal corpse spawns the model lying on the ground
	if item_name in ["Lobo muerto", "Ciervo muerto", "Zorro muerto", "Animal muerto"]:
		var animal_kind := "wolf"
		if item_name == "Ciervo muerto":
			animal_kind = "deer"
		elif item_name == "Zorro muerto":
			animal_kind = "fox"
		var model_path := "res://assets/external/wolf/WolfAnimated.glb"
		if animal_kind == "deer":
			model_path = "res://assets/external/deer/DeerAnimated.glb"
		elif animal_kind == "fox":
			model_path = "res://assets/external/fox/FoxAnimated.glb"
		var p := pos
		p.y = 0.1
		var drop_id := "animal_drop_%d" % Time.get_ticks_msec()
		var visual_name := "Pickup_" + drop_id
		_try_instance_external_scene([model_path], visual_name, p, Vector3.ONE * 0.9, Vector3(0, randf_range(0, 360), -90), true, 0.06)
		_mark_world_action_visual(visual_name)
		var action = _create_world_action(drop_id, "gut_wolf", item_name, p, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
		action.set_meta("visual_name", visual_name)
		action.set_meta("item_name", item_name)
		action.set_meta("animal_type", animal_kind)
		action.set_meta("item_type", "material")
		action.set_meta("item_weight", 8.0)
		action.set_meta("item_quantity", 1)
		action.set_meta("item_use_value", 0.0)
		action.set_meta("gutted", false)
		return
	var drop_id := "drop_%d_%d" % [Time.get_ticks_msec(), randi() % 1000]
	_spawn_dropped_item_visual(drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos)
	if net != null and net.is_connected:
		net.item_dropped.rpc_id(1, drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos)

func _spawn_raw_meat_visual(drop_id: String, item_name: String, pos: Vector3) -> void:
	var visual_name := "Pickup_" + drop_id
	var meat_model := "res://assets/models/props/cc0_-_raw_meat_4.glb"
	_try_instance_external_scene([meat_model], visual_name, pos, Vector3.ONE * 1.0, Vector3(0, randf_range(0, 360), 0), true, 0.06)
	_mark_world_action_visual(visual_name)
	var maction = _create_world_action(drop_id, "wolf_meat_raw", item_name, pos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
	if maction != null:
		maction.set_meta("visual_name", visual_name)
		maction.set_meta("item_name", item_name)
		maction.set_meta("item_type", "food")
		maction.set_meta("item_weight", 0.3)
		maction.set_meta("item_quantity", 1)
		maction.set_meta("item_use_value", 15.0)

func _spawn_dropped_item_visual(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3) -> void:
	var visual_name := "Pickup_" + drop_id
	var paths: Array = _get_drop_model_paths(item_name, item_type)
	var scale_value := _get_drop_scale(item_name, item_type)
	# Default clothing pickups are pre-flattened in their GLB (smallest extent up)
	# so they only need the survival garments to be tipped 90 deg here.
	var lay_flat := item_name in ["Botas survival"]
	var pre_flat := item_name in ["Camiseta", "Pantalones", "Zapatillas", "Chaqueta militar", "Pantalones militares", "Guantes militares"]
	var rot := Vector3(0, randf_range(0, 360), 0)
	var is_rifle := item_type == "weapon_rifle"
	if is_rifle:
		rot.z += 90.0
	elif lay_flat:
		rot.x += 90.0
	if not paths.is_empty():
		_try_instance_external_scene(paths, visual_name, pos, Vector3.ONE * scale_value, rot, true, 0.06)
		if lay_flat or pre_flat:
			var laid := get_node_or_null(NodePath(visual_name))
			if laid is Node3D:
				_snap_node_bottom_to_y(laid as Node3D, 0.06)
		_mark_world_action_visual(visual_name)
	# Apply black material to dropped Botas survival
	if item_name == "Botas survival":
		var boot_node := get_node_or_null(NodePath(visual_name))
		if boot_node is Node3D:
			_apply_black_material_recursive(boot_node as Node3D)
	# Apply character clothing color to dropped default clothing
	if item_name in ["Camiseta", "Pantalones", "Zapatillas"]:
		var cloth_node := get_node_or_null(NodePath(visual_name))
		if cloth_node is Node3D:
			var gsess := get_node_or_null("/root/GameSession")
			if gsess != null:
				var drop_color: Color = gsess.selected_top_color
				if item_name == "Pantalones":
					drop_color = gsess.selected_bottom_color
				elif item_name == "Zapatillas":
					drop_color = gsess.selected_shoes_color
				_apply_color_material_recursive(cloth_node, drop_color)
	var action_kind := "eat_food" if (item_type == "food" and not item_name.begins_with("Lata de ")) else "pickup_item"
	var action = _create_world_action(drop_id, action_kind, item_name, pos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
	action.set_meta("visual_name", visual_name)
	action.set_meta("item_name", item_name)
	action.set_meta("item_type", item_type)
	action.set_meta("item_weight", item_weight)
	action.set_meta("item_quantity", item_quantity)
	action.set_meta("item_use_value", item_use_value)

func _net_item_dropped(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3) -> void:
	if net != null and net.is_dedicated_server:
		_dropped_items.append({"id": drop_id, "name": item_name, "type": item_type, "weight": item_weight, "qty": item_quantity, "use": item_use_value, "pos": pos})
	if world_actions_by_id.has(drop_id):
		return
	_spawn_dropped_item_visual(drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos)

func _get_drop_model_paths(item_name: String, item_type: String) -> Array:
	match item_type:
		"water":
			if item_name == "Botella de agua":
				return [PLASTIC_BOTTLE_MODEL]
			return [K_SURVIVAL + "bottle-large.glb", K_SURVIVAL + "bottle.glb"]
		"resource":
			if item_name == "Piedra":
				return [SURVIVAL_TOOL_MODELS["stone"]]
			if item_name == "Tronco":
				return [K_SURVIVAL + "tree-log.glb", K_SURVIVAL + "tree-log-small.glb", "res://assets/models/props/wood_stick_01.glb"]
			if item_name == "Palo":
				return ["res://assets/models/props/wood_stick.glb"]
			return [SURVIVAL_TOOL_MODELS["planks"], SURVIVAL_TOOL_MODELS["wood"]]
		"weapon":
			return ["res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/Knife.gltf"]
		"weapon_rifle":
			return ["res://assets/models/weapons/modern_sniper_rifle__free_lowpoly.glb"]
		"tool_matches":
			return ["res://assets/models/props/box_of_matches_north_korea_1955.glb"]
		"food":
			if item_name.begins_with("Carne cruda"):
				return ["res://assets/models/props/cc0_-_raw_meat_4.glb"]
			return [CANNED_FOOD_LOW_MODEL, FOOD_CAN_415G_MODEL]
		"backpack":
			return [ROOT_BACKPACK_MODEL, SURVIVAL_TOOL_MODELS["backpack"]]
		"tool_axe":
			return ["res://assets/models/props/simple_axe.glb", ROOT_GLB_DIR + "axe_survival.glb", SURVIVAL_TOOL_MODELS["axe"]]
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
				"Camiseta":
					return ["res://assets/characters/adapted/pickup_default_tops.glb"]
				"Pantalones":
					return ["res://assets/characters/adapted/pickup_default_bottoms.glb"]
				"Zapatillas":
					return ["res://assets/characters/adapted/pickup_default_shoes.glb"]
				"Guantes de trabajo":
					return [POLY_GARDEN_GLOVES_MODEL]
				"Sombrero de pescador":
					return [POLY_FISHERMANS_HAT_MODEL]
				"Guantes survival":
					return [POLY_GARDEN_GLOVES_MODEL]
				"Botas survival":
					return ["res://assets/characters/adapted/pickup_cloth_feet.glb"]
				"Chaqueta militar":
					return ["res://assets/characters/adapted/pickup_soldier_torso.glb"]
				"Pantalones militares":
					return ["res://assets/characters/adapted/pickup_soldier_legs.glb"]
				"Guantes militares":
					return ["res://assets/characters/adapted/pickup_soldier_hands.glb"]
				_:
					return [K_SURVIVAL + "box-large.glb", K_SURVIVAL + "box.glb"]
		"seed":
			return [K_SURVIVAL + "grass.glb"]
		"misc":
			if item_name == "Botella de plastico":
				return [PLASTIC_BOTTLE_MODEL]
			return [K_SURVIVAL + "box-large.glb", K_SURVIVAL + "box.glb"]
		_:
			return [K_SURVIVAL + "box-large.glb", K_SURVIVAL + "box.glb"]

func _get_drop_scale(item_name: String, item_type: String) -> float:
	match item_type:
		"water":
			if item_name == "Botella de agua":
				return 0.02
			return 1.0
		"resource":
			if item_name == "Tronco":
				return 0.5
			if item_name == "Palo":
				return 0.2
			return 1.0
		"weapon":
			return 0.8
		"weapon_rifle":
			return 0.068
		"food":
			if item_name == "Carne cruda de lobo":
				return 1.0
			return 1.0
		"backpack":
			return 1.2
		"tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe":
			return 1.0
		"tool_matches":
			return 0.0005
		"clothing":
			match item_name:
				"Camiseta":
					return 0.5
				"Pantalones":
					return 0.5
				"Zapatillas":
					return 0.7
				"Guantes survival":
					return 1.2
				"Botas survival":
					return 0.9
				"Chaqueta militar":
					return 0.8
				"Pantalones militares":
					return 0.8
				"Guantes militares":
					return 1.2
				_:
					return 0.7
		"seed":
			return 1.0
		"misc":
			if item_name == "Botella de plastico":
				return 0.02
			return 0.8
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

func _create_debug_overlay() -> void:
	_debug_overlay = CanvasLayer.new()
	_debug_overlay.name = "DebugOverlay"
	_debug_overlay.layer = 110
	_debug_overlay.visible = false
	
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.custom_minimum_size = Vector2(340, 260)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.08, 0.1, 0.85)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	
	_debug_label = Label.new()
	_debug_label.add_theme_font_size_override("font_size", 14)
	_debug_label.add_theme_color_override("font_color", Color(0.4, 0.95, 0.6))
	panel.add_child(_debug_label)
	
	_debug_overlay.add_child(panel)
	add_child(_debug_overlay)

func _toggle_debug_overlay() -> void:
	_debug_visible = not _debug_visible
	if _debug_overlay != null:
		_debug_overlay.visible = _debug_visible

func _update_debug_overlay_text() -> void:
	if _debug_label == null:
		return
	var fps := Engine.get_frames_per_second()
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var mem_mb := float(OS.get_static_memory_usage()) / 1048576.0
	var node_count := get_tree().get_node_count()
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var primitives := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	
	var stream_info := {}
	if world_streaming_mgr != null:
		stream_info = world_streaming_mgr.get_debug_info()
	
	var p_pos := Vector3.ZERO
	if player != null and is_instance_valid(player):
		p_pos = player.global_position
	
	var chunk_coords := Vector2i.ZERO
	if world_streaming_mgr != null:
		chunk_coords = world_streaming_mgr.world_to_chunk_coords(p_pos)
	
	var text := "=== DIAGNÓSTICO DE MUNDO ABIERTO (TECLA 0) ===\n"
	text += "FPS: %d  |  Frame Time: %.2f ms\n" % [fps, process_ms]
	text += "Memoria RAM: %.1f MB\n" % mem_mb
	text += "Nodos en Árbol: %d\n" % node_count
	text += "Draw Calls: %d  |  Primitivas: %d\n" % [draw_calls, primitives]
	text += "----------------------------------------\n"
	text += "Posición Jugador: (%.1f, %.1f, %.1f)\n" % [p_pos.x, p_pos.y, p_pos.z]
	text += "Sector Actual: (%d, %d)\n" % [chunk_coords.x, chunk_coords.y]
	if not stream_info.is_empty():
		text += "Sectores Activos (3x3): %d\n" % stream_info.get("active_sectors", 0)
		text += "Sectores Precargados (5x5): %d\n" % stream_info.get("preloaded_sectors", 0)
		text += "Cola Carga: %d  |  Cola Descarga: %d\n" % [stream_info.get("queued_loads", 0), stream_info.get("queued_unloads", 0)]
		text += "Pool de Sectores: %d\n" % stream_info.get("pool_size", 0)
	
	_debug_label.text = text

#endregion


#region NPCs Y IA
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

#endregion


#region CONSTRUCCIÓN DEL MAPA Y CARRETERAS
func _create_map() -> void:
	var _tm := Time.get_ticks_msec()
	_generated_hills.clear()
	river_segments_data = _default_river_segments()
	_create_invisible_collision_box("GroundCollision", Vector3(0, -0.2, 0), Vector3(MAP_EXTENT * 2.0, 0.2, MAP_EXTENT * 2.0))
	var is_client: bool = net != null and net.is_connected and not net.is_host and not net.is_dedicated_server
	var is_server: bool = net != null and net.is_dedicated_server
	if not is_server:
		_create_leafy_floor_ground()
		if _loading_label != null:
			_loading_label.text = "Generando terreno..."
		await get_tree().process_frame
	if not is_server:
		await _create_grass_ground_cover()
	_tm = Time.get_ticks_msec()
	if not is_server:
		_create_mountain_backdrop()
		# Esperamos frames de física para asegurar que las colisiones del terreno se registren en el servidor de físicas
		await get_tree().physics_frame
		await get_tree().physics_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		_create_mountain_river()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		_create_road()
		await get_tree().process_frame
	if not is_server:
		_create_house(Vector3(-25, 0, -18), "Casa abandonada 1", "house_1", 11.4, 9.4, 4.35)
		await get_tree().process_frame
		if _loading_label != null:
			_loading_label.text = "Construyendo casas..."
		_create_house(Vector3(-38, 0, 18), "Casa abandonada 2", "house_2", 14.0, 11.0, 4.9)
		await get_tree().process_frame
		_create_house(Vector3(23, 0, 18), "Casa abandonada 3", "house_3", 9.0, 7.5, 3.9)
		await get_tree().process_frame
		_create_house(Vector3(42, 0, 26), "Casa abandonada 4", "house_4", 12.5, 10.0, 4.5)
		await get_tree().process_frame
		_create_house(Vector3(-12, 0, 42), "Casa abandonada 5", "house_5", 8.0, 7.0, 3.7)
		await get_tree().process_frame
		_create_house(Vector3(-35, 0, -40), "Casa abandonada 6", "house_6", 10.5, 8.5, 4.1)
		await get_tree().process_frame
		_create_house(Vector3(30, 0, -35), "Casa abandonada 7", "house_7", 13.0, 10.0, 4.7)
		await get_tree().process_frame
		_create_house(Vector3(-45, 0, -5), "Casa abandonada 8", "house_8", 9.5, 8.0, 3.9)
		await get_tree().process_frame
		_create_house(Vector3(35, 0, -8), "Casa abandonada 9", "house_9", 11.0, 9.0, 4.3)
		await get_tree().process_frame
		_create_house(Vector3(-20, 0, 30), "Casa abandonada 10", "house_10", 7.5, 6.5, 3.6)
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		_create_world_details()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		# Light posts and power lines
		_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightA", Vector3(3.0, 0, -22), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
		_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightB", Vector3(3.0, 0, 14), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
		_create_power_line(Vector3(15, 0, -40), Vector3(15, 0, 40))
	_tm = Time.get_ticks_msec()
	if not is_server:
		if _loading_label != null:
			_loading_label.text = "Generando vegetacion..."
		await _create_ground_clutter()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		await _create_tall_grass_fields()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		await _create_grass_carpet()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		await _create_dense_vegetation_zones()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		if _loading_label != null:
			_loading_label.text = "Plantando bosque..."
		await _create_forest()
		await get_tree().process_frame
	_tm = Time.get_ticks_msec()
	if not is_server:
		_create_survival_objectives()
		await get_tree().process_frame
	_create_river_drink_zones()
	# Server needs wildlife blockers registered for nav grid (no visuals)
	if is_server:
		_register_server_house_blockers()
	# Only server simulates wildlife AI and navigation
	if not is_client:
		_build_nav_grid()
		await get_tree().process_frame
		if _loading_label != null:
			_loading_label.text = "Generando fauna..."
		_create_wildlife()
		await get_tree().process_frame
	if not is_server:
		_flush_grass_batches()
		await get_tree().process_frame


const ROAD_HALF_WIDTH := 5.0
const ROAD_START_Z := -52.0
const ROAD_END_Z := 52.0

func _is_on_road(pos: Vector3) -> bool:
	return abs(pos.x) <= ROAD_HALF_WIDTH and pos.z >= ROAD_START_Z - 3.0 and pos.z <= ROAD_END_Z + 3.0

func _create_road() -> void:
	var road_x := 9.0
	var road_z_start := -57.0
	var road_z_end := 57.0
	var road_width := 10.0
	var road_length := road_z_end - road_z_start
	var space_state := get_world_3d().direct_space_state
	# Raycast for ground height at road center
	var mid_z := (road_z_start + road_z_end) * 0.5
	var ray_origin := Vector3(road_x, 100.0, mid_z)
	var ray_end := Vector3(road_x, -200.0, mid_z)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	var ground_y := 0.0
	if not hit.is_empty():
		ground_y = float(hit["position"].y)
	# Create dirt road as a flat plane with proper UV tiling
	var tile_size := 2.0
	var tiles_x := int(road_width / tile_size)
	var tiles_z := int(road_length / tile_size)
	var road_plane := PlaneMesh.new()
	road_plane.size = Vector2(road_width, road_length)
	road_plane.orientation = PlaneMesh.FACE_Y
	road_plane.subdivide_width = max(1, tiles_x - 1)
	road_plane.subdivide_depth = max(1, tiles_z - 1)
	var road_mi := MeshInstance3D.new()
	road_mi.mesh = road_plane
	road_mi.name = "DirtRoad"
	var road_mat := StandardMaterial3D.new()
	road_mat.roughness = 1.0
	road_mat.metallic = 0.0
	road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	road_mat.texture_repeat = true
	# Load Ground032 textures (now imported by Godot)
	var tex_dir := "res://assets/textures/ground032/"
	var color_tex := load(tex_dir + "Ground032_4K-JPG_Color.jpg")
	if color_tex != null:
		road_mat.albedo_texture = color_tex
		road_mat.albedo_color = Color(0.45, 0.38, 0.30)
	else:
		push_warning("[ROAD] Failed to load color texture")
		road_mat.albedo_color = Color(0.45, 0.32, 0.2)
	var normal_tex := load(tex_dir + "Ground032_4K-JPG_NormalGL.jpg")
	if normal_tex != null:
		road_mat.normal_texture = normal_tex
		road_mat.normal_enabled = true
	var rough_tex := load(tex_dir + "Ground032_4K-JPG_Roughness.jpg")
	if rough_tex != null:
		road_mat.roughness_texture = rough_tex
		road_mat.roughness_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_GREEN
	var ao_tex := load(tex_dir + "Ground032_4K-JPG_AmbientOcclusion.jpg")
	if ao_tex != null:
		road_mat.ao_texture = ao_tex
		road_mat.ao_texture_channel = StandardMaterial3D.TEXTURE_CHANNEL_RED
	# Set UV1 scale for tiling (for 2D UVs: .x = U across width, .y = V along length)
	road_mat.uv1_scale = Vector3(float(tiles_x), float(tiles_z), 1.0)
	road_mi.material_override = road_mat
	add_child(road_mi)
	road_mi.global_position = Vector3(road_x, ground_y + 0.02, mid_z)
	# Static body for collision
	var road_body := StaticBody3D.new()
	road_body.name = "RoadCollision"
	add_child(road_body)
	road_body.global_position = Vector3(road_x, ground_y + 0.02, mid_z)
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(road_width, 0.1, road_length)
	var col := CollisionShape3D.new()
	col.shape = col_shape
	road_body.add_child(col)
	# Procedural grass along both road edges, dense at edge, fading to merge with existing grass
	var grass_depth := 20.0
	var tuft_spacing := 0.18
	var num_tufts := int(road_length / tuft_spacing)
	var grass_base := Color(0.20, 0.34, 0.12)
	var color_var := Color(0.34, 0.46, 0.16)
	for side in [-1, 1]:
		for i in range(num_tufts):
			var z_pos: float = road_z_start + (i + 0.5) * tuft_spacing + _world_rng.randf_range(-0.08, 0.08)
			# Dense near road, gradually thinning to merge with existing grass
			var blade_count := 18
			for j in range(blade_count):
				# Bias towards near-road but with long tail for seamless merge
				var t: float = pow(_world_rng.randf(), 2.5) # 0 = near road, 1 = far, strongly biased towards 0
				var offset_x: float = t * grass_depth + _world_rng.randf_range(-0.25, 0.25)
				var edge_x: float = road_x + side * (road_width * 0.5 + 0.05 + offset_x)
				var pos := Vector3(edge_x, 0.02, z_pos + _world_rng.randf_range(-0.15, 0.15))
				# Height decreases very gradually towards outside
				var h := _world_rng.randf_range(0.15, 0.35) * (1.0 - t * 0.3)
				var r := _world_rng.randf_range(0.18, 0.38)
				var c := grass_base.lerp(color_var, _world_rng.randf()).darkened(_world_rng.randf_range(0.0, 0.12))
				_queue_grass_instance(pos, h, r, c)

func _get_mesh_global_min_y(mi: MeshInstance3D) -> float:
	var aabb := mi.get_aabb()
	var min_y := INF
	for cx in [aabb.position.x, aabb.end.x]:
		for cy in [aabb.position.y, aabb.end.y]:
			for cz in [aabb.position.z, aabb.end.z]:
				var wc := mi.global_transform * Vector3(cx, cy, cz)
				min_y = min(min_y, wc.y)
	return min_y

func _get_mesh_global_max_y(mi: MeshInstance3D) -> float:
	var aabb := mi.get_aabb()
	var max_y := -INF
	for cx in [aabb.position.x, aabb.end.x]:
		for cy in [aabb.position.y, aabb.end.y]:
			for cz in [aabb.position.z, aabb.end.z]:
				var wc := mi.global_transform * Vector3(cx, cy, cz)
				max_y = max(max_y, wc.y)
	return max_y

func _get_bounds_in_node_space(
	mesh_instance: MeshInstance3D,
	target_space: Node3D
) -> AABB:
	var source_aabb := mesh_instance.get_aabb()
	var mesh_to_target := (
		target_space.global_transform.affine_inverse()
		* mesh_instance.global_transform
	)
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for x in [source_aabb.position.x, source_aabb.end.x]:
		for y in [source_aabb.position.y, source_aabb.end.y]:
			for z in [source_aabb.position.z, source_aabb.end.z]:
				var point := mesh_to_target * Vector3(x, y, z)
				minimum.x = min(minimum.x, point.x)
				minimum.y = min(minimum.y, point.y)
				minimum.z = min(minimum.z, point.z)
				maximum.x = max(maximum.x, point.x)
				maximum.y = max(maximum.y, point.y)
				maximum.z = max(maximum.z, point.z)
	return AABB(minimum, maximum - minimum)

func _print_mesh_hierarchy(node: Node, indent: String) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
	for child in node.get_children():
		_print_mesh_hierarchy(child, indent + "  ")

func _get_world_y_extent(model_root: Node) -> float:
	var meshes: Array = []
	_collect_mesh_instances(model_root, meshes)
	var minimum_y := INF
	var maximum_y := -INF
	for mn in meshes:
		var mi := mn as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var aabb := mi.get_aabb()
		for cx in [aabb.position.x, aabb.end.x]:
			for cy in [aabb.position.y, aabb.end.y]:
				for cz in [aabb.position.z, aabb.end.z]:
					var wc := mi.global_transform * Vector3(cx, cy, cz)
					minimum_y = min(minimum_y, wc.y)
					maximum_y = max(maximum_y, wc.y)
	if minimum_y == INF:
		return INF
	return maximum_y - minimum_y

func _register_server_house_blockers() -> void:
	var house_data := [
		{"origin": Vector3(-25, 0, -18), "w": 11.4, "d": 9.4},
		{"origin": Vector3(-38, 0, 18), "w": 14.0, "d": 11.0},
		{"origin": Vector3(23, 0, 18), "w": 9.0, "d": 7.5},
		{"origin": Vector3(42, 0, 26), "w": 12.5, "d": 10.0},
		{"origin": Vector3(-12, 0, 42), "w": 8.0, "d": 7.0},
		{"origin": Vector3(-35, 0, -40), "w": 10.5, "d": 8.5},
		{"origin": Vector3(30, 0, -35), "w": 13.0, "d": 10.0},
		{"origin": Vector3(-45, 0, -5), "w": 9.5, "d": 8.0},
		{"origin": Vector3(35, 0, -8), "w": 11.0, "d": 9.0},
		{"origin": Vector3(-20, 0, 30), "w": 7.5, "d": 6.5},
	]
	for hd in house_data:
		var origin: Vector3 = hd["origin"]
		var half_w: float = hd["w"] * 0.5
		var half_d: float = hd["d"] * 0.5
		var idx := _register_wildlife_blocker(origin, max(half_w, half_d) + 2.0)
		wildlife_blockers[idx]["house_bounds"] = Rect2(origin.x - half_w - 0.3, origin.z - half_d - 0.5, hd["w"] + 0.6, hd["d"] + 1.0)

func _create_house(origin: Vector3, label: String, id_prefix: String, width: float, depth: float, height: float) -> void:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	var door_w := 1.8
	var return_w: float = min(2.0, half_w * 0.32)
	var front_seg_w: float = half_w - door_w * 0.5 - return_w + 0.5
	var front_seg_c: float = half_w - front_seg_w * 0.5
	var return_c: float = door_w * 0.5 + return_w * 0.5
	var door_h := 3.2
	var wall_t := 0.35
	var win_y := height * 0.6
	var win_w: float = min(1.5, front_seg_w * 0.72)
	var win_h: float = win_w * 0.8
	var blocker_idx := _register_wildlife_blocker(origin, max(half_w, half_d) + 2.0)
	#_create_label(label, origin + Vector3(0, 4.05, -4.65))
	_create_house_overgrowth(origin, label, half_w, half_d)
	_create_house_foundation(origin, label, half_w, half_d, front_seg_c, front_seg_w)
	_create_house_floor(origin, label, width, depth)
	# Back wall with two window holes (closer to center for smaller houses)
	var back_win_x := width * 0.22
	_create_textured_wall_with_openings(label + " Back", origin + Vector3(0, 0, -half_d), Vector3(width, height, wall_t), Vector3.ZERO, [
		[-back_win_x, win_y, win_w, win_h],
		[back_win_x, win_y, win_w, win_h],
	])
	# Left wall with one window hole (closer to front/door)
	var side_win_z := depth * 0.28
	_create_textured_wall_with_openings(label + " Left", origin + Vector3(-half_w, 0, 0), Vector3(wall_t, height, depth), Vector3.ZERO, [
		[side_win_z, win_y, win_w, win_h],
	])
	# Right wall with one window hole
	_create_textured_wall_with_openings(label + " Right", origin + Vector3(half_w, 0, 0), Vector3(wall_t, height, depth), Vector3.ZERO, [
		[side_win_z, win_y, win_w, win_h],
	])
	# FrontA with window hole
	_create_textured_wall_with_openings(label + " FrontA", origin + Vector3(-front_seg_c, 0, half_d), Vector3(front_seg_w, height, wall_t), Vector3.ZERO, [
		[0.0, win_y, win_w, win_h],
	])
	# FrontB with window hole
	_create_textured_wall_with_openings(label + " FrontB", origin + Vector3(front_seg_c, 0, half_d), Vector3(front_seg_w, height, wall_t), Vector3.ZERO, [
		[0.0, win_y, win_w, win_h],
	])
	_create_textured_wall(label + " FrontLeftReturn", origin + Vector3(-return_c, 0, half_d), Vector3(return_w, height, wall_t), Vector3.ZERO)
	_create_textured_wall(label + " FrontRightReturn", origin + Vector3(return_c, 0, half_d), Vector3(return_w, height, wall_t), Vector3.ZERO)
	# Door lintel
	_create_textured_wall(label + " DoorLintel", origin + Vector3(0, door_h, half_d), Vector3(door_w, height - door_h, wall_t), Vector3.ZERO)
	_create_house_details(origin, label, width, depth, height, half_w, half_d, front_seg_c)
	_create_house_interior(origin, label, id_prefix, width, depth, height)
	# Roof collision
	_create_invisible_collision_box(label + " RoofCollision", origin + Vector3(0, height, 0), Vector3(width, 0.7, depth))
	# Link door to wildlife blocker so wolves can enter when door is open
	var door_node := get_node_or_null(label + " Door")
	if door_node != null:
		wildlife_blockers[blocker_idx]["door"] = door_node
		wildlife_blockers[blocker_idx]["house_bounds"] = Rect2(origin.x - half_w - 0.3, origin.z - half_d - 0.5, width + 0.6, depth + 1.0)

func _create_house_foundation(origin: Vector3, label: String, half_w: float, half_d: float, front_seg_c: float, front_seg_w: float) -> void:
	# Concrete skirting (perimeter beams) under the brick walls, so the houses
	# read as "brick over a concrete base" without covering the wooden floor.
	# Front is split (FrontLeft/FrontRight) to leave the doorway gap clear.
	var beams := [
		{"pos": Vector3(0, 0, -(half_d + 0.08)), "size": Vector3(half_w * 2.0 + 0.9, 0.5, 0.6)},
		{"pos": Vector3(-front_seg_c, 0, half_d + 0.08), "size": Vector3(front_seg_w + 0.9, 0.5, 0.6)},
		{"pos": Vector3(front_seg_c, 0, half_d + 0.08), "size": Vector3(front_seg_w + 0.9, 0.5, 0.6)},
		{"pos": Vector3(-(half_w + 0.08), 0, 0), "size": Vector3(0.6, 0.5, half_d * 2.0 + 0.8)},
		{"pos": Vector3(half_w + 0.08, 0, 0), "size": Vector3(0.6, 0.5, half_d * 2.0 + 0.8)}
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

func _create_house_floor(origin: Vector3, label: String, width: float, depth: float) -> void:
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
	mesh_instance.scale = Vector3(width - 0.4, 0.08, depth - 0.4)
	mesh_instance.position.y = 0.04
	mesh_instance.material_override = floor_mat
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.4, 0.08, depth - 0.4)
	collision.shape = shape
	collision.position.y = 0.04
	body.add_child(collision)
	add_child(body)

func _create_house_overgrowth(origin: Vector3, label: String, half_w: float, half_d: float) -> void:
	# Sparse grass around houses — just a few weeds near walls
	for i in range(20):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := origin + Vector3(side * _world_rng.randf_range(half_w + 0.2, half_w + 0.95), 0.055, _world_rng.randf_range(-(half_d - 0.1), half_d + 0.1))
		_create_house_grass_asset(label + " SideGrass", pos, _world_rng.randf_range(0.22, 0.45))
	for i in range(15):
		var fb := 1.0 if i % 2 == 0 else -1.0
		var pos := origin + Vector3(_world_rng.randf_range(-(half_w - 0.2), half_w - 0.2), 0.055, fb * _world_rng.randf_range(half_d + 0.2, half_d + 0.95))
		_create_house_grass_asset(label + " WallWeed", pos, _world_rng.randf_range(0.20, 0.42))
	# Light grass fill from house edge to 12 units
	var grass_radius: float = max(half_w, half_d) + 2.0
	for i in range(500):
		var angle := _world_rng.randf_range(0.0, TAU)
		var dist := _world_rng.randf_range(grass_radius, 12.0)
		var pos := origin + Vector3(cos(angle) * dist, 0.04, sin(angle) * dist)
		_create_grass_clump(pos, _world_rng.randf_range(0.4, 1.15), Color(0.15, 0.30, 0.10).lerp(Color(0.32, 0.42, 0.14), _world_rng.randf()))

func _create_house_grass_asset(node_name: String, pos: Vector3, scale_value: float) -> void:
	_create_grass_clump(pos, scale_value * 1.6, Color(0.17, 0.33, 0.10).lerp(Color(0.35, 0.43, 0.15), _world_rng.randf()))

func _create_new_world_props() -> void:
	var _dbg_file := FileAccess.open("user://scrap_car_debug.txt", FileAccess.WRITE)
	if _dbg_file:
		_dbg_file.store_line("=== _create_new_world_props START ===")
	var space_state := get_world_3d().direct_space_state
	# Abandoned junk car on the road (angled across road)
	var car_s := Vector3.ONE * 2.0
	var car_pos := Vector3(9.0, 0.0, -30.0)
	var car_rot := Vector3(0, 70, 0)
	var car_ground_y := _raycast_ground_y(space_state, car_pos)
	if _try_instance_external_scene([ABANDONED_JUNK_CAR_MODEL], "JunkCar0", car_pos, car_s, car_rot, true, car_ground_y):
		var junk_node := get_node_or_null("JunkCar0")
		var junk_height := 2.0
		var junk_coll_pos := car_pos
		if junk_node != null and junk_node is Node3D:
			var jn := junk_node as Node3D
			jn.force_update_transform()
			junk_coll_pos = Vector3(car_pos.x, jn.position.y, car_pos.z)
		_create_invisible_collision_box_rotated("JunkCarCollision0", junk_coll_pos, Vector3(2.0, junk_height, 4.0), float(car_rot.y))
	# Scrap barricade car abandoned on the road (different angle)
	var scrap_s := Vector3.ONE * 0.5
	var scrap_pos := Vector3(9.0, 0.0, 20.0)
	var scrap_rot := Vector3(0, -40, 0)
	var scrap_ground_y := _raycast_ground_y(space_state, scrap_pos)
	if _dbg_file:
		_dbg_file.store_line("scrap_ground_y=" + str(scrap_ground_y) + " pos=" + str(scrap_pos) + " scale=" + str(scrap_s))
		_dbg_file.close()
	var scrap_ok := _try_instance_external_scene([SCRAP_BARRICADE_CAR_MODEL], "ScrapBarricadeCar", scrap_pos, scrap_s, scrap_rot, true, scrap_ground_y)
	_dbg_file = FileAccess.open("user://scrap_car_debug.txt", FileAccess.READ_WRITE)
	if _dbg_file:
		_dbg_file.seek_end()
		_dbg_file.store_line("scrap_ok=" + str(scrap_ok))
	if scrap_ok:
		var scrap_node := get_node_or_null("ScrapBarricadeCar")
		var scrap_height := 2.5
		if scrap_node != null and scrap_node is Node3D:
			var sn := scrap_node as Node3D
			sn.force_update_transform()
			sn.position.y += SCRAP_CAR_Y_CORRECTION
			if _dbg_file:
				_dbg_file.store_line("final_pos=" + str(sn.global_position) + " ground_y=" + str(scrap_ground_y))
			scrap_height = 1.0
			if _dbg_file:
				_dbg_file.store_line("height=" + str(scrap_height))
		_create_invisible_collision_box_rotated("ScrapBarricadeCarCollision", Vector3(scrap_pos.x, scrap_pos.y + 1.885811 + SCRAP_CAR_Y_CORRECTION, scrap_pos.z), Vector3(2.0, scrap_height, 4.0), float(scrap_rot.y))
		if _dbg_file:
			_dbg_file.store_line("=== MESH HIERARCHY DUMP ===")
			var _meshes := []
			_collect_mesh_instances(scrap_node, _meshes)
			for _mi in _meshes:
				var _mi3d := _mi as MeshInstance3D
				if _mi3d and _mi3d.mesh:
					_mi3d.force_update_transform()
					var _aabb := _mi3d.get_aabb()
					var _waabb := _mi3d.global_transform * _aabb
					_dbg_file.store_line("  mesh=" + str(_mi3d.name) + " local_aabb=" + str(_aabb) + " world_aabb=" + str(_waabb) + " parent_path=" + str(_mi3d.get_parent().get_path()))
	if _dbg_file:
		_dbg_file.store_line("=== _create_new_world_props END ===")
		_dbg_file.close()
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
	_create_new_world_props()
	_create_fence_line(Vector3(-8, 0, -9), Vector3(-8, 0, 8), 5)
	_create_fence_line(Vector3(16, 0, 32), Vector3(16, 0, 48), 6)

func _create_dayz_interaction_examples() -> void:
	_spawn_interaction_item(BACKPACK_ITEM_SCENE, Vector3(8.35, 0.05, 2.5), Vector3(0, -18, 0))

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
	#_create_label("Objetivo: construir una cabana", Vector3(-54, 2.8, 48))
	for i in range(5):
		var wood_pos := Vector3(_world_rng.randf_range(-62, -28), 0.04, _world_rng.randf_range(12, 62))
		var log_a_name := "HarvestableLogA_%d" % i
		var log_b_name := "HarvestableLogB_%d" % i
		var wood_spawned_a := _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], log_a_name, wood_pos + Vector3(-0.25, 0.04, 0.0), Vector3.ONE * 0.72, Vector3(0, _world_rng.randf_range(0, 180), 0), true, 0.04)
		var wood_spawned_b := _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], log_b_name, wood_pos + Vector3(0.25, 0.04, 0.08), Vector3.ONE * 0.58, Vector3(0, _world_rng.randf_range(0, 180), 0), true, 0.04)
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
		var along_off := seg_along * (seg_size.x * 0.5 - _world_rng.randf_range(1.2, 3.0)) * end_sign
		var bank_dist := seg_size.y * 0.5 + _world_rng.randf_range(0.7, 1.4)
		var pos_in := seg_center + along_off + seg_across * bank_dist
		var pos_out := seg_center + along_off - seg_across * bank_dist
		# Place on the land side that is closer to the map centre (playable interior).
		var stone_pos: Vector3 = pos_in if Vector2(pos_in.x, pos_in.z).length() < Vector2(pos_out.x, pos_out.z).length() else pos_out
		stone_pos.y = 0.04
		var stone_visual_name := "StonePickup_%d" % i
		if not _try_instance_external_scene([SURVIVAL_TOOL_MODELS["stone"]], stone_visual_name, stone_pos, Vector3.ONE * _world_rng.randf_range(0.65, 0.92), Vector3(0, _world_rng.randf_range(0, 180), 0), true, 0.04):
			continue
		_mark_world_action_visual(stone_visual_name)
		var stone_action = _create_world_action("stone_%d" % i, "stone", "Piedras utiles", stone_pos, Vector3(1.2, 0.75, 1.1), Color(0.31, 0.30, 0.26), false, false)
		stone_action.set_meta("visual_name", stone_visual_name)
		# Cover the pile with grass tufts so it blends into the river bank.
		for g in range(5 + _world_rng.randi() % 4):
			var grass_pos := stone_pos + seg_along * _world_rng.randf_range(-0.95, 0.95) + seg_across * _world_rng.randf_range(-0.30, 0.95)
			grass_pos.y = 0.05
			_create_grass_clump(grass_pos, _world_rng.randf_range(0.85, 1.45), Color(0.13, 0.30, 0.09).lerp(Color(0.34, 0.42, 0.13), _world_rng.randf()))
	_create_world_action("fish_north", "fish", "Zona de pesca", Vector3(-35, 0.05, -57), Vector3(2.8, 0.7, 1.6), Color(0.09, 0.16, 0.14), true, false)
	_create_world_action("fish_south", "fish", "Zona de pesca", Vector3(22, 0.05, 64), Vector3(2.8, 0.7, 1.6), Color(0.09, 0.16, 0.14), true, false)
	_create_world_action("hunt_trail", "hunt", "Rastro de animal", Vector3(-50, 0.04, 28), Vector3(1.8, 0.65, 1.2), Color(0.16, 0.11, 0.055), true, false)
	_create_backpack_pickup("small_backpack_pickup", _find_safe_loot_pos())
	_create_tool_pickup("loose_axe_0", "axe_tool", "Hacha", "res://assets/models/props/simple_axe.glb", _find_safe_loot_pos(), 1.2, Vector3(0, 45, 0))
	_create_tool_pickup("loose_matches_0", "matches_tool", "Cerillas", "res://assets/models/props/box_of_matches_north_korea_1955.glb", _find_safe_loot_pos(), 0.0005, Vector3(0, 30, 0))
	_create_loose_survival_pickups()
	_create_house_loot()

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

func _create_wildlife() -> void:
	var player_start := Vector3(8, 0.0, 2.5)
	# Deer: large outer ring routes around the expanded map
	var deer_routes := [
		_build_circular_route(55.0, 0.0, 10, 6.0),
		_build_circular_route(85.0, PI * 0.5, 10, 6.0),
		_build_circular_route(115.0, PI, 10, 7.0),
		_build_circular_route(140.0, PI * 1.5, 10, 8.0),
		_build_circular_route(165.0, PI * 0.25, 12, 9.0),
		_build_circular_route(180.0, PI * 0.75, 12, 10.0),
	]
	for dr in deer_routes:
		_create_deer_pair(dr)
	
	# Foxes: territorial patrols in 10 distinct zones across the full map
	var fox_zones := [
		[Vector3(-85, 0, -60), Vector3(-45, 0, -20)],
		[Vector3(50, 0, 80), Vector3(90, 0, 40)],
		[Vector3(-110, 0, 70), Vector3(-70, 0, 110)],
		[Vector3(60, 0, -100), Vector3(100, 0, -60)],
		[Vector3(-40, 0, 120), Vector3(10, 0, 150)],
		[Vector3(120, 0, 10), Vector3(160, 0, 50)],
		[Vector3(-150, 0, -80), Vector3(-110, 0, -120)],
		[Vector3(130, 0, -110), Vector3(170, 0, -70)],
		[Vector3(-130, 0, 130), Vector3(-90, 0, 160)],
		[Vector3(90, 0, 130), Vector3(130, 0, 160)],
	]
	for fz in fox_zones:
		var fox_route := _build_zigzag_route(fz[0], fz[1], 6, 6.0)
		_create_wildlife_animal("fox", fox_route)
	
	# Wolves: spread across 12 expanded quadrants of the open world
	var wolf_quadrants := [
		Vector3(-120, 0, -120), Vector3(0, 0, -135), Vector3(120, 0, -120),
		Vector3(-140, 0, 0), Vector3(140, 0, 0), Vector3(-120, 0, 120),
		Vector3(0, 0, 135), Vector3(120, 0, 120), Vector3(-60, 0, -60),
		Vector3(60, 0, -60), Vector3(-60, 0, 60), Vector3(60, 0, 60)
	]
	for i in range(wolf_quadrants.size()):
		var center: Vector3 = wolf_quadrants[i] + Vector3(_world_rng.randf_range(-20, 20), 0.0, _world_rng.randf_range(-20, 20))
		for _retry in range(30):
			if not _is_near_wildlife_blocker(center, 5.0):
				break
			center = wolf_quadrants[i] + Vector3(_world_rng.randf_range(-20, 20), 0.0, _world_rng.randf_range(-20, 20))
		var route: Array = []
		for j in range(12):
			var wp: Vector3 = center + Vector3(_world_rng.randf_range(-45, 45), 0.0, _world_rng.randf_range(-45, 45))
			wp.x = clamp(wp.x, -180, 180)
			wp.z = clamp(wp.z, -180, 180)
			for _wp_retry in range(10):
				if not _is_near_wildlife_blocker(wp, 2.0):
					break
				wp = center + Vector3(_world_rng.randf_range(-45, 45), 0.0, _world_rng.randf_range(-45, 45))
				wp.x = clamp(wp.x, -180, 180)
				wp.z = clamp(wp.z, -180, 180)
			route.append(wp)
		_create_wildlife_animal("wolf", route)
		var _saved_rng_state := _world_rng.state
		await get_tree().process_frame
		_world_rng.state = _saved_rng_state

func _check_wildlife_respawn() -> void:
	var alive_deer := 0
	var alive_fox := 0
	var alive_wolf := 0
	for node in get_tree().get_nodes_in_group("wildlife"):
		if node is WildlifeController and not node._is_dead:
			match node.animal_type:
				"deer":
					alive_deer += 1
				"fox":
					alive_fox += 1
				"wolf":
					alive_wolf += 1
	# Respawn one animal at a time, prioritizing the most depleted species
	if alive_wolf < 12 and alive_wolf <= alive_fox and alive_wolf <= alive_deer:
		var center := Vector3(randf_range(-150, 150), 0.0, randf_range(-150, 150))
		for _retry in range(30):
			if not _is_near_wildlife_blocker(center, 5.0):
				break
			center = Vector3(randf_range(-150, 150), 0.0, randf_range(-150, 150))
		var route: Array = []
		for j in range(12):
			var wp: Vector3 = center + Vector3(randf_range(-45, 45), 0.0, randf_range(-45, 45))
			wp.x = clamp(wp.x, -180, 180)
			wp.z = clamp(wp.z, -180, 180)
			for _wp_retry in range(10):
				if not _is_near_wildlife_blocker(wp, 2.0):
					break
				wp = center + Vector3(randf_range(-45, 45), 0.0, randf_range(-45, 45))
				wp.x = clamp(wp.x, -180, 180)
				wp.z = clamp(wp.z, -180, 180)
			route.append(wp)
		_create_wildlife_animal("wolf", route)
	elif alive_deer < 12 and alive_deer <= alive_fox:
		var deer_route := _build_circular_route(randf_range(50.0, 180.0), randf() * TAU, 10, 7.0)
		_create_deer_pair(deer_route)
	elif alive_fox < 10:
		var fox_zone := Vector3(randf_range(-140, 140), 0.0, randf_range(-140, 140))
		var fox_route := _build_zigzag_route(fox_zone, fox_zone + Vector3(25, 0, 15), 6, 6.0)
		_create_wildlife_animal("fox", fox_route)

# Build a circular patrol route around the map center.
# radius: distance from center, angle_offset: starting angle in radians,
# num_points: waypoints around the circle, jitter: random offset per point.
func _build_circular_route(radius: float, angle_offset: float, num_points: int, jitter: float) -> Array:
	var route: Array = []
	for i in range(num_points):
		var angle := angle_offset + TAU * float(i) / float(num_points)
		var r := radius + _world_rng.randf_range(-jitter, jitter)
		var pos := Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		pos.x = clamp(pos.x, -180.0, 180.0)
		pos.z = clamp(pos.z, -180.0, 180.0)
		# Sanitize: push point away from blocked areas
		if not is_wildlife_allowed_at(pos):
			pos = _find_allowed_near(pos, 3.0)
		route.append(pos)
	return route

func _build_zigzag_route(corner_a: Vector3, corner_b: Vector3, num_points: int, jitter: float) -> Array:
	var route: Array = []
	for i in range(num_points):
		var t := float(i) / float(num_points - 1) if num_points > 1 else 0.0
		var base := corner_a.lerp(corner_b, t)
		var perp := (corner_b - corner_a).cross(Vector3.UP).normalized() if (corner_b - corner_a).length() > 0.01 else Vector3.RIGHT
		var offset := perp * _world_rng.randf_range(-jitter, jitter)
		var pos := base + offset
		pos.x = clamp(pos.x, -180.0, 180.0)
		pos.z = clamp(pos.z, -180.0, 180.0)
		if not is_wildlife_allowed_at(pos):
			pos = _find_allowed_near(pos, 3.0)
		route.append(pos)
	return route

func _find_allowed_near(origin: Vector3, max_radius: float) -> Vector3:
	for radius in [2.0, 4.0, 6.0, 9.0, 13.0, 18.0]:
		if radius > max_radius and max_radius > 0.0:
			break
		for i in range(16):
			var angle := TAU * float(i) / 16.0
			var candidate := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -65.0, 65.0)
			candidate.z = clamp(candidate.z, -65.0, 65.0)
			if is_wildlife_allowed_at(candidate):
				return candidate
	return origin

func _random_pos_far_from(origin: Vector3, min_dist: float, world_range: float) -> Vector3:
	var pos := Vector3.ZERO
	for _attempt in range(50):
		pos = Vector3(randf_range(-world_range, world_range), 0.0, randf_range(-world_range, world_range))
		if Vector2(pos.x, pos.z).distance_to(Vector2(origin.x, origin.z)) >= min_dist:
			break
	return pos

func _random_pos_far_from_all(origin: Vector3, others: Array, min_dist: float, min_from_others: float, world_range: float) -> Vector3:
	var pos := Vector3.ZERO
	for _attempt in range(80):
		pos = Vector3(randf_range(-world_range, world_range), 0.0, randf_range(-world_range, world_range))
		if Vector2(pos.x, pos.z).distance_to(Vector2(origin.x, origin.z)) < min_dist:
			continue
		var ok := true
		for other in others:
			if Vector2(pos.x, pos.z).distance_to(Vector2(other.x, other.z)) < min_from_others:
				ok = false
				break
		if ok and not is_wildlife_allowed_at(pos):
			ok = false
		if ok:
			break
	return pos

func _create_deer_pair(route: Array) -> void:
	var offsets := [Vector3(-2.4, 0.0, -1.6), Vector3(2.4, 0.0, 1.6)]
	for offset in offsets:
		var shifted: Array = []
		for point in route:
			shifted.append((point as Vector3) + offset)
		_create_wildlife_animal("deer", shifted)

var _animal_id_counter := 0

func _create_wildlife_animal(kind: String, points: Array) -> void:
	var animal = WildlifeControllerScript.new()
	animal.name = "Wildlife_%s_%d" % [kind, _animal_id_counter]
	_animal_id_counter += 1
	add_child(animal)
	animal.setup(kind, points)

#endregion


#region ACCIONES DEL MUNDO Y PICKUPS
func _create_world_action(id: String, action_type: String, label: String, pos: Vector3, size: Vector3, color: Color, repeatable: bool, marker_visible := true):
	var action = WorldActionScript.new()
	action.name = "WorldAction_" + id
	action.position = pos
	action.setup(id, action_type, label, size, color, repeatable, marker_visible)
	add_child(action)
	world_actions_by_id[id] = action
	action.disable_collision()
	return action

func _create_tool_pickup(id: String, action_type: String, label: String, model_path: String, pos: Vector3, scale_value: float, rot: Vector3) -> void:
	var visual_name := "Pickup_" + id
	var spawned := _try_instance_external_scene([model_path], visual_name, pos, Vector3.ONE * scale_value, rot, true, 0.05)
	if not spawned:
		push_warning("No se crea %s porque falta/carga mal el asset: %s" % [label, model_path])
		return
	var tool_node := get_node_or_null(visual_name)
	if tool_node != null:
		_remove_collision_from_node(tool_node)
	var action = _create_world_action(id, action_type, label, pos, Vector3(1.2, 0.75, 1.2), Color(0.10, 0.095, 0.07), false, false)
	action.set_meta("visual_name", visual_name)

func _create_loose_survival_pickups() -> void:
	var Q_WEAPONS := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/"
	var pickups := [
		{"id": "loose_knife_0", "name": "Cuchillo", "type": "weapon", "weight": 0.35, "qty": 1, "use": 0.0, "paths": [Q_WEAPONS + "Knife.gltf"], "scale": 0.55, "rot": Vector3(0, 38, 82), "color": Color(0.20, 0.20, 0.18)},
		{"id": "loose_knife_1", "name": "Cuchillo", "type": "weapon", "weight": 0.35, "qty": 1, "use": 0.0, "paths": [Q_WEAPONS + "Knife.gltf"], "scale": 0.55, "rot": Vector3(0, -20, 82), "color": Color(0.20, 0.20, 0.18)},
		{"id": "loose_knife_2", "name": "Cuchillo", "type": "weapon", "weight": 0.35, "qty": 1, "use": 0.0, "paths": [Q_WEAPONS + "Knife.gltf"], "scale": 0.55, "rot": Vector3(0, 15, 82), "color": Color(0.20, 0.20, 0.18)},
		{"id": "surv_gloves", "name": "Guantes survival", "type": "clothing", "weight": 0.3, "qty": 1, "use": 0.08, "paths": [POLY_GARDEN_GLOVES_MODEL], "scale": 1.5, "rot": Vector3(0, 60, 0), "color": Color(0.16, 0.12, 0.08)},
		{"id": "surv_boots", "name": "Botas survival", "type": "clothing", "weight": 1.2, "qty": 1, "use": 0.18, "paths": ["res://assets/characters/adapted/pickup_cloth_feet.glb"], "scale": 0.9, "rot": Vector3(0, -40, 0), "flat": true, "color": Color(0.10, 0.09, 0.07)},
		{"id": "soldier_torso", "name": "Chaqueta militar", "type": "clothing", "weight": 1.5, "qty": 1, "use": 0.20, "paths": ["res://assets/characters/adapted/pickup_soldier_torso.glb"], "scale": 0.8, "rot": Vector3(0, 45, 0), "flat": false, "color": Color(0.15, 0.18, 0.12)},
		{"id": "soldier_legs", "name": "Pantalones militares", "type": "clothing", "weight": 1.0, "qty": 1, "use": 0.14, "paths": ["res://assets/characters/adapted/pickup_soldier_legs.glb"], "scale": 0.8, "rot": Vector3(0, -25, 0), "flat": false, "color": Color(0.12, 0.14, 0.10)},
		{"id": "soldier_hands", "name": "Guantes militares", "type": "clothing", "weight": 0.3, "qty": 1, "use": 0.08, "paths": ["res://assets/characters/adapted/pickup_soldier_hands.glb"], "scale": 1.5, "rot": Vector3(0, 60, 0), "flat": false, "color": Color(0.10, 0.12, 0.08)},
		{"id": "loose_bottle_0", "name": "Botella de plastico", "type": "misc", "weight": 0.1, "qty": 1, "use": 0.0, "paths": [PLASTIC_BOTTLE_MODEL], "scale": 0.02, "rot": Vector3(0, 20, 0), "color": Color(0.15, 0.18, 0.20)},
		{"id": "loose_bottle_1", "name": "Botella de plastico", "type": "misc", "weight": 0.1, "qty": 1, "use": 0.0, "paths": [PLASTIC_BOTTLE_MODEL], "scale": 0.02, "rot": Vector3(0, -50, 0), "color": Color(0.15, 0.18, 0.20)},
		{"id": "loose_bottle_2", "name": "Botella de plastico", "type": "misc", "weight": 0.1, "qty": 1, "use": 0.0, "paths": [PLASTIC_BOTTLE_MODEL], "scale": 0.02, "rot": Vector3(0, 80, 0), "color": Color(0.15, 0.18, 0.20)},
		{"id": "loose_bottle_3", "name": "Botella de plastico", "type": "misc", "weight": 0.1, "qty": 1, "use": 0.0, "paths": [PLASTIC_BOTTLE_MODEL], "scale": 0.02, "rot": Vector3(0, 140, 0), "color": Color(0.15, 0.18, 0.20)},
		{"id": "loose_canned_food_0", "name": "Lata de guiso", "type": "food", "weight": 0.5, "qty": 1, "use": 35.0, "paths": [CANNED_FOOD_LOW_MODEL], "scale": 0.0005, "rot": Vector3(0, 30, 0), "color": Color(0.38, 0.28, 0.15)},
		{"id": "loose_canned_food_1", "name": "Lata de atun", "type": "food", "weight": 0.3, "qty": 1, "use": 18.0, "paths": [FOOD_CAN_415G_MODEL], "scale": 1.35, "rot": Vector3(0, -45, 0), "color": Color(0.42, 0.30, 0.12)},
		{"id": "loose_canned_food_2", "name": "Lata de guiso", "type": "food", "weight": 0.5, "qty": 1, "use": 35.0, "paths": [CANNED_FOOD_LOW_MODEL], "scale": 0.0005, "rot": Vector3(0, 80, 0), "color": Color(0.35, 0.25, 0.10)},
		{"id": "loose_canned_food_3", "name": "Lata de atun", "type": "food", "weight": 0.3, "qty": 1, "use": 18.0, "paths": [FOOD_CAN_415G_MODEL], "scale": 1.35, "rot": Vector3(0, 120, 0), "color": Color(0.40, 0.28, 0.14)},
	]
	for pickup in pickups:
		pickup["pos"] = _find_safe_loot_pos()
		_create_pickup_item(pickup)

func _create_house_loot() -> void:
	var Q_WEAPONS := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/"
	var house_loot_pool := [
		{"name": "Cuchillo", "type": "weapon", "weight": 0.35, "qty": 1, "use": 0.0, "paths": [Q_WEAPONS + "Knife.gltf"], "scale": 0.55, "rot": Vector3(0, 38, 82), "color": Color(0.20, 0.20, 0.18)},
		{"name": "Rifle francotirador", "type": "weapon_rifle", "weight": 3.5, "qty": 1, "use": 0.0, "paths": ["res://assets/models/weapons/modern_sniper_rifle__free_lowpoly.glb"], "scale": 0.068, "rot": Vector3(-90, 30, 180), "flat": true, "color": Color(0.25, 0.22, 0.15), "rare": true},
		{"name": "Botella de plastico", "type": "misc", "weight": 0.1, "qty": 1, "use": 0.0, "paths": [PLASTIC_BOTTLE_MODEL], "scale": 0.02, "rot": Vector3(0, 20, 0), "color": Color(0.15, 0.18, 0.20)},
		{"name": "Lata de guiso", "type": "food", "weight": 0.5, "qty": 1, "use": 35.0, "paths": [CANNED_FOOD_LOW_MODEL], "scale": 0.0005, "rot": Vector3(0, 30, 0), "color": Color(0.38, 0.28, 0.15)},
		{"name": "Lata de atun", "type": "food", "weight": 0.3, "qty": 1, "use": 18.0, "paths": [FOOD_CAN_415G_MODEL], "scale": 1.35, "rot": Vector3(0, -45, 0), "color": Color(0.42, 0.30, 0.12)},
		{"name": "Lata de guiso", "type": "food", "weight": 0.5, "qty": 1, "use": 35.0, "paths": [CANNED_FOOD_LOW_MODEL], "scale": 0.0005, "rot": Vector3(0, 70, 0), "color": Color(0.35, 0.25, 0.10)},
		{"name": "Lata de atun", "type": "food", "weight": 0.3, "qty": 1, "use": 18.0, "paths": [FOOD_CAN_415G_MODEL], "scale": 1.35, "rot": Vector3(0, 110, 0), "color": Color(0.40, 0.28, 0.14)},
		{"name": "Guantes survival", "type": "clothing", "weight": 0.3, "qty": 1, "use": 0.08, "paths": [POLY_GARDEN_GLOVES_MODEL], "scale": 1.5, "rot": Vector3(0, 60, 0), "color": Color(0.16, 0.12, 0.08)},
		{"name": "Botas survival", "type": "clothing", "weight": 1.2, "qty": 1, "use": 0.18, "paths": ["res://assets/characters/adapted/pickup_cloth_feet.glb"], "scale": 0.9, "rot": Vector3(0, -40, 0), "flat": true, "color": Color(0.10, 0.09, 0.07)},
		{"name": "Chaqueta militar", "type": "clothing", "weight": 1.5, "qty": 1, "use": 0.20, "paths": ["res://assets/characters/adapted/pickup_soldier_torso.glb"], "scale": 0.8, "rot": Vector3(0, 45, 0), "flat": false, "color": Color(0.15, 0.18, 0.12)},
		{"name": "Pantalones militares", "type": "clothing", "weight": 1.0, "qty": 1, "use": 0.14, "paths": ["res://assets/characters/adapted/pickup_soldier_legs.glb"], "scale": 0.8, "rot": Vector3(0, -25, 0), "flat": false, "color": Color(0.12, 0.14, 0.10)},
	]
	var house_loot_data := [
		{"origin": Vector3(-25, 0, -18), "w": 11.4, "d": 9.4},
		{"origin": Vector3(-38, 0, 18), "w": 14.0, "d": 11.0},
		{"origin": Vector3(23, 0, 18), "w": 9.0, "d": 7.5},
		{"origin": Vector3(42, 0, 26), "w": 12.5, "d": 10.0},
		{"origin": Vector3(-12, 0, 42), "w": 8.0, "d": 7.0},
	]
	var loot_idx := 0
	for hd in house_loot_data:
		var origin: Vector3 = hd["origin"]
		var half_w: float = hd["w"] * 0.5
		var half_d: float = hd["d"] * 0.5
		var num_items := 2 + _world_rng.randi() % 3
		for _j in range(num_items):
			var template: Dictionary = house_loot_pool[_world_rng.randi() % house_loot_pool.size()]
			if template.get("rare", false) and _world_rng.randf() > 0.50:
				template = house_loot_pool[_world_rng.randi() % house_loot_pool.size()]
			var loot_data: Dictionary = template.duplicate()
			loot_data["id"] = "house_loot_%d" % loot_idx
			loot_idx += 1
			loot_data["pos"] = _find_pos_inside_house(origin, half_w, half_d)
			_create_pickup_item(loot_data)

func _find_pos_inside_house(origin: Vector3, half_w: float, half_d: float) -> Vector3:
	var pos := Vector3(
		origin.x + _world_rng.randf_range(-half_w + 1.0, half_w - 1.0),
		0.06,
		origin.z + _world_rng.randf_range(-half_d + 1.0, half_d - 1.0)
	)
	return pos

func _find_safe_loot_pos() -> Vector3:
	for _attempt in range(60):
		var pos := Vector3(_world_rng.randf_range(-65, 65), 0.06, _world_rng.randf_range(-65, 65))
		if _is_pos_safe_for_loot(pos):
			return pos
	return Vector3(_world_rng.randf_range(-65, 65), 0.06, _world_rng.randf_range(-65, 65))

func _is_pos_safe_for_loot(pos: Vector3) -> bool:
	if _is_near_river(pos, 5.0):
		return false
	if _is_near_wildlife_blocker(pos, 3.0):
		return false
	if _is_near_car_or_container(pos, 4.0):
		return false
	for sz in _spawn_zones:
		if Vector2(pos.x - sz.x, pos.z - sz.z).length() < 20.0:
			return false
	return true

func _is_near_car_or_container(pos: Vector3, margin: float) -> bool:
	var car_positions := [Vector3(33.0, 0.0, 2.0), Vector3(-48.0, 0.0, -32.0)]
	var cont_positions := [Vector3(14.0, 0.0, -50.0), Vector3(56.0, 0.0, 38.0), Vector3(58.0, 0.0, -52.0)]
	var p := Vector2(pos.x, pos.z)
	for cp in car_positions:
		if p.distance_to(Vector2(cp.x, cp.z)) <= 5.0 + margin:
			return true
	for cp in cont_positions:
		if p.distance_to(Vector2(cp.x, cp.z)) <= 7.0 + margin:
			return true
	return false

func _apply_black_material_recursive(node: Node3D) -> void:
	var black_mat := StandardMaterial3D.new()
	black_mat.albedo_color = Color(0.05, 0.05, 0.05)
	black_mat.roughness = 0.9
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = black_mat
		for c in n.get_children():
			stack.append(c)

func _apply_color_material_recursive(node: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	var stack: Array = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).material_override = mat
		for c in n.get_children():
			stack.append(c)

func _create_pickup_item(data: Dictionary) -> void:
	var id := str(data["id"])
	var item_name := str(data["name"])
	var item_type := str(data["type"])
	var pos: Vector3 = data["pos"]
	var visual_name := "Pickup_" + id
	var paths: Array = data.get("paths", [])
	var color: Color = data.get("color", Color(0.42, 0.38, 0.28))
	var scale_value: float = float(data.get("scale", 0.42))
	var rotation_degrees: Vector3 = data.get("rot", Vector3(0, _world_rng.randf_range(0, 360), 0))
	# Garments baked from the standing T-pose are tipped onto their back so they
	# read as clothing dropped on the ground (rot.x=90, then spun by yaw).
	var lay_flat: bool = bool(data.get("flat", false))
	if lay_flat:
		rotation_degrees.x += 90.0
	var space_state := get_world_3d().direct_space_state
	var real_ground_y := _raycast_ground_y(space_state, pos)
	var spawned := false
	if not paths.is_empty():
		spawned = _try_instance_external_scene(paths, visual_name, pos, Vector3.ONE * scale_value, rotation_degrees, false, 0.0)
	if not spawned:
		push_warning("No se crea %s porque falta/carga mal el asset .glb" % item_name)
		return
	var sn := get_node_or_null(NodePath(visual_name))
	if sn is Node3D:
		_snap_node_bottom_to_y(sn as Node3D, real_ground_y)
	_mark_world_action_visual(visual_name)
	var pickup_node := get_node_or_null(visual_name)
	if pickup_node != null:
		_remove_collision_from_node(pickup_node)
	# Apply black material to Botas survival pickup so they look black on the ground
	if item_name == "Botas survival":
		var boot_node := get_node_or_null(NodePath(visual_name))
		if boot_node is Node3D:
			_apply_black_material_recursive(boot_node as Node3D)
	var action_kind := "eat_food" if (item_type == "food" and not item_name.begins_with("Lata de ")) else "pickup_item"
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
	var backpack_node := get_node_or_null(visual_name)
	if backpack_node != null:
		_remove_collision_from_node(backpack_node)

	var action = _create_world_action(id, "backpack_pickup", "Mochila pequena", pos, Vector3(1.25, 0.85, 1.25), Color(0.06, 0.075, 0.055), false, false)
	action.set_meta("visual_name", visual_name)

func _create_choppable_tree(id: String, pos: Vector3) -> void:
	var visual_name := "ChoppableTree_" + id
	var collision_name := visual_name + "_Collision"
	var scale_value := Vector3.ONE * _world_rng.randf_range(1.05, 1.75)
	if not _try_instance_external_scene(_shuffled_paths(POLY_TREE_MODELS), visual_name, pos, scale_value, Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
		if not _try_instance_external_scene(_shuffled_paths(REAL_LIVING_TREE_MODELS), visual_name, pos, scale_value, Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
			push_warning("No se crea arbol talable %s porque falta/carga mal el asset .glb" % id)
			return
	_override_tree_foliage_green(visual_name)
	var collision := _create_tree_collision(collision_name, pos)
	collision.add_to_group("world_action_visual")
	var action = _create_world_action(id, "fell_tree", "Arbol talable", pos, Vector3(1.35, 3.2, 1.35), Color(0.12, 0.08, 0.035), false, false)
	action.set_meta("visual_name", visual_name)
	action.set_meta("collision_name", collision_name)

func _create_choppable_bush(id: String, pos: Vector3) -> void:
	var visual_name := "ChoppableBush_" + id
	var scale_value := Vector3.ONE * _world_rng.randf_range(0.8, 1.3)
	if not _try_instance_external_scene(_shuffled_paths(REAL_BUSH_MODELS), visual_name, pos, scale_value, Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
		var base_color := Color(0.05, 0.12, 0.045).lerp(Color(0.10, 0.17, 0.075), _world_rng.randf())
		_create_visual_sphere(visual_name, pos + Vector3(0, 0.35, 0), Vector3(0.8, 0.5, 0.8), base_color)
	var visual_node := get_node_or_null(visual_name)
	if visual_node != null:
		visual_node.add_to_group("world_action_visual")
		_remove_collision_from_node(visual_node)
	var action = _create_world_action(id, "fell_bush", "Arbusto", pos, Vector3(0.9, 0.8, 0.9), Color(0.08, 0.14, 0.05), false, false)
	action.set_meta("visual_name", visual_name)

func _fall_tree_animation(action) -> void:
	var visual_name := str(action.get_meta("visual_name")) if action.has_meta("visual_name") else ""
	if visual_name.is_empty():
		return
	var tree_node := get_node_or_null(visual_name)
	if tree_node == null or not is_instance_valid(tree_node):
		return
	var fall_dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	if fall_dir == Vector3.ZERO:
		fall_dir = Vector3.FORWARD
	var fall_axis := fall_dir.cross(Vector3.UP).normalized()
	var tw := create_tween()
	var start_rot: Vector3 = tree_node.rotation
	var target_rot: Vector3 = start_rot + fall_axis * deg_to_rad(80.0)
	tw.tween_property(tree_node, "rotation", target_rot, 1.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(tree_node, "position:y", tree_node.position.y - 0.3, 1.5)

func _shrink_bush_animation(action) -> void:
	var visual_name := str(action.get_meta("visual_name")) if action.has_meta("visual_name") else ""
	if visual_name.is_empty():
		return
	var visual_names := visual_name.split("|", false)
	for vn in visual_names:
		var node := get_node_or_null(vn)
		if node == null or not is_instance_valid(node):
			continue
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(node, "scale", Vector3.ZERO, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(node, "position:y", node.position.y - 0.2, 0.8)

func _create_cut_log_action(pos: Vector3) -> void:
	var id := "cut_log_%d" % [_world_rng.randi() % 100000]
	var visual_name := "CutLog_" + id
	_create_static_box(visual_name, pos + Vector3(0, 0.2, 0), Vector3(3.5, 0.4, 0.4), Color(0.25, 0.15, 0.06))
	var visual_node := get_node_or_null(visual_name)
	if visual_node != null:
		visual_node.add_to_group("world_action_visual")
	var action = _create_world_action(id, "cut_log", "Tronco", pos, Vector3(3.0, 0.5, 0.5), Color(0.25, 0.15, 0.06), false, false)
	action.set_meta("visual_name", visual_name)

func _spawn_ground_pickup(item_name: String, item_type: String, pos: Vector3, weight: float, qty: int, use_value: float, fixed_id: String = "", action_type_override: String = "") -> void:
	var id := fixed_id if not fixed_id.is_empty() else "pickup_%s_%d" % [item_name.replace(" ", "_"), Time.get_ticks_msec() + randi() % 1000]
	var visual_name := "Pickup_" + id
	var paths: Array = _get_drop_model_paths(item_name, item_type)
	var drop_scale := _get_drop_scale(item_name, item_type)
	var spawned := false
	if not paths.is_empty():
		spawned = _try_instance_external_scene(paths, visual_name, pos, Vector3.ONE * drop_scale, Vector3(0, randf_range(0, 360), 0), true, 0.06)
	if not spawned:
		_create_visual_cylinder(visual_name, pos + Vector3(0, 0.1, 0), 0.12, 0.5, Color(0.25, 0.15, 0.06), Vector3(90, randf_range(0, 180), 0))
	_mark_world_action_visual(visual_name)
	var ground_node := get_node_or_null(visual_name)
	if ground_node != null:
		_remove_collision_from_node(ground_node)
	var actual_action_type := action_type_override if not action_type_override.is_empty() else "pickup_item"
	var action = _create_world_action(id, actual_action_type, item_name, pos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
	action.set_meta("visual_name", visual_name)
	action.set_meta("item_name", item_name)
	action.set_meta("item_type", item_type)
	action.set_meta("item_weight", weight)
	action.set_meta("item_quantity", qty)
	action.set_meta("item_use_value", use_value)
	# On server: persist the pickup so it survives client disconnects and syncs to new clients
	if net != null and net.is_dedicated_server:
		_dropped_items.append({
			"id": id,
			"name": item_name,
			"type": item_type,
			"weight": weight,
			"qty": qty,
			"use": use_value,
			"pos": [pos.x, pos.y, pos.z],
			"action_type": actual_action_type
		})

func _net_world_action_completed(action_id: String, spawns: Array, extra_visual: String, extra_pos: Vector3) -> void:
	if net != null and net.is_dedicated_server:
		if not action_id.is_empty() and not _depleted_action_ids.has(action_id):
			_depleted_action_ids.append(action_id)
		for spawn in spawns:
			_dropped_items.append(spawn)
	# Remove the completed action's visual on this client
	if not action_id.is_empty() and world_actions_by_id.has(action_id):
		var action = world_actions_by_id[action_id]
		_hide_action_visual(action)
		action.mark_depleted()
		world_actions_by_id.erase(action_id)
	# Spawn any items that resulted from the action (skip if already spawned locally)
	for spawn in spawns:
		var spawn_id := str(spawn.get("id", ""))
		if not world_actions_by_id.has(spawn_id):
			_spawn_ground_pickup(
				spawn["name"], spawn["type"], spawn["pos"],
				spawn["weight"], spawn["qty"], spawn["use"], spawn_id
			)
	# Create extra visual if specified
	if extra_visual == "tree_remains":
		_create_cut_tree_remains(extra_pos)
	elif extra_visual == "cabin":
		_build_player_cabin(extra_pos)


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
			node.queue_free()
		if not collision_name.is_empty() and node.name == collision_name:
			node.queue_free()

func handle_world_action(action, actor) -> void:
	match action.action_type:
		"gut_wolf":
			if action.get_meta("gutted", false):
				var an_name: String = action.get_meta("item_name", "Animal muerto")
				actor.notice.emit("El %s ya esta vacio." % an_name.to_lower().replace(" muerto", ""))
				return
			var held_g = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_g == null or (held_g.item_type != "weapon" and held_g.item_name != "Hacha"):
				actor.notice.emit("Necesitas tener un cuchillo o hacha en la mano para destripar.")
				return
			var animal_kind: String = action.get_meta("animal_type", "wolf")
			var an_lower := "lobo"
			var meat_name := "Carne cruda de lobo"
			var meat_qty := 5
			match animal_kind:
				"deer":
					an_lower = "ciervo"
					meat_name = "Carne cruda de ciervo"
					meat_qty = 8
				"fox":
					an_lower = "zorro"
					meat_name = "Carne cruda de zorro"
					meat_qty = 3
				_:
					an_lower = "lobo"
					meat_name = "Carne cruda de lobo"
					meat_qty = 5
			_play_actor_action(actor, "plant", 5.0)
			if hud != null:
				hud.show_countdown("Destripando %s" % an_lower, 5.0)
			await get_tree().create_timer(5.0).timeout
			action.set_meta("gutted", true)
			# Spawn 5 meat pieces and 1 skin around the animal
			var animal_pos: Vector3 = action.global_position
			var meat_model := "res://assets/models/props/cc0_-_raw_meat_4.glb"
			var gut_spawns: Array = []
			for i in range(meat_qty):
				var angle := TAU * float(i) / float(meat_qty) + randf_range(-0.3, 0.3)
				var offset := Vector3(cos(angle) * randf_range(0.4, 0.9), 0.0, sin(angle) * randf_range(0.4, 0.9))
				var mpos := animal_pos + offset
				mpos.y = 0.06
				var mid := "gut_meat_%d_%d" % [Time.get_ticks_msec(), i]
				var mvis := "Pickup_" + mid
				_try_instance_external_scene([meat_model], mvis, mpos, Vector3.ONE * 1.0, Vector3(0, randf_range(0, 360), 0), true, 0.06)
				_mark_world_action_visual(mvis)
				var maction = _create_world_action(mid, "wolf_meat_raw", meat_name, mpos, Vector3(1.0, 0.72, 1.0), Color(0.42, 0.38, 0.28), false, false)
				maction.set_meta("visual_name", mvis)
				maction.set_meta("item_name", meat_name)
				maction.set_meta("item_type", "food")
				maction.set_meta("item_weight", 0.3)
				maction.set_meta("item_quantity", 1)
				maction.set_meta("item_use_value", 15.0)
				gut_spawns.append({"id": mid, "name": meat_name, "type": "food", "pos": mpos, "weight": 0.3, "qty": 1, "use": 15.0})
			actor.notice.emit("Destripar al %s: +%d carne cruda." % [an_lower, meat_qty])
			_save_world_change_silent()
			# Hide the wolf corpse after the 5-second animation finishes
			var action_ref: Node = action
			var gut_action_id: String = action.action_id
			var t := get_tree().create_timer(5.0)
			t.timeout.connect(func():
				_hide_action_visual(action_ref)
				action_ref.mark_depleted()
				_save_world_change_silent()
				if net != null and net.is_connected and not net.is_host:
					net.world_action_completed.rpc_id(1, gut_action_id, gut_spawns, "", Vector3.ZERO)
			)
			return
		"wolf_meat_raw":
			var meat_item = ItemScript.create(
				str(action.get_meta("item_name")),
				str(action.get_meta("item_type")),
				float(action.get_meta("item_weight")),
				int(action.get_meta("item_quantity")),
				float(action.get_meta("item_use_value"))
			)
			_finish_pickup_action(action, actor, meat_item, "Recoges %s." % meat_item.item_name)
		"pickup_item":
			var item = ItemScript.create(
				str(action.get_meta("item_name")),
				str(action.get_meta("item_type")),
				float(action.get_meta("item_weight")),
				int(action.get_meta("item_quantity")),
				float(action.get_meta("item_use_value"))
			)
			print("[PICKUP] item_name=", item.item_name, " item_type=", item.item_type)
			if str(item.item_type) == "clothing" and actor.has_method("equip_clothing"):
				# Equip directly from ground — adds to inventory, equips (drops old to ground)
				_play_actor_action(actor, "pickup", 0.8)
				if not actor.inventory.add_item(item):
					return
				actor.equip_clothing(item.item_name)
				actor.notice.emit("Equipas %s." % item.item_name)
				_hide_action_visual(action)
				action.mark_depleted()
				_save_world_change_silent()
				if net != null and net.is_connected and not net.is_host:
					net.item_picked_up.rpc_id(1, action.action_id)
			elif str(item.item_type) == "backpack" and actor.has_method("equip_backpack"):
				print("[PICKUP] backpack branch taken, calling equip_backpack")
				_play_actor_action(actor, "pickup", 0.3)
				# Equip first so carry capacity expands before the weight check in
				# add_item runs — otherwise a previous drop (which shrinks capacity
				# without removing carried items) can make the weight check fail
				# and silently block re-equipping the backpack.
				actor.equip_backpack(item.item_name)
				if not actor.inventory.add_item(item):
					actor.equip_backpack("")
					return
				actor.notice.emit("Recoges %s. Puedes cargar mas." % item.item_name)
				_hide_action_visual(action)
				action.mark_depleted()
				_save_world_change_silent()
				if net != null and net.is_connected and not net.is_host:
					net.item_picked_up.rpc_id(1, action.action_id)
			else:
				_finish_pickup_action(action, actor, item, "Recoges %s." % item.item_name)
		"eat_food":
			_play_actor_action(actor, "plant", 1.2)
			if hud != null:
				hud.show_countdown("Comiendo", 1.2)
			await get_tree().create_timer(1.2).timeout
			var food_value := float(action.get_meta("item_use_value")) if action.has_meta("item_use_value") else 18.0
			actor.stats.hunger = min(actor.stats.max_stat, actor.stats.hunger + food_value)
			actor.stats.changed.emit()
			var eaten_name := str(action.get_meta("item_name")) if action.has_meta("item_name") else "algo"
			actor.notice.emit("Comes %s." % eaten_name)
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
			if eaten_name == "Carne humana":
				actor.notice.emit("La carne humana esta en mal estado... te sientes muy mal.")
				actor.stats.health = 0.0
				actor.stats.changed.emit()
				if actor.has_method("die"):
					actor.die()
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
			_net_notify_pickup(action)
		"wood":
			_play_actor_action(actor, "collect", 0.8)
			if not actor.inventory.add_item(ItemScript.create("Tronco", "resource", 1.2, 2, 0.0)):
				return
			_equip_actor_item(actor, "Tronco")
			actor.notice.emit("Recoges troncos para construir.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
		"stone":
			_play_actor_action(actor, "collect", 0.8)
			if not actor.inventory.add_item(ItemScript.create("Piedra", "resource", 0.45, 2, 0.0)):
				return
			_equip_actor_item(actor, "Piedra")
			actor.notice.emit("Recoges piedras utiles.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
		"fish":
			var held_f = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_f == null or (held_f.item_name != "Cuchillo" and held_f.item_name != "Hacha" and held_f.item_type != "tool_fishing"):
				actor.notice.emit("Necesitas un cuchillo, hacha o caña de pescar para pescar.")
				return
			var fish_chance := 0.72 if held_f.item_type == "tool_fishing" else 0.48
			_play_actor_action(actor, "fish", 1.6)
			if hud != null:
				hud.show_countdown("Pescando", 1.6)
			await get_tree().create_timer(1.6).timeout
			if randf() < fish_chance:
				if actor.inventory.add_item(ItemScript.create("Pez crudo", "food", 0.55, 1, 24.0)):
					_equip_actor_item(actor, "Pez crudo")
					actor.notice.emit("Pescas un pez pequeno.")
			else:
				actor.notice.emit("No pica nada.")
		"drink_water":
			# If holding an empty plastic bottle, fill it instead of drinking
			var held_dw = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_dw != null and held_dw.item_name == "Botella de plastico":
				_play_actor_action(actor, "plant", 5.0)
				actor.notice.emit("Llenando botella en el rio...")
				if hud != null:
					hud.show_countdown("Llenando botella", 5.0)
				await get_tree().create_timer(5.0).timeout
				# Remove empty bottle and add filled one
				for i in range(actor.inventory.items.size()):
					if actor.inventory.items[i] != null and actor.inventory.items[i].item_name == "Botella de plastico":
						actor.inventory.remove_index(i)
						break
				var filled_bottle = ItemScript.create("Botella de agua", "water", 0.4, 1, 25.0)
				filled_bottle.max_durability = 100.0
				filled_bottle.durability = 100.0
				if actor.inventory.add_item(filled_bottle):
					actor.inventory.changed.emit()
					if actor.has_method("_sync_held_item"):
						actor._sync_held_item()
					actor.notice.emit("Has llenado la botella de agua. Puedes beber de ella.")
				return
			# If holding a partially empty water bottle, refill it
			if held_dw != null and held_dw.item_name == "Botella de agua" and held_dw.has_method("is_broken") and not held_dw.is_broken() and float(held_dw.durability) < float(held_dw.max_durability):
				_play_actor_action(actor, "plant", 5.0)
				actor.notice.emit("Llenando botella en el rio...")
				if hud != null:
					hud.show_countdown("Llenando botella", 5.0)
				await get_tree().create_timer(5.0).timeout
				held_dw.durability = float(held_dw.max_durability)
				actor.inventory.changed.emit()
				if actor.has_method("_sync_held_item"):
					actor._sync_held_item()
				actor.notice.emit("Has llenado la botella de agua.")
				return
			if _drink_hold_actor != null:
				return
			_play_actor_action(actor, "plant", _DRINK_HOLD_TIME)
			_drink_hold_actor = actor
			_drink_hold_timer = 0.0
			actor.notice.emit("Mantén E para beber...")
		"light_campfire":
			if action.get_meta("lit", false):
				actor.notice.emit("La fogata ya esta encendida.")
				return
			var held_m = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_m == null or held_m.item_name != "Cerillas":
				actor.notice.emit("Necesitas tener las cerillas en la mano para encender la fogata.")
				return
			_play_actor_action(actor, "plant", 1.5)
			actor.notice.emit("Encendiendo fogata...")
			if hud != null:
				hud.show_countdown("Encendiendo fogata", 1.5)
			await get_tree().create_timer(1.5).timeout
			var fire_name := "CampfireFire_%d" % randi()
			_create_campfire_fire(action.position + Vector3(0, 0.15, 0), fire_name)
			action.set_meta("lit", true)
			action.set_meta("lit_time", Time.get_ticks_msec())
			action.set_meta("fire_name", fire_name)
			action.action_type = "cook"
			action.display_name = "Fogata encendida"
			action.repeatable = true
			_save_world_change_silent()
			actor.notice.emit("Has encendido la fogata. Durara 5 minutos.")
			if net != null and net.is_connected and not net.is_host:
				net.campfire_lit.rpc_id(1, action.action_id, fire_name, action.position)
		"cook":
			if not action.get_meta("lit", false):
				actor.notice.emit("La fogata no esta encendida.")
				return
			var held_c = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_c == null or held_c.item_name != "Carne ensartada":
				actor.notice.emit("Necesitas tener carne ensartada en la mano para cocinar.")
				return
			# Make sure the meat on stick is visible in hand during cooking
			if actor.has_method("_sync_held_item"):
				actor._sync_held_item()
			_play_actor_action(actor, "cook", 10.0)
			actor.notice.emit("Cocinando carne en la fogata...")
			if hud != null:
				hud.show_countdown("Cocinando", 10.0)
			await get_tree().create_timer(10.0).timeout
			# Replace raw meat on stick with cooked meat on stick
			var cooked := false
			for i in range(actor.inventory.items.size()):
				if actor.inventory.items[i] != null and actor.inventory.items[i].item_name == "Carne ensartada":
					actor.inventory.remove_index(i)
					cooked = true
					break
			# Also remove any leftover Palo afilado used for the skewer
			for i in range(actor.inventory.items.size() - 1, -1, -1):
				if actor.inventory.items[i] != null and actor.inventory.items[i].item_name == "Palo afilado":
					actor.inventory.remove_index(i)
					break
			if cooked:
				var cooked_item = ItemScript.create("Carne cocinada", "food", 0.4, 1, 35.0)
				if actor.inventory.add_item(cooked_item):
					if actor.stats.has_method("add_hot_food"):
						actor.stats.add_hot_food(2)
					actor.inventory.changed.emit()
					_equip_actor_item(actor, "Carne cocinada")
					if actor.has_method("_sync_held_item"):
						actor._sync_held_item()
					actor.notice.emit("Has cocinado carne. Segura para comer. Caliente!")
				else:
					actor.inventory.changed.emit()
					actor.notice.emit("No tienes espacio para la carne cocinada.")
		"hunt":
			_play_actor_action(actor, "interact", 1.0)
			if hud != null:
				hud.show_countdown("Cazando", 1.0)
			await get_tree().create_timer(1.0).timeout
			if randf() < 0.48:
				if actor.inventory.add_item(ItemScript.create("Carne cruda", "food", 0.75, 1, 30.0)):
					_equip_actor_item(actor, "Carne cruda")
					actor.notice.emit("Sigues el rastro y consigues carne.")
			else:
				actor.notice.emit("El animal escapa entre la maleza.")
		"axe_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Hacha", "tool_axe", 1.2, 1, 0.0), "Recoges un hacha. Ya puedes talar arboles.")
		"matches_tool":
			_finish_pickup_action(action, actor, ItemScript.create("Cerillas", "tool_matches", 0.1, 10, 0.0), "Recoges cerillas (10 usos). Ya puedes encender fogatas.")
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
			if actor.has_method("equip_backpack"):
				actor.equip_backpack("Mochila pequena")
			if not actor.inventory.add_item(ItemScript.create("Mochila pequena", "backpack", 0.8, 1, 0.0)):
				if actor.has_method("equip_backpack"):
					actor.equip_backpack("")
				return
			if actor.has_method("_sync_held_item"):
				actor._sync_held_item()
			actor.notice.emit("Recoges una mochila pequena. Puedes cargar mas.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
		"farm_plot":
			_handle_farm_plot(action, actor)
		"fell_tree":
			var held = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held == null or held.item_name != "Hacha":
				actor.notice.emit("Necesitas tener el hacha en la mano para talar.")
				return
			_play_actor_action(actor, "chop", 10.0)
			if audio_system != null and audio_system.has_method("play_chop_loop_at"):
				audio_system.play_chop_loop_at(action.position, 10.0)
			_attract_wolves_to_noise(action.position, 45.0)
			actor.notice.emit("Taland arbol... (10s)")
			if hud != null:
				hud.show_countdown("Talando arbol", 10.0)
			await get_tree().create_timer(10.0).timeout
			_fall_tree_animation(action)
			await get_tree().create_timer(1.5).timeout
			_hide_action_visual(action)
			_create_cut_tree_remains(action.position)
			var tree_pos: Vector3 = action.position
			var log1_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var log2_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var log3_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var log4_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			_spawn_ground_pickup("Tronco", "resource", tree_pos + Vector3(1.0, 0.06, 0.3), 1.2, 1, 0.0, log1_id)
			_spawn_ground_pickup("Tronco", "resource", tree_pos + Vector3(1.5, 0.06, -0.2), 1.2, 1, 0.0, log2_id)
			_spawn_ground_pickup("Tronco", "resource", tree_pos + Vector3(0.5, 0.06, 0.8), 1.2, 1, 0.0, log3_id)
			_spawn_ground_pickup("Tronco", "resource", tree_pos + Vector3(2.0, 0.06, 0.1), 1.2, 1, 0.0, log4_id)
			actor.notice.emit("Talas el arbol. Recoge los troncos del suelo.")
			action.mark_depleted()
			_save_world_change_silent()
			var tree_spawns: Array = [
				{"id": log1_id, "name": "Tronco", "type": "resource", "pos": tree_pos + Vector3(1.0, 0.06, 0.3), "weight": 1.2, "qty": 1, "use": 0.0},
				{"id": log2_id, "name": "Tronco", "type": "resource", "pos": tree_pos + Vector3(1.5, 0.06, -0.2), "weight": 1.2, "qty": 1, "use": 0.0},
				{"id": log3_id, "name": "Tronco", "type": "resource", "pos": tree_pos + Vector3(0.5, 0.06, 0.8), "weight": 1.2, "qty": 1, "use": 0.0},
				{"id": log4_id, "name": "Tronco", "type": "resource", "pos": tree_pos + Vector3(2.0, 0.06, 0.1), "weight": 1.2, "qty": 1, "use": 0.0},
			]
			if net != null and net.is_connected and not net.is_host:
				net.world_action_completed.rpc_id(1, action.action_id, tree_spawns, "tree_remains", tree_pos)
		"fell_bush":
			var held_b = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_b == null or (held_b.item_name != "Cuchillo" and held_b.item_name != "Hacha"):
				actor.notice.emit("Necesitas tener un cuchillo o hacha en la mano para cortar.")
				return
			_play_actor_action(actor, "forage", 5.0)
			if audio_system != null and audio_system.has_method("play_chop_loop_at"):
				audio_system.play_chop_loop_at(action.position, 5.0)
			_attract_wolves_to_noise(action.position, 30.0)
			actor.notice.emit("Cortando arbusto... (5s)")
			if hud != null:
				hud.show_countdown("Cortando arbusto", 5.0)
			await get_tree().create_timer(5.0).timeout
			_shrink_bush_animation(action)
			await get_tree().create_timer(0.8).timeout
			_hide_action_visual(action)
			var bush_pos: Vector3 = action.position
			var stick1_id := "pickup_Palo_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var stick2_id := "pickup_Palo_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var stick3_id := "pickup_Palo_%d" % (Time.get_ticks_msec() + randi() % 1000)
			_spawn_ground_pickup("Palo", "resource", bush_pos + Vector3(0.3, 0.06, 0.0), 0.3, 1, 0.0, stick1_id)
			_spawn_ground_pickup("Palo", "resource", bush_pos + Vector3(-0.3, 0.06, 0.2), 0.3, 1, 0.0, stick2_id)
			_spawn_ground_pickup("Palo", "resource", bush_pos + Vector3(0.1, 0.06, -0.3), 0.3, 1, 0.0, stick3_id)
			actor.notice.emit("Cortas el arbusto. Recoge los palos del suelo.")
			action.mark_depleted()
			_save_world_change_silent()
			var bush_spawns: Array = [
				{"id": stick1_id, "name": "Palo", "type": "resource", "pos": bush_pos + Vector3(0.3, 0.06, 0.0), "weight": 0.3, "qty": 1, "use": 0.0},
				{"id": stick2_id, "name": "Palo", "type": "resource", "pos": bush_pos + Vector3(-0.3, 0.06, 0.2), "weight": 0.3, "qty": 1, "use": 0.0},
				{"id": stick3_id, "name": "Palo", "type": "resource", "pos": bush_pos + Vector3(0.1, 0.06, -0.3), "weight": 0.3, "qty": 1, "use": 0.0},
			]
			if net != null and net.is_connected and not net.is_host:
				net.world_action_completed.rpc_id(1, action.action_id, bush_spawns, "", Vector3.ZERO)
		"cut_log":
			var held_l = actor.get_held_item() if actor.has_method("get_held_item") else null
			if held_l == null or held_l.item_name != "Hacha":
				actor.notice.emit("Necesitas tener el hacha en la mano para cortar el tronco.")
				return
			_play_actor_action(actor, "chop", 3.0)
			if audio_system != null and audio_system.has_method("play_chop_loop_at"):
				audio_system.play_chop_loop_at(action.position, 3.0)
			_attract_wolves_to_noise(action.position, 35.0)
			actor.notice.emit("Cortando tronco...")
			if hud != null:
				hud.show_countdown("Cortando tronco", 3.0)
			await get_tree().create_timer(3.0).timeout
			_hide_action_visual(action)
			var log_pos: Vector3 = action.position
			var clog1_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var clog2_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			var clog3_id := "pickup_Tronco_%d" % (Time.get_ticks_msec() + randi() % 1000)
			_spawn_ground_pickup("Tronco", "resource", log_pos + Vector3(0.3, 0.06, 0.0), 1.2, 1, 0.0, clog1_id)
			_spawn_ground_pickup("Tronco", "resource", log_pos + Vector3(-0.3, 0.06, 0.2), 1.2, 1, 0.0, clog2_id)
			_spawn_ground_pickup("Tronco", "resource", log_pos + Vector3(0.0, 0.06, -0.3), 1.2, 1, 0.0, clog3_id)
			actor.notice.emit("Cortas el tronco en troncos mas pequenos. Recogelos del suelo.")
			action.mark_depleted()
			var cutlog_spawns: Array = [
				{"id": clog1_id, "name": "Tronco", "type": "resource", "pos": log_pos + Vector3(0.3, 0.06, 0.0), "weight": 1.2, "qty": 1, "use": 0.0},
				{"id": clog2_id, "name": "Tronco", "type": "resource", "pos": log_pos + Vector3(-0.3, 0.06, 0.2), "weight": 1.2, "qty": 1, "use": 0.0},
				{"id": clog3_id, "name": "Tronco", "type": "resource", "pos": log_pos + Vector3(0.0, 0.06, -0.3), "weight": 1.2, "qty": 1, "use": 0.0},
			]
			if net != null and net.is_connected and not net.is_host:
				net.world_action_completed.rpc_id(1, action.action_id, cutlog_spawns, "", Vector3.ZERO)
			_save_world_change_silent()
		"sleep":
			if actor.has_method("start_sleep"):
				actor.start_sleep()
			else:
				_play_actor_action(actor, "sleep", 8.0)
			actor.notice.emit("Durmiendo... pulsa D para despertar.")
			# Wait until sleep is full and health is full, or player wakes up
			var sleep_seconds := 0
			while actor.stats.sleep < actor.stats.max_stat:
				if actor.has_method("is_sleeping") and not actor.is_sleeping:
					break
				sleep_seconds += 1
				if sleep_seconds >= 120:
					break
				if hud != null:
					hud.show_countdown("Durmiendo", float(sleep_seconds + 1))
				await get_tree().create_timer(1.0).timeout
			if actor.has_method("stop_sleep"):
				actor.stop_sleep()
			actor.notice.emit("Has dormido. Te sientes descansado.")
		"build_cabin":
			if not actor.inventory.has_item_name("Tronco", 6) or not actor.inventory.has_item_name("Piedra", 4):
				actor.notice.emit("Faltan materiales: 6 troncos y 4 piedra.")
				return
			_play_actor_action(actor, "interact", 3.0)
			if hud != null:
				hud.show_countdown("Construyendo cabana", 3.0)
			await get_tree().create_timer(3.0).timeout
			actor.inventory.consume_item_name("Tronco", 6)
			actor.inventory.consume_item_name("Piedra", 4)
			_build_player_cabin(action.position)
			actor.notice.emit("Levantas una cabana basica. Ya tienes un refugio propio.")
			action.mark_depleted()
			_save_world_change_silent()
			if net != null and net.is_connected and not net.is_host:
				net.world_action_completed.rpc_id(1, action.action_id, [], "cabin", action.position)
		"shelter":
			_play_actor_action(actor, "forage", 3.0)
			if hud != null:
				hud.show_countdown("Desmontando refugio", 3.0)
			await get_tree().create_timer(3.0).timeout
			var sh_id: String = action.action_id
			# Remove shelter stick visuals
			var stick_names := [
				"PlayerShelter_%s_SupportA" % sh_id,
				"PlayerShelter_%s_SupportB" % sh_id,
			]
			for i in range(9):
				stick_names.append("PlayerShelter_%s_Roof_%d" % [sh_id, i])
			stick_names.append("PlayerShelter_%s_Net" % sh_id)
			for sn in stick_names:
				var sn_node := get_node_or_null(sn)
				if sn_node != null:
					sn_node.queue_free()
			# Give back 11 palos
			var palo_item = ItemScript.create("Palo", "material", 0.3, 1, 0.0)
			for _i in range(11):
				actor.inventory.add_item(palo_item.duplicate())
			if actor.has_method("refresh_carry_capacity"):
				actor.refresh_carry_capacity()
			actor.inventory.changed.emit()
			# Remove from _built_shelters
			for i in range(_built_shelters.size() - 1, -1, -1):
				if _built_shelters[i] is Dictionary and str(_built_shelters[i].get("id", "")) == sh_id:
					_built_shelters.remove_at(i)
			# Remove the world action
			_hide_action_visual(action)
			action.mark_depleted()
			world_actions_by_id.erase(sh_id)
			_save_world_change_silent()
			actor.notice.emit("Desmontas el refugio. Recuperas 11 palos.")
			# Notify server to remove shelter for other clients
			if net != null and net.is_connected and not net.is_host:
				net.shelter_dismantled.rpc_id(1, sh_id)

#endregion


#region ACTORES Y ANIMALES
func _play_actor_action(actor, action_name: String, duration: float) -> void:
	if actor != null and actor.has_method("play_action_animation"):
		actor.play_action_animation(action_name, duration)

func _attract_wolves_to_noise(pos: Vector3, radius: float = 40.0) -> void:
	for node in get_tree().get_nodes_in_group("wildlife"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("attract_to_noise"):
			node.attract_to_noise(pos, radius)

func _equip_actor_item(actor, item_name: String) -> void:
	if actor != null and actor.has_method("equip_item_by_name"):
		actor.equip_item_by_name(item_name)

func _finish_pickup_action(action, actor, item, message: String, action_name := "pickup", duration := 0.8, hide_visual := true) -> void:
	_play_actor_action(actor, action_name, duration)
	if not actor.inventory.add_item(item):
		return
	# Don't auto-equip clothing from ground pickups — just add to inventory
	if str(item.item_type) != "clothing":
		_equip_actor_item(actor, item.item_name)
	if actor.has_method("refresh_carry_capacity"):
		actor.refresh_carry_capacity()
	actor.notice.emit(message)
	if hide_visual:
		_hide_action_visual(action)
	action.mark_depleted()
	_save_world_change_silent()
	# Notify other clients to remove this item from world
	if net != null and net.is_connected and not net.is_host:
		var picked_id: String = action.action_id
		net.item_picked_up.rpc_id(1, picked_id)

func _net_notify_pickup(action) -> void:
	if net != null and net.is_connected and not net.is_host:
		var picked_id: String = action.action_id
		net.item_picked_up.rpc_id(1, picked_id)

func handle_world_action_collect(action, actor) -> void:
	match action.action_type:
		"gut_wolf":
			if action.get_meta("gutted", false):
				actor.notice.emit("El lobo ya esta vacio, no hay nada que coger.")
				return
			var has_backpack := false
			if actor.get("equipped_backpack") != null and not str(actor.get("equipped_backpack")).is_empty():
				has_backpack = true
			if not has_backpack:
				for it in actor.inventory.items:
					if it != null and (it.item_type == "backpack" or it.item_name == "Mochila pequena"):
						has_backpack = true
						break
			if not has_backpack:
				actor.notice.emit("Necesitas una mochila para cargar el lobo entero.")
				return
			var wolf_item = ItemScript.create("Lobo muerto", "material", 8.0, 1, 0.0)
			_play_actor_action(actor, "pickup", 0.8)
			if not actor.inventory.add_item(wolf_item):
				actor.notice.emit("No puedes cargar con el lobo, demasiado peso.")
				return
			actor.notice.emit("Coges el lobo entero.")
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
		"wolf_meat_raw":
			var raw_meat_item = ItemScript.create(
				str(action.get_meta("item_name", "Carne cruda")),
				"food",
				float(action.get_meta("item_weight", 0.3)),
				int(action.get_meta("item_quantity", 1)),
				float(action.get_meta("item_use_value", 15.0))
			)
			_finish_pickup_action(action, actor, raw_meat_item, "Coges %s." % raw_meat_item.item_name)
		"eat_food":
			var eat_item = ItemScript.create(
				str(action.get_meta("item_name")),
				str(action.get_meta("item_type")),
				float(action.get_meta("item_weight")),
				int(action.get_meta("item_quantity")),
				float(action.get_meta("item_use_value"))
			)
			_finish_pickup_action(action, actor, eat_item, "Coges %s." % eat_item.item_name)
		"pickup_item", "axe_tool", "hoe_tool", "shovel_tool", "hammer_tool", "pickaxe_tool", "matches_tool":
			if not action.has_meta("item_name"):
				handle_world_action(action, actor)
				return
			var item = ItemScript.create(
				str(action.get_meta("item_name")),
				str(action.get_meta("item_type")),
				float(action.get_meta("item_weight")),
				int(action.get_meta("item_quantity")),
				float(action.get_meta("item_use_value"))
			)
			_play_actor_action(actor, "pickup", 0.8)
			if not actor.inventory.add_item(item):
				return
			if str(item.item_type) == "clothing" and actor.has_method("equip_clothing"):
				actor.equip_clothing(item.item_name)
				actor.notice.emit("Equipas %s." % item.item_name)
			else:
				actor.notice.emit("Coges %s." % item.item_name)
			if actor.has_method("refresh_carry_capacity"):
				actor.refresh_carry_capacity()
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
		_:
			handle_world_action(action, actor)

func handle_world_action_eat(action, actor) -> void:
	match action.action_type:
		"eat_food":
			_play_actor_action(actor, "plant", 1.2)
			if hud != null:
				hud.show_countdown("Comiendo", 1.2)
			await get_tree().create_timer(1.2).timeout
			var food_value := float(action.get_meta("item_use_value")) if action.has_meta("item_use_value") else 18.0
			actor.stats.hunger = min(actor.stats.max_stat, actor.stats.hunger + food_value)
			actor.stats.changed.emit()
			var eaten_name := str(action.get_meta("item_name")) if action.has_meta("item_name") else "algo"
			actor.notice.emit("Comes %s." % eaten_name)
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)
			if eaten_name == "Carne humana":
				actor.notice.emit("La carne humana esta en mal estado... te sientes muy mal.")
				actor.stats.health = 0.0
				actor.stats.changed.emit()
				if actor.has_method("die"):
					actor.die()
		"wolf_meat_raw":
			_play_actor_action(actor, "plant", 3.0)
			if hud != null:
				hud.show_countdown("Comiendo carne cruda", 3.0)
			await get_tree().create_timer(3.0).timeout
			var raw_food_value := float(action.get_meta("item_use_value")) if action.has_meta("item_use_value") else 15.0
			actor.stats.hunger = min(actor.stats.max_stat, actor.stats.hunger + raw_food_value)
			if actor.stats.has_method("get_sick"):
				actor.stats.get_sick(60.0)
			actor.stats.changed.emit()
			actor.notice.emit("Comes %s. Te sientes mal del estomago." % str(action.get_meta("item_name", "carne cruda")))
			_hide_action_visual(action)
			action.mark_depleted()
			_save_world_change_silent()
			_net_notify_pickup(action)

func _handle_farm_plot(action, actor) -> void:
	match action.action_state:
		"planted":
			actor.notice.emit("El cultivo aun esta creciendo.")
		"ready":
			_play_actor_action(actor, "plant", 1.25)
			if hud != null:
				hud.show_countdown("Cosechando", 1.25)
			await get_tree().create_timer(1.25).timeout
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
			if hud != null:
				hud.show_countdown("Plantando semillas", 1.35)
			await get_tree().create_timer(1.35).timeout
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

func _spawn_player_campfire(pos: Vector3) -> void:
	var cf_id := "player_campfire_%d" % randi()
	_spawn_player_campfire_with_id(cf_id, pos)

func _spawn_player_campfire_with_id(cf_id: String, pos: Vector3) -> void:
	var spawned := _try_instance_external_scene([K_SURVIVAL + "campfire-pit.glb"], "PlayerCampfire_" + cf_id, pos, Vector3(1.5, 1.5, 1.5), Vector3.ZERO, true, 0.0)
	if not spawned:
		_create_visual_box("PlayerCampfireAsh_" + cf_id, pos, Vector3(0.7, 0.04, 0.7), Color(0.09, 0.085, 0.075), Vector3.ZERO)
		for i in range(8):
			var angle := i * 45.0
			var stone_pos := pos + Vector3(cos(deg_to_rad(angle)) * 0.45, 0.05, sin(deg_to_rad(angle)) * 0.45)
			_create_static_box("PlayerCampfireStone_%s_%d" % [cf_id, i], stone_pos, Vector3(0.18, 0.12, 0.15), Color(0.25, 0.23, 0.22))
	var campfire_action = _create_world_action(cf_id, "light_campfire", "Fogata apagada", pos, Vector3(1.2, 0.8, 1.2), Color(0.12, 0.08, 0.04), false, false)
	campfire_action.set_meta("visual_name", "PlayerCampfire_" + cf_id)

func _net_campfire_built(cf_id: String, pos: Vector3) -> void:
	if net != null and net.is_dedicated_server:
		_built_campfires.append({"id": cf_id, "pos": pos})
	if world_actions_by_id.has(cf_id):
		return
	_spawn_player_campfire_with_id(cf_id, pos)

func _spawn_player_shelter_with_id(sh_id: String, pos: Vector3) -> void:
	var stick_path := "res://assets/models/props/wood_stick.glb"
	# Two vertical support poles at the back end, left and right
	_try_instance_external_scene([stick_path], "PlayerShelter_%s_SupportA" % sh_id, pos + Vector3(-0.9, 0.3, -2.0), Vector3(1.0, 0.4, 0.4), Vector3(0, 0, 90), false, 0.0)
	_try_instance_external_scene([stick_path], "PlayerShelter_%s_SupportB" % sh_id, pos + Vector3(0.9, 0.3, -2.0), Vector3(1.0, 0.4, 0.4), Vector3(0, 0, 90), false, 0.0)
	# 9 long thin roof sticks leaning from front to back
	var offsets := [-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8]
	for i in range(9):
		_try_instance_external_scene([stick_path], "PlayerShelter_%s_Roof_%d" % [sh_id, i], pos + Vector3(offsets[i], 0.4, 0.8), Vector3(1.5, 0.4, 0.4), Vector3(-50, 0, 90), false, 0.0)
	# Camouflage net draped over the roof (fitted to the real stick geometry)
	_try_instance_external_scene(["res://assets/models/props/camo_net.glb"], "PlayerShelter_%s_Net" % sh_id, pos + Vector3(0.0, 1.0, 0.0), Vector3(1.0, 1.0, 1.0), Vector3(0, 0, 0), false, 0.0)
	_fit_shelter_net(sh_id)
	# Apply camouflage material
	_apply_shelter_camouflage(sh_id)
	# Register as world action so it syncs
	var shelter_action = _create_world_action(sh_id, "shelter", "Refugio", pos, Vector3(2.0, 1.5, 3.0), Color(0.15, 0.12, 0.08), false, false)
	shelter_action.set_meta("visual_name", "PlayerShelter_%s" % sh_id)

func _fit_shelter_net(sh_id: String) -> void:
	var net_node := get_node_or_null("PlayerShelter_%s_Net" % sh_id) as Node3D
	if net_node == null:
		return
	var center_roof := get_node_or_null("PlayerShelter_%s_Roof_4" % sh_id) as Node3D
	if center_roof == null:
		return
	# Combined global AABB of the 9 roof sticks
	var have_bounds := false
	var bmin := Vector3.ZERO
	var bmax := Vector3.ZERO
	for i in range(9):
		var stick := get_node_or_null("PlayerShelter_%s_Roof_%d" % [sh_id, i]) as Node3D
		if stick == null:
			continue
		var meshes: Array = []
		_collect_mesh_instances(stick, meshes)
		for mi in meshes:
			var aabb: AABB = (mi as MeshInstance3D).get_aabb()
			var gt: Transform3D = (mi as MeshInstance3D).global_transform
			for ci in range(8):
				var corner := gt * aabb.get_endpoint(ci)
				if not have_bounds:
					bmin = corner
					bmax = corner
					have_bounds = true
				else:
					bmin = bmin.min(corner)
					bmax = bmax.max(corner)
	if not have_bounds:
		return
	var roof_center := (bmin + bmax) * 0.5
	var bsize := bmax - bmin
	# Slope direction: long axis of the central roof stick (model local X)
	var d := center_roof.global_transform.basis.x.normalized()
	if d.y < 0.0:
		d = -d
	var n := Vector3.RIGHT.cross(d).normalized()
	if n.y < 0.0:
		n = -n
	# Net source size: 4m (X) x 3m (Z). Slight overhang over the roof.
	var slope_len: float = sqrt(bsize.y * bsize.y + bsize.z * bsize.z)
	var sx: float = (bsize.x * 1.15) / 4.0
	var sz: float = (slope_len * 1.15) / 3.0
	var net_basis := Basis(Vector3.RIGHT * sx, n, -d * sz)
	net_node.global_transform = Transform3D(net_basis, roof_center + n * 0.12)

func _apply_shelter_camouflage(sh_id: String) -> void:
	var ground_tex := _extract_texture_from_glb(LEAFY_FLOOR_MODEL)
	var camo_mat := StandardMaterial3D.new()
	if ground_tex != null:
		camo_mat.albedo_texture = ground_tex
		camo_mat.albedo_color = Color(0.22, 0.26, 0.16)
		camo_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	else:
		camo_mat.albedo_color = Color(0.18, 0.20, 0.12)
	camo_mat.roughness = 0.95
	camo_mat.metallic = 0.0
	var stick_names := [
		"PlayerShelter_%s_SupportA" % sh_id,
		"PlayerShelter_%s_SupportB" % sh_id,
	]
	for i in range(9):
		stick_names.append("PlayerShelter_%s_Roof_%d" % [sh_id, i])
	for node_name in stick_names:
		var node := get_node_or_null(NodePath(node_name))
		if node == null:
			continue
		var meshes: Array = []
		_collect_mesh_instances(node, meshes)
		for mi in meshes:
			(mi as MeshInstance3D).material_override = camo_mat

func _net_shelter_built(sh_id: String, pos: Vector3) -> void:
	if net != null and net.is_dedicated_server:
		_built_shelters.append({"id": sh_id, "pos": pos})
	if world_actions_by_id.has(sh_id):
		return
	_spawn_player_shelter_with_id(sh_id, pos)

func _net_shelter_dismantled(sh_id: String) -> void:
	if net != null and net.is_dedicated_server:
		for i in range(_built_shelters.size() - 1, -1, -1):
			if _built_shelters[i] is Dictionary and str(_built_shelters[i].get("id", "")) == sh_id:
				_built_shelters.remove_at(i)
	# Remove stick visuals
	var stick_names := [
		"PlayerShelter_%s_SupportA" % sh_id,
		"PlayerShelter_%s_SupportB" % sh_id,
	]
	for i in range(9):
		stick_names.append("PlayerShelter_%s_Roof_%d" % [sh_id, i])
	stick_names.append("PlayerShelter_%s_Net" % sh_id)
	for sn in stick_names:
		var sn_node := get_node_or_null(sn)
		if sn_node != null:
			sn_node.queue_free()
	# Remove world action
	if world_actions_by_id.has(sh_id):
		var action = world_actions_by_id[sh_id]
		if action != null and is_instance_valid(action):
			_hide_action_visual(action)
			action.mark_depleted()
		world_actions_by_id.erase(sh_id)

func _net_campfire_lit(action_id: String, fire_name: String, pos: Vector3) -> void:
	if net != null and net.is_dedicated_server:
		_lit_campfires.append({"id": action_id, "fire_name": fire_name, "pos": pos})
	if not world_actions_by_id.has(action_id):
		return
	var action = world_actions_by_id[action_id]
	if action.get_meta("lit", false):
		return
	_create_campfire_fire(action.position + Vector3(0, 0.15, 0), fire_name)
	action.set_meta("lit", true)
	action.set_meta("lit_time", Time.get_ticks_msec())
	action.set_meta("fire_name", fire_name)
	action.action_type = "cook"
	action.display_name = "Fogata encendida"
	action.repeatable = true

func _create_quaternius_environment_props() -> void:
	_spawn_external(Q_ENV + "WaterTower.gltf", "QWaterTower", Vector3(-43, 0, -48), Vector3.ONE, Vector3.ZERO, Vector3(2.0, 7.0, 2.0))
	_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightA", Vector3(3.0, 0, -22), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
	_spawn_external(Q_ENV + "StreetLights.gltf", "QStreetLightB", Vector3(3.0, 0, 14), Vector3.ONE, Vector3(0, 90, 0), Vector3(0.5, 4.0, 0.5))
	_spawn_external(Q_ENV + "TrafficLight_1.gltf", "QTrafficLight", Vector3(13.0, 0, -5.0), Vector3.ONE, Vector3(0, 180, 0), Vector3(0.6, 3.5, 0.6))
	_spawn_external(Q_ENV + "TownSign.gltf", "QTownSign", Vector3(14.8, 0, -28.5), Vector3.ONE, Vector3(0, 180, 0), Vector3(1.6, 1.8, 0.5))
	_spawn_external(Q_ENV + "TrafficBarrier_1.gltf", "QBarrierA", Vector3(6.0, 0, -4.2), Vector3.ONE, Vector3(0, 18, 0), Vector3(2.2, 1.0, 0.6))
	_spawn_external(Q_ENV + "TrafficBarrier_2.gltf", "QBarrierB", Vector3(10.4, 0, -2.8), Vector3.ONE, Vector3(0, -14, 0), Vector3(2.2, 1.0, 0.6))
	for i in range(8):
		var pos := Vector3(_world_rng.randf_range(3.5, 13.2), 0, _world_rng.randf_range(-54, 52))
		_spawn_external(Q_ENV + ("TrafficCone_1.gltf" if i % 2 == 0 else "TrafficCone_2.gltf"), "QTrafficCone", pos, Vector3.ONE, Vector3(0, _world_rng.randf_range(0, 360), 0), Vector3(0.35, 0.7, 0.35))
	for i in range(12):
		var pos := Vector3(_world_rng.randf_range(-58, 58), 0, _world_rng.randf_range(-58, 58))
		if abs(pos.x - 8.0) < 5.0:
			pos.x += 8.0
		var prop_names := ["TrashBag_1.gltf", "TrashBag_2.gltf", "Pallet_Broken.gltf", "Wheel.gltf", "Wheels_Stack.gltf", "Barrel.gltf"]
		var path: String = Q_ENV + str(prop_names[i % prop_names.size()])
		_spawn_external(path, "QWorldProp", pos, Vector3.ONE, Vector3(0, _world_rng.randf_range(0, 360), 0), Vector3(1.0, 1.0, 1.0))

func _create_terrain_variation() -> void:
	for i in range(26):
		var rock_pos := Vector3(_world_rng.randf_range(-70, 70), 0.04, _world_rng.randf_range(-70, 70))
		if not _can_place_ground_vegetation(rock_pos, 1.6):
			continue
		var rock_scale := _world_rng.randf_range(0.7, 1.35)
		if _try_instance_external_scene(_shuffled_paths(REAL_ROCK_MODELS), "RealRock", rock_pos, Vector3.ONE * rock_scale, Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
			pass
		else:
			_create_polyhaven_boulder(rock_pos, Vector3(_world_rng.randf_range(0.32, 0.74), _world_rng.randf_range(0.16, 0.34), _world_rng.randf_range(0.28, 0.62)))
	for i in range(16):
		var boulder_pos := Vector3(_world_rng.randf_range(-68, 68), 0.04, _world_rng.randf_range(-68, 68))
		if not _can_place_ground_vegetation(boulder_pos, 1.8):
			continue
		_create_polyhaven_boulder(boulder_pos, Vector3(_world_rng.randf_range(0.7, 1.7), _world_rng.randf_range(0.35, 0.8), _world_rng.randf_range(0.6, 1.5)))

func _create_mountain_backdrop() -> void:
	var mountain_color := Color(0.19, 0.20, 0.18)
	var shadow_color := Color(0.11, 0.12, 0.11)
	var snow_color := Color(0.70, 0.72, 0.68)
	var ridges := [
		{"center": Vector3(-MAP_EXTENT * 0.77, -0.35, -MAP_EXTENT * 1.09), "count": 12, "step": Vector3(35, 0, 0), "yaw": 4.0},
		{"center": Vector3(MAP_EXTENT * 0.77, -0.35, -MAP_EXTENT * 1.09), "count": 12, "step": Vector3(35, 0, 0), "yaw": -5.0},
		{"center": Vector3(-MAP_EXTENT * 1.14, -0.35, -MAP_EXTENT * 0.5), "count": 10, "step": Vector3(0, 0, 40), "yaw": 88.0},
		{"center": Vector3(MAP_EXTENT * 1.14, -0.35, -MAP_EXTENT * 0.45), "count": 10, "step": Vector3(0, 0, 40), "yaw": -88.0},
		{"center": Vector3(-MAP_EXTENT * 0.5, -0.35, MAP_EXTENT * 1.12), "count": 9, "step": Vector3(45, 0, 0), "yaw": 184.0},
		{"center": Vector3(MAP_EXTENT * 0.72, -0.35, MAP_EXTENT * 1.12), "count": 9, "step": Vector3(45, 0, 0), "yaw": 176.0}
	]
	for ridge in ridges:
		var center: Vector3 = ridge["center"]
		var count: int = int(ridge["count"])
		var step: Vector3 = ridge["step"]
		var yaw: float = float(ridge["yaw"])
		for i in range(count):
			var offset := step * (float(i) - float(count - 1) * 0.5)
			var pos := center + offset + Vector3(_world_rng.randf_range(-12.0, 12.0), 0.0, _world_rng.randf_range(-10.0, 10.0))
			var peak_height := _world_rng.randf_range(14.0, 26.0)
			var radius_x := _world_rng.randf_range(40.0, 75.0)
			var radius_z := _world_rng.randf_range(30.0, 60.0)
			var base_color := shadow_color.lerp(mountain_color, _world_rng.randf_range(0.35, 0.95))
			_create_mountain_peak("MountainPeak", pos, radius_x, radius_z, peak_height, yaw + _world_rng.randf_range(-14.0, 14.0), base_color)
	_create_rocky_foothills()

func _create_rocky_foothills() -> void:
	# En lugar de colinas gigantes y solapadas, generamos colinas suaves, espaciadas y de menor tamaño.
	var num_hills := int(7 * (MAP_EXTENT / 75.0) * (MAP_EXTENT / 75.0)) # ~75 colinas en total
	var large_hill_count := 0
	for i in range(num_hills):
		var pos := Vector3(_world_rng.randf_range(-MAP_EXTENT*0.85, MAP_EXTENT*0.85), 0.0, _world_rng.randf_range(-MAP_EXTENT*0.85, MAP_EXTENT*0.85))
		
		# Mantener el centro del mapa plano para poder construir y empujar detrás del río
		if Vector2(pos.x, pos.z).length() < 55.0:
			continue
		
		# Evitar generar colinas encima de los puntos de aparición del jugador (spawn zones)
		var near_spawn := false
		for sz in _spawn_zones:
			if Vector2(pos.x - sz.x, pos.z - sz.z).length() < (max(40.0, 25.0) + 25.0):
				near_spawn = true
				break
		if near_spawn:
			continue
		
		# ~25% de las colinas se convierten en montañas grandes con vegetación
		var is_large_mountain := large_hill_count < 12 and _world_rng.randf() < 0.25
		var radius_x: float
		var radius_z: float
		var height: float
		if is_large_mountain:
			radius_x = _world_rng.randf_range(30.0, 60.0)
			radius_z = _world_rng.randf_range(30.0, 60.0)
			height = _world_rng.randf_range(10.0, 25.0)
			large_hill_count += 1
		else:
			radius_x = _world_rng.randf_range(6.0, 14.0)
			radius_z = _world_rng.randf_range(6.0, 14.0)
			height = _world_rng.randf_range(0.8, 2.8) # Muy suaves y caminables
		
		# Color de tierra verdosa para las colinas
		var hill_color := Color(0.25, 0.35, 0.16).lerp(Color(0.20, 0.28, 0.14), _world_rng.randf())
		_create_mountain_peak("RollingHill", pos, radius_x, radius_z, height, _world_rng.randf_range(0, 360), hill_color)
		# Añadir abundantes manojos de hierba en las colinas
		var grass_count := 4 if not is_large_mountain else 30
		for _hc in range(grass_count):
			var angle := _world_rng.randf_range(0.0, TAU)
			var r_dist := _world_rng.randf_range(0.1, max(radius_x, radius_z) * 0.85)
			var hpos := pos + Vector3(cos(angle) * r_dist, 0, sin(angle) * r_dist)
			hpos.y = _get_exact_ground_y(hpos.x, hpos.z) + 0.02
			if _can_place_ground_vegetation(hpos):
				_create_grass_clump(hpos, _world_rng.randf_range(0.35, 0.85), Color(0.22, 0.38, 0.14).lerp(Color(0.36, 0.48, 0.18), _world_rng.randf()))
		
		# En montañas grandes, añadir árboles densos y arbustos
		if is_large_mountain:
			var tree_count := int(radius_x * radius_z * 0.04)
			for _tc in range(tree_count):
				var t_angle := _world_rng.randf_range(0.0, TAU)
				var t_dist := _world_rng.randf_range(2.0, max(radius_x, radius_z) * 0.75)
				var tpos := pos + Vector3(cos(t_angle) * t_dist, 0, sin(t_angle) * t_dist)
				tpos.y = _get_exact_ground_y(tpos.x, tpos.z)
				if tpos.y < 0.05:
					continue
				if _is_near_house(tpos, 3.0):
					continue
				if not _can_place_ground_vegetation(tpos, 2.8):
					continue
				_create_tree(tpos, false)
			# Añadir arbustos densos
			var bush_count := int(radius_x * radius_z * 0.015)
			for _bc in range(bush_count):
				var b_angle := _world_rng.randf_range(0.0, TAU)
				var b_dist := _world_rng.randf_range(1.0, max(radius_x, radius_z) * 0.8)
				var bpos := pos + Vector3(cos(b_angle) * b_dist, 0, sin(b_angle) * b_dist)
				bpos.y = _get_exact_ground_y(bpos.x, bpos.z)
				if bpos.y < 0.05:
					continue
				if _can_place_ground_vegetation(bpos):
					_create_bush(bpos, _world_rng.randf_range(0.4, 0.9))

func _create_polyhaven_boulder(pos: Vector3, scale_value: Vector3) -> void:
	if abs(pos.x - 8.0) < 5.4 or _is_in_no_grass_area(pos, 1.4):
		return
	var base_color := Color(0.26, 0.24, 0.20)
	var rock_texture := POLY_ROCK_07_DIFF if _world_rng.randf() < 0.55 else POLY_BOULDER_DIFF
	_create_textured_visual_sphere("PolyhavenBoulder", pos + Vector3(0, scale_value.y * 0.55, 0), scale_value, rock_texture, base_color)
	if _world_rng.randf() < 0.45:
		_create_textured_visual_sphere("PolyhavenBoulderLobe", pos + Vector3(scale_value.x * _world_rng.randf_range(-0.35, 0.35), scale_value.y * 0.42, scale_value.z * _world_rng.randf_range(-0.35, 0.35)), scale_value * Vector3(_world_rng.randf_range(0.45, 0.72), _world_rng.randf_range(0.45, 0.72), _world_rng.randf_range(0.45, 0.72)), rock_texture, base_color.darkened(0.05))
	if scale_value.x > 1.25 and scale_value.z > 1.25:
		_create_invisible_collision_box("PolyhavenBoulderCollision", pos, Vector3(scale_value.x, scale_value.y, scale_value.z))

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
		if _world_rng.randf() < 0.72:
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

func get_day_cycle():
	return day_cycle

func get_hud():
	return hud

#endregion


#region API PÚBLICA DEL MUNDO
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

const HOUSE_DATA := [
	{"pos": Vector3(-25, 0, -18), "w": 11.4, "d": 9.4},
	{"pos": Vector3(-38, 0, 18), "w": 14.0, "d": 11.0},
	{"pos": Vector3(23, 0, 18), "w": 9.0, "d": 7.5},
	{"pos": Vector3(42, 0, 26), "w": 12.5, "d": 10.0},
	{"pos": Vector3(-12, 0, 42), "w": 8.0, "d": 7.0},
]

func _is_player_in_house(pos: Vector3) -> bool:
	for hd in HOUSE_DATA:
		var house_pos: Vector3 = hd["pos"]
		var half_w: float = hd["w"] * 0.5
		var half_d: float = hd["d"] * 0.5
		if abs(pos.x - house_pos.x) < half_w and abs(pos.z - house_pos.z) < half_d:
			return true
	return false

func _is_near_built_shelter(pos: Vector3) -> bool:
	for sh in _built_shelters:
		var sh_pos: Vector3 = sh["pos"]
		if pos.distance_to(sh_pos) < 3.5:
			return true
	return false

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
			var edge_pos: Vector3 = center + along * _world_rng.randf_range(-size.x * 0.53, size.x * 0.53) + across * side * _world_rng.randf_range(size.y * 0.42, size.y * 0.86)
			edge_pos.y = 0.041 + _world_rng.randf_range(0.0, 0.006)
			if not _can_place_ground_vegetation(edge_pos, -1.0):
				continue
			if i % 2 == 0:
				_create_river_pebble_cluster(edge_pos, along, across, side)
			if _world_rng.randf() < 0.94:
				var grass_pos: Vector3 = edge_pos + across * side * _world_rng.randf_range(0.10, 1.15) + along * _world_rng.randf_range(-0.70, 0.70)
				grass_pos.y = 0.052
				_create_grass_clump(grass_pos, _world_rng.randf_range(0.92, 1.68), Color(0.13, 0.30, 0.09).lerp(Color(0.36, 0.44, 0.12), _world_rng.randf()))
			if _world_rng.randf() < 0.68:
				var reed_pos: Vector3 = edge_pos + across * side * _world_rng.randf_range(0.18, 1.05)
				reed_pos.y = 0.052
				_create_river_reed_cluster(reed_pos, _world_rng.randf_range(1.15, 2.05), side)

func _create_river_end_blend(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for end_value in [-1.0, 1.0]:
		var end: float = end_value
		for i in range(72):
			var side := -1.0 if _world_rng.randf() < 0.5 else 1.0
			var cap_pos: Vector3 = center + along * end * _world_rng.randf_range(size.x * 0.36, size.x * 0.66) + across * _world_rng.randf_range(-size.y * 0.92, size.y * 0.92)
			cap_pos += across * side * _world_rng.randf_range(0.0, 0.68)
			cap_pos.y = 0.052
			if not _can_place_ground_vegetation(cap_pos, -1.0):
				continue
			if i % 6 == 0:
				_create_polyhaven_boulder(cap_pos + across * side * _world_rng.randf_range(0.15, 0.55), Vector3(_world_rng.randf_range(0.30, 0.78), _world_rng.randf_range(0.12, 0.36), _world_rng.randf_range(0.30, 0.78)))
			elif i % 3 == 0:
				_create_river_pebble_cluster(cap_pos, along, across, side)
			else:
				_create_river_reed_cluster(cap_pos, _world_rng.randf_range(1.25, 2.25), side)
				_create_grass_clump(cap_pos + along * end * _world_rng.randf_range(0.05, 0.95), _world_rng.randf_range(1.05, 1.85), Color(0.13, 0.30, 0.09).lerp(Color(0.32, 0.40, 0.13), _world_rng.randf()))
		for corner_side in [-1.0, 1.0]:
			var corner_center: Vector3 = center + along * end * size.x * 0.50 + across * corner_side * size.y * 0.50
			corner_center.y = 0.052
			for j in range(15):
				var corner_pos: Vector3 = corner_center + along * end * _world_rng.randf_range(-0.85, 1.15) + across * corner_side * _world_rng.randf_range(-0.35, 1.15)
				if not _can_place_ground_vegetation(corner_pos, -1.0):
					continue
				_create_river_pebble_cluster(corner_pos, along, across, corner_side)
				if _world_rng.randf() < 0.82:
					_create_river_reed_cluster(corner_pos + across * corner_side * _world_rng.randf_range(0.15, 0.55), _world_rng.randf_range(1.15, 1.95), corner_side)

func _create_river_seam_cover(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	for end_value in [-1.0, 1.0]:
		var end: float = end_value
		var seam_center: Vector3 = center + along * end * size.x * 0.50
		for i in range(44):
			var side := -1.0 if i % 2 == 0 else 1.0
			var seam_pos: Vector3 = seam_center + across * _world_rng.randf_range(-size.y * 0.58, size.y * 0.58) + along * end * _world_rng.randf_range(-0.35, 1.20)
			seam_pos.y = 0.054
			if not _can_place_ground_vegetation(seam_pos, -1.0):
				continue
			if i % 4 == 0:
				_create_polyhaven_boulder(seam_pos + across * side * _world_rng.randf_range(0.0, 0.45), Vector3(_world_rng.randf_range(0.24, 0.62), _world_rng.randf_range(0.10, 0.28), _world_rng.randf_range(0.24, 0.62)))
			elif i % 3 == 0:
				_create_river_pebble_cluster(seam_pos, along, across, side)
			else:
				_create_river_reed_cluster(seam_pos + across * side * _world_rng.randf_range(0.05, 0.50), _world_rng.randf_range(1.35, 2.35), side)
				_create_grass_clump(seam_pos + along * end * _world_rng.randf_range(0.0, 0.75), _world_rng.randf_range(1.10, 1.95), Color(0.12, 0.28, 0.08).lerp(Color(0.34, 0.43, 0.13), _world_rng.randf()))

func _create_river_pebble_cluster(pos: Vector3, along: Vector3, across: Vector3, side: float) -> void:
	for i in range(3 + _world_rng.randi() % 4):
		var pebble_pos: Vector3 = pos + along * _world_rng.randf_range(-0.65, 0.65) + across * side * _world_rng.randf_range(-0.22, 0.56)
		pebble_pos.y = 0.055
		var pebble_scale: Vector3 = Vector3(_world_rng.randf_range(0.12, 0.34), _world_rng.randf_range(0.035, 0.09), _world_rng.randf_range(0.10, 0.30))
		var texture_path: String = POLY_RIVER_PEBBLES_DIFF if _world_rng.randf() < 0.62 else POLY_ROCK_07_DIFF
		_create_textured_visual_sphere("RiverPebbleClusterStone", pebble_pos, pebble_scale, texture_path, Color(0.30, 0.29, 0.25))

#endregion


#region VEGETACIÓN Y NATURALEZA (VegetationBuilder)
func _create_fish_school(center: Vector3, size: Vector2, yaw: float) -> void:
	var angle := deg_to_rad(yaw)
	var along := Vector3(cos(angle), 0, -sin(angle))
	var across := Vector3(sin(angle), 0, cos(angle))
	var count := 2 + _world_rng.randi() % 3
	for i in range(count):
		var fish = FishControllerScript.new()
		fish.name = "RiverFish"
		var fish_center := center + along * _world_rng.randf_range(-size.x * 0.36, size.x * 0.36) + across * _world_rng.randf_range(-size.y * 0.22, size.y * 0.22)
		fish_center.y = center.y + 0.035
		fish.setup(fish_center, along, across, _world_rng.randf_range(size.x * 0.22, size.x * 0.55), _world_rng.randf_range(size.y * 0.18, size.y * 0.45))
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
			var bank_pos := center + along * _world_rng.randf_range(-size.x * 0.56, size.x * 0.56) + across * side * _world_rng.randf_range(size.y * 0.58, size.y * 1.50)
			bank_pos.y = 0.052
			if not _can_place_ground_vegetation(bank_pos, -1.0):
				continue
			_create_grass_clump(bank_pos, _world_rng.randf_range(0.95, 1.85), Color(0.14, 0.31, 0.09))
			if _world_rng.randf() < 0.62:
				_create_river_reed_cluster(bank_pos + along * _world_rng.randf_range(-0.75, 0.75), _world_rng.randf_range(1.15, 2.20), side)
			if _world_rng.randf() < 0.28:
				_create_bush(bank_pos + across * side * _world_rng.randf_range(0.25, 0.9), _world_rng.randf_range(0.44, 0.74))

func _create_mountain_peak(node_name: String, pos: Vector3, radius_x: float, radius_z: float, height: float, yaw: float, color: Color) -> void:
	if not node_name.contains("SnowCap"):
		_generated_hills.append({
			"pos": pos,
			"radius_x": radius_x,
			"radius_z": radius_z,
			"height": height,
			"yaw_rad": deg_to_rad(yaw)
		})
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
			var noise := _world_rng.randf_range(0.78, 1.18)
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
			
			# Convertir vértice local a posición global para la proyección de textura UV
			var world_a := pos + a.rotated(Vector3.UP, deg_to_rad(yaw))
			var world_b := pos + b.rotated(Vector3.UP, deg_to_rad(yaw))
			var world_c := pos + c.rotated(Vector3.UP, deg_to_rad(yaw))
			var world_d := pos + d.rotated(Vector3.UP, deg_to_rad(yaw))
			
			var uv_scale := 1.0 / (MAP_EXTENT * 2.0)
			st.set_uv(Vector2(world_a.x * uv_scale + 0.5, world_a.z * uv_scale + 0.5))
			st.add_vertex(a)
			st.set_uv(Vector2(world_b.x * uv_scale + 0.5, world_b.z * uv_scale + 0.5))
			st.add_vertex(b)
			st.set_uv(Vector2(world_c.x * uv_scale + 0.5, world_c.z * uv_scale + 0.5))
			st.add_vertex(c)
			
			st.set_uv(Vector2(world_b.x * uv_scale + 0.5, world_b.z * uv_scale + 0.5))
			st.add_vertex(b)
			st.set_uv(Vector2(world_d.x * uv_scale + 0.5, world_d.z * uv_scale + 0.5))
			st.add_vertex(d)
			st.set_uv(Vector2(world_c.x * uv_scale + 0.5, world_c.z * uv_scale + 0.5))
			st.add_vertex(c)
	st.generate_normals()
	var mesh := st.commit()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = Vector3(0, yaw, 0)
	mesh_instance.mesh = mesh
	if not node_name.contains("SnowCap") and _cached_leafy_material != null:
		if _mountain_shared_material == null:
			_mountain_shared_material = _cached_leafy_material.duplicate() as StandardMaterial3D
			_mountain_shared_material.uv1_triplanar = true
			_mountain_shared_material.uv1_scale = Vector3(0.12, 0.12, 0.12)
			_mountain_shared_material.albedo_color = Color(0.85, 0.95, 0.80)
		mesh_instance.material_override = _mountain_shared_material
	else:
		mesh_instance.material_override = _make_material(color, true)
	# Crear colisión para poder caminar sobre la montaña
	if not node_name.contains("SnowCap"):
		var static_body := StaticBody3D.new()
		static_body.set_collision_layer_value(1, true) # Entorno
		var coll_shape := CollisionShape3D.new()
		coll_shape.shape = mesh.create_trimesh_shape()
		static_body.add_child(coll_shape)
		mesh_instance.add_child(static_body)
	add_child(mesh_instance)

func _create_house_details(origin: Vector3, label: String, width: float, depth: float, height: float, half_w: float, half_d: float, front_seg_c: float) -> void:
	var return_w: float = min(2.0, half_w * 0.32)
	var front_seg_w: float = half_w - 1.8 * 0.5 - return_w + 0.5
	var win_w: float = min(1.5, front_seg_w * 0.72)
	var win_h: float = win_w * 0.8
	_create_visual_gable_roof(label + " Roof", origin + Vector3(0, height - 0.1, 0), width + 1.2, depth + 0.8, 1.85, Color(0.14, 0.065, 0.035))
	_create_house_exterior_assets(origin, label, half_w, half_d, height)
	_create_static_box(label + " Chimney", origin + Vector3(half_w * 0.6, height + 0.35, -(half_d * 0.38)), Vector3(0.62, 1.25, 0.62), Color(0.11, 0.08, 0.065))
	_create_house_doorway(origin, label, half_d, height)
	_create_house_windows(origin, label, half_w, half_d, front_seg_c, height, win_w, win_h)
	_create_visual_box(label + " BrokenGlassA", origin + Vector3(-front_seg_c, height * 0.44, half_d + 0.3), Vector3(0.12, 0.32, 0.035), Color(0.50, 0.62, 0.66, 0.72), Vector3(0, 0, -18))
	_create_visual_box(label + " RoofHole", origin + Vector3(-(half_w * 0.41), height + 0.4, half_d * 0.38), Vector3(1.2, 0.08, 0.75), Color(0.035, 0.025, 0.02), Vector3(0, 22, -12))
	_create_visual_box(label + " BigRustRoofPatch", origin + Vector3(half_w * 0.37, height + 0.63, half_d * 0.29), Vector3(2.25, 0.09, 1.15), Color(0.34, 0.13, 0.055), Vector3(0, -13, 10))

func _create_house_doorway(origin: Vector3, label: String, half_d: float, height: float) -> void:
	var door_h := 3.2
	var door_w := 1.8
	var dz := half_d
	var frame_depth := 0.44  # protrudes past wall_t (0.35) on both faces so it's visible as trim
	var frame_offset := door_w * 0.5 + 0.09
	_create_visual_box(label + " DoorFrameLeft", origin + Vector3(-frame_offset, door_h * 0.5, dz), Vector3(0.18, door_h + 0.12, frame_depth), Color(0.22, 0.13, 0.07), Vector3.ZERO)
	_create_visual_box(label + " DoorFrameRight", origin + Vector3(frame_offset, door_h * 0.5, dz), Vector3(0.18, door_h + 0.12, frame_depth), Color(0.22, 0.13, 0.07), Vector3.ZERO)
	_create_visual_box(label + " DoorFrameTop", origin + Vector3(0.0, door_h + 0.09, dz), Vector3(door_w + 0.36, 0.18, frame_depth), Color(0.19, 0.11, 0.06), Vector3.ZERO)
	# Inner trim lip (slightly darker) framing the opening edge for depth
	_create_visual_box(label + " DoorFrameLeftInner", origin + Vector3(-door_w * 0.5 - 0.015, door_h * 0.5, dz), Vector3(0.03, door_h, frame_depth + 0.02), Color(0.10, 0.06, 0.03), Vector3.ZERO)
	_create_visual_box(label + " DoorFrameRightInner", origin + Vector3(door_w * 0.5 + 0.015, door_h * 0.5, dz), Vector3(0.03, door_h, frame_depth + 0.02), Color(0.10, 0.06, 0.03), Vector3.ZERO)
	_create_interactive_door(label + " Door", origin + Vector3(-door_w * 0.5, 0.0, half_d), Vector3(door_w, door_h, 0.11), Color(0.13, 0.075, 0.04), -96.0)

func _create_interactive_door(node_name: String, hinge_pos: Vector3, size: Vector3, color: Color, open_angle: float) -> void:
	var door = DoorScript.new()
	door.name = node_name
	door.position = hinge_pos
	add_child(door)
	var door_model: String = DOOR_MODELS[_world_rng.randi() % DOOR_MODELS.size()]
	door.setup("Puerta", size, color, open_angle, door_model)

func _create_house_windows(origin: Vector3, label: String, half_w: float, half_d: float, front_seg_c: float, height: float, win_w: float, win_h: float) -> void:
	var win_y := height * 0.6
	var back_win_x := half_w * 0.44
	var side_win_z := half_d * 0.56
	_create_front_window(label + " FrontWindowLeft", origin + Vector3(-front_seg_c, win_y, half_d), win_w, win_h)
	_create_front_window(label + " FrontWindowRight", origin + Vector3(front_seg_c, win_y, half_d), win_w, win_h)
	_create_front_window(label + " BackWindowA", origin + Vector3(-back_win_x, win_y, -half_d), win_w, win_h)
	_create_front_window(label + " BackWindowB", origin + Vector3(back_win_x, win_y, -half_d), win_w, win_h)
	_create_side_window(label + " LeftSideWindow", origin + Vector3(-half_w, win_y, side_win_z), win_w, win_h)
	_create_side_window(label + " RightSideWindow", origin + Vector3(half_w, win_y, side_win_z), win_w, win_h)

func _create_front_window(node_name: String, center: Vector3, width: float, height: float) -> void:
	var frame := Color(0.19, 0.12, 0.065)
	var frame_dark := Color(0.14, 0.085, 0.045)
	var sill := Color(0.12, 0.09, 0.07)
	var ft := 0.06  # frame thickness
	var wall_t := 0.35
	var fd := 0.44  # frame depth — protrudes past wall_t on both faces so it's visible as trim
	# Sill (alféizar)
	_create_visual_box(node_name + " Sill", center + Vector3(0, -height * 0.5 - 0.04, fd * 0.5 + 0.04), Vector3(width, 0.06, 0.16), sill, Vector3.ZERO)
	# Glass (kept at wall thickness, recessed within the frame)
	var gw := width - ft * 2.0
	var gh := height - ft * 2.0
	_create_glass_panel(node_name + " Glass", center, Vector3(gw, gh, wall_t), false)
	# Frame boards — outer edge exactly at opening edge
	_create_visual_box(node_name + " FrameTop", center + Vector3(0, height * 0.5 - ft * 0.5, 0.0), Vector3(width, ft, fd), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameBottom", center + Vector3(0, -height * 0.5 + ft * 0.5, 0.0), Vector3(width, ft, fd), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameLeft", center + Vector3(-width * 0.5 + ft * 0.5, 0, 0.0), Vector3(ft, height, fd), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameRight", center + Vector3(width * 0.5 - ft * 0.5, 0, 0.0), Vector3(ft, height, fd), frame, Vector3.ZERO)
	# Inner mullions (cross dividers)
	_create_visual_box(node_name + " MullionVertical", center + Vector3(0, 0, 0.0), Vector3(0.04, gh, fd), frame_dark, Vector3.ZERO)
	_create_visual_box(node_name + " MullionHorizontal", center + Vector3(0, 0, 0.0), Vector3(gw, 0.04, fd), frame_dark, Vector3.ZERO)

func _create_side_window(node_name: String, center: Vector3, width: float, height: float) -> void:
	var frame := Color(0.19, 0.12, 0.065)
	var frame_dark := Color(0.14, 0.085, 0.045)
	var sill := Color(0.12, 0.09, 0.07)
	var ft := 0.06
	var wall_t := 0.35
	var fd := 0.44  # frame depth — protrudes past wall_t on both faces so it's visible as trim
	# Sill
	_create_visual_box(node_name + " Sill", center + Vector3(fd * 0.5 + 0.04, -height * 0.5 - 0.04, 0), Vector3(0.16, 0.06, width), sill, Vector3.ZERO)
	# Glass (kept at wall thickness, recessed within the frame)
	var gw := width - ft * 2.0
	var gh := height - ft * 2.0
	_create_glass_panel(node_name + " Glass", center, Vector3(wall_t, gh, gw), true)
	# Frame boards — outer edge exactly at opening edge
	_create_visual_box(node_name + " FrameTop", center + Vector3(0, height * 0.5 - ft * 0.5, 0), Vector3(fd, ft, width), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameBottom", center + Vector3(0, -height * 0.5 + ft * 0.5, 0), Vector3(fd, ft, width), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameLeft", center + Vector3(0, 0, -width * 0.5 + ft * 0.5), Vector3(fd, height, ft), frame, Vector3.ZERO)
	_create_visual_box(node_name + " FrameRight", center + Vector3(0, 0, width * 0.5 - ft * 0.5), Vector3(fd, height, ft), frame, Vector3.ZERO)
	# Inner mullions
	_create_visual_box(node_name + " MullionVertical", center + Vector3(0, 0, 0), Vector3(fd, gh, 0.04), frame_dark, Vector3.ZERO)
	_create_visual_box(node_name + " MullionHorizontal", center + Vector3(0, 0, 0), Vector3(fd, 0.04, gw), frame_dark, Vector3.ZERO)

func _create_glass_panel(node_name: String, pos: Vector3, size: Vector3, is_side: bool) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.mesh = _get_shared_box_mesh()
	mesh_instance.scale = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.04, 0.09, 0.12, 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.metallic = 0.3
	mat.emission = Color(0.03, 0.05, 0.07)
	mat.emission_energy_multiplier = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_instance.material_override = mat
	add_child(mesh_instance)

func _create_house_exterior_assets(origin: Vector3, label: String, half_w: float, half_d: float, height: float) -> void:
	_create_house_grass_asset(label + " FrontGrassLeft", origin + Vector3(-1.75, 0.055, half_d + 1.05), 0.34)
	_create_house_grass_asset(label + " FrontGrassRight", origin + Vector3(1.75, 0.055, half_d + 0.95), 0.30)
	_create_house_grass_asset(label + " FrontGrassSide", origin + Vector3(0.0, 0.055, half_d + 1.95), 0.26)
	_create_visual_box(label + " RoofEaveFront", origin + Vector3(0, height - 0.07, half_d + 0.52), Vector3(half_w * 2.0 + 1.5, 0.16, 0.32), Color(0.095, 0.055, 0.035), Vector3.ZERO)
	_create_visual_box(label + " RoofEaveBack", origin + Vector3(0, height - 0.07, -(half_d + 0.52)), Vector3(half_w * 2.0 + 1.5, 0.16, 0.32), Color(0.085, 0.05, 0.035), Vector3.ZERO)
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
	_create_visual_box(label + " RoofEaveFront", origin + Vector3(0, 2.72, 4.05), Vector3(9.4, 0.16, 0.28), Color(0.095, 0.055, 0.035), Vector3.ZERO)
	_create_visual_box(label + " RoofEaveBack", origin + Vector3(0, 2.72, -4.05), Vector3(9.4, 0.16, 0.28), Color(0.085, 0.05, 0.035), Vector3.ZERO)
	_create_visual_box(label + " FrontDirtMat", origin + Vector3(0.0, 0.025, 4.1), Vector3(1.3, 0.035, 0.75), Color(0.065, 0.055, 0.04), Vector3.ZERO)

func _create_house_interior(origin: Vector3, label: String, id_prefix: String, width: float, depth: float, height: float) -> void:
	var half_w := width * 0.5
	var half_d := depth * 0.5
	# Bed against the back-left corner
	var bed_pos := origin + Vector3(-half_w + 2.2, 0, -half_d + 1.7)
	_try_instance_external_scene([BED_MODEL_PATH], label + " Bed", bed_pos, Vector3.ONE * 2.0, Vector3(0, 0, 0), true, 0.0)
	# Remove collision from the bed model so it doesn't push the player through the roof
	var bed_node := get_node_or_null(label + " Bed")
	if bed_node != null:
		_remove_collision_from_node(bed_node)
	else:
		push_warning("Bed node not found: " + label + " Bed")
	# Add interactable area so the player can sleep in the bed
	var bed_area := Area3D.new()
	bed_area.name = label + " BedInteractable"
	var bed_col := CollisionShape3D.new()
	var bed_shape := BoxShape3D.new()
	bed_shape.size = Vector3(3.0, 2.0, 4.0)
	bed_col.shape = bed_shape
	bed_area.add_child(bed_col)
	bed_area.set_script(load("res://scripts/BedInteractable.gd"))
	bed_area.position = bed_pos + Vector3(0, 0.8, 0)
	bed_area.set("bed_position", bed_pos + Vector3(0, 0.9, 0))
	add_child(bed_area)
	# Post-apocalyptic furniture: different placement per house (relative to house dimensions)
	# Bed is at back-left corner (-half_w + 2.2, -half_d + 1.7), furniture goes back-right
	var furniture_layouts := {
		"house_1": {"pos": Vector3(half_w - 1.0, 0, -half_d + 2.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.6},
		"house_2": {"pos": Vector3(half_w - 1.0, 0, -half_d + 2.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.4},
		"house_3": {"pos": Vector3(half_w - 0.8, 0, -half_d + 2.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.3},
		"house_4": {"pos": Vector3(half_w - 1.0, 0, -half_d + 2.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.6},
		"house_5": {"pos": Vector3(half_w - 0.8, 0, -half_d + 2.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.2},
		"house_6": {"pos": Vector3(half_w - 1.0, 0, -half_d + 2.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.5},
		"house_7": {"pos": Vector3(half_w - 1.0, 0, -half_d + 2.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.5},
		"house_8": {"pos": Vector3(half_w - 0.8, 0, -half_d + 2.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.3},
		"house_9": {"pos": Vector3(half_w - 1.0, 0, -half_d + 2.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.5},
		"house_10": {"pos": Vector3(half_w - 0.7, 0, -half_d + 1.8), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 2.0},
	}
	# Fridge on front-right area, with clearance from wall, away from windows, furniture and bed
	var fridge_layouts := {
		"house_1": {"pos": Vector3(half_w - 1.1, 0, half_d - 1.5), "rot": Vector3(0, -90, 0), "scale": Vector3(0.35, 0.45, 0.35)},
		"house_2": {"pos": Vector3(half_w - 1.1, 0, half_d - 1.5), "rot": Vector3(0, -90, 0), "scale": Vector3(0.32, 0.42, 0.32)},
		"house_3": {"pos": Vector3(half_w - 0.9, 0, half_d - 1.2), "rot": Vector3(0, -90, 0), "scale": Vector3(0.30, 0.39, 0.30)},
		"house_4": {"pos": Vector3(half_w - 1.1, 0, half_d - 1.5), "rot": Vector3(0, -90, 0), "scale": Vector3(0.35, 0.45, 0.35)},
		"house_5": {"pos": Vector3(half_w - 0.9, 0, half_d - 1.2), "rot": Vector3(0, -90, 0), "scale": Vector3(0.28, 0.37, 0.28)},
		"house_6": {"pos": Vector3(half_w - 1.1, 0, half_d - 1.5), "rot": Vector3(0, -90, 0), "scale": Vector3(0.33, 0.43, 0.33)},
		"house_7": {"pos": Vector3(half_w - 1.1, 0, half_d - 1.5), "rot": Vector3(0, -90, 0), "scale": Vector3(0.34, 0.44, 0.34)},
		"house_8": {"pos": Vector3(half_w - 0.9, 0, half_d - 1.2), "rot": Vector3(0, -90, 0), "scale": Vector3(0.30, 0.39, 0.30)},
		"house_9": {"pos": Vector3(half_w - 1.1, 0, half_d - 1.5), "rot": Vector3(0, -90, 0), "scale": Vector3(0.33, 0.43, 0.33)},
		"house_10": {"pos": Vector3(half_w - 0.8, 0, half_d - 1.0), "rot": Vector3(0, -90, 0), "scale": Vector3(0.26, 0.35, 0.26)},
	}
	# Bathroom: toilet + sink together in front-left corner, away from bed (back-left), furniture (back-right), fridge (front-right)
	var toilet_layouts := {
		"house_1": {"pos": Vector3(-half_w + 0.5, 0, half_d - 2.1), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.7},
		"house_2": {"pos": Vector3(-half_w + 0.5, 0, half_d - 2.1), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.6},
		"house_3": {"pos": Vector3(-half_w + 0.4, 0, half_d - 1.9), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.4},
		"house_4": {"pos": Vector3(-half_w + 0.5, 0, half_d - 2.1), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.7},
		"house_5": {"pos": Vector3(-half_w + 0.4, 0, half_d - 1.9), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.3},
		"house_6": {"pos": Vector3(-half_w + 0.5, 0, half_d - 2.1), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.6},
		"house_7": {"pos": Vector3(-half_w + 0.5, 0, half_d - 2.1), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.7},
		"house_8": {"pos": Vector3(-half_w + 0.4, 0, half_d - 1.9), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.4},
		"house_9": {"pos": Vector3(-half_w + 0.5, 0, half_d - 2.1), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.6},
		"house_10": {"pos": Vector3(-half_w + 0.3, 0, half_d - 1.6), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.2},
	}
	var sink_layouts := {
		"house_1": {"pos": Vector3(-half_w + 0.5, 0.1, half_d - 3.0), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 2.1},
		"house_2": {"pos": Vector3(-half_w + 0.5, 0.1, half_d - 3.0), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.9},
		"house_3": {"pos": Vector3(-half_w + 0.4, 0.1, half_d - 2.6), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.7},
		"house_4": {"pos": Vector3(-half_w + 0.5, 0.1, half_d - 3.0), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 2.1},
		"house_5": {"pos": Vector3(-half_w + 0.4, 0.1, half_d - 2.6), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.6},
		"house_6": {"pos": Vector3(-half_w + 0.5, 0.1, half_d - 3.0), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 2.0},
		"house_7": {"pos": Vector3(-half_w + 0.5, 0.1, half_d - 3.0), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 2.1},
		"house_8": {"pos": Vector3(-half_w + 0.4, 0.1, half_d - 2.6), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.7},
		"house_9": {"pos": Vector3(-half_w + 0.5, 0.1, half_d - 3.0), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 2.0},
		"house_10": {"pos": Vector3(-half_w + 0.3, 0.1, half_d - 2.2), "rot": Vector3(0, 90, 0), "scale": Vector3.ONE * 1.5},
	}
	# Kitchen stove next to the sink cabinet, against the same (+X) wall
	var stove_layouts := {
		"house_1": {"pos": Vector3(half_w - 1.1, 0, half_d - 4.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.5},
		"house_2": {"pos": Vector3(half_w - 1.1, 0, half_d - 4.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.4},
		"house_3": {"pos": Vector3(half_w - 0.9, 0, half_d - 4.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.3},
		"house_4": {"pos": Vector3(half_w - 1.1, 0, half_d - 4.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.5},
		"house_5": {"pos": Vector3(half_w - 0.9, 0, half_d - 4.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.2},
		"house_6": {"pos": Vector3(half_w - 1.1, 0, half_d - 4.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.4},
		"house_7": {"pos": Vector3(half_w - 1.1, 0, half_d - 4.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.5},
		"house_8": {"pos": Vector3(half_w - 0.9, 0, half_d - 4.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.3},
		"house_9": {"pos": Vector3(half_w - 1.1, 0, half_d - 4.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.4},
		"house_10": {"pos": Vector3(half_w - 0.8, 0, half_d - 3.5), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 1.1},
	}
	# Sink cabinet to the left of fridge, against the same (+X) wall
	var sink_cabinet_layouts := {
		"house_1": {"pos": Vector3(half_w - 1.1, 0, half_d - 3.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.042},
		"house_2": {"pos": Vector3(half_w - 1.1, 0, half_d - 3.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.04},
		"house_3": {"pos": Vector3(half_w - 0.9, 0, half_d - 2.6), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.038},
		"house_4": {"pos": Vector3(half_w - 1.1, 0, half_d - 3.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.042},
		"house_5": {"pos": Vector3(half_w - 0.9, 0, half_d - 2.6), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.035},
		"house_6": {"pos": Vector3(half_w - 1.1, 0, half_d - 3.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.04},
		"house_7": {"pos": Vector3(half_w - 1.1, 0, half_d - 3.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.042},
		"house_8": {"pos": Vector3(half_w - 0.9, 0, half_d - 2.6), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.038},
		"house_9": {"pos": Vector3(half_w - 1.1, 0, half_d - 3.0), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.04},
		"house_10": {"pos": Vector3(half_w - 0.8, 0, half_d - 2.2), "rot": Vector3(0, -90, 0), "scale": Vector3.ONE * 0.032},
	}
	if furniture_layouts.has(id_prefix):
		var fl: Dictionary = furniture_layouts[id_prefix]
		var furn_pos: Vector3 = origin + fl.pos
		var furn_scale: Vector3 = fl.scale
		var furn_rot: Vector3 = fl.rot
		_try_instance_external_scene([POST_APO_FURNITURE_MODEL], label + " Furniture", furn_pos, furn_scale, furn_rot, true, 0.0)
		var furn_node := get_node_or_null(label + " Furniture")
		if furn_node != null:
			_remove_collision_from_node(furn_node)
	if fridge_layouts.has(id_prefix):
		var frl: Dictionary = fridge_layouts[id_prefix]
		var fridge_pos: Vector3 = origin + frl.pos
		var fridge_scale: Vector3 = frl.scale
		var fridge_rot: Vector3 = frl.rot
		_try_instance_external_scene([POST_APO_FRIDGE_MODEL], label + " Fridge", fridge_pos, fridge_scale, fridge_rot, true, 0.0)
		var fridge_node := get_node_or_null(label + " Fridge")
		if fridge_node != null:
			_remove_collision_from_node(fridge_node)
	if toilet_layouts.has(id_prefix):
		var tl: Dictionary = toilet_layouts[id_prefix]
		var toilet_pos: Vector3 = origin + tl.pos
		var toilet_scale: Vector3 = tl.scale
		var toilet_rot: Vector3 = tl.rot
		_try_instance_external_scene([TOILET_MODEL], label + " Toilet", toilet_pos, toilet_scale, toilet_rot, true, 0.0)
		var toilet_node := get_node_or_null(label + " Toilet")
		if toilet_node != null:
			_remove_collision_from_node(toilet_node)
	if sink_layouts.has(id_prefix):
		var sl: Dictionary = sink_layouts[id_prefix]
		var sink_pos: Vector3 = origin + sl.pos
		var sink_scale: Vector3 = sl.scale
		var sink_rot: Vector3 = sl.rot
		_try_instance_external_scene([BATHROOM_SINK_MODEL], label + " Sink", sink_pos, sink_scale, sink_rot, true, 0.0)
		var sink_node := get_node_or_null(label + " Sink")
		if sink_node != null:
			_remove_collision_from_node(sink_node)
	if stove_layouts.has(id_prefix):
		var stl: Dictionary = stove_layouts[id_prefix]
		var stove_pos: Vector3 = origin + stl.pos
		var stove_scale: Vector3 = stl.scale
		var stove_rot: Vector3 = stl.rot
		_try_instance_external_scene([KITCHEN_STOVE_MODEL], label + " Stove", stove_pos, stove_scale, stove_rot, true, 0.0)
		var stove_node := get_node_or_null(label + " Stove")
		if stove_node != null:
			_remove_collision_from_node(stove_node)
	if sink_cabinet_layouts.has(id_prefix):
		var scl: Dictionary = sink_cabinet_layouts[id_prefix]
		var cabinet_pos: Vector3 = origin + scl.pos
		var cabinet_scale: Vector3 = scl.scale
		var cabinet_rot: Vector3 = scl.rot
		_try_instance_external_scene([SINK_CABINET_MODEL], label + " SinkCabinet", cabinet_pos, cabinet_scale, cabinet_rot, true, 0.0)
		var cabinet_node := get_node_or_null(label + " SinkCabinet")
		if cabinet_node != null:
			_remove_collision_from_node(cabinet_node)
			var fridge_ref := get_node_or_null(label + " Fridge")
			if fridge_ref != null:
				fridge_ref.force_update_transform()
				cabinet_node.force_update_transform()
				var fridge_aabb: AABB = _compute_node_world_aabb(fridge_ref)
				var cabinet_aabb: AABB = _compute_node_world_aabb(cabinet_node)
				var gap := 0.05
				# Both are against the +X wall: align back faces (max X) to same wall plane
				var fridge_back_x := fridge_aabb.position.x + fridge_aabb.size.x
				var cabinet_back_x := cabinet_aabb.position.x + cabinet_aabb.size.x
				var delta_x := fridge_back_x - cabinet_back_x
				cabinet_node.position.x += delta_x
				# Place cabinet to the LEFT of the fridge along the wall (-Z side): cabinet max Z = fridge min Z - gap
				var fridge_left_z := fridge_aabb.position.z
				var cabinet_max_z := cabinet_aabb.position.z + cabinet_aabb.size.z
				var delta_z := (fridge_left_z - gap) - cabinet_max_z
				cabinet_node.position.z += delta_z
				# Align bases (min Y) to same floor height
				var fridge_bottom_y := fridge_aabb.position.y
				var cabinet_bottom_y := cabinet_aabb.position.y
				var delta_y := fridge_bottom_y - cabinet_bottom_y
				cabinet_node.position.y += delta_y
				cabinet_node.force_update_transform()
				# Verify final placement
				var final_fridge_aabb := _compute_node_world_aabb(fridge_ref)
				var final_cabinet_aabb := _compute_node_world_aabb(cabinet_node)
				# Log each mesh child to find origin offsets
				var cabinet_meshes := []
				_collect_mesh_instances(cabinet_node, cabinet_meshes)
				var actual_gap := final_fridge_aabb.position.z - (final_cabinet_aabb.position.z + final_cabinet_aabb.size.z)
				if actual_gap < -0.001:
					push_warning("[SINK_CABINET] %s OVERLAP detected! Gap=%.4f" % [label, actual_gap])
				elif actual_gap > 0.06:
					push_warning("[SINK_CABINET] %s Gap too large: %.4f m (expected 0.05)" % [label, actual_gap])
				# Place the stove to the LEFT of the sink cabinet, against the same (+X) wall
				var stove_ref := get_node_or_null(label + " Stove")
				if stove_ref != null:
					stove_ref.force_update_transform()
					var stove_aabb: AABB = _compute_node_world_aabb(stove_ref)
					var cab_aabb2: AABB = _compute_node_world_aabb(cabinet_node)
					var stove_gap := 0.05
					# Align back faces (max X) to same wall plane as cabinet
					var cab_back_x := cab_aabb2.position.x + cab_aabb2.size.x
					var stove_back_x := stove_aabb.position.x + stove_aabb.size.x
					stove_ref.position.x += cab_back_x - stove_back_x
					# Place stove to the LEFT of the cabinet (-Z side): stove max Z = cabinet min Z - gap
					var cab_left_z := cab_aabb2.position.z
					var stove_max_z := stove_aabb.position.z + stove_aabb.size.z
					stove_ref.position.z += (cab_left_z - stove_gap) - stove_max_z
					stove_ref.force_update_transform()
					var final_stove_aabb := _compute_node_world_aabb(stove_ref)
					var final_cab_aabb := _compute_node_world_aabb(cabinet_node)
					var stove_actual_gap := final_cab_aabb.position.z - (final_stove_aabb.position.z + final_stove_aabb.size.z)
					if stove_actual_gap < -0.001:
						push_warning("[STOVE] %s OVERLAP with cabinet! Gap=%.4f" % [label, stove_actual_gap])

func _create_campfire_fire(pos: Vector3, node_name: String) -> void:
	campfire_positions.append(pos)
	# Store expiry time (5 minutes from now)
	var expiry_time := Time.get_ticks_msec() + 300000
	campfire_fire_timers[node_name] = expiry_time
	# Point light for warm glow
	var light := OmniLight3D.new()
	light.name = node_name + "Light"
	light.position = pos
	light.light_color = Color(1.0, 0.65, 0.25)
	light.light_energy = 3.0
	light.omni_range = 8.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	add_child(light)
	# Fire particles with billboard planes
	var particles := GPUParticles3D.new()
	particles.name = node_name + "Particles"
	particles.position = pos
	particles.amount = 60
	particles.lifetime = 0.6
	particles.explosiveness = 0.4
	particles.randomness = 0.6
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 8.0
	mat.initial_velocity_min = 1.0
	mat.initial_velocity_max = 2.5
	mat.gravity = Vector3(0, 1.0, 0)
	mat.scale_min = 0.15
	mat.scale_max = 0.4
	mat.color = Color(1.0, 0.6, 0.15, 1.0)
	mat.color_ramp = _make_fire_ramp()
	particles.process_material = mat
	# Billboard plane with radial gradient flame texture
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.3, 0.3)
	quad.orientation = PlaneMesh.FACE_Y
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.5, 0.1, 1.0)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.55, 0.12)
	fire_mat.emission_energy_multiplier = 4.0
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	fire_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_mat.no_depth_test = true
	fire_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fire_mat.billboard_keep_scale = true
	fire_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material = fire_mat
	particles.draw_pass_1 = quad
	add_child(particles)
	# Smoke particles
	var smoke := GPUParticles3D.new()
	smoke.name = node_name + "Smoke"
	smoke.position = pos + Vector3(0, 0.5, 0)
	smoke.amount = 20
	smoke.lifetime = 3.0
	smoke.explosiveness = 0.2
	smoke.randomness = 0.5
	var smoke_mat := ParticleProcessMaterial.new()
	smoke_mat.direction = Vector3(0, 1, 0)
	smoke_mat.spread = 15.0
	smoke_mat.initial_velocity_min = 0.5
	smoke_mat.initial_velocity_max = 1.5
	smoke_mat.gravity = Vector3(0, 0.3, 0)
	smoke_mat.scale_min = 0.3
	smoke_mat.scale_max = 1.0
	smoke_mat.color = Color(0.3, 0.3, 0.3, 0.4)
	smoke.process_material = smoke_mat
	var smoke_quad := PlaneMesh.new()
	smoke_quad.size = Vector2(0.5, 0.5)
	smoke_quad.orientation = PlaneMesh.FACE_Y
	var smoke_tex_mat := StandardMaterial3D.new()
	smoke_tex_mat.albedo_color = Color(0.3, 0.3, 0.3, 0.4)
	smoke_tex_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_tex_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_tex_mat.no_depth_test = true
	smoke_tex_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smoke_tex_mat.billboard_keep_scale = true
	smoke_quad.material = smoke_tex_mat
	smoke.draw_pass_1 = smoke_quad
	add_child(smoke)

func _make_fire_ramp() -> GradientTexture1D:
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1.0, 0.9, 0.3, 1.0))
	grad.add_point(0.3, Color(1.0, 0.5, 0.1, 0.9))
	grad.add_point(0.7, Color(0.8, 0.15, 0.02, 0.5))
	grad.add_point(1.0, Color(0.2, 0.05, 0.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex

# Interior de casas: pendiente de implementar (placeholder para futura expansión)
func _create_visible_house_interior_details(_origin: Vector3, _label: String) -> void:
	return

func _create_extra_house_furniture(_origin: Vector3, _label: String) -> void:
	return

func _create_house_living_room(_origin: Vector3, _label: String) -> void:
	return

func _create_house_bedroom(_origin: Vector3, _label: String) -> void:
	return

func _create_house_warehouse(_origin: Vector3, _label: String) -> void:
	return

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
		if _world_rng.randf() < 0.82:
			var crack_pos := Vector3(_world_rng.randf_range(5.0, 11.0), 0.084, float(z) + _world_rng.randf_range(-2.2, 2.2))
			_create_road_crack(crack_pos, _world_rng.randf_range(-28.0, 28.0))
	for i in range(34):
		var patch_pos := Vector3(_world_rng.randf_range(4.8, 11.2), 0.086, _world_rng.randf_range(-60.0, 60.0))
		var patch_color := Color(0.018, 0.020, 0.018).lerp(Color(0.09, 0.075, 0.055), _world_rng.randf())
		_create_visual_box("RoadOilDirtPatch", patch_pos, Vector3(_world_rng.randf_range(0.7, 2.8), 0.018, _world_rng.randf_range(0.28, 1.35)), patch_color, Vector3(0, _world_rng.randf_range(-18.0, 18.0), 0))
	for i in range(22):
		var hole_pos := Vector3(_world_rng.randf_range(4.9, 11.1), 0.091, _world_rng.randf_range(-58.0, 58.0))
		_create_visual_box("RoadBrokenGroundHole", hole_pos, Vector3(_world_rng.randf_range(0.45, 1.35), 0.020, _world_rng.randf_range(0.30, 1.05)), Color(0.15, 0.17, 0.11), Vector3(0, _world_rng.randf_range(0.0, 180.0), 0))
		if _world_rng.randf() < 0.45:
			_create_grass_clump(hole_pos + Vector3(_world_rng.randf_range(-0.25, 0.25), 0.02, _world_rng.randf_range(-0.25, 0.25)), _world_rng.randf_range(0.22, 0.42), Color(0.11, 0.22, 0.07))
	for z in [-48, -36, -19, -2, 13, 31, 49]:
		_create_visual_box("FadedRoadLineBreak", Vector3(8, 0.096, z + _world_rng.randf_range(-2.0, 2.0)), Vector3(0.34, 0.020, _world_rng.randf_range(1.2, 3.0)), Color(0.035, 0.036, 0.032), Vector3(0, _world_rng.randf_range(-5.0, 5.0), 0))
	# Dense grass growing through cracks all over the abandoned road
	for i in range(800):
		var grass_pos := Vector3(_world_rng.randf_range(3.0, 13.0), 0.09, _world_rng.randf_range(-60.0, 60.0))
		_create_grass_clump(grass_pos, _world_rng.randf_range(0.25, 0.65), Color(0.13, 0.26, 0.08).lerp(Color(0.28, 0.38, 0.12), _world_rng.randf()))
	# Grass encroaching from road edges inward
	for i in range(400):
		var side := -1.0 if i % 2 == 0 else 1.0
		var grass_pos := Vector3(8.0 + side * _world_rng.randf_range(2.0, 5.4), 0.05, _world_rng.randf_range(-60.0, 60.0))
		_create_grass_clump(grass_pos, _world_rng.randf_range(0.35, 0.85), Color(0.15, 0.28, 0.09).lerp(Color(0.30, 0.40, 0.13), _world_rng.randf()))

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
	var house_centers := [
		Vector3(-25, 0, -18),
		Vector3(-38, 0, 18),
		Vector3(23, 0, 18),
		Vector3(42, 0, 26),
		Vector3(-12, 0, 42)
	]
	for center in house_centers:
		if absf(pos.x - center.x) < 8.0 and absf(pos.z - center.z) < 10.0:
			return false
	var other_blocked := [
		Vector3(0, 0, 0),
		Vector3(33, 0, -30),
		Vector3(45, 0, 0),
		Vector3(-42, 0, -42)
	]
	for center in other_blocked:
		if absf(pos.x - center.x) < 9.0 and absf(pos.z - center.z) < 8.0:
			return false
	if _is_in_house_doorway(pos, 8.0):
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
	_create_visual_box("RoadCrack", pos, Vector3(_world_rng.randf_range(1.2, 2.7), 0.025, 0.08), Color(0.018, 0.018, 0.018), Vector3(0, yaw, 0))
	_create_visual_box("RoadCrackBranch", pos + Vector3(_world_rng.randf_range(-0.4, 0.4), 0.01, _world_rng.randf_range(-0.4, 0.4)), Vector3(0.8, 0.025, 0.06), Color(0.015, 0.015, 0.015), Vector3(0, yaw + _world_rng.randf_range(35, 70), 0))

func _create_power_line(start: Vector3, end: Vector3) -> void:
	var pole_path := "res://assets/external/telephone_pole_scene.glb"
	var center := start.lerp(end, 0.5)
	var post_count := 3
	var pole_scale := 9.0 / 49.45
	var pole_scene: Variant = _load_gltf_scene_from_file(pole_path)
	if pole_scene is Node3D:
		for i in range(post_count):
			var t := float(i) / float(post_count - 1)
			var pos := start.lerp(end, t)
			var node := (pole_scene as Node3D).duplicate() as Node3D
			node.name = "TelephonePoleGLB_%d" % i
			node.add_to_group("world_action_visual")
			node.position = pos
			node.scale = Vector3.ONE * pole_scale
			node.rotation_degrees = Vector3(0, 90, 0)
			add_child(node)
			_snap_node_bottom_to_y_cached(node, pos.y, pole_path, Vector3.ONE * pole_scale)
	_register_wildlife_blocker(center, 1.0)

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
	var stick_path := "res://assets/models/props/wood_stick.glb"
	# Two vertical support poles at the back end of the shelter, left and right
	_try_instance_external_scene([stick_path], "CampSupportPoleA", pos + Vector3(-0.9, 0.3, -2.0), Vector3(1.0, 0.4, 0.4), Vector3(0, 0, 90), false, 0.0)
	_try_instance_external_scene([stick_path], "CampSupportPoleB", pos + Vector3(0.9, 0.3, -2.0), Vector3(1.0, 0.4, 0.4), Vector3(0, 0, 90), false, 0.0)
	# 9 long thin roof sticks leaning from front pole to back pole
	var offsets := [-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8]
	for i in range(9):
		_try_instance_external_scene([stick_path], "CampRoofStick_%d" % i, pos + Vector3(offsets[i], 0.4, 0.8), Vector3(1.5, 0.4, 0.4), Vector3(-50, 0, 90), false, 0.0)
	# Apply darkened ground texture to all camp sticks for camouflage
	_apply_camp_camouflage(pos)

func _apply_camp_camouflage(_camp_pos: Vector3) -> void:
	# Extract the ground texture from the terrain model
	var ground_tex := _extract_texture_from_glb(LEAFY_FLOOR_MODEL)
	var camo_mat := StandardMaterial3D.new()
	if ground_tex != null:
		camo_mat.albedo_texture = ground_tex
		camo_mat.albedo_color = Color(0.22, 0.26, 0.16)  # darkened green-brown
		camo_mat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	else:
		camo_mat.albedo_color = Color(0.18, 0.20, 0.12)
	camo_mat.roughness = 0.95
	camo_mat.metallic = 0.0
	# Find all camp stick nodes and apply the material
	var stick_names := ["CampSupportPoleA", "CampSupportPoleB"]
	for i in range(9):
		stick_names.append("CampRoofStick_%d" % i)
	for node_name in stick_names:
		var node := get_node_or_null(NodePath(node_name))
		if node == null:
			continue
		var meshes: Array = []
		_collect_mesh_instances(node, meshes)
		for mi in meshes:
			(mi as MeshInstance3D).material_override = camo_mat

func _create_military_leftovers(pos: Vector3) -> void:
	_register_wildlife_blocker(pos, 4.5)
	_create_static_box_rotated("SandbagLineA", pos + Vector3(-1.1, 0, 0), Vector3(2.4, 0.42, 0.72), Color(0.31, 0.29, 0.21), Vector3(0, 10, 0))
	_create_static_box_rotated("SandbagLineB", pos + Vector3(1.3, 0, 0.3), Vector3(2.0, 0.42, 0.72), Color(0.28, 0.26, 0.19), Vector3(0, -12, 0))
	_create_static_cylinder("OldOilDrumA", pos + Vector3(-2.2, 0, -1.1), 0.34, 0.9, Color(0.12, 0.14, 0.12))
	_create_static_cylinder("OldOilDrumB", pos + Vector3(-1.65, 0, -1.35), 0.30, 0.78, Color(0.15, 0.08, 0.055))
	_create_static_box_rotated("WarningBoard", pos + Vector3(1.7, 0.5, -1.2), Vector3(1.4, 0.72, 0.10), Color(0.30, 0.25, 0.11), Vector3(0, -24, -5))

func _is_in_house_doorway(pos: Vector3, margin := 4.0) -> bool:
	var house_origins := [
		Vector3(-25, 0, -18),
		Vector3(-38, 0, 18),
		Vector3(23, 0, 18),
		Vector3(42, 0, 26),
		Vector3(-12, 0, 42)
	]
	for origin in house_origins:
		var door_pos: Vector3 = origin + Vector3(0, 0, 4.87)
		if absf(pos.x - door_pos.x) <= 3.0 + margin and pos.z >= door_pos.z - 1.0 and pos.z <= door_pos.z + margin:
			return true
	return false

func _can_place_ground_vegetation(pos: Vector3, river_margin := 0.45) -> bool:
	if _is_in_house_doorway(pos):
		return false
	if _is_on_road(pos):
		return false
	if river_margin >= 0.0 and _is_inside_river_band(pos, river_margin):
		return false
	return not _is_in_no_grass_area(pos, 0.65)

#endregion


#region CONSULTAS GEOGRÁFICAS
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

const HOUSE_FOOTPRINTS := [
	{"origin": Vector3(-25, 0, -18), "w": 11.4, "d": 9.4},
	{"origin": Vector3(-38, 0, 18), "w": 14.0, "d": 11.0},
	{"origin": Vector3(23, 0, 18), "w": 9.0, "d": 7.5},
	{"origin": Vector3(42, 0, 26), "w": 12.5, "d": 10.0},
	{"origin": Vector3(-12, 0, 42), "w": 8.0, "d": 7.0},
	{"origin": Vector3(-35, 0, -40), "w": 10.5, "d": 8.5},
	{"origin": Vector3(30, 0, -35), "w": 13.0, "d": 10.0},
	{"origin": Vector3(-45, 0, -5), "w": 9.5, "d": 8.0},
	{"origin": Vector3(35, 0, -8), "w": 11.0, "d": 9.0},
	{"origin": Vector3(-20, 0, 30), "w": 7.5, "d": 6.5},
]

func _is_near_house(pos: Vector3, margin: float) -> bool:
	for hd in HOUSE_FOOTPRINTS:
		var origin: Vector3 = hd["origin"]
		var half_w: float = float(hd["w"]) * 0.5 + margin
		var half_d: float = float(hd["d"]) * 0.5 + margin
		if abs(pos.x - origin.x) <= half_w and abs(pos.z - origin.z) <= half_d:
			return true
	return false

func _is_near_river(pos: Vector3, margin: float) -> bool:
	var p := Vector2(pos.x, pos.z)
	for segment in river_segments_data:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = deg_to_rad(float(segment["yaw"]))
		var along := Vector2(cos(yaw), -sin(yaw))
		var across := Vector2(sin(yaw), cos(yaw))
		var half_length := size.x * 0.5 + margin
		var half_width := size.y * 0.5 + margin
		var offset := p - Vector2(center.x, center.z)
		var local_along := offset.dot(along)
		var local_across := offset.dot(across)
		if abs(local_along) <= half_length and abs(local_across) <= half_width:
			return true
	return false

func _is_in_river(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for segment in river_segments_data:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = deg_to_rad(float(segment["yaw"]))
		var along := Vector2(cos(yaw), -sin(yaw))
		var across := Vector2(sin(yaw), cos(yaw))
		var half_length := size.x * 0.5
		var half_width := size.y * 0.5
		var offset := p - Vector2(center.x, center.z)
		var local_along := offset.dot(along)
		var local_across := offset.dot(across)
		if abs(local_along) <= half_length and abs(local_across) <= half_width:
			return true
	return false

func _is_inside_closed_house(pos: Vector3) -> bool:
	var p := Vector2(pos.x, pos.z)
	for blocker in wildlife_blockers:
		var door = blocker.get("door", null)
		var door_is_open := _check_door_open(door, blocker)
		if not door_is_open and blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			if bounds.has_point(p):
				return true
	return false

func get_wildlife_avoidance_vector_at(pos: Vector3) -> Vector3:
	var push := Vector3.ZERO
	var p := Vector2(pos.x, pos.z)
	for blocker in wildlife_blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var door = blocker.get("door", null)
		var door_is_open := _check_door_open(door, blocker)
		# When a house door is closed, push wolf toward house center if near bounds edge
		if not door_is_open and blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			var expanded := bounds.grow(2.5)
			if expanded.has_point(p) and not bounds.has_point(p):
				var center := bounds.get_center()
				push += Vector3(center.x - p.x, 0.0, center.y - p.y).normalized()
			continue
		var radius := float(blocker.get("radius", 1.8)) + 2.1
		var offset := p - Vector2(blocker_pos.x, blocker_pos.z)
		var distance := offset.length()
		if distance <= 0.001:
			push += Vector3.RIGHT * radius
		elif distance < radius:
			if door_is_open:
				var local_x := pos.x - blocker_pos.x
				var local_z := pos.z - blocker_pos.z
				if abs(local_x) <= 3.0 and local_z >= -5.5 and local_z <= 10.0:
					continue
			var strength := (radius - distance) / radius
			push += Vector3(offset.x, 0.0, offset.y).normalized() * strength
	if push.length() > 0.01:
		return push.normalized()
	return Vector3.ZERO

func _register_wildlife_blocker(pos: Vector3, radius := 1.8) -> int:
	var idx := wildlife_blockers.size()
	wildlife_blockers.append({
		"pos": Vector3(pos.x, 0.0, pos.z),
		"radius": radius,
		"door": null
	})
	return idx

func _check_door_open(door, blocker: Dictionary) -> bool:
	if door != null and is_instance_valid(door) and door.get("is_open") == true:
		return true
	# Fallback: check _server_door_states by door name
	if door != null and is_instance_valid(door):
		var door_name: String = door.name
		if _server_door_states.has(door_name):
			return bool(_server_door_states[door_name])
	return false

func _is_near_wildlife_blocker(pos: Vector3, extra_margin := 0.0) -> bool:
	var p := Vector2(pos.x, pos.z)
	for blocker in wildlife_blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var door = blocker.get("door", null)
		var door_is_open := _check_door_open(door, blocker)
		# House bounds: always block walls, allow doorway passage when door is open
		if blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			var expanded_bounds := bounds.grow(3.5)
			if expanded_bounds.has_point(p):
				if door_is_open and _is_in_doorway_passage(pos, blocker_pos):
					continue
				return true
			continue
		var radius := float(blocker.get("radius", 1.8)) + extra_margin
		if p.distance_to(Vector2(blocker_pos.x, blocker_pos.z)) <= radius:
			if door_is_open:
				var local_x := pos.x - blocker_pos.x
				var local_z := pos.z - blocker_pos.z
				if abs(local_x) <= 3.0 and local_z >= -5.5 and local_z <= 10.0:
					continue
			return true
	return false

func _is_in_doorway_passage(pos: Vector3, house_origin: Vector3) -> bool:
	var local_x := pos.x - house_origin.x
	var local_z := pos.z - house_origin.z
	if abs(local_x) <= 1.5 and local_z >= -5.2 and local_z <= 5.2:
		return true
	return false

func _update_door_open_cache() -> void:
	_door_open_cache.clear()
	for blocker in wildlife_blockers:
		var door = blocker.get("door", null)
		if door == null or not is_instance_valid(door):
			continue
		if door.get("is_open") != true:
			continue
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		# For house_bounds blockers, unblock doorway passage cells
		if blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			var expanded := bounds.grow(3.5)
			var min_cell := _world_to_grid(Vector3(expanded.position.x, 0.0, expanded.position.y))
			var max_cell := _world_to_grid(Vector3(expanded.position.x + expanded.size.x, 0.0, expanded.position.y + expanded.size.y))
			for gx in range(min_cell.x, max_cell.x + 1):
				for gy in range(min_cell.y, max_cell.y + 1):
					if gx < 0 or gx >= _nav_grid_size or gy < 0 or gy >= _nav_grid_size:
						continue
					var cell := Vector2i(gx, gy)
					if not _nav_grid.has(cell):
						continue
					var world_pos := _grid_to_world(cell)
					if _is_in_doorway_passage(world_pos, blocker_pos):
						_door_open_cache[cell] = true
			continue
		var radius: float = float(blocker.get("radius", 1.8))
		var center_cell := _world_to_grid(blocker_pos)
		var cell_radius := int(ceil(radius / _nav_cell_size)) + 1
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
				if cell.x < 0 or cell.x >= _nav_grid_size or cell.y < 0 or cell.y >= _nav_grid_size:
					continue
				if not _nav_grid.has(cell):
					continue
				var world_pos := _grid_to_world(cell)
				var local_x := world_pos.x - blocker_pos.x
				var local_z := world_pos.z - blocker_pos.z
				if abs(local_x) <= 1.5 and local_z >= -5.2 and local_z <= 10.0:
					_door_open_cache[cell] = true

func _get_exact_ground_y(x: float, z: float) -> float:
	var space_state := get_world_3d().direct_space_state
	if space_state != null:
		var query := PhysicsRayQueryParameters3D.create(Vector3(x, 250.0, z), Vector3(x, -50.0, z))
		query.collision_mask = 1
		var result := space_state.intersect_ray(query)
		if not result.is_empty() and result.has("position"):
			return (result["position"] as Vector3).y
	return _get_ground_height(Vector3(x, 0, z))

func _get_ground_height(pos: Vector3) -> float:
	var max_h := 0.0
	for hill in _generated_hills:
		var dx_world: float = pos.x - hill.pos.x
		var dz_world: float = pos.z - hill.pos.z
		
		# Rotación inversa para alinear con los ejes locales de la colina
		var cos_y: float = cos(-hill.yaw_rad)
		var sin_y: float = sin(-hill.yaw_rad)
		var dx: float = dx_world * cos_y - dz_world * sin_y
		var dz: float = dx_world * sin_y + dz_world * cos_y
		
		var rx: float = hill.radius_x
		var rz: float = hill.radius_z
		var dist_sq: float = (dx * dx) / (rx * rx) + (dz * dz) / (rz * rz)
		if dist_sq < 1.0:
			var pct: float = sqrt(dist_sq)
			var h: float = hill.pos.y + hill.height * pow(1.0 - pct, 0.85)
			if h > max_h:
				max_h = h
	return max_h

func _create_ground_clutter() -> void:
	var total_clutter := int(200 * (MAP_EXTENT / 75.0) * (MAP_EXTENT / 75.0))
	for i in range(total_clutter):
		var rx := _world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT)
		var rz := _world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT)
		var pos := Vector3(rx, _get_exact_ground_y(rx, rz) + 0.02, rz)
		if not _can_place_ground_vegetation(pos):
			continue
		# Solo generamos pequeños manojos de hierba extra, eliminados todos los escombros (LooseDebris)
		_create_grass_clump(pos, _world_rng.randf_range(0.18, 0.52), Color(0.20, 0.36, 0.12).lerp(Color(0.38, 0.50, 0.17), _world_rng.randf()))
		if i % 200 == 0:
			var _saved_rng_state := _world_rng.state
			await get_tree().process_frame
			_world_rng.state = _saved_rng_state

func _create_tall_grass_fields() -> void:
	var total_fields := int(3 * (MAP_EXTENT / 75.0) * (MAP_EXTENT / 75.0))
	for i in range(total_fields):
		var center := Vector3(_world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT), 0, _world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT))
		var radius := Vector2(_world_rng.randf_range(20, 55), _world_rng.randf_range(20, 55))
		var count := int(radius.x * radius.y * 0.18)
		for j in range(count):
			var angle := _world_rng.randf_range(0.0, TAU)
			var dist := sqrt(_world_rng.randf()) 
			var pos := center + Vector3(cos(angle) * radius.x * dist, 0.0, sin(angle) * radius.y * dist)
			pos.y = _get_exact_ground_y(pos.x, pos.z) + 0.02
			if not _can_place_ground_vegetation(pos):
				continue
			_create_grass_clump(pos, _world_rng.randf_range(0.34, 0.72), Color(0.18, 0.32, 0.11).lerp(Color(0.32, 0.42, 0.14), _world_rng.randf()))
			if j % 200 == 0:
				var _saved_rng_state := _world_rng.state
				await get_tree().process_frame
				_world_rng.state = _saved_rng_state

func _create_dense_vegetation_zones() -> void:
	var total_zones := int(2 * (MAP_EXTENT / 75.0) * (MAP_EXTENT / 75.0))
	for i in range(total_zones):
		var center := Vector3(_world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT), 0, _world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT))
		var radius := Vector2(_world_rng.randf_range(15, 30), _world_rng.randf_range(15, 30))
		var count := int(radius.x * radius.y * 0.3)
		for j in range(count):
			var angle := _world_rng.randf_range(0.0, TAU)
			var dist := sqrt(_world_rng.randf())
			var pos := center + Vector3(cos(angle) * radius.x * dist, 0.0, sin(angle) * radius.y * dist)
			pos.y = _get_exact_ground_y(pos.x, pos.z) + 0.02
			if not _can_place_ground_vegetation(pos):
				continue
			_create_grass_clump(pos, _world_rng.randf_range(0.48, 1.05), Color(0.13, 0.27, 0.09).lerp(Color(0.30, 0.44, 0.14), _world_rng.randf()))
			if _world_rng.randf() < 0.30:
				_create_bush(pos + Vector3(_world_rng.randf_range(-0.4, 0.4), 0, _world_rng.randf_range(-0.4, 0.4)), _world_rng.randf_range(0.55, 0.95))
			if j % 150 == 0:
				var _saved_rng_state := _world_rng.state
				await get_tree().process_frame
				_world_rng.state = _saved_rng_state

func _create_grass_ground_cover() -> void:
	var total_patches := int(2 * (MAP_EXTENT / 75.0) * (MAP_EXTENT / 75.0))
	for i in range(total_patches):
		var center := Vector3(_world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT), 0, _world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT))
		var radius := Vector2(_world_rng.randf_range(30, 65), _world_rng.randf_range(30, 65))
		var count := int(radius.x * radius.y * 0.15)
		for j in range(count):
			var angle := _world_rng.randf_range(0.0, TAU)
			var dist := sqrt(_world_rng.randf())
			var pos := center + Vector3(cos(angle) * radius.x * dist, 0.0, sin(angle) * radius.y * dist)
			pos.y = _get_exact_ground_y(pos.x, pos.z) + 0.018
			if not _can_place_ground_vegetation(pos):
				continue
			_create_grass_clump(pos, _world_rng.randf_range(0.22, 0.48), Color(0.18, 0.32, 0.12).lerp(Color(0.34, 0.44, 0.16), _world_rng.randf()))
			if j % 200 == 0:
				var _saved_rng_state := _world_rng.state
				await get_tree().process_frame
				_world_rng.state = _saved_rng_state

func _create_grass_carpet() -> void:
	_ensure_grass_batches()
	var coverage := MAP_EXTENT * 1.05
	var spacing := 3.0
	var cells_x := int(coverage * 2.0 / spacing)
	var cells_z := int(coverage * 2.0 / spacing)
	var base_color := Color(0.20, 0.34, 0.12)
	var color_var := Color(0.34, 0.46, 0.16)
	for cx in range(cells_x):
		for cz in range(cells_z):
			if _world_rng.randf() < 0.25:
				continue
			var px := -coverage + float(cx) * spacing + _world_rng.randf_range(-0.5, 0.5)
			var pz := -coverage + float(cz) * spacing + _world_rng.randf_range(-0.5, 0.5)
			var pos := Vector3(px, _get_ground_height(Vector3(px, 0, pz)) + 0.012, pz)
			if not _can_place_ground_vegetation(pos):
				continue
			var h := _world_rng.randf_range(0.14, 0.36)
			var r := _world_rng.randf_range(0.28, 0.52)
			var c := base_color.lerp(color_var, _world_rng.randf()).darkened(_world_rng.randf_range(0.0, 0.12))
			_queue_grass_instance(pos, h, r, c)
		if cx % 20 == 0:
			var _saved_rng_state := _world_rng.state
			await get_tree().process_frame
			_world_rng.state = _saved_rng_state

func _create_billboard_underbrush_fields() -> void:
	var total_brushes := int(4 * (MAP_EXTENT / 75.0) * (MAP_EXTENT / 75.0))
	for i in range(total_brushes):
		var pos := Vector3(_world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT), 0.03, _world_rng.randf_range(-MAP_EXTENT, MAP_EXTENT))
		if not _can_place_ground_vegetation(pos):
			continue
		if _world_rng.randf() < 0.55 and pos.distance_to(Vector3(-48, 0, 20)) > 34.0:
			continue
		_create_billboard_underbrush(pos, _world_rng.randf_range(0.55, 1.05))

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
	var width := height * _world_rng.randf_range(0.95, 1.55)
	var yaw := _world_rng.randf_range(0.0, 360.0)
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

func _create_forest() -> void:
	# Generar bosque ultra denso y exhuberante optimizado por MultiMesh
	var total_trees := int(MAP_EXTENT * MAP_EXTENT * 0.09)
	var inner_clear_radius := 45.0 # Mantener centro despejado para casas
	var base_color := Color(0.20, 0.34, 0.12)
	var color_var := Color(0.34, 0.46, 0.16)
	for i in range(total_trees):
		var x := _world_rng.randf_range(-MAP_EXTENT * 1.10, MAP_EXTENT * 1.10)
		var z := _world_rng.randf_range(-MAP_EXTENT * 1.10, MAP_EXTENT * 1.10)
		
		# Mantener las zonas de construcción principales despejadas
		if Vector2(x, z).length() < inner_clear_radius:
			continue
		
		var pos := Vector3(x, _get_exact_ground_y(x, z), z)
		if not _can_place_ground_vegetation(pos, 2.0):
			continue
		if _is_near_house(pos, 3.0):
			continue
			
		_create_tree(pos, false)
		
		# Sembrar hierba MultiMesh hiper eficiente alrededor de los troncos
		for _g in range(1):
			var gpos := pos + Vector3(_world_rng.randf_range(-1.5, 1.5), 0.0, _world_rng.randf_range(-1.5, 1.5))
			gpos.y = _get_ground_height(Vector3(gpos.x, 0, gpos.z)) + 0.012
			if not _can_place_ground_vegetation(gpos):
				_queue_grass_instance(gpos, _world_rng.randf_range(0.25, 0.55), _world_rng.randf_range(0.35, 0.65), base_color.lerp(color_var, _world_rng.randf()))
				
		if i % 300 == 0:
			var _saved_rng_state := _world_rng.state
			await get_tree().process_frame
			_world_rng.state = _saved_rng_state

func _update_tree_interactions() -> void:
	if player == null or not is_instance_valid(player):
		return
	var ppos: Vector3 = player.global_position
	for entry in _tree_registry:
		var dist := Vector2(ppos.x - entry.pos.x, ppos.z - entry.pos.z).length()
		if dist < _tree_activation_radius and not entry.active:
			_activate_tree(entry)
		elif dist > _tree_deactivation_radius and entry.active:
			_deactivate_tree(entry)

func _activate_tree(entry: Dictionary) -> void:
	var visual_name: String = entry.visual_name
	var tree_id: int = entry.id
	var collision_name := visual_name + "_Collision"
	var pos: Vector3 = entry.pos
	_register_wildlife_blocker(pos, 5.0)
	var collision := _create_tree_collision(collision_name, pos)
	collision.add_to_group("world_action_visual")
	var action = _create_world_action("fell_tree_%d" % tree_id, "fell_tree", "Arbol", pos, Vector3(1.35, 3.2, 1.35), Color(0.12, 0.08, 0.035), false, false)
	var trunk_check := get_node_or_null(visual_name)
	if trunk_check == null:
		var trunk_fallback := get_node_or_null(visual_name + "_Trunk")
		if trunk_fallback != null:
			action.set_meta("visual_name", visual_name + "_Trunk")
	else:
		action.set_meta("visual_name", visual_name)
	action.set_meta("collision_name", collision_name)
	entry.active = true

func _deactivate_tree(entry: Dictionary) -> void:
	var action_id := "fell_tree_%d" % entry.id
	if world_actions_by_id.has(action_id):
		var action = world_actions_by_id[action_id]
		# Remove collision only, not the tree visual
		var collision_name := str(action.get_meta("collision_name")) if action.has_meta("collision_name") else ""
		if not collision_name.is_empty():
			var col_node := get_node_or_null(collision_name)
			if col_node != null:
				col_node.queue_free()
		action.mark_depleted()
		action.queue_free()
		world_actions_by_id.erase(action_id)
	entry.active = false

func _create_tree(pos: Vector3, is_interactive: bool = true) -> void:
	if not _can_place_ground_vegetation(pos, 2.8):
		return
	_tree_id_counter += 1
	var tree_id := _tree_id_counter
	var visual_name := "Tree_%d" % tree_id
	var collision_name := visual_name + "_Collision"
	var made_visual := false
	if _forest_tree_meshes.is_empty():
		_load_forest_tree_pack()
	if not _forest_tree_meshes.is_empty():
		var entry = _forest_tree_meshes[_world_rng.randi() % _forest_tree_meshes.size()]
		var src_mesh: ArrayMesh = entry.mesh
		var xform: Transform3D = entry.transform
		var aabb: AABB = entry.aabb
		var mi := MeshInstance3D.new()
		mi.name = visual_name
		mi.mesh = src_mesh
		var tree_scale := _world_rng.randf_range(0.8, 1.4)
		var tree_height := aabb.size.z * tree_scale
		if tree_height < 1.0:
			tree_scale = 1.0 / max(0.01, aabb.size.z)
		mi.position = pos
		mi.rotation_degrees = Vector3(-90, 0, _world_rng.randf_range(0, 360))
		mi.scale = Vector3(tree_scale, tree_scale, tree_scale)
		if pos.length() > 15.0:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 180.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)
		mi.add_to_group("world_action_visual")
		made_visual = true
	elif _try_instance_external_scene(_shuffled_paths(POLY_TREE_MODELS), visual_name, pos, Vector3.ONE * _world_rng.randf_range(1.15, 2.15), Vector3(0, _world_rng.randf_range(0, 360), 0), true, pos.y):
		_override_tree_foliage_green(visual_name)
		made_visual = true
	else:
		made_visual = _create_living_tree_fallback(pos, visual_name)
	if made_visual:
		if is_interactive:
			_register_wildlife_blocker(pos, 5.0)
			var collision := _create_tree_collision(collision_name, pos)
			collision.add_to_group("world_action_visual")
			var action = _create_world_action("fell_tree_%d" % tree_id, "fell_tree", "Arbol", pos, Vector3(1.35, 3.2, 1.35), Color(0.12, 0.08, 0.035), false, false)
			var trunk_check := get_node_or_null(visual_name)
			if trunk_check == null:
				var trunk_fallback := get_node_or_null(visual_name + "_Trunk")
				if trunk_fallback != null:
					action.set_meta("visual_name", visual_name + "_Trunk")
			else:
				action.set_meta("visual_name", visual_name)
			action.set_meta("collision_name", collision_name)
		else:
			_tree_registry.append({"pos": pos, "visual_name": visual_name, "id": tree_id, "active": false})

func _load_forest_tree_pack() -> void:
	var scene_resource = _get_external_scene_resource(FOREST_TREE_PACK_MODEL)
	if scene_resource == null:
		return
	var instance: Node = null
	if scene_resource is PackedScene:
		instance = (scene_resource as PackedScene).instantiate()
	elif scene_resource is Node3D:
		instance = (scene_resource as Node3D).duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS | Node.DUPLICATE_USE_INSTANTIATION)
	if not (instance is Node3D):
		if instance != null:
			instance.queue_free()
		return
	var root := instance as Node3D
	add_child(root)
	root.rotation_degrees.x = -90.0
	root.force_update_transform()
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh == null:
			continue
		var name_lower := mesh_inst.name.to_lower()
		if not (name_lower.contains("tree") or name_lower.contains("branch") or name_lower.contains("trunk")):
			continue
		if name_lower.contains("rock"):
			continue
		var aabb := mesh_inst.get_aabb()
		if aabb.size.z < 1.5:
			continue
		var world_xform: Transform3D = mesh_inst.global_transform
		_forest_tree_meshes.append({
			"mesh": mesh_inst.mesh,
			"transform": world_xform,
			"aabb": aabb
		})
	remove_child(root)
	root.queue_free()

func _create_cut_tree_remains(pos: Vector3) -> void:
	var stump := _create_static_cylinder("CutTreeStump", pos, 0.32, 0.55, Color(0.18, 0.105, 0.045))
	stump.add_to_group("cut_tree_remains")
	_create_visual_cylinder("CutTreeStumpTop", pos + Vector3(0, 0.585, 0), 0.33, 0.035, Color(0.36, 0.24, 0.12), Vector3.ZERO)
	var yaw_a := _world_rng.randf_range(0.0, 180.0)
	var yaw_b := yaw_a + _world_rng.randf_range(42.0, 86.0)
	if not _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], "CutTreeLogAssetA", pos + Vector3(0.72, 0.12, 0.18), Vector3.ONE * 0.75, Vector3(0, yaw_a, 0), true, 0.06):
		_create_visual_cylinder("CutTreeLogA", pos + Vector3(0.72, 0.22, 0.18), 0.18, 2.2, Color(0.20, 0.12, 0.055), Vector3(90, yaw_a, 0))
	if not _try_instance_external_scene([SURVIVAL_TOOL_MODELS["wood"]], "CutTreeLogAssetB", pos + Vector3(-0.58, 0.12, -0.28), Vector3.ONE * 0.62, Vector3(0, yaw_b, 0), true, 0.06):
		_create_visual_cylinder("CutTreeLogB", pos + Vector3(-0.58, 0.20, -0.28), 0.15, 1.65, Color(0.16, 0.09, 0.04), Vector3(90, yaw_b, 0))
	for i in range(3):
		var branch_pos := pos + Vector3(_world_rng.randf_range(-0.7, 0.7), 0.10, _world_rng.randf_range(-0.7, 0.7))
		_create_visual_cylinder("CutTreeBranch", branch_pos, _world_rng.randf_range(0.035, 0.06), _world_rng.randf_range(0.7, 1.15), Color(0.13, 0.075, 0.035), Vector3(90, _world_rng.randf_range(0, 180), _world_rng.randf_range(-12, 12)))
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
	mat.angle_curve = rot_tex
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
	var width := height * _world_rng.randf_range(0.42, 0.56)
	var yaw := _world_rng.randf_range(0.0, 360.0)
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

func _create_living_tree_fallback(pos: Vector3, visual_name: String) -> bool:
	if _try_instance_external_scene(_shuffled_paths(REAL_LIVING_TREE_MODELS), visual_name, pos, Vector3.ONE * _world_rng.randf_range(1.15, 1.9), Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
		_override_tree_foliage_green(visual_name)
		return true
	var height := _world_rng.randf_range(6.4, 10.2)
	var trunk_radius := _world_rng.randf_range(0.18, 0.34)
	var use_fir := _world_rng.randf() < 0.45
	var bark_texture := POLY_FIR_BARK_DIFF if use_fir else POLY_PINE_BARK_DIFF
	var twig_texture := POLY_FIR_TWIG_DIFF if use_fir else POLY_PINE_TWIG_DIFF
	var twig_alpha := POLY_FIR_TWIG_ALPHA if use_fir else POLY_PINE_TWIG_ALPHA
	_create_textured_cylinder(visual_name + "_Trunk", pos, trunk_radius, height * 0.82, bark_texture, Color(0.18, 0.12, 0.075), Vector3(2.0, 6.0, 1.0))
	var trunk_node := get_node_or_null(visual_name + "_Trunk")
	if trunk_node != null:
		trunk_node.add_to_group("world_action_visual")
	var branch_count := 18 + _world_rng.randi() % 9
	for i in range(branch_count):
		var t: float = float(i) / float(max(branch_count - 1, 1))
		var branch_y: float = lerp(height * 0.26, height * 0.93, t)
		var ring_scale: float = 1.0 - t * 0.72
		var angle: float = _world_rng.randf_range(0.0, TAU)
		var side := Vector3(cos(angle), 0, sin(angle))
		var branch_pos := pos + side * _world_rng.randf_range(0.06, 0.20) + Vector3(0, branch_y, 0)
		var branch_width := _world_rng.randf_range(1.2, 2.4) * ring_scale
		var branch_height := _world_rng.randf_range(0.62, 1.15) * ring_scale
		_create_tree_twig_plane(branch_pos, Vector2(branch_width, branch_height), rad_to_deg(angle), twig_texture, twig_alpha)
	return true

func _create_dead_tree_fallback(pos: Vector3) -> void:
	if _try_instance_external_scene(_shuffled_paths(REAL_DEAD_TREE_MODELS), "ExternalDeadTree", pos, Vector3.ONE * _world_rng.randf_range(1.05, 1.75), Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
		_create_tree_collision("ExternalDeadTreeCollision", pos)
		return
	var height := _world_rng.randf_range(4.2, 7.2)
	var trunk_color := Color(0.14, 0.10, 0.07).lerp(Color(0.24, 0.20, 0.15), _world_rng.randf())
	_create_static_cylinder("DeadFallbackTrunk", pos, _world_rng.randf_range(0.16, 0.28), height * 0.82, trunk_color)
	for i in range(5 + _world_rng.randi() % 4):
		var side := -1.0 if i % 2 == 0 else 1.0
		var y := height * _world_rng.randf_range(0.34, 0.78)
		var branch_length := _world_rng.randf_range(0.85, 1.75)
		var branch_pos := pos + Vector3(side * _world_rng.randf_range(0.18, 0.46), y, _world_rng.randf_range(-0.22, 0.22))
		var branch_rot := Vector3(_world_rng.randf_range(54.0, 76.0), _world_rng.randf_range(-70.0, 70.0), side * _world_rng.randf_range(18.0, 42.0))
		_create_visual_cylinder("DeadFallbackBranch", branch_pos, _world_rng.randf_range(0.025, 0.055), branch_length, trunk_color.darkened(_world_rng.randf_range(0.04, 0.18)), branch_rot)
	if _world_rng.randf() < 0.35:
		_create_visual_sphere("DeadFallbackSparseLeaves", pos + Vector3(_world_rng.randf_range(-0.25, 0.25), height * 0.74, _world_rng.randf_range(-0.25, 0.25)), Vector3(_world_rng.randf_range(0.55, 0.9), _world_rng.randf_range(0.24, 0.42), _world_rng.randf_range(0.45, 0.78)), Color(0.055, 0.095, 0.042))

func _create_grass_clump(pos: Vector3, height: float, color: Color) -> void:
	if not _can_place_ground_vegetation(pos):
		return
	var clump_height: float = clamp(height, 0.16, 1.35)
	var tuft_color := color.lerp(Color(0.42, 0.52, 0.18), _world_rng.randf_range(0.0, 0.22)).darkened(_world_rng.randf_range(0.0, 0.08))
	_create_grass_tuft("VerticalGrassTuft", pos, clump_height * _world_rng.randf_range(0.80, 1.18), _world_rng.randf_range(0.12, 0.24), tuft_color)

func _create_river_reed_cluster(pos: Vector3, height: float, side: float) -> void:
	for i in range(3 + _world_rng.randi() % 4):
		var reed_pos := pos + Vector3(_world_rng.randf_range(-0.55, 0.55), 0.0, _world_rng.randf_range(-0.55, 0.55))
		if not _can_place_ground_vegetation(reed_pos, -1.0):
			continue
		var reed_color := Color(0.12, 0.25, 0.08).lerp(Color(0.18, 0.32, 0.10), _world_rng.randf())
		_queue_tall_grass_instance(reed_pos, height * _world_rng.randf_range(0.72, 1.08) * 0.45, reed_color)

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
	grass_batch_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	_tall_grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
		await get_tree().process_frame
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

#endregion


#region PRIMITIVAS Y GEOMETRÍA (PrimitiveBuilder)
func _create_bush(pos: Vector3, radius: float) -> void:
	if not _can_place_ground_vegetation(pos):
		return
	_bush_id_counter += 1
	var visual_name := "Bush_%d" % _bush_id_counter
	var made_visual := false
	var meta_names := ""
	if _try_instance_external_scene(_shuffled_paths(REAL_BUSH_MODELS), visual_name, pos, Vector3.ONE * _world_rng.randf_range(radius * 0.22, radius * 0.42), Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0):
		var vn := get_node_or_null(visual_name)
		if vn != null:
			vn.add_to_group("world_action_visual")
			_remove_collision_from_node(vn)
		meta_names = visual_name
		made_visual = true
	else:
		var base_color := Color(0.05, 0.12, 0.045).lerp(Color(0.10, 0.17, 0.075), _world_rng.randf())
		var parts := ["_Core", "_LobeA", "_LobeB"]
		var offsets := [Vector3(0, radius * 0.25, 0), Vector3(radius * 0.30, radius * 0.35, -radius * 0.12), Vector3(-radius * 0.28, radius * 0.28, radius * 0.18)]
		var sizes := [Vector3(radius, radius * 0.48, radius * 0.82), Vector3(radius * 0.55, radius * 0.36, radius * 0.50), Vector3(radius * 0.48, radius * 0.34, radius * 0.52)]
		var colors := [base_color, base_color.darkened(0.10), base_color.lightened(0.06)]
		for i in range(3):
			var pname: String = visual_name + parts[i]
			_create_visual_sphere(pname, pos + offsets[i], sizes[i], colors[i])
			var pnode := get_node_or_null(pname)
			if pnode != null:
				pnode.add_to_group("world_action_visual")
		meta_names = visual_name + "_Core|" + visual_name + "_LobeA|" + visual_name + "_LobeB"
		made_visual = true
	if made_visual:
		var action = _create_world_action("fell_bush_%d" % _bush_id_counter, "fell_bush", "Arbusto", pos, Vector3(1.4, 1.2, 1.4), Color(0.08, 0.14, 0.05), false, false)
		action.set_meta("visual_name", meta_names)

func _create_cutout_plant(node_name: String, pos: Vector3, height: float, texture_path: String, alpha_path: String, width_factor: float) -> bool:
	if not _resource_path_exists(texture_path):
		return false
	var root := Node3D.new()
	root.name = node_name
	root.position = pos
	root.rotation_degrees.y = _world_rng.randf_range(0.0, 360.0)
	add_child(root)
	var plane_count := 2 + _world_rng.randi() % 2
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

func _create_textured_wall_with_openings(node_name: String, pos: Vector3, size: Vector3, rot: Vector3, openings: Array) -> void:
	var is_x_wall := size.x > size.z
	var wall_w := size.x if is_x_wall else size.z
	var wall_h := size.y
	var wall_t := size.z if is_x_wall else size.x
	var holes: Array = []
	for op in openings:
		holes.append({
			"x0": float(op[0]) - float(op[2]) * 0.5,
			"x1": float(op[0]) + float(op[2]) * 0.5,
			"y0": float(op[1]) - float(op[3]) * 0.5,
			"y1": float(op[1]) + float(op[3]) * 0.5,
		})
	var ys: Array = [0.0, wall_h]
	for h in holes:
		ys.append(h["y0"])
		ys.append(h["y1"])
	ys.sort()
	var seg := 0
	for yi in range(ys.size() - 1):
		var y0: float = ys[yi]
		var y1: float = ys[yi + 1]
		if y1 - y0 < 0.005:
			continue
		var yh := y1 - y0
		var xs: Array = [-wall_w * 0.5, wall_w * 0.5]
		for h in holes:
			if h["y0"] <= y0 + 0.005 and h["y1"] >= y1 - 0.005:
				xs.append(h["x0"])
				xs.append(h["x1"])
		xs.sort()
		for xi in range(xs.size() - 1):
			var x0: float = xs[xi]
			var x1: float = xs[xi + 1]
			if x1 - x0 < 0.005:
				continue
			var is_hole := false
			for h in holes:
				if h["y0"] <= y0 + 0.005 and h["y1"] >= y1 - 0.005:
					if x0 >= h["x0"] - 0.005 and x1 <= h["x1"] + 0.005:
						is_hole = true
						break
			if is_hole:
				continue
			var xmid := (x0 + x1) * 0.5
			var xw := x1 - x0
			var seg_pos: Vector3
			var seg_size: Vector3
			if is_x_wall:
				seg_pos = pos + Vector3(xmid, y0, 0)
				seg_size = Vector3(xw, yh, wall_t)
			else:
				seg_pos = pos + Vector3(0, y0, xmid)
				seg_size = Vector3(wall_t, yh, xw)
			_create_textured_wall(node_name + " S" + str(seg), seg_pos, seg_size, rot)
			seg += 1

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
	trunk_shape.radius = 0.20
	trunk_shape.height = 6.8
	trunk_collision.shape = trunk_shape
	trunk_collision.position.y = trunk_shape.height * 0.5
	body.add_child(trunk_collision)

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
	mesh_instance.rotation_degrees = Vector3(_world_rng.randf_range(-10.0, 7.0), yaw, _world_rng.randf_range(-8.0, 8.0))
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

func _create_leafy_floor_ground() -> void:
	var leafy_texture = _extract_texture_from_glb(LEAFY_FLOOR_MODEL)
	if leafy_texture == null:
		_create_visual_plane("TerrainSurface", Vector3(0, 0.003, 0), Vector2(MAP_EXTENT * 2.0, MAP_EXTENT * 2.0), Color(0.17, 0.20, 0.145))
		var ts := get_node_or_null("TerrainSurface") as MeshInstance3D
		if ts != null:
			_cached_leafy_material = ts.material_override as StandardMaterial3D
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "TerrainSurface"
	mesh_instance.position = Vector3(0, 0.003, 0)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(MAP_EXTENT * 2.0, MAP_EXTENT * 2.0)
	mesh.subdivide_width = int(MAP_EXTENT / 10.0)
	mesh.subdivide_depth = int(MAP_EXTENT / 10.0)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.65, 0.28)
	material.albedo_texture = leafy_texture
	material.roughness = 0.97
	material.metallic = 0.0
	material.uv1_scale = Vector3(MAP_EXTENT * 0.3, MAP_EXTENT * 0.3, 1.0)
	_cached_leafy_material = material
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var dirt_mi := MeshInstance3D.new()
	dirt_mi.name = "TerrainSurfaceDirt"
	dirt_mi.position = Vector3(0, 0.002, 0)
	var dirt_mesh := PlaneMesh.new()
	dirt_mesh.size = Vector2(MAP_EXTENT * 2.0, MAP_EXTENT * 2.0)
	dirt_mesh.subdivide_width = int(MAP_EXTENT / 10.0)
	dirt_mesh.subdivide_depth = int(MAP_EXTENT / 10.0)
	dirt_mi.mesh = dirt_mesh
	var dirt_mat := StandardMaterial3D.new()
	dirt_mat.albedo_color = Color(0.48, 0.38, 0.26, 0.5)
	dirt_mat.albedo_texture = leafy_texture
	dirt_mat.roughness = 0.97
	dirt_mat.metallic = 0.0
	dirt_mat.uv1_scale = Vector3(44.0, 44.0, 1.0)
	dirt_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dirt_mi.material_override = dirt_mat
	add_child(dirt_mi)

func _extract_texture_from_glb(path: String) -> Texture2D:
	var disk_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		return null
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(disk_path, state)
	if error != OK:
		return null
	var generated_scene := document.generate_scene(state)
	if not (generated_scene is Node3D):
		if generated_scene != null:
			generated_scene.queue_free()
		return null
	var root := generated_scene as Node3D
	add_child(root)
	var meshes: Array = []
	_collect_mesh_instances(root, meshes)
	var result: Texture2D = null
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst.mesh != null and mesh_inst.mesh.get_surface_count() > 0:
			var mat = mesh_inst.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				if sm.albedo_texture != null:
					result = sm.albedo_texture
					break
	if result == null:
		for mi in meshes:
			var mesh_inst := mi as MeshInstance3D
			var mat_override = mesh_inst.material_override
			if mat_override is StandardMaterial3D:
				var sm := mat_override as StandardMaterial3D
				if sm.albedo_texture != null:
					result = sm.albedo_texture
					break
	remove_child(root)
	root.queue_free()
	return result

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
		var ripple := _world_rng.randf_range(0.68, 1.18)
		if i % 3 == 0:
			ripple *= _world_rng.randf_range(0.76, 1.04)
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
	mesh_instance.rotation_degrees = Vector3(_world_rng.randf_range(-4.0, 4.0), _world_rng.randf_range(0.0, 360.0), _world_rng.randf_range(-4.0, 4.0))
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
	var tile := 1.5
	var uvs := PackedVector2Array([
		Vector2(vertices[0].x / tile + 0.5, vertices[0].z / tile + 0.5),
		Vector2(vertices[1].x / tile + 0.5, vertices[1].z / tile + 0.5),
		Vector2(vertices[2].x / tile + 0.5, vertices[2].z / tile + 0.5),
		Vector2(vertices[3].x / tile + 0.5, vertices[3].z / tile + 0.5),
		Vector2(vertices[4].x / tile + 0.5, vertices[4].z / tile + 0.5),
		Vector2(vertices[5].x / tile + 0.5, vertices[5].z / tile + 0.5)
	])
	var normals := PackedVector3Array([
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0)
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.mesh = mesh
	if _roof_texture == null:
		_roof_texture = _extract_texture_from_glb(MODULAR_ROOF_MODEL)
	if _roof_texture != null:
		var roof_mat := StandardMaterial3D.new()
		roof_mat.albedo_color = Color(0.85, 0.75, 0.65)
		roof_mat.albedo_texture = _roof_texture
		roof_mat.roughness = 0.95
		roof_mat.metallic = 0.0
		roof_mat.uv1_scale = Vector3(2.5, 2.5, 1.0)
		roof_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mesh.surface_set_material(0, roof_mat)
	else:
		mesh_instance.material_override = _make_material(color, true)
	add_child(mesh_instance)

#endregion


#region FÁBRICA DE MATERIALES Y TEXTURAS
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

const REALISTIC_SKY_SHADER := "res://shaders/realistic_sky.gdshader"

func _make_shader_sky_material() -> ShaderMaterial:
	if not ResourceLoader.exists(REALISTIC_SKY_SHADER):
		return null
	var shader = load(REALISTIC_SKY_SHADER)
	if shader == null or not (shader is Shader):
		return null
	var material := ShaderMaterial.new()
	material.shader = shader
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

#endregion


#region RECURSOS EXTERNOS Y ESCENAS
func _create_loot_container(id: String, label: String, pos: Vector3, size: Vector3, color: Color, model_paths: Array = []):
	var visual_name := "LootContainer_" + id
	var spawned := false
	if not model_paths.is_empty():
		spawned = _try_instance_external_scene(model_paths, visual_name, pos, Vector3.ONE, Vector3(0, _world_rng.randf_range(0, 360), 0), true, 0.0)
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
				if not path_str.contains("telephone_pole"):
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

func _remove_collision_from_node(root: Node) -> void:
	var to_remove: Array = []
	_collect_collision_nodes(root, to_remove)
	for node in to_remove:
		if is_instance_valid(node):
			var parent := (node as Node).get_parent()
			if parent != null:
				parent.remove_child(node)
			(node as Node).queue_free()

func _collect_collision_nodes(node: Node, result: Array) -> void:
	if node is CollisionShape3D or node is StaticBody3D or node is RigidBody3D or node is AnimatableBody3D:
		result.append(node)
		return
	for child in node.get_children():
		_collect_collision_nodes(child, result)

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

# Barrera de hormigón: pendiente de implementar asset 3D
func _create_concrete_barrier(_node_name: String, _pos: Vector3, _rot: Vector3) -> void:
	return

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
	var _snap_dbg := FileAccess.open("user://scrap_car_debug.txt", FileAccess.READ_WRITE) if path.contains("scrap_barricade") else null
	if _snap_dbg:
		_snap_dbg.seek_end()
		_snap_dbg.store_line("[SNAP] path=" + path + " ground_y=" + str(ground_y) + " scale=" + str(scale_value) + " node_pos=" + str(node.global_position))
	if _snap_offset_cache.has(path):
		var unit_offset: float = float(_snap_offset_cache[path])
		node.global_position.y += ground_y - unit_offset * scale_value.y
		if _snap_dbg:
			_snap_dbg.store_line("[SNAP] cached unit_offset=" + str(unit_offset) + " new_pos_y=" + str(node.position.y))
			_snap_dbg.close()
		return
	node.force_update_transform()
	var meshes := []
	_collect_mesh_instances(node, meshes)
	if _snap_dbg:
		_snap_dbg.store_line("[SNAP] mesh_count=" + str(meshes.size()))
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
	if _snap_dbg:
		_snap_dbg.store_line("[SNAP] min_local_y=" + str(min_local_y))
	if min_local_y < 999999.0:
		var unit_offset := min_local_y / scale_value.y
		_snap_offset_cache[path] = unit_offset
		node.global_position.y += ground_y - min_local_y
		if _snap_dbg:
			_snap_dbg.store_line("[SNAP] adjusted pos_y=" + str(node.position.y) + " unit_offset=" + str(unit_offset))
			_snap_dbg.close()
	else:
		if _snap_dbg:
			_snap_dbg.store_line("[SNAP] WARNING: no valid meshes found for " + path)
			_snap_dbg.close()

func _collect_mesh_instances(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		_collect_mesh_instances(child, result)

func _raycast_ground_y(space_state: PhysicsDirectSpaceState3D, pos: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, 100.0, pos.z), Vector3(pos.x, -200.0, pos.z))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return float(hit["position"].y)
	return 0.0

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

func _get_node_world_aabb_min_y(node: Node3D) -> float:
	node.force_update_transform()
	var meshes := []
	_collect_mesh_instances(node, meshes)
	var min_y := 1000000.0
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		min_y = min(min_y, world_aabb.position.y)
	if min_y < 1000000.0:
		return min_y
	return 0.0

func _compute_node_world_aabb(node: Node3D) -> AABB:
	node.force_update_transform()
	var meshes := []
	_collect_mesh_instances(node, meshes)
	var combined := AABB()
	var first := true
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		if first:
			combined = world_aabb
			first = false
		else:
			combined = combined.merge(world_aabb)
	if first:
		return AABB(node.global_position, Vector3.ZERO)
	return combined

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
		# Block rectangular house bounds (walls)
		if blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			var expanded := bounds.grow(3.5)
			var min_cell := _world_to_grid(Vector3(expanded.position.x, 0.0, expanded.position.y))
			var max_cell := _world_to_grid(Vector3(expanded.position.x + expanded.size.x, 0.0, expanded.position.y + expanded.size.y))
			for gx in range(min_cell.x, max_cell.x + 1):
				for gy in range(min_cell.y, max_cell.y + 1):
					if gx >= 0 and gx < _nav_grid_size and gy >= 0 and gy < _nav_grid_size:
						_nav_grid[Vector2i(gx, gy)] = true
			continue
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
	_block_river_cells_in_nav_grid()
	_nav_grid_built = true

func _block_river_cells_in_nav_grid() -> void:
	for segment in river_segments_data:
		var center: Vector3 = segment["center"]
		var size: Vector2 = segment["size"]
		var yaw: float = deg_to_rad(float(segment["yaw"]))
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var across := Vector3(sin(yaw), 0.0, cos(yaw))
		var half_length := size.x * 0.5
		var half_width := size.y * 0.5
		var steps_l := int(ceil(size.x / _nav_cell_size)) + 1
		var steps_w := int(ceil(size.y / _nav_cell_size)) + 1
		for i in range(steps_l + 1):
			var local_along: float = lerp(-half_length, half_length, float(i) / float(steps_l))
			for j in range(steps_w + 1):
				var local_across: float = lerp(-half_width, half_width, float(j) / float(steps_w))
				var world_pos: Vector3 = center + along * local_along + across * local_across
				var cell := _world_to_grid(world_pos)
				if cell.x >= 0 and cell.x < _nav_grid_size and cell.y >= 0 and cell.y < _nav_grid_size:
					_nav_grid[cell] = true

func is_nav_cell_blocked(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.x >= _nav_grid_size - 1 or cell.y < 1 or cell.y >= _nav_grid_size - 1:
		return true
	if not _nav_grid.has(cell):
		return false
	if _door_open_cache.has(cell):
		return false
	return true

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
	var max_iterations := 8000
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
	return []

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
	return _smooth_path(path)

func _smooth_path(path: Array) -> Array:
	if path.size() <= 2:
		return path
	var smoothed: Array = [path[0]]
	var current_idx := 0
	while current_idx < path.size() - 1:
		var farthest := current_idx + 1
		for j in range(path.size() - 1, current_idx + 1, -1):
			if _is_path_clear_nav(path[current_idx], path[j]):
				farthest = j
				break
		smoothed.append(path[farthest])
		current_idx = farthest
	return smoothed

func _is_path_clear_nav(a: Vector3, b: Vector3) -> bool:
	var diff := b - a
	diff.y = 0.0
	var dist := diff.length()
	if dist < 0.01:
		return true
	var dir := diff.normalized()
	var steps := int(ceil(dist / _nav_cell_size))
	for i in range(1, steps):
		var pos := a + dir * (float(i) * _nav_cell_size)
		var cell := _world_to_grid(pos)
		if is_nav_cell_blocked(cell):
			return false
	return true

#endregion
