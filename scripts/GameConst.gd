class_name GameConst
## Central constants file. Reference as GameConst.NAME from any script.
## Migrate constants here in small batches, always parse-check + regression
## after each batch (see AGENTS.md).

# -- World ---------------------------------------------------------------
const WORLD_LIMIT := 480.0
# Fauna puede adentrarse en la expansión sur; el límite en X sigue WORLD_LIMIT.
const WORLD_LIMIT_Z := 892.0
const WORLD_SEED := 1337

# -- Firearms (human player and survivor bots) -----------------------------
const RIFLE_MAG_SIZE := 5
const M4_MAG_SIZE := 30
const M4_BURST_ROUNDS := 3
const GUN_RELOAD_TIME := 2.2
const GUN_START_RESERVE_MAGS := 3

# -- Hand-thrown weapons (same flight for players and bots) ----------------
const SPEAR_THROW_SPEED := 25.0
const BOLA_THROW_SPEED := 22.0
const THROW_MAX_DISTANCE := 45.0
const BOT_THROW_EFFECTIVE_RANGE := 22.0

# -- Survivor emergency recovery -----------------------------------------
const BOT_EMERGENCY_REFUGE_RADIUS := 1400.0
const BOT_HEAT_ALERT_TEMP := 37.75
const BOT_HEAT_RECOVERY_TEMP := 37.5

# -- Network -------------------------------------------------------------
const GAME_PORT := 5005
const DISCOVERY_PORT := 5006

# -- WorldAction ---------------------------------------------------------
const INTERACTION_CELL_SIZE := 4.0

# -- DayNightCycle -------------------------------------------------------
const LIGHTING_UPDATE_INTERVAL := 0.20
# Posicion del mundo en el globo: de ella salen amanecer/atardecer reales.
const WORLD_LATITUDE := 40.0    # peninsula iberica
const WORLD_LONGITUDE := -3.7   # centro peninsular (mediodia solar ~13:00 CET)
# Horario unico del mundo (hora decimal). Lo usan DayNightCycle y los bots:
# ningun sistema define sus propios umbrales de dia/noche. Son `static var`
# porque DayNightCycle los recalcula al arrancar y cada medianoche a partir
# de la fecha real del sistema — en noviembre el sol se pone ~18:00, en junio
# ~21:30; los valores de abajo son los respaldos de arranque.
static var DAWN_START := 5.5     # primera luz
static var NIGHT_END := 6.0      # fin de la noche de reloj
static var SUNRISE_END := 7.0    # pleno dia
static var PREP_START := 16.5    # ultimas horas de luz plena: preparar la noche
static var DUSK_START := 19.5    # el sol empieza a caer (crepusculo)
static var NIGHT_START := 21.5   # noche de reloj
const DARK_LIGHT := 0.35    # luz ambiente por debajo de la cual hace falta antorcha

# -- Farming -------------------------------------------------------------
const CROP_MOIST_GROWTH := 2.5    # moist soil (rain or watering) multiplies growth
const CROP_WATER_SECONDS := 300.0 # a watering keeps the bed moist this many seconds
const CROP_RAIN_MIN := 0.1        # mm of rain that counts as moist soil
const CROP_WATER_USE := 40.0      # bottle durability drained per watering
const CROP_ROT_SECONDS := 600.0   # a ripe crop rots this many seconds after ready

# -- Food ------------------------------------------------------------------
# Carne cocinada por especie: [nombre, use_value, peso]. La especie viaja en
# el meta "species" del espeton (Carne ensartada) desde la pieza cruda.
# Orden nutritivo: oso > ciervo > lobo > zorro > ave; el pescado cocinado
# supera a toda la carne (COOKED_FISH = 50).
const COOKED_MEAT := {
	"": ["Carne cocinada", 35.0, 0.4],
	"oso": ["Carne asada de oso", 45.0, 0.5],
	"ciervo": ["Carne asada de ciervo", 40.0, 0.5],
	"lobo": ["Carne asada de lobo", 36.0, 0.4],
	"zorro": ["Carne asada de zorro", 32.0, 0.4],
	"ave": ["Carne asada de ave", 30.0, 0.35],
}
const COOKED_FISH := ["Pez cocinado", 50.0, 0.35]

# -- Shared asset paths ----------------------------------------------------
# Adapted character (Mixamo body + survival clothing skinned to the same rig).
const PLAYER_MODEL := "res://assets/characters/adapted/player_with_clothes.glb"
const NPC_HOSTILE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Characters/glTF/Characters_Matt_SingleWeapon.gltf"
const KNIFE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/Knife.gltf"
const MILITARY_HELMET_MODEL := "res://assets/models/equipment/tactical_helmet.glb"
const HEADLAMP_MODEL := "res://assets/characters/adapted/headlamp.glb"
const HEADLAMP_ITEM_NAME := "Linterna frontal"
const HEADLAMP_DROP_SCALE := 0.55
const MILITARY_BACKPACK_MODEL := "res://assets/characters/adapted/military_backpack.glb"
const BACKPACK_MODEL := "res://assets/characters/adapted/backpack_detailed.glb"
const FISHERMANS_HAT_MODEL := "res://assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf"
const GARDEN_GLOVES_MODEL := "res://assets/external/polyhaven/garden_gloves_01/garden_gloves_01_1k.gltf"
const WOLF_MODEL := "res://assets/models/animals/wolf_companion.glb"
const DEER_MODEL := "res://assets/models/wildlife/deer.glb"
const FOX_MODEL := "res://assets/models/wildlife/fox.glb"
const BEAR_MODEL := "res://assets/models/wildlife/bear.glb"
const RIVERBANK_DIR := "res://assets/models/props/shore/"
const LAKE_DIR := "res://assets/models/props/lake/"
const BIRD_MODEL := "res://assets/external/bird/simple_bird.glb"

# Animal-head tocados generated by tools/blender/make_pelt_headdresses.py —
# each keeps the real animal head and draped pelt of that species.
const PELT_DIR := "res://assets/characters/adapted/pelt/"
const PELT_HEADDRESS := {
	"lobo": PELT_DIR + "headdress_lobo.glb",
	"lobo negro": PELT_DIR + "headdress_lobo.glb",
	"ciervo": PELT_DIR + "headdress_ciervo.glb",
	"zorro": PELT_DIR + "headdress_zorro.glb",
	"oso": PELT_DIR + "headdress_oso.glb",
}
const PELT_DEFAULT_SPECIES := "lobo"

# Seamless fur tiles cropped from a fur-dense island of each species' real
# albedo atlas (tools/blender/make_pelt_fur_tiles.py). The raw atlases are UV
# unwraps on a flat background — sampling them directly would paint garments
# with the background fill. "ave" has no albedo texture (flat-color GLB), so
# its tile is synthesized feather streaks in the Bird_Body tint.
const PELT_FUR_TEXTURES := {
	"lobo": "res://assets/textures/pelt/fur_lobo.png",
	"lobo negro": "res://assets/textures/pelt/fur_lobo.png",
	"ciervo": "res://assets/textures/pelt/fur_ciervo.png",
	"zorro": "res://assets/textures/pelt/fur_zorro.png",
	"oso": "res://assets/textures/pelt/fur_oso.png",
	"ave": "res://assets/textures/pelt/fur_ave.png",
}
const PELT_FUR_ITEMS := ["Chaqueta de piel", "Pantalones de piel", "Botas de piel", "Guantes de piel", "Gorro de piel", "Tocado de piel animal"]
