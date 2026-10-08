class_name GameConst
## Central constants file. Reference as GameConst.NAME from any script.
## Migrate constants here in small batches, always parse-check + regression
## after each batch (see AGENTS.md).

# -- World ---------------------------------------------------------------
const WORLD_LIMIT := 480.0
const WORLD_SEED := 1337

# -- Network -------------------------------------------------------------
const GAME_PORT := 5005
const DISCOVERY_PORT := 5006

# -- WorldAction ---------------------------------------------------------
const INTERACTION_CELL_SIZE := 4.0

# -- DayNightCycle -------------------------------------------------------
const LIGHTING_UPDATE_INTERVAL := 0.20

# -- Farming -------------------------------------------------------------
const CROP_MOIST_GROWTH := 2.5    # moist soil (rain or watering) multiplies growth
const CROP_WATER_SECONDS := 300.0 # a watering keeps the bed moist this many seconds
const CROP_RAIN_MIN := 0.1        # mm of rain that counts as moist soil
const CROP_WATER_USE := 40.0      # bottle durability drained per watering
const CROP_ROT_SECONDS := 600.0   # a ripe crop rots this many seconds after ready

# -- Shared asset paths ----------------------------------------------------
# Adapted character (Mixamo body + survival clothing skinned to the same rig).
const PLAYER_MODEL := "res://assets/characters/adapted/player_with_clothes.glb"
const NPC_HOSTILE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Characters/glTF/Characters_Matt_SingleWeapon.gltf"
const KNIFE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/Knife.gltf"
const MILITARY_HELMET_MODEL := "res://assets/models/equipment/tactical_helmet.glb"
const MILITARY_BACKPACK_MODEL := "res://assets/characters/adapted/military_backpack.glb"
const FISHERMANS_HAT_MODEL := "res://assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf"
const GARDEN_GLOVES_MODEL := "res://assets/external/polyhaven/garden_gloves_01/garden_gloves_01_1k.gltf"
const RIVERBANK_DIR := "res://assets/models/props/shore/"
const LAKE_DIR := "res://assets/models/props/lake/"
