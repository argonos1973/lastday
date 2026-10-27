extends CharacterBody3D
class_name PlayerController

@export_group("Rifle Strap")
@export var strap_width: float = 0.10
@export var strap_body_offset: float = 0.06
@export var strap_segment_count: int = 128
@export var strap_smoothing: float = 12.0
@export var strap_curvature: float = 1.0
@export var strap_sag: float = 0.06
@export var strap_uv_tile: float = 4.0
@export var strap_debug_points: bool = false

const SurvivalStatsScript = preload("res://scripts/SurvivalStats.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const ItemScript = preload("res://scripts/Item.gd")
const InteractionRaycastScript = preload("res://scripts/InteractionRaycast.gd")
const PlayerEquipmentScript = preload("res://scripts/PlayerEquipment.gd")
const PlayerHandsScript = preload("res://scripts/PlayerHands.gd")
const CraftingSystemScript = preload("res://scripts/CraftingSystem.gd")
const RifleStrapScript = preload("res://scripts/RifleStrap.gd")
const REAL_BOTTLE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/bottle.glb"
const REAL_PLASTIC_BOTTLE_MODEL := "res://assets/models/props/plastic_water_bottle.glb"
const REAL_WOOD_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/resource-wood.glb"
const REAL_STONE_MODEL := "res://assets/models/props/lake/lake_boulder_0.glb"
const REAL_AXE_MODEL := "res://assets/models/props/simple_axe.glb"
const REAL_HOE_MODEL := "res://assets/models/props/tools/tool_hoe.glb"
const REAL_SHOVEL_MODEL := "res://assets/models/props/tools/tool_shovel.glb"
const REAL_HAMMER_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-hammer.glb"
const REAL_PICKAXE_MODEL := "res://assets/models/props/tools/tool_pickaxe.glb"
const REAL_BACKPACK_MODEL := "res://assets/characters/adapted/backpack_detailed.glb"
const REAL_MEAT_ON_STICK_MODEL := "res://assets/models/props/cc0_-_raw_meat_4.glb"
const REAL_WOOD_STICK_MODEL := "res://assets/models/props/wood_stick.glb"
const REAL_TORCH_MODEL := "res://assets/animations/torch_stick.glb"

# Wearable visuals placed on the body relative to its measured bounding box, so
# they fit regardless of the character model's scale/proportions.
#   frac_y: anchor height as a fraction of body height (0 = feet, 1 = head top)
#   size:   item height as a fraction of body height
#   forward: shift toward the front of the body (fraction of depth)
#   align:  "center" (default) or "bottom"; "strip" hides duplicate variant meshes
const CLOTHING_VISUALS := {
	"Pasamontañas": {"path": "res://assets/characters/adapted/civil/balaclava.glb", "frac_y": 0.94, "size": 0.16, "yaw": 0.0, "face_fit": true},
	"Pasamontañas navideño": {"path": "res://assets/characters/adapted/civil/balaclava_navideno.glb", "frac_y": 0.94, "size": 0.16, "yaw": 0.0, "face_fit": true},
	"Sombrero de pescador": {"path": GameConst.FISHERMANS_HAT_MODEL, "frac_y": 0.94, "size": 0.06, "yaw": 0.0, "align": "bottom", "forward": -0.04},
	"Gorro de piel": {"path": GameConst.FISHERMANS_HAT_MODEL, "frac_y": 0.94, "size": 0.065, "yaw": 0.0, "align": "bottom", "forward": -0.04, "tint": Color(0.31, 0.22, 0.13)},
	"Tocado de piel animal": {"path": "", "frac_y": 0.94, "size": 0.09, "yaw": 0.0, "seat_height": 0.56},
	"Casco militar": {"path": GameConst.MILITARY_HELMET_MODEL, "frac_y": 0.96, "size": 0.16, "yaw": 0.0, "align": "bottom", "forward": -0.02},
	"Guantes de trabajo": {"path": GameConst.GARDEN_GLOVES_MODEL, "frac_y": 0.45, "size": 0.09, "yaw": 0.0, "forward": 0.2},
}
const SOLDADO_MODEL := "res://assets/characters/adapted/soldado_parts.glb"
const MilitaryJackets = preload("res://scripts/MilitaryJackets.gd")
const AutumnClothes = preload("res://scripts/AutumnClothes.gd")

# Survival garments that are skinned to the Mixamo rig inside GameConst.PLAYER_MODEL.
# item_name -> mesh node to show + Mixamo default meshes to hide while worn.
const SURVIVAL_CLOTHING := {
	"Chaqueta de piel": {"mesh": "field_jacket_olive", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"], "tint": Color(0.28, 0.19, 0.11)},
	"Pantalones de piel": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "tint": Color(0.28, 0.19, 0.11)},
	"Chaqueta de campaña verde": {"mesh": "field_jacket_olive", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"]},
	"Chaqueta de campaña azul": {"mesh": "field_jacket_navy", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"]},
	"Chaqueta de campaña arena": {"mesh": "field_jacket_sand", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"]},
	"Guantes survival": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": []},
	"Botas survival": {"mesh": "cloth_feet", "hides": ["Shoes"], "skin_hides": ["Desnudo_feet"], "body_hides": ["Body_feet"], "tint": Color(0.05, 0.05, 0.05)},
	"Botas de piel": {"mesh": "cloth_feet", "hides": ["Shoes"], "skin_hides": ["Desnudo_feet"], "body_hides": ["Body_feet"], "tint": Color(0.35, 0.24, 0.13)},
	"Guantes de piel": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": [], "tint": Color(0.32, 0.22, 0.13)},
	"Botas militares": {"mesh": "military_boots", "hides": ["Shoes"], "skin_hides": ["Desnudo_feet"], "body_hides": ["Body_feet"], "tint": Color(0.10, 0.10, 0.075)},
	"Pantalones militares": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"]},
	"Guantes militares": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": []},
	"Pantalones militares azules": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "tint": Color(0.02, 0.04, 0.08)},
	"Pantalones militares negros II": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "tint": Color(0.02, 0.02, 0.03)},
	"Pantalones camuflaje": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "camo": Color(0.18, 0.22, 0.13)},
	"Pantalones camuflaje desert": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "camo": Color(0.32, 0.28, 0.16)},
	# Military jackets reuse the soldier_torso mesh (long sleeves cover the arms);
	# body_shows keeps Body_torso visible so the neck doesn't leave a hole.
	"Chaqueta militar": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"], "body_shows": ["Body_torso"], "camo": Color(0.18, 0.22, 0.13)},
	"Chaqueta militar azul": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"], "body_shows": ["Body_torso"], "tint": Color(0.02, 0.04, 0.08)},
	"Chaqueta militar negra II": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"], "body_shows": ["Body_torso"], "tint": Color(0.02, 0.02, 0.03)},
	"Chaqueta camuflaje": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"], "body_shows": ["Body_torso"], "camo": Color(0.18, 0.22, 0.13)},
	"Chaqueta camuflaje desert": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms"], "body_shows": ["Body_torso"], "camo": Color(0.32, 0.28, 0.16)},
	# Skinned Sketchfab garments adapted in Blender (adapt_new_gear.py).
	"Chaqueta de cuadros": {"mesh": "field_jacket_plaid", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms", "Body_torso"]},
	"Chaqueta de otoño": {"mesh": "autumn_jacket", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms", "Body_torso"]},
	"Chaqueta militar digital": {"mesh": "digital_field_jacket", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_arms", "Body_torso"]},
	"Pantalones de senderismo": {"mesh": "autumn_pants", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"]},
	"Pantalones cargo con rodilleras": {"mesh": "cargo_kneepad_pants", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"]},
	"Botas de montaña": {"mesh": "autumn_boots", "hides": ["Shoes"], "skin_hides": ["Desnudo_feet"], "body_hides": ["Body_feet"]},
	"Gorra militar": {"mesh": "autumn_hat", "hides": [], "skin_hides": [], "body_hides": []},
	"Gorro de otoño": {"mesh": "autumn_hat", "hides": [], "skin_hides": [], "body_hides": []},
	# Plate carrier is worn over the clothes: it hides nothing, only overlays.
	"Chaleco táctico": {"mesh": "field_jacket_plate_carrier", "hides": [], "skin_hides": [], "body_hides": []},
}

# Maps clothing slot to possible mesh names in custom character models.
# Any clothing item equipped in a slot will show the corresponding mesh.
const CUSTOM_SLOT_MESHES := {
	"torso": ["Tops", "Ch42_Shirt"],
	"legs": ["Bottoms", "Ch42_Shorts"],
	"feet": ["Shoes", "Ch42_Sneakers"],
	"hands": [],
}

const CUSTOM_BODY_MESHES := ["Body", "Ch42_Body1"]

const DEFAULT_CLOTHING := {
	"Camiseta": "Tops",
	"Pantalones": "Bottoms",
	"Zapatillas": "Shoes",
}

const DEFAULT_SKIN_HIDES := {
	"Chaqueta de piel": ["Desnudo_torso", "Desnudo_arms"],
	"Pantalones de piel": ["Desnudo_legs"],
	"Botas de piel": ["Desnudo_feet"],
	"Guantes de piel": ["Desnudo_hands"],
	"Chaqueta de campaña verde": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta de campaña azul": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta de campaña arena": ["Desnudo_torso", "Desnudo_arms"],
	"Camiseta": ["Desnudo_torso"],
	"Pantalones": ["Desnudo_legs"],
	"Zapatillas": ["Desnudo_feet"],
	"Pantalones militares": ["Desnudo_legs"],
	"Pantalones militares azules": ["Desnudo_legs"],
	"Pantalones militares negros II": ["Desnudo_legs"],
	"Pantalones camuflaje": ["Desnudo_legs"],
	"Pantalones camuflaje desert": ["Desnudo_legs"],
	"Guantes survival": ["Desnudo_hands"],
	"Guantes militares": ["Desnudo_hands"],
	"Botas survival": ["Desnudo_feet"],
	"Botas militares": ["Desnudo_feet"],
	"Chaqueta militar": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta militar azul": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta militar negra II": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta camuflaje": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta camuflaje desert": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta de cuadros": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta de otoño": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta militar digital": ["Desnudo_torso", "Desnudo_arms"],
	"Pantalones de senderismo": ["Desnudo_legs"],
	"Pantalones cargo con rodilleras": ["Desnudo_legs"],
	"Botas de montaña": ["Desnudo_feet"],
	"Chaleco táctico": [],
}

const DEFAULT_BODY_HIDES := {
	"Chaqueta de piel": ["Body_arms"],
	"Pantalones de piel": ["Body_legs"],
	"Botas de piel": ["Body_feet"],
	"Chaqueta de campaña verde": ["Body_arms"],
	"Chaqueta de campaña azul": ["Body_arms"],
	"Chaqueta de campaña arena": ["Body_arms"],
	"Chaqueta de cuadros": ["Body_arms"],
	"Chaqueta de otoño": ["Body_arms", "Body_torso"],
	"Chaqueta militar digital": ["Body_arms", "Body_torso"],
	"Pantalones de senderismo": ["Body_legs"],
	"Pantalones cargo con rodilleras": ["Body_legs"],
	"Botas de montaña": ["Body_feet"],
	"Camiseta": [],
	"Pantalones": [],
	"Zapatillas": ["Body_feet"],
}

# Map of body zones covered by each clothing item.
# Used for debug messages and to know which body regions to restore on unequip.
const CLOTHING_COVERED_ZONES := {
	"Chaqueta de piel": ["torso", "brazos"],
	"Pantalones de piel": ["cadera", "piernas"],
	"Botas de piel": ["pies"],
	"Guantes de piel": ["manos"],
	"Chaqueta de campaña verde": ["torso", "brazos"],
	"Chaqueta de campaña azul": ["torso", "brazos"],
	"Chaqueta de campaña arena": ["torso", "brazos"],
	"Camiseta": ["torso"],
	"Pantalones": ["cadera", "piernas"],
	"Zapatillas": ["pies"],
	"Pantalones militares": ["cadera", "piernas"],
	"Pantalones militares azules": ["cadera", "piernas"],
	"Pantalones militares negros II": ["cadera", "piernas"],
	"Pantalones camuflaje": ["cadera", "piernas"],
	"Pantalones camuflaje desert": ["cadera", "piernas"],
	"Chaqueta militar": ["torso", "brazos"],
	"Chaqueta militar azul": ["torso", "brazos"],
	"Chaqueta militar negra II": ["torso", "brazos"],
	"Chaqueta camuflaje": ["torso", "brazos"],
	"Chaqueta camuflaje desert": ["torso", "brazos"],
	"Guantes survival": ["manos"],
	"Guantes militares": ["manos"],
	"Botas survival": ["pies"],
	"Botas militares": ["pies"],
	"Guantes de trabajo": ["manos"],
	"Sombrero de pescador": ["cabeza"],
	"Pasamontañas": ["cabeza"],
	"Pasamontañas navideño": ["cabeza"],
	"Gorro de piel": ["cabeza"],
	"Tocado de piel animal": ["cabeza"],
	"Casco militar": ["cabeza"],
	"Chaqueta de cuadros": ["torso", "brazos"],
	"Chaqueta de otoño": ["torso", "brazos"],
	"Chaqueta militar digital": ["torso", "brazos"],
	"Pantalones de senderismo": ["cadera", "piernas"],
	"Pantalones cargo con rodilleras": ["cadera", "piernas"],
	"Botas de montaña": ["pies"],
	"Gorra militar": ["cabeza"],
	"Gorro de otoño": ["cabeza"],
	"Chaleco táctico": ["torso"],
}

# Maps each clothing item to a body slot for exchange logic.
const CLOTHING_SLOTS := {
	"Chaqueta de piel": "torso",
	"Pantalones de piel": "legs",
	"Botas de piel": "feet",
	"Guantes de piel": "hands",
	"Chaqueta de campaña verde": "torso",
	"Chaqueta de campaña azul": "torso",
	"Chaqueta de campaña arena": "torso",
	"Camiseta": "torso",
	"Pantalones": "legs",
	"Zapatillas": "feet",
	"Guantes survival": "hands",
	"Botas survival": "feet",
	"Botas militares": "feet",
	"Pantalones militares": "legs",
	"Guantes militares": "hands",
	"Pantalones militares azules": "legs",
	"Pantalones militares negros II": "legs",
	"Pantalones camuflaje": "legs",
	"Pantalones camuflaje desert": "legs",
	"Chaqueta militar": "torso",
	"Chaqueta militar azul": "torso",
	"Chaqueta militar negra II": "torso",
	"Chaqueta camuflaje": "torso",
	"Chaqueta camuflaje desert": "torso",
	"Guantes de trabajo": "hands",
	"Sombrero de pescador": "head",
	# Balaclavas ride in their own face slot so they can be worn under any hat.
	"Pasamontañas": "face",
	"Pasamontañas navideño": "face",
	"Gorro de piel": "head",
	"Tocado de piel animal": "head",
	"Casco militar": "head",
	"Chaqueta de cuadros": "torso",
	"Chaqueta de otoño": "torso",
	"Chaqueta militar digital": "torso",
	"Pantalones de senderismo": "legs",
	"Pantalones cargo con rodilleras": "legs",
	"Botas de montaña": "feet",
	"Gorra militar": "head",
	"Gorro de otoño": "head",
	# The plate carrier rides over the clothing in its own vest slot.
	"Chaleco táctico": "chaleco",
}

# Warmth value per clothing item. Higher = warmer.
# Short sleeves / shorts give little warmth; jackets and long pants give more.
const CLOTHING_WARMTH := {
	"Chaqueta de piel": 0.85,
	"Pantalones de piel": 0.55,
	"Botas de piel": 0.48,
	"Guantes de piel": 0.28,
	"Chaqueta de campaña verde": 0.32,
	"Chaqueta de campaña azul": 0.32,
	"Chaqueta de campaña arena": 0.32,
	"Camiseta": 0.05,
	"Pantalones": 0.08,
	"Zapatillas": 0.05,
	"Guantes survival": 0.08,
	"Botas survival": 0.18,
	"Botas militares": 0.24,
	"Pantalones militares": 0.26,
	"Pantalones militares azules": 0.26,
	"Pantalones militares negros II": 0.26,
	"Pantalones camuflaje": 0.26,
	"Pantalones camuflaje desert": 0.22,
	"Chaqueta militar": 0.38,
	"Chaqueta militar azul": 0.38,
	"Chaqueta militar negra II": 0.38,
	"Chaqueta camuflaje": 0.38,
	"Chaqueta camuflaje desert": 0.34,
	"Guantes militares": 0.12,
	"Guantes de trabajo": 0.08,
	"Sombrero de pescador": 0.07,
	"Pasamontañas": 0.34,
	"Pasamontañas navideño": 0.34,
	"Gorro de piel": 0.38,
	"Tocado de piel animal": 0.45,
	"Casco militar": 0.05,
	"Chaqueta de cuadros": 0.45,
	"Chaqueta de otoño": 0.42,
	"Chaqueta militar digital": 0.42,
	"Pantalones de senderismo": 0.22,
	"Pantalones cargo con rodilleras": 0.22,
	"Botas de montaña": 0.20,
	"Gorra militar": 0.08,
	"Gorro de otoño": 0.08,
	"Chaleco táctico": 0.10,
}

# Heat protection: reduces body temperature gain in hot environments.
# Hats and headwear shield from the sun; other clothing has no heat protection.
const CLOTHING_HEAT_PROTECTION := {
	"Gorro de piel": 0.20,
	"Tocado de piel animal": 0.20,
	"Pasamontañas": 0.12,
	"Pasamontañas navideño": 0.12,
	"Sombrero de pescador": 0.35,
	"Gorra militar": 0.28,
	"Casco militar": 0.30,
}

# Heat retention: how much body heat is retained in hot environments.
# Heavy clothing retains heat (bad in hot weather); light/short items ventilate (good in hot weather).
# 0.0 = neutral, positive = retains heat, negative = ventilates (cools down).
const CLOTHING_HEAT_RETENTION := {
	"Chaqueta de piel": 0.45,
	"Pantalones de piel": 0.24,
	"Botas de piel": 0.20,
	"Guantes de piel": 0.14,
	"Gorro de piel": 0.18,
	"Tocado de piel animal": 0.22,
	"Pasamontañas": 0.16,
	"Pasamontañas navideño": 0.16,
	"Chaqueta de campaña verde": 0.26,
	"Chaqueta de campaña azul": 0.26,
	"Chaqueta de campaña arena": 0.26,
	"Camiseta": 0.04,
	"Pantalones": 0.06,
	"Zapatillas": 0.03,
	"Guantes survival": 0.05,
	"Botas survival": 0.10,
	"Botas militares": 0.14,
	"Pantalones militares": 0.30,
	"Pantalones militares azules": 0.30,
	"Pantalones militares negros II": 0.30,
	"Pantalones camuflaje": 0.30,
	"Pantalones camuflaje desert": 0.18,
	"Chaqueta militar": 0.36,
	"Chaqueta militar azul": 0.36,
	"Chaqueta militar negra II": 0.36,
	"Chaqueta camuflaje": 0.36,
	"Chaqueta camuflaje desert": 0.24,
	"Guantes militares": 0.10,
	"Guantes de trabajo": 0.05,
	"Sombrero de pescador": 0.0,
	"Gorra militar": 0.02,
	"Gorro de otoño": 0.10,
	"Casco militar": 0.06,
	"Chaqueta de cuadros": 0.36,
	"Chaqueta de otoño": 0.34,
	"Chaqueta militar digital": 0.34,
	"Pantalones de senderismo": 0.20,
	"Pantalones cargo con rodilleras": 0.20,
	"Botas de montaña": 0.14,
	"Chaleco táctico": 0.15,
}

const THIRD_PERSON_MODEL_CANDIDATES := [
	GameConst.PLAYER_MODEL,
	"res://assets/animations/inicio.glb",
	"res://assets/animations/walking.glb",
	GameConst.NPC_HOSTILE_MODEL
]
const THIRD_PERSON_ANIMATION_LIBRARY := preload("res://assets/animations/third_person_animations.res")
const REAL_RIFLE_MODEL := "res://assets/models/weapons/modern_sniper_rifle__free_lowpoly.glb"
const RIFLE_RANGE := 600.0
const RIFLE_MUZZLE_SPEED := 750.0
const SCOPE_MAGNIFICATIONS := [4.0, 8.0, 12.0, 16.0]
var _scope_zoom_index := 0
const RIFLE_NAME := "Rifle francotirador"
const RIFLE_AMMO_TYPE := "7.62x54mm"
const RIFLE_MAG_SIZE := 5
const RIFLE_DAMAGE := 260.0
const RIFLE_MAGAZINE_MODEL := "res://assets/models/weapons/rifle_magazine.glb"
# Fusil de asalto M4 — mismo item_type "weapon_rifle" pero semiautomatico,
# mira fija 4x y municion 5.56 propia. El GLB Sketchfab mide ~0.184 m en
# escena (nodo .fbx con escala 0.01) frente a las ~18 unidades del
# francotirador, asi que su weapon_scale y toda su geometria de agarre van
# en el espacio de ese modelo (0.01 x las unidades crudas del mesh).
const M4_NAME := "Fusil de asalto"
const M4_MODEL := "res://assets/models/weapons/m4_carbine_rifle.glb"
const M4_MAGAZINE_MODEL := "res://assets/models/weapons/m4_magazine.glb"
const M4_SHOOT_SOUND := "res://assets/audio/m4_disparo.mp3"
const M4_AMMO_TYPE := "5,56 × 45 mm NATO"
const M4_MAG_SIZE := 30
const M4_BURST_ROUNDS := 3
const M4_DAMAGE := 95.0
const M4_PVP_HEAD := 60.0
const M4_PVP_BODY := 28.0
const M4_COOLDOWN := 0.27
const M4_MUZZLE_SPEED := 880.0
const M4_SPREAD_MULT := 2.2
const M4_RECOIL := 4.5
const M4_ENERGY_COST := 1.2
const M4_SCALE_FACTOR := 82.0
const M4_SCOPE_MAGNIFICATIONS := [1.35]
const THIRD_PERSON_EXTERNAL_RUN_ANIMATION := "RunExternal"
const THIRD_PERSON_EXTERNAL_IDLE_ANIMATION := "IdleExternal"
const THIRD_PERSON_EXTERNAL_WALK_ANIMATION := "WalkExternal"
const THIRD_PERSON_EXTERNAL_SNEAK_ANIMATION := "SneakExternal"
const THIRD_PERSON_EXTERNAL_SNEAK_WALK_ANIMATION := "SneakWalkExternal"
const THIRD_PERSON_EXTERNAL_LEFT_TURN_ANIMATION := "LeftTurnExternal"
const THIRD_PERSON_EXTERNAL_RIGHT_TURN_ANIMATION := "RightTurnExternal"
const THIRD_PERSON_EXTERNAL_PLANT_ANIMATION := "PlantExternal"
const THIRD_PERSON_EXTERNAL_GATHER_ANIMATION := "GatherExternal"
const THIRD_PERSON_EXTERNAL_FISH_ANIMATION := "FishExternal"
const THIRD_PERSON_EXTERNAL_INTERACT_ANIMATION := "InteractExternal"
# GatherExternal's kneel-and-grab lands at ~5.1s of a 7.1s clip — actions start
# here so the gesture reads inside a short action window. The offset is a
# property of the clip, so local playback and remote puppets stay consistent.
const THIRD_PERSON_GATHER_ANIM_OFFSET := 4.2
# InteractExternal (talking gesture) is only a fallback clip — its forward
# bend sits at ~2.6s of a 4.7s clip.
const THIRD_PERSON_INTERACT_ANIM_OFFSET := 1.55
const THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION := "AttackExternal"
const THIRD_PERSON_EXTERNAL_PUNCH_ANIMATION := "PunchExternal"
const THIRD_PERSON_EXTERNAL_MELEE_DEATH_ANIMATION := "MeleeDeathExternal"
const THIRD_PERSON_EXTERNAL_HIT_ANIMATION := "HitExternal"
const THIRD_PERSON_EXTERNAL_SHOT_ANIMATION := "ShotReceivedExternal"
const THIRD_PERSON_EXTERNAL_GIVE_ANIMATION := "GiveFoodExternal"
const THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION := "LowHealthExternal"
const THIRD_PERSON_EXTERNAL_DYING_ANIMATION := "DyingExternal"
const THIRD_PERSON_EXTERNAL_JUMP_ANIMATION := "JumpExternal"
const THIRD_PERSON_EXTERNAL_JUMP_DOWN_ANIMATION := "JumpDownExternal"
const THIRD_PERSON_EXTERNAL_SLEEP_ANIMATION := "SleepExternal"
const THIRD_PERSON_EXTERNAL_SIT_ANIMATION := "SitExternal"
const THIRD_PERSON_EXTERNAL_DRINK_ANIMATION := "DrinkExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_FIRE_ANIMATION := "RifleFireExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_LEFT_TURN_ANIMATION := "RifleLeftTurnExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_RIGHT_TURN_ANIMATION := "RifleRightTurnExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_IDLE_ANIMATION := "RifleIdleExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_AIM_IDLE_ANIMATION := "RifleAimIdleExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_WALK_ANIMATION := "RifleWalkExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_RUN_ANIMATION := "RifleRunExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_SIT_ANIMATION := "RifleSitExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_PRONE_ANIMATION := "RifleProneExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_GETUP_ANIMATION := "RifleGetupExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_SIT_FIRE_ANIMATION := "RifleSitFireExternal"
const THIRD_PERSON_EXTERNAL_RIFLE_PRONE_FIRE_ANIMATION := "RifleProneFireExternal"
const THIRD_PERSON_EXTERNAL_TORCH_IDLE_ANIMATION := "TorchIdleExternal"
const THIRD_PERSON_EXTERNAL_TORCH_WALK_ANIMATION := "TorchWalkExternal"
const THIRD_PERSON_EXTERNAL_TORCH_RUN_ANIMATION := "TorchRunExternal"
const THIRD_PERSON_EXTERNAL_TORCH_TURN_LEFT_ANIMATION := "TorchTurnLeftExternal"
const THIRD_PERSON_EXTERNAL_TORCH_TURN_RIGHT_ANIMATION := "TorchTurnRightExternal"
const THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_LEFT_ANIMATION := "TorchCrouchTurnLeftExternal"
const THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_RIGHT_ANIMATION := "TorchCrouchTurnRightExternal"
const THIRD_PERSON_EXTERNAL_TORCH_CROUCH_IDLE_ANIMATION := "TorchCrouchIdleExternal"
const THIRD_PERSON_EXTERNAL_TORCH_CROUCH_WALK_ANIMATION := "TorchCrouchWalkExternal"
const TORCH_IDLE_FBX := "res://assets/animations/Standing Torch Idle 01.glb"
const TORCH_WALK_FBX := "res://assets/animations/Standing Torch Walk Forward.glb"
const TORCH_RUN_FBX := "res://assets/animations/Standing Torch Run Forward.glb"
const TORCH_TURN_LEFT_FBX := "res://assets/animations/Standing Torch Turn Left 90.glb"
const TORCH_TURN_RIGHT_FBX := "res://assets/animations/Standing Torch Turn Right 90.glb"
const TORCH_CROUCH_TURN_LEFT_FBX := "res://assets/animations/Crouch Torch Turn Left 90.glb"
const TORCH_CROUCH_TURN_RIGHT_FBX := "res://assets/animations/Crouch Torch Turn Right 90.glb"
const TORCH_CROUCH_IDLE_FBX := "res://assets/animations/Crouch Torch Idle 01.glb"
const TORCH_CROUCH_WALK_FBX := "res://assets/animations/Crouch Torch Walk Forward.glb"
const DRINK_ANIMATION_GLB := "res://assets/animations/Drinking.glb"
const PUNCH_ANIMATION_GLB := "res://assets/animations/Cross Punch.glb"
const MELEE_DEATH_ANIMATION_GLB := "res://assets/animations/Standing Death Forward 02.glb"
const HIT_ANIMATION_GLB := "res://assets/animations/Head Hit.glb"
const SHOT_ANIMATION_GLB := "res://assets/animations/RecibirDisparo.glb"
const GIVE_FOOD_ANIMATION_GLB := "res://assets/animations/GiveFood.glb"
const BOW_SHOOT_ANIMATION_GLB := "res://assets/animations/BowShoot.glb"
const BOW_AIM_IDLE_ANIMATION_GLB := "res://assets/animations/BowAimIdle.glb"
const BOW_AIM_WALK_ANIMATION_GLB := "res://assets/animations/BowAimWalk.glb"
const THIRD_PERSON_EXTERNAL_BOW_SHOOT_ANIMATION := "BowShootExternal"
const THIRD_PERSON_EXTERNAL_BOW_AIM_IDLE_ANIMATION := "BowAimIdleExternal"
const THIRD_PERSON_EXTERNAL_BOW_AIM_WALK_ANIMATION := "BowAimWalkExternal"
const WOODEN_BOW_MODEL := "res://assets/models/weapons/wooden_bow.glb"
const REINFORCED_BOW_MODEL := "res://assets/models/weapons/reinforced_bow.glb"
const ARROW_WOOD_MODEL := "res://assets/models/weapons/arrow_wood.glb"
const ARROW_STONE_MODEL := "res://assets/models/weapons/arrow_stone.glb"
const ARROW_BONE_MODEL := "res://assets/models/weapons/arrow_bone.glb"
const ROPE_COIL_MODEL := "res://assets/models/props/rope_coil.glb"
const ANIMAL_BONE_MODEL := "res://assets/models/props/animal_bone.glb"
const ANIMAL_SINEW_MODEL := "res://assets/models/props/animal_sinew.glb"
# Swing timers: the clip's contact frame, and the lead so the whoosh peaks
# just before impact instead of firing at click time.
const MELEE_PUNCH_IMPACT_DELAY := 0.95
const MELEE_SWING_IMPACT_DELAY := 0.45
const MELEE_SWING_SOUND_LEAD := 0.25
const ROD_FISH_START_GLB := "res://assets/animations/inicio_pesca_2.glb"
const ROD_WALK_GLB := ""
const ROD_CAST_GLB := ""
const ROD_IDLE_GLB := "res://assets/animations/fishing_idle_rod_line.glb"
const ROD_FISH_END_GLB := "res://assets/animations/fishing_end_catch.glb"
const FISHING_IDLE_DURATION := 10.0
const ROD_MODEL_PATH := "res://assets/models/props/cana_de_pescar.glb"
const NORMAL_FISHING_ROD_GRIP_CORRECTION := Vector3(-0.058, 0.051, -0.100)
const THIRD_PERSON_EXTERNAL_ROD_WALK_ANIMATION := "RodWalkExternal"
const THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION := "RodCastExternal"
const THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION := "RodIdleExternal"
const THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION := "RodFishStartExternal"
const THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION := "RodFishEndExternal"
const THIRD_PERSON_CAMERA_POS := Vector3(0.0, 2.8, 6.5)
const THIRD_PERSON_DEFAULT_SCALE := 1.55
const MIXAMO_CHARACTER_SCALE := 0.72
const MIXAMO_GROUND_CORRECTION := 0.38
const BASE_CARRY_SLOTS := 3
const BASE_CARRY_WEIGHT := 5.0
const TORSO_CARRY_SLOTS := 2
const TORSO_CARRY_WEIGHT := 2.0
const LEGS_CARRY_SLOTS := 2
const LEGS_CARRY_WEIGHT := 2.0
# Descalzo: heridas en los pies por caminar/correr sin calzado
const FEET_WOUND_THRESHOLD := 15.0   # a partir de aqui las heridas duelen y drenan salud
const FEET_WOUND_WALK_RATE := 0.9    # gravedad por segundo caminando descalzo
const FEET_WOUND_RUN_RATE := 5.5     # gravedad por segundo corriendo descalzo
const FEET_DPS_WALK := 0.14          # hp/s con heridas, caminando descalzo
const FEET_DPS_RUN := 0.9            # hp/s con heridas, corriendo descalzo
const FEET_COLD_AMBIENT := 14.0      # bajo esta temperatura ambiente los pies descalzos enfrian
const HEAD_CARRY_SLOTS := 0
const HEAD_CARRY_WEIGHT := 0.0
const SMALL_BACKPACK_SLOTS := 8
const SMALL_BACKPACK_WEIGHT := 10.0
# Plate carriers add magazine/utility pouches on top of the clothes below.
const VEST_CARRY_SLOTS := 4
const VEST_CARRY_WEIGHT := 4.0
# The military rucksack is bigger than the civilian small backpack.
const MILITARY_BACKPACK_SLOTS := 20
const MILITARY_BACKPACK_WEIGHT := 25.0

signal prompt_changed(text: String)
signal notice(text: String)
signal item_dropped(item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3, color: Color, broken: bool, spoilage: float)

@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.0
@export var jump_force := 5.0
@export var sprint_jump_force := 9.0
@export var mouse_sensitivity := 0.0025
@export var interaction_distance := 3.5
@export var jump_stamina_cost := 15.0
@export var min_jump_stamina := 10.0

static var _model_cache: Dictionary = {}
var stats
var inventory
var equipment
var hands
var camera: Camera3D
var _camera_fov := 85.0
var audio_listener: AudioListener3D
var raycast
var flashlight: SpotLight3D
var torch_light: OmniLight3D
var body_mesh: MeshInstance3D
var _collision_shape: CollisionShape3D
var third_person_model: Node3D
var _full_body_mesh: MeshInstance3D = null
var _head_mesh: MeshInstance3D = null
var _body_no_head_mesh: MeshInstance3D = null
var third_person_hand_item_root: Node3D
var third_person_back_item_root: Node3D
var _torch_hand_root: Node3D
var _drink_hand_root: Node3D
var _left_hand_bone_idx: int = -1
var _drink_bone_idx: int = -1
var _spine_skeleton: Skeleton3D = null
var _spine_bone_idx: int = -1
var _hand_skeleton: Skeleton3D = null
var _hand_bone_idx: int = -1
var _head_skeleton: Skeleton3D = null
var _head_bone_idx: int = -1
var _backpack_rest_pos: Vector3 = Vector3(0.0, -0.05, -0.18)
var _backpack_rest_basis_inverse := Basis.IDENTITY
var third_person_left_arm: Node3D
var third_person_right_arm: Node3D
var third_person_left_leg: Node3D
var third_person_right_leg: Node3D
var third_person_animation_player: AnimationPlayer
var third_person_idle_animation := ""
var third_person_walk_animation := ""
var third_person_stairs_animation := ""
var _stairs_last_position := Vector3.ZERO
var _stairs_position_valid := false
var _stairs_grace := 0.0
var third_person_run_animation := ""
var third_person_sneak_animation := ""
var third_person_sneak_walk_animation := ""
var third_person_left_turn_animation := ""
var third_person_right_turn_animation := ""
var third_person_plant_animation := ""
var third_person_gather_animation := ""
var third_person_fish_animation := ""
var third_person_interact_animation := ""
var third_person_attack_animation := ""
var third_person_punch_animation := ""
var third_person_melee_death_animation := ""
var third_person_hit_animation := ""
var third_person_shot_animation := ""
var third_person_give_animation := ""
var third_person_low_health_animation := ""
var third_person_dying_animation := ""
var third_person_jump_animation := ""
var third_person_jump_down_animation := ""
var third_person_sleep_animation := ""
var third_person_sit_animation := ""
var third_person_drink_animation := ""
var is_sleeping := false
var is_sleeping_on_bed := false
var _saved_collision_mask := 0xFFFFFFFF
var _bed_sleep_position := Vector3.ZERO
var is_sitting := false
var rowing_boat: Node3D
var _boat_local_offset := Vector2.ZERO
var _boat_standing := false
var _rowing_model_transform := Transform3D.IDENTITY
var _rowing_camera_transform := Transform3D.IDENTITY
var _rowing_view_yaw := 0.0
var _rowing_view_height := 3.5
var _rowing_view_dist := 7.0
var _rowing_animation := "rowing/Stroke"
var _boat_prompt_shown := ""
var _boat_prompt_timer := 0.0
const BOAT_PROMPT_SECONDS := 5.0
var is_prone := false
var _sit_cooldown := 0.0
var _auto_sleep_triggered := false
var _clothing_wear_timer := 0.0
var _is_falling_from_height := false
var _fall_height := 0.0
var _max_fall_height := 0.0
const FALL_SAFE_HEIGHT := 3.0
const FALL_DAMAGE_SCALE := 9.0
const FALL_WATER_FACTOR := 0.3
var third_person_ground_offset := 0.0
var third_person_has_real_idle := false
var _pain_audio_player = null
var _shoot_audio_player = null
var _swing_audio_player = null
var _impact_audio_player = null
var _shot_audio_player = null
var _fall_audio_player = null
var _unwell_audio_player = null
var _pain_sound_timer := 0.0
var _critical_sound_timer := 0.0
var _was_critical := false
var third_person_loaded_path := ""
var third_person_action_animation := ""
var third_person_action_timer := 0.0
var third_person_action_start_offset := 0.0
var _attack_cooldown := 0.0
var _is_aiming := false
var _scope_overlay: Control = null
var _rifle_model_node: Node3D = null
var _shoot_cooldown := 0.0
var _rifle_fire_animation := ""
var _rifle_left_turn_animation := ""
var _rifle_right_turn_animation := ""
var _rifle_idle_animation := ""
var _rifle_aim_idle_animation := ""
var _rifle_walk_animation := ""
var _rifle_run_animation := ""
var _rifle_sit_animation := ""
var _rifle_prone_animation := ""
var _rifle_getup_animation := ""
var _rifle_sit_fire_animation := ""
var _rifle_prone_fire_animation := ""
var _bow_shoot_animation := ""
var _bow_aim_idle_animation := ""
var _bow_aim_walk_animation := ""
var _torch_idle_animation := ""
var _torch_walk_animation := ""
var _torch_run_animation := ""
var _torch_turn_left_animation := ""
var _torch_turn_right_animation := ""
var _torch_crouch_turn_left_animation := ""
var _torch_crouch_turn_right_animation := ""
var _torch_crouch_idle_animation := ""
var _torch_crouch_walk_animation := ""
var _torch_animations_loaded := false
var _drink_animation_loaded := false
var _drink_animation_length := 2.0
var _punch_animation_loaded := false
var _melee_death_animation_loaded := false
var _hit_animation_loaded := false
var _shot_animation_loaded := false
var _give_animation_loaded := false
var _was_sick := false
var _beaten_death := false
var _torch_in_hands := false
var _has_fishing_rod := false
var _rod_walk_animation := ""
var _rod_cast_animation := ""
var _rod_idle_animation := ""
var _rod_fish_start_animation := ""
var _rod_fish_end_animation := ""
var _rod_animations_loaded := false
var _rod_animations_loading := false
var _rod_animations_pending: Array = []
var _rod_animations_deferred := false
var _is_fishing_idle := false
var _is_fishing := false
var _interact_busy := false  # bloquea interacciones con await en curso
var _throw_charging := false
var _throw_charge_time := 0.0
var _throw_anim_frozen := false
const THROW_MAX_CHARGE_TIME := 1.2
# Lanzado apuntado (lanzas/bolas): mismo gesto que el lanzado con G — el
# wind-up de AttackExternal se congela mientras se apunta y el proyectil
# sale cuando el brazo llega al punto de suelta.
var _throw_aim_hold := false
var _throw_aim_frozen := false
var _throw_release_item = null
var _throw_release_timer := 0.0
var _throw_release_revision := -1
var _throw_release_target := Vector3.ZERO
# AttackExternal swings forward at 0.82s, after its 0.40s wind-up.
const THROW_RELEASE_DELAY := 0.42
const BOW_RELEASE_DELAY := 22.0 / 30.0
const BOW_SHOT_DURATION := 1.2
var _bow_release_item = null
var _bow_release_timer := 0.0
var _bow_release_revision := -1
var _aim_pitch_saved_rotations: Dictionary = {}
var _applying_aim_pitch := false
const THROW_ANIM_FREEZE_TIME := 0.4
const THROW_MIN_FORCE := 4.0
const THROW_MAX_FORCE := 22.0
const THROW_GRAVITY := 14.0
# F mantenido: guardar al inventario; G mantenido: tirar lejos
var _f_holding := false
var _f_hold_time := 0.0
var _f_hold_triggered := false
var _g_holding := false
var _g_hold_time := 0.0
const HOLD_THRESHOLD := 0.3
var _can_fish_near_water := false
var _is_near_fishing_shore := false
var _fishing_water_cache_pos := Vector3.INF
var _fishing_water_cache := {"near": false, "facing": false, "point": Vector3.ZERO}
var _rod_socket_keyframes: Array = []
var _rod_base_position := Vector3.ZERO
var _rod_socket_active := false
var _rod_visual_overlays: Dictionary = {}
var _active_rod_visual_key := ""
var _active_rod_visual_root: Node3D = null
var _active_rod_visual_player: AnimationPlayer = null
var _active_rod_visual_animation := ""
var _rod_action_speed_scale := 1.0
var _normal_fishing_rod_source: Node3D = null
var _normal_fishing_rod_hand_transform := Transform3D.IDENTITY
var _normal_fishing_rod_pose_ready := false
var _has_rifle := false
var _rifle_in_hands := false
var _is_reloading := false
var _is_firing := false
var _fire_button_held := false
var _rifle_burst_revision := 0
var _held_selection_revision := 0
var _rifle_ammo_initialized := false
# Pool de municion propio del M4 (5.56) — independiente del 7.62 del
# francotirador para que cada fusil guarde sus balas por separado.
var _m4_magazine := 0
var _m4_reserve_ammo := 0
var _m4_ammo_initialized := false
# Geometria de agarre/apuntado del arma en mano, en unidades del propio
# modelo. Los valores por defecto son los del francotirador; al montar un
# M4 se cargan sus medidas (espacio 0.01 x unidades crudas, ya volteado).
var _rg_eye := RIFLE_AIM_EYE
var _rg_right_knuckle := RIFLE_AIM_RIGHT_KNUCKLE
var _rg_left_knuckle := RIFLE_AIM_LEFT_KNUCKLE
var _rg_left_thumb := Vector3(-0.55, 0.65, -1.7)
var _rg_right_grip := Vector3(0.5000, -0.5000, 1.2000)
var _rg_left_grip := Vector3(-1.5, -0.5, -3.8)
var _mounted_rifle_is_m4 := false
var _m4_saved_left_arm_poses: Array = []
var _fishing_session := 0
var _rifle_magazine := 0
var _rifle_reserve_ammo := 0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _recoil_recover_speed := 3.0
var _crosshair_bloom := 0.0   # dispersion extra en px tras cada disparo
var _wind_dir := Vector3(1.0, 0.0, 0.3).normalized()
var _wind_strength := 0.0
var _wind_target_strength := 0.0
var _wind_timer := 0.0
var _breath_timer := 0.0
var _breath_pitch_offset := 0.0
var _breath_yaw_offset := 0.0
const BREATH_HOLD_DURATION := 15.0
var _breath_shift_pressed := false
var _breath_hold_timer := 0.0
var _breath_hold_active := false
var _breath_hold_recover := 0.0
var _rifle_bone_attachment: BoneAttachment3D = null
var _rifle_weapon_offset: Node3D = null
var _rifle_root: Node3D = null
var _rifle_model: Node3D = null
var _rifle_on_back: Node3D = null
const BACK_SLOT_LEFT := 0
const BACK_SLOT_RIGHT := 1
var _stored_back_items: Array = [null, null]
var _stored_back_visuals: Array = [null, null]
var _rifle_on_back_strap: Node3D = null
var _strap_skeleton: Skeleton3D = null
var _strap_barrel_marker: Marker3D = null
var _strap_stock_marker: Marker3D = null
var _strap_guide_upper: BoneAttachment3D = null
var _strap_guide_lower: BoneAttachment3D = null
var _strap_upper_offset: Marker3D = null
var _strap_lower_offset: Marker3D = null
var _strap_prev_pts: PackedVector3Array = PackedVector3Array()
var _strap_initialized := false
var _rifle_strap_system: RefCounted = null
var _rifle_strap_update_accum := 0.0
var _rifle_right_grip: Marker3D = null
var _rifle_left_hand_grip: Marker3D = null
var _rifle_stock_ref: Marker3D = null
var _rifle_muzzle: Marker3D = null
var _rifle_stock_target: Marker3D = null
var _rifle_muzzle_target: Marker3D = null
var _rifle_shoulder_target: Marker3D = null
var _rifle_aim_target: Marker3D = null
var _rifle_solver_stable_count := 0
var _rifle_solver_ik_activated := false
var _rifle_left_elbow_pole: Marker3D = null
var _rifle_left_arm_ik: TwoBoneIK3D = null
var _rifle_right_arm_ik: TwoBoneIK3D = null
var _rifle_right_elbow_pole: Marker3D = null
var _rifle_cached_basis: Basis = Basis.IDENTITY
var _rifle_cached_rg_local: Vector3 = Vector3.ZERO
var _ik_skel: Skeleton3D = null
var _ik_lh_idx: int = -1
var _ik_skeleton_connected: bool = false
var _ik_upper_arm_idx: int = -1
var _ik_forearm_idx: int = -1
# Standing/crouched aim: the rifle is placed from the body (butt in the right
# shoulder pocket, scope line at the eye, barrel along the aim direction) and
# both arms are IK'd onto it. Points in RifleRoot/model-local units (barrel
# -Z, up +Y, right +X) measured from modern_sniper_rifle__free_lowpoly.glb.
const RIFLE_AIM_BUTT := Vector3(0.0, 0.4, 8.45)
const RIFLE_AIM_EYE := Vector3(0.0, 2.05, 4.31)
# Grip geometry (raycast against the rifle mesh): pistol grip right face at
# x≈0.26, front edge z≈3.3, back z≈4.0, y -0.2..-1.85, raked ~15° back;
# forend underside y≈0.25, sides x≈±0.4, z -6.4..-2.2.
# Knuckle = middle-finger MCP joint (MiddleFinger1 bone) target on the rifle.
const RIFLE_AIM_RIGHT_KNUCKLE := Vector3(0.40, -1.15, 3.5)
const RIFLE_AIM_LEFT_KNUCKLE := Vector3(0.70, 0.15, -1.45)
# Hand anatomy in rifle-local space (-Z barrel, +Y up, +X right):
# fingers = wrist→knuckles direction, palm = direction the palm faces.
# Right hand: knuckles stack down the grip's front-right edge, so fingers
# point down-forward-left across the grip's right face and curl around its
# front; palm presses the grip's right-back corner (faces left, down, back).
# Left hand: palm cupped under the forend, fingers up its right side.
const RIFLE_AIM_RIGHT_FINGERS := Vector3(0.0, -0.45, -0.89)
const RIFLE_AIM_RIGHT_PALM := Vector3(-0.95, -0.10, 0.22)
const RIFLE_AIM_LEFT_FINGERS := Vector3(0.95, 0.05, -0.15)
const RIFLE_AIM_LEFT_PALM := Vector3(0.10, 0.95, 0.15)
# Finger flexion in degrees per joint [1, 2, 3], replacing the animated finger
# pose. Kept ≤65° — sharper bends collapse the low-poly knuckle skinning.
const RIFLE_AIM_RIGHT_CURL := {
	"Thumb": [15.0, 25.0, 20.0], "Index": [30.0, 45.0, 25.0],
	"Middle": [60.0, 65.0, 35.0], "Ring": [62.0, 65.0, 35.0], "Pinky": [62.0, 60.0, 30.0],
}
# Support hand: curl around the forend, with the knuckles outside its
# right face and the fingertips turning over its upper edge.
const RIFLE_AIM_LEFT_CURL := {
	"Thumb": [18.0, 12.0, 8.0], "Index": [65.0, 65.0, 30.0],
	"Middle": [65.0, 65.0, 30.0], "Ring": [65.0, 65.0, 30.0], "Pinky": [65.0, 65.0, 30.0],
}
# Share of the hand twist absorbed by forearm roll, and how strongly the elbow
# is steered to line the forearm up with the hand.
const RIFLE_AIM_FOREARM_TWIST := 0.5
const RIFLE_AIM_FINGER_CLOSE := {"Index": 7.0, "Ring": 7.0, "Pinky": 14.0}
const RIFLE_AIM_ELBOW_STEER := 0.0
# Elbow pole directions in rifle-local space (out + down + slightly back), so
# the firing elbow doesn't flare above the shoulder in the front view.
const RIFLE_AIM_RIGHT_ELBOW := Vector3(0.55, -0.85, 0.20)
const RIFLE_AIM_LEFT_ELBOW := Vector3(-0.20, -1.0, 0.15)
const RIFLE_AIM_ELBOW_POLE := 1.0
var _rifle_aim_pose_active := false
var _ik_right_upper_arm_idx: int = -1
var _ik_right_forearm_idx: int = -1
var _ik_rh_idx: int = -1
# hand bone -> {"frame": rest anatomical frame (hand-local), "knuckle": MCP
# offset (hand-local), "fingers": [[bone, axis_local, rest_basis, deg], ...]}
var _grip_rig: Dictionary = {}
var _grip_rig_skel: Skeleton3D = null
var _grip_pivots_applied := false
var _rifle_has_cache: bool = false
var _rifle_current_ik_weight := 1.0
var _rifle_target_ik_weight := 1.0
var _last_rifle_animation_debug := ""
var _cached_exclude_rids: Array[RID] = []
var _cached_rids_dirty := true
var _cam_ray_exclude: Array[RID] = []
var _cam_ray_exclude_dirty := true
var _cam_collision_timer: float = 0.0
var _cached_cam_z: float = 0.0
var _interaction_prompt_timer := 0.0
var _stats_emit_timer := 0.0
var _ik_bone_cache: Dictionary = {}
# Cache del skeleton del modelo 3P para evitar búsquedas cada frame
var _anim_skel_cache: Skeleton3D = null
var _anim_skel_dirty := true
# Cache de materiales reutilizables para skin/ropa (evita new() cada equip/unequip)
var _skin_mat_cache: Dictionary = {}
# Throttle de bone transform update: solo forzar cuando cambia la animación
var _prev_anim_name := ""
var _bone_update_pending := false
# Alineación de RifleRoot (debug/calibración)
var _auto_align_enabled := false
var _auto_align_iteration := 0
var _auto_align_rifleidle_timer := 0.0
var _auto_align_converged := false
var _auto_align_samples: Array = []
# Medición de agarre mano derecha
var _rh_grip_measure_timer := 0.0
var _rh_grip_measure_samples: Array = []
var _rh_grip_last_dist := 0.0
var _rh_grip_logged := false
var _rifle_two_point_log_timer := 0.0
var _rifle_two_point_logged := false
var _root_align_enabled := false
var _root_align_step := 2.0
var _root_align_axis := 0
var _root_align_phase := 0
var _root_align_timer := 0.0
var _root_align_samples: Array = []
var _root_align_best_dist := 999.0
var _root_align_best_offset := Vector3.ZERO
var _root_align_converged := true
var _root_align_round := 0

@export_group("Rifle Placement")
@export var weapon_scale: float = 12.0
@export_range(0.0, 1.0) var left_hand_ik_weight := 1.0
@export var right_hand_bone_name := "mixamorig:RightHand"
@export_subgroup("WeaponOffset")
@export var weapon_offset_pos := Vector3(0.0, 0.0, 0.0) # rifle anchored via BoneAttachment3D; adjust RifleRoot local if needed
@export var weapon_offset_rot_deg := Vector3(0.0, 135.0, 0.0) # fixed orientation — do not change
@export var ik_enabled := false
@export_subgroup("RifleRoot Local")
@export var rifle_root_offset := Vector3.ZERO # unused: rifle is translated along the real barrel line

var _frontal_camera := false
var _side_camera := false
var _left_camera := false
var _rear_camera := false
var _top_camera := false
var _aerial_camera := false
var _aerial_pos := Vector3(0.0, 0.0, 0.0)
var _aerial_height := 600.0
const _AERIAL_MIN_HEIGHT := 100.0
const _AERIAL_MAX_HEIGHT := 1500.0
const _AERIAL_PAN_SPEED := 400.0
const _AERIAL_ZOOM_STEP := 100.0

var _crosshair_check_timer := 0.0
var is_jumping := false
var _jump_velocity := 0.0
var _jump_apex := false
var _jump_animation_timer := 0.0
var is_dead := false
var _death_anim_played := false
var death_pose_time := 0.0
var _puppet_death_remove_timer := 0.0
var _puppet_naked_pending := false
var _puppet_naked_timer := 0.0
var is_sprinting := false
var _sprint_double_tap := false
var _last_forward_press_time := 0.0
const DOUBLE_TAP_WINDOW := 0.3
var is_crouching := false
var _force_crouch := false
var is_moving := false
var is_rowing := false
var _feet_blood_timer := 0.0
var _feet_notice_timer := 0.0
var _feet_cold_notice_timer := 0.0
var _feet_emit_timer := 0.0
var _feet_wounded_notice := false
var in_shelter := false
var is_in_water := false
var wetness := 0.0
var _rain_wetting := false
var flashlight_charge := 0.0
var held_index := 0
var _consumption_pending := false
var _held_item_reference = null
var _held_item_external := false
var equipped_clothing := ""
var equipped_backpack := ""
# Survival deformable clothing nodes inside the adapted model (mesh name -> node).
var _survival_cloth_nodes := {}
var _survival_body_nodes := {}
var _worn_survival := {}        # item_name -> true while the garment is shown
var _equipped_slots := {}         # slot -> item_name currently equipped
var _equipped_pelt := {}          # item_name -> hide species of the worn pelt garment
var _active_pelt_species := ""    # species being equipped right now (read by the wear fns)
var _initializing := true         # true during _ready, prevents drop_excess

var _pitch := 0.0
var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _walk_bob := 0.0
var _walk_intensity := 0.0
var _turn_input := 0.0
var _water_depth := 0.0

var _water_step_timer := 0.0
var _water_step_left := false
var _water_ripple_shader: Shader
var _water_droplet_mesh: SphereMesh
var _water_sink := 0.0
var _water_notice_cooldown := 0.0
var _water_query_timer := 0.0
var _aim_screen_offset := Vector2.ZERO
var is_puppet := false
var _puppet_anim := "idle"
var _puppet_current_anim := ""
var is_custom_character: bool = false
var is_clothing_model: bool = false
var _custom_body_mesh_name: String = ""
var _custom_clothing_mesh_names: Dictionary = {}
var puppet_model_path: String = ""

func setup_as_puppet() -> void:
	is_puppet = true
	# Disable physics entirely — puppet position is set via puppet_apply
	set_physics_process(false)
	# Lightweight puppet: only load 3D model + animations, skip everything heavy
	if puppet_model_path.is_empty():
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			puppet_model_path = gs.get_selected_model_path()
	# The puppet needs the torch light so puppet_set_torch can show it lit
	# (the same light a local player gets in _create_body).
	torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.visible = false
	torch_light.light_energy = 5.0
	torch_light.omni_range = 22.0
	torch_light.omni_attenuation = 0.8
	torch_light.light_color = Color(1.0, 0.7, 0.3)
	torch_light.shadow_enabled = false
	_create_third_person_model()
	if third_person_model != null:
		third_person_model.visible = true
		# Find skeleton and bone indices for hand/backpack sockets
		_spine_skeleton = _find_skeleton(third_person_model)
		_spine_bone_idx = -1
		if _spine_skeleton != null:
			for bone_name in ["mixamorig:Spine2", "mixamorig:Spine1", "mixamorig:Spine", "mixamorig_Spine2", "mixamorig_Spine1", "mixamorig_Spine", "Spine2", "Spine1", "Spine"]:
				_spine_bone_idx = _spine_skeleton.find_bone(bone_name)
				if _spine_bone_idx != -1:
					break
			_bind_backpack_socket()
			_hand_skeleton = _spine_skeleton
			_hand_bone_idx = -1
			_left_hand_bone_idx = -1
			if _hand_skeleton != null:
				for bone_name in ["mixamorig:RightHand", "mixamorig:LeftHand", "mixamorig_RightHand", "mixamorig_LeftHand", "RightHand", "LeftHand"]:
					_hand_bone_idx = _hand_skeleton.find_bone(bone_name)
					if _hand_bone_idx != -1:
						break
				for bone_name in ["mixamorig:LeftHand", "mixamorig_LeftHand", "LeftHand"]:
					_left_hand_bone_idx = _hand_skeleton.find_bone(bone_name)
					if _left_hand_bone_idx != -1:
						break
			_head_skeleton = _spine_skeleton
			_head_bone_idx = -1
			if _head_skeleton != null:
				for bone_name in ["mixamorig:Head", "mixamorig_Head", "Head", "head", "Cabeza"]:
					_head_bone_idx = _head_skeleton.find_bone(bone_name)
					if _head_bone_idx != -1:
						break
			_bind_headwear_socket_signal()
	# PvP: puppets are the only shootable representation of remote players —
	# give them damage hitboxes so rifle rays connect and headshots register.
	add_to_group("remote_player")
	_create_puppet_hitboxes()
	set_process(true)
	set_process_input(false)
	set_physics_process(false)

func _create_puppet_hitboxes() -> void:
	if not is_puppet or _collision_shape != null:
		return
	# The rifle ray only honors Area3D nodes named *Hitbox — a torso capsule
	# plus a sphere glued to the head bone so headshots track animations.
	var body_area := Area3D.new()
	body_area.name = "BodyHitbox"
	body_area.collision_layer = 1
	body_area.collision_mask = 0
	body_area.monitorable = true
	body_area.monitoring = false
	var body_col := CollisionShape3D.new()
	var body_capsule := CapsuleShape3D.new()
	body_capsule.radius = 0.42
	body_capsule.height = 1.55
	body_col.shape = body_capsule
	body_col.position.y = 0.82
	body_area.add_child(body_col)
	add_child(body_area)
	if _head_skeleton != null and _head_bone_idx >= 0:
		var attach := BoneAttachment3D.new()
		attach.name = "HeadHitboxAttach"
		attach.bone_name = _head_skeleton.get_bone_name(_head_bone_idx)
		_head_skeleton.add_child(attach)
		var head_area := Area3D.new()
		head_area.name = "HeadHitbox"
		head_area.collision_layer = 1
		head_area.collision_mask = 0
		head_area.monitorable = true
		head_area.monitoring = false
		var head_col := CollisionShape3D.new()
		var head_sphere := SphereShape3D.new()
		# Bone space is in centimetres — the armature carries a 0.01 scale.
		head_sphere.radius = 25.0
		head_col.shape = head_sphere
		head_col.position = Vector3(0.0, 16.0, 0.0)
		head_area.add_child(head_col)
		attach.add_child(head_area)
	else:
		var head_area := Area3D.new()
		head_area.name = "HeadHitbox"
		head_area.collision_layer = 1
		head_area.collision_mask = 0
		head_area.monitorable = true
		head_area.monitoring = false
		var head_col := CollisionShape3D.new()
		var head_sphere := SphereShape3D.new()
		head_sphere.radius = 0.26
		head_col.shape = head_sphere
		head_col.position.y = 1.58
		head_area.add_child(head_col)
		add_child(head_area)

var _puppet_clothing := ""
var _puppet_clothing_colors: Array = []
var _puppet_held := ""
var _puppet_backpack := ""
var _applied_appearance := false
var _puppet_char_name := ""
var _puppet_top_color := Color(0.5, 0.5, 0.5)
var _puppet_bottom_color := Color(0.3, 0.3, 0.3)
var _puppet_shoes_color := Color(0.15, 0.15, 0.15)
var _puppet_hair_color := Color(0.2, 0.15, 0.1)
var _puppet_skin_color := Color(0.8, 0.7, 0.6)
var _puppet_top_camo := false
var _puppet_bottom_camo := false

func puppet_apply(pos: Vector3, rot: float, anim: String) -> void:
	if is_instance_valid(rowing_boat) and not bool(rowing_boat.get("occupant_standing")) and not anim.to_lower().contains("dead"):
		return
	if is_dead:
		# Still update position for dead puppets (corpse sync)
		global_position = pos
		rotation.y = rot
		# A melee-tagged death packet may arrive after a generic "dead" sync —
		# upgrade the corpse to the beaten visual instead of staying procedural.
		if not _beaten_death and anim.to_lower().find("melee") >= 0:
			_apply_melee_death_visual()
		return
	global_position = pos
	rotation.y = rot
	_puppet_anim = anim
	if anim.to_lower().find("dead") >= 0:
		is_dead = true
		death_pose_time = 0.0
		_puppet_death_remove_timer = 0.0
		if flashlight != null:
			flashlight.visible = false
		add_to_group("interactable")
		if _death_anim_played:
			return
		_death_anim_played = true
		if anim.to_lower().find("melee") >= 0:
			_apply_melee_death_visual()
		if not _beaten_death and third_person_animation_player != null:
			third_person_animation_player.stop()
		_puppet_current_anim = anim
		return
	if third_person_animation_player != null and anim != _puppet_current_anim:
		var target := ""
		# Try exact animation name first (both clients load same animations)
		if not anim.is_empty() and third_person_animation_player.has_animation(anim):
			target = anim
		else:
			# Fall back to keyword matching
			var lower := anim.to_lower()
			if lower.find("riflefire") >= 0 and not _rifle_fire_animation.is_empty():
				target = _rifle_fire_animation
			elif lower.find("rifleaim") >= 0 and not _rifle_aim_idle_animation.is_empty():
				target = _rifle_aim_idle_animation
			elif lower.find("rifleidle") >= 0 and not _rifle_idle_animation.is_empty():
				target = _rifle_idle_animation
			elif lower.find("riflewalk") >= 0 and not _rifle_walk_animation.is_empty():
				target = _rifle_walk_animation
			elif lower.find("riflerun") >= 0 and not _rifle_run_animation.is_empty():
				target = _rifle_run_animation
			elif lower.find("run") >= 0:
				target = third_person_run_animation
			elif lower.find("walk") >= 0:
				target = third_person_walk_animation
			elif lower.find("sneak") >= 0:
				target = third_person_sneak_animation
			elif lower.find("idle") >= 0:
				target = third_person_idle_animation
			elif lower.find("jumpdown") >= 0 or lower.find("jump_down") >= 0:
				target = third_person_jump_down_animation
			elif lower.find("jump") >= 0:
				target = third_person_jump_animation
			elif lower.find("shot") >= 0:
				target = third_person_shot_animation
			elif lower.find("hit") >= 0:
				target = third_person_hit_animation
			elif lower.find("punch") >= 0:
				target = third_person_punch_animation
			elif lower.find("attack") >= 0:
				target = third_person_attack_animation
			elif lower.find("sit") >= 0:
				target = third_person_sit_animation
			elif lower.find("sleep") >= 0:
				target = third_person_sleep_animation
			elif lower.find("drink") >= 0:
				target = third_person_drink_animation
			elif lower.find("plant") >= 0:
				target = third_person_plant_animation
			elif lower.find("gather") >= 0:
				target = third_person_gather_animation
			elif lower.find("fish") >= 0:
				target = third_person_fish_animation
			elif lower.find("interact") >= 0:
				target = third_person_interact_animation
			elif lower.find("dying") >= 0 or lower.find("dead") >= 0:
				target = third_person_dying_animation
			elif lower.find("low") >= 0:
				target = third_person_low_health_animation
		if not target.is_empty() and third_person_animation_player.has_animation(target):
			third_person_animation_player.play(target, 0.15)
			# Gesture clips (kneel/talk) keep a canonical start offset so remote
			# players see the same readable part of the clip as the sender.
			var clip_offset := _third_person_clip_start_offset(target)
			if clip_offset > 0.0:
				third_person_animation_player.seek(clip_offset, true)
			else:
				third_person_animation_player.advance(0.0)
			_puppet_current_anim = anim
			_update_puppet_ground_alignment(1.0)
			# Confirmed impact audio arrives through a reliable hit event. Swing
			# sounds still follow the attacker's synced action clip.
			if target == third_person_punch_animation or target == third_person_attack_animation:
				_schedule_melee_swing_sound(MELEE_PUNCH_IMPACT_DELAY if target == third_person_punch_animation else MELEE_SWING_IMPACT_DELAY)

func puppet_apply_visuals(clothing: String, held_item: String, backpack: String, clothing_colors: Array = []) -> void:
	if not is_puppet:
		return
	# If dead and naked swap not yet done, ensure pending is active
	if is_dead and clothing.is_empty() and not _puppet_naked_pending:
		if third_person_model != null and third_person_model.name != "NakedCorpse":
			_puppet_naked_pending = true
			_puppet_naked_timer = 0.0
	# Update clothing — also re-applies when only a loot color changed
	if clothing != _puppet_clothing or clothing_colors != _puppet_clothing_colors:
		var old_items: Array = []
		for item_name in _puppet_clothing.split(","):
			var name := item_name.strip_edges().split("|")[0]
			if not name.is_empty():
				old_items.append(name)
		_puppet_clothing = clothing
		_puppet_clothing_colors = clothing_colors.duplicate()
		var new_items: Array = []
		var new_colors: Array = []
		var new_species: Array = []
		if clothing.is_empty():
			if is_dead:
				# Dead body: delay naked swap until death animation finishes
				_puppet_naked_pending = true
				_puppet_naked_timer = 0.0
				new_items = []
				new_colors = []
			else:
				# Living puppet with no clothing: show naked body
				new_items = []
				new_colors = []
		else:
			var raw_names := clothing.split(",")
			for ri in range(raw_names.size()):
				# Pelt garments carry their species as "name|species" so remote
				# players render the same animal hide (fisherman cap -> wolf
				# head, jacket -> wolf fur). Plain names stay valid for peers
				# that never wear pelt clothing.
				var entry := raw_names[ri].strip_edges()
				var sp := ""
				if entry.contains("|"):
					var parts := entry.split("|")
					entry = parts[0]
					sp = parts[1] if parts.size() > 1 else ""
				if not entry.is_empty():
					new_items.append(entry)
					new_species.append(sp)
					var c: Variant = clothing_colors[ri] if ri < clothing_colors.size() else null
					new_colors.append(c if c is Color else Color(0, 0, 0, 0))
		# Unequip items that were worn before but are no longer in the list
		for name in old_items:
			if not new_items.has(name):
				unequip_clothing(name)
		# Equip items in the new list
		for ni in range(new_items.size()):
			equip_clothing(new_items[ni], new_colors[ni], null, new_species[ni])
	# Update held item
	if held_item != _puppet_held:
		_puppet_held = held_item
		_update_puppet_held_item(held_item)
	# Update backpack. Si el visual se perdio por cualquier rebuild (los
	# puppets no tienen inventory/equipment y no pueden regenerarlo ahi),
	# se reconstruye aqui aunque el nombre no haya cambiado.
	var bp_visual_missing := not backpack.is_empty() and third_person_back_item_root != null and third_person_back_item_root.get_node_or_null("BackpackAsset") == null
	if backpack != _puppet_backpack or bp_visual_missing:
		_puppet_backpack = backpack
		if third_person_back_item_root != null:
			for child in third_person_back_item_root.get_children():
				third_person_back_item_root.remove_child(child)
				child.free()
		if not backpack.is_empty():
			equipped_backpack = backpack
			_build_third_person_backpack()
		else:
			equipped_backpack = ""

func puppet_set_aiming(aiming: bool) -> void:
	if not is_puppet:
		return
	_is_aiming = aiming
	if not aiming:
		# Release the direct-aim state immediately — the next _update_rifle_ik
		# has to rebuild the idle grip instead of holding the last eye-line pose.
		_rifle_aim_pose_active = false
		_restore_grip_origins()

func puppet_apply_appearance(char_name: String, top_color: Color, bottom_color: Color, shoes_color: Color, hair_color: Color, skin_color: Color, top_camo: bool, bottom_camo: bool) -> void:
	if not is_puppet:
		return
	_applied_appearance = true
	_puppet_char_name = char_name
	_puppet_top_color = top_color
	_puppet_bottom_color = bottom_color
	_puppet_shoes_color = shoes_color
	_puppet_hair_color = hair_color
	_puppet_skin_color = skin_color
	_puppet_top_camo = top_camo
	_puppet_bottom_camo = bottom_camo
	_apply_puppet_appearance()

func _apply_puppet_appearance() -> void:
	if third_person_model == null:
		return
	# Apply Tops — reutilizar material cacheado si existe
	var top_mi: MeshInstance3D = _find_mesh_in_third_person("Tops")
	if top_mi != null:
		var top_key := "puppet_top"
		var tmat: StandardMaterial3D = _skin_mat_cache.get(top_key) as StandardMaterial3D
		if tmat == null:
			tmat = StandardMaterial3D.new()
			tmat.roughness = 0.8
			_skin_mat_cache[top_key] = tmat
		if _puppet_top_camo:
			if tmat.albedo_texture == null:
				tmat.albedo_texture = _make_camo_texture()
				tmat.albedo_color = Color.WHITE
				MaterialFactory.cloth_detail(tmat, "jersey")
			top_mi.material_override = tmat
		else:
			top_mi.material_override = MaterialFactory.make_clothing_material("top", _puppet_top_color)
	# Apply Bottoms
	var bot_mi: MeshInstance3D = _find_mesh_in_third_person("Bottoms")
	if bot_mi != null:
		var bot_key := "puppet_bot"
		var bmat: StandardMaterial3D = _skin_mat_cache.get(bot_key) as StandardMaterial3D
		if bmat == null:
			bmat = StandardMaterial3D.new()
			bmat.roughness = 0.8
			_skin_mat_cache[bot_key] = bmat
		if _puppet_bottom_camo:
			if bmat.albedo_texture == null:
				bmat.albedo_texture = _make_camo_texture()
				bmat.albedo_color = Color.WHITE
				MaterialFactory.cloth_detail(bmat, "denim")
			bot_mi.material_override = bmat
		else:
			bot_mi.material_override = MaterialFactory.make_clothing_material("bottom", _puppet_bottom_color)
	# Apply Shoes
	var shoes_mi: MeshInstance3D = _find_mesh_in_third_person("Shoes")
	if shoes_mi != null:
		shoes_mi.material_override = MaterialFactory.make_clothing_material("shoes", _puppet_shoes_color)
	# Apply skin color
	for body_name in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet",
			"Body_torso", "Body_arms", "Body_hands", "Body_legs", "Body_feet"]:
		var bmi: MeshInstance3D = _find_mesh_in_third_person(body_name)
		_tint_mesh(bmi, _puppet_skin_color, 0.9)
	# Apply hair color
	var hair_mi: MeshInstance3D = _find_mesh_in_third_person("Hair")
	_tint_mesh(hair_mi, _puppet_hair_color, 0.8)
	# Apply skin to head/full body
	_tint_mesh(_head_mesh, _puppet_skin_color, 0.9)
	_tint_mesh(_full_body_mesh, _puppet_skin_color, 0.9)
	_tint_mesh(_body_no_head_mesh, _puppet_skin_color, 0.9)


func puppet_set_rifle(has_rifle: bool) -> void:
	if not is_puppet:
		return
	_has_rifle = has_rifle

func puppet_set_state_flags(sleeping: bool, sitting: bool, prone: bool, crouching: bool) -> void:
	if not is_puppet:
		return
	is_sleeping = sleeping
	is_sitting = sitting
	is_prone = prone
	is_crouching = crouching

var _puppet_torch_lit := false

func puppet_set_torch(lit: bool) -> void:
	if not is_puppet:
		return
	# El estado encendido viaja por sync_player_state y se re-aplica en cada
	# rebuild del modelo (_build_third_person_torch fuerza visible=false si
	# mira el meta torch_lit, que el puppet no tiene).
	_puppet_torch_lit = lit
	if torch_light != null:
		torch_light.visible = lit

func puppet_set_flashlight(on: bool) -> void:
	if not is_puppet:
		return
	if flashlight == null:
		# Local players mount the spotlight on the camera; puppets have no
		# camera, so attach it to the chest of the model facing forward.
		flashlight = SpotLight3D.new()
		flashlight.name = "Flashlight"
		flashlight.visible = false
		flashlight.light_energy = 3.0
		flashlight.spot_range = 18.0
		flashlight.spot_angle = 35.0
		var host: Node3D = third_person_model if third_person_model != null else self
		host.add_child(flashlight)
		# The model is rotated 180 deg on Y (line ~8538), so flip the spot to
		# face the character's forward direction, with the camera's downtilt.
		flashlight.position = Vector3(0.0, 1.35, 0.0)
		flashlight.rotation_degrees = Vector3(-8.0, 180.0, 0.0)
	flashlight.visible = on

func _puppet_swap_to_naked() -> void:
	if not is_puppet:
		return
	if third_person_model == null or not is_instance_valid(third_person_model):
		return
	# Mark as naked corpse to prevent re-triggering
	third_person_model.name = "NakedCorpse"
	# Hide ALL MeshInstance3D in the model first
	var stack: Array = [third_person_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			(node as MeshInstance3D).visible = false
		for c in node.get_children():
			stack.append(c)
	# Show only Desnudo_* parts (naked body)
	for dn in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
		var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
		if dmi != null:
			dmi.visible = true
	# Show Body_torso (includes neck)
	var bt: MeshInstance3D = _find_mesh_in_third_person("Body_torso")
	if bt != null:
		bt.visible = true
	# Show head
	if _head_mesh != null:
		_head_mesh.visible = true
	# Hair belongs to the naked body too — the hide-all above switched it off.
	# Strands never touched by headwear go back visible; strands hidden by a
	# balaclava keep their meta and are resolved by restore_hair below.
	for hm in third_person_model.find_children("Hair", "MeshInstance3D", true, false):
		if not hm.has_meta("headwear_original_visible"):
			hm.visible = true
	# Remove any worn visual garments
	preload("res://scripts/HeadwearFit.gd").restore_hair(third_person_model)
	for child in third_person_model.get_children():
		if child.name.begins_with("Worn_"):
			child.free()
	# Clear equipped slots
	_equipped_slots.clear()
	_puppet_clothing = ""

func _update_puppet_held_item(item_name: String) -> void:
	if third_person_hand_item_root == null:
		return
	# Always clean up rifle bone attachment when switching items
	_clear_rifle_attachment()
	# The torch lives in the torch hand socket, not the item root — clear it
	# when the remote player swaps to anything else.
	if item_name != "Antorcha":
		if _torch_hand_root != null and is_instance_valid(_torch_hand_root) and _torch_hand_root.get_child_count() > 0:
			_clear_torch_attachment()
		if torch_light != null:
			torch_light.visible = false
	# Clear current held item
	for child in third_person_hand_item_root.get_children():
		third_person_hand_item_root.remove_child(child)
		child.free()
	if item_name.is_empty():
		return
	# Build visual based on item name
	match item_name:
		"Antorcha":
			# The torch hangs from the torch hand socket; puppet_set_torch
			# toggles its light according to the remote player's state.
			_build_third_person_torch()
			return
		"Cuchillo":
			_build_third_person_knife()
		"Rifle francotirador", M4_NAME:
			_build_third_person_rifle(item_name)
		"Hacha":
			_build_third_person_axe()
		"Pala":
			_build_third_person_tool(REAL_SHOVEL_MODEL, "PuppetShovel", Color(0.6, 0.4, 0.2), 1.15)
		"Azada":
			_build_third_person_tool(REAL_HOE_MODEL, "PuppetHoe", Color(0.5, 0.35, 0.18), 1.5)
		"Martillo":
			_build_third_person_tool(REAL_HAMMER_MODEL, "PuppetHammer", Color(0.5, 0.5, 0.5))
		"Pico":
			_build_third_person_tool(REAL_PICKAXE_MODEL, "PuppetPickaxe", Color(0.4, 0.4, 0.4), 0.9)
		"Linterna":
			_build_third_person_flashlight()
		"Caña de pescar":
			_build_third_person_fishing_rod()
		"Palo afilado", "Lanza", "Lanza de hueso":
			_build_third_person_primitive(item_name)
		"Arco de madera", "Arco reforzado", "Flecha de madera", "Flecha de piedra", "Flecha de hueso", "Flecha improvisada", "Boleadoras", "Cuerda", "Hueso", "Tendón", "Pluma", "Piedra afilada", "Cuchillo de piedra", "Cuchillo de hueso":
			_build_third_person_primitive(item_name)
		"Hacha de piedra":
			_build_third_person_axe()
		"Cerillas":
			_add_held_box(third_person_hand_item_root, "HeldMatches", Vector3(0.12, 0.05, 0.075), Vector3.ZERO, Color(0.38, 0.16, 0.07), Vector3.ZERO)
		"Botella de agua":
			_build_third_person_plastic_bottle()
		"Botella de agua llena":
			_build_third_person_plastic_bottle()
		"Botella":
			_build_third_person_bottle()
		"Vendaje":
			_build_third_person_bandage()
		"Bateria":
			_build_third_person_battery()
		"Madera":
			_build_third_person_resource("Madera")
		"Piedra":
			_build_third_person_resource("Piedra")
		"Carne ensartada":
			_build_third_person_can()
		"Carne asada":
			_build_third_person_can()
		"Carne cocinada":
			_build_third_person_can()
		"Pez ensartado":
			_build_third_person_can()
		"Pez cocinado":
			_build_third_person_can()
		"Pez crudo":
			_build_third_person_can()
		_:
			_build_third_person_pack()


#region PROCESO PRINCIPAL (_process + input)
func _process(delta: float) -> void:
	if is_puppet:
		# One-shot action clips (fire, punch, ...) must expire on puppets too —
		# otherwise _is_firing pins want_direct_aim forever and the rifle stays
		# glued to the aim pose after a remote shot.
		if third_person_action_timer > 0.0:
			third_person_action_timer = maxf(0.0, third_person_action_timer - delta)
			if third_person_action_timer <= 0.0:
				third_person_action_animation = ""
				third_person_action_start_offset = 0.0
				_is_firing = false
		if not is_dead:
			_update_puppet_ground_alignment(delta)
			_update_rifle_visuals(delta)
		_update_hand_socket()
		_update_torch_hand_socket()
		_update_drink_hand_socket()
		_update_backpack_socket()
		_update_head_worn_items()
		if is_dead:
			_update_death_pose(delta)
			if _puppet_naked_pending:
				_puppet_naked_timer += delta
				if _puppet_naked_timer >= 2.0:
					_puppet_naked_pending = false
					_puppet_swap_to_naked()
		return
	if stats != null and stats.sick != _was_sick:
		_was_sick = stats.sick
		if _was_sick:
			_play_unwell_sound()
			_sync_condition_audio("sick")
	if stats != null:
		var critical: bool = stats.health > 0.0 and stats.health <= 20.0
		if critical:
			_critical_sound_timer = maxf(0.0, _critical_sound_timer - delta)
			if not _was_critical or _critical_sound_timer <= 0.0:
				_was_critical = true
				_critical_sound_timer = 14.0
				_play_unwell_sound()
				_sync_condition_audio("critical")
		else:
			_was_critical = false
			_critical_sound_timer = 0.0
	# Detectar hold de F y G por polling (mas fiable que eventos)
	var f_held := Input.is_key_pressed(KEY_F) and (not is_instance_valid(rowing_boat) or _boat_standing)
	var g_held := Input.is_key_pressed(KEY_G) and (not is_instance_valid(rowing_boat) or _boat_standing)
	# F: press ya llama _interact() en _input; aqui solo track hold para guardar
	if f_held and not _f_holding:
		_f_holding = true
		_f_hold_time = 0.0
		_f_hold_triggered = false
	elif not f_held and _f_holding:
		_f_holding = false
	# G: tap = soltar, hold = tirar
	if g_held and not _g_holding:
		_g_holding = true
		_g_hold_time = 0.0
		_throw_charging = false
		_throw_anim_frozen = false
	elif not g_held and _g_holding:
		_g_holding = false
		if _throw_charging:
			_throw_charging = false
			_throw_anim_frozen = false
			if third_person_animation_player != null:
				third_person_animation_player.speed_scale = 1.0
			if _has_throwable_weapon_equipped():
				_throw_aimed_weapon()
			else:
				_throw_held_item(clamp(_throw_charge_time / THROW_MAX_CHARGE_TIME, 0.15, 1.0))
		elif _g_hold_time < HOLD_THRESHOLD:
			_drop_held_item()
	# Carga de lanzamiento (mantener G) y guardar (mantener F)
	if _f_holding:
		_f_hold_time += delta
		if _f_hold_time >= HOLD_THRESHOLD and not _f_hold_triggered:
			_f_hold_triggered = true
			# Solo guardar si no hay target de interaccion (evita double-act)
			if get_held_item() != null and _get_interaction_target() == null:
				_store_held_item()
	if _g_holding:
		_g_hold_time += delta
		if _g_hold_time >= HOLD_THRESHOLD and not _throw_charging:
			var held = get_held_item()
			if held != null and str(held.item_type) != "weapon_rifle" and not _is_fishing and not is_sleeping:
				_throw_charging = true
				_throw_charge_time = 0.0
				_throw_anim_frozen = false
				var h_nm := str(held.item_name)
				if not (h_nm in ["Lanza", "Lanza de hueso", "Palo afilado"] and not _bow_aim_idle_animation.is_empty()):
					# Iniciar animación de ataque al empezar a cargar (wind-up)
					_start_throw_animation()
			else:
				_g_holding = false
	if _throw_charging:
		_throw_charge_time = min(_throw_charge_time + delta, THROW_MAX_CHARGE_TIME)
		var pct := int((_throw_charge_time / THROW_MAX_CHARGE_TIME) * 100.0)
		notice.emit("Cargando lanzamiento... %d%%" % pct)
		var ch_it = get_held_item()
		var ch_spear := ch_it != null and str(ch_it.item_name) in ["Lanza", "Lanza de hueso", "Palo afilado"] and not _bow_aim_idle_animation.is_empty()
		if not ch_spear:
			# Mantener el timer de la animación vivo mientras se carga
			third_person_action_timer = 0.8
			# Congelar la animación a los 0.4s mientras se sigue cargando
			if _throw_charge_time >= THROW_ANIM_FREEZE_TIME and not _throw_anim_frozen:
				_throw_anim_frozen = true
				if third_person_animation_player != null:
					third_person_animation_player.speed_scale = 0.0
	# Wind-up congelado al apuntar con arrojadizas (mismo gesto que G).
	if _throw_aim_hold:
		if _is_aiming and not is_dead and _has_throwable_weapon_equipped():
			var h_it = get_held_item()
			var is_spear_pose := h_it != null and str(h_it.item_name) in ["Lanza", "Lanza de hueso", "Palo afilado"] and not _bow_aim_idle_animation.is_empty()
			if not is_spear_pose:
				third_person_action_timer = 0.8
				if not _throw_aim_frozen and third_person_animation_player != null and third_person_animation_player.current_animation == third_person_attack_animation and third_person_animation_player.current_animation_position >= THROW_ANIM_FREEZE_TIME:
					_throw_aim_frozen = true
					third_person_animation_player.speed_scale = 0.0
		else:
			_throw_aim_hold = false
			_throw_aim_frozen = false
			if not _throw_charging and third_person_animation_player != null:
				third_person_animation_player.speed_scale = 1.0
	_tick_primitive_releases(delta)
	# Tick spoilage for perishable food in inventory
	if inventory != null and not is_dead:
		var _any_spoiled := false
		for item in inventory.items:
			if item.is_perishable():
				var _prev_state: int = item.spoil_state()
				item.tick_spoilage(delta)
				if item.spoil_state() != _prev_state:
					_any_spoiled = true
		if _any_spoiled:
			inventory.changed.emit()
	# Recoil recovery: exponential decay back to neutral
	if _recoil_pitch != 0.0 or _recoil_yaw != 0.0:
		var decay := 1.0 - exp(-_recoil_recover_speed * delta)
		_recoil_pitch = lerp(_recoil_pitch, 0.0, decay)
		_recoil_yaw = lerp(_recoil_yaw, 0.0, decay * 0.6)
	# Wind simulation: smoothly varying wind strength and direction
	_wind_timer += delta
	if _wind_timer > 3.0:
		_wind_timer = 0.0
		_wind_target_strength = randf_range(0.5, 3.5)
		_wind_dir = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_wind_strength = lerp(_wind_strength, _wind_target_strength, delta * 0.5)
	# Breath sway when aiming: compute oscillation offsets
	_breath_timer += delta
	_breath_pitch_offset = 0.0
	_breath_yaw_offset = 0.0
	_update_breath_hold(delta, Input.is_key_pressed(KEY_SHIFT))
	if _is_aiming and not is_moving:
		# Fatigue increases breath amplitude: less energy = more sway
		var fatigue_mult := 1.0
		if stats != null:
			fatigue_mult = 1.0 + (1.0 - clamp(stats.energy / 100.0, 0.0, 1.0)) * 1.5
		var is_m4_aim := _held_is_m4()
		var mag_scale := 1.0
		if not is_m4_aim:
			var mags := _rifle_scope_mags()
			var mag: float = float(mags[clampi(_scope_zoom_index, 0, mags.size() - 1)]) if not mags.is_empty() else 4.0
			mag_scale = sqrt(4.0 / maxf(mag, 1.0))
		var breath_amp_pitch := (0.65 if is_m4_aim else 0.35 * mag_scale) * fatigue_mult
		var breath_amp_yaw := (0.48 if is_m4_aim else 0.25 * mag_scale) * fatigue_mult
		if _breath_hold_active:
			breath_amp_pitch = 0.0
			breath_amp_yaw = 0.0
		var stance_mult := 0.12 if is_prone else (0.28 if (is_crouching or is_sitting) else 1.0)
		_breath_pitch_offset = deg_to_rad(breath_amp_pitch * sin(_breath_timer * 1.2)) * stance_mult
		_breath_yaw_offset = deg_to_rad(breath_amp_yaw * sin(_breath_timer * 0.8)) * stance_mult
	_crosshair_check_timer += delta
	if _crosshair_check_timer >= 0.5:
		_crosshair_check_timer = 0.0
		var main := get_tree().current_scene
		if main != null and main.hud != null:
			_update_crosshair(_has_rifle_equipped())
	_update_crosshair_spread(delta)
	_update_rifle_visuals(delta)
	# Camera overrides for debug views only
	if camera != null and (_frontal_camera or _side_camera or _left_camera or _rear_camera or _top_camera or _aerial_camera):
		var char_forward := -global_basis.z.normalized()
		var char_right := global_basis.x.normalized()
		var char_up := global_basis.y.normalized()
		if _frontal_camera:
			camera.global_position = global_position + char_forward * 3.5 + char_up * 1.5
			camera.look_at(global_position + char_up * 1.2, char_up)
			camera.fov = 55.0
		elif _side_camera:
			camera.global_position = global_position + char_right * 3.5 + char_up * 1.5
			camera.look_at(global_position + char_up * 1.2, char_up)
			camera.fov = 55.0
		elif _left_camera:
			camera.global_position = global_position - char_right * 3.5 + char_up * 1.5
			camera.look_at(global_position + char_up * 1.2, char_up)
			camera.fov = 55.0
		elif _rear_camera:
			camera.global_position = global_position - char_forward * 3.5 + char_up * 1.5
			camera.look_at(global_position + char_up * 1.2, char_up)
			camera.fov = 55.0
		elif _top_camera:
			camera.global_position = global_position + char_up * 5.0
			camera.look_at(global_position, char_forward)
			camera.fov = 55.0
		elif _aerial_camera:
			# Pan with WASD / arrows
			var pan_x := 0.0
			var pan_z := 0.0
			if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
				pan_x += 1.0
			if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
				pan_x -= 1.0
			if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
				pan_z += 1.0
			if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
				pan_z -= 1.0
			var pan_vec := Vector3(pan_x, 0.0, pan_z)
			if pan_vec.length() > 0.0:
				pan_vec = pan_vec.normalized()
				_aerial_pos += pan_vec * _AERIAL_PAN_SPEED * delta * (_aerial_height / 600.0)
			camera.global_position = Vector3(_aerial_pos.x, _aerial_height, _aerial_pos.z)
			camera.look_at(Vector3(_aerial_pos.x, 0.0, _aerial_pos.z), Vector3(0.0, 0.0, -1.0))
			camera.fov = 90.0
			camera.far = 2000.0
	else:
		_sync_camera_lens()

func _sync_camera_lens() -> void:
	if camera == null:
		return
	var want_far := RIFLE_RANGE + 50.0 if _is_aiming else 500.0
	if camera.far != want_far:
		camera.far = want_far
	if not _is_aiming and camera.fov != _camera_fov:
		camera.fov = _camera_fov

#endregion


#region INICIALIZACIÓN (_ready, _create_body, etc.)
func _ready() -> void:
	if is_puppet:
		return
	stats = SurvivalStatsScript.new()
	stats.name = "SurvivalStats"
	add_child(stats)

	inventory = InventoryScript.new()
	inventory.name = "Inventory"
	add_child(inventory)
	inventory.item_used.connect(func(message: String) -> void: notice.emit(message))
	inventory.changed.connect(_on_inventory_changed)
	inventory.max_slots = 10
	inventory.max_weight = 18.0

	equipment = PlayerEquipmentScript.new()
	equipment.name = "PlayerEquipment"
	add_child(equipment)

	hands = PlayerHandsScript.new()
	hands.name = "PlayerHands"
	add_child(hands)

	_add_starting_items()
	_create_body()
	_sync_held_item()
	_apply_view_mode()
	call_deferred("_capture_mouse")
	_initializing = false
	_recalculate_carry_capacity()

func _input(event: InputEvent) -> void:
	if get_parent().has_node("ShelterPlacement") and not event is InputEventMouseMotion:
		return
	if is_puppet or is_dead:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if is_instance_valid(rowing_boat):
		if event is InputEventMouseMotion:
			_rowing_view_yaw -= event.relative.x * mouse_sensitivity
			_rowing_view_height = clampf(_rowing_view_height + event.relative.y * 0.015, 1.5, 6.0)
			return
		if event is InputEventMouseButton:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_WHEEL_UP:
					_rowing_view_dist = clampf(_rowing_view_dist - 0.8, 3.0, 14.0)
					return
				elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
					_rowing_view_dist = clampf(_rowing_view_dist + 0.8, 3.0, 14.0)
					return
				elif event.button_index == MOUSE_BUTTON_LEFT and _boat_standing and _has_fishing_rod_in_hand() and not _is_fishing:
					_start_fishing_near_water()
					return
			if not _boat_standing:
				return
		elif event.is_action_pressed("interact") and not event.is_echo():
			# Con la caña en la mano, F lanza el hilo como en la orilla; para
			# salir hay que sentarse primero (E) o guardar la caña.
			if _boat_standing and _has_fishing_rod_in_hand():
				if not _is_fishing:
					_start_fishing_near_water()
			else:
				rowing_boat.request_exit()
			return
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
			rowing_boat.request_toggle_stand()
			return
		if not _boat_standing:
			return
		# De pie en la barca el resto de entradas corren como si estuviera en tierra.
	# Abandon the fishing cast/idle-with-line state as soon as any key or mouse
	# button is pressed, returning the player to the normal controllable pose.
	var _pressed_key_or_button: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventMouseButton and event.pressed)
	if _pressed_key_or_button and (_is_fishing_idle or (not third_person_action_animation.is_empty() and third_person_action_animation == _rod_cast_animation) or _is_fishing):
		_is_fishing = false
		_is_fishing_idle = false
		third_person_action_animation = ""
		third_person_action_timer = 0.0
		third_person_action_start_offset = 0.0
		_deactivate_rod_visual_overlay()
		# Hide countdown and clear notice
		var main := get_tree().current_scene
		if main != null:
			if main.get("hud") != null and main.hud.has_method("hide_countdown"):
				main.hud.hide_countdown()
		notice.emit("")
		# Return to normal animation
		if third_person_animation_player != null and not third_person_idle_animation.is_empty():
			third_person_animation_player.play(third_person_idle_animation, 0.3)
			third_person_animation_player.speed_scale = 1.0
		# Store the fishing rod back into inventory
		_store_held_item()
		# Consume this input so it only cancels fishing and does not trigger
		# other actions (store item, switch slot, etc.) with the same press.
		return
	if event is InputEventMouseButton and event.pressed:
		_on_game_mouse_button_pressed(event)
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_fire_button_held = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and _is_aiming:
			_toggle_aim()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not _aerial_camera:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_turn_input = clamp(event.relative.x, -80.0, 80.0)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-78.0), deg_to_rad(78.0))
		if camera != null:
			camera.rotation.x = _pitch + _recoil_pitch + _breath_pitch_offset
			if _is_aiming:
				camera.rotation.y = _breath_yaw_offset * 0.5
	if event.is_action_pressed("interact") and not event.echo:
		_interact()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		var target = _get_interaction_target()
		if target != null and target.has_method("interact") and "is_open" in target and target.is_open:
			target.interact(self)
		else:
			_collect()
	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_I:
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_close_loot_ui") and scene._loot_panel != null:
			scene._close_loot_ui()
		return
	if event.is_action_pressed("toggle_inventory"):
		notice.emit("Inventario alternado.")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		if is_on_floor() and not is_in_water and not is_jumping and stats.energy >= min_jump_stamina:
			var base_jump := sprint_jump_force if is_sprinting else jump_force
			var carry := _get_carry_weight_ratio()
			velocity.y = base_jump * (1.0 - carry * 0.6)
			stats.energy = max(0.0, stats.energy - jump_stamina_cost)
			stats.changed.emit()
			is_jumping = true
			_jump_apex = false
			_jump_animation_timer = 1.2
			_is_falling_from_height = true
			_fall_height = global_position.y
			_max_fall_height = global_position.y
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_frontal_camera = not _frontal_camera
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			_aerial_camera = false
			return
		if event.keycode == KEY_2:
			_side_camera = not _side_camera
			_frontal_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			_aerial_camera = false
			return
		if event.keycode == KEY_3:
			_left_camera = not _left_camera
			_frontal_camera = false
			_side_camera = false
			_rear_camera = false
			_top_camera = false
			_aerial_camera = false
			return
		if event.keycode == KEY_4:
			_rear_camera = not _rear_camera
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_top_camera = false
			_aerial_camera = false
			return
		if event.keycode == KEY_5:
			_top_camera = not _top_camera
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			_aerial_camera = false
			return
		if event.keycode == KEY_6:
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			_aerial_camera = false
			return
		if event.keycode == KEY_9:
			_aerial_camera = not _aerial_camera
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			if _aerial_camera:
				_aerial_pos = Vector3(global_position.x, 0.0, global_position.z)
				_aerial_height = 600.0
			return
		var inventory_index := _inventory_index_for_key(event.keycode)
		if inventory_index >= 0:
			_use_inventory_index(inventory_index)
			return
		if event.keycode == KEY_B:
			_craft_campfire()
		if event.keycode == KEY_D and not is_sleeping:
			start_sleep()
			notice.emit("Durmiendo... pulsa D para despertar.")
			return
		if event.keycode == KEY_D and is_sleeping:
			stop_sleep()
			notice.emit("Has despertado.")
			return
		if event.keycode == KEY_S and not is_sleeping:
			_toggle_sit()
		if event.keycode == KEY_M:
			_eat_action()
			return
		if event.keycode == KEY_N:
			_light_action()
			return
		if (event.keycode == KEY_R or event.keycode == KEY_T) and _has_rifle_equipped():
			_reload_rifle()
			return
		# Atajos de equipo: H guarda el objeto que esta en la mano y J usa
		# el primer objeto disponible de los hombros.
		if event.keycode == KEY_H:
			_store_held_item()
			return
		if event.keycode == KEY_J:
			if not use_back_item():
				notice.emit("No llevas nada en la espalda.")
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _on_game_mouse_button_pressed(event: InputEventMouseButton) -> void:
	if _aerial_camera:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_aerial_height = clamp(_aerial_height - _AERIAL_ZOOM_STEP, _AERIAL_MIN_HEIGHT, _AERIAL_MAX_HEIGHT)
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_aerial_height = clamp(_aerial_height + _AERIAL_ZOOM_STEP, _AERIAL_MIN_HEIGHT, _AERIAL_MAX_HEIGHT)
			return
	_capture_mouse()
	var has_rifle := _has_rifle_equipped()
	var has_bow := _has_bow_equipped()
	var has_throwable := _has_throwable_weapon_equipped()
	if event.button_index == MOUSE_BUTTON_LEFT:
		if has_rifle:
			_fire_button_held = true
			_shoot_rifle()
		elif has_bow:
			_shoot_bow()
		elif has_throwable and _is_aiming:
			_throw_aimed_weapon()
		else:
			_melee_attack()
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# El aviso interactivo manda: con una accion anunciada el boton
		# derecho la ejecuta igual que su tecla ([F]/[C]/[M]/[K]) en vez
		# de apuntar. Sin aviso se conserva la punteria/uso rapido.
		var rmb_target = _get_interaction_target()
		if _nearby_rowboat() != null or (_can_fish_near_water and _has_fishing_rod_in_hand() and not _is_fishing) or _find_nearby_feedable_player() != null:
			_interact()
		elif rmb_target != null and _right_click_interact(rmb_target):
			pass
		elif (has_rifle or has_bow or has_throwable) and not _is_aiming:
			_toggle_aim()
		else:
			_quick_use_held_item()
	elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
		if _is_aiming:
			_scope_zoom_index = clampi(_scope_zoom_index + direction, 0, _rifle_scope_mags().size()-1)
			_update_scope_zoom()
		else:
			_camera_fov = clampf(_camera_fov - direction * 4.0, 30.0, 90.0)
			if camera != null: camera.fov = _camera_fov

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		call_deferred("_capture_mouse")

func _capture_mouse() -> void:
	if DisplayServer.window_is_focused() and get_tree().get_root().visible:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _inventory_index_for_key(keycode: Key) -> int:
	match keycode:
		KEY_6:
			return 0
		KEY_7:
			return 1
		KEY_8:
			return 2
		KEY_9:
			return 3
		_:
			return -1

func _use_inventory_index(index: int) -> void:
	if inventory == null or index < 0 or index >= inventory.items.size():
		return
	if _is_aiming and index != held_index:
		_cancel_aim()
	var item = inventory.items[index]
	var item_name := str(item.item_name)
	var item_type := str(item.item_type)
	if item.has_method("is_broken") and item.is_broken() and item_type != "food" and item_type != "water":
		notice.emit("%s esta roto y no se puede usar." % item_name)
		return
	# Loose ammunition loads straight into the rifle reserve — there is no
	# hands animation for it and "use" consumes one unit immediately.
	if item_type == "ammo":
		_load_ammo_item(item, index)
		return
	# Food items: first put in hand, then eat with animation when used again
	if item_type == "food":
		if held_index == index and hands != null and hands.has_item_in_hands():
			_eat_held_item()
		else:
			_select_held_item(index)
			notice.emit("Tienes %s en la mano. Pulsa usar de nuevo para comer." % item_name)
		return
	# Water items: first put in hand, then drink with animation when used again
	if item_type == "water":
		if held_index == index and hands != null and hands.has_item_in_hands():
			_drink_held_item()
		else:
			_select_held_item(index)
			notice.emit("Tienes %s en la mano. Pulsa usar de nuevo para beber." % item_name)
		return
	# Plastic bottle: put in hand, then fill at river
	if item_name == "Botella de plastico":
		_select_held_item(index)
		notice.emit("Tienes la botella en la mano. Ve al rio y pulsa E para llenarla.")
		return
	# Medicinas y ropa también pasan primero por la mano: evita que el botón
	# "Usar" aplique el efecto desde el inventario sin feedback visual.
	if item_type == "clothing":
		equip_clothing(item_name, item.get_meta("clothing_color", Color.TRANSPARENT), item)
		return
	if item_type == "medical":
		if held_index != index or hands == null or not hands.has_item_in_hands():
			_select_held_item(index)
			notice.emit("Tienes %s en la mano. Pulsa usar de nuevo para usarlo." % item_name)
			return
	var used: bool = inventory.use_index(index, stats)
	if used:
		stats.changed.emit()
	if used and item_type == "clothing":
		var _inv_color: Color = item.get_meta("clothing_color", Color(0, 0, 0, 0))
		equip_clothing(item_name, _inv_color)
	elif not used:
		_select_held_item(index)

func _on_inventory_changed() -> void:
	if not _held_item_external and inventory != null and _held_item_reference != null:
		var current_index: int = inventory.items.find(_held_item_reference)
		if current_index >= 0:
			held_index = current_index
	_recalculate_carry_capacity()
	_sync_held_item()

#endregion


#region ROPA Y APARIENCIA (PlayerAppearance)
func get_current_clothing_color(item_name: String, slot := "") -> Color:
	if inventory != null:
		# Prefer the item bound to the slot (equipped_slot meta) — a same-named
		# packed copy could carry a different loot color.
		if not slot.is_empty():
			for it in inventory.items:
				if it != null and str(it.get_meta("equipped_slot", "")) == slot and str(it.item_name) == item_name and it.has_meta("clothing_color"):
					var sc: Color = it.get_meta("clothing_color")
					if sc.a > 0.0:
						return sc
		for i in range(inventory.items.size()):
			if str(inventory.items[i].item_name) == item_name and inventory.items[i].has_meta("clothing_color"):
				var c: Color = inventory.items[i].get_meta("clothing_color")
				if c.a > 0.0:
					return c
	# Fall back to the character customization color for default clothing that
	# was never explicitly dyed/looted (color lives only in GameSession).
	if item_name in ["Camiseta", "Pantalones", "Zapatillas"]:
		var gsess := get_node_or_null("/root/GameSession")
		if gsess != null:
			if item_name == "Camiseta":
				return gsess.selected_top_color
			elif item_name == "Pantalones":
				return gsess.selected_bottom_color
			elif item_name == "Zapatillas":
				return gsess.selected_shoes_color
	if SURVIVAL_CLOTHING.has(item_name) and SURVIVAL_CLOTHING[item_name].has("tint"):
		return SURVIVAL_CLOTHING[item_name]["tint"]
	return Color(0, 0, 0, 0)

func equip_clothing(item_name: String, clothing_color: Color = Color(0, 0, 0, 0), source_item = null, pelt_species: String = "") -> void:
	var slot := ""
	if CLOTHING_SLOTS.has(item_name):
		slot = CLOTHING_SLOTS[item_name]
	# The crafted garment keeps the hide of the animal it was made from:
	# "Chaqueta de piel" sewn from wolf pelts wears the wolf's fur. The species
	# travels on the item's `pelt_species` meta (craft → save → drop → puppet).
	var species := pelt_species
	if species.is_empty() and source_item != null:
		species = str(source_item.get_meta("pelt_species", ""))
	if species.is_empty() and inventory != null:
		for it in inventory.items:
			if it != null and str(it.item_name) == item_name and it.has_meta("pelt_species"):
				species = str(it.get_meta("pelt_species"))
				break
	_active_pelt_species = species
	if item_name in GameConst.PELT_FUR_ITEMS:
		_equipped_pelt[item_name] = species
	# Unequip previous item in the same slot and drop it on the ground
	if not slot.is_empty() and _equipped_slots.get(slot, "") != item_name:
		var prev_name := str(_equipped_slots.get(slot, ""))
		if not prev_name.is_empty() and prev_name != item_name:
			var prev_color := get_current_clothing_color(prev_name)
			set_meta("last_dropped_camo", clothing_has_camo(prev_name))
			var prev_init := _initializing
			_initializing = true
			unequip_clothing(prev_name)
			_initializing = prev_init
			# Remove old clothing from inventory and drop it on the ground
			if inventory != null:
				for i in range(inventory.items.size()):
					if str(inventory.items[i].item_name) == prev_name:
						set_meta("last_dropped_wetness", float(inventory.items[i].wetness))
						set_meta("last_dropped_pelt", str(inventory.items[i].get_meta("pelt_species", "")))
						inventory.remove_index(i)
						break
			var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
			drop_pos.y = global_position.y
			item_dropped.emit(prev_name, "clothing", 0.5, 1, 0.1, drop_pos, prev_color, false, 0.0)
	equipped_clothing = item_name
	# Determine if all clothing slots will be equipped after this item
	var equipped_check := _equipped_slots.duplicate()
	if CLOTHING_SLOTS.has(item_name):
		equipped_check[CLOTHING_SLOTS[item_name]] = item_name
	var all_equipped := not str(equipped_check.get("torso", "")).is_empty() \
		and not str(equipped_check.get("legs", "")).is_empty() \
		and not str(equipped_check.get("feet", "")).is_empty()
	# Check if any survival clothing with skin_hides is equipped — if so, we can't
	# use _full_body_mesh because it shows bare skin that can't be selectively hidden.
	var has_survival_skin_hide := false
	for equipped_item in equipped_check.values():
		var eitem := str(equipped_item)
		if SURVIVAL_CLOTHING.has(eitem) and not SURVIVAL_CLOTHING[eitem]["skin_hides"].is_empty():
			has_survival_skin_hide = true
			break
	if all_equipped and not has_survival_skin_hide and not is_custom_character:
		if _full_body_mesh != null:
			_full_body_mesh.visible = false
		if _body_no_head_mesh != null:
			_body_no_head_mesh.visible = false
		if _head_mesh != null:
			_head_mesh.visible = true
		for dn in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
			var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
			if dmi != null:
				dmi.visible = false
		# Show individual Body_* parts from player_with_clothes.glb
		for bn in ["Body_torso", "Body_arms", "Body_hands", "Body_legs", "Body_feet"]:
			var bmi: MeshInstance3D = _find_mesh_in_third_person(bn)
			if bmi != null:
				bmi.visible = true
		# Hide Body_* parts covered by equipped clothing (e.g. Body_feet for Zapatillas)
		for equipped_item in equipped_check.values():
			var eitem := str(equipped_item)
			if DEFAULT_BODY_HIDES.has(eitem):
				for body_name in DEFAULT_BODY_HIDES[eitem]:
					var body_mi: MeshInstance3D = _find_mesh_in_third_person(body_name)
					if body_mi != null:
						body_mi.visible = false
	else:
		if _full_body_mesh != null:
			_full_body_mesh.visible = false
			_tint_mesh(_full_body_mesh, _char_skin_color, 0.9)
		if _body_no_head_mesh != null:
			_body_no_head_mesh.visible = false
		if _head_mesh != null:
			_head_mesh.visible = true
		for dn in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
			var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
			if dmi != null:
				dmi.visible = true
		# Hide all Body_* parts — they overlap with Desnudo_*
		for bn in ["Body_torso", "Body_arms", "Body_hands", "Body_legs", "Body_feet"]:
			var bmi: MeshInstance3D = _find_mesh_in_third_person(bn)
			if bmi != null:
				bmi.visible = false
		# Restore Body_legs/Body_feet for default clothing still equipped in those slots
		for slot_key in ["legs", "feet"]:
			var slot_item := str(equipped_check.get(slot_key, ""))
			if DEFAULT_CLOTHING.has(slot_item):
				var body_name: String = DEFAULT_CLOTHING[slot_item]
				var body_mi: MeshInstance3D = _survival_body_nodes.get(body_name)
				if body_mi != null:
					body_mi.visible = true
				# Also restore the Body_* part for this slot unless DEFAULT_BODY_HIDES lists it
				var body_part: String = "Body_" + slot_key
				var hide_it := false
				if DEFAULT_BODY_HIDES.has(slot_item):
					for hn in DEFAULT_BODY_HIDES[slot_item]:
						if str(hn) == body_part:
							hide_it = true
							break
				if not hide_it:
					var bpmi: MeshInstance3D = _find_mesh_in_third_person(body_part)
					if bpmi != null:
						bpmi.visible = true
		for equipped_item in equipped_check.values():
			var eitem := str(equipped_item)
			if DEFAULT_SKIN_HIDES.has(eitem):
				for skin_name in DEFAULT_SKIN_HIDES[eitem]:
					var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
					if skin_mi != null:
						skin_mi.visible = false
	if DEFAULT_CLOTHING.has(item_name):
		var bn: MeshInstance3D = _survival_body_nodes.get(DEFAULT_CLOTHING[item_name])
		if bn != null:
			bn.visible = true
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = false
		if DEFAULT_BODY_HIDES.has(item_name):
			for body_name in DEFAULT_BODY_HIDES[item_name]:
				var body_mi: MeshInstance3D = _find_mesh_in_third_person(body_name)
				if body_mi != null:
					body_mi.visible = false
		# Apply loot color to the clothing mesh if provided
		if clothing_color.a > 0.0 and bn != null:
			bn.material_override = _clothing_material_for(bn.name, clothing_color)
	elif SURVIVAL_CLOTHING.has(item_name):
		_wear_survival_clothing(item_name, true, clothing_color)
	else:
		_wear_clothing_visual(item_name, clothing_color)
	if not slot.is_empty():
		_equipped_slots[slot] = item_name
		# Vincula la prenda equipada con su Item para que su humedad propia
		# alimente la humedad efectiva (ropa seca = menos enfriamiento).
		var item_ref = source_item
		if item_ref == null and inventory != null:
			for it in inventory.items:
				if it != null and str(it.item_name) == item_name and str(it.get_meta("equipped_slot", "")) == "":
					item_ref = it
					break
		if item_ref != null:
			item_ref.set_meta("equipped_slot", slot)
			# Vestirse con la piel empapada traspasa algo de humedad a la ropa.
			item_ref.wetness = maxf(float(item_ref.wetness), wetness * 0.35)
			if stats != null:
				stats.wetness = _effective_wetness()
		# Equipping a tactical vest guarantees its 5 magazines (25 rounds) of
		# rifle reserve unless it was already drained/dropped by a player.
		if item_name == "Chaleco táctico" and not is_puppet and not _initializing:
			var already_granted := item_ref != null and bool(item_ref.get_meta("vest_mags_granted", false))
			var from_player_drop := item_ref != null and bool(item_ref.get_meta("player_dropped", false))
			if not already_granted and not from_player_drop:
				var vest_rounds: int = RIFLE_MAG_SIZE * 5
				_rifle_reserve_ammo += vest_rounds
				if item_ref != null:
					item_ref.set_meta("vest_mags_granted", true)
			var mags_count: int = int(ceil(float(_rifle_reserve_ammo) / float(RIFLE_MAG_SIZE)))
			notice.emit("Chaleco táctico equipado: %d cargadores (%d balas) para el fusil [R para recargar]." % [mags_count, _rifle_reserve_ammo])
			var main_v := get_tree().current_scene if is_inside_tree() else null
			if main_v != null and main_v.has_method("_sync_local_player_inventory"):
				main_v.call_deferred("_sync_local_player_inventory")
	# Custom character: show the clothing mesh, hide Desnudo_* for covered zones
	# Skip for survival clothing items — _wear_survival_clothing handles mesh visibility
	if is_custom_character and not slot.is_empty() and not SURVIVAL_CLOTHING.has(item_name):
		var cloth_mi := _find_custom_slot_mesh(slot)
		if cloth_mi != null:
			cloth_mi.visible = true
			if clothing_color.a > 0.0:
				cloth_mi.material_override = _clothing_material_for(cloth_mi.name, clothing_color)
		# Hide Desnudo_* parts covered by this clothing item
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = false
	if DEFAULT_CLOTHING.has(item_name):
		var cloth_node: MeshInstance3D = _survival_body_nodes.get(DEFAULT_CLOTHING[item_name])
		var camo := clothing_has_camo(item_name, source_item)
		if cloth_node != null and camo:
			var material := _clothing_material_for(str(cloth_node.name), Color.WHITE)
			material.albedo_texture = _make_camo_texture()
			cloth_node.material_override = material
		if source_item != null:
			source_item.set_meta("clothing_camo", camo)
	_recalculate_carry_capacity()
	_recalculate_warmth()
	_recalculate_heat_protection()
	_sync_held_item()
	if inventory != null:
		inventory.changed.emit()

func unequip_clothing(item_name: String) -> void:
	var slot := ""
	if CLOTHING_SLOTS.has(item_name):
		slot = CLOTHING_SLOTS[item_name]
	if DEFAULT_CLOTHING.has(item_name):
		var bn: MeshInstance3D = _survival_body_nodes.get(DEFAULT_CLOTHING[item_name])
		if bn != null:
			bn.visible = false
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = true
		if DEFAULT_BODY_HIDES.has(item_name):
			for body_name in DEFAULT_BODY_HIDES[item_name]:
				var body_mi: MeshInstance3D = _find_mesh_in_third_person(body_name)
				if body_mi != null:
					body_mi.visible = false
	if SURVIVAL_CLOTHING.has(item_name):
		_wear_survival_clothing(item_name, false)
		if item_name in ["Gorra militar", "Gorro de otoño"]:
			preload("res://scripts/HeadwearFit.gd").restore_hair_mesh(third_person_model)
	# Remove the attached 3D garment visual (vests, hat, rubber boots, gloves)
	# so swapping two visual garments in the same slot doesn't leave the old one
	# stuck on the character.
	if CLOTHING_VISUALS.has(item_name) and third_person_model != null:
		var worn := third_person_model.get_node_or_null("Worn_" + item_name)
		if worn != null:
			worn.free()
		_head_worn_rel.erase("Worn_" + item_name)
		match CLOTHING_SLOTS.get(item_name, ""):
			"head":
				# Hats tuck the hair; a balaclava still equipped keeps it hidden.
				preload("res://scripts/HeadwearFit.gd").restore_hair_mesh(third_person_model)
			"face":
				# Balaclavas hide the hair; a hat still equipped keeps it tucked.
				preload("res://scripts/HeadwearFit.gd").restore_hair_visible(third_person_model)
	if CLOTHING_SLOTS.has(item_name):
		if _equipped_slots.get(slot, "") == item_name:
			_equipped_slots.erase(slot)
		_equipped_pelt.erase(item_name)
		if inventory != null:
			for it in inventory.items:
				if it != null and str(it.item_name) == item_name and str(it.get_meta("equipped_slot", "")) == slot:
					it.remove_meta("equipped_slot")
					break
		if stats != null:
			stats.wetness = _effective_wetness()
	if equipped_clothing == item_name:
		equipped_clothing = ""
	_recalculate_carry_capacity()
	_recalculate_warmth()
	_recalculate_heat_protection()
	# Hide _full_body_mesh, show _head_mesh (face stays visible).
	# Show Desnudo_* for exposed areas.
	var hide_legs := not (_equipped_slots.has("legs") and not str(_equipped_slots["legs"]).is_empty())
	var hide_torso := not (_equipped_slots.has("torso") and not str(_equipped_slots["torso"]).is_empty())
	if _full_body_mesh != null:
		_full_body_mesh.visible = false
		var fbmat := StandardMaterial3D.new()
		fbmat.albedo_color = _char_skin_color
		fbmat.roughness = 0.9
		_full_body_mesh.material_override = fbmat
	if _body_no_head_mesh != null:
		_body_no_head_mesh.visible = false
	if _head_mesh != null:
		_head_mesh.visible = true
	# Hide all Body_* parts — they overlap with Desnudo_* and _body_no_head_mesh
	for bn in ["Body_torso", "Body_arms", "Body_hands", "Body_legs", "Body_feet"]:
		var bmi: MeshInstance3D = _find_mesh_in_third_person(bn)
		if bmi != null:
			bmi.visible = false
	# Show all Desnudo_* parts (naked skin)
	for dn in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
		var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
		if dmi != null:
			dmi.visible = true
	# Hide Desnudo_* parts that are covered by still-equipped clothing
	for equipped_item in _equipped_slots.values():
		var eitem := str(equipped_item)
		if DEFAULT_SKIN_HIDES.has(eitem):
			for skin_name in DEFAULT_SKIN_HIDES[eitem]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = false
	# Restore Body_* parts and survival clothing for still-equipped DEFAULT_CLOTHING items
	for slot_key in ["legs", "feet", "torso"]:
		var slot_item := str(_equipped_slots.get(slot_key, ""))
		if DEFAULT_CLOTHING.has(slot_item):
			var body_name: String = DEFAULT_CLOTHING[slot_item]
			var body_mi: MeshInstance3D = _survival_body_nodes.get(body_name)
			if body_mi != null:
				body_mi.visible = true
			var body_part: String = "Body_" + slot_key
			var hide_it := false
			if DEFAULT_BODY_HIDES.has(slot_item):
				for hn in DEFAULT_BODY_HIDES[slot_item]:
					if str(hn) == body_part:
						hide_it = true
						break
			if not hide_it:
				var bpmi: MeshInstance3D = _find_mesh_in_third_person(body_part)
				if bpmi != null:
					bpmi.visible = true
	# Custom character: hide the clothing mesh, show Desnudo_* for uncovered zones
	# Skip for survival clothing items — _wear_survival_clothing handles mesh visibility
	if is_custom_character and not slot.is_empty() and not SURVIVAL_CLOTHING.has(item_name):
		var cloth_mi := _find_custom_slot_mesh(slot)
		if cloth_mi != null:
			cloth_mi.visible = false
		# Show Desnudo_* parts that were covered by this clothing item
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = true
	# If torso is still equipped, _head_mesh shows nothing below head,
	# so we need Desnudo_arms/hands for arms
	# (they're already shown above and not hidden by Camiseta's SKIN_HIDES)
	if inventory != null:
		inventory.changed.emit()

# Caches the deformable survival garment meshes inside the adapted model and
# hides them all (they are revealed one by one as the player equips them).
func _refine_character_arms() -> void:
	if is_custom_character:
		return
	var arms := _find_mesh_in_third_person("Desnudo_arms")
	if arms == null or arms.has_meta("refined_elbows"):
		return
	if not ResourceLoader.exists("res://assets/characters/adapted/arms_refined.glb"):
		return
	var scene: PackedScene = load("res://assets/characters/adapted/arms_refined.glb")
	if scene == null:
		return
	var source := scene.instantiate()
	var nodes: Array[Node] = [source]
	while not nodes.is_empty():
		var node := nodes.pop_back() as Node
		nodes.append_array(node.get_children())
		if node is MeshInstance3D and node.name == "Desnudo_arms":
			# Preserve the character's skin material, visibility and attachment.
			var skin_material := arms.get_active_material(0)
			arms.mesh = node.mesh
			arms.skin = node.skin
			arms.set_surface_override_material(0, skin_material)
			arms.set_meta("refined_elbows", true)
			break
	source.free()

func _init_survival_clothing(root: Node) -> void:
	_refine_character_arms()
	_survival_cloth_nodes.clear()
	_survival_body_nodes.clear()
	var wanted := {}
	for name in SURVIVAL_CLOTHING:
		wanted[String(SURVIVAL_CLOTHING[name]["mesh"])] = true
	var body_names := {}
	for name in SURVIVAL_CLOTHING:
		for h in SURVIVAL_CLOTHING[name]["hides"]:
			body_names[String(h)] = true
	for dname in DEFAULT_CLOTHING:
		body_names[String(DEFAULT_CLOTHING[dname])] = true
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.name == "soldier_torso":
				MilitaryJackets.fit_legacy_hem(mi)
			if str(mi.name).begins_with("military_boots_"):
				mi.hide()
			if wanted.has(mi.name):
				_survival_cloth_nodes[mi.name] = mi
				mi.visible = false
				if mi.name == "cloth_hands" or mi.name == "cloth_feet":
					mi.material_override = _clothing_material_for(mi.name, Color(0.05, 0.05, 0.05))
			elif body_names.has(mi.name):
				_survival_body_nodes[mi.name] = mi
				mi.visible = false
				if mi.name == "Shoes":
					mi.material_override = _clothing_material_for("Shoes", Color(0.85, 0.82, 0.78))
		for c in node.get_children():
			stack.append(c)
	# Hide all Desnudo_* parts at init (character starts clothed)
	# EXCEPT Desnudo_arms and Desnudo_hands (leftturn Body_arms/hands have built-in gloves)
	var skin_names := ["Desnudo_legs", "Desnudo_feet"]
	for sn in skin_names:
		var smi: MeshInstance3D = _find_mesh_in_third_person(sn)
		if smi != null:
			smi.visible = false
	# Body_arms and Body_hands from leftturn have built-in gloves, always hide them
	# soldier_hands is also always hidden (not used, would show as gloves)
	for bn in ["Body_arms", "Body_hands", "soldier_hands", "soldier_feet"]:
		var bmi: MeshInstance3D = _find_mesh_in_third_person(bn)
		if bmi != null:
			bmi.visible = false
	# Body_torso includes the neck, always show it under clothing
	var bt: MeshInstance3D = _find_mesh_in_third_person("Body_torso")
	if bt != null:
		bt.visible = true
	# Always show Desnudo_arms and Desnudo_hands as the bare skin
	for dn in ["Desnudo_arms", "Desnudo_hands"]:
		var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
		if dmi != null:
			dmi.visible = true
	# Add the head/face from inicio.glb (player_with_clothes.glb lacks face geometry)
	_add_head_mesh()

# Maps a clothing mesh to its Blender-baked fabric (jersey shirt, denim pants,
# leather footwear) so the equipped color still tints a detailed material.
func _clothing_material_for(mesh_name: String, color: Color) -> StandardMaterial3D:
	var kind := "denim"
	match mesh_name:
		"Tops":
			kind = "top"
		"Bottoms":
			kind = "bottom"
		"Shoes":
			kind = "shoes"
		"soldier_legs", "soldier_torso":
			kind = "soldier"
		"cloth_hands":
			kind = "gloves"
		"cloth_feet":
			kind = "boots"
		"military_boots":
			kind = "mboots"
		"Ch42_Shirt":
			kind = "jersey"
		"Ch42_Sneakers":
			kind = "leather"
	# The jacket sits over the waistband like a shirt; the pants must stay flat
	# so their belt/holster geometry doesn't poke through the garment above.
	var grow := -999.0
	if mesh_name == "soldier_torso":
		grow = 0.015
	elif mesh_name == "soldier_legs":
		grow = -0.5
	return MaterialFactory.make_clothing_material(kind, color, grow)

# Sync label for the equipped_clothing CSV: pelt garments append "|species" so
# remote puppets render the same animal hide (wolf jacket, deer tocado...).
func clothing_sync_label(item_name: String) -> String:
	var species := str(_equipped_pelt.get(item_name, ""))
	return item_name + "|" + species if not species.is_empty() else item_name

# Fur of the hunted species projected over the garment mesh — shared with the
# world drops and the saved-character preview via MaterialFactory.
func _pelt_fur_material(species: String) -> Material:
	return MaterialFactory.pelt_fur_material(species)

# Applies the selected character's colors (clothing, hair, skin) to the
# player_with_clothes.glb meshes. Colors are read from GameSession.
func _apply_character_colors() -> void:
	var top_color := Color(0.5, 0.5, 0.5)
	var bottom_color := Color(0.3, 0.3, 0.3)
	var shoes_color := Color(0.15, 0.15, 0.15)
	var hair_color := Color(0.2, 0.15, 0.1)
	var skin_color := Color(0.8, 0.7, 0.6)
	var top_camo := false
	var bottom_camo := false
	var gs := get_node_or_null("/root/GameSession")
	if gs != null:
		top_color = gs.selected_top_color
		bottom_color = gs.selected_bottom_color
		shoes_color = gs.selected_shoes_color
		hair_color = gs.selected_hair_color
		skin_color = gs.selected_skin_color
		top_camo = gs.get_meta("top_camo", false) if gs.has_meta("top_camo") else false
		bottom_camo = gs.get_meta("bottom_camo", false) if gs.has_meta("bottom_camo") else false
	# Apply Tops — reutilizar material cacheado
	var top_mi: MeshInstance3D = _find_mesh_in_third_person("Tops")
	if top_mi != null:
		var tmat: StandardMaterial3D = _skin_mat_cache.get("char_top") as StandardMaterial3D
		if tmat == null:
			tmat = StandardMaterial3D.new()
			tmat.roughness = 0.8
			_skin_mat_cache["char_top"] = tmat
		if top_camo:
			if tmat.albedo_texture == null:
				tmat.albedo_texture = _make_camo_texture()
				tmat.albedo_color = Color.WHITE
				MaterialFactory.cloth_detail(tmat, "jersey")
			top_mi.material_override = tmat
		else:
			top_mi.material_override = MaterialFactory.make_clothing_material("top", top_color)
	# Apply Bottoms
	var bot_mi: MeshInstance3D = _find_mesh_in_third_person("Bottoms")
	if bot_mi != null:
		var bmat: StandardMaterial3D = _skin_mat_cache.get("char_bot") as StandardMaterial3D
		if bmat == null:
			bmat = StandardMaterial3D.new()
			bmat.roughness = 0.8
			_skin_mat_cache["char_bot"] = bmat
		if bottom_camo:
			if bmat.albedo_texture == null:
				bmat.albedo_texture = _make_camo_texture()
				bmat.albedo_color = Color.WHITE
				MaterialFactory.cloth_detail(bmat, "denim")
			bot_mi.material_override = bmat
		else:
			bot_mi.material_override = MaterialFactory.make_clothing_material("bottom", bottom_color)
	# Apply Shoes
	var shoes_mi: MeshInstance3D = _find_mesh_in_third_person("Shoes")
	if shoes_mi != null:
		shoes_mi.material_override = MaterialFactory.make_clothing_material("shoes", shoes_color)
	# Apply skin color to Desnudo_* (bare skin) and Body_* (base body). The skin
	# shrinks ~8 mm so its surface never pokes through the tight clothing meshes
	# (the painted underwear in the source body texture showed as a dark belly
	# patch where the shirt hugs the torso).
	for body_name in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet",
			"Body_torso", "Body_arms", "Body_hands", "Body_legs", "Body_feet"]:
		var bmi: MeshInstance3D = _find_mesh_in_third_person(body_name)
		_tint_mesh(bmi, skin_color, 0.9, -0.008)
	# Apply hair color to Hair mesh if it exists in the model
	var hair_mi: MeshInstance3D = _find_mesh_in_third_person("Hair")
	_tint_mesh(hair_mi, hair_color, 0.8)
	# Apply skin color to head mesh (face)
	_tint_mesh(_head_mesh, skin_color, 0.9)
	_tint_mesh(_full_body_mesh, skin_color, 0.9)
	_tint_mesh(_body_no_head_mesh, skin_color, 0.9)
	# Store colors so they can be re-applied after unequip
	_char_top_color = top_color
	_char_bottom_color = bottom_color
	_char_shoes_color = shoes_color
	_char_hair_color = hair_color
	_char_skin_color = skin_color

var _char_top_color: Color = Color(0.5, 0.5, 0.5)
var _char_bottom_color: Color = Color(0.3, 0.3, 0.3)
var _char_shoes_color: Color = Color(0.15, 0.15, 0.15)
var _char_hair_color: Color = Color(0.2, 0.15, 0.1)
var _char_skin_color: Color = Color(0.8, 0.7, 0.6)

func _make_camo_texture(base_color: Color = Color(0.25, 0.3, 0.15)) -> Texture2D:
	return MaterialFactory.make_camo_texture(base_color)

func _skeleton_height(skel: Skeleton3D) -> float:
	if skel == null:
		return 0.0
	var min_y := 1e9
	var max_y := -1e9
	for i in range(skel.get_bone_count()):
		var gp := skel.get_bone_global_pose(i)
		min_y = min(min_y, gp.origin.y)
		max_y = max(max_y, gp.origin.y)
	return max_y - min_y

func _tint_mesh(mi: MeshInstance3D, color: Color, roughness: float = 0.9, shrink: float = 0.0) -> void:
	if mi == null:
		return
	var orig := mi.get_active_material(0)
	var mat: StandardMaterial3D
	if orig != null and orig is StandardMaterial3D:
		mat = (orig as StandardMaterial3D).duplicate()
		mat.albedo_color = color
		mat.roughness = roughness
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
	if shrink != 0.0:
		mat.grow = true
		mat.grow_amount = shrink
	mi.material_override = mat

func _find_mesh_in_third_person(mesh_name: String) -> MeshInstance3D:
	if third_person_model == null:
		return null
	var stack: Array = [third_person_model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and node.name == mesh_name:
			return node as MeshInstance3D
		for c in node.get_children():
			stack.append(c)
	return null

func _find_custom_slot_mesh(slot: String) -> MeshInstance3D:
	if not CUSTOM_SLOT_MESHES.has(slot):
		return null
	for mesh_name in CUSTOM_SLOT_MESHES[slot]:
		var mi := _find_mesh_in_third_person(mesh_name)
		if mi != null:
			return mi
	return null

func _find_custom_body_mesh() -> MeshInstance3D:
	for body_name in CUSTOM_BODY_MESHES:
		var mi := _find_mesh_in_third_person(body_name)
		if mi != null:
			return mi
	return null

# Loads the Desnudo_* meshes from player_with_clothes.glb and attaches them
# to the custom character's skeleton so the existing equip/unequip Desnudo_*
# logic works identically for custom characters.
func _create_custom_desnudo_meshes(character_scale: float = 1.0) -> void:
	if third_person_model == null:
		return
	# Use the custom model's own Body as the nude body
	var body_mi := _find_custom_body_mesh()
	if body_mi != null:
		_full_body_mesh = body_mi
		_full_body_mesh.visible = true
	var src_path := GameConst.PLAYER_MODEL
	var src_scene: Node = load(src_path).instantiate()
	if src_scene == null:
		return
	var dst_skel: Skeleton3D = _find_skeleton(third_person_model)
	if dst_skel == null:
		src_scene.free()
		return
	var src_skel: Skeleton3D = _find_skeleton(src_scene)
	if src_skel == null:
		src_scene.free()
		return
	# Custom Body mesh is the head/face; the rest of the body is missing.
	# Clone Desnudo_* from player_with_clothes.glb and build a HeadMesh from Body.
	var desnudo_names := ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]
	var src_meshes: Dictionary = {}
	var stack: Array = [src_scene]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and n.name in desnudo_names:
			src_meshes[n.name] = n
		for c in n.get_children():
			stack.append(c)
	# Build bone name -> index map for destination skeleton
	var dst_bone_map: Dictionary = {}
	for i in range(dst_skel.get_bone_count()):
		dst_bone_map[dst_skel.get_bone_name(i)] = i
	# The source and destination meshes are in the same unit system
	# (Desnudo width 0.82 vs Remy Bottoms width 0.82). Vertices don't need scaling.
	# Bind pose = inverse(dst_bone_rest) for correct skinning on destination skeleton.
	var scale_factor := 1.0
	var src_height := _skeleton_height(src_skel)
	var dst_height := _skeleton_height(dst_skel)
	for desnudo_name in desnudo_names:
		if not src_meshes.has(desnudo_name):
			continue
		var src_mi: MeshInstance3D = src_meshes[desnudo_name]
		var clone := MeshInstance3D.new()
		var src_mesh: ArrayMesh = src_mi.mesh
		if src_mesh != null:
			var scaled_mesh := ArrayMesh.new()
			for surf_idx in range(src_mesh.get_surface_count()):
				var arrays := src_mesh.surface_get_arrays(surf_idx)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for vi in range(verts.size()):
					verts[vi] *= scale_factor
				arrays[Mesh.ARRAY_VERTEX] = verts
				scaled_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				scaled_mesh.surface_set_material(surf_idx, src_mesh.surface_get_material(surf_idx))
			clone.mesh = scaled_mesh
		clone.name = desnudo_name
		clone.visible = false
		if src_mi.skin != null:
			var new_skin := Skin.new()
			var src_skin: Skin = src_mi.skin
			var bone_count := src_skin.get_bind_count()
			var matched := 0
			var unmatched := 0
			for bi in range(bone_count):
				var bind_bone := src_skin.get_bind_bone(bi)
				var bone_name: StringName = src_skin.get_bind_name(bi)
				if bind_bone >= 0:
					bone_name = src_skel.get_bone_name(bind_bone)
				if bone_name.is_empty():
					continue
				var dst_bone_idx: int = dst_bone_map.get(bone_name, -1)
				if dst_bone_idx < 0:
					unmatched += 1
					if unmatched <= 3:
						pass
					continue
				matched += 1
				var src_bind_pose := src_skin.get_bind_pose(bi)
				# Source skin bind poses are in cm (basis has 100x scale, origin in cm)
				# Scale entire transform by 0.01 to convert to meters
				var scaled_bind := Transform3D(src_bind_pose.basis * 0.01, src_bind_pose.origin * 0.01)
				new_skin.add_bind(dst_bone_idx, scaled_bind)
			clone.skin = new_skin
		dst_skel.add_child(clone)
		clone.skeleton = dst_skel.get_path()

	# --- Clone survival clothing meshes (cloth_*) from player_with_clothes.glb ---
	var survival_mesh_names := ["cloth_hands", "cloth_feet", "military_boots"]
	var src_survival_meshes: Dictionary = {}
	var sstack: Array = [src_scene]
	while not sstack.is_empty():
		var sn: Node = sstack.pop_back()
		if sn is MeshInstance3D and sn.name in survival_mesh_names:
			src_survival_meshes[sn.name] = sn
		for sc in sn.get_children():
			sstack.append(sc)
	for smesh_name in survival_mesh_names:
		if not src_survival_meshes.has(smesh_name):
			continue
		var s_mi: MeshInstance3D = src_survival_meshes[smesh_name]
		var s_clone := MeshInstance3D.new()
		var s_src_mesh: ArrayMesh = s_mi.mesh
		if s_src_mesh != null:
			s_clone.mesh = s_src_mesh
		s_clone.name = smesh_name
		s_clone.visible = false
		if s_mi.skin != null:
			var s_new_skin := Skin.new()
			var s_src_skin: Skin = s_mi.skin
			var s_matched := 0
			var s_unmatched := 0
			for bi in range(s_src_skin.get_bind_count()):
				var s_bind_bone := s_src_skin.get_bind_bone(bi)
				var s_bone_name: StringName = s_src_skin.get_bind_name(bi)
				if s_bind_bone >= 0:
					s_bone_name = src_skel.get_bone_name(s_bind_bone)
				if s_bone_name.is_empty():
					s_unmatched += 1
					continue
				var s_dst_idx: int = dst_bone_map.get(s_bone_name, -1)
				if s_dst_idx < 0:
					s_unmatched += 1
					continue
				s_matched += 1
				var s_bind := s_src_skin.get_bind_pose(bi)
				var s_scaled_bind := Transform3D(s_bind.basis * 0.01, s_bind.origin * 0.01)
				s_new_skin.add_bind(s_dst_idx, s_scaled_bind)
			s_clone.skin = s_new_skin
		dst_skel.add_child(s_clone)
		s_clone.skeleton = dst_skel.get_path()
		_survival_cloth_nodes[smesh_name] = s_clone

	# --- Clone soldier meshes (soldier_*) from player_with_clothes.glb ---
	# These meshes are already in src_scene with correct scale and same skin as survival
	var soldier_mesh_names := ["soldier_torso", "soldier_legs", "soldier_hands", "soldier_feet"]
	var src_soldier_meshes: Dictionary = {}
	var sol_stack: Array = [src_scene]
	while not sol_stack.is_empty():
		var soln: Node = sol_stack.pop_back()
		if soln is MeshInstance3D and soln.name in soldier_mesh_names:
			src_soldier_meshes[soln.name] = soln
		for solc in soln.get_children():
			sol_stack.append(solc)
	for sol_mesh_name in soldier_mesh_names:
		if not src_soldier_meshes.has(sol_mesh_name):
			continue
		var sol_mi: MeshInstance3D = src_soldier_meshes[sol_mesh_name]
		var sol_clone := MeshInstance3D.new()
		var sol_src_mesh: ArrayMesh = sol_mi.mesh
		if sol_src_mesh != null:
			sol_clone.mesh = sol_src_mesh
		sol_clone.name = sol_mesh_name + "_001"
		sol_clone.visible = false
		if sol_mi.skin != null:
			var sol_new_skin := Skin.new()
			var sol_src_skin: Skin = sol_mi.skin
			var sol_matched := 0
			var sol_unmatched := 0
			for bi in range(sol_src_skin.get_bind_count()):
				var sol_bind_bone := sol_src_skin.get_bind_bone(bi)
				var sol_bone_name: StringName = sol_src_skin.get_bind_name(bi)
				if sol_bind_bone >= 0:
					sol_bone_name = src_skel.get_bone_name(sol_bind_bone)
				if sol_bone_name.is_empty():
					sol_unmatched += 1
					continue
				var sol_dst_idx: int = dst_bone_map.get(sol_bone_name, -1)
				if sol_dst_idx < 0:
					sol_unmatched += 1
					continue
				sol_matched += 1
				var sol_bind := sol_src_skin.get_bind_pose(bi)
				var sol_scaled_bind := Transform3D(sol_bind.basis * 0.01, sol_bind.origin * 0.01)
				sol_new_skin.add_bind(sol_dst_idx, sol_scaled_bind)
			sol_clone.skin = sol_new_skin
		dst_skel.add_child(sol_clone)
		sol_clone.skeleton = dst_skel.get_path()
		var cloth_key: String = sol_mesh_name
		_survival_cloth_nodes[cloth_key] = sol_clone

	# Also cache the custom character's built-in body meshes as _survival_body_nodes
	# Split the custom Body so only the head remains visible; Desnudo_* cover the rest.
	_add_custom_head_mesh()
	# Hide custom character's built-in clothing meshes — survival clothing replaces them
	for cloth_name in ["Bottoms", "Tops", "Shoes", "Pants", "Shirt", "Jacket", "Dress", "Skirt", "Ch42_Shirt", "Ch42_Shorts", "Ch42_Sneakers"]:
		var cmi: MeshInstance3D = _find_mesh_in_third_person(cloth_name)
		if cmi != null:
			_survival_body_nodes[cloth_name] = cmi
			cmi.visible = false
	src_scene.free()

func _wear_survival_clothing(item_name: String, worn: bool, loot_color: Color = Color(0, 0, 0, 0)) -> void:
	if not SURVIVAL_CLOTHING.has(item_name):
		return
	if item_name in ["Chaqueta de otoño", "Chaqueta militar digital"]:
		AutumnClothes.set_jacket_mask(third_person_model, worn)
	var cfg: Dictionary = SURVIVAL_CLOTHING[item_name]
	var mesh_name := String(cfg["mesh"])
	var mi: MeshInstance3D = _survival_cloth_nodes.get(mesh_name)
	if mi == null and worn and MilitaryJackets.VARIANTS.has(item_name):
		mi = MilitaryJackets.attach(third_person_model, item_name)
		if mi != null:
			_survival_cloth_nodes[mesh_name] = mi
	if mi == null and worn and AutumnClothes.VARIANTS.has(item_name):
		mi = AutumnClothes.attach(third_person_model, item_name)
		if mi != null:
			_survival_cloth_nodes[mesh_name] = mi
	# The fur jacket rides on the olive field-jacket mesh; attach it lazily so
	# it renders even when no campaign jacket created that node first.
	if mi == null and worn and item_name == "Chaqueta de piel":
		mi = MilitaryJackets.attach(third_person_model, "Chaqueta de campaña verde")
		if mi != null:
			_survival_cloth_nodes[mesh_name] = mi
	if mi != null:
		mi.visible = worn
		if worn and item_name in ["Gorra militar", "Gorro de otoño"]:
			preload("res://scripts/HeadwearFit.gd").tuck_hair_under_skinned_cap(third_person_model, mi)
		if MilitaryJackets.VARIANTS.has(item_name) or AutumnClothes.VARIANTS.has(item_name):
			# Preserve the distinct cloth, cuff and metal surfaces authored in Blender.
			mi.material_override = null
		elif worn and item_name in GameConst.PELT_FUR_ITEMS and not str(_equipped_pelt.get(item_name, _active_pelt_species)).is_empty():
			# Una prenda de piel recogida del suelo llega con clothing_color (el
			# tinte plano del drop): el pelaje de SU especie siempre manda.
			mi.material_override = _pelt_fur_material(str(_equipped_pelt.get(item_name, _active_pelt_species)))
		elif worn and loot_color.a > 0.0 and not cfg.has("camo"):
			mi.material_override = _clothing_material_for(mesh_name, loot_color)
		elif worn and cfg.has("camo"):
			var mat := StandardMaterial3D.new()
			mat.albedo_texture = _make_camo_texture(cfg["camo"])
			mat.albedo_color = Color.WHITE
			MaterialFactory.cloth_detail(mat, "soldier")
			if mesh_name == "soldier_torso":
				mat.grow = true
				mat.grow_amount = 0.015
			mi.material_override = mat
		elif worn and cfg.has("tint"):
			mi.material_override = _clothing_material_for(mesh_name, cfg["tint"])
		elif worn:
			if mesh_name.begins_with("soldier_"):
				mi.material_override = _clothing_material_for(mesh_name, Color(0.15, 0.18, 0.12))
			elif mesh_name == "cloth_hands":
				mi.material_override = _clothing_material_for(mesh_name, Color(0.28, 0.22, 0.15))
			else:
				mi.material_override = null
	# Build reverse map: body mesh name -> default clothing item name
	var _body_to_default := {}
	for dname in DEFAULT_CLOTHING:
		_body_to_default[DEFAULT_CLOTHING[dname]] = dname
	for h in cfg["hides"]:
		var bn: MeshInstance3D = _survival_body_nodes.get(String(h))
		if bn != null:
			if worn:
				bn.visible = false
			else:
				# Only restore the default body mesh if the corresponding
				# default clothing item is actually still equipped.
				var default_item: String = String(_body_to_default.get(String(h), ""))
				var slot: String = String(CLOTHING_SLOTS.get(default_item, ""))
				var equipped: String = String(_equipped_slots.get(slot, "")) if not slot.is_empty() else ""
				bn.visible = equipped == default_item
	_worn_survival[item_name] = worn
	# Hide/show skin meshes (e.g. Desnudo_*) that would clip through clothing
	if cfg.has("skin_hides"):
		for skin_name in cfg["skin_hides"]:
			var skin_mi: MeshInstance3D = _find_mesh_in_third_person(String(skin_name))
			if skin_mi != null:
				skin_mi.visible = not worn
	# Hide the default Body_* parts while the survival garment is worn, so they
	# don't overlap the garment mesh (e.g. Body_feet clipping through cloth_feet).
	if cfg.has("body_hides"):
		for body_name in cfg["body_hides"]:
			var body_mi: MeshInstance3D = _find_mesh_in_third_person(String(body_name))
			if body_mi != null:
				body_mi.visible = not worn
	# Some garments cover skin but still need a base Body_* part underneath
	# (e.g. the jacket covers the chest yet Body_torso provides the neck).
	if cfg.has("body_shows"):
		for body_name in cfg["body_shows"]:
			var body_mi: MeshInstance3D = _find_mesh_in_third_person(String(body_name))
			if body_mi != null:
				body_mi.visible = worn

# Attaches and fits a clothing model onto the body relative to its measured
# bounding box, so the player is visibly wearing it (e.g. the life vest on the
# chest) regardless of the character model's scale/proportions.
func _wear_clothing_visual(item_name: String, loot_color: Color = Color(0, 0, 0, 0)) -> void:
	if third_person_model == null or not CLOTHING_VISUALS.has(item_name):
		return
	var cfg: Dictionary = CLOTHING_VISUALS[item_name]
	var parent := third_person_model
	var worn_name := "Worn_" + item_name
	var previous := parent.get_node_or_null(worn_name)
	if previous != null:
		previous.free()
	# Godot's GLTF importer bakes the Armature transform into the mesh vertex
	# positions at import time, so get_aabb() already returns bounds in the
	# character root's local space.  Using global_transform would re-apply the
	# Armature's +90°X / 0.01 scale and produce a body height of ~7 mm instead
	# of ~3.8 m.  Collect raw AABBs directly instead.
	var body := _baked_aabb(parent, true)
	if body.size.y <= 0.001:
		return
	var node: Node3D = null
	var model_path := str(cfg["path"])
	if item_name == "Tocado de piel animal":
		# The tocado IS the hunted animal: head + draped pelt of the species
		# whose hide went into the recipe (fallback: wolf).
		model_path = str(GameConst.PELT_HEADDRESS.get(_active_pelt_species,
			GameConst.PELT_HEADDRESS[GameConst.PELT_DEFAULT_SPECIES]))
	node = _load_external_node3d(model_path)
	if node == null:
		return
	var face_fit := bool(cfg.get("face_fit", false))
	var external_model := node
	if face_fit:
		node = Node3D.new()
		node.name = worn_name
		external_model.name = "BalaclavaModel"
		_strip_model_lights(external_model)
		_strip_named_meshes(external_model, cfg.get("strip", []))
		parent.add_child(node)
		node.add_child(external_model)
		if not preload("res://scripts/HeadwearFit.gd").fit_face(parent, node, item_name):
			node.queue_free()
			return
	else:
		node.name = worn_name
		_strip_model_lights(node)
		_strip_named_meshes(node, cfg.get("strip", []))
		parent.add_child(node)
		node.rotation_degrees = Vector3(0.0, float(cfg["yaw"]), 0.0)
		var item := _local_aabb_in(parent, node, false)
		if item.size.y > 0.001:
			var target: float = float(cfg["size"]) * body.size.y
			node.scale = Vector3.ONE * (target / item.size.y)
		item = _local_aabb_in(parent, node, false)
		var anchor := Vector3(
			body.position.x + body.size.x * 0.5,
			body.position.y + float(cfg["frac_y"]) * body.size.y,
			body.position.z + body.size.z * 0.5 - float(cfg.get("forward", 0.0)) * body.size.z
		)
		var item_center := item.position + item.size * 0.5
		if str(cfg.get("align", "center")) == "bottom":
			item_center.y = item.position.y
		node.position += anchor - item_center
		node.position += cfg.get("offset", Vector3.ZERO)
		if CLOTHING_SLOTS.get(item_name, "") == "head":
			if item_name == "Tocado de piel animal":
				# Authored with its scalp seat at the GLB origin — sit it on the
				# crown as-is instead of crown-fitting it like a generic hat.
				preload("res://scripts/HeadwearFit.gd").fit_pelt(parent, node, _active_pelt_species)
			else:
				preload("res://scripts/HeadwearFit.gd").fit(parent, node, item_name)
	if clothing_has_camo(item_name):
		var camo_meshes: Array = []
		_collect_mesh_instances(node, camo_meshes)
		for mi in camo_meshes:
			var cmat := StandardMaterial3D.new()
			cmat.albedo_texture = _make_camo_texture()
			cmat.albedo_color = Color.WHITE
			cmat.roughness = 0.9
			mi.material_override = cmat
	else:
		# Pelaje primero: una prenda de piel recogida del suelo trae
		# clothing_color plano, pero la especie siempre manda sobre el tinte.
		var pelt_sp := str(_equipped_pelt.get(item_name, _active_pelt_species))
		var pelt_mat := _pelt_fur_material(pelt_sp) if (item_name in GameConst.PELT_FUR_ITEMS and item_name != "Tocado de piel animal" and not pelt_sp.is_empty()) else null
		var tint: Color = cfg["tint"] if cfg.has("tint") else Color(0, 0, 0, 0)
		var base_col := loot_color if loot_color.a > 0.0 else tint
		if pelt_mat != null or base_col.a > 0.0:
			var meshes: Array = []
			_collect_mesh_instances(node, meshes)
			for mi in meshes:
				if pelt_mat != null:
					mi.material_override = pelt_mat
					continue
				var mat := StandardMaterial3D.new()
				mat.albedo_color = base_col
				mat.roughness = 0.9
				mat.metallic = 0.0
				mi.material_override = mat
	# If this is a head-slot item and we have a head bone, store the relative
	# transform so _update_head_worn_items() can follow the bone each frame.
	# The offset is captured against the bone REST pose, not the current
	# animated pose — the anchor above was computed from the bind-pose AABB,
	# so equipping while crouched/sitting must not bake that pose's offset.
	if CLOTHING_SLOTS.get(item_name, "") in ["head", "face"] and _head_skeleton != null and _head_bone_idx >= 0:
		var bone_rest := _head_skeleton.get_bone_global_rest(_head_bone_idx)
		var skel_global := _head_skeleton.global_transform
		var rest_world := skel_global * bone_rest
		var local_to_model := third_person_model.global_transform.affine_inverse()
		var rest_local := local_to_model * rest_world
		_head_worn_rel[worn_name] = rest_local.affine_inverse() * node.transform
		_update_head_worn_items()

# Body AABB collected directly from get_aabb() without going through
# global_transform.  This is correct for Mixamo GLTF models because the
# GLTF importer bakes the Armature's transform into the vertex positions,
# meaning get_aabb() already returns bounds in the character root's local
# space.  Applying global_transform on top would double-count the Armature.
func _baked_aabb(root: Node, exclude_worn: bool) -> AABB:
	var combined := AABB()
	var has_any := false
	var meshes: Array = []
	_collect_body_meshes(root, meshes, exclude_worn)
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		if not has_any:
			combined = mi.get_aabb()
			has_any = true
		else:
			combined = combined.merge(mi.get_aabb())
	return combined

# AABB of an entire hierarchy expressed in `root`'s own local space, accumulating
# each descendant's local transform. Required for runtime-loaded GLTF models whose
# meshes carry non-identity node transforms (unlike Mixamo models whose armature
# transform is baked into vertices). Does not require the node to be in the tree.
func _hierarchy_local_aabb(root: Node) -> AABB:
	var combined := AABB()
	var has_any := false
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		combined = (root as MeshInstance3D).get_aabb()
		has_any = true
	var stack: Array = []
	for child in root.get_children():
		if child is Node3D:
			stack.append([child, (child as Node3D).transform])
	while not stack.is_empty():
		var entry = stack.pop_back()
		var node: Node3D = entry[0]
		var xform: Transform3D = entry[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var local_aabb: AABB = xform * (node as MeshInstance3D).get_aabb()
			if not has_any:
				combined = local_aabb
				has_any = true
			else:
				combined = combined.merge(local_aabb)
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, xform * (c as Node3D).transform])
	return combined

# AABB of a node's meshes expressed in `frame`'s local space. When `exclude_worn`
# is true, mesh subtrees named "Worn_*" are skipped (used to measure the body).
func _local_aabb_in(frame: Node3D, root: Node, exclude_worn: bool) -> AABB:
	var meshes: Array = []
	_collect_body_meshes(root, meshes, exclude_worn)
	var to_local := frame.global_transform.affine_inverse()
	var combined := AABB()
	var has_any := false
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_aabb: AABB = to_local * (mesh_instance.global_transform * mesh_instance.get_aabb())
		if not has_any:
			combined = local_aabb
			has_any = true
		else:
			combined = combined.merge(local_aabb)
	return combined

func _collect_body_meshes(node: Node, result: Array, exclude_worn: bool) -> void:
	if exclude_worn:
		# Skip everything attached at runtime (worn garments, sockets, held
		# props, fishing-rod overlays, rifle attachments). Their meshes inflate
		# the body AABB — a rod overlay alone pushes the clothing anchor metres
		# above the head.
		var n := String(node.name)
		if n.begins_with("Worn_") or n.begins_with("RodVisual_") or n.begins_with("BoneAttachment") or n.ends_with("Socket"):
			return
		if n in ["RifleSlingRoot", "RifleRoot", "WeaponOffset", "MuzzleFlash"]:
			return
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		_collect_body_meshes(child, result, exclude_worn)

func _strip_named_meshes(root: Node, needles: Array) -> void:
	if needles.is_empty():
		return
	var to_remove: Array = []
	_collect_named_meshes(root, needles, to_remove)
	for node in to_remove:
		if is_instance_valid(node):
			(node as Node).queue_free()

func _collect_named_meshes(node: Node, needles: Array, result: Array) -> void:
	var lower := node.name.to_lower()
	for needle in needles:
		if lower.find(str(needle).to_lower()) >= 0:
			result.append(node)
			return
	for child in node.get_children():
		_collect_named_meshes(child, needles, result)

func _visual_aabb_global(node: Node3D) -> AABB:
	var meshes: Array = []
	_collect_player_meshes(node, meshes)
	var combined := AABB()
	var has_any := false
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		if not has_any:
			combined = world_aabb
			has_any = true
		else:
			combined = combined.merge(world_aabb)
	return combined

func _collect_player_meshes(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		_collect_player_meshes(child, result)

func _strip_model_lights(root: Node) -> void:
	var lights: Array = []
	_collect_lights(root, lights)
	for light in lights:
		if is_instance_valid(light):
			(light as Node).queue_free()

func _collect_lights(node: Node, result: Array) -> void:
	if node is Light3D or node.name.to_lower() == "sun" or node.name.to_lower().begins_with("circle"):
		result.append(node)
		return
	for child in node.get_children():
		_collect_lights(child, result)

func equip_backpack(item_name: String) -> void:
	equipped_backpack = item_name
	if inventory != null:
		var marked := false
		for it in inventory.items:
			if it == null or str(it.item_type) != "backpack":
				continue
			if not marked and not item_name.is_empty() and str(it.item_name) == item_name:
				it.set_meta("equipped_slot", "backpack")
				marked = true
			elif str(it.get_meta("equipped_slot", "")) == "backpack":
				it.remove_meta("equipped_slot")
	_recalculate_carry_capacity()
	_sync_held_item()
	if inventory != null:
		inventory.changed.emit()

func _has_backpack_in_inventory() -> bool:
	if inventory == null:
		return false
	for it in inventory.items:
		if it != null and str(it.item_type) == "backpack":
			return true
	return false

func refresh_carry_capacity() -> void:
	_recalculate_carry_capacity()
	_sync_held_item()

func _recalculate_carry_capacity() -> void:
	if inventory == null:
		return
	if _initializing:
		return
	var cap := _compute_carry_capacity(true)
	var slots: int = cap["slots"]
	var weight: float = cap["weight"]
	var old_max: int = inventory.max_slots
	inventory.max_slots = slots
	inventory.max_weight = weight
	# Un muerto no expulsa objetos por capacidad: die() desequipa la ropa y cada
	# unequip reduce los slots, lo que soltaba items (p. ej. el sombrero) antes
	# de que el servidor repartiera el loot del cadáver — y sus item_dropped
	# llegaban rechazados (proxy_dead) o duplicados.
	var stored_count: int = inventory.get_stored_count() if inventory.has_method("get_stored_count") else inventory.items.size()
	if not _initializing and not is_dead and slots < old_max and stored_count > slots:
		_drop_excess_items(stored_count - slots)

func _compute_carry_capacity(with_backpack := true) -> Dictionary:
	var slots := BASE_CARRY_SLOTS
	var weight := BASE_CARRY_WEIGHT
	# Bonus per equipped clothing slot
	for slot in _equipped_slots:
		var equipped_item_name: String = str(_equipped_slots[slot])
		if equipped_item_name.is_empty():
			continue
		var is_military := equipped_item_name.find("militar") >= 0 or equipped_item_name.find("camuflaje") >= 0
		match slot:
			"torso":
				slots += TORSO_CARRY_SLOTS
				weight += TORSO_CARRY_WEIGHT
				if is_military:
					slots += 3
					weight += 3.0
			"legs":
				slots += LEGS_CARRY_SLOTS
				weight += LEGS_CARRY_WEIGHT
				if is_military:
					slots += 2
					weight += 2.0
			"head":
				# Sombreros, gorros y cascos no son contenedores.
				slots += HEAD_CARRY_SLOTS
				weight += HEAD_CARRY_WEIGHT
			"chaleco":
				slots += VEST_CARRY_SLOTS
				weight += VEST_CARRY_WEIGHT
	# Backpack bonus only if actually equipped (not just in inventory)
	if with_backpack and not equipped_backpack.is_empty():
		var bpc := backpack_capacity()
		slots += int(bpc["slots"])
		weight += float(bpc["weight"])
	return {"slots": slots, "weight": weight}

func backpack_capacity() -> Dictionary:
	if equipped_backpack == "Mochila militar":
		return {"slots": MILITARY_BACKPACK_SLOTS, "weight": MILITARY_BACKPACK_WEIGHT}
	return {"slots": SMALL_BACKPACK_SLOTS, "weight": SMALL_BACKPACK_WEIGHT}

# Suelta la última mochila: los objetos que ya no caben sin su bonus se meten
# dentro del propio drop (meta "pending_backpack_contents" → WorldAction "contents")
# en vez de desparramarse por el suelo. Llamar DESPUÉS de quitar la mochila del
# inventario. Devuelve los dicts serializados.
func _pack_backpack_drop_contents() -> Array:
	if inventory == null:
		return []
	# Otra mochila en inventario → no hay pérdida de capacidad.
	if _has_backpack_in_inventory():
		return []
	var slots: int = int(_compute_carry_capacity(false)["slots"])
	var stored_count: int = inventory.get_stored_count() if inventory.has_method("get_stored_count") else inventory.items.size()
	var overflow: int = stored_count - slots
	var held = get_held_item()
	var contents: Array = []
	var taken: Array = []
	# Explicitly stored backpack cargo travels with the dropped backpack,
	# even if other pockets have room. Legacy saves still use overflow packing.
	var candidates: Array = inventory.items.duplicate()
	candidates.reverse()
	candidates.sort_custom(func(a, b): return a.cargo_location == "backpack" and b.cargo_location != "backpack")
	for item in candidates:
		if contents.size() >= overflow and item.cargo_location != "backpack":
			continue
		if item == null or item == held:
			continue
		var is_equipped := false
		for slot_val in _equipped_slots.values():
			if str(slot_val) == str(item.item_name):
				is_equipped = true
				break
		if is_equipped or str(item.item_type) == "backpack":
			continue
		contents.append(item.to_dict())
		taken.append(item)
	for item in taken:
		var ri: int = inventory.items.find(item)
		if ri >= 0:
			inventory.remove_index(ri, int(item.quantity))
	if not contents.is_empty():
		inventory.changed.emit()
		notice.emit("El resto de objetos quedan dentro de la mochila.")
	return contents

func _drop_excess_items(count: int) -> void:
	if inventory == null or count <= 0:
		return
	var dropped := 0
	# Drop from the end of inventory (least recently picked up)
	for i in range(inventory.items.size() - 1, -1, -1):
		if dropped >= count:
			break
		var item = inventory.items[i]
		if item == null:
			continue
		# Don't drop equipped clothing or the equipped backpack
		var is_equipped := false
		for slot_val in _equipped_slots.values():
			if str(slot_val) == str(item.item_name):
				is_equipped = true
				break
		if str(item.item_type) == "backpack" and not equipped_backpack.is_empty():
			is_equipped = true
		if is_equipped:
			continue
		var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
		drop_pos.y = global_position.y
		var qty: int = int(item.quantity)
		set_meta("last_dropped_durability", float(item.durability))
		set_meta("last_dropped_max_durability", float(item.max_durability))
		set_meta("last_dropped_wetness", float(item.wetness))
		set_meta("last_dropped_pelt", str(item.get_meta("pelt_species", "")))
		var is_broken := false
		if item.has_method("is_broken"):
			is_broken = item.is_broken()
		item_dropped.emit(str(item.item_name), str(item.item_type), float(item.weight), qty, float(item.use_value), drop_pos, Color(0, 0, 0, 0), is_broken, float(item.spoilage))
		inventory.remove_index(i, qty)
		dropped += 1
	if dropped > 0:
		notice.emit("Se ha caido %d objeto(s) al perder capacidad." % dropped)
		inventory.changed.emit()

func _recalculate_warmth() -> void:
	if stats == null:
		return
	var prev_warmth: float = stats.warmth_bonus
	var total := 0.0
	for slot in _equipped_slots:
		var item_name: String = str(_equipped_slots[slot])
		if CLOTHING_WARMTH.has(item_name):
			total += CLOTHING_WARMTH[item_name]
			if str(_equipped_pelt.get(item_name, "")) == "oso":
				total += 0.10
	stats.warmth_bonus = total
	if not _initializing and total < prev_warmth:
		var lost_warmth := prev_warmth - total
		var cooling_drop := clampf(lost_warmth * 0.55, 0.04, 1.0)
		stats.body_temperature = maxf(34.0, stats.body_temperature - cooling_drop)
	stats.changed.emit()

func _recalculate_heat_protection() -> void:
	if stats == null:
		return
	var total := 0.0
	var retention := 0.0
	for slot in _equipped_slots:
		var item_name: String = str(_equipped_slots[slot])
		if CLOTHING_HEAT_PROTECTION.has(item_name):
			total += CLOTHING_HEAT_PROTECTION[item_name]
		if CLOTHING_HEAT_RETENTION.has(item_name):
			retention += CLOTHING_HEAT_RETENTION[item_name]
	stats.heat_protection_bonus = total
	stats.heat_retention_bonus = retention
	stats.changed.emit()

func _get_carry_weight_ratio() -> float:
	if inventory == null or inventory.max_weight <= 0.0:
		return 0.0
	var current: float = inventory.get_total_weight()
	return clamp(current / inventory.max_weight, 0.0, 1.0)

func _is_chat_open() -> bool:
	var sc := get_tree().current_scene if get_tree() != null else null
	if sc != null and sc.get("hud") != null and sc.hud.get("chat_open") == true:
		return true
	return false

func _update_crouch_collision() -> void:
	if _collision_shape == null:
		return
	var capsule := _collision_shape.shape as CapsuleShape3D
	if capsule == null:
		return
	# Keep capsule bottom at fixed Y (0.025) so player doesn't float when crouching on objects
	var bottom_y := 0.025
	if is_prone:
		capsule.height = 0.4
		_collision_shape.position.y = bottom_y + 0.2
	elif is_sitting:
		capsule.height = 0.8
		_collision_shape.position.y = bottom_y + 0.4
	elif is_crouching:
		capsule.height = 1.1
		_collision_shape.position.y = bottom_y + 0.55
	else:
		capsule.height = 1.75
		_collision_shape.position.y = bottom_y + 0.875

func _on_forward_press() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# Armar el sprint exige un mínimo de energía para que un doble-tap
	# con la reserva agotada no produzca un micro-arranque de un frame.
	if now - _last_forward_press_time < DOUBLE_TAP_WINDOW and stats.energy > 10.0:
		_sprint_double_tap = true
	_last_forward_press_time = now

func _update_sprint_state(input_dir: Vector2) -> void:
	# Sprint: double-tap forward to toggle, hold forward to keep sprinting
	var forward_held := Input.is_action_pressed("move_forward") and input_dir.y < -0.1
	if Input.is_action_just_pressed("move_forward"):
		_on_forward_press()
	if not forward_held:
		_sprint_double_tap = false
	# Sin stamina el sprint no parpadea: el toggle se suelta y el personaje
	# pasa directo a paso normal hasta un nuevo doble-tap de avance.
	if _sprint_double_tap and stats.energy <= 4.0:
		_sprint_double_tap = false
	is_sprinting = _sprint_double_tap and not is_crouching and stats.energy > 4.0 and input_dir.length() > 0.1

#endregion


#region FÍSICA Y MOVIMIENTO (_physics_process)
func _physics_process(delta: float) -> void:
	if is_puppet:
		return
	_pain_sound_timer = max(0.0, _pain_sound_timer - delta)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_shoot_cooldown = max(0.0, _shoot_cooldown - delta)
	var headless_run := DisplayServer.get_name() == "headless"
	var lmb_live := not headless_run and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and not _aerial_camera
	if _fire_button_held and (is_dead or _is_reloading or not _held_is_m4() or (not headless_run and not lmb_live)):
		_fire_button_held = false
	if (_fire_button_held or (lmb_live and _held_is_m4() and not is_dead and not _is_reloading)) and _held_is_m4() and _shoot_cooldown <= 0.0:
		_fire_button_held = true
		_shoot_rifle()
	elif _shoot_cooldown <= 0.0 and _held_is_m4() and _shoot_audio_player != null and _shoot_audio_player.playing:
		_shoot_audio_player.stop()
	# Gradually wear equipped clothing (faster when moving, slower when sleeping)
	if not is_dead and inventory != null:
		var wear_rate := 1.0
		if is_sleeping:
			wear_rate = 0.3
		if is_moving:
			wear_rate = 2.5
		if is_sprinting:
			wear_rate = 4.0
		_clothing_wear_timer += delta * wear_rate
		if _clothing_wear_timer >= 60.0:
			_clothing_wear_timer = 0.0
			var _broken_indices: Array = []
			for i in range(inventory.items.size()):
				var item = inventory.items[i]
				if item != null and item.item_type == "clothing" and item.has_method("reduce_durability"):
					var is_equipped := false
					for slot_val in _equipped_slots.values():
						if str(slot_val) == item.item_name:
							is_equipped = true
							break
					if is_equipped:
						var wear_amount := 0.30 if (item.item_name in GameConst.PELT_FUR_ITEMS or item.item_name == "Tocado de piel animal") else 1.0
						item.reduce_durability(wear_amount)
						if item.is_broken():
							notice.emit("%s se ha deteriorado y ya no sirve." % item.item_name)
							_broken_indices.append(i)
			# Drop and remove broken clothing from highest index to lowest
			for idx in range(_broken_indices.size() - 1, -1, -1):
				var i_broken: int = _broken_indices[idx]
				var broken_item = inventory.items[i_broken]
				var broken_name := str(broken_item.item_name)
				unequip_clothing(broken_name)
				var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
				drop_pos.y = global_position.y
				var drop_color := get_current_clothing_color(broken_name)
				set_meta("last_dropped_pelt", str(broken_item.get_meta("pelt_species", "")))
				item_dropped.emit(broken_name, "clothing", float(broken_item.weight), 1, float(broken_item.use_value), drop_pos, drop_color, true, 0.0)
				inventory.remove_index(i_broken, 1)
			# After losing clothing, capacity is reduced — drop items that no longer fit
			_recalculate_carry_capacity()
			while inventory.get_stored_count() > inventory.max_slots:
				var drop_idx := -1
				for k in range(inventory.items.size() - 1, -1, -1):
					if not InventoryScript.is_equipment_item(inventory.items[k]):
						drop_idx = k
						break
				if drop_idx < 0:
					break
				var overflow_item = inventory.items[drop_idx]
				var overflow_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
				overflow_pos.y = global_position.y
				if overflow_item != null:
					notice.emit("Has perdido %s al romperse la ropa." % overflow_item.item_name)
					set_meta("last_dropped_wetness", float(overflow_item.wetness))
					set_meta("last_dropped_pelt", str(overflow_item.get_meta("pelt_species", "")))
					item_dropped.emit(str(overflow_item.item_name), str(overflow_item.item_type), float(overflow_item.weight), int(overflow_item.quantity), float(overflow_item.use_value), overflow_pos, Color(0, 0, 0, 0), false, float(overflow_item.spoilage))
				inventory.remove_index(drop_idx)
			while inventory.get_total_weight() > inventory.max_weight and inventory.get_stored_count() > 0:
				var drop_idx2 := -1
				for k2 in range(inventory.items.size() - 1, -1, -1):
					if not InventoryScript.is_equipment_item(inventory.items[k2]):
						drop_idx2 = k2
						break
				if drop_idx2 < 0:
					break
				var overflow_item2 = inventory.items[drop_idx2]
				var overflow_pos2 := global_position + (global_transform.basis * Vector3.FORWARD * 0.8) + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
				overflow_pos2.y = global_position.y
				if overflow_item2 != null:
					notice.emit("Has perdido %s al romperse la ropa." % overflow_item2.item_name)
					set_meta("last_dropped_wetness", float(overflow_item2.wetness))
					set_meta("last_dropped_pelt", str(overflow_item2.get_meta("pelt_species", "")))
					item_dropped.emit(str(overflow_item2.item_name), str(overflow_item2.item_type), float(overflow_item2.weight), int(overflow_item2.quantity), float(overflow_item2.use_value), overflow_pos2, Color(0, 0, 0, 0), false, float(overflow_item2.spoilage))
				inventory.items.remove_at(drop_idx2)
			if held_index >= inventory.items.size():
				held_index = max(0, inventory.items.size() - 1)
			_sync_held_item()
			inventory.changed.emit()
	if is_dead:
		is_sprinting = false
		is_crouching = false
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_death_pose(delta)
		_update_backpack_socket()
		_update_hand_socket()
		_update_torch_hand_socket()
		_update_drink_hand_socket()
		_update_head_worn_items()
		return
	if is_instance_valid(rowing_boat):
		velocity = Vector3.ZERO
		is_sprinting = false
		is_in_water = false
		_water_depth = 0.0
		_water_sink = 0.0
		if _boat_standing:
			is_rowing = false
			var boat_move := _boat_movement_input()
			is_moving = boat_move.length_squared() > 0.001
			_boat_local_offset.x = clampf(_boat_local_offset.x + boat_move.x * 1.6 * delta, -1.0, 1.0)
			_boat_local_offset.y = clampf(_boat_local_offset.y + boat_move.y * 1.6 * delta, -2.6, 2.7)
			global_position = rowing_boat.to_global(Vector3(_boat_local_offset.x, 0.5, _boat_local_offset.y))
			var facing := rowing_boat.global_basis * Vector3(-sin(_rowing_view_yaw), 0.0, -cos(_rowing_view_yaw))
			rotation.y = atan2(-facing.x, -facing.z)
			_update_third_person_animation(is_moving, delta)
		else:
			# Remar exige como caminar: el occupante no se desplaza pero si trabaja.
			is_moving = false
			is_rowing = bool(rowing_boat.get("rowing"))
		_boat_prompt_timer = maxf(0.0, _boat_prompt_timer - delta)
		_update_interaction_prompt()
		_update_flashlight(delta)
		_update_torch(delta)
		_update_backpack_socket()
		_update_hand_socket()
		_update_torch_hand_socket()
		_update_drink_hand_socket()
		_update_head_worn_items()
		return
	if is_sleeping:
		velocity.x = 0.0
		velocity.z = 0.0
		if is_sleeping_on_bed:
			velocity = Vector3.ZERO
			global_position = _bed_sleep_position
		else:
			if not is_on_floor():
				velocity.y -= _gravity * delta
			else:
				velocity.y = 0.0
			move_and_slide()
		stats.do_sleep(delta)
		_update_backpack_socket()
		_update_hand_socket()
		_update_torch_hand_socket()
		_update_drink_hand_socket()
		_update_head_worn_items()
		_update_interaction_prompt()
		# Align sleeping model vertically so it stays on top of bed
		if third_person_model != null:
			var sleep_character: Node3D = third_person_model
			var sleep_skel := _find_skeleton(sleep_character)
			if sleep_skel != null:
				sleep_skel.force_update_all_bone_transforms()
				var min_foot_model_y := 1000000.0
				for i in range(sleep_skel.get_bone_count()):
					var bn := sleep_skel.get_bone_name(i)
					if bn.find("Foot") >= 0 or bn.find("Toe") >= 0 or bn.find("Hips") >= 0 or bn.find("Pelvis") >= 0 or bn.find("Spine") >= 0:
						var bone_world := sleep_skel.global_transform * sleep_skel.get_bone_global_pose(i).origin
						var bone_model := sleep_character.to_local(bone_world)
						if bone_model.y < min_foot_model_y:
							min_foot_model_y = bone_model.y
				if min_foot_model_y < 999999.0:
					var sleep_target_y := 0.086 - min_foot_model_y
					sleep_character.position = sleep_character.position.lerp(Vector3(0.0, sleep_target_y, 0.0), delta * 10.0)
		if camera != null:
			var sleep_cam_pos := Vector3(0.8, 1.2, 4.5)
			camera.position = camera.position.lerp(sleep_cam_pos, delta * 5.0)
			_constrain_camera_to_shelter()
			_pitch = lerp(_pitch, deg_to_rad(-12.0), delta * 5.0)
			camera.rotation.x = _pitch
		return
	# Aerial camera: freeze player movement
	if _aerial_camera:
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_backpack_socket()
		_update_hand_socket()
		_update_torch_hand_socket()
		_update_drink_hand_socket()
		_update_head_worn_items()
		return
	var chat_typing := _is_chat_open()
	var input_dir := Vector2.ZERO if chat_typing else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	is_moving = input_dir.length() > 0.1 and not is_dead
	if _sit_cooldown > 0.0:
		_sit_cooldown = max(0.0, _sit_cooldown - delta)
	if is_sitting or is_prone:
		if _sit_cooldown <= 0.0 and input_dir.length() > 0.1:
			is_sitting = false
			is_prone = false
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			direction = Vector3.ZERO
	if not chat_typing and Input.is_action_just_pressed("crouch"):
		is_crouching = not is_crouching
		_force_crouch = false
	if _force_crouch and input_dir.length() < 0.1:
		is_crouching = true
	_update_crouch_collision()
	_update_sprint_state(input_dir)
	var carry := _get_carry_weight_ratio()
	var effective_max_energy: float = stats.max_stat * (1.0 - carry * 0.5)
	# Cannot sprint when heavily loaded
	if carry > 0.85 or stats.get_thermal_stress() >= 0.85:
		is_sprinting = false
	var speed := crouch_speed if is_crouching else (sprint_speed * (1.0 - carry * 0.4) if is_sprinting else walk_speed * (1.0 - carry * 0.2))
	# Reduce speed when aiming with rifle or bow/throwable for careful movement
	if _is_aiming and _has_rifle_equipped():
		speed = crouch_speed * 0.8
		is_sprinting = false
	elif _is_aiming and (_has_bow_equipped() or _has_throwable_weapon_equipped()):
		speed = minf(speed, crouch_speed * 0.95)
		is_sprinting = false
	# Lock movement while attacking (but allow slow careful step while holding spear aim)
	if third_person_action_timer > 0.0 and not _throw_aim_hold and not _throw_charging and (third_person_action_animation == third_person_attack_animation or third_person_action_animation == third_person_punch_animation):
		direction = Vector3.ZERO
		speed = 0.0
		is_sprinting = false
	if is_sprinting:
		stats.energy = max(0.0, stats.energy - (3.0 + carry * 9.0) * (1.0 + stats.get_thermal_stress()) * delta)
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
	elif not is_jumping and is_on_floor():
		stats.energy = min(effective_max_energy, stats.energy + (8.0 - carry * 5.0) * stats.get_thermal_recovery_multiplier() * delta)
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
	_update_water_state(delta)
	if is_in_water:
		speed = crouch_speed if is_crouching else walk_speed
		speed *= lerp(0.72, 0.48, _water_depth)
		is_sprinting = false

	speed *= stats.get_thermal_speed_multiplier()
	# Cojera: las heridas en los pies reducen la velocidad (hasta -22%)
	speed *= 1.0 - 0.22 * clampf((stats.feet_wound - 40.0) / 60.0, 0.0, 1.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_jumping:
		velocity.y -= _gravity * delta
		move_and_slide()
		if not is_on_floor():
			_jump_apex = true
			_max_fall_height = max(_max_fall_height, global_position.y)
		if _jump_apex and is_on_floor() and velocity.y <= 0.0:
			is_jumping = false
			_jump_velocity = 0.0
			velocity.y = 0.0
			_jump_animation_timer = 0.0
			_jump_apex = false
			_land_after_fall()
	elif not is_on_floor():
		if not _is_falling_from_height:
			_is_falling_from_height = true
			_fall_height = global_position.y
		_max_fall_height = max(_max_fall_height, global_position.y)
		velocity.y -= _gravity * delta
		move_and_slide()
		if is_on_floor():
			velocity.y = 0.0
			_land_after_fall()
	else:
		velocity.y = -1.0
		move_and_slide()
		velocity.y = 0.0

	_update_barefoot(delta)
	_update_walk_motion(delta, input_dir.length())
	_update_rod_visual_overlay()
	_interaction_prompt_timer += delta
	if _interaction_prompt_timer >= 0.1:
		_interaction_prompt_timer = 0.0
		_update_interaction_prompt()
	_update_flashlight(delta)
	_update_torch(delta)
	_update_backpack_socket()
	_update_hand_socket()
	_update_torch_hand_socket()
	_update_drink_hand_socket()
	_update_head_worn_items()

#endregion


#region SOCKETS Y ACCESORIOS (mochila, manos, cabeza)
func _bind_backpack_socket() -> void:
	if _spine_skeleton == null or _spine_bone_idx < 0:
		return
	var skeleton_local := third_person_model.global_transform.affine_inverse() * _spine_skeleton.global_transform
	var rest_basis := skeleton_local.basis * _spine_skeleton.get_bone_global_rest(_spine_bone_idx).basis
	_backpack_rest_basis_inverse = rest_basis.orthonormalized().inverse()
	if not _spine_skeleton.skeleton_updated.is_connected(_update_backpack_socket):
		_spine_skeleton.skeleton_updated.connect(_update_backpack_socket)
	_update_backpack_socket()

func _update_backpack_socket() -> void:
	if _spine_skeleton == null or _spine_bone_idx < 0 or third_person_back_item_root == null:
		return
	if not is_instance_valid(_spine_skeleton) or not is_instance_valid(third_person_back_item_root):
		return
	var bone_pose := _spine_skeleton.get_bone_global_pose(_spine_bone_idx)
	var skel_global := _spine_skeleton.global_transform
	var bone_world := skel_global * bone_pose
	var local_to_model := third_person_model.global_transform.affine_inverse()
	var bone_local := local_to_model * bone_world
	var orientation := bone_local.basis.orthonormalized() * _backpack_rest_basis_inverse
	third_person_back_item_root.transform = Transform3D(orientation, bone_local.origin + orientation * _backpack_rest_pos)

var _hand_socket_offset := Vector3(0.10, 0.0, 0.0)
var _generic_hand_grip := false
var _hand_grip_curl := 1.0
var _hand_grip_adjustment := Vector3.ZERO
var _grip_modifier: SkeletonModifier3D

var _cached_palm_length := -1.0
var _cached_palm_skel: Skeleton3D = null

func _palm_grip_offset() -> Vector3:
	if _cached_palm_skel == _hand_skeleton and _cached_palm_length > 0.0:
		return Vector3(0.0, _cached_palm_length * 0.92, _cached_palm_length * 0.28) + _hand_grip_adjustment
	# Measure the actual imported rig rather than assuming centimetres/metres.
	var middle := -1
	for prefix in ["mixamorig:", "mixamorig_", ""]:
		middle = _hand_skeleton.find_bone(prefix + "RightHandMiddle1")
		if middle >= 0:
			break
	if middle < 0:
		return Vector3(0.0, 0.08, 0.025)
	var wrist := _hand_skeleton.get_bone_global_rest(_hand_bone_idx)
	var knuckle := wrist.affine_inverse() * _hand_skeleton.get_bone_global_rest(middle).origin
	var model_basis := third_person_model.global_basis.inverse() * _hand_skeleton.global_basis * wrist.basis
	var palm_length := (model_basis * knuckle).length()
	_cached_palm_skel = _hand_skeleton
	_cached_palm_length = palm_length
	return Vector3(0.0, palm_length * 0.92, palm_length * 0.28) + _hand_grip_adjustment

func _fit_held_prop_to_palm(item) -> void:
	_generic_hand_grip = false
	if item == null or third_person_hand_item_root == null:
		return
	# These actions carry their own authored hand/weapon animation.
	if str(item.item_type) in ["weapon_rifle", "weapon_bow", "tool_fishing", "tool_torch"] or str(item.item_name) in ["Arco de madera", "Arco reforzado"]:
		return
	if str(item.item_type) == "tool_spear" or str(item.item_name) in ["Lanza", "Lanza de hueso", "Palo afilado"]:
		_generic_hand_grip = true
		_hand_grip_curl = 1.0
		_hand_grip_adjustment = Vector3.ZERO
		return
	if third_person_hand_item_root.get_child_count() == 0:
		return
	_generic_hand_grip = true
	_hand_grip_curl = 1.0
	_hand_grip_adjustment = Vector3.ZERO
	var item_type := str(item.item_type)
	var long_tool := item_type in ["tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe", "tool_spear", "weapon"] or str(item.item_name) in ["Hacha", "Pala", "Pico", "Martillo", "Palo", "Palo afilado", "Madera", "Tronco", "Ramas", "Carne ensartada", "Pez ensartado", "Carne asada en palo"]
	# Keep multi-part props together under one grip pivot.
	var pivot := Node3D.new()
	pivot.name = "PalmGripVisual"
	for child in third_person_hand_item_root.get_children():
		third_person_hand_item_root.remove_child(child)
		pivot.add_child(child)
		if long_tool and child is Node3D:
			child.rotation = Vector3.ZERO
	third_person_hand_item_root.add_child(pivot)
	var bounds := _hierarchy_local_aabb(pivot)
	if bounds.size.length_squared() < 0.000001:
		return
	var axis := bounds.size.max_axis_index()
	var direction := Vector3.ZERO
	direction[axis] = 1.0
	# Handles run across the palm; fingers wrap around their cross-section.
	pivot.quaternion = Quaternion(direction, Vector3.RIGHT)
	var length := 0.22
	if long_tool:
		length = 0.65 if item_type != "weapon" else 0.25
		if item_type == "food": length = 0.45
		# El cuchillo importado tiene mucho margen vacio en el modelo y, con
		# la escala generica de armas, queda demasiado pequeno en la mano.
		if str(item.item_name) == "Cuchillo":
			length = 0.38
		# Long-handled tools keep their real-world reach instead of the
		# generic 0.65 m grip (final size is length × 1.30).
		match str(item.item_name):
			"Azada":
				length = 0.95
			"Pala":
				length = 1.08
	elif item_type in ["clothing", "backpack"]:
		length = 0.28
	elif item_type == "resource":
		length = 0.17
	elif item_type == "tool_matches":
		length = 0.15
		_hand_grip_curl = 0.8
		_hand_grip_adjustment = Vector3(0, 0.015, 0.025)
	elif item_type == "medical":
		length = 0.12
	elif item_type == "battery":
		length = 0.07
	if str(item.item_name).begins_with("Lata de "):
		length = 0.20
		_hand_grip_curl = 0.85
	elif item_type == "tool_matches":
		length = 0.18
	elif item_type == "water":
		length = 0.27
	elif str(item.item_name) in ["Naranja", "Higo", "Bayas silvestres"] or str(item.item_name).begins_with("Seta"):
		length = 0.13
	# Imported props are authored with generous empty margins; enlarge the
	# normalized grip slightly so the object sits visibly inside the palm.
	pivot.scale = Vector3.ONE * (length / bounds.size[axis]) * 1.30
	var anchor := bounds.get_center()
	if long_tool:
		anchor[axis] = bounds.position[axis] + bounds.size[axis] * 0.22
		anchor = _held_handle_center(pivot, axis, anchor, bounds.size[axis] * 0.10)
	pivot.position = -(pivot.basis * anchor)
	# Bulky objects need a more open grasp than a narrow handle.
	if item_type in ["clothing", "backpack"]:
		_hand_grip_curl = 0.65

func _held_handle_center(root: Node3D, axis: int, fallback: Vector3, tolerance: float) -> Vector3:
	# A blade/head makes the full AABB off-centre. Locate the handle section.
	var total := Vector3.ZERO
	var count := 0
	var pending: Array = []
	for child in root.get_children():
		if child is Node3D:
			pending.append([child, child.transform])
	while not pending.is_empty():
		var entry: Array = pending.pop_back()
		var node: Node3D = entry[0]
		var transform: Transform3D = entry[1]
		if node is MeshInstance3D and node.mesh != null:
			for surface in range(node.mesh.get_surface_count()):
				var arrays: Array = node.mesh.surface_get_arrays(surface)
				if arrays.is_empty():
					continue
				for vertex in arrays[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = transform * vertex
					if absf(point[axis] - fallback[axis]) <= tolerance:
						total += point
						count += 1
		for child in node.get_children():
			if child is Node3D:
				pending.append([child, transform * child.transform])
	if count == 0:
		return fallback
	var center := total / count
	center[axis] = fallback[axis]
	return center

var _head_worn_rel: Dictionary = {}
var _head_socket_signal_skeleton: Skeleton3D = null

func _bind_headwear_socket_signal() -> void:
	if _head_skeleton == null or _head_bone_idx < 0:
		return
	if _head_socket_signal_skeleton == _head_skeleton and _head_skeleton.skeleton_updated.is_connected(_on_head_skeleton_updated):
		return
	if is_instance_valid(_head_socket_signal_skeleton) and _head_socket_signal_skeleton.skeleton_updated.is_connected(_on_head_skeleton_updated):
		_head_socket_signal_skeleton.skeleton_updated.disconnect(_on_head_skeleton_updated)
	_head_socket_signal_skeleton = _head_skeleton
	if not _head_skeleton.skeleton_updated.is_connected(_on_head_skeleton_updated):
		_head_skeleton.skeleton_updated.connect(_on_head_skeleton_updated)

func _on_head_skeleton_updated() -> void:
	_update_head_worn_items()

func _on_third_person_mixer_applied() -> void:
	_aim_pitch_saved_rotations.clear()

var _spear_world_dir := Vector3(0.0, 0.0, -1.0)
var _spear_grip_shift := 0.20
var _spear_bone_cache: Dictionary = {}
var _spear_bone_cache_skel: Skeleton3D = null

func _find_spear_bone(skel: Skeleton3D, bare_name: String) -> int:
	if _spear_bone_cache_skel != skel:
		_spear_bone_cache.clear()
		_spear_bone_cache_skel = skel
	if _spear_bone_cache.has(bare_name):
		return int(_spear_bone_cache[bare_name])
	for prefix in ["mixamorig:", "mixamorig_", ""]:
		var idx := skel.find_bone(prefix + bare_name)
		if idx >= 0:
			_spear_bone_cache[bare_name] = idx
			return idx
	_spear_bone_cache[bare_name] = -1
	return -1

func _save_bone_pose_once(skel: Skeleton3D, b_idx: int) -> void:
	if b_idx >= 0 and not _aim_pitch_saved_rotations.has(b_idx):
		_aim_pitch_saved_rotations[b_idx] = skel.get_bone_pose(b_idx)

func _restore_aim_pitch_pose(skel: Skeleton3D = null) -> void:
	var target_skel: Skeleton3D = skel if skel != null else _hand_skeleton
	if target_skel == null or not is_instance_valid(target_skel) or _aim_pitch_saved_rotations.is_empty():
		_aim_pitch_saved_rotations.clear()
		return
	for b_idx in _aim_pitch_saved_rotations:
		var val = _aim_pitch_saved_rotations[b_idx]
		if val is Transform3D:
			target_skel.set_bone_pose(int(b_idx), val)
		elif val is Quaternion:
			target_skel.set_bone_pose_rotation(int(b_idx), val)
	_aim_pitch_saved_rotations.clear()
	target_skel.force_update_all_bone_transforms()

func _apply_aim_pitch_pose(skel: Skeleton3D = null) -> void:
	var target_skel: Skeleton3D = skel if skel != null else _hand_skeleton
	if _applying_aim_pitch or target_skel == null or not is_instance_valid(target_skel):
		return
	_applying_aim_pitch = true
	_restore_aim_pitch_pose(target_skel)
	var cur_anim: String = third_person_animation_player.current_animation if third_person_animation_player != null else ""
	if cur_anim.is_empty() and third_person_animation_player != null:
		cur_anim = third_person_animation_player.assigned_animation
	var held = get_held_item()
	var held_name := str(held.item_name) if held != null else _puppet_held
	var holding_spear: bool = held_name in ["Lanza", "Lanza de hueso", "Palo afilado"]
	var holding_bow: bool = _has_bow_equipped() or _puppet_held in ["Arco de madera", "Arco reforzado"]
	var bow_active: bool = holding_bow and (_is_aiming or _bow_release_item != null or (not cur_anim.is_empty() and cur_anim in [_bow_aim_idle_animation, _bow_aim_walk_animation, _bow_shoot_animation]))
	var throw_active: bool = _throw_aim_hold or _throw_charging or _throw_release_item != null or (_has_throwable_weapon_equipped() and _is_aiming) or (is_puppet and holding_spear and _is_aiming)
	if not bow_active and not throw_active and not holding_spear:
		_applying_aim_pitch = false
		return
	if bow_active or throw_active:
		if holding_spear and throw_active:
			for s_entry in [
				["Spine", Quaternion(0.019316, -0.063729, 0.032559, 0.997249)],
				["Spine1", Quaternion(0.030418, -0.077473, -0.004973, 0.996518)],
				["Spine2", Quaternion(-0.012315, -0.071555, 0.001948, 0.997359)],
			]:
				var sb_idx := _find_spear_bone(target_skel, String(s_entry[0]))
				if sb_idx >= 0:
					_save_bone_pose_once(target_skel, sb_idx)
					target_skel.set_bone_pose_rotation(sb_idx, (s_entry[1] as Quaternion).normalized())
			target_skel.force_update_all_bone_transforms()
		var aim_pitch := _pitch
		if not is_puppet and is_instance_valid(camera):
			aim_pitch = camera.rotation.x
		var walking_bow := bow_active and not _bow_aim_walk_animation.is_empty() and cur_anim == _bow_aim_walk_animation
		if bow_active:
			aim_pitch += deg_to_rad(2.2 if walking_bow else 4.0)
		aim_pitch = clampf(aim_pitch, deg_to_rad(-72.0), deg_to_rad(72.0))
		var aim_yaw := deg_to_rad(-8.6 if walking_bow else -5.4) if bow_active else 0.0
		if absf(aim_pitch) >= 0.001 or absf(aim_yaw) >= 0.001:
			var skel_inv_basis := target_skel.global_transform.basis.orthonormalized().inverse()
			var skel_right := (skel_inv_basis * global_basis.x.normalized()).normalized()
			var skel_up := (skel_inv_basis * global_basis.y.normalized()).normalized()
			if skel_right.length_squared() < 0.001:
				skel_right = Vector3.LEFT
			if skel_up.length_squared() < 0.001:
				skel_up = Vector3.UP
			var weights := [["Spine", 0.28, 0.55], ["Spine1", 0.36, 0.45], ["Spine2", 0.36, 0.0]]
			for entry in weights:
				var b_idx := _find_spear_bone(target_skel, String(entry[0]))
				_save_bone_pose_once(target_skel, b_idx)
			for entry in weights:
				var b_idx := _find_spear_bone(target_skel, String(entry[0]))
				if b_idx < 0:
					continue
				var step_pitch: float = aim_pitch * float(entry[1])
				var step_yaw: float = aim_yaw * float(entry[2])
				var g_basis := target_skel.get_bone_global_pose(b_idx).basis.orthonormalized()
				var g_inv := g_basis.inverse()
				var cur_q := target_skel.get_bone_pose_rotation(b_idx)
				if absf(step_yaw) > 0.0005:
					var local_up := (g_inv * skel_up).normalized()
					if local_up.length_squared() > 0.001:
						cur_q = (cur_q * Quaternion(local_up, step_yaw)).normalized()
				if absf(step_pitch) > 0.0005:
					var local_right := (g_inv * skel_right).normalized()
					if local_right.length_squared() > 0.001:
						cur_q = (cur_q * Quaternion(local_right, step_pitch)).normalized()
				target_skel.set_bone_pose_rotation(b_idx, cur_q)
				target_skel.force_update_all_bone_transforms()
	if holding_spear:
		_pose_spear_in_hand(target_skel, cur_anim, throw_active)
	_applying_aim_pitch = false

func _pose_spear_arm_orthogonal(skel: Skeleton3D, ua_idx: int, fa_idx: int, hand_idx: int, upper_dir_w: Vector3, raw_lower_dir_w: Vector3, spear_dir_w: Vector3, is_left: bool = false) -> void:
	var w2s := skel.global_transform.basis.orthonormalized().inverse()
	var upper_s := (w2s * upper_dir_w).normalized()
	var spear_s := (w2s * spear_dir_w).normalized()
	var lower_s := (w2s * raw_lower_dir_w).slide(spear_s).normalized()
	if lower_s.length_squared() < 0.01:
		lower_s = (w2s * Vector3.UP).slide(spear_s).normalized()

	var ua_pose := skel.get_bone_global_pose(ua_idx)
	var fa_pose := skel.get_bone_global_pose(fa_idx)
	var h_pose := skel.get_bone_global_pose(hand_idx)
	var root_pos := ua_pose.origin
	var len1 := root_pos.distance_to(fa_pose.origin)
	var new_mid := root_pos + upper_s * len1
	var hinge := upper_s.cross(lower_s).normalized()
	if hinge.length_squared() < 0.05:
		hinge = upper_s.cross(spear_s).normalized()
	if not is_left:
		hinge = -hinge

	var ua_rest := skel.get_bone_global_rest(ua_idx)
	var fa_rest := skel.get_bone_global_rest(fa_idx)
	var h_rest := skel.get_bone_global_rest(hand_idx)
	var ua_rest_dir := (fa_rest.origin - ua_rest.origin).normalized()
	var ua_rest_hinge := ua_rest.basis.z.slide(ua_rest_dir).normalized()
	if ua_rest_hinge.length_squared() < 0.25:
		ua_rest_hinge = ua_rest.basis.y.slide(ua_rest_dir).normalized()
	var ua_rot := _anatomical_frame(upper_s, hinge) * _anatomical_frame(ua_rest_dir, ua_rest_hinge).inverse()
	var ua_scale := ua_pose.basis.get_scale()
	skel.set_bone_global_pose(ua_idx, Transform3D((ua_rot * ua_rest.basis).orthonormalized().scaled_local(ua_scale), root_pos))

	var fa_rest_dir := (h_rest.origin - fa_rest.origin).normalized()
	var rig := _grip_rig_for(skel, hand_idx, is_left)
	var rest_grip_s := (h_rest.basis * (rig.get("frame", Basis.IDENTITY) as Basis).z).slide(fa_rest_dir).normalized()
	var desired_grip_s := spear_s.slide(lower_s).normalized()
	if desired_grip_s.length_squared() < 0.05 or rest_grip_s.length_squared() < 0.05:
		desired_grip_s = hinge
		rest_grip_s = fa_rest.basis.z.slide(fa_rest_dir).normalized()
	var fa_rot := _anatomical_frame(lower_s, desired_grip_s) * _anatomical_frame(fa_rest_dir, rest_grip_s).inverse()
	var fa_scale := fa_pose.basis.get_scale()
	skel.set_bone_global_pose(fa_idx, Transform3D((fa_rot * fa_rest.basis).orthonormalized().scaled_local(fa_scale), new_mid))

	# Keep the hand at its exact rest pose relative to the forearm so the wrist
	# mesh seam never separates, and curl the fingers around the spear shaft.
	skel.set_bone_pose(hand_idx, skel.get_bone_rest(hand_idx))
	if not is_left:
		_close_bow_fingers(hand_idx, false)
	skel.force_update_all_bone_transforms()

func _pose_spear_in_hand(target_skel: Skeleton3D, cur_anim: String, throw_active: bool) -> void:
	var rua_idx := _find_spear_bone(target_skel, "RightArm")
	var rfa_idx := _find_spear_bone(target_skel, "RightForeArm")
	var rh_idx := _hand_bone_idx if _hand_bone_idx >= 0 else _find_spear_bone(target_skel, "RightHand")
	if rua_idx < 0 or rfa_idx < 0 or rh_idx < 0:
		return
	var rsh_idx := _find_spear_bone(target_skel, "RightShoulder")
	var lsh_idx := _find_spear_bone(target_skel, "LeftShoulder")
	var lua_idx := _find_spear_bone(target_skel, "LeftArm")
	var lfa_idx := _find_spear_bone(target_skel, "LeftForeArm")
	var lh_idx := _left_hand_bone_idx if _left_hand_bone_idx >= 0 else _find_spear_bone(target_skel, "LeftHand")
	var neck_idx := _find_spear_bone(target_skel, "Neck")
	var head_idx := _find_spear_bone(target_skel, "Head")
	for b_idx in [rsh_idx, rua_idx, rfa_idx, rh_idx, lsh_idx, lua_idx, lfa_idx, lh_idx, neck_idx, head_idx]:
		_save_bone_pose_once(target_skel, b_idx)
	var r_rig := _grip_rig_for(target_skel, rh_idx, false)
	for entry in r_rig.get("fingers", []):
		_save_bone_pose_once(target_skel, int(entry[0]))

	var fwd_w := -global_basis.z.normalized()
	var right_w := global_basis.x.normalized()
	var up_w := global_basis.y.normalized()
	var skel_xf := target_skel.global_transform

	var anim_r_sh_w := skel_xf * target_skel.get_bone_global_pose(rua_idx).origin
	var anim_r_el_w := skel_xf * target_skel.get_bone_global_pose(rfa_idx).origin
	var anim_r_hd_w := skel_xf * target_skel.get_bone_global_pose(rh_idx).origin
	var arm_len := maxf(0.35, anim_r_el_w.distance_to(anim_r_sh_w) + anim_r_hd_w.distance_to(anim_r_el_w))
	var swing_z := clampf((anim_r_hd_w - anim_r_sh_w).dot(fwd_w) / arm_len, -0.45, 0.45)
	var anim_upper_dir_w := (anim_r_el_w - anim_r_sh_w).normalized()
	if anim_upper_dir_w.length_squared() < 0.01:
		anim_upper_dir_w = (right_w * 0.25 - up_w * 0.95).normalized()

	var melee_spear := (third_person_action_timer > 0.0 or (not third_person_attack_animation.is_empty() and cur_anim == third_person_attack_animation)) and not throw_active and not third_person_attack_animation.is_empty() and cur_anim == third_person_attack_animation

	var upper_dir_w := anim_upper_dir_w
	var raw_lower_dir_w := (-up_w * 0.70 + fwd_w * 0.68 - right_w * 0.12).normalized()

	if throw_active:
		for b_idx in [rsh_idx, neck_idx, head_idx]:
			if b_idx >= 0:
				target_skel.set_bone_pose_rotation(b_idx, target_skel.get_bone_rest(b_idx).basis.get_rotation_quaternion())
		# Natural left-arm balance pose (no forearm twist) + relaxed left fingers
		if lsh_idx >= 0:
			target_skel.set_bone_pose_rotation(lsh_idx, Quaternion(-0.428714, -0.505678, 0.534021, -0.524705).normalized())
		if lua_idx >= 0:
			target_skel.set_bone_pose_rotation(lua_idx, Quaternion(0.237960, -0.076982, -0.101600, 0.962874).normalized())
		if lfa_idx >= 0:
			target_skel.set_bone_pose_rotation(lfa_idx, Quaternion(0.108647, 0.256170, 0.160228, 0.947048).normalized())
		if lh_idx >= 0:
			target_skel.set_bone_pose_rotation(lh_idx, Quaternion(0.103306, -0.141735, 0.049686, 0.983245).normalized())
			var l_rig := _grip_rig_for(target_skel, lh_idx, true)
			for entry in l_rig.get("fingers", []):
				var fb_idx := int(entry[0])
				_save_bone_pose_once(target_skel, fb_idx)
				target_skel.set_bone_pose_rotation(fb_idx, target_skel.get_bone_rest(fb_idx).basis.get_rotation_quaternion())
		target_skel.force_update_all_bone_transforms()
		var aim_fwd_w := (-camera.global_basis.z if (not is_puppet and is_instance_valid(camera)) else (-global_basis.z).rotated(right_w, _pitch)).normalized()
		if _throw_release_item != null:
			var r_sh_now := skel_xf * target_skel.get_bone_global_pose(rua_idx).origin
			var to_tgt := _throw_release_target - (r_sh_now + right_w * 0.18 + up_w * 0.10)
			if to_tgt.length_squared() > 0.01:
				aim_fwd_w = to_tgt.normalized()
		_spear_world_dir = aim_fwd_w
		_spear_grip_shift = 0.28
		if _throw_release_item != null:
			var p := clampf(1.0 - _throw_release_timer / maxf(0.01, THROW_RELEASE_DELAY), 0.0, 1.0)
			upper_dir_w = (right_w * lerpf(0.72, 0.38, p) - up_w * lerpf(0.38, 0.20, p) + aim_fwd_w * lerpf(-0.48, 0.76, p)).normalized()
			raw_lower_dir_w = (up_w * lerpf(0.84, 0.42, p) + right_w * 0.24 + aim_fwd_w * lerpf(0.26, 0.86, p)).normalized()
		else:
			var walk_bob := swing_z * 0.08 if (not _bow_aim_walk_animation.is_empty() and cur_anim == _bow_aim_walk_animation) else 0.0
			upper_dir_w = (right_w * 0.72 - up_w * (0.38 - walk_bob) - aim_fwd_w * 0.48).normalized()
			raw_lower_dir_w = (up_w * 0.84 + right_w * 0.24 + aim_fwd_w * 0.26).normalized()
	elif melee_spear:
		for sname in ["Spine", "Spine1", "Spine2"]:
			var sb := _find_spear_bone(target_skel, sname)
			if sb >= 0:
				_save_bone_pose_once(target_skel, sb)
				target_skel.set_bone_pose_rotation(sb, target_skel.get_bone_rest(sb).basis.get_rotation_quaternion())
		for b_idx in [rsh_idx, neck_idx, head_idx]:
			if b_idx >= 0:
				target_skel.set_bone_pose_rotation(b_idx, target_skel.get_bone_rest(b_idx).basis.get_rotation_quaternion())
		if lsh_idx >= 0:
			target_skel.set_bone_pose_rotation(lsh_idx, Quaternion(-0.428714, -0.505678, 0.534021, -0.524705).normalized())
		if lua_idx >= 0:
			target_skel.set_bone_pose_rotation(lua_idx, Quaternion(0.237960, -0.076982, -0.101600, 0.962874).normalized())
		if lfa_idx >= 0:
			target_skel.set_bone_pose_rotation(lfa_idx, Quaternion(0.108647, 0.256170, 0.160228, 0.947048).normalized())
		if lh_idx >= 0:
			target_skel.set_bone_pose_rotation(lh_idx, Quaternion(0.103306, -0.141735, 0.049686, 0.983245).normalized())
		target_skel.force_update_all_bone_transforms()
		var anim_t := third_person_animation_player.current_animation_position if third_person_animation_player != null else 0.48
		var strike_phase := clampf((anim_t - 0.18) / 0.35, 0.0, 1.0)
		var pitch_rad := deg_to_rad(lerpf(12.0, 3.0, strike_phase))
		_spear_world_dir = (fwd_w * cos(pitch_rad) + up_w * sin(pitch_rad) - right_w * 0.02).normalized()
		_spear_grip_shift = lerpf(0.24, 0.44, strike_phase)
		upper_dir_w = (right_w * lerpf(0.45, 0.28, strike_phase) - up_w * lerpf(0.78, 0.58, strike_phase) + fwd_w * lerpf(-0.42, 0.42, strike_phase)).normalized()
		raw_lower_dir_w = (up_w * 0.18 + right_w * 0.08 + fwd_w * 0.96).normalized()
	elif is_crouching or (not cur_anim.is_empty() and cur_anim in [third_person_sneak_animation, third_person_sneak_walk_animation]):
		if rsh_idx >= 0:
			target_skel.set_bone_pose_rotation(rsh_idx, target_skel.get_bone_rest(rsh_idx).basis.get_rotation_quaternion())
			target_skel.force_update_all_bone_transforms()
		var pitch_rad := deg_to_rad(18.0) + swing_z * 0.14
		_spear_world_dir = (fwd_w * cos(pitch_rad) + up_w * sin(pitch_rad) + right_w * 0.02).normalized()
		_spear_grip_shift = 0.22
		upper_dir_w = (right_w * 0.34 - up_w * 0.90 + fwd_w * (-0.16 + swing_z * 0.35)).normalized()
		raw_lower_dir_w = (-up_w * 0.74 + fwd_w * (0.62 + swing_z * 0.25) + right_w * 0.14).normalized()
	elif is_sprinting or (not third_person_run_animation.is_empty() and cur_anim == third_person_run_animation):
		if rsh_idx >= 0:
			target_skel.set_bone_pose_rotation(rsh_idx, target_skel.get_bone_rest(rsh_idx).basis.get_rotation_quaternion())
			target_skel.force_update_all_bone_transforms()
		var pitch_rad := deg_to_rad(24.0) + swing_z * 0.18
		_spear_world_dir = (fwd_w * cos(pitch_rad) + up_w * sin(pitch_rad) + right_w * 0.02).normalized()
		_spear_grip_shift = 0.20
		upper_dir_w = (right_w * 0.34 - up_w * 0.90 + fwd_w * (-0.14 + swing_z * 0.45)).normalized()
		raw_lower_dir_w = (-up_w * 0.70 + fwd_w * (0.66 + swing_z * 0.30) + right_w * 0.14).normalized()
	else:
		if rsh_idx >= 0:
			target_skel.set_bone_pose_rotation(rsh_idx, target_skel.get_bone_rest(rsh_idx).basis.get_rotation_quaternion())
			target_skel.force_update_all_bone_transforms()
		var is_walk := not third_person_walk_animation.is_empty() and cur_anim == third_person_walk_animation
		var pitch_rad := deg_to_rad(32.0 if is_walk else 34.0) + swing_z * 0.20
		_spear_world_dir = (fwd_w * cos(pitch_rad) + up_w * sin(pitch_rad) + right_w * 0.03).normalized()
		_spear_grip_shift = 0.20
		upper_dir_w = (anim_upper_dir_w * 0.50 + (right_w * 0.36 - up_w * 0.91 + fwd_w * (-0.08 + swing_z * 0.45)) * 0.50).normalized()
		raw_lower_dir_w = (-up_w * 0.82 + fwd_w * (0.48 + swing_z * 0.38) + right_w * 0.18).normalized()

	_pose_spear_arm_orthogonal(target_skel, rua_idx, rfa_idx, rh_idx, upper_dir_w, raw_lower_dir_w, _spear_world_dir, false)

func _close_bow_fingers(hand_idx: int, left: bool) -> Vector3:
	var rig := _grip_rig_for(_hand_skeleton, hand_idx, left)
	_grip_pivots_applied = true
	for entry in rig.get("fingers", []):
		var pose := _hand_skeleton.get_bone_pose(entry[0])
		pose.basis = (entry[2] as Basis) * Basis(entry[1] as Vector3, entry[3] as float)
		var rest := _hand_skeleton.get_bone_rest(entry[0])
		var pivot: Vector3 = entry[4]
		pose.origin = rest.origin + rest.basis * pivot - pose.basis * pivot
		_hand_skeleton.set_bone_pose(entry[0], pose)
	return (rig.get("knuckle", Vector3.ZERO) as Vector3) * 0.7

func _update_hand_socket() -> void:
	if _hand_skeleton == null or _hand_bone_idx < 0 or third_person_hand_item_root == null:
		return
	if not is_instance_valid(_hand_skeleton) or not is_instance_valid(third_person_hand_item_root):
		return
	_apply_aim_pitch_pose(_hand_skeleton)
	var skel_global := _hand_skeleton.global_transform
	var local_to_model := third_person_model.global_transform.affine_inverse()
	var holding_bow: bool = _has_bow_equipped() or _puppet_held in ["Arco de madera", "Arco reforzado"]
	if holding_bow and _left_hand_bone_idx >= 0:
		var cur_anim: String = third_person_animation_player.current_animation if third_person_animation_player != null else ""
		var bow_drawing: bool = _is_aiming or _bow_release_item != null or (not cur_anim.is_empty() and cur_anim in [_bow_aim_idle_animation, _bow_aim_walk_animation, _bow_shoot_animation])
		var l_world := skel_global * _hand_skeleton.get_bone_global_pose(_left_hand_bone_idx)
		var knuckle_off := _close_bow_fingers(_left_hand_bone_idx, true)
		if not bow_drawing:
			l_world.origin = l_world * knuckle_off
		var l_local := local_to_model * l_world
		var r_world := skel_global * _hand_skeleton.get_bone_global_pose(_hand_bone_idx)
		var r_local := local_to_model * r_world
		var prim_node := third_person_hand_item_root.find_child("HeldPrimitive", true, false) as Node3D
		if bow_drawing:
			var draw_vec := l_local.origin - r_local.origin
			var draw_dist := draw_vec.length()
			var raw_pitch := camera.rotation.x if (not is_puppet and is_instance_valid(camera)) else _pitch
			var ideal_fwd := Vector3(0.0, sin(raw_pitch), cos(raw_pitch)).normalized()
			var fwd_dir := (draw_vec / draw_dist) if draw_dist > 0.04 else ideal_fwd
			var released := cur_anim == _bow_shoot_animation and third_person_animation_player.current_animation_position >= BOW_RELEASE_DELAY
			if released or draw_dist < 0.28:
				fwd_dir = ideal_fwd
			elif fwd_dir.dot(ideal_fwd) < 0.996:
				# Keep the bow aligned with the player's sight line during blend/nock
				# transitions while preserving the hand-to-hand draw line at anchor.
				var align_w := clampf((0.996 - fwd_dir.dot(ideal_fwd)) / 0.12, 0.35, 1.0)
				fwd_dir = fwd_dir.slerp(ideal_fwd, align_w).normalized()
			# Keep right_hint near model -X (player right) so pitching up to the sky
			# or down to the ground never hits gimbal lock with the vertical axis.
			var right_hint := Vector3(-1.0, 0.22, 0.0).normalized()
			var up_dir := right_hint.cross(fwd_dir).normalized()
			if up_dir.length_squared() < 0.001:
				up_dir = Vector3(0.0, 1.0, 0.0)
			var right_dir := fwd_dir.cross(up_dir).normalized()
			# Bow local -Z points forward along the arrow; +Z points directly to the right hand
			var bow_basis := Basis(right_dir, up_dir, -fwd_dir)
			third_person_hand_item_root.position = l_local.origin
			third_person_hand_item_root.basis = bow_basis
			if prim_node != null:
				prim_node.scale = Vector3.ONE * 1.38
				prim_node.rotation_degrees = Vector3.ZERO
				var model_scale_z := maxf(0.01, third_person_model.global_transform.basis.get_scale().z * prim_node.scale.z)
				var world_draw_dist := l_world.origin.distance_to(r_world.origin)
				_update_bow_draw_visuals(prim_node, world_draw_dist / model_scale_z, not released)
			return
		else:
			third_person_hand_item_root.position = l_local.origin
			var swing_z := clampf(l_local.origin.z, -0.35, 0.35)
			var pitch_rad := deg_to_rad(18.0 - swing_z * 38.0)
			# Model space: +X is player-left (outward from left hip), +Y is up, +Z is forward.
			# Bow local +Y is limb-to-limb; +Z is grip-to-string.
			var bow_y := Vector3(0.06, sin(pitch_rad), cos(pitch_rad)).normalized()
			var bow_z := Vector3(0.52, -0.85, 0.0).slide(bow_y).normalized()
			var bow_x := bow_y.cross(bow_z).normalized()
			third_person_hand_item_root.basis = Basis(bow_x, bow_y, bow_z)
			if prim_node != null:
				prim_node.scale = Vector3.ONE * 1.42
				prim_node.rotation_degrees = Vector3.ZERO
				_update_bow_draw_visuals(prim_node, 0.24, false)
			return
	var bone_pose := _hand_skeleton.get_bone_global_pose(_hand_bone_idx)
	var bone_world := skel_global * bone_pose
	var bone_local := local_to_model * bone_world
	var rod_offset := Vector3.ZERO
	if _rod_socket_active and third_person_animation_player != null:
		var anim_time := third_person_animation_player.current_animation_position
		rod_offset = _get_rod_socket_offset(anim_time)
	if _generic_hand_grip:
		third_person_hand_item_root.position = bone_local.origin + bone_local.basis.orthonormalized() * _palm_grip_offset()
	else:
		third_person_hand_item_root.position = bone_local.origin + _hand_socket_offset + rod_offset
	var euler := bone_local.basis.orthonormalized().get_euler()
	third_person_hand_item_root.rotation_degrees = Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))

	var held = get_held_item()
	var held_name := str(held.item_name) if held != null else _puppet_held
	if held_name in ["Lanza", "Lanza de hueso", "Palo afilado"]:
		var spear := third_person_hand_item_root.find_child("HeldPrimitive", true, false) as Node3D
		if spear != null:
			var spear_scale := Vector3(1.22, 1.48, 1.22)
			spear.scale = Vector3.ONE
			var dir_w := _spear_world_dir
			if dir_w.length_squared() < 0.001:
				dir_w = -global_basis.z
			var up_ref := Vector3.UP if absf(dir_w.y) < 0.97 else Vector3.FORWARD
			var world_orient := Basis.looking_at(dir_w, up_ref) * Basis(Vector3.RIGHT, -PI * 0.5)
			var local_orient := third_person_hand_item_root.global_basis.orthonormalized().inverse() * world_orient
			spear.basis = local_orient.scaled_local(spear_scale)
			spear.position = local_orient * Vector3(0.0, _spear_grip_shift, 0.0)

func _update_bow_draw_visuals(prim_node: Node3D, draw_dist: float, active: bool) -> void:
	var static_str := prim_node.find_child("BowString", true, false) as Node3D
	var top_seg := prim_node.get_node_or_null("BowDrawStringTop") as MeshInstance3D
	var bot_seg := prim_node.get_node_or_null("BowDrawStringBot") as MeshInstance3D
	var nocked_arrow := prim_node.get_node_or_null("BowNockedArrow") as Node3D
	if not active:
		if static_str != null: static_str.visible = true
		if top_seg != null: top_seg.visible = false
		if bot_seg != null: bot_seg.visible = false
		if nocked_arrow != null: nocked_arrow.visible = false
		return
	# Since +Z of prim_node points directly from the left hand (0,0,0) to the
	# right hand, the right hand string anchor is at (0, 0, draw_dist).
	var pull_z := clampf(draw_dist, 0.26, 1.45)
	var nock_pt := Vector3(0.0, 0.0, pull_z)
	var is_recurve: bool = prim_node.find_child("BoneSiyah_1", true, false) != null
	var tip_z := 0.341 if is_recurve else 0.246
	var top_tip := Vector3(0.0, 0.608, tip_z)
	var bot_tip := Vector3(0.0, -0.608, tip_z)
	if static_str != null:
		static_str.visible = false
	for seg_pair in [[top_seg, top_tip], [bot_seg, bot_tip]]:
		var seg: MeshInstance3D = seg_pair[0]
		var tip: Vector3 = seg_pair[1]
		if seg == null:
			continue
		seg.visible = true
		var span := nock_pt - tip
		var seg_len := maxf(0.01, span.length())
		var cyl := seg.mesh as CylinderMesh
		if cyl != null:
			cyl.height = seg_len
		seg.position = (tip + nock_pt) * 0.5
		var y_axis := span / seg_len
		var x_axis := Vector3(1.0, 0.0, 0.0)
		var z_axis := x_axis.cross(y_axis).normalized()
		seg.basis = Basis(x_axis, y_axis, z_axis)
	if nocked_arrow != null:
		var has_arrows: bool = is_puppet or _count_inventory_arrows() > 0
		nocked_arrow.visible = has_arrows
		if has_arrows:
			var desired_arrow := _peek_best_arrow_name() if not is_puppet else "Flecha de piedra"
			if not desired_arrow.is_empty() and str(nocked_arrow.get_meta("arrow_kind", "")) != desired_arrow:
				for ch in nocked_arrow.get_children():
					nocked_arrow.remove_child(ch)
					ch.queue_free()
				var arrow_vis := _build_arrow_or_spear_visual(desired_arrow, "ammo_arrow", false)
				if arrow_vis != null:
					nocked_arrow.add_child(arrow_vis)
				nocked_arrow.set_meta("arrow_kind", desired_arrow)
			# _build_arrow_or_spear_visual places fletching at +Z (+0.36) and
			# arrowhead at -Z (-0.425). Scale and position so the fletching sits
			# on the drawn string nock_pt (+pull_z) and the arrowhead projects
			# well past the left-hand fingertips (-Z) clearly visible to the camera.
			var z_scale := maxf(1.22, (pull_z + 0.38) / 0.68)
			nocked_arrow.rotation_degrees = Vector3.ZERO
			nocked_arrow.scale = Vector3(1.95, 1.95, z_scale)
			nocked_arrow.position = Vector3(-0.022, 0.038, pull_z - 0.44 * z_scale)

func _update_torch_hand_socket() -> void:
	if _hand_skeleton == null or _left_hand_bone_idx < 0:
		return
	if not is_instance_valid(_hand_skeleton) or not is_instance_valid(_torch_hand_root):
		return
	var bone_pose := _hand_skeleton.get_bone_global_pose(_left_hand_bone_idx)
	var skel_global := _hand_skeleton.global_transform
	var bone_world := skel_global * bone_pose
	var local_to_model := third_person_model.global_transform.affine_inverse()
	var bone_local := local_to_model * bone_world
	# Offset in model space: +Z moves forward (away from body), small -X stays on arm line
	_torch_hand_root.position = bone_local.origin + Vector3(-0.15, 0.0, 0.20)
	var euler := bone_local.basis.get_euler()
	_torch_hand_root.rotation_degrees = Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))

func _update_drink_hand_socket() -> void:
	if _hand_skeleton == null or _drink_bone_idx < 0:
		return
	if not is_instance_valid(_hand_skeleton) or not is_instance_valid(_drink_hand_root):
		return
	var bone_pose := _hand_skeleton.get_bone_global_pose(_drink_bone_idx)
	var skel_global := _hand_skeleton.global_transform
	var bone_world := skel_global * bone_pose
	var local_to_model := third_person_model.global_transform.affine_inverse()
	var bone_local := local_to_model * bone_world
	# Offset in the palm bone's local space; bone is at base of middle finger
	_drink_hand_root.position = bone_local.origin + Vector3(0.0, 0.0, -0.10)
	var euler := bone_local.basis.get_euler()
	_drink_hand_root.rotation_degrees = Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))

# Keeps head-slot clothing (e.g. the hat) glued to the head bone so it follows
# animations (walking, looking up/down, sitting, etc.) instead of staying
# fixed relative to the character root.
func _update_head_worn_items() -> void:
	if _head_worn_rel.is_empty() or third_person_model == null:
		return
	if _head_skeleton == null or _head_bone_idx < 0 or not is_instance_valid(_head_skeleton):
		return
	var bone_pose := _head_skeleton.get_bone_global_pose(_head_bone_idx)
	var skel_global := _head_skeleton.global_transform
	var bone_world := skel_global * bone_pose
	var local_to_model := third_person_model.global_transform.affine_inverse()
	var bone_local := local_to_model * bone_world
	var stale: Array = []
	for worn_name in _head_worn_rel.keys():
		var node := third_person_model.get_node_or_null(String(worn_name))
		if node == null or not is_instance_valid(node):
			stale.append(worn_name)
			continue
		var rel: Transform3D = _head_worn_rel[worn_name]
		node.transform = bone_local * rel
	for worn_name in stale:
		_head_worn_rel.erase(worn_name)

# Re-aplica los transforms de los accesorios sobre un modelo y esqueleto
# ajenos — el duplicado del retrato de inventario congela la pose de origen
# (sentado, agachado...) y no ejecuta los updaters de _physics_process. Se
# llama una vez tras forzar la pose del retrato (idle).
func _sync_posed_attachments(model: Node3D, skel: Skeleton3D) -> void:
	if model == null or skel == null or not is_instance_valid(skel):
		return
	var local_to_model := model.global_transform.affine_inverse()
	if _head_bone_idx >= 0:
		var head_local := local_to_model * skel.global_transform * skel.get_bone_global_pose(_head_bone_idx)
		for worn_name in _head_worn_rel.keys():
			var worn := model.get_node_or_null(String(worn_name)) as Node3D
			if worn != null:
				worn.transform = head_local * (_head_worn_rel[worn_name] as Transform3D)
	if _spine_bone_idx >= 0 and third_person_back_item_root != null:
		var back := model.get_node_or_null(String(third_person_back_item_root.name)) as Node3D
		if back != null:
			var spine_local := local_to_model * skel.global_transform * skel.get_bone_global_pose(_spine_bone_idx)
			var orientation := spine_local.basis.orthonormalized() * _backpack_rest_basis_inverse
			back.transform = Transform3D(orientation, spine_local.origin + orientation * _backpack_rest_pos)
	if _hand_bone_idx >= 0 and third_person_hand_item_root != null:
		var hand := model.get_node_or_null(String(third_person_hand_item_root.name)) as Node3D
		if hand != null:
			if _has_bow_equipped() and _left_hand_bone_idx >= 0:
				var lhand_local := local_to_model * skel.global_transform * skel.get_bone_global_pose(_left_hand_bone_idx)
				hand.position = lhand_local.origin + Vector3(0.12, 0.04, 0.06)
				var lhand_euler := lhand_local.basis.orthonormalized().get_euler()
				hand.rotation_degrees = Vector3(rad_to_deg(lhand_euler.x), rad_to_deg(lhand_euler.y), rad_to_deg(lhand_euler.z))
				var pnode := hand.find_child("HeldPrimitive", true, false) as Node3D
				if pnode != null:
					pnode.scale = Vector3.ONE * 1.42
					pnode.rotation_degrees = Vector3(18.0, 22.0, -16.0)
			else:
				var hand_local := local_to_model * skel.global_transform * skel.get_bone_global_pose(_hand_bone_idx)
				hand.position = hand_local.origin + _hand_socket_offset
				var hand_euler := hand_local.basis.orthonormalized().get_euler()
				hand.rotation_degrees = Vector3(rad_to_deg(hand_euler.x), rad_to_deg(hand_euler.y), rad_to_deg(hand_euler.z))
	if _left_hand_bone_idx >= 0 and _torch_hand_root != null:
		var torch := model.get_node_or_null(String(_torch_hand_root.name)) as Node3D
		if torch != null:
			var lhand_local := local_to_model * skel.global_transform * skel.get_bone_global_pose(_left_hand_bone_idx)
			torch.position = lhand_local.origin + Vector3(-0.15, 0.0, 0.20)
			var torch_euler := lhand_local.basis.get_euler()
			torch.rotation_degrees = Vector3(rad_to_deg(torch_euler.x), rad_to_deg(torch_euler.y), rad_to_deg(torch_euler.z))
	if _drink_bone_idx >= 0 and _drink_hand_root != null:
		var drink := model.get_node_or_null(String(_drink_hand_root.name)) as Node3D
		if drink != null:
			var drink_local := local_to_model * skel.global_transform * skel.get_bone_global_pose(_drink_bone_idx)
			drink.position = drink_local.origin + Vector3(0.0, 0.0, -0.10)
			var drink_euler := drink_local.basis.get_euler()
			drink.rotation_degrees = Vector3(rad_to_deg(drink_euler.x), rad_to_deg(drink_euler.y), rad_to_deg(drink_euler.z))

# Re-seats the held rifle/M4 inside a duplicated model (inventory portrait).
# In the live rig WeaponOffset is top_level and re-solved every frame by
# _update_rifle_ik; the duplicate keeps the stale world transform and the
# weapon would render outside the portrait frame. Runs the same rest solve
# against the posed duplicate skeleton. Returns true when a rifle was seated.
func _seat_m4_idle_grip(skel: Skeleton3D, hand_idx: int, offset: Node3D) -> void:
	# Anchor to the skinned knuckle instead of a fixed wrist offset: the idle
	# clip moves the palm, and a cosmetic stock shift must not detach the grip.
	var rig := _grip_rig_for(skel, hand_idx, false)
	var middle := int(rig.get("middle", -1))
	if middle < 0:
		return
	var contact: Vector3 = skel.global_transform * skel.get_bone_global_pose(middle) * (rig["middle_pivot"] as Vector3)
	offset.global_position += contact - offset.global_transform * _rg_right_knuckle
	offset.force_update_transform()

func pose_rifle_for_portrait(model: Node3D, skel: Skeleton3D) -> bool:
	if model == null or skel == null or not is_instance_valid(skel):
		return false
	var weapon_offset := model.find_child("WeaponOffset", true, false) as Node3D
	var rifle_root := model.find_child("RifleRoot", true, false) as Node3D
	if weapon_offset == null or rifle_root == null:
		return false
	var right_grip := rifle_root.get_node_or_null("RightGrip") as Marker3D
	var left_grip := rifle_root.get_node_or_null("LeftHandGripTarget") as Marker3D
	var stock_ref := rifle_root.get_node_or_null("StockReference") as Marker3D
	var muzzle_marker := rifle_root.get_node_or_null("MuzzleRef") as Marker3D
	if right_grip == null or left_grip == null or stock_ref == null:
		return false
	var rh_idx := skel.find_bone(_resolve_bone_name_safe(right_hand_bone_name, skel))
	var lh_idx := skel.find_bone(_resolve_bone_name_safe("mixamorig:LeftHand", skel))
	var sh_idx := skel.find_bone(_resolve_bone_name_safe("mixamorig:RightShoulder", skel))
	if sh_idx < 0:
		sh_idx = skel.find_bone(_resolve_bone_name_safe("mixamorig:RightArm", skel))
	if rh_idx < 0 or lh_idx < 0 or sh_idx < 0:
		return false
	var s := _rifle_weapon_scale() * skel.global_transform.basis.get_scale().x
	var rh_pos := (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var lh_pos := (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	var shoulder_pos := (skel.global_transform * skel.get_bone_global_pose(sh_idx)).origin
	var char_basis := model.global_basis.orthonormalized()
	var char_fwd := -char_basis.z
	var raw_shoulder := shoulder_pos + char_basis.x * 0.06 + char_basis.z * 0.02 - char_basis.y * 0.08
	if _mounted_rifle_is_m4:
		lh_pos -= char_fwd * 0.10 + char_basis.y * 0.05
		raw_shoulder += char_fwd * 0.25 - char_basis.x * 0.05 + char_basis.y * 0.08
	var v_world_dir := (lh_pos - rh_pos).normalized()
	var rg_local := right_grip.position
	var lg_local := left_grip.position
	var v_local_dir := Vector3(0.0, 0.0, -1.0) if _mounted_rifle_is_m4 else (lg_local - rg_local).normalized()
	if v_world_dir.length_squared() < 0.0001 or v_local_dir.length_squared() < 0.0001:
		return false
	# Shift the left-hand marker along the handguard so its distance matches
	# the animated hands, same as the live solve.
	var target_len := (lh_pos - rh_pos).length() / s
	if not _mounted_rifle_is_m4:
		left_grip.position = rg_local + v_local_dir * target_len
		lg_local = left_grip.position
	var axis := v_local_dir.cross(v_world_dir)
	var angle := v_local_dir.angle_to(v_world_dir)
	if axis.length_squared() < 0.0001:
		axis = Vector3(1.0, 0.0, 0.0) if abs(v_local_dir.y) < 0.9 else Vector3(0.0, 1.0, 0.0)
		angle = PI if v_local_dir.dot(v_world_dir) < 0.0 else 0.0
	var r0 := Basis(Quaternion(axis.normalized(), angle))
	var stock_vec := stock_ref.position - rg_local
	var stock_dist_world := s * stock_vec.length()
	var stock_parallel_len := s * stock_vec.dot(v_local_dir)
	var raw_shoulder_vec := raw_shoulder - rh_pos
	var raw_shoulder_proj := raw_shoulder_vec - v_world_dir * raw_shoulder_vec.dot(v_world_dir)
	var perp_radius_sq := stock_dist_world * stock_dist_world - stock_parallel_len * stock_parallel_len
	if perp_radius_sq < 0.0001:
		perp_radius_sq = 0.0001
	var perp_radius := sqrt(perp_radius_sq)
	var perp_dir := raw_shoulder_proj.normalized()
	if perp_dir.length_squared() < 0.0001:
		perp_dir = (Vector3(1.0, 0.0, 1.0).slide(v_world_dir)).normalized()
	shoulder_pos = rh_pos + v_world_dir * stock_parallel_len + perp_dir * perp_radius
	var stock_perp := stock_vec.slide(v_local_dir).normalized()
	if stock_perp.length_squared() < 0.0001:
		stock_perp = Vector3(0.0, 1.0, 0.0).slide(v_local_dir).normalized()
	var shoulder_vec := shoulder_pos - rh_pos
	var shoulder_perp := shoulder_vec.slide(v_world_dir).normalized()
	if shoulder_perp.length_squared() < 0.0001:
		shoulder_perp = Vector3(0.0, 1.0, 0.0).slide(v_world_dir).normalized()
	var stock_aligned_perp := r0 * stock_perp
	var roll := stock_aligned_perp.signed_angle_to(shoulder_perp, v_world_dir)
	var r := Basis(Quaternion(v_world_dir, roll)) * r0
	if _mounted_rifle_is_m4:
		var barrel_axis := (r * Vector3(0.0, 0.0, -1.0)).normalized()
		var desired_up := (char_basis.y - char_basis.z * 0.25).slide(barrel_axis).normalized()
		var current_up := (r * Vector3.UP).slide(barrel_axis).normalized()
		if desired_up.length_squared() > 0.001 and current_up.length_squared() > 0.001:
			var fix_roll := current_up.signed_angle_to(desired_up, barrel_axis)
			r = Basis(Quaternion(barrel_axis, fix_roll)) * r
	var weapon_basis := r.scaled(Vector3.ONE * s)
	rifle_root.position = Vector3.ZERO
	weapon_offset.global_basis = weapon_basis
	weapon_offset.global_position = rh_pos - weapon_basis * rg_local
	weapon_offset.force_update_transform()
	if muzzle_marker != null:
		rifle_root.force_update_transform()
		var barrel_dir := (muzzle_marker.global_position - stock_ref.global_position).normalized()
		if _mounted_rifle_is_m4:
			var up_dir := weapon_basis.y.normalized()
			weapon_offset.global_position += barrel_dir * 0.095 - up_dir * 0.015 + char_fwd * 0.045
			weapon_offset.force_update_transform()
		else:
			rifle_root.global_position += barrel_dir * 0.40
	if _mounted_rifle_is_m4:
		_seat_m4_idle_grip(skel, rh_idx, weapon_offset)
	return true

#endregion


#region ENTORNO (agua, temperatura)
func _update_water_state(delta: float) -> void:
	_water_step_timer = maxf(0.0, _water_step_timer - delta)
	_water_notice_cooldown = max(0.0, _water_notice_cooldown - delta)
	_water_query_timer += delta
	if is_instance_valid(rowing_boat):
		_water_depth = 0.0
		is_in_water = false
	elif _water_query_timer >= 0.25:
		_water_query_timer = 0.0
		var river_depth := _query_river_depth()
		_water_depth = river_depth
		is_in_water = river_depth > 0.02
	if is_in_water:
		var water_speed := Vector2(velocity.x, velocity.z).length()
		if _water_step_timer <= 0.0 and water_speed > 0.4 and is_on_floor():
			var water_scene := get_tree().current_scene
			var motion := Vector3(velocity.x, 0.0, velocity.z)
			_water_step_left = not _water_step_left
			var side := -1.0 if _water_step_left else 1.0
			var splash_pos := global_position + global_basis.x.normalized() * side * 0.16
			if is_instance_valid(_hand_skeleton):
				var foot_name := "LeftFoot" if _water_step_left else "RightFoot"
				for prefix in ["mixamorig:", "mixamorig_", ""]:
					var foot_idx := _hand_skeleton.find_bone(prefix + foot_name)
					if foot_idx >= 0:
						splash_pos = _hand_skeleton.global_transform * _hand_skeleton.get_bone_global_pose(foot_idx).origin
						break
			if water_scene != null and water_scene.has_method("get_river_surface_y_at") and water_scene.has_method("get_river_depth_at"):
				if float(water_scene.get_river_depth_at(splash_pos)) > 0.02:
					splash_pos.y = float(water_scene.get_river_surface_y_at(splash_pos))
					var strength := clampf(water_speed / 5.0, 0.2, 0.8)
					var spray_strength := strength * lerpf(1.0, 0.45, clampf(_water_depth / 1.2, 0.0, 1.0))
					_spawn_water_splash(splash_pos, spray_strength, motion)
					_spawn_water_ripples(splash_pos, strength, motion)
					_play_water_step_sound(splash_pos)
			_water_step_timer = clampf(0.95 / water_speed, 0.28, 0.65)
		wetness = min(1.0, wetness + delta * (0.38 + _water_depth * 0.55))
		_soaked_each_equipped(delta * (0.38 + _water_depth * 0.55))
		stats.wetness = _effective_wetness()
		stats.energy = max(0.0, stats.energy - delta * 0.018 * (0.8 + _water_depth))
		stats.body_temperature = max(32.0, stats.body_temperature - delta * 0.013 * (0.5 + wetness + _water_depth))
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
		if _water_notice_cooldown <= 0.0:
			notice.emit("Te mojas. La ropa fria te roba calor.")
			_water_notice_cooldown = 8.0
	else:
		if wetness <= 0.0 and not _any_equipped_wet():
			return
		# Rain/snow keeps clothes wet — Main refreshes _rain_wetting each
		# weather tick; without this gate the per-frame dry rate (~0.1/s)
		# outran the 2-second rain wet gain and clothes never got wet.
		if _rain_wetting:
			# stats.tick keeps drying its own wetness copy — pin it back to
			# the real (clothes + skin) value each frame while it rains.
			stats.wetness = _effective_wetness()
			return
		var ambient: float = _ambient_temperature()
		# Secado ambiental lento: ropa al aire tarda minutos (empapada→seca
		# ~2-5 min segun temperatura); junto al fuego sigue siendo rapido
		# via apply_warmth_drying.
		var dry_rate: float = 0.0035 + max(0.0, (ambient - 10.0)) * 0.0007
		wetness = max(0.0, wetness - delta * dry_rate)
		_dry_each_equipped(delta * dry_rate)
		stats.wetness = _effective_wetness()
		if wetness > 0.05:
			stats.body_temperature = max(32.0, stats.body_temperature - delta * 0.005 * wetness)
			_stats_emit_timer += delta
			if _stats_emit_timer >= 0.25:
				_stats_emit_timer = 0.0
				stats.changed.emit()

# Peso de cobertura de cada slot sobre la humedad efectiva del cuerpo.
const SLOT_WET_WEIGHT := {"torso": 0.35, "legs": 0.30, "feet": 0.10, "hands": 0.10, "head": 0.15}

func _equipped_item_for_slot(slot: String):
	if inventory == null:
		return null
	for it in inventory.items:
		if it != null and str(it.get_meta("equipped_slot", "")) == slot:
			return it
	var equipped_name := str(_equipped_slots.get(slot, ""))
	if equipped_name.is_empty():
		return null
	for it in inventory.items:
		if it != null and str(it.item_name) == equipped_name and str(it.get_meta("equipped_slot", "")) == "":
			return it
	return null

func _effective_wetness() -> float:
	# La humedad que enfría es la de la ropa encima; la piel descubierta usa
	# la humedad corporal. Así una muda seca se refleja al instante.
	var eff := 0.0
	for slot in SLOT_WET_WEIGHT:
		var item = _equipped_item_for_slot(slot)
		eff += (item.wetness if item != null else wetness) * float(SLOT_WET_WEIGHT[slot])
	return clampf(eff, 0.0, 1.0)

func _any_equipped_wet() -> bool:
	for slot in SLOT_WET_WEIGHT:
		var item = _equipped_item_for_slot(slot)
		if item != null and item.wetness > 0.001:
			return true
	return false

func _soaked_each_equipped(amount: float) -> void:
	for slot in SLOT_WET_WEIGHT:
		var item = _equipped_item_for_slot(slot)
		if item != null:
			item.wetness = minf(1.0, item.wetness + amount)

func _dry_each_equipped(amount: float) -> void:
	for slot in SLOT_WET_WEIGHT:
		var item = _equipped_item_for_slot(slot)
		if item != null:
			item.wetness = maxf(0.0, item.wetness - amount)

func apply_precipitation_wetness(gain: float) -> void:
	# La lluvia empapa la ropa equipada; la piel solo se moja donde queda
	# descubierta (más un poco de traspaso bajo la ropa empapada).
	var covered := 0.0
	for slot in SLOT_WET_WEIGHT:
		var item = _equipped_item_for_slot(slot)
		if item != null:
			item.wetness = minf(1.0, item.wetness + gain)
			covered += float(SLOT_WET_WEIGHT[slot])
	wetness = minf(1.0, wetness + gain * ((1.0 - covered) + 0.2 * covered))
	if stats != null:
		stats.wetness = _effective_wetness()

func apply_warmth_drying(amount: float) -> void:
	# Fuego/antorcha: seca la piel y la ropa equipada por igual.
	wetness = maxf(0.0, wetness - amount)
	_dry_each_equipped(amount)
	if stats != null:
		stats.wetness = _effective_wetness()

func _query_river_depth() -> float:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_river_depth_at"):
		return float(scene.call("get_river_depth_at", global_position))
	return 0.0

func _ambient_temperature() -> float:
	var ambient: float = 12.0
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_day_cycle"):
		var dc = scene.call("get_day_cycle")
		if dc != null and dc.has_method("get_ambient_temperature"):
			ambient = float(dc.call("get_ambient_temperature"))
	if scene != null and scene.has_method("get_hud"):
		var hud = scene.call("get_hud")
		if hud != null and hud.get("_real_temp_parsed") != null and float(hud.get("_real_temp_parsed")) != -999.0:
			ambient = float(hud.get("_real_temp_parsed"))
	return ambient

func _is_barefoot() -> bool:
	return str(_equipped_slots.get("feet", "")).is_empty()

func _is_on_walkable_ground() -> bool:
	return is_on_floor()

func _update_barefoot(delta: float) -> void:
	if stats == null or is_dead or is_puppet:
		return
	_feet_notice_timer = maxf(0.0, _feet_notice_timer - delta)
	_feet_cold_notice_timer = maxf(0.0, _feet_cold_notice_timer - delta)
	var barefoot := _is_barefoot()
	var abusing := barefoot and is_moving and _is_on_walkable_ground() and not is_in_water
	if abusing:
		stats.feet_wound = minf(100.0, stats.feet_wound + (FEET_WOUND_RUN_RATE if is_sprinting else FEET_WOUND_WALK_RATE) * delta)
		if stats.feet_wound >= FEET_WOUND_THRESHOLD:
			if not _feet_wounded_notice:
				_feet_wounded_notice = true
				notice.emit("Tienes los pies heridos por ir descalzo. Cada paso duele.")
			stats.health = maxf(0.0, stats.health - (FEET_DPS_RUN if is_sprinting else FEET_DPS_WALK) * delta)
			_feet_emit_timer += delta
			if _feet_emit_timer >= 0.5:
				_feet_emit_timer = 0.0
				stats.changed.emit()
			if _feet_notice_timer <= 0.0:
				_feet_notice_timer = 25.0
				notice.emit("Correr descalzo desgarra tus pies." if is_sprinting else "Caminar descalzo te daña los pies.")
			if is_sprinting:
				_feet_blood_timer -= delta
				if _feet_blood_timer <= 0.0:
					_feet_blood_timer = 0.45
					_spawn_blood_splatter(global_position + Vector3(0, 0.08, 0), 0.45)
	else:
		var recovery := 2.0 if not barefoot else 0.35
		stats.feet_wound = maxf(0.0, stats.feet_wound - recovery * delta)
		if stats.feet_wound < FEET_WOUND_THRESHOLD:
			_feet_wounded_notice = false
	# Calzado mojado enfría los pies como ir descalzo, en proporción a su
	# humedad (hasta un 65% del efecto); seco o mojado en charcos cuenta igual.
	var feet_cover_wet := 0.0
	if not barefoot:
		var feet_item = _equipped_item_for_slot("feet")
		if feet_item != null:
			feet_cover_wet = float(feet_item.wetness)
	var feet_chill := 1.0 if barefoot else feet_cover_wet * 0.65
	var cur_main := get_tree().current_scene if is_inside_tree() and get_tree() != null else null
	if cur_main != null and cur_main.has_method("_is_near_pelt_lined_shelter") and bool(cur_main._is_near_pelt_lined_shelter(global_position)):
		feet_chill = 0.0
	if feet_chill > 0.0 and _is_on_walkable_ground() and not is_in_water:
		var ambient := _ambient_temperature()
		if ambient < FEET_COLD_AMBIENT:
			stats.body_temperature = maxf(31.0, stats.body_temperature - (FEET_COLD_AMBIENT - ambient) * 0.0025 * feet_chill * delta)
			if _feet_cold_notice_timer <= 0.0:
				_feet_cold_notice_timer = 40.0
				notice.emit("El frío cala en tus pies descalzos." if barefoot else "El calzado mojado te hiela los pies.")

func _create_body() -> void:
	floor_max_angle = deg_to_rad(65.0)
	_collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	_collision_shape.shape = capsule
	_collision_shape.position.y = 0.9
	add_child(_collision_shape)
	_cached_rids_dirty = true

	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.35
	capsule_mesh.height = 1.65
	mesh.mesh = capsule_mesh
	mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.18, 0.16)
	material.roughness = 0.95
	mesh.material_override = material
	mesh.visible = false
	add_child(mesh)
	body_mesh = mesh

	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	camera.far = 500.0
	camera.position = THIRD_PERSON_CAMERA_POS
	add_child(camera)

	audio_listener = AudioListener3D.new()
	audio_listener.name = "AudioListener3D"
	camera.add_child(audio_listener)
	audio_listener.make_current()

	raycast = InteractionRaycastScript.new()
	raycast.name = "InteractionRaycast"
	raycast.interaction_distance = interaction_distance
	raycast.collide_with_areas = true
	camera.add_child(raycast)

	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.visible = false
	flashlight.light_energy = 3.0
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 35.0
	flashlight.rotation_degrees.x = -8.0
	camera.add_child(flashlight)
	torch_light = OmniLight3D.new()
	torch_light.name = "TorchLight"
	torch_light.visible = false
	torch_light.light_energy = 5.0
	torch_light.omni_range = 22.0
	torch_light.omni_attenuation = 0.8
	torch_light.light_color = Color(1.0, 0.7, 0.3)
	torch_light.shadow_enabled = false
	_create_third_person_model()
	# torch_light will be re-parented to _torch_hand_root after model creation

func _add_starting_items() -> void:
	var shirt = ItemScript.create("Camiseta", "clothing", 0.3, 1, 0.05)
	shirt.set_meta("equipped_slot", "torso")
	inventory.add_item(shirt)
	var pants = ItemScript.create("Pantalones", "clothing", 0.5, 1, 0.10)
	pants.set_meta("equipped_slot", "legs")
	inventory.add_item(pants)
	var shoes = ItemScript.create("Zapatillas", "clothing", 0.4, 1, 0.08)
	shoes.set_meta("equipped_slot", "feet")
	inventory.add_item(shoes)

func _create_third_person_model() -> void:
	var character: Node3D = null
	# Always use player_with_clothes.glb for the in-game model
	var model_path := GameConst.PLAYER_MODEL
	# Puppet: use puppet_model_path if set
	if is_puppet and not puppet_model_path.is_empty():
		model_path = puppet_model_path
	character = _load_external_node3d(model_path)
	if character != null:
		third_person_loaded_path = model_path
	if character == null:
		# Fallback: try default candidates
		for candidate in THIRD_PERSON_MODEL_CANDIDATES:
			character = _load_external_node3d(candidate)
			if character != null:
				third_person_loaded_path = candidate
				break
	if character != null:
		character.name = "ThirdPersonCharacter"
		character.visible = false
		character.position = Vector3.ZERO
		character.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		is_clothing_model = true
		add_child(character)
		third_person_model = character
		_anim_skel_dirty = true  # Invalida cache al cambiar el modelo
		_prev_anim_name = ""
		_hide_third_person_held_props(character)
		_hide_third_person_export_helpers(character)
		is_custom_character = false
		# Calculate and apply scale after adding to scene tree so skeleton poses are valid
		var character_scale: float = MIXAMO_CHARACTER_SCALE
		character.scale = Vector3.ONE * character_scale
		if is_custom_character:
			# Custom characters Body mesh lacks geometry under clothing (head-only).
			# Clone Desnudo_* meshes from player_with_clothes.glb as the nude body.
			_create_custom_desnudo_meshes(character_scale)
		# Only init survival clothing for the adapted player_with_clothes model.
		# Custom characters (Remy, personaje2) are complete models without the
		# survival clothing node structure.
		if is_clothing_model:
			_init_survival_clothing(character)
			_apply_character_colors()
		if not is_puppet:
			if is_clothing_model or is_custom_character:
				# Ensure default clothing is in inventory and equipped
				if inventory != null:
					var has_camiseta := false
					var has_pantalones := false
					var has_zapatillas := false
					for item in inventory.items:
						if str(item.item_name) == "Camiseta": has_camiseta = true
						if str(item.item_name) == "Pantalones": has_pantalones = true
						if str(item.item_name) == "Zapatillas": has_zapatillas = true
					if not has_camiseta:
						inventory.add_item(ItemScript.create("Camiseta", "clothing", 0.3, 1, 0.0))
					if not has_pantalones:
						inventory.add_item(ItemScript.create("Pantalones", "clothing", 0.4, 1, 0.0))
					if not has_zapatillas:
						inventory.add_item(ItemScript.create("Zapatillas", "clothing", 0.3, 1, 0.0))
				# Equip default clothing items
				for item in inventory.items:
					if DEFAULT_CLOTHING.has(str(item.item_name)):
						var _def_color: Color = item.get_meta("clothing_color", Color(0, 0, 0, 0))
						item.set_meta("clothing_camo", clothing_has_camo(str(item.item_name), item))
						equip_clothing(str(item.item_name), _def_color, item)
			else:
				if is_clothing_model:
					# Puppet: equip default clothing directly without inventory
					equip_clothing("Camiseta")
					equip_clothing("Pantalones")
					equip_clothing("Zapatillas")
				elif is_custom_character:
					# Custom character puppet: equip default clothing
					equip_clothing("Camiseta")
					equip_clothing("Pantalones")
					equip_clothing("Zapatillas")
		if not is_puppet:
			_create_third_person_item_slots()
		else:
			# Puppet: create minimal hand socket for held items
			if third_person_model != null:
				third_person_hand_item_root = Node3D.new()
				third_person_hand_item_root.name = "HandsSocket"
				third_person_hand_item_root.position = Vector3(0.29, 1.15, -0.16)
				third_person_hand_item_root.rotation_degrees = Vector3(8.0, 188.0, -8.0)
				third_person_model.add_child(third_person_hand_item_root)
				_torch_hand_root = Node3D.new()
				_torch_hand_root.name = "TorchHandSocket"
				third_person_model.add_child(_torch_hand_root)
				if torch_light != null:
					third_person_model.add_child(torch_light)
					torch_light.position = Vector3(0.0, 1.8, -1.2)
				third_person_back_item_root = Node3D.new()
				third_person_back_item_root.name = "BackpackSocket"
				third_person_back_item_root.position = Vector3(0.0, -0.05, -0.18)
				third_person_model.add_child(third_person_back_item_root)
		_setup_third_person_animation(character)
		_align_third_person_model_to_ground()
		if not is_puppet and third_person_model != null:
			third_person_model.visible = true
	return
	_create_procedural_third_person_model()

func _create_procedural_third_person_model() -> void:
	var rig := Node3D.new()
	rig.name = "ThirdPersonAnimatedRig"
	rig.visible = false
	add_child(rig)
	third_person_model = rig
	_anim_skel_dirty = true  # Invalida cache al cambiar el modelo
	_prev_anim_name = ""

	_add_held_box(rig, "RigTorso", Vector3(0.42, 0.72, 0.24), Vector3(0.0, 1.18, 0.0), Color(0.62, 0.45, 0.20), Vector3.ZERO)
	_add_held_sphere(rig, "RigHead", Vector3(0.18, 0.18, 0.18), Vector3(0.0, 1.68, 0.0), Color(0.45, 0.34, 0.25), Vector3.ZERO)

	third_person_left_arm = Node3D.new()
	third_person_left_arm.name = "RigLeftArmPivot"
	third_person_left_arm.position = Vector3(-0.29, 1.44, 0.0)
	rig.add_child(third_person_left_arm)
	_add_held_cylinder(third_person_left_arm, "RigLeftArm", 0.055, 0.58, Vector3(0.0, -0.29, 0.0), Color(0.49, 0.36, 0.24), Vector3.ZERO)

	third_person_right_arm = Node3D.new()
	third_person_right_arm.name = "RigRightArmPivot"
	third_person_right_arm.position = Vector3(0.29, 1.44, 0.0)
	rig.add_child(third_person_right_arm)
	_add_held_cylinder(third_person_right_arm, "RigRightArm", 0.055, 0.58, Vector3(0.0, -0.29, 0.0), Color(0.49, 0.36, 0.24), Vector3.ZERO)

	third_person_left_leg = Node3D.new()
	third_person_left_leg.name = "RigLeftLegPivot"
	third_person_left_leg.position = Vector3(-0.13, 0.84, 0.0)
	rig.add_child(third_person_left_leg)
	_add_held_cylinder(third_person_left_leg, "RigLeftLeg", 0.065, 0.72, Vector3(0.0, -0.36, 0.0), Color(0.11, 0.13, 0.14), Vector3.ZERO)

	third_person_right_leg = Node3D.new()
	third_person_right_leg.name = "RigRightLegPivot"
	third_person_right_leg.position = Vector3(0.13, 0.84, 0.0)
	rig.add_child(third_person_right_leg)
	_add_held_cylinder(third_person_right_leg, "RigRightLeg", 0.065, 0.72, Vector3(0.0, -0.36, 0.0), Color(0.11, 0.13, 0.14), Vector3.ZERO)
	_create_third_person_item_slots()

func _create_third_person_item_slots() -> void:
	if third_person_model == null:
		return
	third_person_hand_item_root = Node3D.new()
	third_person_hand_item_root.name = "HandsSocket"
	third_person_hand_item_root.position = Vector3(0.29, 1.15, -0.16)
	third_person_hand_item_root.rotation_degrees = Vector3(8.0, 188.0, -8.0)
	third_person_model.add_child(third_person_hand_item_root)
	if hands != null and hands.has_method("register_socket"):
		hands.register_socket(third_person_hand_item_root, Vector3(0.0, 0.0, -0.10), Vector3(0.0, 0.0, 0.0), Vector3.ONE * 0.55)

	_torch_hand_root = Node3D.new()
	_torch_hand_root.name = "TorchHandSocket"
	third_person_model.add_child(_torch_hand_root)
	if torch_light != null:
		third_person_model.add_child(torch_light)
		torch_light.position = Vector3(0.0, 1.8, -1.2)

	third_person_back_item_root = Node3D.new()
	third_person_back_item_root.name = "BackpackSocket"
	third_person_back_item_root.position = Vector3(0.0, -0.05, -0.18)
	third_person_back_item_root.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	third_person_model.add_child(third_person_back_item_root)
	_spine_skeleton = _find_skeleton(third_person_model)
	_spine_bone_idx = -1
	if _spine_skeleton != null:
		for bone_name in ["mixamorig:Spine2", "mixamorig:Spine1", "mixamorig:Spine", "mixamorig_Spine2", "mixamorig_Spine1", "mixamorig_Spine", "Spine2", "Spine1", "Spine"]:
			_spine_bone_idx = _spine_skeleton.find_bone(bone_name)
			if _spine_bone_idx != -1:
				break
	_bind_backpack_socket()
	_hand_skeleton = _spine_skeleton
	_hand_bone_idx = -1
	_left_hand_bone_idx = -1
	if _hand_skeleton != null:
		for bone_name in ["mixamorig:RightHand", "mixamorig_RightHand", "RightHand"]:
			_hand_bone_idx = _hand_skeleton.find_bone(bone_name)
			if _hand_bone_idx != -1:
				break
		for bone_name in ["mixamorig:LeftHand", "mixamorig_LeftHand", "LeftHand"]:
			_left_hand_bone_idx = _hand_skeleton.find_bone(bone_name)
			if _left_hand_bone_idx != -1:
				break
		for bone_name in ["mixamorig:LeftHandMiddle1", "mixamorig_LeftHandMiddle1", "LeftHandMiddle1"]:
			_drink_bone_idx = _hand_skeleton.find_bone(bone_name)
			if _drink_bone_idx != -1:
				break
	if _left_hand_bone_idx >= 0 and _drink_hand_root == null:
		_drink_hand_root = Node3D.new()
		_drink_hand_root.name = "DrinkHandSocket"
		third_person_model.add_child(_drink_hand_root)
	if _hand_skeleton != null:
		_grip_modifier = preload("res://scripts/HeldGripModifier.gd").new()
		_grip_modifier.name = "HeldGripModifier"
		_grip_modifier.controller = self
		_hand_skeleton.add_child(_grip_modifier)
	_head_skeleton = _spine_skeleton
	_head_bone_idx = -1
	if _head_skeleton != null:
		for bone_name in ["mixamorig:Head", "mixamorig_Head", "Head", "head", "Cabeza"]:
			_head_bone_idx = _head_skeleton.find_bone(bone_name)
			if _head_bone_idx != -1:
				break
	_bind_headwear_socket_signal()

	var head_socket := _create_equipment_socket("HeadSocket", Vector3(0.0, 1.72, -0.02), Vector3.ZERO)
	var chest_socket := _create_equipment_socket("ChestSocket", Vector3(0.0, 1.24, -0.18), Vector3.ZERO)
	var primary_socket := _create_equipment_socket("PrimaryWeaponSocket", Vector3(0.32, 1.16, 0.22), Vector3(18.0, 8.0, -22.0))
	var secondary_socket := _create_equipment_socket("SecondaryWeaponSocket", Vector3(-0.32, 1.16, 0.22), Vector3(18.0, -8.0, 22.0))
	var belt_socket := _create_equipment_socket("BeltSocket", Vector3(0.30, 0.90, -0.05), Vector3.ZERO)
	_create_equipment_socket("FeetSocket", Vector3(0.0, 0.0, 0.04), Vector3.ZERO)
	if equipment != null and equipment.has_method("register_socket"):
		equipment.register_socket("backpack", third_person_back_item_root, Vector3(0.0, 0.0, 0.0), Vector3(8.0, 180.0, 0.0), Vector3.ONE * 0.24)
		equipment.register_socket("head", head_socket)
		equipment.register_socket("chest", chest_socket)
		equipment.register_socket("primary_weapon", primary_socket)
		equipment.register_socket("secondary_weapon", secondary_socket)
		equipment.register_socket("belt", belt_socket)

func _create_equipment_socket(socket_name: String, pos: Vector3, rot: Vector3) -> Node3D:
	var socket := Node3D.new()
	socket.name = socket_name
	socket.position = pos
	socket.rotation_degrees = rot
	third_person_model.add_child(socket)
	return socket

func _setup_third_person_animation(character: Node3D) -> void:
	third_person_animation_player = _find_animation_player(character)
	if third_person_animation_player == null:
		# The adapted model (player_with_clothes.glb) is exported without an
		# AnimationPlayer, so it would stay frozen in T-pose. Create one that
		# drives the model's skeleton; the external Mixamo animations below are
		# retargeted onto it exactly as they are for inicio.glb.
		var skeleton := _find_skeleton(character)
		if skeleton == null:
			return
		var created := AnimationPlayer.new()
		created.name = "ThirdPersonAnimationPlayer"
		character.add_child(created)
		created.root_node = created.get_path_to(character)
		third_person_animation_player = created
	if third_person_animation_player != null and not third_person_animation_player.mixer_applied.is_connected(_on_third_person_mixer_applied):
		third_person_animation_player.mixer_applied.connect(_on_third_person_mixer_applied)
	# Load pre-built AnimationLibrary and retarget each animation to the character skeleton
	var debug_skel := _find_skeleton(character)
	if debug_skel != null:
		var debug_root := third_person_animation_player.root_node
		var debug_anim_root: Node = third_person_animation_player.get_node_or_null(debug_root) if not debug_root.is_empty() else third_person_animation_player
		if debug_anim_root == null:
			debug_anim_root = third_person_animation_player
		var debug_skel_path := str(debug_anim_root.get_path_to(debug_skel))
	var lib: AnimationLibrary = AnimationLibrary.new()
	var skip_post_process := [THIRD_PERSON_EXTERNAL_SLEEP_ANIMATION, THIRD_PERSON_EXTERNAL_SIT_ANIMATION, THIRD_PERSON_EXTERNAL_RIFLE_SIT_ANIMATION, THIRD_PERSON_EXTERNAL_RIFLE_PRONE_ANIMATION, THIRD_PERSON_EXTERNAL_RIFLE_GETUP_ANIMATION, THIRD_PERSON_EXTERNAL_RIFLE_SIT_FIRE_ANIMATION, THIRD_PERSON_EXTERNAL_RIFLE_PRONE_FIRE_ANIMATION]
	for anim_name in THIRD_PERSON_ANIMATION_LIBRARY.get_animation_list():
		var src_anim: Animation = THIRD_PERSON_ANIMATION_LIBRARY.get_animation(anim_name)
		if src_anim == null:
			continue
		var copied := src_anim.duplicate(true)
		copied.loop_mode = Animation.LOOP_NONE
		copied.step = 0.0166667
		_retarget_animation_to_character_skeleton(copied)
		var skel := _find_skeleton(third_person_model)
		# For custom characters, retarget rotation tracks to account for
		# different rest pose rotations between source and target skeletons
		if is_custom_character:
			_retarget_rotation_tracks(copied)
		# For custom characters, remove non-Hips position tracks to prevent
		# bone stretching from mismatched skeleton proportions
		if is_custom_character:
			var _allow_hips_y := anim_name in skip_post_process
			var _sit_fraction := 0.0
			if anim_name == THIRD_PERSON_EXTERNAL_SIT_ANIMATION:
				_sit_fraction = 0.20
			elif anim_name == THIRD_PERSON_EXTERNAL_SLEEP_ANIMATION:
				_sit_fraction = 0.10
			_remove_non_hips_position_tracks(copied, _allow_hips_y, _sit_fraction)
		if anim_name in skip_post_process:
			if copied.length > 5.0:
				copied = _trim_animation(copied, 0.0, 5.0)
				copied.loop_mode = Animation.LOOP_LINEAR
		else:
			if not is_custom_character:
				_remove_root_motion_drift(copied, skel)
			_smooth_loop_boundary(copied)
		lib.add_animation(anim_name, copied)
	third_person_animation_player.add_animation_library("external", lib)
	# Load torch-specific animations from FBX files
	third_person_stairs_animation = preload("res://scripts/StairAnimation.gd").install(self)
	_load_torch_animations()
	# Pre-cache the fishing rod pose and animations at startup so fishing starts instantly.
	if not is_puppet:
		_preload_rod_pose()
		_load_rod_animations()
	# Warm the rifle model cache at startup so selecting it later is instant.
	if not is_puppet:
		var warm_rifle := _load_external_node3d(REAL_RIFLE_MODEL)
		if warm_rifle != null:
			warm_rifle.queue_free()
	var names := third_person_animation_player.get_animation_list()
	var non_loop_keywords := ["jump", "attack", "punch", "dying", "dead", "drink", "interact", "gather", "plant", "fish", "coger", "recoger", "beber", "muerto", "pegar", "riflefire"]
	for animation_name in names:
		var name_text := String(animation_name)
		var animation := third_person_animation_player.get_animation(animation_name)
		if animation != null:
			var lower := name_text.to_lower()
			var is_non_loop := false
			for kw in non_loop_keywords:
				if lower.find(kw) >= 0:
					is_non_loop = true
					break
			if not is_non_loop:
				animation.loop_mode = Animation.LOOP_LINEAR
		var lower_name := name_text.to_lower()
		if lower_name == "idle" or lower_name.find("idle") >= 0:
			third_person_idle_animation = name_text
			third_person_has_real_idle = true
		if lower_name == "walk" or lower_name.find("walk") >= 0:
			third_person_walk_animation = name_text
		if lower_name == "run" or lower_name.find("run") >= 0:
			third_person_run_animation = name_text
	if third_person_idle_animation.is_empty() and names.size() > 0:
		third_person_idle_animation = ""
	if third_person_walk_animation.is_empty():
		third_person_walk_animation = third_person_run_animation if not third_person_run_animation.is_empty() else (String(names[0]) if names.size() > 0 else "")
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_WALK_ANIMATION):
		third_person_walk_animation = "external/" + THIRD_PERSON_EXTERNAL_WALK_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_IDLE_ANIMATION):
		third_person_idle_animation = "external/" + THIRD_PERSON_EXTERNAL_IDLE_ANIMATION
		third_person_has_real_idle = true
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RUN_ANIMATION):
		third_person_run_animation = "external/" + THIRD_PERSON_EXTERNAL_RUN_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_SNEAK_ANIMATION):
		third_person_sneak_animation = "external/" + THIRD_PERSON_EXTERNAL_SNEAK_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_SNEAK_WALK_ANIMATION):
		third_person_sneak_walk_animation = "external/" + THIRD_PERSON_EXTERNAL_SNEAK_WALK_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_LEFT_TURN_ANIMATION):
		third_person_left_turn_animation = "external/" + THIRD_PERSON_EXTERNAL_LEFT_TURN_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIGHT_TURN_ANIMATION):
		third_person_right_turn_animation = "external/" + THIRD_PERSON_EXTERNAL_RIGHT_TURN_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_PLANT_ANIMATION):
		third_person_plant_animation = "external/" + THIRD_PERSON_EXTERNAL_PLANT_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_GATHER_ANIMATION):
		third_person_gather_animation = "external/" + THIRD_PERSON_EXTERNAL_GATHER_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_FISH_ANIMATION):
		third_person_fish_animation = "external/" + THIRD_PERSON_EXTERNAL_FISH_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_INTERACT_ANIMATION):
		third_person_interact_animation = "external/" + THIRD_PERSON_EXTERNAL_INTERACT_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION):
		third_person_attack_animation = "external/" + THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION
		var atk_anim := third_person_animation_player.get_animation(third_person_attack_animation)
		if atk_anim != null:
			atk_anim.loop_mode = Animation.LOOP_NONE
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION):
		third_person_low_health_animation = "external/" + THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_DYING_ANIMATION):
		third_person_dying_animation = "external/" + THIRD_PERSON_EXTERNAL_DYING_ANIMATION
		var dying_animation := third_person_animation_player.get_animation(third_person_dying_animation)
		if dying_animation != null:
			dying_animation.loop_mode = Animation.LOOP_NONE
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_JUMP_ANIMATION):
		third_person_jump_animation = "external/" + THIRD_PERSON_EXTERNAL_JUMP_ANIMATION
		var jump_animation := third_person_animation_player.get_animation(third_person_jump_animation)
		if jump_animation != null:
			jump_animation.loop_mode = Animation.LOOP_NONE
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_JUMP_DOWN_ANIMATION):
		third_person_jump_down_animation = "external/" + THIRD_PERSON_EXTERNAL_JUMP_DOWN_ANIMATION
		var jump_down_animation := third_person_animation_player.get_animation(third_person_jump_down_animation)
		if jump_down_animation != null:
			jump_down_animation.loop_mode = Animation.LOOP_NONE
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_FIRE_ANIMATION):
		_rifle_fire_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_FIRE_ANIMATION
		var rifle_anim := third_person_animation_player.get_animation(_rifle_fire_animation)
		if rifle_anim != null:
			rifle_anim.loop_mode = Animation.LOOP_NONE
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_LEFT_TURN_ANIMATION):
		_rifle_left_turn_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_LEFT_TURN_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_RIGHT_TURN_ANIMATION):
		_rifle_right_turn_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_RIGHT_TURN_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_IDLE_ANIMATION):
		_rifle_idle_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_IDLE_ANIMATION
		var rifle_idle_anim := third_person_animation_player.get_animation(_rifle_idle_animation)
		if rifle_idle_anim != null:
			rifle_idle_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_AIM_IDLE_ANIMATION):
		_rifle_aim_idle_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_AIM_IDLE_ANIMATION
		var rifle_aim_anim := third_person_animation_player.get_animation(_rifle_aim_idle_animation)
		if rifle_aim_anim != null:
			rifle_aim_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_WALK_ANIMATION):
		_rifle_walk_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_WALK_ANIMATION
		var rifle_walk_anim := third_person_animation_player.get_animation(_rifle_walk_animation)
		if rifle_walk_anim != null:
			rifle_walk_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_RUN_ANIMATION):
		_rifle_run_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_RUN_ANIMATION
		var rifle_run_anim := third_person_animation_player.get_animation(_rifle_run_animation)
		if rifle_run_anim != null:
			rifle_run_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_SLEEP_ANIMATION):
		third_person_sleep_animation = "external/" + THIRD_PERSON_EXTERNAL_SLEEP_ANIMATION
		var sleep_anim := third_person_animation_player.get_animation(third_person_sleep_animation)
		if sleep_anim != null:
			sleep_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_SIT_ANIMATION):
		third_person_sit_animation = "external/" + THIRD_PERSON_EXTERNAL_SIT_ANIMATION
		var sit_anim := third_person_animation_player.get_animation(third_person_sit_animation)
		if sit_anim != null:
			sit_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_DRINK_ANIMATION):
		third_person_drink_animation = "external/" + THIRD_PERSON_EXTERNAL_DRINK_ANIMATION
		var drink_anim := third_person_animation_player.get_animation(third_person_drink_animation)
		if drink_anim != null:
			drink_anim.loop_mode = Animation.LOOP_LINEAR
	# Custom drink animation converted from Drinking.fbx, overrides the pre-built one if it loads successfully
	_load_drink_animation()
	# Bare-fist melee punch (Cross Punch.glb). Puppets also need it: the attacker's
	# current_animation name is synced over the network and remote players resolve it
	# against their own animation player.
	_load_punch_animation()
	# Death-by-beating clip (Standing Death Forward 02.glb). Puppets load it too:
	# the server tags melee kills in the death broadcast and remote players play
	# the same retargeted clip instead of the procedural fall.
	_load_melee_death_animation()
	# Hit reaction (Head Hit.glb) — the victim plays it on validated melee
	# damage; the synced anim name makes remote puppets flinch too.
	_load_hit_animation()
	# Shot-received reaction (RecibirDisparo.glb) — rifle hits play the
	# impact-only clip; synced to puppets the same way.
	_load_shot_animation()
	# Cooperative feed gesture (GiveFood.glb) — loaded for puppets too so the
	# giver plays the same synced clip on every client.
	_load_give_food_animation()
	_load_bow_animations()
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_SIT_ANIMATION):
		_rifle_sit_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_SIT_ANIMATION
		var rifle_sit_anim := third_person_animation_player.get_animation(_rifle_sit_animation)
		if rifle_sit_anim != null:
			rifle_sit_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_PRONE_ANIMATION):
		_rifle_prone_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_PRONE_ANIMATION
		var rifle_prone_anim := third_person_animation_player.get_animation(_rifle_prone_animation)
		if rifle_prone_anim != null:
			rifle_prone_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_GETUP_ANIMATION):
		_rifle_getup_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_GETUP_ANIMATION
		var rifle_getup_anim := third_person_animation_player.get_animation(_rifle_getup_animation)
		if rifle_getup_anim != null:
			rifle_getup_anim.loop_mode = Animation.LOOP_NONE
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_SIT_FIRE_ANIMATION):
		_rifle_sit_fire_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_SIT_FIRE_ANIMATION
		var sit_fire_anim := third_person_animation_player.get_animation(_rifle_sit_fire_animation)
		if sit_fire_anim != null:
			sit_fire_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_RIFLE_PRONE_FIRE_ANIMATION):
		_rifle_prone_fire_animation = "external/" + THIRD_PERSON_EXTERNAL_RIFLE_PRONE_FIRE_ANIMATION
		var prone_fire_anim := third_person_animation_player.get_animation(_rifle_prone_fire_animation)
		if prone_fire_anim != null:
			prone_fire_anim.loop_mode = Animation.LOOP_LINEAR
	if third_person_run_animation.is_empty():
		third_person_run_animation = third_person_walk_animation
	if third_person_sneak_animation.is_empty():
		third_person_sneak_animation = third_person_walk_animation
	if third_person_sneak_walk_animation.is_empty():
		third_person_sneak_walk_animation = third_person_sneak_animation
	if third_person_has_real_idle and not third_person_idle_animation.is_empty():
		third_person_animation_player.play(third_person_idle_animation)
	else:
		third_person_animation_player.stop()

func _trim_animation(animation: Animation, start_time: float, end_time: float) -> Animation:
	var trimmed := Animation.new()
	trimmed.loop_mode = animation.loop_mode
	trimmed.step = animation.step
	var duration := end_time - start_time
	if duration <= 0.0:
		return animation
	for track_index in range(animation.get_track_count()):
		var track_type := animation.track_get_type(track_index)
		var track_path := animation.track_get_path(track_index)
		trimmed.add_track(track_type)
		trimmed.track_set_path(track_index, track_path)
		trimmed.track_set_interpolation_type(track_index, animation.track_get_interpolation_type(track_index))
		var key_count := animation.track_get_key_count(track_index)
		for key_index in range(key_count):
			var key_time := animation.track_get_key_time(track_index, key_index)
			if key_time < start_time or key_time > end_time:
				continue
			var new_time := key_time - start_time
			var key_value: Variant = animation.track_get_key_value(track_index, key_index)
			if track_type == Animation.TYPE_POSITION_3D:
				trimmed.position_track_insert_key(track_index, new_time, key_value)
			elif track_type == Animation.TYPE_ROTATION_3D:
				trimmed.rotation_track_insert_key(track_index, new_time, key_value)
			elif track_type == Animation.TYPE_SCALE_3D:
				trimmed.scale_track_insert_key(track_index, new_time, key_value)
			elif track_type == Animation.TYPE_BLEND_SHAPE:
				trimmed.blend_shape_track_insert_key(track_index, new_time, key_value)
			else:
				trimmed.track_insert_key(track_index, new_time, key_value)
	trimmed.length = duration
	return trimmed

func _remove_non_hips_position_tracks(animation: Animation, allow_hips_y: bool = false, sit_fraction: float = 0.0, preserve_hips_anim_y: bool = false) -> void:
	# For custom characters, retarget position tracks to the target skeleton's
	# rest pose. Animations from a different Mixamo skeleton have bone offsets
	# that don't match Remy's proportions, causing deformation.
	# We keep rotation tracks (universal) and replace position values with
	# the target bone's rest pose position.
	# When allow_hips_y is true (sit/sleep), preserve the Hips Y offset from
	# the animation so the character lowers their body.
	var skeleton := _find_skeleton(third_person_model)
	if skeleton == null:
		return
	# First pass: replace non-Hips position values with rest pose
	for track_index in range(animation.get_track_count()):
		var track_type := animation.track_get_type(track_index)
		if track_type != Animation.TYPE_POSITION_3D:
			continue
		var path_text := str(animation.track_get_path(track_index))
		var is_hips := path_text.find("mixamorig_Hips") >= 0 or path_text.find("mixamorig:Hips") >= 0
		if is_hips:
			# Lock Hips to rest pose position (no root motion)
			# But preserve Y offset for sit/sleep/crouch animations
			var bone_name := "mixamorig_Hips"
			var bone_idx := skeleton.find_bone(bone_name)
			if bone_idx == -1:
				bone_idx = skeleton.find_bone("mixamorig:Hips")
			if bone_idx != -1:
				var rest_pos := skeleton.get_bone_rest(bone_idx).origin
				var key_count := animation.track_get_key_count(track_index)
				if preserve_hips_anim_y:
					# Keep original animation Hips Y (for crouch), lock X/Z to rest
					for key_index in range(key_count):
						var orig_val: Vector3 = animation.track_get_key_value(track_index, key_index)
						animation.track_set_key_value(track_index, key_index, Vector3(rest_pos.x, orig_val.y, rest_pos.z))
				elif allow_hips_y and sit_fraction > 0.0:
					# For sit/sleep, set Hips Y to a fraction of standing height
					# This avoids coordinate system mismatches between source/target skeletons
					var target_y := rest_pos.y * sit_fraction
					for key_index in range(key_count):
						animation.track_set_key_value(track_index, key_index, Vector3(rest_pos.x, target_y, rest_pos.z))
				else:
					for key_index in range(key_count):
						animation.track_set_key_value(track_index, key_index, rest_pos)
			continue
		# Non-Hips: replace with rest pose
		var bone_name := _extract_mixamo_bone_name(path_text)
		if bone_name.is_empty():
			continue
		bone_name = _resolve_mixamo_bone_name(skeleton, bone_name)
		if bone_name.is_empty():
			continue
		var bone_idx := skeleton.find_bone(bone_name)
		if bone_idx == -1:
			continue
		var rest_pos := skeleton.get_bone_rest(bone_idx).origin
		var key_count := animation.track_get_key_count(track_index)
		for key_index in range(key_count):
			animation.track_set_key_value(track_index, key_index, rest_pos)
	# Second pass: remove all SCALE_3D tracks
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		if animation.track_get_type(track_index) == Animation.TYPE_SCALE_3D:
			animation.remove_track(track_index)

# Rebase a preserved Hips Y curve (from _remove_non_hips_position_tracks with
# preserve_hips_anim_y=true) onto the target skeleton's rest height, keeping
# the original relative vertical motion (e.g. a crouch/lean) but anchored to
# the character's actual standing height instead of the source rig's own
# coordinate baseline, which otherwise causes a visible offset/deformation.
# Basis product along the node chain root → node (excluding root's own basis):
# maps positions expressed in `node`'s local space into `root`'s model space.
func _node_chain_basis(root: Node, node: Node3D) -> Basis:
	var chain: Array[Node3D] = []
	var n := node
	while n != null and n != root:
		chain.push_front(n)
		n = n.get_parent()
	var b := Basis.IDENTITY
	for c in chain:
		b = b * c.transform.basis
	return b

# The death clip's hips track lives in the source rig's skeleton space, whose
# axes do not match the target rig (source: +Y is forward, +Z is down after the
# FBX -90°X armature fixup; target: +Y is up). Copying Y→Y leaves the corpse
# floating ~2.7 m up. Convert the delta through world space instead, keeping
# only the vertical drop so the body folds down on top of its network spot.
func _retarget_death_hips_track(animation: Animation, tgt_skel: Skeleton3D, src_anim: Animation, src_skel: Skeleton3D, src_root: Node3D) -> void:
	if tgt_skel == null or src_skel == null or src_anim == null:
		return
	var src_hips := src_skel.find_bone("mixamorig_Hips")
	if src_hips == -1:
		src_hips = src_skel.find_bone("mixamorig:Hips")
	var tgt_hips := tgt_skel.find_bone("mixamorig_Hips")
	if tgt_hips == -1:
		tgt_hips = tgt_skel.find_bone("mixamorig:Hips")
	if src_hips == -1 or tgt_hips == -1:
		return
	var src_basis := _node_chain_basis(src_root, src_skel)
	var tgt_inv := _node_chain_basis(third_person_model, tgt_skel).inverse()
	var src_rest := src_skel.get_bone_rest(src_hips).origin
	var tgt_rest := tgt_skel.get_bone_rest(tgt_hips).origin
	# Read the vertical fall from the untouched source clip…
	var src_vals: Array[Vector3] = []
	for t in range(src_anim.get_track_count()):
		if src_anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var p := str(src_anim.track_get_path(t))
		if p.find("Hips") < 0:
			continue
		var kc := src_anim.track_get_key_count(t)
		for k in range(kc):
			var src_val: Vector3 = src_anim.track_get_key_value(t, k)
			var world_delta := src_basis * (src_val - src_rest)
			src_vals.append(Vector3(0.0, world_delta.y, 0.0))
	# …and write it back into the target clip's hips track (already rest-locked).
	var i := 0
	for t in range(animation.get_track_count()):
		if animation.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var p := str(animation.track_get_path(t))
		if p.find("Hips") < 0:
			continue
		var kc := animation.track_get_key_count(t)
		for k in range(kc):
			if i < src_vals.size():
				animation.track_set_key_value(t, k, tgt_rest + tgt_inv * src_vals[i])
				i += 1

func _normalize_hips_anim_y_offset(animation: Animation, skeleton: Skeleton3D) -> void:
	if skeleton == null:
		return
	var bone_idx := skeleton.find_bone("mixamorig_Hips")
	if bone_idx == -1:
		bone_idx = skeleton.find_bone("mixamorig:Hips")
	if bone_idx == -1:
		return
	var rest_y := skeleton.get_bone_rest(bone_idx).origin.y
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var path_text := str(animation.track_get_path(track_index))
		if path_text.find("mixamorig_Hips") < 0 and path_text.find("mixamorig:Hips") < 0:
			continue
		var key_count := animation.track_get_key_count(track_index)
		if key_count == 0:
			continue
		var base_y: float = (animation.track_get_key_value(track_index, 0) as Vector3).y
		for key_index in range(key_count):
			var val: Vector3 = animation.track_get_key_value(track_index, key_index)
			animation.track_set_key_value(track_index, key_index, Vector3(val.x, rest_y + (val.y - base_y), val.z))

# Cache for source skeleton rest rotations (from player_with_clothes.glb)
var _source_skeleton_rest_cache: Dictionary = {}
var _source_skeleton_rest_pos_cache: Dictionary = {}

func _get_source_skeleton_rest_rot(bone_name: String) -> Quaternion:
	_load_source_skeleton_cache()
	if _source_skeleton_rest_cache.has(bone_name):
		return _source_skeleton_rest_cache[bone_name]
	return Quaternion.IDENTITY

func _get_source_skeleton_rest_pos(bone_name: String) -> Vector3:
	_load_source_skeleton_cache()
	if _source_skeleton_rest_pos_cache.has(bone_name):
		return _source_skeleton_rest_pos_cache[bone_name]
	return Vector3.ZERO

func _load_source_skeleton_cache() -> void:
	if not _source_skeleton_rest_cache.is_empty():
		return
	var src_model: Node3D = load(GameConst.PLAYER_MODEL).instantiate()
	if src_model == null:
		return
	add_child(src_model)
	var src_skel := _find_skeleton(src_model)
	if src_skel != null:
		for i in range(src_skel.get_bone_count()):
			var bn := src_skel.get_bone_name(i)
			_source_skeleton_rest_cache[bn] = src_skel.get_bone_rest(i).basis.get_rotation_quaternion()
			_source_skeleton_rest_pos_cache[bn] = src_skel.get_bone_rest(i).origin
			if bn.begins_with("mixamorig_"):
				_source_skeleton_rest_cache["mixamorig:" + bn.substr("mixamorig_".length())] = src_skel.get_bone_rest(i).basis.get_rotation_quaternion()
				_source_skeleton_rest_pos_cache["mixamorig:" + bn.substr("mixamorig_".length())] = src_skel.get_bone_rest(i).origin
			elif bn.begins_with("mixamorig:"):
				_source_skeleton_rest_cache["mixamorig_" + bn.substr("mixamorig:".length())] = src_skel.get_bone_rest(i).basis.get_rotation_quaternion()
				_source_skeleton_rest_pos_cache["mixamorig_" + bn.substr("mixamorig:".length())] = src_skel.get_bone_rest(i).origin
	src_model.queue_free()

func _retarget_rotation_tracks(animation: Animation) -> void:
	# For custom characters, adjust rotation keyframes to account for
	# different rest pose rotations between source and target skeletons.
	# For each bone: new_rot = target_rest * source_rest.inverse() * original_rot
	var skeleton := _find_skeleton(third_person_model)
	if skeleton == null:
		return
	_retarget_rotation_tracks_with_source(animation, skeleton, null)

func _retarget_rotation_tracks_with_source(animation: Animation, target_skeleton: Skeleton3D, source_skeleton: Skeleton3D) -> void:
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var path_text := str(animation.track_get_path(track_index))
		var bone_name := _extract_mixamo_bone_name(path_text)
		if bone_name.is_empty():
			continue
		var resolved_name := _resolve_mixamo_bone_name(target_skeleton, bone_name)
		if resolved_name.is_empty():
			continue
		var target_idx := target_skeleton.find_bone(resolved_name)
		if target_idx == -1:
			continue
		var target_rest_rot := target_skeleton.get_bone_rest(target_idx).basis.get_rotation_quaternion()
		# Get source rest rotation: from source_skeleton if provided, else from cache
		var source_rest_rot := Quaternion.IDENTITY
		if source_skeleton != null:
			# Find the bone in the source skeleton (try original and resolved names)
			var src_idx := source_skeleton.find_bone(bone_name)
			if src_idx == -1:
				# Try mixamorig5_ variant
				src_idx = source_skeleton.find_bone("mixamorig5_" + resolved_name.substr("mixamorig_".length()))
			if src_idx != -1:
				source_rest_rot = source_skeleton.get_bone_rest(src_idx).basis.get_rotation_quaternion()
		else:
			source_rest_rot = _get_source_skeleton_rest_rot(bone_name)
		if source_rest_rot == Quaternion.IDENTITY and target_rest_rot == Quaternion.IDENTITY:
			continue
		# Compute offset: target_rest * source_rest.inverse()
		var offset := target_rest_rot * source_rest_rot.inverse()
		if offset == Quaternion.IDENTITY:
			continue
		var key_count := animation.track_get_key_count(track_index)
		for key_index in range(key_count):
			var original_rot: Quaternion = animation.track_get_key_value(track_index, key_index)
			var new_rot := offset * original_rot
			animation.track_set_key_value(track_index, key_index, new_rot)

func _retarget_animation_to_character_skeleton(animation: Animation) -> void:
	var skeleton := _find_skeleton(third_person_model)
	if skeleton == null or third_person_animation_player == null:
		return
	var animation_root := third_person_animation_player.get_node_or_null(third_person_animation_player.root_node)
	if animation_root == null:
		animation_root = third_person_animation_player
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for track_index in range(animation.get_track_count()):
		var path_text := str(animation.track_get_path(track_index))
		var bone_name := _extract_mixamo_bone_name(path_text)
		if bone_name.is_empty():
			continue
		bone_name = _resolve_mixamo_bone_name(skeleton, bone_name)
		if bone_name.is_empty():
			continue
		animation.track_set_path(track_index, NodePath(skeleton_path + ":" + bone_name))

func _extract_mixamo_bone_name(path_text: String) -> String:
	var slash_index := path_text.rfind("/")
	var colon_index := path_text.find(":mixamorig", max(0, slash_index))
	if colon_index >= 0:
		return path_text.substr(colon_index + 1)
	var underscore_index := path_text.find("mixamorig_", max(0, slash_index))
	if underscore_index >= 0:
		return path_text.substr(underscore_index)
	# Match mixamorig5_, mixamorig6_, etc.
	var digit_index := path_text.find("mixamorig", max(0, slash_index))
	if digit_index >= 0:
		var after := path_text.substr(digit_index + "mixamorig".length())
		var d_end := 0
		while d_end < after.length() and after[d_end] >= '0' and after[d_end] <= '9':
			d_end += 1
		if d_end > 0 and d_end < after.length() and after[d_end] == '_':
			return path_text.substr(digit_index)
	return ""

func _resolve_mixamo_bone_name(skeleton: Skeleton3D, imported_bone_name: String) -> String:
	var candidates: Array[String] = [imported_bone_name]
	if imported_bone_name.begins_with("mixamorig:"):
		candidates.append("mixamorig_" + imported_bone_name.substr("mixamorig:".length()))
	elif imported_bone_name.begins_with("mixamorig_"):
		candidates.append("mixamorig:" + imported_bone_name.substr("mixamorig_".length()))
	# Handle mixamorig5_, mixamorig6_, etc. (different Mixamo FBX export versions)
	var digit_match := imported_bone_name.find("mixamorig")
	if digit_match >= 0:
		var after_prefix := imported_bone_name.substr(digit_match + "mixamorig".length())
		var digit_end := 0
		while digit_end < after_prefix.length() and after_prefix[digit_end] >= '0' and after_prefix[digit_end] <= '9':
			digit_end += 1
		if digit_end > 0 and digit_end < after_prefix.length() and after_prefix[digit_end] == '_':
			var bare_name := after_prefix.substr(digit_end + 1)
			candidates.append("mixamorig_" + bare_name)
			candidates.append("mixamorig:" + bare_name)
	for candidate in candidates:
		if skeleton.find_bone(candidate) == -1:
			continue
		return candidate
	return ""

func _find_mesh_in_node(root: Node, mesh_name: String) -> MeshInstance3D:
	if root == null:
		return null
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and node.name == mesh_name:
			return node as MeshInstance3D
		for c in node.get_children():
			stack.append(c)
	return null

func _add_head_mesh() -> void:
	if third_person_model == null:
		return
	var skeleton := _find_skeleton(third_person_model)
	if skeleton == null:
		return
	var src_model := _load_external_node3d("res://assets/animations/inicio.glb")
	if src_model == null:
		return
	var src_body := _find_mesh_in_node(src_model, "Body")
	if src_body != null:
		var src_parent := src_body.get_parent()
		if src_parent != null:
			src_parent.remove_child(src_body)
		# Duplicate the Body node BEFORE adding to skeleton — duplicate preserves skin
		var head_dup := src_body.duplicate() as MeshInstance3D
		src_body.owner = null
		skeleton.add_child(src_body)
		_full_body_mesh = src_body
		if head_dup != null:
			head_dup.name = "HeadMesh"
			# Build a clean head-only mesh using add_surface_from_arrays
			var mesh_res := src_body.mesh
			if mesh_res != null and mesh_res.get_surface_count() > 0:
				var orig_mat := mesh_res.surface_get_material(0)
				var mdt := MeshDataTool.new()
				mdt.create_from_surface(mesh_res, 0)
				# Collect head face indices
				var head_faces: PackedInt32Array = []
				for face_idx in range(mdt.get_face_count()):
					var v0 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 0))
					var v1 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 1))
					var v2 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 2))
					var cy := (v0.y + v1.y + v2.y) / 3.0
					var cx := (v0.x + v1.x + v2.x) / 3.0
					if cy >= 3.0 and absf(cx) < 0.4:
						head_faces.append(face_idx)
				# Build arrays for head-only mesh
				var verts: PackedVector3Array = []
				var normals: PackedVector3Array = []
				var uvs: PackedVector2Array = []
				var bones_arr: PackedInt32Array = []
				var weights_arr: PackedFloat32Array = []
				var indices: PackedInt32Array = []
				var vert_map := {}
				for face_idx in head_faces:
					for fv in range(3):
						var orig_vi := mdt.get_face_vertex(face_idx, fv)
						var key := orig_vi
						if not vert_map.has(key):
							var new_idx := verts.size()
							vert_map[key] = new_idx
							verts.append(mdt.get_vertex(orig_vi))
							normals.append(mdt.get_vertex_normal(orig_vi))
							uvs.append(mdt.get_vertex_uv(orig_vi))
							var bs: PackedInt32Array = mdt.get_vertex_bones(orig_vi)
							var ws: PackedFloat32Array = mdt.get_vertex_weights(orig_vi)
							# Ensure exactly 4 bones/weights per vertex
							for b in range(4):
								if b < bs.size():
									bones_arr.append(bs[b])
								else:
									bones_arr.append(0)
							for w in range(4):
								if w < ws.size():
									weights_arr.append(ws[w])
								else:
									weights_arr.append(0.0)
						indices.append(vert_map[key])
				var arrays: Array = []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = verts
				arrays[Mesh.ARRAY_NORMAL] = normals
				arrays[Mesh.ARRAY_TEX_UV] = uvs
				arrays[Mesh.ARRAY_BONES] = bones_arr
				arrays[Mesh.ARRAY_WEIGHTS] = weights_arr
				arrays[Mesh.ARRAY_INDEX] = indices
				var head_mesh := ArrayMesh.new()
				head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				if head_mesh.get_surface_count() > 0 and orig_mat != null:
					head_mesh.surface_set_material(0, orig_mat)
				head_dup.mesh = head_mesh
				# Create body-without-head mesh from the same inicio.glb Body
				var body_nh_dup := src_body.duplicate() as MeshInstance3D
				if body_nh_dup != null:
					body_nh_dup.name = "BodyNoHead"
					var mdt2 := MeshDataTool.new()
					mdt2.create_from_surface(mesh_res, 0)
					var head_face_set := {}
					for hf in head_faces:
						head_face_set[hf] = true
					var verts2: PackedVector3Array = []
					var normals2: PackedVector3Array = []
					var uvs2: PackedVector2Array = []
					var bones_arr2: PackedInt32Array = []
					var weights_arr2: PackedFloat32Array = []
					var indices2: PackedInt32Array = []
					var vert_map2 := {}
					for face_idx in range(mdt2.get_face_count()):
						if head_face_set.has(face_idx):
							continue
						for fv in range(3):
							var orig_vi := mdt2.get_face_vertex(face_idx, fv)
							var key := orig_vi
							if not vert_map2.has(key):
								var new_idx := verts2.size()
								vert_map2[key] = new_idx
								verts2.append(mdt2.get_vertex(orig_vi))
								normals2.append(mdt2.get_vertex_normal(orig_vi))
								uvs2.append(mdt2.get_vertex_uv(orig_vi))
								var bs2: PackedInt32Array = mdt2.get_vertex_bones(orig_vi)
								var ws2: PackedFloat32Array = mdt2.get_vertex_weights(orig_vi)
								for b in range(4):
									if b < bs2.size():
										bones_arr2.append(bs2[b])
									else:
										bones_arr2.append(0)
								for w in range(4):
									if w < ws2.size():
										weights_arr2.append(ws2[w])
									else:
										weights_arr2.append(0.0)
							indices2.append(vert_map2[key])
					var arrays2: Array = []
					arrays2.resize(Mesh.ARRAY_MAX)
					arrays2[Mesh.ARRAY_VERTEX] = verts2
					arrays2[Mesh.ARRAY_NORMAL] = normals2
					arrays2[Mesh.ARRAY_TEX_UV] = uvs2
					arrays2[Mesh.ARRAY_BONES] = bones_arr2
					arrays2[Mesh.ARRAY_WEIGHTS] = weights_arr2
					arrays2[Mesh.ARRAY_INDEX] = indices2
					var body_nh_mesh := ArrayMesh.new()
					body_nh_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays2)
					if body_nh_mesh.get_surface_count() > 0 and orig_mat != null:
						body_nh_mesh.surface_set_material(0, orig_mat)
					body_nh_dup.mesh = body_nh_mesh
					body_nh_dup.skeleton = src_body.skeleton
					body_nh_dup.skin = src_body.skin
					body_nh_dup.visible = false
					skeleton.add_child(body_nh_dup)
					_body_no_head_mesh = body_nh_dup
			skeleton.add_child(head_dup)
			_head_mesh = head_dup
			_head_mesh.visible = false
		# Hide the Body_* and Desnudo_* parts from player_with_clothes.glb
		for bn in ["Body_arms", "Body_hands", "Body_torso", "Body_legs", "Body_feet",
				"Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
			var bmi: MeshInstance3D = _find_mesh_in_third_person(bn)
			if bmi != null:
				bmi.visible = false
	src_model.queue_free()

func _add_custom_head_mesh() -> void:
	if third_person_model == null:
		return
	var skeleton := _find_skeleton(third_person_model)
	if skeleton == null:
		return
	var body_mi := _find_custom_body_mesh()
	if body_mi == null:
		return
	var src_body := body_mi
	var head_dup := src_body.duplicate() as MeshInstance3D
	if head_dup == null:
		return
	head_dup.name = "HeadMesh"
	var mesh_res := src_body.mesh
	if mesh_res != null and mesh_res.get_surface_count() > 0:
		var orig_mat := mesh_res.surface_get_material(0)
		var mdt := MeshDataTool.new()
		mdt.create_from_surface(mesh_res, 0)
		var aabb := mesh_res.get_aabb()
		var cy_threshold := aabb.position.y + aabb.size.y * 0.92
		var cx_threshold := aabb.size.x * 0.08
		var head_faces: PackedInt32Array = []
		for face_idx in range(mdt.get_face_count()):
			var v0 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 0))
			var v1 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 1))
			var v2 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 2))
			var cy := (v0.y + v1.y + v2.y) / 3.0
			var cx := (v0.x + v1.x + v2.x) / 3.0
			if cy >= cy_threshold and absf(cx) < cx_threshold:
				head_faces.append(face_idx)
		var verts: PackedVector3Array = []
		var normals: PackedVector3Array = []
		var uvs: PackedVector2Array = []
		var bones_arr: PackedInt32Array = []
		var weights_arr: PackedFloat32Array = []
		var indices: PackedInt32Array = []
		var vert_map := {}
		for face_idx in head_faces:
			for fv in range(3):
				var orig_vi := mdt.get_face_vertex(face_idx, fv)
				var key := orig_vi
				if not vert_map.has(key):
					var new_idx := verts.size()
					vert_map[key] = new_idx
					verts.append(mdt.get_vertex(orig_vi))
					normals.append(mdt.get_vertex_normal(orig_vi))
					uvs.append(mdt.get_vertex_uv(orig_vi))
					var bs: PackedInt32Array = mdt.get_vertex_bones(orig_vi)
					var ws: PackedFloat32Array = mdt.get_vertex_weights(orig_vi)
					for b in range(4):
						if b < bs.size():
							bones_arr.append(bs[b])
						else:
							bones_arr.append(0)
					for w in range(4):
						if w < ws.size():
							weights_arr.append(ws[w])
						else:
							weights_arr.append(0.0)
				indices.append(vert_map[key])
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_BONES] = bones_arr
		arrays[Mesh.ARRAY_WEIGHTS] = weights_arr
		arrays[Mesh.ARRAY_INDEX] = indices
		var head_mesh := ArrayMesh.new()
		head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if head_mesh.get_surface_count() > 0 and orig_mat != null:
			head_mesh.surface_set_material(0, orig_mat)
		# Use the original full Body mesh but clip it to the head in the shader.
		# This preserves the original skinning and material, avoiding the fan artefact.
		var shader := Shader.new()
		shader.code = "shader_type spatial;\n" + "uniform sampler2D albedo_texture : source_color;\n" + "uniform vec4 albedo_color : source_color = vec4(1.0);\n" + "uniform float clip_y = 3.45;\n" + "varying float v_local_y;\n" + "void vertex() {\n" + "\tv_local_y = VERTEX.y;\n" + "}\n" + "void fragment() {\n" + "\tif (v_local_y < clip_y) { discard; }\n" + "\tvec4 tex = texture(albedo_texture, UV);\n" + "\tALBEDO = (tex * albedo_color).rgb;\n" + "}\n"
		var head_mat := ShaderMaterial.new()
		head_mat.shader = shader
		if orig_mat is StandardMaterial3D:
			head_mat.set_shader_parameter("albedo_texture", orig_mat.albedo_texture)
			head_mat.set_shader_parameter("albedo_color", orig_mat.albedo_color)
		else:
			head_mat.set_shader_parameter("albedo_color", Color.WHITE)
		head_dup.mesh = head_mesh
		# Create body-without-head mesh (inverse of head extraction)
		var body_nh_dup := src_body.duplicate() as MeshInstance3D
		if body_nh_dup != null:
			body_nh_dup.name = "BodyNoHead"
			var mdt2 := MeshDataTool.new()
			mdt2.create_from_surface(mesh_res, 0)
			var head_face_set := {}
			for hf in head_faces:
				head_face_set[hf] = true
			var verts2: PackedVector3Array = []
			var normals2: PackedVector3Array = []
			var uvs2: PackedVector2Array = []
			var bones_arr2: PackedInt32Array = []
			var weights_arr2: PackedFloat32Array = []
			var indices2: PackedInt32Array = []
			var vert_map2 := {}
			for face_idx in range(mdt2.get_face_count()):
				if head_face_set.has(face_idx):
					continue
				for fv in range(3):
					var orig_vi := mdt2.get_face_vertex(face_idx, fv)
					var key := orig_vi
					if not vert_map2.has(key):
						var new_idx := verts2.size()
						vert_map2[key] = new_idx
						verts2.append(mdt2.get_vertex(orig_vi))
						normals2.append(mdt2.get_vertex_normal(orig_vi))
						uvs2.append(mdt2.get_vertex_uv(orig_vi))
						var bs: PackedInt32Array = mdt2.get_vertex_bones(orig_vi)
						var ws: PackedFloat32Array = mdt2.get_vertex_weights(orig_vi)
						for b in range(4):
							if b < bs.size():
								bones_arr2.append(bs[b])
							else:
								bones_arr2.append(0)
						for w in range(4):
							if w < ws.size():
								weights_arr2.append(ws[w])
							else:
								weights_arr2.append(0.0)
					indices2.append(vert_map2[key])
			var arrays2: Array = []
			arrays2.resize(Mesh.ARRAY_MAX)
			arrays2[Mesh.ARRAY_VERTEX] = verts2
			arrays2[Mesh.ARRAY_NORMAL] = normals2
			arrays2[Mesh.ARRAY_TEX_UV] = uvs2
			arrays2[Mesh.ARRAY_BONES] = bones_arr2
			arrays2[Mesh.ARRAY_WEIGHTS] = weights_arr2
			arrays2[Mesh.ARRAY_INDEX] = indices2
			var body_nh_mesh := ArrayMesh.new()
			body_nh_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays2)
			if body_nh_mesh.get_surface_count() > 0 and orig_mat != null:
				body_nh_mesh.surface_set_material(0, orig_mat)
			body_nh_dup.mesh = body_nh_mesh
			body_nh_dup.skeleton = src_body.skeleton
			body_nh_dup.skin = src_body.skin
			body_nh_dup.visible = false
			src_body.get_parent().add_child(body_nh_dup)
			_body_no_head_mesh = body_nh_dup
	src_body.get_parent().add_child(head_dup)
	# Ensure HeadMesh uses the same skeleton and skin as the original Body
	head_dup.skeleton = src_body.skeleton
	head_dup.skin = src_body.skin
	_full_body_mesh = src_body
	_full_body_mesh.visible = false
	_head_mesh = head_dup
	_head_mesh.visible = true

func _find_skeleton(root: Node) -> Skeleton3D:
	if root == null:
		return null
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _remove_root_motion_drift(animation: Animation, skeleton: Skeleton3D = null) -> void:
	var rest_hips_y := 0.0
	var rest_hips_x := 0.0
	var rest_hips_z := 0.0
	if skeleton != null:
		var hips_bone := skeleton.find_bone("mixamorig_Hips")
		if hips_bone == -1:
			hips_bone = skeleton.find_bone("mixamorig:Hips")
		if hips_bone != -1:
			rest_hips_y = skeleton.get_bone_rest(hips_bone).origin.y
			rest_hips_x = skeleton.get_bone_rest(hips_bone).origin.x
			rest_hips_z = skeleton.get_bone_rest(hips_bone).origin.z
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_POSITION_3D:
			continue
		var key_count := animation.track_get_key_count(track_index)
		if key_count <= 0:
			continue
		var first_value: Variant = animation.track_get_key_value(track_index, 0)
		if not (first_value is Vector3):
			continue
		var last_value: Variant = animation.track_get_key_value(track_index, key_count - 1)
		if not (last_value is Vector3):
			continue
		var first_position := first_value as Vector3
		var last_position := last_value as Vector3
		var drift := last_position - first_position
		var path_text := str(animation.track_get_path(track_index))
		var is_root_hips := path_text.find("mixamorig_Hips") >= 0 or path_text.find("mixamorig:Hips") >= 0
		var is_lower_body := path_text.find("Foot") >= 0 or path_text.find("foot") >= 0 or path_text.find("Leg") >= 0 or path_text.find("leg") >= 0 or path_text.find("Toe") >= 0 or path_text.find("toe") >= 0
		var lock_x := is_root_hips or absf(drift.x) > 2.0
		var lock_y := is_root_hips or is_lower_body or absf(drift.y) > 2.0
		var lock_z := is_root_hips or absf(drift.z) > 2.0
		if not lock_x and not lock_y and not lock_z:
			continue
		for key_index in range(key_count):
			var value: Variant = animation.track_get_key_value(track_index, key_index)
			if value is Vector3:
				var locked_position := value as Vector3
				if lock_x:
					if is_root_hips:
						locked_position.x = rest_hips_x
					else:
						locked_position.x = first_position.x
				if lock_y:
					if is_root_hips:
						locked_position.y = rest_hips_y
					else:
						locked_position.y = first_position.y
				if lock_z:
					if is_root_hips:
						locked_position.z = rest_hips_z
					else:
						locked_position.z = first_position.z
				animation.track_set_key_value(track_index, key_index, locked_position)

func _smooth_loop_boundary(animation: Animation) -> void:
	var blend_keys := 10
	for track_index in range(animation.get_track_count()):
		var key_count := animation.track_get_key_count(track_index)
		if key_count < blend_keys * 2:
			continue
		var track_type := animation.track_get_type(track_index)
		var first_value: Variant = animation.track_get_key_value(track_index, 0)
		if track_type == Animation.TYPE_POSITION_3D and first_value is Vector3:
			var first_pos := first_value as Vector3
			for i in range(blend_keys):
				var idx := key_count - blend_keys + i
				var t := float(i + 1) / float(blend_keys + 1)
				var cur: Variant = animation.track_get_key_value(track_index, idx)
				if cur is Vector3:
					var blended := (cur as Vector3).lerp(first_pos, t)
					animation.track_set_key_value(track_index, idx, blended)
		elif track_type == Animation.TYPE_ROTATION_3D and first_value is Quaternion:
			var first_quat := first_value as Quaternion
			for i in range(blend_keys):
				var idx := key_count - blend_keys + i
				var t := float(i + 1) / float(blend_keys + 1)
				var cur: Variant = animation.track_get_key_value(track_index, idx)
				if cur is Quaternion:
					var blended := (cur as Quaternion).slerp(first_quat, t)
					animation.track_set_key_value(track_index, idx, blended)
		elif track_type == Animation.TYPE_SCALE_3D and first_value is Vector3:
			var first_scale := first_value as Vector3
			for i in range(blend_keys):
				var idx := key_count - blend_keys + i
				var t := float(i + 1) / float(blend_keys + 1)
				var cur: Variant = animation.track_get_key_value(track_index, idx)
				if cur is Vector3:
					var blended := (cur as Vector3).lerp(first_scale, t)
					animation.track_set_key_value(track_index, idx, blended)

func play_action_animation(action_name: String, duration := 1.1) -> void:
	if is_dead or third_person_animation_player == null:
		return
	var target_animation := ""
	var anim_start_offset := 0.0
	match action_name:
		"plant":
			target_animation = third_person_plant_animation
		"fish":
			if _has_fishing_rod and not _rod_fish_start_animation.is_empty():
				target_animation = _rod_fish_start_animation
				_is_fishing_idle = false
				_rod_socket_active = not _rod_visual_overlays.has(THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION)
				var fish_anim := third_person_animation_player.get_animation(target_animation)
				if fish_anim != null:
					fish_anim.loop_mode = Animation.LOOP_NONE
			elif _has_fishing_rod and not _rod_cast_animation.is_empty():
				target_animation = _rod_cast_animation
				_is_fishing_idle = false
				var cast_anim := third_person_animation_player.get_animation(target_animation)
				if cast_anim != null:
					cast_anim.loop_mode = Animation.LOOP_NONE
			else:
				target_animation = third_person_fish_animation
		"fish_end":
			if _has_fishing_rod and not _rod_fish_end_animation.is_empty():
				target_animation = _rod_fish_end_animation
				_is_fishing_idle = false
			else:
				target_animation = third_person_fish_animation
		"forage":
			target_animation = third_person_gather_animation
			if target_animation.is_empty():
				target_animation = third_person_interact_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
		"pickup", "collect":
			# Recoger es instantáneo: sin gesto de agacharse.
			return
		"cook":
			target_animation = third_person_sit_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
		"drink":
			target_animation = third_person_drink_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
		"give":
			target_animation = third_person_give_animation
			if target_animation.is_empty():
				target_animation = third_person_interact_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
		"bow_shoot":
			target_animation = _bow_shoot_animation
			if target_animation.is_empty():
				target_animation = third_person_attack_animation
		"interact", "chop":
			target_animation = third_person_attack_animation
			if target_animation.is_empty():
				target_animation = third_person_interact_animation
			else:
				var chop_anim := third_person_animation_player.get_animation(target_animation)
				if chop_anim != null:
					chop_anim.loop_mode = Animation.LOOP_LINEAR
	if target_animation.is_empty():
		return
	anim_start_offset = _third_person_clip_start_offset(target_animation)
	third_person_action_animation = target_animation
	third_person_action_timer = duration
	third_person_action_start_offset = anim_start_offset
	_rod_action_speed_scale = 1.0
	if duration > 0.0 and (target_animation == _rod_fish_start_animation or target_animation == _rod_fish_end_animation or target_animation == _rod_cast_animation):
		var rod_action := third_person_animation_player.get_animation(target_animation)
		if rod_action != null and rod_action.length > 0.0:
			_rod_action_speed_scale = rod_action.length / duration
	third_person_animation_player.play(target_animation, 0.08)
	if anim_start_offset > 0.0:
		third_person_animation_player.seek(anim_start_offset, true)
	third_person_animation_player.speed_scale = _rod_action_speed_scale
	if target_animation == _rod_fish_start_animation:
		_activate_rod_visual_overlay(THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION)
	elif target_animation == _rod_fish_end_animation:
		_activate_rod_visual_overlay(THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION)
	elif target_animation == _rod_cast_animation:
		_activate_rod_visual_overlay(THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION)
	else:
		_deactivate_rod_visual_overlay()

func _third_person_clip_start_offset(anim: String) -> float:
	# Gesture clips with a long wind-up start partway in so short action windows
	# show the readable part of the motion. The offset is a property of the clip
	# — local playback and remote puppets resolve it identically.
	if anim == third_person_gather_animation:
		return THIRD_PERSON_GATHER_ANIM_OFFSET
	if anim == third_person_interact_animation:
		return THIRD_PERSON_INTERACT_ANIM_OFFSET
	return 0.0

func die(cause: String = "") -> void:
	if is_dead:
		# Already down (e.g. a local death raced the server's order): still honor a
		# melee-death order so the corpse matches what the server broadcast.
		if cause == "melee":
			_apply_melee_death_visual()
		return
	is_dead = true
	# Si moría con el alijo abierto, ninguna tecla podía cerrarlo (todo el
	# gate de _input exige !is_dead) — ciérralo aquí.
	var death_scene := get_tree().current_scene
	if death_scene != null and death_scene.has_method("_close_backpack_ui") and death_scene.get("_backpack_panel") != null:
		death_scene._close_backpack_ui()
	_is_aiming = false
	_breath_hold_active = false
	_remove_scope_overlay()
	mouse_sensitivity = 0.0025
	_death_anim_played = true
	death_pose_time = 0.0
	_apply_view_mode()
	if flashlight != null:
		flashlight.visible = false
	velocity = Vector3.ZERO
	stats.health = 0.0
	stats.dead = true
	stats.changed.emit()
	if cause == "melee":
		_apply_melee_death_visual()
	if not _beaten_death and third_person_animation_player != null:
		third_person_animation_player.stop()
	# Unequip all clothing so the body shows naked parts
	for slot in _equipped_slots.keys():
		var equipped_item := str(_equipped_slots[slot])
		if not equipped_item.is_empty():
			unequip_clothing(equipped_item)

func _apply_melee_death_visual() -> void:
	if _beaten_death:
		return
	if third_person_animation_player == null:
		return
	if third_person_melee_death_animation.is_empty() or not third_person_animation_player.has_animation(third_person_melee_death_animation):
		return
	_beaten_death = true
	# Undo the procedural fall in case it already ran: the clip owns the fall now.
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character != null:
		character.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		character.position = Vector3(0.0, third_person_ground_offset, 0.0)
	third_person_animation_player.play(third_person_melee_death_animation, 0.1)

func _play_hit_reaction(play_impact_sound: bool = true) -> void:
	if is_dead or third_person_animation_player == null:
		return
	if third_person_hit_animation.is_empty() or not third_person_animation_player.has_animation(third_person_hit_animation):
		return
	# Route through the action-anim slot so the clip also travels in
	# sync_player_state — remote puppets see the victim flinch too.
	third_person_action_animation = third_person_hit_animation
	third_person_action_timer = 0.55
	third_person_animation_player.play(third_person_hit_animation, 0.06)
	if play_impact_sound:
		_play_punch_impact_sound()

func _play_shot_reaction() -> void:
	if is_dead or third_person_animation_player == null:
		return
	if third_person_shot_animation.is_empty() or not third_person_animation_player.has_animation(third_person_shot_animation):
		_play_hit_reaction()
		return
	# Route through the action-anim slot so the clip also travels in
	# sync_player_state — remote puppets see the victim flinch too.
	third_person_action_animation = third_person_shot_animation
	third_person_action_timer = 0.5
	third_person_animation_player.play(third_person_shot_animation, 0.06)
	_play_shot_received_sound()

func _update_death_pose(delta: float) -> void:
	if _beaten_death:
		return
	death_pose_time += delta
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	var fall_ratio: float = clamp((death_pose_time - 0.0) / 1.4, 0.0, 1.0)
	var target_rotation := Vector3(-88.0 * fall_ratio, 180.0, 0.0)
	var ground_y: float = max(0.045, _water_sink * 0.18)
	var target_position := Vector3(0.0, lerp(third_person_ground_offset, ground_y, fall_ratio), -0.34 * fall_ratio)
	character.rotation_degrees = character.rotation_degrees.lerp(target_rotation, delta * 5.5)
	character.position = character.position.lerp(target_position, delta * 5.5)

func _resource_path_exists(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if FileAccess.file_exists(path):
		return true
	if path.begins_with("res://"):
		return FileAccess.file_exists(ProjectSettings.globalize_path(path))
	return false

func _hide_third_person_held_props(root: Node) -> void:
	var lower_name := root.name.to_lower()
	if lower_name.find("knife") >= 0 or lower_name.find("bat") >= 0 or lower_name.find("weapon") >= 0 or lower_name.find("gun") >= 0:
		if root is Node3D:
			(root as Node3D).visible = false
	for child in root.get_children():
		_hide_third_person_held_props(child)

func _hide_third_person_export_helpers(root: Node) -> void:
	var lower_name := root.name.to_lower()
	if _is_third_person_export_helper_name(lower_name):
		if root is Node3D:
			(root as Node3D).visible = false
	for child in root.get_children():
		_hide_third_person_export_helpers(child)

func _is_third_person_export_helper_name(lower_name: String) -> bool:
	return lower_name == "cube" or lower_name.find("placeholder") >= 0 or lower_name.find("floor") >= 0

func _calculate_character_scale(character: Node3D, target_height: float) -> float:
	# Measure model height using skeleton bone global poses (in skeleton space)
	var skeleton := _find_skeleton(character)
	if skeleton != null:
		var min_y := 1000000.0
		var max_y := -1000000.0
		# First try: use foot and head/neck bones
		for i in range(skeleton.get_bone_count()):
			var bone_name := skeleton.get_bone_name(i)
			if bone_name.find("Foot") >= 0 or bone_name.find("foot") >= 0 or bone_name.find("Head") >= 0 or bone_name.find("head") >= 0:
				var gp := skeleton.get_bone_global_pose(i)
				min_y = min(min_y, gp.origin.y)
				max_y = max(max_y, gp.origin.y)
		# If range too small, use all bones
		if max_y - min_y < 0.5:
			min_y = 1000000.0
			max_y = -1000000.0
			for i in range(skeleton.get_bone_count()):
				var gp := skeleton.get_bone_global_pose(i)
				min_y = min(min_y, gp.origin.y)
				max_y = max(max_y, gp.origin.y)
		if max_y > min_y:
			return target_height / (max_y - min_y)
	# Fallback: use mesh AABB (skip Body for custom characters - distorted AABB)
	var meshes := []
	_collect_mesh_instances(character, meshes)
	var aabb_min_y := 1000000.0
	var aabb_max_y := -1000000.0
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if is_custom_character and mi.name == "Body":
			continue
		var aabb := mi.get_aabb()
		aabb_min_y = min(aabb_min_y, aabb.position.y)
		aabb_max_y = max(aabb_max_y, aabb.position.y + aabb.size.y)
	if aabb_max_y > aabb_min_y:
		return target_height / (aabb_max_y - aabb_min_y)
	return MIXAMO_CHARACTER_SCALE

func _is_mixamo_root_asset(path: String) -> bool:
	var file_name := path.get_file().to_lower()
	return file_name.find("player_with_clothes") >= 0 \
		or file_name.find("inicio") >= 0 \
		or file_name.find("idle") >= 0 \
		or file_name.find("walking") >= 0 \
		or file_name.find("start walking") >= 0 \
		or file_name.find("pike") >= 0 \
		or file_name.find("run") >= 0 \
		or file_name.find("leftturn") >= 0 \
		or file_name.find("rightturn") >= 0 \
		or file_name.find("remy") >= 0 \
		or file_name.find("personaje") >= 0

func _align_third_person_model_to_ground() -> void:
	if third_person_model == null:
		return
	third_person_ground_offset = 0.0
	third_person_model.position = Vector3.ZERO
	# Measure in third_person_model local space so the offset is independent of
	# the character's current global_position in the world.
	var min_y := 1000000.0
	if is_custom_character or is_clothing_model:
		var skeleton := _find_skeleton(third_person_model)
		if skeleton != null:
			skeleton.force_update_all_bone_transforms()
			for i in range(skeleton.get_bone_count()):
				var bone_name := skeleton.get_bone_name(i)
				if bone_name.find("Foot") >= 0 or bone_name.find("foot") >= 0 or bone_name.find("Toe") >= 0 or bone_name.find("toe") >= 0:
					var gp := skeleton.get_bone_global_pose(i)
					var world_pos: Vector3 = skeleton.global_transform * gp.origin
					var offset_y: float = world_pos.y - third_person_model.global_position.y
					min_y = min(min_y, offset_y)
	# Fallback: use world-scaled height of non-Body meshes relative to third_person_model
	if min_y > 999999.0:
		var was_visible := third_person_model.visible
		third_person_model.visible = true
		var meshes := []
		_collect_mesh_instances(third_person_model, meshes)
		for mesh_node in meshes:
			var mesh_instance := mesh_node as MeshInstance3D
			if is_custom_character and mesh_instance.name == "Body":
				continue
			var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
			var offset_min_y: float = world_aabb.position.y - third_person_model.global_position.y
			min_y = min(min_y, offset_min_y)
		third_person_model.visible = was_visible
	if min_y < 999999.0:
		third_person_ground_offset = 0.025 - min_y
		third_person_model.position.y = third_person_ground_offset

func _collect_mesh_instances(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		var mesh_node := root as MeshInstance3D
		if mesh_node.visible and not _is_third_person_export_helper_name(mesh_node.name.to_lower()):
			result.append(mesh_node)
	for child in root.get_children():
		_collect_mesh_instances(child, result)

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _load_external_node3d(path: String) -> Node3D:
	if _model_cache.has(path):
		var cached = _model_cache[path]
		if cached is PackedScene:
			return (cached as PackedScene).instantiate() as Node3D
	var instance: Node = null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
			_model_cache[path] = loaded
			instance = (loaded as PackedScene).instantiate()
	if instance == null and (path.get_extension().to_lower() == "gltf" or path.get_extension().to_lower() == "glb"):
		instance = _load_gltf_node3d(path)
	if instance is Node3D:
		return instance as Node3D
	if instance != null:
		instance.queue_free()
	return null

func _load_gltf_node3d(path: String) -> Node3D:
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
		var packed := PackedScene.new()
		if packed.pack(generated_scene) == OK:
			_model_cache[path] = packed
			var instance := packed.instantiate() as Node3D
			generated_scene.queue_free()
			return instance
		return generated_scene as Node3D
	if generated_scene != null:
		generated_scene.queue_free()
	return null

func _request_stand_for_items() -> void:
	# Sacar equipo remando te pone de pie automaticamente en lugar de bloquearse.
	if is_instance_valid(rowing_boat) and not _boat_standing and not bool(rowing_boat.get("occupant_standing")):
		rowing_boat.request_toggle_stand()

func _select_held_item(index: int) -> void:
	if is_instance_valid(rowing_boat) and not _boat_standing:
		_request_stand_for_items()
	if inventory == null or index < 0 or index >= inventory.items.size():
		return
	var next_item = inventory.items[index]
	var current_item = get_held_item()
	if current_item != null and current_item != next_item:
		# Cambiar de rifle/cana/palo a otro objeto guarda automaticamente el
		# equipo largo en un hombro libre. Los objetos normales siguen en el
		# inventario y solo se quitan de la mano.
		if can_store_item_on_back(current_item):
			store_held_on_back()
			index = inventory.items.find(next_item)
			if index < 0:
				return
		elif _is_back_only_item(current_item) or _held_item_external:
			_store_held_item()
			if get_held_item() != null:
				return
	if _is_fishing and current_item != next_item:
		_is_fishing = false
		_is_fishing_idle = false
		_deactivate_rod_visual_overlay()
	# Back equipment is never left as an inventory item while it is in the
	# hands. Remove one physical unit and hold that unit externally.
	if _is_back_only_item(next_item):
		var detached = inventory.remove_index(index, 1)
		if detached == null:
			return
		_held_selection_revision += 1
		held_index = -1
		_held_item_reference = detached
		_held_item_external = true
		_sync_held_item()
		return
	_held_selection_revision += 1
	held_index = index
	_held_item_reference = inventory.items[index]
	_held_item_external = false
	_sync_held_item()

func restore_held_item(item_name: String, index: int, item_data: Dictionary = {}) -> void:
	clear_hands()
	if inventory == null or item_name.is_empty():
		return
	if index >= 0 and index < inventory.items.size() and str(inventory.items[index].item_name) == item_name:
		_select_held_item(index)
		return
	# The saved index can be stale after migrations or stack merges; fall back
	# to a name match so a valid held item is not dropped on load.
	for i in range(inventory.items.size()):
		var candidate = inventory.items[i]
		if candidate != null and str(candidate.item_name) == item_name:
			_select_held_item(i)
			return
	# Back equipment held in the hands is kept outside the inventory, so saves
	# carry the item payload instead of an index. Rebuild that single external
	# unit — the same state use_back_item() produces — instead of losing it.
	var item = ItemScript.from_dict(item_data) if not item_data.is_empty() else null
	if item == null:
		item = _legacy_held_back_item(item_name)
	if item != null and _is_back_only_item(item):
		item.quantity = 1
		_held_selection_revision += 1
		held_index = -1
		_held_item_reference = item
		_held_item_external = true
		_sync_held_item()

func _legacy_held_back_item(item_name: String):
	# Older saves stored only the held name, never held_item_data. Rebuild the
	# long equipment that can legitimately sit outside the inventory.
	var back_type := ""
	var weight := 1.0
	if item_name.findn("rifle") >= 0 or item_name.findn("fusil") >= 0:
		back_type = "weapon_rifle"
		weight = 3.5
	elif item_name.findn("caña") >= 0 or item_name.findn("cana") >= 0:
		back_type = "tool_fishing"
		weight = 1.2
	elif item_name == "Palo afilado" or item_name in ["Lanza", "Lanza de hueso"]:
		back_type = "tool_spear"
		weight = 0.8
	elif item_name in ["Arco de madera", "Arco reforzado"]:
		back_type = "weapon_bow"
		weight = 1.1 if item_name == "Arco reforzado" else 0.9
	if back_type.is_empty():
		return null
	return ItemScript.create(item_name, back_type, weight, 1, 0.0)

func equip_item_by_name(item_name: String) -> void:
	if inventory == null:
		return
	for i in range(inventory.items.size() - 1, -1, -1):
		if inventory.items[i].item_name == item_name:
			_select_held_item(i)
			return

func get_held_item():
	if _held_item_reference == null:
		return null
	if _held_item_external:
		return _held_item_reference
	if inventory == null:
		return null
	if not inventory.items.has(_held_item_reference):
		return null
	return _held_item_reference

func has_axe_in_hand() -> bool:
	var item = get_held_item()
	return item != null and (str(item.item_name) in ["Hacha", "Hacha de piedra"] or str(item.item_type) == "tool_axe") and (not item.has_method("is_broken") or not item.is_broken())

#endregion


#region DORMIR Y DESCANSO
func start_sleep(bed_pos: Vector3 = Vector3.ZERO, on_bed: bool = false) -> void:
	if is_dead or is_sleeping:
		return
	if is_in_water:
		notice.emit("No puedes dormir en el agua.")
		return
	is_sleeping = true
	_cancel_aim()
	# Cancel fishing if in progress
	if _is_fishing or _is_fishing_idle:
		_is_fishing = false
		_is_fishing_idle = false
		third_person_action_animation = ""
		third_person_action_timer = 0.0
		third_person_action_start_offset = 0.0
		_deactivate_rod_visual_overlay()
	# Store everything held in hands back to inventory
	if hands != null and hands.has_item_in_hands():
		_store_held_item()
	# Clear torch light if lit
	if torch_light != null and torch_light.visible:
		torch_light.visible = false
	# Clear rifle state
	_rifle_in_hands = false
	if on_bed:
		is_sleeping_on_bed = true
		_bed_sleep_position = bed_pos
		global_position = bed_pos
		_saved_collision_mask = collision_mask
		collision_mask = 0
	_sync_held_item()
	if third_person_animation_player != null and not third_person_sleep_animation.is_empty():
		third_person_animation_player.play(third_person_sleep_animation, 0.3)
	elif third_person_animation_player != null and not third_person_idle_animation.is_empty():
		third_person_animation_player.play(third_person_idle_animation, 0.3)

func stop_sleep() -> void:
	if not is_sleeping:
		return
	is_sleeping = false
	if is_sleeping_on_bed:
		collision_mask = _saved_collision_mask
	is_sleeping_on_bed = false
	_auto_sleep_triggered = false
	if third_person_animation_player != null and not third_person_idle_animation.is_empty():
		third_person_animation_player.play(third_person_idle_animation, 0.3)
	_sync_held_item()

func clear_hands() -> void:
	_held_selection_revision += 1
	_held_item_reference = null
	_held_item_external = false
	_sync_held_item()

func _cycle_held_item() -> void:
	if inventory.items.is_empty():
		return
	if _is_aiming:
		_cancel_aim()
	var next_index: int = (held_index + 1) % inventory.items.size() if get_held_item() != null else 0
	_select_held_item(next_index)
	var item = inventory.items[held_index]
	notice.emit("En mano: %s." % item.item_name)

func _craft_campfire() -> void:
	if inventory == null:
		return
	if not inventory.has_item_name("Tronco", 2) or not inventory.has_item_name("Palo", 1):
		var main_node := get_parent()
		if main_node != null and main_node.has_method("craft_ground_recipe"):
			for r in CraftingSystemScript.RECIPES:
				if r.get("output", {}).get("type", "") == "campfire":
					if main_node.craft_ground_recipe(self, r):
						play_action_animation("plant", 2.0)
						notice.emit("Has crafteado una fogata. Enciendela con cerillas.")
						return
					break
		if not inventory.has_item_name("Tronco", 2):
			notice.emit("Necesitas 2 troncos para craftear una fogata.")
		else:
			notice.emit("Necesitas 1 palo para craftear una fogata.")
		return
	inventory.consume_item_name("Tronco", 2)
	inventory.consume_item_name("Palo", 1)
	play_action_animation("plant", 2.0)
	notice.emit("Crafteando fogata...")
	# Show countdown via parent HUD
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("HUD"):
		var hud_node := parent_node.get_node("HUD")
		if hud_node != null and hud_node.has_method("show_countdown"):
			hud_node.show_countdown("Crafteando fogata", 2.0)
	# Wait for animation then spawn campfire
	await get_tree().create_timer(2.0).timeout
	var pos: Vector3 = global_position + (global_transform.basis * Vector3.FORWARD * 1.5)
	# Keep the player's height: _on_item_dropped raycasts down from pos.y+0.5,
	# so a campfire crafted on a rooftop lands on the roof instead of being
	# pinned to terrain level inside the building.
	pos.y = global_position.y
	item_dropped.emit("campfire", "campfire", 0.0, 1, 0.0, pos, Color(0, 0, 0, 0), false, 0.0)
	notice.emit("Has crafteado una fogata. Enciendela con cerillas.")

func _craft_shelter() -> void:
	get_parent().begin_shelter_placement(self, {}, false)

func get_ground_crafting_tools() -> Array:
	var held = get_held_item()
	if held != null and CraftingSystemScript._is_tool(str(held.item_name)) and not held.is_broken():
		return [held]
	return []

func craft_recipe(recipe: Dictionary, from_ground: bool = false) -> void:
	if inventory == null or not CraftingSystemScript.RECIPES.has(recipe):
		return
	var out: Dictionary = recipe["output"]
	if out["type"] == "shelter":
		get_parent().begin_shelter_placement(self, recipe, from_ground)
		return
	if from_ground:
		var main := get_parent()
		if main == null or not main.has_method("craft_ground_recipe"):
			return
		if not main.craft_ground_recipe(self, recipe):
			notice.emit(CraftingSystemScript.craft_error)
			return
		_post_craft_success(recipe, out)
		return
	# Fogata uses the full campfire flow with animation + spawn
	if out["type"] == "campfire":
		_craft_campfire()
		return
	if out["type"] == "shelter":
		_craft_shelter()
		return
	# Try crafting with inventory only first (original path)
	if not CraftingSystemScript.craft(recipe, inventory):
		notice.emit(CraftingSystemScript.craft_error if CraftingSystemScript.craft_error != "" else "No tienes los materiales necesarios.")
		return
	_post_craft_success(recipe, out)

func _post_craft_success(recipe: Dictionary, out: Dictionary) -> void:
	# Change equipment only after the transaction succeeded.
	for slot in _equipped_slots.keys():
		var clothing_name := str(_equipped_slots[slot])
		if not clothing_name.is_empty() and not inventory.has_item_name(clothing_name):
			unequip_clothing(clothing_name)
	if (str(out.get("type", "")) == "weapon_bow" or str(out.get("name", "")) in ["Arco de madera", "Arco reforzado"]) and _find_free_back_slot() >= 0:
		_store_inventory_item_type_on_back("weapon_bow", "el arco")
	inventory.changed.emit()
	# Determine animation and duration based on recipe type
	var craft_anim := "forage"
	var craft_duration := 2.0
	var out_name := str(out["name"])
	if out_name.find("abierta") >= 0:
		craft_anim = "plant"
		craft_duration = 1.5
		notice.emit("Abriendo lata con cuchillo...")
	else:
		notice.emit("Has crafteado: %s." % out_name)
	# Play crafting animation
	play_action_animation(craft_anim, craft_duration)
	# Show countdown via parent HUD
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("HUD"):
		var hud_node := parent_node.get_node("HUD")
		if hud_node != null and hud_node.has_method("show_countdown"):
			hud_node.show_countdown("Abriendo lata" if craft_anim == "plant" else "Crafteando", craft_duration)
	if craft_anim == "plant":
		await get_tree().create_timer(craft_duration).timeout
		notice.emit("Has abierto la lata. Ya puedes comerla.")
		for _it in inventory.items:
			if _it != null and _it.has_method("is_broken") and _it.is_broken():
				if _it.item_name == "Cuchillo":
					notice.emit("Tu Cuchillo se ha roto!")
				elif _it.item_name == "Hacha":
					notice.emit("Tu Hacha se ha roto!")
				break

func _toggle_sit() -> void:
	var has_rifle := _has_rifle_equipped()
	if is_prone:
		is_prone = false
		is_sitting = false
		_sit_cooldown = 0.3
		if has_rifle and not _rifle_getup_animation.is_empty():
			third_person_action_animation = _rifle_getup_animation
			third_person_action_timer = 2.0
			third_person_animation_player.play(_rifle_getup_animation, 0.1)
		elif not third_person_sit_animation.is_empty():
			third_person_animation_player.play(third_person_sit_animation, 0.1)
		notice.emit("Te levantas.")
	elif is_sitting:
		if has_rifle and not _rifle_prone_animation.is_empty():
			is_prone = true
			is_sitting = false
			_sit_cooldown = 0.3
			third_person_animation_player.play(_rifle_prone_animation, 0.1)
			notice.emit("Te estiras. Pulsa S para levantarte.")
		else:
			is_sitting = false
			_sit_cooldown = 0.3
			notice.emit("Te levantas.")
	else:
		is_sitting = true
		_sit_cooldown = 0.3
		if has_rifle and not _rifle_sit_animation.is_empty():
			third_person_animation_player.play(_rifle_sit_animation, 0.1)
		elif not third_person_sit_animation.is_empty():
			third_person_animation_player.play(third_person_sit_animation, 0.1)
		notice.emit("Te sientas. Pulsa S para tumbarte.")

func _eat_held_item() -> void:
	if _consumption_pending or is_dead:
		return
	var item = get_held_item()
	if item == null or item.item_type != "food":
		notice.emit("No tienes comida en la mano.")
		return
	# Canned food must be opened with knife/axe before eating
	if item.item_name.begins_with("Lata de ") and not item.item_name.ends_with(" abierta") and item.durability > 0.0:
		if not _inventory_has_blade():
			notice.emit("Necesitas un cuchillo o hacha para abrir la lata.")
			return
		if item.quantity > 1:
			# Split one can from the stack, open only that one
			item.quantity -= 1
			var opened = ItemScript.create(item.item_name + " abierta", item.item_type, item.weight, 1, item.use_value)
			opened.durability = 100.0
			opened.max_durability = 100.0
			inventory.changed.emit()
			if not inventory.add_item(opened):
				# No space — revert and put it back
				item.quantity += 1
				inventory.changed.emit()
				notice.emit("No tienes espacio para la lata abierta.")
				return
			# Find the opened can and hold it
			for i in range(inventory.items.size()):
				if inventory.items[i].item_name == item.item_name + " abierta" and inventory.items[i].quantity == 1:
					held_index = i
					break
			_select_held_item(held_index)
		else:
			item.durability = 100.0
			item.max_durability = 100.0
			item.item_name = item.item_name + " abierta"
			inventory.changed.emit()
		notice.emit("Abres la lata con el cuchillo. Ahora puedes comer.")
		return
	_start_consumption(item, "plant", 2.0)

func _start_consumption(item, animation: String, duration: float) -> void:
	if _consumption_pending or is_dead or stats == null:
		return
	_consumption_pending = true
	play_action_animation(animation, duration)
	notice.emit("Bebiendo..." if animation == "drink" else "Comiendo...")
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = maxf(duration, 0.01)
	timer.timeout.connect(func():
		timer.queue_free()
		_consumption_pending = false
		# Resolve by identity: sorting, moving or dropping cannot consume another item.
		if not is_dead and inventory != null and stats != null:
			var index: int = inventory.items.find(item)
			if index >= 0:
				var consumed: bool = inventory.use_index(index, stats)
				if consumed:
					stats.changed.emit()
					if item.item_name == "Carne humana":
						stats.health = 0.0
						stats.changed.emit()
						die()
		_clear_third_person_drink_bottle_left_hand()
		_sync_held_item()
	)
	add_child(timer)
	timer.start()

func _drink_held_item() -> void:
	if _consumption_pending or is_dead:
		return
	var item = get_held_item()
	if item == null or item.item_type != "water":
		notice.emit("No tienes agua en la mano.")
		return
	if item.is_broken():
		notice.emit("La botella esta vacia.")
		return
	if third_person_hand_item_root != null:
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
	_generic_hand_grip = false
	_build_third_person_drink_bottle_left_hand()
	_start_consumption(item, "drink", _drink_animation_length)

func _drop_held_item() -> void:
	var item = get_held_item()
	if item == null:
		# An item mounted on the back is outside the inventory by design. It
		# still needs a single, physical drop path so releasing it cannot leave
		# the back visual behind or create a second copy on the ground.
		if _drop_stored_back_item():
			return
		notice.emit("No tienes nada que soltar.")
		return
	if _held_item_external:
		var item_name := str(item.item_name)
		var item_type := str(item.item_type)
		var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
		drop_pos.y = global_position.y
		set_meta("last_dropped_durability", float(item.durability))
		set_meta("last_dropped_max_durability", float(item.max_durability))
		set_meta("last_dropped_wetness", float(item.wetness))
		set_meta("last_dropped_pelt", str(item.get_meta("pelt_species", "")))
		item_dropped.emit(item_name, item_type, float(item.weight), 1, float(item.use_value), drop_pos, get_current_clothing_color(item_name), item.is_broken(), float(item.spoilage))
		_held_item_reference = null
		_held_item_external = false
		held_index = -1
		_sync_held_item()
		notice.emit("Sueltas %s." % item_name)
		return
	drop_inventory_item(inventory.items.find(item))

func _store_held_item() -> void:
	_held_selection_revision += 1
	var item = get_held_item()
	if item == null:
		notice.emit("No tienes nada en la mano.")
		return
	# Rifle, cana y palo afilado son equipo de espalda. Nunca se guardan como
	# un objeto normal del inventario al pulsar H o el boton equivalente.
	if _is_back_only_item(item) and can_store_item_on_back(item):
		store_held_on_back()
		return
	# Objects taken from a shoulder are held outside the inventory until the
	# player explicitly stores them. Add that single physical unit now; normal
	# inventory-held items are already present and only need their visual cleared.
	if _held_item_external:
		if inventory == null or not inventory.add_item(item):
			notice.emit("No hay espacio para guardar %s." % item.item_name)
			return
	_held_item_reference = null
	_held_item_external = false
	# Clear hands visual - item stays in inventory but is not shown in hand
	if hands != null:
		hands.clear_hands()
	# Re-sync third person equipment: clear hand items but keep backpack on back
	if third_person_hand_item_root != null:
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
	# Rebuild backpack if equipped
	var equip_has_bp: bool = equipment != null and equipment.has_equipped("backpack")
	var eq_bp_set: bool = not equipped_backpack.is_empty()
	if third_person_back_item_root != null:
		if not equip_has_bp:
			for child in third_person_back_item_root.get_children():
				if _stored_back_visuals.has(child):
					continue
				third_person_back_item_root.remove_child(child)
				child.free()
		if (inventory != null or is_puppet) and not equip_has_bp and eq_bp_set:
			_build_third_person_backpack()
	notice.emit("Guardas %s en el inventario." % item.item_name)
	_rifle_in_hands = false
	_sync_third_person_equipment(null)
	_update_crosshair(false)

func drop_inventory_item(index: int) -> void:
	if inventory == null or index < 0 or index >= inventory.items.size():
		return
	var item = inventory.items[index]
	var item_name := str(item.item_name)
	var item_type := str(item.item_type)
	set_meta("last_dropped_camo", clothing_has_camo(item_name, item))
	if CLOTHING_SLOTS.has(item_name):
		unequip_clothing(item_name)
	if item_type == "tool_torch":
		set_meta("last_torch_durability", float(item.durability))
		set_meta("last_torch_lit", torch_light != null and torch_light.visible)
		if torch_light != null:
			torch_light.visible = false
	# Water bottles: append fill state to display name
	if item_type == "water" and item_name == "Botella de agua":
		if float(item.durability) >= float(item.max_durability):
			item_name = "Botella de agua llena"
		elif item.is_broken():
			item_name = "Botella de plastico"
			item_type = "misc"
	# Soltar deja caer una sola unidad del stack; el resto se queda en el
	# inventario (y en la mano si era el objeto sostenido).
	var drop_qty := 1
	var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
	drop_pos.y = global_position.y
	var drop_color := get_current_clothing_color(item_name)
	# Preservar durabilidad al soltar: usar metas del jugador como canal
	# (mismo patron que last_torch_durability)
	set_meta("last_dropped_durability", float(item.durability))
	set_meta("last_dropped_max_durability", float(item.max_durability))
	set_meta("last_dropped_wetness", float(item.wetness))
	set_meta("last_dropped_pelt", str(item.get_meta("pelt_species", "")))
	var is_broken := false
	if item.has_method("is_broken"):
		is_broken = item.is_broken()
	inventory.remove_index(index, drop_qty)
	if item_type == "backpack":
		# El contenido anidado viaja con la unidad soltada solo cuando el stack
		# sale del todo del inventario.
		var packed: Array = []
		if inventory.items.find(item) < 0:
			for c in item.contents:
				if c != null:
					packed.append(c.to_dict())
			item.contents.clear()
		# Only unequip the backpack once its last unit leaves the inventory — a
		# stacked second backpack must keep the worn one equipped.
		if not _has_backpack_in_inventory():
			# El exceso no cabe sin la mochila: viaja dentro del drop, no al suelo.
			packed.append_array(_pack_backpack_drop_contents())
			equipped_backpack = ""
			_recalculate_carry_capacity()
		if not packed.is_empty():
			set_meta("pending_backpack_contents", packed)
	item_dropped.emit(item_name, item_type, float(item.weight), drop_qty, float(item.use_value), drop_pos, drop_color, is_broken, float(item.spoilage))
	# A weapon taken from a shoulder is owned by the hand, not inventory.
	# Dropping unrelated cargo must never clear that external ownership.
	if _held_item_external and _held_item_reference != null:
		held_index = -1
	elif _held_item_reference != null and inventory.items.has(_held_item_reference):
		held_index = inventory.items.find(_held_item_reference)
	else:
		_held_item_reference = null
		_held_item_external = false
		held_index = -1
	_sync_held_item()
	notice.emit("Sueltas %s." % item_name)

# Inicia la animación de ataque como wind-up del lanzamiento
func _start_throw_animation() -> void:
	if not third_person_attack_animation.is_empty() and third_person_animation_player != null:
		var atk_anim := third_person_animation_player.get_animation(third_person_attack_animation)
		if atk_anim != null:
			atk_anim.loop_mode = Animation.LOOP_NONE
		third_person_action_animation = third_person_attack_animation
		third_person_action_timer = 0.8
		third_person_animation_player.play(third_person_attack_animation, 0.08)

# Tirar el item en mano lejos, con fuerza según carga y distancia según peso.
# La animación de ataque ya empezó al cargar. Al soltar G, lanza el objeto
# con toda la fuerza almacenada, usando física real (RigidBody3D).
func _throw_held_item(charge: float) -> void:
	var item = get_held_item()
	if item == null:
		notice.emit("No tienes nada en la mano para tirar.")
		return
	if str(item.item_type) == "weapon_rifle":
		notice.emit("No puedes tirar el rifle.")
		return
	if _consumption_pending or get_tree().current_scene == null:
		return
	# Capture the current prop before inventory.changed rebuilds the hand.
	var thrown_visual := Node3D.new()
	if not _try_spawn_item_visual(thrown_visual, item, str(item.item_name)):
		thrown_visual.free()
		notice.emit("No se ha podido preparar el modelo del objeto.")
		return
	var item_name := str(item.item_name)
	var item_type := str(item.item_type)
	var item_weight := float(item.weight)
	# Mismo preprocesamiento que drop_inventory_item para agua/ropa/antorcha
	if CLOTHING_SLOTS.has(item_name):
		unequip_clothing(item_name)
	if item_type == "tool_torch":
		set_meta("last_torch_durability", float(item.durability))
		set_meta("last_torch_lit", torch_light != null and torch_light.visible)
		if torch_light != null:
			torch_light.visible = false
	if item_type == "water" and item_name == "Botella de agua":
		if float(item.durability) >= float(item.max_durability):
			item_name = "Botella de agua llena"
		elif item.is_broken():
			item_name = "Botella de plastico"
			item_type = "misc"
	var drop_color := get_current_clothing_color(item_name)
	set_meta("last_dropped_durability", float(item.durability))
	set_meta("last_dropped_max_durability", float(item.max_durability))
	set_meta("last_dropped_wetness", float(item.wetness))
	set_meta("last_dropped_pelt", str(item.get_meta("pelt_species", "")))
	var is_broken := false
	if item.has_method("is_broken"):
		is_broken = item.is_broken()
	var item_use_value := float(item.use_value)
	var item_spoilage := float(item.spoilage)
	# Remove exactly one unit by identity, and leave the hand empty even for stacks.
	var idx: int = inventory.items.find(item) if inventory != null else -1
	if idx < 0 and not _held_item_external:
		thrown_visual.free()
		return
	_held_item_reference = null
	_held_item_external = false
	held_index = -1
	_held_selection_revision += 1
	if idx >= 0:
		var removed = inventory.remove_index(idx, 1)
		if removed == null:
			thrown_visual.free()
			return
	# Mochila lanzada: el contenido anidado y el exceso que deja de caber se
	# empaquetan dentro del drop (viajan por drop_data hasta el aterrizaje).
	var thrown_contents: Array = []
	if item_type == "backpack":
		if idx >= 0 and inventory.items.find(item) < 0:
			for c in item.contents:
				if c != null:
					thrown_contents.append(c.to_dict())
			item.contents.clear()
		if not _has_backpack_in_inventory():
			thrown_contents.append_array(_pack_backpack_drop_contents())
			equipped_backpack = ""
			_recalculate_carry_capacity()
	_sync_held_item()
	# Fuerza de lanzamiento: la carga se escala, el peso la reduce
	var weight_factor := 1.0 / (1.0 + item_weight * 0.5)
	var throw_force: float = lerp(THROW_MIN_FORCE, THROW_MAX_FORCE, charge) * weight_factor
	notice.emit("Tiras %s." % item_name)
	# Lanzar desde la posición de la cámara hacia donde mira
	var launch_pos := third_person_hand_item_root.global_position if third_person_hand_item_root != null else camera.global_position
	# Dirección real de la cámara (incluye pitch - donde apunta la vista)
	var cam_dir := -camera.global_transform.basis.z.normalized()
	# Añadir un pequeño ángulo hacia arriba para que no caiga de golpe
	var launch_dir := (cam_dir + Vector3(0, 0.15, 0)).normalized()
	var launch_vel: Vector3 = launch_dir * throw_force
	# Lanzar el objeto con física real (RigidBody3D)
	_spawn_thrown_item_physics(item_name, item_type, item_weight, item_use_value, drop_color, is_broken, item_spoilage, launch_pos, launch_vel, thrown_visual, thrown_contents, str(item.get_meta("pelt_species", "")) if item != null else "")

# Crea un RigidBody3D que vuela con física real (gravedad, colisiones).
# Al aterrizar genera el drop; si cae al agua: splash + ondas + hundimiento.
func _spawn_thrown_item_physics(item_name: String, item_type: String, item_weight: float, item_use_value: float, color: Color, broken: bool, spoilage: float, start_pos: Vector3, velocity: Vector3, prepared_visual: Node3D, contents: Array = [], pelt_species: String = "") -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	# Crear RigidBody3D con física real
	var body := RigidBody3D.new()
	body.name = "ThrownItem_%d" % Time.get_ticks_msec()
	# La colisión sigue aproximadamente el tamaño real del objeto (un cubo fijo
	# hacía que piedras pequeñas y mochilas grandes se comportasen igual).
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = _thrown_item_collision_size(item_name, item_type, item_weight)
	col.shape = shape
	body.add_child(col)
	body.add_child(prepared_visual)
	# Configurar física: gravedad normal, sin dormir
	body.gravity_scale = 1.0
	body.can_sleep = false
	# Capa de colisión: el objeto en capa 2, colisiona con todo excepto el jugador
	body.collision_layer = 2
	body.collision_mask = 1  # colisiona con capa 1 (terreno, objetos)
	# Excluir al jugador de la colisión
	body.add_collision_exception_with(self)
	# Lanzar
	scene.add_child(body)
	body.global_position = start_pos
	body.linear_velocity = velocity
	body.angular_velocity = Vector3(randf_range(-3, 3), randf_range(-3, 3), randf_range(-3, 3))
	# Empaquetar datos del drop para cuando aterrice
	var drop_data := {
		"item_name": item_name,
		"item_type": item_type,
		"item_weight": item_weight,
		"item_use_value": item_use_value,
		"color": color,
		"broken": broken,
		"spoilage": spoilage,
		"contents": contents,
		"pelt": pelt_species
	}
	# Monitorear colisiones para detectar aterrizaje
	var landed := false
	var land_pos := start_pos
	var timeout := 8.0
	var rest_time := 0.0
	while not landed and timeout > 0.0 and is_instance_valid(body):
		await get_tree().physics_frame
		timeout -= 0.016
		# Detectar contacto con suelo/agua; la velocidad baja por sí sola no basta,
		# porque podía convertir un objeto aún en el aire en un drop prematuro.
		var speed := body.linear_velocity.length()
		var water_depth_now := float(scene.call("get_river_depth_at", body.global_position)) if scene.has_method("get_river_depth_at") else 0.0
		var water_surface_y := float(scene.call("get_river_surface_y_at", body.global_position)) if scene.has_method("get_river_surface_y_at") else 0.085
		var ground_y := 0.0
		if scene.has_method("_get_exact_ground_y"):
			ground_y = float(scene.call("_get_exact_ground_y", body.global_position.x, body.global_position.z, body.global_position.y + 5.0))
		var contact_y := water_surface_y if water_depth_now > 0.02 else ground_y
		var crossed_water_surface := water_depth_now > 0.02 and body.global_position.y <= water_surface_y + 0.08
		var reached_ground := water_depth_now <= 0.02 and body.global_position.y <= contact_y + 0.10 and body.linear_velocity.y <= 0.5
		# Un objeto quieto apoyado sobre algo que no es suelo (p.ej. la tapa del
		# collider de un tronco) no cumple reached_ground — tras un reposo breve
		# se toma como aterrizado y el drop final se baja a la superficie real.
		if speed < 0.25:
			rest_time += 0.016
		else:
			rest_time = 0.0
		if crossed_water_surface or reached_ground or rest_time > 0.8:
			landed = true
			land_pos = body.global_position
			break
	if not is_instance_valid(body):
		return
	land_pos = body.global_position
	# Comprobar si cae al agua
	var water_depth := 0.0
	if scene.has_method("get_river_depth_at"):
		water_depth = float(scene.call("get_river_depth_at", land_pos))
	if water_depth > 0.02:
		land_pos.y = float(scene.call("get_river_surface_y_at", land_pos)) if scene.has_method("get_river_surface_y_at") else 0.085
		# Splash + ondas + hundir el objeto
		_spawn_water_splash(land_pos)
		_spawn_water_ripples(land_pos)
		_play_water_splash_sound(land_pos)
		notice.emit("Cae al agua con un chapoteo.")
		# Hundir el objeto visualmente
		_sink_thrown_item(body, land_pos)
		# El item se pierde en el agua (no se puede recuperar)
		return
	# RigidBody origin is at its centre, so its Y value is deliberately above
	# the floor. The world pickup, however, expects its origin on the ground.
	if scene.has_method("_get_exact_ground_y"):
		land_pos.y = float(scene.call("_get_exact_ground_y", land_pos.x, land_pos.z, land_pos.y + 5.0)) + 0.06
	else:
		land_pos.y = 0.06
	body.queue_free()
	# Drop normal en la posición de aterrizaje
	var landed_contents: Array = drop_data.get("contents", [])
	if not landed_contents.is_empty():
		set_meta("pending_backpack_contents", landed_contents)
	set_meta("last_dropped_pelt", str(drop_data.get("pelt", "")))
	item_dropped.emit(
		drop_data["item_name"], drop_data["item_type"],
		drop_data["item_weight"], 1, drop_data["item_use_value"],
		land_pos, drop_data["color"], drop_data["broken"], drop_data["spoilage"]
	)

# Intenta usar el modelo real del item para el objeto lanzado
func _try_spawn_item_visual(parent: Node3D, item, item_name: String) -> bool:
	# Copy all parts, including procedural props, while this item is still held.
	if third_person_hand_item_root != null and get_held_item() == item:
		for child in third_person_hand_item_root.get_children():
			if child is Node3D and not child.is_queued_for_deletion():
				var copy := child.duplicate() as Node3D
				if copy != null:
					parent.add_child(copy)
		if parent.get_child_count() > 0:
			_normalize_thrown_visual(parent, item_name, str(item.item_type))
			return true
	# Opción 2: cargar modelo por nombre (fallback)
	var model_path := ""
	match item_name:
		"Botella de agua", "Botella de agua llena":
			model_path = REAL_BOTTLE_MODEL
		"Botella de plastico":
			model_path = REAL_PLASTIC_BOTTLE_MODEL
		"Carne ensartada", "Pez ensartado", "Carne asada en palo":
			model_path = REAL_MEAT_ON_STICK_MODEL
		"Cuchillo":
			model_path = GameConst.KNIFE_MODEL
		"Palo", "Palo afilado":
			model_path = REAL_WOOD_MODEL
		"Piedra":
			model_path = REAL_STONE_MODEL
		_:
			# Intentar por tipo de item
			if item != null and str(item.item_type) == "tool_torch":
				model_path = REAL_WOOD_MODEL
	if model_path.is_empty():
		return false
	var model := _load_external_node3d(model_path)
	if model == null:
		return false
	model.name = "ThrownItemVisual"
	parent.add_child(model)
	_normalize_thrown_visual(model, item_name, str(item.item_type))
	return true

func _thrown_item_collision_size(item_name: String, item_type: String, item_weight: float) -> Vector3:
	var diameter := 0.22
	if item_type == "tool" or item_type == "tool_axe" or item_type == "weapon":
		diameter = 0.65
	elif item_type == "backpack" or item_type == "clothing":
		diameter = 0.55
	elif item_name in ["Palo", "Palo afilado"]:
		diameter = 0.50
	elif item_name == "Piedra":
		diameter = 0.24
	elif item_type == "food" or item_type == "water":
		diameter = 0.30
	diameter = clampf(diameter + item_weight * 0.01, 0.16, 0.85)
	return Vector3.ONE * diameter

func _normalize_thrown_visual(root: Node3D, item_name: String, item_type: String) -> void:
	var bounds := _hierarchy_local_aabb(root)
	if bounds.size.length_squared() <= 0.000001:
		return
	var target := 0.30
	if item_type == "tool" or item_type == "tool_axe" or item_type == "weapon":
		target = 0.70
	elif item_type == "backpack":
		target = 0.62
	elif item_name in ["Palo", "Palo afilado"]:
		target = 0.55
	elif item_name == "Piedra":
		target = 0.22
	var max_extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if max_extent > 0.0001:
		root.scale *= clampf(target / max_extent, 0.05, 4.0)
	root.position = -bounds.get_center() * root.scale

# Hunde el objeto lanzado en el agua visualmente
func _sink_thrown_item(body: Node3D, at_pos: Vector3) -> void:
	if not is_instance_valid(body):
		return
	# Desactivar física y hundir
	var rb := body as RigidBody3D
	if rb != null:
		rb.freeze = true
	# Tween para hundir: bajar Y y desvanecer
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(body, "global_position", at_pos + Vector3(0, -1.5, 0), 1.5)
	# Desvanecer todos los meshes, también los anidados dentro de un GLB. Duplicar
	# el material evita cambiar accidentalmente el modelo que sigue en la mano.
	var mesh_nodes: Array[MeshInstance3D] = []
	_collect_thrown_meshes(body, mesh_nodes)
	for mesh_node in mesh_nodes:
		var source_mat := mesh_node.material_override as StandardMaterial3D
		if source_mat == null and mesh_node.mesh != null and mesh_node.mesh.get_surface_count() > 0:
			source_mat = mesh_node.mesh.surface_get_material(0) as StandardMaterial3D
		if source_mat == null:
			continue
		var mat := source_mat.duplicate() as StandardMaterial3D
		if mat == null:
			continue
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_node.material_override = mat
		tween.tween_property(mat, "albedo_color:a", 0.0, 1.5)
	tween.chain().tween_callback(func(): body.queue_free())

func _collect_thrown_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_thrown_meshes(child, out)

# Splash de agua: partículas blancas/azules hacia arriba
func _play_water_splash_sound(at_pos: Vector3) -> void:
	var audio = _get_water_audio()
	if audio == null:
		return
	if audio.has_method("play_water_splash"):
		audio.call("play_water_splash", at_pos, true)
	elif audio.has_method("play_sfx"):
		audio.call("play_sfx", "water_splash", at_pos)

func _play_water_step_sound(at_pos: Vector3) -> void:
	var audio = _get_water_audio()
	if audio == null:
		return
	if audio.has_method("play_water_step"):
		audio.call("play_water_step", at_pos, is_sprinting)
	elif audio.has_method("play_sfx"):
		audio.call("play_sfx", "water_step", at_pos)

func _get_water_audio():
	var audio = get_node_or_null("/root/AudioSystem")
	if audio != null:
		return audio
	if has_meta("audio_system"):
		audio = get_meta("audio_system")
		if audio != null and is_instance_valid(audio):
			return audio
	# In the normal game AudioSystem is a child of Main, while the current
	# scene is Inicio. Walk the ownership tree so both launch paths resolve it.
	var owner_node: Node = self
	while owner_node != null:
		var scene_audio = owner_node.get("audio_system")
		if scene_audio != null and is_instance_valid(scene_audio):
			return scene_audio
		owner_node = owner_node.get_parent()
	return null

func _spawn_water_splash(at_pos: Vector3, strength: float = 1.0, motion: Vector3 = Vector3.ZERO) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	strength = clampf(strength, 0.1, 1.0)
	if _water_droplet_mesh == null:
		_water_droplet_mesh = SphereMesh.new()
		_water_droplet_mesh.radius = 0.012
		_water_droplet_mesh.height = 0.034
		_water_droplet_mesh.radial_segments = 8
		_water_droplet_mesh.rings = 4
		var droplet_mat := StandardMaterial3D.new()
		droplet_mat.albedo_color = Color(0.64, 0.77, 0.80, 0.72)
		droplet_mat.roughness = 0.16
		droplet_mat.metallic_specular = 0.8
		droplet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		droplet_mat.vertex_color_use_as_albedo = true
		_water_droplet_mesh.material = droplet_mat
	var particles := GPUParticles3D.new()
	particles.name = "WaterSplash"
	particles.emitting = false
	particles.amount = int(lerpf(14.0, 48.0, strength))
	particles.lifetime = lerpf(0.38, 0.8, strength)
	particles.explosiveness = 0.94
	particles.one_shot = true
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ParticleProcessMaterial.new()
	mat.direction = (Vector3.UP + motion.limit_length(5.0) * 0.12).normalized()
	mat.spread = lerpf(48.0, 65.0, strength)
	mat.initial_velocity_min = lerpf(0.65, 1.6, strength)
	mat.initial_velocity_max = lerpf(1.2, 3.4, strength)
	mat.gravity = Vector3(0, -9.8, 0)
	mat.scale_min = 0.35
	mat.scale_max = lerpf(0.85, 1.5, strength)
	mat.color_ramp = _make_fade_ramp(0.03, 0.35)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = lerpf(0.045, 0.14, strength)
	particles.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	particles.process_material = mat
	particles.draw_pass_1 = _water_droplet_mesh
	scene.add_child(particles)
	particles.global_position = at_pos + Vector3(0, 0.025, 0)
	particles.emitting = true
	var cleanup := particles.create_tween()
	cleanup.tween_interval(particles.lifetime + 0.2)
	cleanup.tween_callback(particles.queue_free)

# Ondas concéntricas en el agua: anillos que se expanden y se desvanecen
func _spawn_water_ripples(at_pos: Vector3, strength: float = 1.0, motion: Vector3 = Vector3.ZERO) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	strength = clampf(strength, 0.1, 1.0)
	if _water_ripple_shader == null:
		_water_ripple_shader = Shader.new()
		_water_ripple_shader.code = """
shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never;
uniform float progress = 0.0;
uniform float travel = 1.0;
uniform float phase = 0.0;
uniform float opacity = 0.3;
void vertex() {
	vec2 radial = normalize(VERTEX.xz);
	float angle = atan(radial.y, radial.x);
	float wobble = sin(angle * 5.0 + phase) * 0.012 + sin(angle * 9.0 - phase) * 0.006;
	VERTEX.xz += radial * (travel * progress + wobble * smoothstep(0.0, 0.2, progress));
	VERTEX.y *= 1.0 - progress * 0.8;
}
void fragment() {
	float breakup = 0.65 + 0.35 * sin(UV.x * 43.9823 + phase + progress * 2.0);
	float envelope = smoothstep(0.0, 0.08, progress) * pow(1.0 - progress, 1.7);
	ALBEDO = vec3(0.40, 0.57, 0.60);
	ROUGHNESS = 0.19;
	SPECULAR = 0.8;
	ALPHA = opacity * envelope * breakup;
}
"""
	var ring_count := 3 if strength >= 0.65 else 2
	for i in range(ring_count):
		var ring := MeshInstance3D.new()
		ring.name = "WaterRipple_%d" % i
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.10
		ring_mesh.outer_radius = 0.13
		ring_mesh.rings = 64
		ring_mesh.ring_segments = 6
		ring.mesh = ring_mesh
		var mat := ShaderMaterial.new()
		mat.shader = _water_ripple_shader
		var travel := lerpf(0.45, 1.65, strength) * (1.0 - float(i) * 0.12)
		mat.set_shader_parameter("travel", travel)
		mat.set_shader_parameter("phase", randf_range(0.0, TAU))
		mat.set_shader_parameter("opacity", lerpf(0.30, 0.55, strength) / (1.0 + float(i) * 0.4))
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.custom_aabb = AABB(Vector3(-2.0, -0.1, -2.0), Vector3(4.0, 0.2, 4.0))
		scene.add_child(ring)
		ring.global_position = at_pos + Vector3(0, 0.022 + float(i) * 0.002, 0)
		ring.rotation.y = atan2(motion.x, motion.z)
		ring.scale = Vector3(1.0, 0.22, 1.0 + minf(motion.length() * 0.025, 0.12))
		# TorusMesh ya está orientado alrededor del eje Y: queda horizontal sobre
		# la superficie del agua (rotarlo en X lo dejaba vertical).
		# Animar expansión y fade
		ring.visible = false
		var delay := i * 0.16
		var tween := ring.create_tween()
		tween.tween_interval(delay)
		tween.tween_callback(func(): ring.visible = true)
		tween.tween_method(func(progress: float):
			mat.set_shader_parameter("progress", progress)
		, 0.0, 1.0, lerpf(1.1, 2.1, strength))
		tween.tween_callback(ring.queue_free)
#endregion


#region ITEMS EN MANO Y EQUIPAMIENTO (PlayerHeldItems)
func _sync_held_item() -> void:
	var held_item = get_held_item()
	if held_item == null:
		_generic_hand_grip = false
		_held_item_reference = null
		_held_item_external = false
		if hands != null:
			hands.clear_hands()
		_sync_third_person_equipment(null)
		_update_crosshair(false)
		return
	held_index = inventory.items.find(held_item) if inventory != null else -1
	if hands != null:
		hands.clear_hands()
		hands.current_item = held_item
	# Build the third-person prop after the item is marked as held. Several
	# equipment paths consult hands.has_item_in_hands() while synchronizing.
	_sync_third_person_equipment(held_item)
	_fit_held_prop_to_palm(held_item)
	_update_hand_socket()
	_update_crosshair(_has_rifle_equipped())

func _sync_third_person_equipment(held_item) -> void:
	_generic_hand_grip = false
	for stored_visual in _stored_back_visuals:
		if stored_visual != null and is_instance_valid(stored_visual):
			# El objeto del hombro sigue visible mientras se usa el otro
			# hombro o se lleva algo en la mano.
			stored_visual.visible = true
	if is_instance_valid(third_person_back_item_root):
		for slot in _stored_back_items.size():
			if _is_back_slot_occupied(slot) and not is_instance_valid(_stored_back_visuals[slot]):
				_build_stored_back_visual(slot)
	_rifle_in_hands = held_item != null and str(held_item.item_type) == "weapon_rifle"
	# Hide torch character when not holding a torch
	_torch_in_hands = held_item != null and str(held_item.item_type) == "tool_torch"
	_has_fishing_rod = held_item != null and str(held_item.item_type) == "tool_fishing"
	# Don't load rod animations here — only when fishing starts.
	# The rod visual uses the fallback model (ROD_MODEL_PATH) immediately.
	if not _has_fishing_rod:
		_is_fishing_idle = false
		_deactivate_rod_visual_overlay()
	var _is_holding_torch := _torch_in_hands
	if not _is_holding_torch:
		_clear_torch_attachment()
	if third_person_hand_item_root == null or third_person_back_item_root == null:
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			return
		return
	if is_sleeping:
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
		_clear_rifle_attachment()
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			return
	# Rebuild the hand slot from a clean state. Inventory change notifications
	# can synchronize the same equipped item repeatedly; retaining the previous
	# visual here accumulated duplicate rods and left one visible while fishing.
	for child in third_person_hand_item_root.get_children():
		third_person_hand_item_root.remove_child(child)
		child.free()
	_clear_rifle_attachment()
	var equip_has_bp: bool = equipment != null and equipment.has_equipped("backpack")
	if not equip_has_bp:
		for child in third_person_back_item_root.get_children():
			if _stored_back_visuals.has(child):
				continue
			third_person_back_item_root.remove_child(child)
			child.free()
	var eq_bp_set: bool = not equipped_backpack.is_empty()
	# Los puppets no tienen inventory: sin la excepcion el BackpackAsset
	# borrado arriba nunca se reconstruia y la mochila remota desaparecia.
	if (inventory != null or is_puppet) and not equip_has_bp and eq_bp_set:
		_build_third_person_backpack()
	# Ownership changes happen in pickup/store actions, never while drawing.
	_clear_rifle_on_back()
	# Caña de pescar: si está en el inventario y no en mano, moverla a la espalda
	var _has_rod_in_inventory := false
	if inventory != null and not inventory.items.is_empty():
		for item in inventory.items:
			if item != null and str(item.item_type) == "tool_fishing":
				_has_rod_in_inventory = true
				break
	var _rod_in_hands := held_item != null and str(held_item.item_type) == "tool_fishing"
	if _has_rod_in_inventory and not _rod_in_hands and not _has_stored_back_item_type("tool_fishing") and _back_slot_count() < 2:
		_store_inventory_fishing_rod_on_back()
	if hands != null and hands.has_item_in_hands():
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			_build_third_person_rifle(str(held_item.item_name))
			_initialize_rifle_ammo()
			return
	if held_item == null:
		return
	var held_name := str(held_item.item_name)
	# Older saves can retain Hacha with the generic "tool" type. Resolve by
	# name before the generic tool/flashlight fallback so it always gets the axe.
	if held_name in ["Hacha", "Hacha de piedra"]:
		_build_third_person_axe()
		_clear_rifle_attachment()
		return
	if held_name in ["Arco de madera", "Arco reforzado", "Flecha de madera", "Flecha de piedra", "Flecha de hueso", "Flecha improvisada", "Lanza", "Lanza de hueso", "Palo afilado", "Boleadoras", "Cuerda", "Hueso", "Tendón", "Pluma", "Piedra afilada", "Cuchillo de piedra", "Cuchillo de hueso"]:
		_build_third_person_primitive(held_name)
		_clear_rifle_attachment()
		return
	if flashlight.visible and str(held_item.item_type) == "tool" and held_name in ["Linterna", "Flashlight"]:
		_build_third_person_flashlight()
		return
	match held_item.item_type:
		"backpack":
			_build_third_person_tool(_backpack_model_path(str(held_item.item_name)), "ThirdPersonBackpack", Color(0.2, 0.25, 0.12))
		"weapon":
			if str(held_item.item_name) == "Lanza":
				_build_third_person_resource("Palo afilado")
			else:
				_build_third_person_knife()
			_clear_rifle_attachment()
		"weapon_rifle":
			_build_third_person_rifle(str(held_item.item_name))
			_initialize_rifle_ammo()
		"tool":
			if held_name == "Pala":
				_build_third_person_tool(REAL_SHOVEL_MODEL, "ThirdPersonShovel", Color(0.18, 0.16, 0.12), 1.15)
			elif held_name == "Martillo":
				_build_third_person_tool(REAL_HAMMER_MODEL, "ThirdPersonHammer", Color(0.20, 0.15, 0.09))
			elif held_name == "Pico":
				_build_third_person_tool(REAL_PICKAXE_MODEL, "ThirdPersonPickaxe", Color(0.18, 0.15, 0.10), 0.9)
			else:
				_build_third_person_flashlight()
			_clear_rifle_attachment()
		"food":
			_build_held_food(str(held_item.item_name))
			_clear_rifle_attachment()
		"tool_matches":
			# The imported matchbox contains helper meshes with offsets intended for
			# the floor pickup. Use a compact hand prop so every part stays together.
			_add_held_box(third_person_hand_item_root, "HeldMatches", Vector3(0.12, 0.05, 0.075), Vector3.ZERO, Color(0.38, 0.16, 0.07), Vector3.ZERO)
		"water":
			var wname := str(held_item.item_name)
			if wname == "Botella de agua" or wname == "Botella de agua llena":
				_build_third_person_plastic_bottle()
			else:
				_build_third_person_bottle()
			_clear_rifle_attachment()
		"medical":
			_build_third_person_bandage()
			_clear_rifle_attachment()
		"battery":
			_build_third_person_battery()
			_clear_rifle_attachment()
		"tool_spear":
			_build_third_person_resource("Palo afilado")
		"resource", "material":
			_build_third_person_resource(str(held_item.item_name))
			_clear_rifle_attachment()
		"seed":
			_build_third_person_seed_bag()
			_clear_rifle_attachment()
		"clothing":
			_build_held_clothing(str(held_item.item_name))
			_clear_rifle_attachment()
		"misc":
			if str(held_item.item_name) == "Botella de plastico":
				_build_third_person_plastic_bottle()
			else:
				_build_third_person_pack()
			_clear_rifle_attachment()
		"tool_torch":
			_build_third_person_torch()
			_clear_rifle_attachment()
		"tool_fishing":
			_build_third_person_fishing_rod()
			_clear_rifle_attachment()
		"tool_axe":
			_build_third_person_axe()
			_clear_rifle_attachment()
		"tool_hoe":
			_build_third_person_tool(REAL_HOE_MODEL, "ThirdPersonHoe", Color(0.20, 0.14, 0.08), 1.5)
			_clear_rifle_attachment()
		"tool_shovel":
			_build_third_person_tool(REAL_SHOVEL_MODEL, "ThirdPersonShovel", Color(0.18, 0.16, 0.12), 1.15)
			_clear_rifle_attachment()
		"tool_hammer":
			_build_third_person_tool(REAL_HAMMER_MODEL, "ThirdPersonHammer", Color(0.20, 0.15, 0.09))
			_clear_rifle_attachment()
		"tool_pickaxe":
			_build_third_person_tool(REAL_PICKAXE_MODEL, "ThirdPersonPickaxe", Color(0.18, 0.15, 0.10), 0.9)
			_clear_rifle_attachment()
		"ammo":
			_add_named_held_model(RIFLE_MAGAZINE_MODEL, "HeldRifleMagazine")
			_clear_rifle_attachment()
		_:
			_build_third_person_pack()
			_clear_rifle_attachment()

func _add_named_held_model(path: String, label: String) -> bool:
	if not _try_add_model_to_parent(third_person_hand_item_root, path, label, Vector3.ZERO, Vector3.ZERO, Vector3.ONE):
		return false
	var node := third_person_hand_item_root.get_node_or_null(label) as Node3D
	if node == null:
		return false
	var bounds := _hierarchy_local_aabb(node)
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if extent <= 0.00001:
		return true
	var target := 0.16
	if label == "HeldMatches": target = 0.13
	elif label == "HeldClothing": target = 0.25
	elif label == "HeldFish" or label == "HeldMeat" or label == "HeldFig": target = 0.18
	node.scale *= target / extent
	node.position = -bounds.get_center() * node.scale
	return true

func _build_held_food(item_name: String) -> void:
	if item_name.begins_with("Lata de "):
		var path := "res://assets/models/props/food_can_415g.glb" if item_name.begins_with("Lata de atun") else "res://assets/models/props/canned_food_low.glb"
		_add_named_held_model(path, "HeldFoodCan")
	elif "ensartad" in item_name or item_name == "Carne asada en palo":
		_build_held_skewer(item_name)
	elif item_name.begins_with("Carne"):
		_add_named_held_model(REAL_MEAT_ON_STICK_MODEL, "HeldMeat")
	elif item_name.begins_with("Pez"):
		_add_named_held_model("res://assets/models/props/fish.glb", "HeldFish")
	elif item_name == "Naranja":
		_add_held_sphere(third_person_hand_item_root, "HeldOrange", Vector3.ONE * 0.08, Vector3.ZERO, Color(0.95, 0.35, 0.025), Vector3.ZERO)
	elif item_name == "Higo":
		_add_named_held_model("res://assets/models/props/fruit/fig.glb", "HeldFig")
	elif item_name.begins_with("Seta"):
		_add_named_held_model("res://assets/models/environment/mushrooms/amanita_muscaria_mushroom.glb", "HeldMushroom")
	elif item_name == "Bayas silvestres" or item_name == "Verduras":
		for i in range(3):
			var berry := item_name == "Bayas silvestres"
			_add_held_sphere(third_person_hand_item_root, "HeldProduce%d" % i, Vector3.ONE * 0.025, Vector3((i - 1) * 0.035, 0.012 * (i % 2), 0), Color(0.4, 0.05, 0.12) if berry else Color(0.2, 0.45, 0.08), Vector3.ZERO)
	else:
		_build_third_person_pack()

func _build_held_skewer(item_name: String) -> void:
	# Use a common frame for the stick and food; imported origins differ wildly.
	_add_held_cylinder(third_person_hand_item_root, "SkewerStick", 0.008, 0.50, Vector3.ZERO, Color(0.3, 0.18, 0.08), Vector3.ZERO)
	var food := _load_external_node3d("res://assets/models/props/fish.glb" if item_name == "Pez ensartado" else REAL_MEAT_ON_STICK_MODEL)
	if food == null:
		return
	food.name = "SkeweredFood"
	var bounds := _hierarchy_local_aabb(food)
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if extent <= 0.00001:
		food.free()
		return
	food.scale = Vector3.ONE * (0.18 / extent)
	food.position = Vector3(0, 0.14, 0) - food.basis * bounds.get_center()
	third_person_hand_item_root.add_child(food)

func _build_held_clothing(item_name: String) -> void:
	var path := MilitaryJackets.pickup_path(item_name)
	match item_name:
		"Pasamontañas": path = "res://assets/characters/adapted/civil/pickup_balaclava.glb"
		"Pasamontañas navideño": path = "res://assets/characters/adapted/civil/pickup_balaclava_navideno.glb"
		"Camiseta": path = "res://assets/characters/adapted/pickup_default_tops.glb"
		"Pantalones": path = "res://assets/characters/adapted/pickup_default_bottoms.glb"
		"Zapatillas": path = "res://assets/characters/adapted/pickup_default_shoes.glb"
		"Sombrero de pescador": path = GameConst.FISHERMANS_HAT_MODEL
		"Gorro de piel": path = GameConst.FISHERMANS_HAT_MODEL
		"Tocado de piel animal":
			var held = get_held_item()
			var held_pelt := str(held.get_meta("pelt_species", "")) if held != null else ""
			path = str(GameConst.PELT_HEADDRESS.get(held_pelt, GameConst.PELT_HEADDRESS[GameConst.PELT_DEFAULT_SPECIES]))
		"Casco militar": path = GameConst.MILITARY_HELMET_MODEL
		"Guantes survival", "Guantes de trabajo", "Guantes militares": path = GameConst.GARDEN_GLOVES_MODEL
		"Guantes de piel": path = "res://assets/characters/adapted/pickup_soldier_hands.glb"
		"Botas militares": path = "res://assets/characters/adapted/pickup_military_boots.glb"
		"Botas de piel": path = "res://assets/characters/adapted/pickup_military_boots.glb"
		_:
			if item_name.begins_with("Pantalones"):
				path = "res://assets/characters/adapted/pickup_soldier_legs.glb"
	if path.is_empty() or not _add_named_held_model(path, "HeldClothing"):
		_build_third_person_clothing_bundle()
	elif item_name in GameConst.PELT_FUR_ITEMS and item_name != "Tocado de piel animal":
		# Held pelt garment: fur of the species it was sewn from.
		var held2 = get_held_item()
		var sp2 := str(held2.get_meta("pelt_species", "")) if held2 != null else ""
		var fm := _pelt_fur_material(sp2) if not sp2.is_empty() else null
		if fm != null:
			var held_node := third_person_hand_item_root.get_node_or_null("HeldClothing") if third_person_hand_item_root != null else null
			if held_node != null:
				var _hm: Array = []
				_collect_mesh_instances(held_node, _hm)
				for _mi in _hm:
					(_mi as MeshInstance3D).material_override = fm
	else:
		var held_node2 := third_person_hand_item_root.get_node_or_null("HeldClothing") if third_person_hand_item_root != null else null
		var scene_main := get_tree().current_scene if is_inside_tree() else null
		if held_node2 != null and scene_main != null and scene_main.has_method("_apply_military_drop_material"):
			scene_main._apply_military_drop_material(item_name, held_node2, get_current_clothing_color(item_name))

func _backpack_model_path(bp_name: String = "") -> String:
	if bp_name.is_empty():
		bp_name = equipped_backpack
	return GameConst.MILITARY_BACKPACK_MODEL if bp_name == "Mochila militar" else REAL_BACKPACK_MODEL

func _build_third_person_backpack() -> void:
	var bp_node := _load_external_node3d(_backpack_model_path())
	if bp_node == null:
		return
	var raw_aabb := _hierarchy_local_aabb(bp_node)
	if raw_aabb.size.y <= 0.0001 or raw_aabb.size.x <= 0.0001 or raw_aabb.size.z <= 0.0001:
		bp_node.queue_free()
		return
	bp_node.name = "BackpackAsset"
	var worn_height := 1.15 if equipped_backpack == "Mochila militar" else 1.3
	var bp_scale := worn_height / raw_aabb.size.y
	bp_node.scale = Vector3.ONE * bp_scale
	var center_offset := Vector3(
		-(raw_aabb.position.x + raw_aabb.size.x * 0.5) * bp_scale,
		-(raw_aabb.position.y + raw_aabb.size.y * 0.5) * bp_scale,
		-(raw_aabb.position.z + raw_aabb.size.z * 0.5) * bp_scale
	)
	bp_node.position = center_offset
	if equipped_backpack == "Mochila militar":
		bp_node.position.y -= 0.07
	bp_node.rotation_degrees = Vector3(0, 180, 0)
	third_person_back_item_root.add_child(bp_node)

func _build_third_person_knife() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, GameConst.KNIFE_MODEL, "ThirdPersonKnife", Vector3(0.0, 0.09, 0.02), Vector3(0, 90, 0), Vector3.ONE * 0.8)

func _traverse_mesh_aabb(node: Node, accumulated: Transform3D, state: Dictionary) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		mi.visible = true
		var local_aabb := mi.get_aabb()
		if local_aabb.size != Vector3.ZERO:
			var world_aabb := accumulated * local_aabb
			if not state["has_aabb"]:
				state["aabb"] = world_aabb
				state["has_aabb"] = true
			else:
				state["aabb"] = (state["aabb"] as AABB).merge(world_aabb)
			state["mesh_count"] = state["mesh_count"] + 1
			var mc: int = state["mesh_count"]
	for child in node.get_children():
		if child is Node3D:
			var child_acc := accumulated * (child as Node3D).transform
			_traverse_mesh_aabb(child, child_acc, state)
		else:
			_traverse_mesh_aabb(child, accumulated, state)

func _disable_collision_recursive(node: Node) -> void:
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	elif node is CollisionObject3D:
		(node as CollisionObject3D).collision_layer = 0
		(node as CollisionObject3D).collision_mask = 0
	for child in node.get_children():
		_disable_collision_recursive(child)

func can_store_held_on_back() -> bool:
	return can_store_item_on_back(get_held_item())

func _back_slot_count() -> int:
	var count := 0
	for slot in range(_stored_back_items.size()):
		if _is_back_slot_occupied(slot):
			count += 1
	return count

func _is_back_slot_occupied(slot: int) -> bool:
	if slot < 0 or slot >= _stored_back_items.size():
		return false
	var entry = _stored_back_items[slot]
	return entry is Dictionary and not str(entry.get("name", "")).is_empty()

func _find_free_back_slot() -> int:
	for slot in range(_stored_back_items.size()):
		var entry = _stored_back_items[slot]
		if not (entry is Dictionary) or str(entry.get("name", "")).is_empty():
			return slot
	return -1

func _back_shoulder_label(slot: int) -> String:
	return "izquierdo" if slot == BACK_SLOT_LEFT else "derecho"

func _is_back_only_item(item) -> bool:
	if item == null:
		return false
	var item_type := str(item.item_type)
	return item_type == "weapon_rifle" or item_type == "weapon_bow" or item_type == "tool_fishing" or item_type == "tool_spear" or str(item.item_name) in ["Palo afilado", "Lanza", "Lanza de hueso"]

func receive_pickup_item(item) -> bool:
	if item == null or inventory == null:
		return false
	if (str(item.item_type) in ["weapon_rifle", "weapon_bow"] or str(item.item_name) in ["Arco de madera", "Arco reforzado"]) and int(item.quantity) == 1:
		var slot := _find_free_back_slot()
		if slot >= 0:
			_stored_back_items[slot] = _back_data_from_item(item)
			_build_stored_back_visual(slot)
			inventory.changed.emit()
			return true
	return inventory.add_item(item)

func _back_data_from_item(item) -> Dictionary:
	if item == null:
		return {}
	var data: Dictionary = item.to_dict()
	data["quantity"] = 1
	return data

func _has_stored_back_item_type(item_type: String) -> bool:
	for entry in _stored_back_items:
		if entry is Dictionary and str(entry.get("type", "")) == item_type:
			return true
	return false

func _store_inventory_rifle_on_back() -> bool:
	return _store_inventory_item_type_on_back("weapon_rifle", "el rifle")

func _store_inventory_fishing_rod_on_back() -> bool:
	return _store_inventory_item_type_on_back("tool_fishing", "la caña")

func _store_inventory_item_type_on_back(item_type: String, label: String) -> bool:
	if inventory == null:
		return false
	var slot := _find_free_back_slot()
	if slot < 0:
		return false
	var item_index := -1
	var item = null
	for index in range(inventory.items.size()):
		var candidate = inventory.items[index]
		if candidate != null and str(candidate.item_type) == item_type:
			item_index = index
			item = candidate
			break
	if item_index < 0 or item == null:
		return false
	_stored_back_items[slot] = {
		"name": str(item.item_name),
		"type": str(item.item_type),
		"weight": float(item.weight),
		"use_value": float(item.use_value),
		"durability": float(item.durability),
		"max_durability": float(item.max_durability),
		"spoilage": float(item.spoilage)
	}
	# Remove exactly one physical item. A stack, if present, keeps its
	# remaining units in the inventory.
	if int(item.quantity) > 1:
		item.quantity -= 1
	else:
		inventory.items.remove_at(item_index)
	_build_stored_back_visual(slot)
	inventory.changed.emit()
	notice.emit("Guardas %s en el hombro %s." % [label, _back_shoulder_label(slot)])
	return true

func can_store_item_on_back(item) -> bool:
	if item == null or inventory == null or _find_free_back_slot() < 0:
		return false
	var item_type := str(item.item_type)
	if item_type == "weapon_rifle" or item_type == "weapon_bow":
		return true
	# Una caña hecha con cuerda ya lleva su propio cordel y se puede colgar.
	if item_type == "tool_fishing":
		return str(item.item_name) in ["Caña de pescar", "Caña simple"] or inventory.has_item_name("Cuerda")
	# El palo afilado o lanza necesita una cuerda disponible para sujetarlo a la espalda.
	if item_type == "tool_spear" or str(item.item_name) in ["Palo afilado", "Lanza", "Lanza de hueso"]:
		return str(item.item_name) == "Lanza de hueso" or inventory.has_item_name("Cuerda")
	return false

func get_back_item_data(slot: int) -> Dictionary:
	if slot < 0 or slot >= _stored_back_items.size():
		return {}
	var data = _stored_back_items[slot]
	return data.duplicate(true) if data is Dictionary else {}

func use_back_item(slot: int = -1) -> bool:
	_request_stand_for_items()
	if slot < 0:
		# El atajo usa primero el hombro derecho, que es el ultimo ocupado.
		if _is_back_slot_occupied(BACK_SLOT_RIGHT):
			slot = BACK_SLOT_RIGHT
		elif _is_back_slot_occupied(BACK_SLOT_LEFT):
			slot = BACK_SLOT_LEFT
	if slot < 0 or slot >= _stored_back_items.size():
		return false
	var data = _stored_back_items[slot]
	if not data is Dictionary or str(data.get("name", "")).is_empty():
		return false
	# If the hand already carries back equipment, swap it directly into the
	# shoulder slot being used. It must never be routed through the inventory.
	var held_item = get_held_item()
	var replacement_data: Dictionary = {}
	if held_item != null and _is_back_only_item(held_item):
		replacement_data = _back_data_from_item(held_item)
		var held_inventory_index: int = inventory.items.find(held_item) if inventory != null else -1
		if hands != null:
			hands.clear_hands()
		if third_person_hand_item_root != null:
			for child in third_person_hand_item_root.get_children():
				third_person_hand_item_root.remove_child(child)
				child.free()
		_held_item_reference = null
		_held_item_external = false
		held_index = -1
		if held_inventory_index >= 0 and inventory != null:
			inventory.remove_index(held_inventory_index, 1)
	elif held_item != null:
		_store_held_item()
		if get_held_item() != null:
			return false
	var item_data: Dictionary = data.duplicate(true)
	item_data["quantity"] = 1
	var item = ItemScript.from_dict(item_data)
	if item == null:
		return false
	var stored_visual = _stored_back_visuals[slot]
	if stored_visual != null and is_instance_valid(stored_visual):
		stored_visual.free()
	_stored_back_visuals[slot] = null
	_stored_back_items[slot] = replacement_data if not replacement_data.is_empty() else null
	if not replacement_data.is_empty():
		_build_stored_back_visual(slot)
	_held_selection_revision += 1
	held_index = -1
	_held_item_reference = item
	_held_item_external = true
	_sync_held_item()
	notice.emit("Usas %s desde el hombro %s." % [item.item_name, _back_shoulder_label(slot)])
	return true

func store_held_on_back(preferred_slot: int = -1) -> bool:
	if not can_store_held_on_back():
		if _back_slot_count() >= 2:
			notice.emit("No hay un hombro libre para guardar ese objeto.")
		else:
			notice.emit("Ese objeto necesita una sujecion valida para la espalda.")
		return false
	var item = get_held_item()
	if item == null:
		return false
	var slot := preferred_slot if (preferred_slot >= 0 and preferred_slot < _stored_back_items.size() and not _is_back_slot_occupied(preferred_slot)) else _find_free_back_slot()
	if slot < 0:
		notice.emit("No hay un hombro libre para guardar ese objeto.")
		return false
	_stored_back_items[slot] = _back_data_from_item(item)
	# A back-mounted item is equipment, not an inventory stack. Remove the
	# exact held unit so a stack of identical tools cannot duplicate or vanish.
	var stored_index: int = inventory.items.find(item)
	if stored_index >= 0:
		inventory.remove_index(stored_index, 1)
	if third_person_hand_item_root != null:
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
	_held_item_reference = null
	held_index = -1
	if hands != null:
		hands.clear_hands()
	_build_stored_back_visual(slot)
	_generic_hand_grip = false
	# Refresh all equipment flags after removing the held resource. This also
	# prevents the fishing-rod state from rebuilding another hand prop.
	_sync_held_item()
	notice.emit("Guardas %s en el hombro %s." % [item.item_name, _back_shoulder_label(slot)])
	return true

func _drop_stored_back_item(slot: int = -1) -> bool:
	if slot < 0:
		# Drop the right shoulder first: it is the last slot filled and keeps
		# the left shoulder stable while the player releases items one by one.
		if _is_back_slot_occupied(BACK_SLOT_RIGHT):
			slot = BACK_SLOT_RIGHT
		elif _is_back_slot_occupied(BACK_SLOT_LEFT):
			slot = BACK_SLOT_LEFT
	if slot < 0 or slot >= _stored_back_items.size():
		return false
	var data = _stored_back_items[slot]
	if not data is Dictionary or str(data.get("name", "")).is_empty():
		return false
	var item_name := str(data.get("name", ""))
	var item_type := str(data.get("type", ""))
	var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
	drop_pos.y = global_position.y
	var drop_color := get_current_clothing_color(item_name)
	var durability := float(data.get("durability", 100.0))
	var max_durability := float(data.get("max_durability", 100.0))
	var is_broken := durability <= 0.0
	set_meta("last_dropped_durability", durability)
	set_meta("last_dropped_max_durability", max_durability)
	set_meta("last_dropped_wetness", float(data.get("wetness", 0.0)))
	set_meta("last_dropped_pelt", str(data.get("pelt_species", "")))
	var stored_visual = _stored_back_visuals[slot]
	if stored_visual != null and is_instance_valid(stored_visual):
		stored_visual.free()
	_stored_back_visuals[slot] = null
	_stored_back_items[slot] = null
	var item_weight := float(data.get("weight", 0.0))
	var item_use_value := float(data.get("use_value", 0.0))
	var item_spoilage := float(data.get("spoilage", 0.0))
	item_dropped.emit(item_name, item_type, item_weight, 1, item_use_value, drop_pos, drop_color, is_broken, item_spoilage)
	_sync_held_item()
	notice.emit("Sueltas %s del hombro %s." % [item_name, _back_shoulder_label(slot)])
	return true

func _stored_rod_upright_rotation(visual: Node3D) -> Quaternion:
	# Imported parent nodes can tilt the shaft even when its AABB is mostly X.
	# Use the longest mesh's actual transformed axis, not the assembly's AABB.
	var longest := 0.0
	var shaft_axis := Vector3.RIGHT
	var stack: Array = [[visual, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var node: Node = entry[0]
		var frame: Transform3D = entry[1]
		if node is MeshInstance3D and node.mesh != null:
			var size: Vector3 = node.get_aabb().size
			for axis_index in range(3):
				var axis := Vector3.ZERO
				axis[axis_index] = size[axis_index]
				var transformed := frame.basis * axis
				if transformed.length() > longest:
					longest = transformed.length()
					shaft_axis = transformed.normalized()
		for child in node.get_children():
			if child is Node3D:
				stack.append([child, frame * child.transform])
	return Quaternion(shaft_axis, Vector3.UP)

func _build_stored_back_visual(slot: int) -> void:
	if slot < 0 or slot >= _stored_back_items.size():
		return
	var old_visual = _stored_back_visuals[slot]
	if old_visual != null and is_instance_valid(old_visual):
		if old_visual.get_parent() != null:
			old_visual.get_parent().remove_child(old_visual)
		old_visual.queue_free()
	_stored_back_visuals[slot] = null
	var data = _stored_back_items[slot]
	if not data is Dictionary or third_person_back_item_root == null:
		return
	var path := ""
	var item_type := str(data.get("type", ""))
	var item_name := str(data.get("name", ""))
	var visual: Node3D = null
	if item_type == "weapon_bow":
		var bpath := REINFORCED_BOW_MODEL if item_name == "Arco reforzado" else WOODEN_BOW_MODEL
		visual = _load_external_node3d(bpath)
		if visual == null:
			visual = MaterialFactory.build_primitive_item_mesh(item_name)
	elif item_name in ["Lanza", "Lanza de hueso", "Palo afilado"]:
		visual = MaterialFactory.build_primitive_item_mesh(item_name)
	else:
		if item_type == "weapon_rifle":
			path = _rifle_model_path_for(item_name)
		elif item_type == "tool_fishing":
			path = ROD_MODEL_PATH
		else:
			path = REAL_WOOD_STICK_MODEL
		visual = _load_external_node3d(path)
	if visual == null:
		return
	var container := Node3D.new()
	container.name = "StoredItemOnBack_%s" % _back_shoulder_label(slot).capitalize()
	_stored_back_visuals[slot] = container
	visual.position = Vector3.ZERO
	visual.scale = Vector3.ONE
	if item_type == "weapon_rifle":
		var r_basis := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, deg_to_rad(-15.0)))
		if str(data.get("name", "")) == M4_NAME:
			r_basis = r_basis * Basis(Vector3.UP, PI)
		visual.basis = r_basis
	elif item_type == "tool_fishing":
		visual.quaternion = _stored_rod_upright_rotation(visual)
	elif item_type == "weapon_bow" or item_name in ["Arco de madera", "Arco reforzado"]:
		visual.rotation_degrees = Vector3(0.0, 90.0, -20.0 if slot == BACK_SLOT_LEFT else 20.0)
	else:
		visual.rotation_degrees = Vector3.ZERO
	container.add_child(visual)
	# Measure after rotation, then scale and center the complete assembly once.
	# Moving individual meshes would separate the reel, handle and shaft.
	var bounds := _hierarchy_local_aabb(container)
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if extent > 0.00001:
		var target_extent := 1.45 if (item_type == "weapon_rifle" and str(data.get("name", "")) == M4_NAME) else (1.35 if (item_type == "weapon_bow" or item_name in ["Arco de madera", "Arco reforzado"]) else 1.65)
		var fit_scale := target_extent / extent
		visual.scale = Vector3.ONE * fit_scale
		visual.position = -bounds.get_center() * fit_scale
	_disable_collision_recursive(visual)
	container.position = Vector3(-0.20 if slot == BACK_SLOT_LEFT else 0.20, 0.03, -0.25)
	third_person_back_item_root.add_child(container)

func _build_rifle_on_back() -> void:
	_clear_rifle_on_back()
	if third_person_back_item_root == null or not is_instance_valid(third_person_back_item_root):
		return
	var rifle_slot := _find_free_back_slot()
	if rifle_slot < 0:
		return
	var skeleton := _spine_skeleton if _spine_skeleton != null else _find_skeleton(third_person_model)
	if skeleton == null or not is_instance_valid(skeleton):
		return
	var back_rifle_name := RIFLE_NAME
	if inventory != null:
		for it in inventory.items:
			if it != null and str(it.item_type) == "weapon_rifle":
				back_rifle_name = str(it.item_name)
				break
	var model := _load_external_node3d(_rifle_model_path_for(back_rifle_name))
	if model == null:
		return
	# Rifle on back: container node
	_rifle_on_back = Node3D.new()
	_rifle_on_back.name = "RifleOnBack"
	model.name = "RifleOnBackMesh"
	# Compute AABB to center the model
	var raw_aabb: AABB = _hierarchy_local_aabb(model)
	if raw_aabb.size.y <= 0.0001:
		model.queue_free()
		_rifle_on_back.queue_free()
		_rifle_on_back = null
		return
	# Scale: target ~1.8m length on the back for the sniper, ~1.10m for the M4 carbine
	var model_length: float = max(raw_aabb.size.x, max(raw_aabb.size.y, raw_aabb.size.z))
	var back_scale: float = (1.45 if back_rifle_name == M4_NAME else 1.8) / model_length
	# Rotate: barrel up (+Y), stock down (-Y). The sniper barrel points -Z;
	# the M4's points +Z, so post-multiply a 180° Y flip in model space first.
	var back_rot := Basis.from_euler(Vector3(deg_to_rad(90.0), 0.0, deg_to_rad(-15.0)))
	if back_rifle_name == M4_NAME:
		back_rot = back_rot * Basis(Vector3.UP, PI)
	model.basis = back_rot.scaled(Vector3.ONE * back_scale)
	model.position = -(model.basis * raw_aabb.get_center())
	model.visible = true
	_rifle_on_back.add_child(model)
	_disable_collision_recursive(model)
	# Automatic rifle display also occupies a free shoulder so it cannot
	# overlap a manually stored item or create a third object on the back.
	_rifle_on_back.position = Vector3(-0.20 if rifle_slot == BACK_SLOT_LEFT else 0.20, 0.05, -0.25)
	_rifle_on_back.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	third_person_back_item_root.add_child(_rifle_on_back)
	# Create Marker3D for strap attachment on the rifle
	var barrel_local := Vector3(-0.10, 0.40, -0.05)
	var stock_local := Vector3(0.12, -0.40, -0.05)
	_strap_barrel_marker = Marker3D.new()
	_strap_barrel_marker.name = "StrapBarrelPoint"
	_strap_barrel_marker.position = barrel_local
	_rifle_on_back.add_child(_strap_barrel_marker)
	_strap_stock_marker = Marker3D.new()
	_strap_stock_marker.name = "StrapStockPoint"
	_strap_stock_marker.position = stock_local
	_rifle_on_back.add_child(_strap_stock_marker)
	_rifle_on_back.force_update_transform()
	RifleStrapScript.attach_swivels(_strap_barrel_marker, _strap_stock_marker, model)
	_strap_barrel_marker.force_update_transform()
	_strap_stock_marker.force_update_transform()
	# Create BoneAttachment3D guide points on torso for natural chest curve
	# Guide upper: Spine2 (upper chest / shoulder area)
	var spine2_idx := skeleton.find_bone("mixamorig_Spine2")
	if spine2_idx < 0:
		spine2_idx = skeleton.find_bone("mixamorig_Spine1")
	if spine2_idx >= 0:
		_strap_guide_upper = BoneAttachment3D.new()
		_strap_guide_upper.name = "StrapGuideUpper"
		_strap_guide_upper.bone_name = skeleton.get_bone_name(spine2_idx)
		_strap_guide_upper.bone_idx = spine2_idx
		# Offset: front of chest, slightly right. Mixamo bone -Z = character front.
		_strap_guide_upper.position = Vector3(0.08, 0.05, -0.22)
		skeleton.add_child(_strap_guide_upper)
		# Add a Marker3D child for the actual offset, since BoneAttachment3D may override position
		_strap_upper_offset = Marker3D.new()
		_strap_upper_offset.name = "StrapGuideUpperOffset"
		_strap_upper_offset.position = Vector3(0.12, 0.08, -0.50)
		_strap_guide_upper.add_child(_strap_upper_offset)
	# Guide lower: Spine1 (lower chest / ribcage)
	var spine1_idx := skeleton.find_bone("mixamorig_Spine1")
	if spine1_idx < 0:
		spine1_idx = skeleton.find_bone("mixamorig_Spine")
	if spine1_idx >= 0:
		_strap_guide_lower = BoneAttachment3D.new()
		_strap_guide_lower.name = "StrapGuideLower"
		_strap_guide_lower.bone_name = skeleton.get_bone_name(spine1_idx)
		_strap_guide_lower.bone_idx = spine1_idx
		# Offset: front of chest, slightly left. Mixamo bone -Z = character front.
		_strap_guide_lower.position = Vector3(-0.06, -0.02, -0.20)
		skeleton.add_child(_strap_guide_lower)
		# Add a Marker3D child for the actual offset
		_strap_lower_offset = Marker3D.new()
		_strap_lower_offset.name = "StrapGuideLowerOffset"
		_strap_lower_offset.position = Vector3(-0.10, -0.05, -0.45)
		_strap_guide_lower.add_child(_strap_lower_offset)
	# Create strap mesh (will be populated on first _update_rifle_strap)
	_build_rifle_strap()
	_strap_initialized = false
	_strap_prev_pts = PackedVector3Array()

func _create_strap_texture() -> ImageTexture:
	var w := 256
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base_col := Color(0.28, 0.31, 0.22, 1.0) # Military Olive Drab / Khaki
	var stitch_col := Color(0.12, 0.14, 0.08, 1.0) # Dark tactical thread
	var weave_dark := Color(0.20, 0.23, 0.16, 1.0)
	var weave_light := Color(0.35, 0.38, 0.28, 1.0)
	var steel_col := Color(0.18, 0.20, 0.22, 1.0) # Gunmetal buckle clip ends
	for y in range(h):
		for x in range(w):
			var col := base_col
			if y < 16 or y > (h - 17):
				col = steel_col
				if x < 10 or x > (w - 11):
					col = steel_col.darkened(0.3)
				elif (y >= 6 and y <= 10) or (y >= (h - 11) and y <= (h - 7)):
					col = steel_col.lightened(0.25)
			else:
				if (x + y) % 8 < 4:
					col = col.lerp(weave_dark, 0.25)
				else:
					col = col.lerp(weave_light, 0.15)
				if (x - y + h) % 6 < 3:
					col = col.lerp(weave_dark, 0.10)
				var edge_dist := minf(x, w - 1 - x)
				if edge_dist < 4:
					col = stitch_col
				elif edge_dist >= 8 and edge_dist <= 12:
					if y % 6 < 3:
						col = stitch_col
				elif edge_dist < 8:
					col = col.lerp(weave_dark, 0.4)
				var n := sin(x * 12.9898 + y * 78.233) * 43758.5453
				n = n - floor(n)
				n = (n - 0.5) * 0.04
				col.r = clampf(col.r + n, 0.0, 1.0)
				col.g = clampf(col.g + n, 0.0, 1.0)
				col.b = clampf(col.b + n, 0.0, 1.0)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	return tex

func _get_chest_target_from_mesh() -> Dictionary:
	# Find a chest/torso mesh and return its AABB center in world space.
	# This gives the actual rendered chest position, avoiding broken Skeleton3D pose data.
	if third_person_model == null or not is_instance_valid(third_person_model):
		return {"chest": Vector3.INF, "front_offset": 0.0}
	var torso_names := ["Tops", "Desnudo_torso", "Body", "Torso"]
	var torso_mi: MeshInstance3D = null
	for mesh_name in torso_names:
		torso_mi = _find_mesh_in_third_person(mesh_name)
		if torso_mi != null and is_instance_valid(torso_mi) and torso_mi.mesh != null:
			break
	if torso_mi == null or not is_instance_valid(torso_mi) or torso_mi.mesh == null:
		return {"chest": Vector3.INF, "front_offset": 0.0}
	var aabb: AABB = torso_mi.get_aabb()
	var center: Vector3 = aabb.get_center()
	# Tops is a skinned child of Skeleton3D; its to_global does not apply the 0.72 model scale.
	# Convert the AABB center (in Tops local) to the character model's local, then to world.
	var local_point: Vector3 = torso_mi.position + torso_mi.basis * center
	var chest_world := third_person_model.global_transform * local_point
	# Distance from the AABB center to the front surface (character faces forward_dir)
	var front_local: Vector3 = aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y * 0.5, aabb.size.z)
	var local_point_front: Vector3 = torso_mi.position + torso_mi.basis * front_local
	var front_world := third_person_model.global_transform * local_point_front
	var forward_dir := (third_person_model.global_basis * Vector3.BACK).normalized()
	var front_offset: float = (front_world - chest_world).dot(forward_dir)
	front_offset = maxf(front_offset, 0.01)
	return {"chest": chest_world, "front_offset": front_offset, "front_world": front_world, "torso_mi": torso_mi}

func _get_bone_global_rest_transform(skel: Skeleton3D, bone_idx: int) -> Transform3D:
	# Accumulate rest transforms from root to bone: root * parent1 * ... * bone
	var chain: Array[int] = []
	var current := bone_idx
	while current >= 0:
		chain.append(current)
		current = skel.get_bone_parent(current)
	chain.reverse()
	var rest := Transform3D.IDENTITY
	for b in chain:
		rest = rest * skel.get_bone_rest(b)
	return rest

func _create_strap_skin() -> Skin:
	# Build a Skin resource from the SlingSkeleton rest pose (inverse bind matrices)
	var skin := Skin.new()
	if _strap_skeleton == null or not is_instance_valid(_strap_skeleton):
		return skin
	var bc := _strap_skeleton.get_bone_count()
	skin.set_bind_count(bc)
	for i in range(bc):
		skin.set_bind_bone(i, i)
		skin.set_bind_name(i, _strap_skeleton.get_bone_name(i))
		var global_rest := _get_bone_global_rest_transform(_strap_skeleton, i)
		skin.set_bind_pose(i, global_rest.affine_inverse())
	return skin

func _build_rifle_strap() -> void:
	if third_person_model == null or not is_instance_valid(third_person_model):
		return
	# Prevent double instantiation
	if _rifle_on_back_strap != null and is_instance_valid(_rifle_on_back_strap):
		return
	# Load the rigged sling asset
	var sling_scene := load("res://assets/models/props/rifle_sling_unfolded.tscn") as PackedScene
	if sling_scene == null:
		push_warning("RIFLE STRAP: could not load rifle_sling_unfolded.tscn")
		return
	var sling_root := sling_scene.instantiate() as Node3D
	if sling_root == null:
		push_warning("RIFLE STRAP: sling scene root is not Node3D")
		return
	sling_root.name = "RifleSlingRoot"
	sling_root.visible = false # The fitted procedural band owns the visible sling.
	# Initial identity transforms
	sling_root.position = Vector3.ZERO
	sling_root.rotation = Vector3.ZERO
	sling_root.scale = Vector3.ONE
	third_person_model.add_child(sling_root)
	_rifle_on_back_strap = sling_root
	# Find the skeleton and mesh inside
	_strap_skeleton = null
	var strap_mi: MeshInstance3D = null
	for child in sling_root.get_children():
		if child is Skeleton3D:
			_strap_skeleton = child as Skeleton3D
		elif child is MeshInstance3D:
			strap_mi = child as MeshInstance3D
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if _strap_skeleton == null:
		push_warning("RIFLE STRAP: no Skeleton3D found in sling scene")
	elif strap_mi != null:
		# PASO 1: assign skeleton and skin for GPU skinning
		strap_mi.skeleton = NodePath("../SlingSkeleton")
		strap_mi.skin = _create_strap_skin()

		var strap_mat := StandardMaterial3D.new()
		strap_mat.resource_name = "MilitaryRifleSlingMaterial"
		strap_mat.albedo_texture = _create_strap_texture()
		strap_mat.roughness = 0.65
		strap_mat.metallic = 0.15
		strap_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		strap_mi.material_override = strap_mat
		strap_mi.custom_aabb = AABB(Vector3(-10.0, -10.0, -10.0), Vector3(20.0, 20.0, 20.0))

	# Do NOT create Skin resource / CPU skinning cache — want pure rest pose
	_strap_mesh_cached = false
	# PASO 2: Align SlingMesh AABB center with real chest bone position
	if strap_mi != null and _strap_skeleton != null:
		var char_skel: Skeleton3D = _spine_skeleton if _spine_skeleton != null and is_instance_valid(_spine_skeleton) else _find_skeleton(third_person_model)
		if char_skel != null and is_instance_valid(char_skel):
			var chest_bone_idx := -1
			for bn in ["mixamorig_Spine2", "mixamorig_Spine1", "mixamorig_Spine", "Spine2", "Spine1", "Spine"]:
				chest_bone_idx = char_skel.find_bone(bn)
				if chest_bone_idx >= 0:
					break
			if chest_bone_idx >= 0:
				var chest_data := _get_chest_target_from_mesh()
				var chest_world: Vector3 = chest_data["chest"]
				var front_world: Vector3 = chest_data.get("front_world", Vector3.INF)
				var torso_mi: MeshInstance3D = chest_data.get("torso_mi", null)
				if chest_world == Vector3.INF or front_world == Vector3.INF:
					push_warning("[STRAP] Could not find torso mesh for chest reference")
				else:
					# === FASE 1: Rigid placement using VISUAL reference, NOT AABB ===
					# Known visual chest surface: (0.011, 1.798, -0.0342)
					# Do NOT use Tops AABB for depth — it's unreliable for skinned mesh
					var forward_dir := (third_person_model.global_basis * Vector3.BACK).normalized()
					var chest_surface_world := Vector3(0.011, 1.798, -0.0342) + forward_dir * 0.025
					# Align SlingMesh AABB CENTER to chest_surface_world
					var aabb: AABB = strap_mi.get_aabb()
					var sling_center_local: Vector3 = aabb.get_center()
					var sling_center_world: Vector3 = strap_mi.to_global(sling_center_local)
					var current_global := sling_root.global_position
					var correction := chest_surface_world - sling_center_world
					var new_global := current_global + correction
					sling_root.global_position = new_global
					sling_root.force_update_transform()
					# Store for debug capture
					_strap_test_positions = [new_global]
					# === FASE 2: ===
					_strap_skeleton.reset_bone_poses()
					_strap_skeleton.force_update_all_bone_transforms()
					for b in range(_strap_skeleton.get_bone_count()):
						pass
			else:
				push_warning("[STRAP] Could not find chest bone for alignment")
		else:
			push_warning("[STRAP] Could not find character skeleton for alignment")

func _setup_strap_reference_visuals(strap_root: Node3D, strap_mi: MeshInstance3D) -> void:
	if strap_root == null or not is_instance_valid(strap_root) or strap_mi == null or not is_instance_valid(strap_mi):
		return
	var aabb: AABB = strap_mi.get_aabb()
	var ref_pts: Array[Vector3] = [
		Vector3.ZERO,                                              # red: RifleSlingRoot origin
		strap_mi.position,                                         # green: SlingMesh origin
		aabb.get_center(),                                         # blue: AABB center
		aabb.position + Vector3(aabb.size.x * 0.5, aabb.size.y * 0.5, aabb.size.z)  # white: AABB front face
	]
	var ref_colors: Array[Color] = [
		Color(1, 0, 0, 1),  # rojo
		Color(0, 1, 0, 1),  # verde
		Color(0, 0, 1, 1),  # azul
		Color(1, 1, 1, 1)   # blanco
	]
	for i in range(ref_pts.size()):
		var sname := "StrapRef%d" % i
		var sphere := strap_root.get_node_or_null(sname) as MeshInstance3D
		if sphere == null:
			sphere = MeshInstance3D.new()
			sphere.name = sname
			var smesh := SphereMesh.new()
			smesh.radius = 0.015
			smesh.height = 0.030
			sphere.mesh = smesh
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ref_colors[i]
			mat.emission_enabled = true
			mat.emission = ref_colors[i]
			mat.emission_energy_multiplier = 3.0
			mat.no_depth_test = true
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			sphere.material_override = mat
			sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			strap_root.add_child(sphere)
			_strap_reference_spheres.append(sphere)
		sphere.position = ref_pts[i]
		sphere.visible = false
	var boxname := "StrapAABBBox"
	var box_mi := strap_root.get_node_or_null(boxname) as MeshInstance3D
	if box_mi == null:
		box_mi = MeshInstance3D.new()
		box_mi.name = boxname
		var bmesh := BoxMesh.new()
		bmesh.size = aabb.size
		box_mi.mesh = bmesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 0, 0, 0.15)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		box_mi.material_override = mat
		box_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		strap_root.add_child(box_mi)
		_strap_aabb_box = box_mi
	box_mi.position = aabb.get_center()
	box_mi.visible = false

var _strap_orig_verts: PackedVector3Array = PackedVector3Array()
var _strap_orig_bones: PackedInt32Array = PackedInt32Array()
var _strap_orig_weights: PackedFloat32Array = PackedFloat32Array()
var _strap_orig_normals: PackedVector3Array = PackedVector3Array()
var _strap_orig_tangents: PackedFloat32Array = PackedFloat32Array()
var _strap_orig_indices: PackedInt32Array = PackedInt32Array()
var _strap_orig_uvs: PackedVector2Array = PackedVector2Array()
var _strap_bind_poses: Array[Transform3D] = []
var _strap_mesh_cached: bool = false

func _apply_cpu_skinning() -> void:
	if not _strap_mesh_cached:
		return
	if _strap_skeleton == null or not is_instance_valid(_strap_skeleton):
		return
	if _rifle_on_back_strap == null or not is_instance_valid(_rifle_on_back_strap):
		return
	var strap_mi: MeshInstance3D = null
	for child in _rifle_on_back_strap.get_children():
		if child is MeshInstance3D:
			strap_mi = child as MeshInstance3D
			break
	if strap_mi == null:
		return
	var bc := _strap_skeleton.get_bone_count()
	# Compute skinning matrices: current_global * bind_inverse
	var skin_mats: Array[Transform3D] = []
	skin_mats.resize(bc)
	for b in range(bc):
		var current_global := _strap_skeleton.get_bone_global_pose(b)
		skin_mats[b] = current_global * _strap_bind_poses[b].affine_inverse()
	# Deform vertices
	var n_verts := _strap_orig_verts.size()
	var deformed := PackedVector3Array()
	deformed.resize(n_verts)
	var deformed_normals := PackedVector3Array()
	deformed_normals.resize(n_verts)
	for v in range(n_verts):
		var orig_v := _strap_orig_verts[v]
		var orig_n := _strap_orig_normals[v]
		var def_v := Vector3.ZERO
		var def_n := Vector3.ZERO
		var bi0 := _strap_orig_bones[v * 4]
		var bi1 := _strap_orig_bones[v * 4 + 1]
		var bi2 := _strap_orig_bones[v * 4 + 2]
		var bi3 := _strap_orig_bones[v * 4 + 3]
		var w0 := _strap_orig_weights[v * 4]
		var w1 := _strap_orig_weights[v * 4 + 1]
		var w2 := _strap_orig_weights[v * 4 + 2]
		var w3 := _strap_orig_weights[v * 4 + 3]
		if w0 > 0.0:
			def_v += w0 * (skin_mats[bi0] * orig_v)
			def_n += w0 * (skin_mats[bi0].basis * orig_n)
		if w1 > 0.0:
			def_v += w1 * (skin_mats[bi1] * orig_v)
			def_n += w1 * (skin_mats[bi1].basis * orig_n)
		if w2 > 0.0:
			def_v += w2 * (skin_mats[bi2] * orig_v)
			def_n += w2 * (skin_mats[bi2].basis * orig_n)
		if w3 > 0.0:
			def_v += w3 * (skin_mats[bi3] * orig_v)
			def_n += w3 * (skin_mats[bi3].basis * orig_n)
		deformed[v] = def_v
		deformed_normals[v] = def_n.normalized()
	# Build new mesh
	var new_mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = deformed
	arr[Mesh.ARRAY_NORMAL] = deformed_normals
	arr[Mesh.ARRAY_TANGENT] = _strap_orig_tangents
	arr[Mesh.ARRAY_TEX_UV] = _strap_orig_uvs
	arr[Mesh.ARRAY_INDEX] = _strap_orig_indices
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	strap_mi.mesh = new_mesh

var _strap_debug_spheres: Array[MeshInstance3D] = []
var _strap_reference_spheres: Array[MeshInstance3D] = []
var _strap_aabb_box: MeshInstance3D = null
var _strap_test_positions: Array[Vector3] = []
var _strap_diagnostic_mode: bool = false

func _update_strap_debug_spheres(pts: Array[Vector3], radius: float = 0.015, custom_colors = []) -> void:
	var default_colors: Array[Color] = [
		Color(1, 0, 0, 1),    # P0: rojo
		Color(0, 1, 0, 1),    # P1: verde
		Color(0, 0.5, 1, 1),  # P2: azul claro
		Color(1, 1, 0, 1),    # P3: amarillo
		Color(1, 0.5, 0, 1),  # P4: naranja
		Color(0.5, 0, 1, 1),  # P5: morado
		Color(0, 1, 1, 1),    # P6: cian
		Color(1, 0, 1, 1),    # P7: magenta
		Color(0.5, 1, 0.5, 1),# P8: verde claro
		Color(1, 0.5, 0.5, 1),# P9: rosa
		Color(1, 1, 1, 1),    # P10: blanco
		Color(0.7, 0.7, 1, 1),# P11: azul claro claro
	]
	var colors: Array = default_colors if custom_colors.is_empty() else custom_colors
	var strap_root: Node3D = _rifle_on_back_strap
	# Crear esferas si no existen
	while _strap_debug_spheres.size() < pts.size():
		var idx: int = _strap_debug_spheres.size()
		var sphere := MeshInstance3D.new()
		sphere.name = "StrapDebugP%d" % idx
		var smesh := SphereMesh.new()
		smesh.radius = radius
		smesh.height = radius * 2.0
		sphere.mesh = smesh
		var mat := StandardMaterial3D.new()
		var col: Color = colors[idx % colors.size()]
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 2.0
		mat.no_depth_test = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere.material_override = mat
		strap_root.add_child(sphere)
		_strap_debug_spheres.append(sphere)
	# Actualizar posiciones
	for i in range(pts.size()):
		if i < _strap_debug_spheres.size() and is_instance_valid(_strap_debug_spheres[i]):
			_strap_debug_spheres[i].position = pts[i]

func _update_rifle_strap(delta: float) -> void:
	if _rifle_strap_system == null:
		_rifle_strap_system = RifleStrapScript.new()
		_rifle_strap_system.player = self
	if _rifle_strap_system != null:
		_rifle_strap_system._update_rifle_strap(delta)

func _clear_rifle_on_back() -> void:
	if _rifle_on_back != null and is_instance_valid(_rifle_on_back):
		_rifle_on_back.queue_free()
	_rifle_on_back = null
	if _rifle_on_back_strap != null and is_instance_valid(_rifle_on_back_strap):
		var p = _rifle_on_back_strap.get_parent()
		if p != null:
			p.remove_child(_rifle_on_back_strap)
		_rifle_on_back_strap.free()
	_rifle_on_back_strap = null
	_strap_skeleton = null
	if _strap_guide_upper != null and is_instance_valid(_strap_guide_upper):
		_strap_guide_upper.free()
	_strap_guide_upper = null
	if _strap_guide_lower != null and is_instance_valid(_strap_guide_lower):
		_strap_guide_lower.free()
	_strap_guide_lower = null
	_strap_upper_offset = null
	_strap_lower_offset = null
	_strap_barrel_marker = null
	_strap_stock_marker = null
	_strap_initialized = false
	for s in _strap_debug_spheres:
		if s != null and is_instance_valid(s):
			s.queue_free()
	_strap_debug_spheres.clear()
	_strap_prev_pts = PackedVector3Array()
	if third_person_model != null and is_instance_valid(third_person_model):
		for child in third_person_model.get_children():
			if child is Node3D and (child.name == "RifleSlingRoot" or child.name.begins_with("RifleSling") or child.name == "ProceduralStrapMesh"):
				child.free()

func _build_third_person_rifle(item_name := "") -> void:
	if third_person_hand_item_root == null or not is_instance_valid(third_person_hand_item_root):
		return
	if item_name.is_empty():
		item_name = _held_rifle_name()
	_clear_rifle_attachment()
	var is_m4 := item_name == M4_NAME
	_mounted_rifle_is_m4 = is_m4
	if is_m4:
		# Medidas del M4 en el espacio del modelo volteado 180° (bocacha -Z,
		# culata +Z): guardamanos Front_Barrel en z≈-0.024, empuñadura Grip
		# en z≈0.052, linea del rail superior en y≈0.054.
		_rg_eye = Vector3(0.0025, 0.068, 0.032)
		_rg_right_knuckle = Vector3(0.0038, 0.0285, 0.0415)
		_rg_left_knuckle = Vector3(0.0068, 0.0365, -0.022)
		_rg_left_thumb = Vector3(-0.0065, 0.045, -0.018)
		_rg_right_grip = Vector3(0.005, 0.020, 0.048)
		_rg_left_grip = Vector3(-0.007, 0.048, -0.024)
	else:
		_rg_eye = RIFLE_AIM_EYE
		_rg_right_knuckle = RIFLE_AIM_RIGHT_KNUCKLE
		_rg_left_knuckle = RIFLE_AIM_LEFT_KNUCKLE
		_rg_left_thumb = Vector3(-0.55, 0.65, -1.7)
		_rg_right_grip = Vector3(0.5000, -0.5000, 1.2000)
		_rg_left_grip = Vector3(-1.5, -0.5, -3.8)
	var model := _load_external_node3d(_rifle_model_path_for(item_name))
	if model == null:
		return
	var skeleton := _spine_skeleton if _spine_skeleton != null else _find_skeleton(third_person_model)
	if skeleton == null or not is_instance_valid(skeleton):
		model.queue_free()
		return
	var resolved_bone := _resolve_bone_name_safe(right_hand_bone_name, skeleton)
	if resolved_bone.is_empty():
		model.queue_free()
		return
	# 1. BoneAttachment3D on right hand bone — rifle follows right hand animation
	_rifle_bone_attachment = BoneAttachment3D.new()
	_rifle_bone_attachment.name = "BoneAttachment3D_RightHand"
	_rifle_bone_attachment.bone_name = resolved_bone
	skeleton.add_child(_rifle_bone_attachment)
	# 2. WeaponOffset — child of BoneAttachment3D; follows RightHand animation
	_rifle_weapon_offset = Node3D.new()
	_rifle_weapon_offset.name = "WeaponOffset"
	_rifle_bone_attachment.add_child(_rifle_weapon_offset)
	# 3. RifleRoot — holds model and reference markers
	# CORRECCIÓN FASE 1: hereda de WeaponOffset, no es top_level
	_rifle_root = Node3D.new()
	_rifle_root.name = "RifleRoot"
	_rifle_root.top_level = false
	_rifle_weapon_offset.add_child(_rifle_root)
	_rifle_root.transform = Transform3D.IDENTITY
	# Rifle model
	model.name = "RifleMesh"
	model.position = Vector3.ZERO
	# El M4 lleva el canon al +Z; se voltea para coincidir con la convencion
	# -Z que asumen todos los marcadores (culata = max Z, boca = min Z).
	model.rotation_degrees = Vector3(0.0, 180.0, 0.0) if is_m4 else Vector3.ZERO
	var skel_scale := skeleton.global_transform.basis.get_scale().x
	var effective_scale := _rifle_weapon_scale() * skel_scale
	# Model at scale 1.0; all scale goes on WeaponOffset (like previous working version)
	model.scale = Vector3.ONE
	model.visible = true
	_rifle_root.add_child(model)
	_rifle_model = model
	_disable_collision_recursive(model)
	# Make all meshes visible and compute AABB in RifleRoot local space
	# Traverse hierarchy accumulating transforms relative to RifleRoot
	var stock_z: float = 0.0
	var muzzle_z: float = 0.0
	var stock_x: float = 0.0
	var stock_y: float = 0.0
	var muzzle_x: float = 0.0
	var muzzle_y: float = 0.0
	var combined_aabb := AABB()
	var has_aabb := false
	var mesh_count := 0
	var aabb_state := {"aabb": AABB(), "has_aabb": false, "mesh_count": 0}
	# model.transform entra en el AABB: el M4 va volteado 180° y sus
	# marcadores de culata/boca deben salir ya en el espacio volteado.
	_traverse_mesh_aabb(model, model.transform, aabb_state)
	has_aabb = aabb_state["has_aabb"]
	combined_aabb = aabb_state["aabb"]
	mesh_count = aabb_state["mesh_count"]
	if has_aabb:
		stock_z = combined_aabb.end.z
		muzzle_z = combined_aabb.position.z
		stock_x = combined_aabb.get_center().x
		stock_y = combined_aabb.get_center().y
		muzzle_x = combined_aabb.get_center().x
		muzzle_y = combined_aabb.get_center().y
	# 4. Reference markers inside RifleRoot (positions in model-local space, scaled by weapon_scale)
	# RightGrip: centro de la empuñadura/palma, sobre el gatillo, ligeramente a la derecha del eje del rifle
	_rifle_right_grip = Marker3D.new()
	_rifle_right_grip.name = "RightGrip"
	_rifle_right_grip.position = _rg_right_grip
	_rifle_right_grip.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_rifle_root.add_child(_rifle_right_grip)
	# LeftHandGripTarget: guardamanos, delante del grip, lado izquierdo del rifle
	_rifle_left_hand_grip = Marker3D.new()
	_rifle_left_hand_grip.name = "LeftHandGripTarget"
	_rifle_left_hand_grip.position = _rg_left_grip
	_rifle_root.add_child(_rifle_left_hand_grip)
	# Left elbow pole: hijo del personaje, no del rifle
	_rifle_left_elbow_pole = Marker3D.new()
	_rifle_left_elbow_pole.name = "LeftElbowPole"
	self.add_child(_rifle_left_elbow_pole)
	_setup_rifle_left_arm_ik(skeleton, _rifle_left_hand_grip)
	# StockReference: extremo trasero fisico de la culata (max Z del AABB — model barrel points -Z)
	_rifle_stock_ref = Marker3D.new()
	_rifle_stock_ref.name = "StockReference"
	_rifle_stock_ref.position = Vector3(stock_x, stock_y, stock_z)
	_rifle_root.add_child(_rifle_stock_ref)
	# Muzzle: extremo delantero fisico del cañon (min Z del AABB — model barrel points -Z)
	_rifle_muzzle = Marker3D.new()
	_rifle_muzzle.name = "MuzzleRef"
	_rifle_muzzle.position = Vector3(muzzle_x, muzzle_y, muzzle_z)
	_rifle_root.add_child(_rifle_muzzle)

	# Strap attachment markers on held rifle
	_strap_barrel_marker = Marker3D.new()
	_strap_barrel_marker.name = "StrapBarrelPoint"
	_strap_barrel_marker.position = Vector3(muzzle_x * 0.75 + stock_x * 0.25, muzzle_y + 0.05, muzzle_z * 0.75 + stock_z * 0.25)
	_rifle_root.add_child(_strap_barrel_marker)

	_strap_stock_marker = Marker3D.new()
	_strap_stock_marker.name = "StrapStockPoint"
	_strap_stock_marker.position = Vector3(stock_x, stock_y + 0.05, stock_z * 0.90 + muzzle_z * 0.10)
	_rifle_root.add_child(_strap_stock_marker)
	RifleStrapScript.attach_swivels(_strap_barrel_marker, _strap_stock_marker, model)

	_build_rifle_strap()

	# Two-point alignment targets. No IK targets, poles, or arm solvers are created.
	_rifle_stock_target = Marker3D.new()
	_rifle_stock_target.name = "StockTarget"
	_rifle_stock_target.top_level = true
	skeleton.add_child(_rifle_stock_target)
	_rifle_muzzle_target = Marker3D.new()
	_rifle_muzzle_target.name = "MuzzleTarget"
	_rifle_muzzle_target.top_level = true
	skeleton.add_child(_rifle_muzzle_target)
	# Auto-solver targets: ShoulderTarget and AimTarget
	_rifle_shoulder_target = Marker3D.new()
	_rifle_shoulder_target.name = "ShoulderTarget"
	_rifle_shoulder_target.top_level = true
	skeleton.add_child(_rifle_shoulder_target)
	_rifle_aim_target = Marker3D.new()
	_rifle_aim_target.name = "AimTarget"
	_rifle_aim_target.top_level = true
	skeleton.add_child(_rifle_aim_target)
	# WeaponOffset remains only as the attachment frame; RifleRoot is aligned below.
	# This way rifle rotates with character but ignores bone animation rotation
	_rifle_bone_attachment.force_update_transform()
	# FASE 1: attach rifle to RightHand while keeping current world placement
	var skel_scale_wo := skeleton.global_transform.basis.get_scale().x
	var rh_bone_idx_init := skeleton.find_bone(_resolve_bone_name_safe(right_hand_bone_name, skeleton))
	var rh_world_init := (skeleton.global_transform * skeleton.get_bone_global_pose(rh_bone_idx_init)).origin
	var rot_basis_init := global_basis * Basis.from_euler(weapon_offset_rot_deg * deg_to_rad(1.0))
	var weapon_basis_init := rot_basis_init.scaled(Vector3.ONE * _rifle_weapon_scale() * skel_scale_wo)
	_rifle_weapon_offset.global_basis = weapon_basis_init
	# Offset so RightGrip sits on the right hand bone
	var init_offset := Vector3.ZERO if is_m4 else weapon_offset_pos
	_rifle_weapon_offset.global_position = rh_world_init + _rifle_weapon_offset.global_basis * (init_offset - _rifle_right_grip.position)
	_rifle_root.transform = Transform3D.IDENTITY
	# Force transforms
	_rifle_bone_attachment.force_update_transform()
	_rifle_weapon_offset.force_update_transform()
	_rifle_root.force_update_transform()
	# FASE 1: left IK starts inactive; will be enabled per-frame with influence 0.70
	if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik):
		_rifle_left_arm_ik.active = true
		_rifle_left_arm_ik.influence = 0.0

#endregion


#region RIFLE: IK Y POSICIONAMIENTO (PlayerRifle)
func _update_rifle_visuals(delta: float) -> void:
	# Both local players and puppets need the solve that also registers the
	# post-animation skeleton callback; the initial attachment is only a seed.
	if is_instance_valid(_rifle_weapon_offset) and is_instance_valid(_rifle_bone_attachment):
		var skel := _spine_skeleton if is_instance_valid(_spine_skeleton) else _find_skeleton(third_person_model)
		if skel != null:
			_update_rifle_ik(skel, delta)
	# Keep the procedural sling at 30 Hz for either carry mode.
	if is_instance_valid(_rifle_on_back_strap):
		_rifle_strap_update_accum += delta
		if _rifle_strap_system == null or _rifle_strap_update_accum >= (1.0 / 30.0):
			var strap_delta := _rifle_strap_update_accum
			_rifle_strap_update_accum = 0.0
			_update_rifle_strap(strap_delta)
	else:
		_rifle_strap_update_accum = 0.0

func _update_rifle_ik(skel: Skeleton3D, delta: float) -> void:
	# Rifle placed by the animation hands and right shoulder; IK disabled.
	if _rifle_root == null or not is_instance_valid(_rifle_root):
		return
	if _rifle_bone_attachment == null or not is_instance_valid(_rifle_bone_attachment):
		return
	if _rifle_weapon_offset == null or not is_instance_valid(_rifle_weapon_offset):
		return
	if _rifle_right_grip == null or not is_instance_valid(_rifle_right_grip):
		return
	if _rifle_left_hand_grip == null or not is_instance_valid(_rifle_left_hand_grip):
		return
	if _rifle_stock_ref == null or not is_instance_valid(_rifle_stock_ref):
		return

	var rh_bone_name := _resolve_bone_name_cached("rh", right_hand_bone_name, skel)
	var lh_bone_name := _resolve_bone_name_cached("lh", "mixamorig:LeftHand", skel)
	var shoulder_bone_name := _resolve_bone_name_cached("sh", "mixamorig:RightShoulder", skel)
	if shoulder_bone_name.is_empty():
		shoulder_bone_name = _resolve_bone_name_cached("sh_alt", "mixamorig:RightArm", skel)
	if rh_bone_name.is_empty() or lh_bone_name.is_empty() or shoulder_bone_name.is_empty():
		return
	var rh_idx := _find_bone_cached("rh_idx", rh_bone_name, skel)
	var lh_idx := _find_bone_cached("lh_idx", lh_bone_name, skel)
	var sh_idx := _find_bone_cached("sh_idx", shoulder_bone_name, skel)
	if rh_idx < 0 or lh_idx < 0 or sh_idx < 0:
		return
	if not _m4_saved_left_arm_poses.is_empty():
		for entry in _m4_saved_left_arm_poses:
			skel.set_bone_pose(entry[0], entry[1])
		_m4_saved_left_arm_poses.clear()

	var skel_scale_wo := skel.global_transform.basis.get_scale().x
	var s := _rifle_weapon_scale() * skel_scale_wo
	var rh_pos := (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var lh_pos := (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	var shoulder_pos := (skel.global_transform * skel.get_bone_global_pose(sh_idx)).origin

	# Raw shoulder aim: right shoulder muscle pad
	var char_basis := global_basis.orthonormalized()
	var raw_shoulder := shoulder_pos + char_basis.x * 0.06 + char_basis.z * 0.02 - char_basis.y * 0.08

	# Standing/crouched aim: the rifle is placed directly on the body — scope
	# line through the eye, butt into the right-shoulder pocket, barrel along
	# the aim direction — and both arms are IK'd onto it. WeaponOffset goes
	# top-level so the IK'd hands cannot drag it back out of place.
	var want_direct_aim := (_is_aiming or _is_firing) and not is_sitting and not is_prone
	if not want_direct_aim and (_rifle_aim_pose_active or _rifle_weapon_offset.top_level):
		_restore_grip_origins()
	_rifle_aim_pose_active = false
	if want_direct_aim and _try_place_rifle_aiming(skel, s):
		_rifle_aim_pose_active = true
		_register_rifle_ik(skel, lh_idx)
		return
	# This is a world-space solve. A later BoneAttachment update must not
	# apply the hand rotation a second time after the rifle was aligned.
	if not _rifle_weapon_offset.top_level:
		_rifle_weapon_offset.set_as_top_level(true)

	var rg_local := _rifle_right_grip.position
	var lg_local := _rifle_left_hand_grip.position
	var stock_local := _rifle_stock_ref.position

	if _mounted_rifle_is_m4:
		# En reposo, orientamos el eje del M4 para que desde la mano derecha
		# hacia atras (-v_world_dir) la culata suba por delante del chaleco
		# tactico y por encima del antebrazo derecho, sin forzar los hombros.
		var char_fwd := -char_basis.z
		lh_pos -= char_fwd * 0.10 + char_basis.y * 0.05
		raw_shoulder += char_fwd * 0.25 - char_basis.x * 0.05 + char_basis.y * 0.08

	var v_world_dir := (lh_pos - rh_pos).normalized()
	var v_local_dir := Vector3(0.0, 0.0, -1.0) if _mounted_rifle_is_m4 else (lg_local - rg_local).normalized()
	if v_world_dir.length_squared() < 0.0001 or v_local_dir.length_squared() < 0.0001:
		return

	# Move the left hand marker along the handguard so its world distance matches the animated left hand
	var target_len := (lh_pos - rh_pos).length() / s
	if not _mounted_rifle_is_m4:
		_rifle_left_hand_grip.position = rg_local + v_local_dir * target_len
	lg_local = _rifle_left_hand_grip.position

	# Rotation that aligns the handguard line with the animated hand direction
	var axis := v_local_dir.cross(v_world_dir)
	var angle := v_local_dir.angle_to(v_world_dir)
	if axis.length_squared() < 0.0001:
		axis = Vector3(1.0, 0.0, 0.0) if abs(v_local_dir.y) < 0.9 else Vector3(0.0, 1.0, 0.0)
		if v_local_dir.dot(v_world_dir) < 0.0:
			angle = PI
		else:
			angle = 0.0
	var q0 := Quaternion(axis.normalized(), angle)
	var r0 := Basis(q0)

	# Place the stock end on the shoulder: the stock is a rigid body, so the butt pad
	# lies on a circle around the handguard axis. Constrain the raw shoulder target to that circle.
	var stock_vec := stock_local - rg_local
	var stock_dist_world := s * stock_vec.length()
	var stock_parallel_len := s * stock_vec.dot(v_local_dir)
	var raw_shoulder_vec := raw_shoulder - rh_pos
	var raw_shoulder_proj := raw_shoulder_vec - v_world_dir * raw_shoulder_vec.dot(v_world_dir)
	var perp_radius_sq := stock_dist_world * stock_dist_world - stock_parallel_len * stock_parallel_len
	if perp_radius_sq < 0.0001:
		perp_radius_sq = 0.0001
	var perp_radius := sqrt(perp_radius_sq)
	var perp_dir := raw_shoulder_proj.normalized()
	if perp_dir.length_squared() < 0.0001:
		perp_dir = (Vector3(1.0, 0.0, 1.0).slide(v_world_dir)).normalized()
	shoulder_pos = rh_pos + v_world_dir * stock_parallel_len + perp_dir * perp_radius

	# Roll around the handguard line to bring the stock to the right shoulder
	var stock_perp := stock_vec.slide(v_local_dir).normalized()
	if stock_perp.length_squared() < 0.0001:
		stock_perp = Vector3(0.0, 1.0, 0.0).slide(v_local_dir).normalized()
	var shoulder_vec := shoulder_pos - rh_pos
	var shoulder_perp := shoulder_vec.slide(v_world_dir).normalized()
	if shoulder_perp.length_squared() < 0.0001:
		shoulder_perp = Vector3(0.0, 1.0, 0.0).slide(v_world_dir).normalized()
	var stock_aligned_perp := r0 * stock_perp
	var roll := stock_aligned_perp.signed_angle_to(shoulder_perp, v_world_dir)
	var roll_q := Quaternion(v_world_dir, roll)
	var r := Basis(roll_q) * r0
	if _mounted_rifle_is_m4 and not _is_aiming and not _is_firing:
		# Mantener el plano lateral del M4 vertical/frontal para que la pala de
		# la culata (Butt_Stock) no gire hacia dentro del pecho ni del brazo.
		var barrel_axis := (r * Vector3(0.0, 0.0, -1.0)).normalized()
		var desired_up := (char_basis.y - char_basis.z * 0.25).slide(barrel_axis).normalized()
		var current_up := (r * Vector3.UP).slide(barrel_axis).normalized()
		if desired_up.length_squared() > 0.001 and current_up.length_squared() > 0.001:
			var fix_roll := current_up.signed_angle_to(desired_up, barrel_axis)
			r = Basis(Quaternion(barrel_axis, fix_roll)) * r

	# Build the world transform for WeaponOffset
	var weapon_basis := r.scaled(Vector3.ONE * s)
	_rifle_root.position = Vector3.ZERO
	if _is_aiming and not is_puppet and is_instance_valid(camera) and is_instance_valid(_rifle_muzzle):
		var barrel_local := (_rifle_muzzle.position - stock_local).normalized()
		var barrel_world := (weapon_basis * barrel_local).normalized()
		var sight_direction := -camera.global_basis.z.normalized()
		weapon_basis = Basis(Quaternion(barrel_world, sight_direction)) * weapon_basis
	_rifle_weapon_offset.global_basis = weapon_basis
	_rifle_weapon_offset.global_position = rh_pos - weapon_basis * rg_local
	_rifle_weapon_offset.force_update_transform()

	# Shift the whole rifle along the real barrel line (from muzzle toward stock)
	# without changing rotation or scale. Direction is taken from the actual
	# muzzle and stock markers.
	if not _is_aiming and not is_sitting and not is_prone and _rifle_muzzle != null and is_instance_valid(_rifle_muzzle) and _rifle_stock_ref != null and is_instance_valid(_rifle_stock_ref):
		_rifle_root.force_update_transform()
		var barrel_dir := (_rifle_muzzle.global_position - _rifle_stock_ref.global_position).normalized()
		if _mounted_rifle_is_m4:
			var up_dir := weapon_basis.y.normalized()
			var char_fwd := -char_basis.z
			_rifle_weapon_offset.global_position += barrel_dir * 0.095 - up_dir * 0.015 + char_fwd * 0.045
			_rifle_weapon_offset.force_update_transform()
		else:
			_rifle_root.global_position += barrel_dir * 0.40

	# While aiming the right-hand grip pivot above is authoritative. A later
	# root translation would visibly detach the rifle from the palm.

	if _mounted_rifle_is_m4 and not _is_aiming and not _is_firing:
		_seat_m4_idle_grip(skel, rh_idx, _rifle_weapon_offset)

	# Force update so the grip marker's global transform is current
	_rifle_root.force_update_transform()
	_rifle_left_hand_grip.force_update_transform()

	# Enable left arm IK when aiming so the left hand reaches the handguard
	if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik):
		if _is_aiming:
			_rifle_left_arm_ik.active = true
			_rifle_left_arm_ik.influence = 1.0
		else:
			_rifle_left_arm_ik.active = false
			_rifle_left_arm_ik.influence = 0.0

	_register_rifle_ik(skel, lh_idx)

func _register_rifle_ik(skel: Skeleton3D, lh_idx: int) -> void:
	# Store references for the skeleton_updated callback
	_ik_skel = skel
	_ik_lh_idx = lh_idx
	var ua_bone_name := _resolve_bone_name_cached("ua", "mixamorig:LeftArm", skel)
	var fa_bone_name := _resolve_bone_name_cached("fa", "mixamorig:LeftForeArm", skel)
	if not ua_bone_name.is_empty():
		_ik_upper_arm_idx = _find_bone_cached("ua_idx", ua_bone_name, skel)
	if not fa_bone_name.is_empty():
		_ik_forearm_idx = _find_bone_cached("fa_idx", fa_bone_name, skel)
	var rua_bone_name := _resolve_bone_name_cached("rua", "mixamorig:RightArm", skel)
	var rfa_bone_name := _resolve_bone_name_cached("rfa", "mixamorig:RightForeArm", skel)
	var rh_bone_name := _resolve_bone_name_cached("rh", right_hand_bone_name, skel)
	_ik_right_upper_arm_idx = -1 if rua_bone_name.is_empty() else _find_bone_cached("rua_idx", rua_bone_name, skel)
	_ik_right_forearm_idx = -1 if rfa_bone_name.is_empty() else _find_bone_cached("rfa_idx", rfa_bone_name, skel)
	_ik_rh_idx = -1 if rh_bone_name.is_empty() else _find_bone_cached("rh_idx", rh_bone_name, skel)
	if not _ik_skeleton_connected and skel != null:
		skel.skeleton_updated.connect(_on_skeleton_updated)
		_ik_skeleton_connected = true

func _try_place_rifle_aiming(skel: Skeleton3D, s: float) -> bool:
	# The camera travels from third person to ADS. Its position must never
	# drag the physical rifle away from the character during that transition.
	var sight_dir := -global_basis.z.normalized()
	if not is_puppet and is_instance_valid(camera):
		sight_dir = -camera.global_basis.z.normalized()
	var head_name := _resolve_bone_name_safe("mixamorig:Head", skel)
	if head_name.is_empty():
		for fallback in ["Head", "head", "Cabeza"]:
			head_name = _resolve_bone_name_safe(fallback, skel)
			if not head_name.is_empty(): break
	var eye_name := _resolve_bone_name_safe("mixamorig:RightEye", skel)
	var head_idx := skel.find_bone(head_name) if not head_name.is_empty() else -1
	var eye_idx := skel.find_bone(eye_name) if not eye_name.is_empty() else -1
	if eye_idx < 0 and head_idx < 0:
		return false
	var eye_position: Vector3
	if eye_idx >= 0:
		eye_position = (skel.global_transform * skel.get_bone_global_pose(eye_idx)).origin
	else:
		eye_position = (skel.global_transform * skel.get_bone_global_pose(head_idx)).origin + global_basis.y.normalized() * .055 + global_basis.x.normalized() * .035
	var eye := eye_position + sight_dir * .10
	if sight_dir.length_squared() < 0.5:
		return false
	# Rifle basis: model -Z is the barrel, +Y is up, +X is its right side
	var bx := sight_dir.cross(global_basis.y.normalized())
	if bx.length_squared() < 0.01:
		bx = global_basis.x
	bx = bx.normalized()
	var bz := -sight_dir
	var by := bz.cross(bx).normalized()
	var b := Basis(bx, by, bz).scaled(Vector3.ONE * s)
	var o := eye - b * _rg_eye
	# Preserve the ocular eye line and 10 cm eye relief. A shoulder correction
	# here would move the scope into the nose as the animation changes.
	if not _rifle_weapon_offset.top_level:
		_rifle_weapon_offset.set_as_top_level(true)
	_rifle_weapon_offset.global_transform = Transform3D(b, o)
	_rifle_root.transform = Transform3D.IDENTITY
	_rifle_weapon_offset.force_update_transform()
	_rifle_root.force_update_transform()
	# The legacy TwoBoneIK3D modifier targets the handguard marker, which the
	# hand-solve no longer maintains — keep it off while this solver owns the pose.
	if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik):
		_rifle_left_arm_ik.active = false
		_rifle_left_arm_ik.influence = 0.0
	return true

func _solve_aim_arms() -> void:
	# Pull both hands onto the rifle: right wrist to the pistol grip, left wrist
	# under the handguard. Runs inside skeleton_updated, after the animation.
	var skel := _ik_skel
	if _rifle_weapon_offset == null or not is_instance_valid(_rifle_weapon_offset):
		return
	var wo_xf := _rifle_weapon_offset.global_transform
	var skel_inv := skel.global_transform.affine_inverse()
	# rifle-local space -> skeleton space, for the grip orientation targets
	var w2s := skel_inv.basis * wo_xf.basis
	if _ik_lh_idx >= 0 and _ik_upper_arm_idx >= 0 and _ik_forearm_idx >= 0:
		_grip_hand(skel, _ik_upper_arm_idx, _ik_forearm_idx, _ik_lh_idx, true,
			skel_inv * (wo_xf * _rg_left_knuckle), w2s * RIFLE_AIM_LEFT_FINGERS, w2s * RIFLE_AIM_LEFT_PALM, w2s * RIFLE_AIM_LEFT_ELBOW)
		var rig := _grip_rig_for(skel, _ik_lh_idx, true)
		if rig.has("thumb_child") and rig["thumb_child"] >= 0:
			var thumb: int = rig["thumb"]
			var thumb_pose := skel.get_bone_global_pose(thumb)
			var pivot: Vector3 = rig["pivots"].get(thumb, Vector3.ZERO)
			var base := thumb_pose * pivot
			var child: int = rig["thumb_child"]
			var tip := skel.get_bone_global_pose(child) * (rig["pivots"].get(child, Vector3.ZERO) as Vector3)
			var target: Vector3 = skel_inv * (wo_xf * _rg_left_thumb)
			var turn := Quaternion((tip - base).normalized(), (target - base).normalized())
			var basis := Basis(turn) * thumb_pose.basis
			skel.set_bone_global_pose(thumb, Transform3D(basis, base - basis * pivot))
	if _ik_rh_idx >= 0 and _ik_right_upper_arm_idx >= 0 and _ik_right_forearm_idx >= 0:
		_grip_hand(skel, _ik_right_upper_arm_idx, _ik_right_forearm_idx, _ik_rh_idx, false,
			skel_inv * (wo_xf * _rg_right_knuckle), w2s * RIFLE_AIM_RIGHT_FINGERS, w2s * RIFLE_AIM_RIGHT_PALM, w2s * RIFLE_AIM_RIGHT_ELBOW)

static func _anatomical_frame(fingers: Vector3, palm: Vector3) -> Basis:
	var f := fingers.normalized()
	var p := (palm - f * palm.dot(f)).normalized()
	return Basis(f, p, f.cross(p))

func _restore_grip_origins() -> void:
	# Imported clips generally animate finger rotations only. Undo the pivot
	# translations explicitly when aiming ends or the rifle is unequipped.
	if not _grip_pivots_applied or not is_instance_valid(_grip_rig_skel):
		return
	_grip_pivots_applied = false
	for rig in _grip_rig.values():
		for entry in rig.get("fingers", []):
			_grip_rig_skel.set_bone_pose_position(entry[0], _grip_rig_skel.get_bone_rest(entry[0]).origin)

func _grip_skin_pivots(skel: Skeleton3D) -> Dictionary:
	# The bare hands were transferred from another character. Their finger
	# geometry is offset from this rig's joint axes. Rotate about the actual
	# phalanges instead of swinging the mesh around an empty skeleton pivot.
	var mesh := _find_mesh_in_third_person("Desnudo_hands")
	var pivots := {}
	if mesh == null or mesh.mesh == null or mesh.skin == null:
		return pivots
	var sums := {}
	var counts := {}
	for surface in mesh.mesh.get_surface_count():
		var arrays := mesh.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		if weights.is_empty() or vertices.is_empty():
			continue
		var stride := int(weights.size() / vertices.size())
		for v in vertices.size():
			var best := 0
			for k in range(1, stride):
				if weights[v * stride + k] > weights[v * stride + best]:
					best = k
			var bind := bones[v * stride + best]
			var name := String(mesh.skin.get_bind_name(bind))
			var bone := skel.find_bone(name) if not name.is_empty() else mesh.skin.get_bind_bone(bind)
			if bone >= 0 and bone < skel.get_bone_count():
				name = skel.get_bone_name(bone)
			if bone < 0 or not name.contains("Hand") or name.ends_with("Hand"):
				continue
			var point := mesh.skin.get_bind_pose(bind) * vertices[v]
			sums[bone] = sums.get(bone, Vector3.ZERO) + point
			counts[bone] = counts.get(bone, 0) + 1
	for bone in sums:
		var children := skel.get_bone_children(bone)
		if not children.is_empty():
			pivots[bone] = sums[bone] / counts[bone] - skel.get_bone_rest(children[0]).origin * 0.5
	return pivots

func _grip_rig_for(skel: Skeleton3D, hand_idx: int, is_left: bool) -> Dictionary:
	# Rest-pose analysis, cached per hand: the hand's anatomical frame and each
	# finger joint's flexion axis (bone direction × palm normal, so a positive
	# angle always bends toward the palm — no per-rig sign guessing).
	if _grip_rig_skel != skel:
		_grip_rig.clear()
		_grip_rig_skel = skel
	if _grip_rig.has(hand_idx):
		return _grip_rig[hand_idx]
	var rig := {}
	_grip_rig[hand_idx] = rig
	var skin_pivots := _grip_skin_pivots(skel)
	var middle1 := -1
	var thumb1 := -1
	for c in skel.get_bone_children(hand_idx):
		var nm := skel.get_bone_name(c)
		if nm.contains("Middle"):
			middle1 = c
		elif nm.contains("Thumb"):
			thumb1 = c
	if middle1 < 0 or thumb1 < 0:
		return rig
	var f_l := skel.get_bone_rest(middle1).origin
	var t_l := skel.get_bone_rest(thumb1).origin
	var p_l := f_l.cross(t_l) if is_left else t_l.cross(f_l)
	rig["frame"] = _anatomical_frame(f_l, p_l)
	rig["knuckle"] = f_l + skel.get_bone_rest(middle1).basis * (skin_pivots.get(middle1, Vector3.ZERO) as Vector3)
	rig["middle"] = middle1
	rig["middle_pivot"] = skin_pivots.get(middle1, Vector3.ZERO)
	rig["thumb"] = thumb1
	rig["pivots"] = skin_pivots
	var thumb_children := skel.get_bone_children(thumb1)
	rig["thumb_child"] = thumb_children[0] if not thumb_children.is_empty() else -1
	var hand_rest := skel.get_bone_global_rest(hand_idx)
	var palm_rest := (hand_rest.basis * p_l).normalized()
	var curl_table: Dictionary = RIFLE_AIM_LEFT_CURL if is_left else RIFLE_AIM_RIGHT_CURL
	var fingers: Array = []
	for root_bone in skel.get_bone_children(hand_idx):
		var key := ""
		for k in curl_table:
			if skel.get_bone_name(root_bone).contains(k):
				key = k
		if key.is_empty():
			continue
		var b := root_bone
		for depth in 3:
			var kids := skel.get_bone_children(b)
			if kids.is_empty():
				break
			var g := skel.get_bone_global_rest(b)
			var dir := skel.get_bone_global_rest(kids[0]).origin - g.origin
			var axis := dir.cross(palm_rest)
			# Thumb base adducts toward the fingers instead of flexing: it lies
			# along the stock rather than sticking up off the palm.
			if key == "Thumb" and depth == 0:
				axis = dir.cross(skel.get_bone_global_rest(middle1).origin - hand_rest.origin)
			if axis.length_squared() > 1e-10:
				var rest_basis := skel.get_bone_rest(b).basis
				# Close the T-pose finger splay toward the middle finger so the
				# fingers lie together on the grip instead of fanning out.
				if depth == 0 and RIFLE_AIM_FINGER_CLOSE.has(key):
					var toward_mid := skel.get_bone_global_rest(middle1).origin - g.origin
					var close := deg_to_rad(RIFLE_AIM_FINGER_CLOSE[key]) * signf(dir.cross(toward_mid).dot(palm_rest))
					rest_basis = rest_basis * Basis((g.basis.inverse() * palm_rest).normalized(), close)
				fingers.append([b, (g.basis.inverse() * axis).normalized(),
					rest_basis, deg_to_rad(curl_table[key][depth]), skin_pivots.get(b, Vector3.ZERO)])
			b = kids[0]
	rig["fingers"] = fingers
	return rig

func _grip_hand(skel: Skeleton3D, ua_idx: int, fa_idx: int, hand_idx: int, is_left: bool, knuckle_s: Vector3, fingers_s: Vector3, palm_s: Vector3, elbow_s: Vector3 = Vector3.ZERO) -> void:
	# Orient the hand from its anatomical frame onto the grip frame, derive the
	# wrist from the knuckle target, IK the arm there, then pose the fingers.
	var rig := _grip_rig_for(skel, hand_idx, is_left)
	if not rig.has("frame"):
		_solve_arm_chain(skel, ua_idx, fa_idx, hand_idx, knuckle_s)
		return
	var scale := skel.get_bone_global_pose(hand_idx).basis.get_scale()
	var hand_basis: Basis = (_anatomical_frame(fingers_s, palm_s) * (rig["frame"] as Basis).inverse()).scaled_local(scale)
	_solve_arm_chain(skel, ua_idx, fa_idx, hand_idx, knuckle_s - hand_basis * (rig["knuckle"] as Vector3), fingers_s, elbow_s)
	# Pronation/supination: roll the forearm about its own axis to take most of
	# the hand's twist, so the wrist skin never wrings like a candy wrapper.
	var wrist_origin := skel.get_bone_global_pose(hand_idx).origin
	var fa := skel.get_bone_global_pose(fa_idx)
	var hand_rest := skel.get_bone_rest(hand_idx)
	var axis_l := hand_rest.origin.normalized()
	var q := Quaternion((fa.basis.orthonormalized().inverse() * hand_basis.orthonormalized()) * hand_rest.basis.orthonormalized().inverse())
	var twist := wrapf(2.0 * atan2(Vector3(q.x, q.y, q.z).dot(axis_l), q.w), -PI, PI)
	var axis_s := (fa.basis * axis_l).normalized()
	skel.set_bone_global_pose(fa_idx, Transform3D(Basis(axis_s, clampf(twist * RIFLE_AIM_FOREARM_TWIST, -0.12, 0.12)) * fa.basis, fa.origin))
	skel.set_bone_global_pose(hand_idx, Transform3D(hand_basis, wrist_origin))
	# Absolute flexion from rest: the animated finger pose is replaced, so the
	# result never stacks on an already-clenched animation fist.
	_grip_pivots_applied = true
	for entry in rig["fingers"]:
		var pose := skel.get_bone_pose(entry[0])
		pose.basis = (entry[2] as Basis) * Basis(entry[1] as Vector3, entry[3] as float)
		var rest := skel.get_bone_rest(entry[0])
		var pivot: Vector3 = entry[4]
		pose.origin = rest.origin + rest.basis * pivot - pose.basis * pivot
		skel.set_bone_pose(entry[0], pose)

func _solve_arm_chain(skel: Skeleton3D, ua_idx: int, fa_idx: int, hand_idx: int, target_skel: Vector3, forearm_hint: Vector3 = Vector3.ZERO, elbow_hint: Vector3 = Vector3.ZERO) -> void:
	# Two-bone IK in skeleton space: rotate upper arm + forearm so the hand bone
	# reaches target_skel; the hand keeps its animated grip orientation.
	var ua_pose := skel.get_bone_global_pose(ua_idx)
	var fa_pose := skel.get_bone_global_pose(fa_idx)
	var h_pose := skel.get_bone_global_pose(hand_idx)
	var root_pos := ua_pose.origin
	var mid_pos := fa_pose.origin
	var end_pos := h_pose.origin
	var len1 := root_pos.distance_to(mid_pos)
	var len2 := mid_pos.distance_to(end_pos)
	if len1 < 0.001 or len2 < 0.001:
		return
	var root_to_target := target_skel - root_pos
	var dist := root_to_target.length()
	var max_reach := (len1 + len2) * 0.999
	var min_reach := maxf(absf(len1 - len2) + 0.001, 0.001)
	if dist < 0.000001:
		root_to_target = (end_pos - root_pos).normalized()
		if root_to_target.length_squared() < 0.5:
			root_to_target = Vector3.DOWN
	if dist > max_reach:
		dist = max_reach
	if dist < min_reach:
		dist = min_reach
	var target_clamped := root_pos + root_to_target.normalized() * dist
	var a := (dist * dist - len2 * len2 + len1 * len1) / (2.0 * dist)
	var h := sqrt(maxf(len1 * len1 - a * a, 0.0))
	var dir_to_target := (target_clamped - root_pos) / dist
	# Elbow pole: keep the elbow on its current side of the root→target line
	var current_mid_offset := mid_pos - root_pos
	var perp := current_mid_offset - dir_to_target * current_mid_offset.dot(dir_to_target)
	if perp.length_squared() < 0.0001:
		perp = Vector3(0.0, -1.0, 0.0).slide(dir_to_target)
		if perp.length_squared() < 0.0001:
			perp = Vector3(1.0, 0.0, 0.0).slide(dir_to_target)
	perp = perp.normalized()
	# Steer the elbow so the forearm runs along forearm_hint: a forearm aimed
	# where the hand points keeps wrist flexion small (no rig twist bones).
	if forearm_hint.length_squared() > 0.0001:
		var ideal := (target_clamped - forearm_hint.normalized() * len2 - root_pos).slide(dir_to_target)
		if ideal.length_squared() > 0.000001:
			perp = perp.lerp(ideal.normalized(), RIFLE_AIM_ELBOW_STEER).normalized()
	# Pole bias: pull the elbow toward an explicit out/down direction so the
	# firing arm doesn't flare its elbow above the shoulder line.
	if elbow_hint.length_squared() > 0.0001:
		var pole := elbow_hint.slide(dir_to_target)
		if pole.length_squared() > 0.000001:
			perp = perp.lerp(pole.normalized(), RIFLE_AIM_ELBOW_POLE).normalized()
	var new_mid := root_pos + dir_to_target * a + perp * h
	# Use one hinge plane for both bones. Independently swinging their animated
	# orientations preserved unrelated rolls and twisted the elbow skin.
	var upper_dir := (new_mid - root_pos).normalized()
	var lower_dir := (target_clamped - new_mid).normalized()
	var hinge := upper_dir.cross(lower_dir).normalized()
	if hinge.length_squared() < 0.5:
		hinge = upper_dir.cross(perp).normalized()
	var source_hinge := ua_pose.basis.z.normalized()
	var bone_name := skel.get_bone_name(ua_idx)
	if bone_name.contains("Right") or (not bone_name.contains("Left") and hinge.dot(source_hinge) < 0.0):
		hinge = -hinge
	for bone in [ua_idx, fa_idx]:
		var child := fa_idx if bone == ua_idx else hand_idx
		var rest := skel.get_bone_global_rest(bone)
		var rest_dir := (skel.get_bone_global_rest(child).origin - rest.origin).normalized()
		var rest_hinge := rest.basis.z.slide(rest_dir).normalized()
		if rest_hinge.length_squared() < 0.5:
			rest_hinge = rest.basis.y.slide(rest_dir).normalized()
		var desired_dir := upper_dir if bone == ua_idx else lower_dir
		var rotation := _anatomical_frame(desired_dir, hinge) * _anatomical_frame(rest_dir, rest_hinge).inverse()
		var basis := rotation * rest.basis
		var current_scale := skel.get_bone_global_pose(bone).basis.get_scale()
		basis = basis.orthonormalized().scaled_local(current_scale)
		skel.set_bone_global_pose(bone, Transform3D(basis, root_pos if bone == ua_idx else new_mid))
	skel.set_bone_global_pose(hand_idx, Transform3D(h_pose.basis, target_clamped))

func _on_skeleton_updated() -> void:
	if _ik_skel == null or not is_instance_valid(_ik_skel):
		return
	if not _is_aiming and not _is_firing:
		# Turn clips update the hands after _process. Refit to that final pose.
		_update_rifle_ik(_ik_skel, 0.0)
		if _mounted_rifle_is_m4 and _ik_lh_idx >= 0 and _ik_upper_arm_idx >= 0 and _ik_forearm_idx >= 0 and is_instance_valid(_rifle_root):
			_m4_saved_left_arm_poses = [
				[_ik_upper_arm_idx, _ik_skel.get_bone_pose(_ik_upper_arm_idx)],
				[_ik_forearm_idx, _ik_skel.get_bone_pose(_ik_forearm_idx)],
				[_ik_lh_idx, _ik_skel.get_bone_pose(_ik_lh_idx)],
			]
			var rf_xf := _rifle_root.global_transform
			var skel_inv2 := _ik_skel.global_transform.affine_inverse()
			var w2s2 := skel_inv2.basis * rf_xf.basis
			_grip_hand(_ik_skel, _ik_upper_arm_idx, _ik_forearm_idx, _ik_lh_idx, true,
				skel_inv2 * (rf_xf * _rg_left_knuckle), w2s2 * RIFLE_AIM_LEFT_FINGERS, w2s2 * RIFLE_AIM_LEFT_PALM, Vector3.ZERO)
			var lrig := _grip_rig_for(_ik_skel, _ik_lh_idx, true)
			if lrig.has("thumb_child") and lrig["thumb_child"] >= 0:
				var thumb: int = lrig["thumb"]
				var thumb_pose := _ik_skel.get_bone_global_pose(thumb)
				var pivot: Vector3 = lrig["pivots"].get(thumb, Vector3.ZERO)
				var base := thumb_pose * pivot
				var child: int = lrig["thumb_child"]
				var tip := _ik_skel.get_bone_global_pose(child) * (lrig["pivots"].get(child, Vector3.ZERO) as Vector3)
				var target: Vector3 = skel_inv2 * (rf_xf * _rg_left_thumb)
				var turn := Quaternion((tip - base).normalized(), (target - base).normalized())
				var tbasis := Basis(turn) * thumb_pose.basis
				_ik_skel.set_bone_global_pose(thumb, Transform3D(tbasis, base - tbasis * pivot))
		return
	if _rifle_aim_pose_active:
		if is_instance_valid(_rifle_weapon_offset):
			var skel_s := _ik_skel.global_transform.basis.get_scale().x
			_try_place_rifle_aiming(_ik_skel, _rifle_weapon_scale() * skel_s)
		_solve_aim_arms()
		return
	if _ik_lh_idx < 0 or _ik_upper_arm_idx < 0 or _ik_forearm_idx < 0:
		return
	if _rifle_left_hand_grip == null or not is_instance_valid(_rifle_left_hand_grip):
		return
	var skel := _ik_skel
	var skel_inv := skel.global_transform.affine_inverse()
	# Target in skeleton space
	var grip_in_skel := skel_inv * _rifle_left_hand_grip.global_transform
	var target_pos := grip_in_skel.origin
	# Current bone global poses in skeleton space
	var ua_pose := skel.get_bone_global_pose(_ik_upper_arm_idx)
	var fa_pose := skel.get_bone_global_pose(_ik_forearm_idx)
	var lh_pose := skel.get_bone_global_pose(_ik_lh_idx)
	var root_pos := ua_pose.origin
	var mid_pos := fa_pose.origin
	var end_pos := lh_pose.origin
	# Bone lengths
	var len1 := root_pos.distance_to(mid_pos)
	var len2 := mid_pos.distance_to(end_pos)
	if len1 < 0.001 or len2 < 0.001:
		return
	# Clamp target to reachable distance
	var root_to_target := target_pos - root_pos
	var dist := root_to_target.length()
	if dist < 0.001:
		return
	var max_reach := len1 + len2 - 0.001
	var min_reach := absf(len1 - len2) + 0.001
	if dist > max_reach:
		root_to_target = root_to_target.normalized() * max_reach
		dist = max_reach
	elif dist < min_reach:
		root_to_target = root_to_target.normalized() * min_reach
		dist = min_reach
	var target_clamped := root_pos + root_to_target
	# Law of cosines: find elbow position
	var a := (dist * dist - len2 * len2 + len1 * len1) / (2.0 * dist)
	var h_sq := len1 * len1 - a * a
	if h_sq < 0.0:
		h_sq = 0.0
	var h := sqrt(h_sq)
	var dir_to_target := root_to_target / dist
	# Pole direction: use current elbow offset perpendicular to root-target line
	var current_mid_offset := mid_pos - root_pos
	var perp := current_mid_offset - dir_to_target * current_mid_offset.dot(dir_to_target)
	if perp.length_squared() < 0.0001:
		perp = Vector3(0.0, 1.0, 0.0).slide(dir_to_target)
		if perp.length_squared() < 0.0001:
			perp = Vector3(1.0, 0.0, 0.0).slide(dir_to_target)
	perp = perp.normalized()
	# New elbow position
	var new_mid := root_pos + dir_to_target * a + perp * h
	# Set upper arm: point from root to new_mid
	var ua_orig_dir := (mid_pos - root_pos).normalized()
	var ua_new_dir := (new_mid - root_pos).normalized()
	var ua_q := Quaternion(ua_orig_dir, ua_new_dir)
	var ua_new_basis := Basis(ua_q) * ua_pose.basis
	skel.set_bone_global_pose(_ik_upper_arm_idx, Transform3D(ua_new_basis, root_pos))
	# Set forearm: point from new_mid to target_clamped
	var fa_orig_dir := (end_pos - mid_pos).normalized()
	var fa_new_dir := (target_clamped - new_mid).normalized()
	var fa_q := Quaternion(fa_orig_dir, fa_new_dir)
	var fa_new_basis := Basis(fa_q) * fa_pose.basis
	skel.set_bone_global_pose(_ik_forearm_idx, Transform3D(fa_new_basis, new_mid))
	# Preserve the reachable wrist position; using the original grip origin
	# here stretched the forearm whenever the marker was out of reach. The
	# basis must stay orthonormal: grip_in_skel carries the WeaponOffset
	# scale (weapon_scale x skeleton scale), and storing it would corrupt
	# the hand pose scale read by the next _grip_hand solve.
	skel.set_bone_global_pose(_ik_lh_idx, Transform3D(grip_in_skel.basis.orthonormalized(), target_clamped))

func _measure_right_hand_to_grip(skel: Skeleton3D, delta: float) -> void:
	# Phase 1 only: measure dist between right hand bone and RightGrip after 2s stable RifleIdle.
	# Do NOT adjust anything here. User will manually tune rifle_root_offset in <=5 unit steps.
	if _rh_grip_logged:
		return
	var anim := _get_rifle_anim_player()
	if anim == null or not anim.is_playing():
		_rh_grip_measure_timer = 0.0
		_rh_grip_measure_samples.clear()
		return
	if anim.current_animation != "external/RifleIdleExternal":
		_rh_grip_measure_timer = 0.0
		_rh_grip_measure_samples.clear()
		return
	_rh_grip_measure_timer += delta
	var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var rh_pos := Vector3.ZERO
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	if _rifle_right_grip == null or not is_instance_valid(_rifle_right_grip):
		return
	var rg_pos := _rifle_right_grip.global_position
	var d := rh_pos.distance_to(rg_pos)
	_rh_grip_measure_samples.append(d)
	if _rh_grip_measure_timer < 2.0:
		return
	# Compute average
	var sum := 0.0
	for s in _rh_grip_measure_samples:
		sum += s
	var n := float(_rh_grip_measure_samples.size())
	var avg := sum / n if n > 0.0 else 0.0
	_rh_grip_last_dist = avg
	_rh_grip_logged = true

func _root_align_search(skel: Skeleton3D, delta: float) -> void:
	if _rifle_right_grip == null or not is_instance_valid(_rifle_right_grip):
		return
	var anim := _get_rifle_anim_player()
	if anim == null or not anim.is_playing():
		_root_align_timer = 0.0
		_root_align_samples.clear()
		return
	if anim.current_animation != "external/RifleIdleExternal":
		_root_align_timer = 0.0
		_root_align_samples.clear()
		return
	_root_align_timer += delta
	# sample current dist_RH
	var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var rh_pos := Vector3.ZERO
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var rg_pos := _rifle_right_grip.global_position
	var d := rh_pos.distance_to(rg_pos)
	_root_align_samples.append(d)
	if _root_align_timer < 2.0:
		return
	# average over window
	var sum := 0.0
	for s in _root_align_samples:
		sum += s
	var n := float(_root_align_samples.size())
	var avg := sum / n if n > 0.0 else 0.0
	var n_int := _root_align_samples.size()
	_root_align_samples.clear()
	_root_align_timer = 0.0
	var axis_names := ["X", "Z", "Y"]
	var axis_name: String = axis_names[_root_align_axis]
		# _root_align_round, axis_name, _root_align_phase, avg, str(rifle_root_offset), n_int
	# ])
	match _root_align_phase:
		0: # base measurement
			_root_align_best_dist = avg
			_root_align_best_offset = rifle_root_offset
			# try +step on current axis
			_apply_root_offset_delta(_root_align_axis, _root_align_step)
			_root_align_phase = 1
		1: # after +
			if avg < _root_align_best_dist:
				_root_align_best_dist = avg
				_root_align_best_offset = rifle_root_offset
				# continue in same direction
				_apply_root_offset_delta(_root_align_axis, _root_align_step)
				_root_align_phase = 1
			else:
				rifle_root_offset = _root_align_best_offset
				_apply_root_offset_delta(_root_align_axis, -_root_align_step)
				_root_align_phase = 2
		2: # after -
			if avg < _root_align_best_dist:
				_root_align_best_dist = avg
				_root_align_best_offset = rifle_root_offset
				_apply_root_offset_delta(_root_align_axis, -_root_align_step)
				_root_align_phase = 2
			else:
				rifle_root_offset = _root_align_best_offset
				_next_root_axis()
	# convergence check
	if _root_align_best_dist < 0.02:
		rifle_root_offset = _root_align_best_offset
		_root_align_converged = true
		# also log other distances at this stable pose for info (no adjustments)
		var lh_bone := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
		var lh_pos := Vector3.ZERO
		if not lh_bone.is_empty():
			var lh_idx := skel.find_bone(lh_bone)
			if lh_idx >= 0:
				lh_pos = (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
		var re_bone := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
		var re_pos := Vector3.ZERO
		if not re_bone.is_empty():
			var re_idx := skel.find_bone(re_bone)
			if re_idx >= 0:
				re_pos = (skel.global_transform * skel.get_bone_global_pose(re_idx)).origin
			# _root_align_best_dist,
			# lh_pos.distance_to(_rifle_left_hand_grip.global_position),
			# re_pos.distance_to(_rifle_stock_ref.global_position)
		# ])

func _apply_root_offset_delta(axis: int, delta: float) -> void:
	match axis:
		0: rifle_root_offset.x += delta
		1: rifle_root_offset.z += delta
		2: rifle_root_offset.y += delta

func _next_root_axis() -> void:
	_root_align_axis += 1
	_root_align_phase = 0
	_root_align_round += 1
	if _root_align_axis > 2:
		_root_align_axis = 0
		_root_align_step *= 0.5
		if _root_align_step < 0.25:
			_root_align_step = 0.25
		# _root_align_best_dist, str(_root_align_best_offset), _root_align_step
	# ])

func _log_ik_diagnostics(skel: Skeleton3D) -> void:
	var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var rh_pos := Vector3.ZERO
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var rg_pos := _rifle_right_grip.global_position
	var dist_rh := rh_pos.distance_to(rg_pos)
	var lh_bone := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	var lh_pos := Vector3.ZERO
	if not lh_bone.is_empty():
		var lh_idx := skel.find_bone(lh_bone)
		if lh_idx >= 0:
			lh_pos = (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	var lgrip_pos := _rifle_left_hand_grip.global_position
	var dist_lh := lh_pos.distance_to(lgrip_pos)
	var re_bone := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
	var re_pos := Vector3.ZERO
	if not re_bone.is_empty():
		var re_idx := skel.find_bone(re_bone)
		if re_idx >= 0:
			re_pos = (skel.global_transform * skel.get_bone_global_pose(re_idx)).origin
	var stock_pos := _rifle_stock_ref.global_position
	var dist_stock := re_pos.distance_to(stock_pos)
	var left_inf := _rifle_left_arm_ik.influence if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik) else 0.0
	var right_inf := _rifle_right_arm_ik.influence if _rifle_right_arm_ik != null and is_instance_valid(_rifle_right_arm_ik) else 0.0
		# left_inf, right_inf, dist_rh, dist_lh, dist_stock,
		# rh_pos.x, rh_pos.y, rh_pos.z, rg_pos.x, rg_pos.y, rg_pos.z
	# ])

func _clear_rifle_attachment() -> void:
	_restore_grip_origins()
	if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik):
		_rifle_left_arm_ik.active = false
		_rifle_left_arm_ik.queue_free()
	if _rifle_right_arm_ik != null and is_instance_valid(_rifle_right_arm_ik):
		_rifle_right_arm_ik.active = false
		_rifle_right_arm_ik.queue_free()
	if _rifle_stock_target != null and is_instance_valid(_rifle_stock_target):
		_rifle_stock_target.queue_free()
	if _rifle_muzzle_target != null and is_instance_valid(_rifle_muzzle_target):
		_rifle_muzzle_target.queue_free()
	if _rifle_left_elbow_pole != null and is_instance_valid(_rifle_left_elbow_pole):
		_rifle_left_elbow_pole.queue_free()
	if _rifle_right_elbow_pole != null and is_instance_valid(_rifle_right_elbow_pole):
		_rifle_right_elbow_pole.queue_free()
	_rifle_left_arm_ik = null
	_rifle_right_arm_ik = null
	_rifle_left_elbow_pole = null
	_rifle_right_elbow_pole = null
	_rifle_stock_target = null
	_rifle_muzzle_target = null
	_rifle_right_grip = null
	_rifle_left_hand_grip = null
	_rifle_stock_ref = null
	_rifle_muzzle = null
	_rifle_model = null
	_rifle_root = null
	_mounted_rifle_is_m4 = false
	_m4_saved_left_arm_poses.clear()
	if _rifle_weapon_offset != null and is_instance_valid(_rifle_weapon_offset):
		_rifle_weapon_offset.queue_free()
	_rifle_weapon_offset = null
	_rifle_aim_pose_active = false
	_is_firing = false
	if _rifle_bone_attachment != null and is_instance_valid(_rifle_bone_attachment):
		_rifle_bone_attachment.queue_free()
	_rifle_bone_attachment = null
	if _rifle_on_back_strap != null and is_instance_valid(_rifle_on_back_strap):
		var p2 = _rifle_on_back_strap.get_parent()
		if p2 != null:
			p2.remove_child(_rifle_on_back_strap)
		_rifle_on_back_strap.free()
	_rifle_on_back_strap = null
	_strap_skeleton = null
	if _strap_guide_upper != null and is_instance_valid(_strap_guide_upper):
		_strap_guide_upper.free()
	_strap_guide_upper = null
	if _strap_guide_lower != null and is_instance_valid(_strap_guide_lower):
		_strap_guide_lower.free()
	_strap_guide_lower = null
	_strap_upper_offset = null
	_strap_lower_offset = null
	_strap_barrel_marker = null
	_strap_stock_marker = null
	_strap_initialized = false
	_strap_prev_pts = PackedVector3Array()
	if third_person_model != null and is_instance_valid(third_person_model):
		for child in third_person_model.get_children():
			if child is Node3D and (child.name == "RifleSlingRoot" or child.name.begins_with("RifleSling") or child.name == "ProceduralStrapMesh"):
				child.free()

func _setup_rifle_left_arm_ik(skel: Skeleton3D, target: Node3D) -> void:
	var upper_arm := _resolve_bone_name_safe("mixamorig:LeftArm", skel)
	var forearm := _resolve_bone_name_safe("mixamorig:LeftForeArm", skel)
	var left_hand := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	if upper_arm.is_empty() or left_hand.is_empty():
		return
	_rifle_left_arm_ik = TwoBoneIK3D.new()
	_rifle_left_arm_ik.name = "TwoBoneIK3D_LeftArm"
	_rifle_left_arm_ik.process_priority = 100
	skel.add_child(_rifle_left_arm_ik)
	_rifle_left_arm_ik.setting_count = 1
	_rifle_left_arm_ik.set_root_bone_name(0, upper_arm)
	_rifle_left_arm_ik.set_middle_bone_name(0, forearm)
	_rifle_left_arm_ik.set_end_bone_name(0, left_hand)
	var target_path := _rifle_left_arm_ik.get_path_to(target)
	var pole_path := _rifle_left_arm_ik.get_path_to(_rifle_left_elbow_pole)
	_rifle_left_arm_ik.set_target_node(0, target_path)
	_rifle_left_arm_ik.set_pole_node(0, pole_path)
	_rifle_left_arm_ik.active = true
	_rifle_left_arm_ik.influence = 0.0

func _setup_rifle_right_arm_ik(skel: Skeleton3D, target: Node3D) -> void:
	var upper_arm := _resolve_bone_name_safe("mixamorig:RightArm", skel)
	var forearm := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
	var right_hand := _resolve_bone_name_safe("mixamorig:RightHand", skel)
	if upper_arm.is_empty() or right_hand.is_empty():
		return
	_rifle_right_arm_ik = TwoBoneIK3D.new()
	_rifle_right_arm_ik.name = "TwoBoneIK3D_RightArm"
	_rifle_right_arm_ik.process_priority = 100
	skel.add_child(_rifle_right_arm_ik)
	_rifle_right_arm_ik.setting_count = 1
	_rifle_right_arm_ik.set_root_bone_name(0, upper_arm)
	_rifle_right_arm_ik.set_middle_bone_name(0, forearm)
	_rifle_right_arm_ik.set_end_bone_name(0, right_hand)
	_rifle_right_arm_ik.set_target_node(0, target.get_path())
	_rifle_right_arm_ik.set_pole_node(0, _rifle_right_elbow_pole.get_path())
	_rifle_right_arm_ik.active = true
	_rifle_right_arm_ik.influence = 0.0

func _auto_align_step(skel: Skeleton3D, delta: float) -> void:
	if not _auto_align_enabled or _auto_align_converged:
		return
	if _rifle_weapon_offset == null or not is_instance_valid(_rifle_weapon_offset):
		return
	if _rifle_stock_ref == null or not is_instance_valid(_rifle_stock_ref):
		return
	if _rifle_left_hand_grip == null or not is_instance_valid(_rifle_left_hand_grip):
		return
	if _rifle_right_grip == null or not is_instance_valid(_rifle_right_grip):
		return
	# Check if RifleIdle is playing
	var anim := _get_rifle_anim_player()
	if anim == null or not anim.is_playing():
		return
	var anim_name := anim.current_animation
	if anim_name != "external/RifleIdleExternal":
		_auto_align_rifleidle_timer = 0.0
		_auto_align_samples.clear()
		return
	# Accumulate time in RifleIdle
	_auto_align_rifleidle_timer += delta
	# Collect samples every frame during the 2s window
	var elbow_pos := Vector3.ZERO
	var lhand_pos := Vector3.ZERO
	var rh_pos := Vector3.ZERO
	var re_bone := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
	if not re_bone.is_empty():
		var re_idx := skel.find_bone(re_bone)
		if re_idx >= 0:
			elbow_pos = (skel.global_transform * skel.get_bone_global_pose(re_idx)).origin
	var lh_bone := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	if not lh_bone.is_empty():
		var lh_idx := skel.find_bone(lh_bone)
		if lh_idx >= 0:
			lhand_pos = (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var stock_pos := _rifle_stock_ref.global_position
	var lgrip_pos := _rifle_left_hand_grip.global_position
	var rg_pos := _rifle_right_grip.global_position
	_auto_align_samples.append({
		"error_stock": elbow_pos - stock_pos,
		"error_left": lhand_pos - lgrip_pos,
		"error_right": rh_pos - rg_pos,
	})
	if _auto_align_rifleidle_timer < 2.0:
		return
	# Average all samples
	var avg_stock := Vector3.ZERO
	var avg_left := Vector3.ZERO
	var avg_right := Vector3.ZERO
	for s in _auto_align_samples:
		avg_stock += s["error_stock"]
		avg_left += s["error_left"]
		avg_right += s["error_right"]
	var n := float(_auto_align_samples.size())
	avg_stock /= n
	avg_left /= n
	avg_right /= n
	var dist_stock := avg_stock.length()
	var dist_left := avg_left.length()
	var dist_right := avg_right.length()
	_auto_align_iteration += 1
	# Check convergence with user-specified thresholds
	if dist_stock < 0.05 and dist_left < 0.03 and dist_right < 0.02:
		_auto_align_converged = true
		return
	# Strategy: only adjust weapon_offset_pos to minimize all three errors.
	# Markers are FIXED. IK should bring hands to grips, but if the rifle is too far,
	# IK can't reach. So we need weapon_offset_pos that minimizes all errors.
	# Use weighted least squares: move by weighted average of all errors.
	# Weight stock more (it can't be reached by IK, only by position),
	# weight right hand less (IK should handle it, but if too far, need position help).
	var skel_scale_align := skel.global_transform.basis.get_scale().x
	# Weighted combination: stock has no IK, so weight it highest.
	# Right and left hands have IK, but if IK can't reach, position must help.
	var w_stock := 1.0
	var w_right := 0.5
	var w_left := 0.5
	var total_weight := w_stock + w_right + w_left
	var combined_error := (avg_stock * w_stock + avg_right * w_right + avg_left * w_left) / total_weight
	weapon_offset_pos += combined_error / skel_scale_align
	# Reset for next iteration
	_auto_align_rifleidle_timer = 0.0
	_auto_align_samples.clear()

func _get_rifle_anim_player() -> AnimationPlayer:
	if _rifle_model != null and is_instance_valid(_rifle_model):
		var p := _rifle_model.get_parent()
		while p != null:
			for c in p.get_children():
				if c is AnimationPlayer:
					return c as AnimationPlayer
			p = p.get_parent()
	return null

func _resolve_bone_name_safe(preferred: String, skeleton: Skeleton3D = null) -> String:
	var target_skeleton := skeleton if skeleton != null else _spine_skeleton
	if target_skeleton == null:
		return ""
	var idx := target_skeleton.find_bone(preferred)
	if idx >= 0:
		return preferred
	var alt := preferred.replace(":", "_")
	idx = target_skeleton.find_bone(alt)
	if idx >= 0:
		return alt
	var short_name := preferred.split(":")[-1] if preferred.find(":") >= 0 else preferred
	idx = target_skeleton.find_bone(short_name)
	if idx >= 0:
		return short_name
	return ""

func _resolve_bone_name_cached(cache_key: String, preferred: String, skeleton: Skeleton3D) -> String:
	if _ik_bone_cache.has(cache_key):
		return _ik_bone_cache[cache_key]
	var resolved := _resolve_bone_name_safe(preferred, skeleton)
	if not resolved.is_empty():
		_ik_bone_cache[cache_key] = resolved
	return resolved

func _find_bone_cached(cache_key: String, bone_name: String, skeleton: Skeleton3D) -> int:
	if _ik_bone_cache.has(cache_key):
		return _ik_bone_cache[cache_key]
	var idx := skeleton.find_bone(bone_name)
	if idx >= 0:
		_ik_bone_cache[cache_key] = idx
	return idx

# Grip-sized flashlight body and lens.
func _build_third_person_flashlight() -> void:
	_add_held_cylinder(third_person_hand_item_root, "FlashlightBody", 0.022, 0.16, Vector3.ZERO, Color(0.12, 0.14, 0.16), Vector3.ZERO)
	_add_held_cylinder(third_person_hand_item_root, "FlashlightLens", 0.035, 0.025, Vector3(0, 0.08, 0), Color(0.8, 0.85, 0.9), Vector3.ZERO)

func _build_third_person_can() -> void:
	_build_third_person_meat_on_stick()

func _build_third_person_meat_on_stick() -> void:
	var stick_node := _load_external_node3d(REAL_WOOD_STICK_MODEL)
	if stick_node != null:
		stick_node.name = "ThirdPersonStick"
		stick_node.scale = Vector3.ONE * 0.2
		stick_node.position = Vector3(0.0, 0.05, -0.15)
		stick_node.rotation_degrees = Vector3(75, 0, 0)
		third_person_hand_item_root.add_child(stick_node)
	var meat_node := _load_external_node3d(REAL_MEAT_ON_STICK_MODEL)
	if meat_node != null:
		meat_node.name = "ThirdPersonMeat"
		meat_node.scale = Vector3.ONE * 0.15
		meat_node.position = Vector3(0.0, 0.12, -0.20)
		meat_node.rotation_degrees = Vector3(75, 0, 0)
		third_person_hand_item_root.add_child(meat_node)

func _build_third_person_bottle() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, REAL_BOTTLE_MODEL, "ThirdPersonBottle", Vector3(0, 0, -0.12), Vector3(0, 0, 0), Vector3.ONE * 0.5)

func _build_third_person_plastic_bottle() -> void:
	if _try_add_model_to_parent(third_person_hand_item_root, REAL_PLASTIC_BOTTLE_MODEL, "ThirdPersonPlasticBottle", Vector3(0, 0, -0.12), Vector3(180, 0, 0), Vector3.ONE * 0.015):
		_fix_bottle_materials(third_person_hand_item_root.get_node("ThirdPersonPlasticBottle"))

# Drink bottle held in the LEFT hand, attached via BoneAttachment3D to the
# left hand bone so it automatically follows the drink animation's pose.
func _build_third_person_drink_bottle_left_hand() -> void:
	if _drink_hand_root == null or not is_instance_valid(_drink_hand_root):
		return
	for child in _drink_hand_root.get_children():
		if child.name == "ThirdPersonDrinkBottleLeft":
			child.queue_free()
	var bottle_mesh_center_local := Vector3(-15.22919, 15.60067, -2.003666)
	var bottle_scale := Vector3.ONE * 0.016
	var bottle_rot_deg := Vector3(-115, 0, 90)
	var bottle_basis := Basis.from_euler(Vector3(deg_to_rad(bottle_rot_deg.x), deg_to_rad(bottle_rot_deg.y), deg_to_rad(bottle_rot_deg.z)))
	var bottle_pos := -(bottle_basis * (bottle_scale * bottle_mesh_center_local)) + Vector3(0, 0.0, 0.0)
	var ok = _try_add_model_to_parent(_drink_hand_root, REAL_PLASTIC_BOTTLE_MODEL, "ThirdPersonDrinkBottleLeft", bottle_pos, bottle_rot_deg, bottle_scale)
	if ok:
		var bottle_node := _drink_hand_root.get_node_or_null("ThirdPersonDrinkBottleLeft")
		if bottle_node != null:
			_fix_bottle_materials(bottle_node)

func _fix_bottle_materials(root: Node) -> void:
	for child in root.get_children():
		if child is MeshInstance3D:
			for i in range(child.get_surface_override_material_count()):
				var mat: Material = child.get_surface_override_material(i)
				if mat == null and child.mesh != null:
					mat = child.mesh.surface_get_material(i)
				if mat is StandardMaterial3D:
					var smat := mat as StandardMaterial3D
					smat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					smat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
					smat.no_depth_test = false
					child.set_surface_override_material(i, smat)
		_fix_bottle_materials(child)

func _print_tree_debug(node: Node, depth: int) -> void:
	var prefix = ""
	for i in range(depth):
		prefix += "  "
	var info = prefix + node.name + " [" + node.get_class() + "]"
	if node is Node3D:
		info += " visible=" + str(node.visible) + " pos=" + str(node.position) + " scale=" + str(node.scale)
	print("DEBUG drink: ", info)
	for child in node.get_children():
		_print_tree_debug(child, depth + 1)

func _clear_third_person_drink_bottle_left_hand() -> void:
	if _drink_hand_root == null or not is_instance_valid(_drink_hand_root):
		return
	for child in _drink_hand_root.get_children():
		if child.name == "ThirdPersonDrinkBottleLeft":
			child.queue_free()

func _build_third_person_drink_bottle() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, REAL_PLASTIC_BOTTLE_MODEL, "ThirdPersonDrinkBottle", Vector3(0, 0, -0.12), Vector3(180, 0, 0), Vector3.ONE * 0.5)

func _build_third_person_bandage() -> void:
	_add_held_cylinder(third_person_hand_item_root, "BandageRoll", 0.035, 0.08, Vector3.ZERO, Color(0.88, 0.86, 0.76), Vector3.ZERO)

func _build_third_person_battery() -> void:
	_add_held_cylinder(third_person_hand_item_root, "BatteryBody", 0.014, 0.055, Vector3.ZERO, Color(0.15, 0.16, 0.18), Vector3.ZERO)
	_add_held_cylinder(third_person_hand_item_root, "BatteryTerminal", 0.006, 0.004, Vector3(0, 0.029, 0), Color(0.7, 0.7, 0.72), Vector3.ZERO)

func _build_third_person_resource(item_name: String) -> void:
	if item_name in ["Palo", "Palo afilado"]:
		_try_add_model_to_parent(third_person_hand_item_root, REAL_WOOD_STICK_MODEL, "ThirdPersonStick", Vector3.ZERO, Vector3.ZERO, Vector3.ONE)
	elif item_name == "Madera" or item_name == "Ramas":
		_try_add_model_to_parent(third_person_hand_item_root, REAL_WOOD_MODEL, "ThirdPersonWood", Vector3(0, 0, -0.18), Vector3(82, 0, 8), Vector3.ONE * 0.5)
	elif item_name == "Piedra":
		_try_add_model_to_parent(third_person_hand_item_root, REAL_STONE_MODEL, "ThirdPersonStone", Vector3(0, 0, -0.12), Vector3(8, 18, 6), Vector3.ONE * 0.11)
	elif item_name == "Tronco":
		_add_named_held_model("res://assets/external/kenney_survival_kit/Models/GLB format/tree-log.glb", "HeldLog")
		if third_person_hand_item_root != null:
			var held_log := third_person_hand_item_root.find_child("HeldLog", true, false)
			if held_log != null:
				MaterialFactory.apply_realistic_log_materials(held_log)
	elif item_name == "Semillas":
		_build_third_person_seed_bag()
	elif item_name == "Trapos":
		_add_named_held_model("res://assets/external/kenney_survival_kit/Models/GLB format/bedroll.glb", "HeldRags")
	elif item_name == "Tela de camuflaje":
		_add_named_held_model("res://assets/models/props/camo_net_pickup.glb", "HeldClothing")
	else:
		_build_third_person_pack()

# Same linen pouch in the hand and as ground loot.
func _build_third_person_seed_bag() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, "res://assets/models/props/farming/farm_seed_pouch.glb", "HeldSeeds", Vector3(0, -0.07, -0.03), Vector3.ZERO, Vector3.ONE)

func _build_third_person_primitive(item_name: String) -> void:
	if third_person_hand_item_root == null:
		return
	var glb_path := ""
	match item_name:
		"Arco de madera": glb_path = WOODEN_BOW_MODEL
		"Arco reforzado": glb_path = REINFORCED_BOW_MODEL
		"Flecha de madera": glb_path = ARROW_WOOD_MODEL
		"Flecha de piedra": glb_path = ARROW_STONE_MODEL
		"Flecha de hueso": glb_path = ARROW_BONE_MODEL
		"Cuerda": glb_path = ROPE_COIL_MODEL
		"Hueso": glb_path = ANIMAL_BONE_MODEL
		"Tendón": glb_path = ANIMAL_SINEW_MODEL
	var prim: Node3D = null
	if not glb_path.is_empty():
		prim = _load_external_node3d(glb_path)
	if prim == null:
		prim = MaterialFactory.build_primitive_item_mesh(item_name)
	prim.name = "HeldPrimitive"
	if item_name in ["Lanza", "Lanza de hueso", "Palo afilado"]:
		prim.rotation_degrees = Vector3(85.0, 0.0, 0.0)
	elif item_name in ["Arco de madera", "Arco reforzado"]:
		prim.rotation_degrees = Vector3(0.0, 90.0, 0.0)
		var str_mat := StandardMaterial3D.new()
		str_mat.albedo_color = Color(0.88, 0.82, 0.66)
		str_mat.roughness = 0.68
		for seg_name in ["BowDrawStringTop", "BowDrawStringBot"]:
			var seg := MeshInstance3D.new()
			seg.name = seg_name
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0036
			cyl.bottom_radius = 0.0036
			cyl.height = 0.62
			cyl.radial_segments = 8
			seg.mesh = cyl
			seg.material_override = str_mat
			seg.visible = false
			prim.add_child(seg)
		var nocked := Node3D.new()
		nocked.name = "BowNockedArrow"
		nocked.visible = false
		var init_arrow_name := _peek_best_arrow_name()
		if init_arrow_name.is_empty():
			init_arrow_name = "Flecha de piedra"
		var init_arrow_vis := _build_arrow_or_spear_visual(init_arrow_name, "ammo_arrow", false)
		if init_arrow_vis != null:
			nocked.add_child(init_arrow_vis)
		nocked.set_meta("arrow_kind", init_arrow_name)
		prim.add_child(nocked)
	third_person_hand_item_root.add_child(prim)

# Bundle de ropa: sin modelo 3P diferenciado, usa pack genérico
func _build_third_person_clothing_bundle() -> void:
	_build_third_person_pack()

func _build_third_person_tool(path: String, node_name: String, _fallback_color: Color, hand_scale := 0.44) -> void:
	_try_add_model_to_parent(third_person_hand_item_root, path, node_name, Vector3(0.0, -0.02, -0.11), Vector3(82, 0, 18), Vector3.ONE * hand_scale)

func _build_third_person_axe() -> void:
	var node := _load_external_node3d(REAL_AXE_MODEL)
	if node == null:
		for fallback_path in [
			"res://assets/external/kenney_survival_kit/Models/GLB format/tool-axe.glb",
			"res://assets/external/realistic/root_glb/axe_survival.glb"
		]:
			node = _load_external_node3d(fallback_path)
			if node != null:
				break
	if node == null:
		return
	node.name = "ThirdPersonAxe"
	# Use same base position as knife which sits in the hand correctly
	node.position = Vector3(0.0, 0.0, 0.0)
	node.rotation_degrees = Vector3(30, 90, 0)
	node.scale = Vector3.ONE * 1.2
	# Offset the mesh children so the handle end is at the node origin
	var meshes: Array = []
	_collect_meshes_recursive(node, meshes)
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		if mesh_inst != null and mesh_inst.mesh != null:
			var aabb := mesh_inst.get_aabb()
			# Shift mesh so handle end (min Z) is at origin
			mesh_inst.position += Vector3(0.0, 0.0, -aabb.position.z)
	third_person_hand_item_root.add_child(node)

func _build_third_person_fishing_rod() -> void:
	if _normal_fishing_rod_pose_ready and _normal_fishing_rod_source != null and is_instance_valid(_normal_fishing_rod_source):
		var animated_rod_copy := _normal_fishing_rod_source.duplicate() as Node3D
		if animated_rod_copy != null:
			animated_rod_copy.name = "ThirdPersonFishingRod"
			animated_rod_copy.transform = _normal_fishing_rod_hand_transform
			animated_rod_copy.visible = true
			third_person_hand_item_root.add_child(animated_rod_copy)
			return
	var node := _load_external_node3d(ROD_MODEL_PATH)
	if node == null:
		return
	node.name = "ThirdPersonFishingRod"
	node.rotation_degrees = Vector3(0, 90, 0)
	node.scale = Vector3.ONE * 1.0
	node.position = Vector3.ZERO
	# The rod is a multi-part model (reel, cork grip, blank, guides, line...).
	# Shifting each mesh individually by its own local AABB (like the axe/knife
	# helpers do for single-piece models) tears the parts apart. Instead compute
	# ONE combined AABB for the whole assembly (in the node's own local space)
	# and rigidly offset the root so the grip end (minimum local X — the cork
	# handle/reel end) sits at the hand socket origin.
	var acc := {"aabb": AABB(), "has": false}
	_collect_rod_local_aabb(node, Transform3D.IDENTITY, acc)
	if acc["has"]:
		var combined: AABB = acc["aabb"]
		var grip_local := Vector3(combined.position.x, combined.position.y + combined.size.y * 0.5, combined.position.z + combined.size.z * 0.5)
		node.position = -(node.transform.basis * grip_local)
	third_person_hand_item_root.add_child(node)

func _collect_rod_local_aabb(node: Node, xform: Transform3D, acc: Dictionary) -> void:
	if node is Node3D:
		xform = xform * (node as Node3D).transform
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_aabb: AABB = (node as MeshInstance3D).mesh.get_aabb()
		var local_aabb: AABB = xform * mesh_aabb
		if not acc["has"]:
			acc["aabb"] = local_aabb
			acc["has"] = true
		else:
			acc["aabb"] = (acc["aabb"] as AABB).merge(local_aabb)
	for c in node.get_children():
		_collect_rod_local_aabb(c, xform, acc)

func _collect_meshes_recursive(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		_collect_meshes_recursive(child, result)

# Pack genérico (caja marrón pequeña) para objetos sin modelo 3P específico
func _build_third_person_pack() -> void:
	_add_held_box(third_person_hand_item_root, "ThirdPersonPack",
		Vector3(0.08, 0.05, 0.12), Vector3(0.0, 0.0, -0.08),
		Color(0.5, 0.35, 0.18), Vector3.ZERO)

func _add_held_box(parent: Node, node_name: String, size: Vector3, pos: Vector3, color: Color, rot: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rot
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_held_cylinder(parent: Node, node_name: String, radius: float, height: float, pos: Vector3, color: Color, rot: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rot
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _add_held_sphere(parent: Node, node_name: String, scale_value: Vector3, pos: Vector3, color: Color, rot: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = pos
	mesh_instance.rotation_degrees = rot
	mesh_instance.scale = scale_value
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance

func _debug_collect_aabb(node: Node, base_xform: Transform3D, out_aabb: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mesh_aabb: AABB = (node as MeshInstance3D).mesh.get_aabb()
		var xform: Transform3D = base_xform * (node as Node3D).transform
		var world_aabb: AABB = xform * mesh_aabb
		if out_aabb.is_empty():
			out_aabb.append(world_aabb)
		else:
			out_aabb[0] = (out_aabb[0] as AABB).merge(world_aabb)
	for child in node.get_children():
		var next_xform := base_xform
		if node is Node3D:
			next_xform = base_xform * (node as Node3D).transform
		_debug_collect_aabb(child, next_xform, out_aabb)

func _try_add_model_to_parent(parent: Node, path: String, node_name: String, pos: Vector3, rot: Vector3, scale_value: Vector3) -> bool:
	if parent == null:
		return false
	var node := _load_external_node3d(path)
	if node == null:
		return false
	node.name = node_name
	if node_name == "ThirdPersonDrinkBottleLeft":
		var aabb_result: Array = []
		_debug_collect_aabb(node, Transform3D.IDENTITY, aabb_result)
		if not aabb_result.is_empty():
			pass
	node.position = pos
	node.rotation_degrees = rot
	node.scale = scale_value
	parent.add_child(node)
	return true

func _apply_view_mode() -> void:
	if third_person_model != null:
		third_person_model.visible = true
	if body_mesh != null:
		body_mesh.visible = third_person_model == null
	if camera != null:
		camera.position = THIRD_PERSON_CAMERA_POS
		_pitch = deg_to_rad(-8.0)
		camera.rotation.x = _pitch
		camera.rotation.z = 0.0
		camera.fov = _camera_fov

func _constrain_camera_to_shelter() -> void:
	var world := get_parent()
	if camera != null and world != null and world.has_method("constrain_shelter_camera"):
		camera.global_position = world.constrain_shelter_camera(global_position, camera.global_position)

func _update_walk_motion(delta: float, movement_amount: float) -> void:
	if camera == null:
		return
	var _debug_cam_active := _frontal_camera or _side_camera or _left_camera or _rear_camera or _top_camera
	var moving := movement_amount > 0.05 and is_on_floor()
	var target_intensity: float = 1.0 if moving else 0.0
	if is_sprinting:
		target_intensity = 1.35
	elif is_crouching:
		target_intensity = 0.55 if moving else 0.0
	_walk_intensity = lerp(_walk_intensity, target_intensity, delta * 8.0)
	if moving:
		var step_speed: float = 11.5 if is_sprinting else (4.4 if is_crouching else 7.2)
		_walk_bob += delta * step_speed
	else:
		_walk_bob = lerp(_walk_bob, 0.0, delta * 4.0)
	var base_height: float = 1.0 if is_crouching else 1.65
	var vertical_bob: float = abs(sin(_walk_bob)) * 0.055 * _walk_intensity
	var side_bob: float = sin(_walk_bob * 0.5) * 0.028 * _walk_intensity
	var roll: float = sin(_walk_bob) * deg_to_rad(0.75) * _walk_intensity
	var target_sink := -0.8 * _water_depth if is_in_water else 0.0
	_water_sink = lerp(_water_sink, target_sink, delta * 5.0)
	var target_position := Vector3(side_bob, base_height + vertical_bob, 0.0)
	var third_height := (1.55 if is_crouching else THIRD_PERSON_CAMERA_POS.y) + vertical_bob * 0.45
	var desired_z := THIRD_PERSON_CAMERA_POS.z

	# Camera collision: throttled to 10/s, caches exclude array
	_cam_collision_timer += delta
	if _cam_collision_timer >= 0.1:
		_cam_collision_timer = 0.0
		var space_state := get_world_3d().direct_space_state
		if space_state != null:
			if _cam_ray_exclude_dirty:
				_cam_ray_exclude = [self.get_rid()]
				_cam_ray_exclude_dirty = false
			var camera_origin := global_position + Vector3(0, third_height, 0)
			var camera_target := camera_origin + global_transform.basis.z * desired_z
			var query := PhysicsRayQueryParameters3D.create(camera_origin, camera_target)
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.exclude = _cam_ray_exclude
			var hit := space_state.intersect_ray(query)
			if not hit.is_empty():
				var hit_point: Vector3 = hit["position"]
				var hit_distance := camera_origin.distance_to(hit_point)
				_cached_cam_z = max(hit_distance - 0.3, 1.0)
			else:
				_cached_cam_z = desired_z
	desired_z = _cached_cam_z if _cached_cam_z > 0.0 else desired_z
	
	target_position = Vector3(side_bob * 0.45, third_height, desired_z)
	target_position.y += _water_sink
	if _is_aiming:
		# First-person eye position looking down the rifle barrel.
		# Height adapts to stance.
		var aim_height: float = 1.65
		if is_crouching:
			aim_height = 1.15
		elif is_prone:
			aim_height = 0.45
		aim_height += vertical_bob * 0.2
		# Slight lateral offset to align with rifle scope (right eye)
		var aim_side: float = 0.12
		# Add breathing lateral sway
		var breath_sway_x: float = 0.0
		var breath_sway_y: float = 0.0
		var fatigue_mult := 1.0
		if stats != null:
			fatigue_mult = 1.0 + (1.0 - clamp(stats.energy / 100.0, 0.0, 1.0)) * 1.5
		var pos_stance_mult := 0.12 if is_prone else (0.28 if (is_crouching or is_sitting) else 1.0)
		var pos_rifle_mult := 1.0 if _held_is_m4() else 0.35
		if not is_moving:
			breath_sway_x = sin(_breath_timer * 0.8) * 0.02 * fatigue_mult * pos_stance_mult * pos_rifle_mult
			breath_sway_y = sin(_breath_timer * 1.2) * 0.015 * fatigue_mult * pos_stance_mult * pos_rifle_mult
			if _breath_hold_active:
				breath_sway_x = 0.0
				breath_sway_y = 0.0
		else:
			# Weapon sway when moving while aiming: more intense bob
			var move_sway: float = 0.02 * _walk_intensity * pos_stance_mult * pos_rifle_mult
			breath_sway_x = sin(_walk_bob * 0.5) * move_sway
			breath_sway_y = abs(sin(_walk_bob)) * move_sway * 0.7
			if not is_on_floor():
				breath_sway_x *= 2.0
				breath_sway_y *= 2.0
		# Position the camera: first-person eye level for scoped rifles,
		# or third-person over-the-shoulder archer view for bows/throwables
		# so the player clearly sees the bow draw animation and arrow.
		if _has_bow_equipped() or _has_throwable_weapon_equipped():
			var bow_cam_z := minf(desired_z, 1.42)
			var base_pivot_y := 1.15 if is_crouching else 1.68
			if is_instance_valid(_hand_skeleton) and _spine_bone_idx >= 0:
				var live_spine_y := (_hand_skeleton.global_transform * _hand_skeleton.get_bone_global_pose(_spine_bone_idx).origin).y - global_position.y
				if is_finite(live_spine_y) and live_spine_y > 0.4:
					base_pivot_y = clampf(live_spine_y, 0.75, 1.85)
			var pivot_y := base_pivot_y + breath_sway_y + _water_sink
			var shoulder_pivot := Vector3(0.46 + breath_sway_x, pivot_y, 0.0)
			var orbit_pitch := clampf(_pitch, deg_to_rad(-65.0), deg_to_rad(65.0))
			var boom_offset := Vector3(0.0, 0.48, bow_cam_z).rotated(Vector3.RIGHT, orbit_pitch)
			target_position = shoulder_pivot + boom_offset
			target_position.y = maxf(target_position.y, 0.28 + _water_sink)
		else:
			target_position = Vector3(aim_side + breath_sway_x, aim_height + breath_sway_y + _water_sink, 0.15)
		if not _debug_cam_active:
			camera.position = camera.position.lerp(target_position, delta * 18.0)
			# Use _pitch for vertical aim control (mouse up/down)
			# Breath sway adds small offsets to pitch only (yaw handled by body rotation)
			camera.rotation.x = _pitch + _recoil_pitch + _breath_pitch_offset
			# Small lateral sway via rotation.y (offset from body, not absolute)
			camera.rotation.y = _breath_yaw_offset * 0.5
	else:
		if not _debug_cam_active:
			camera.position = camera.position.lerp(target_position, delta * 10.0)
			camera.rotation.x = _pitch + _recoil_pitch + _breath_pitch_offset
	if not _debug_cam_active:
		camera.rotation.z = lerp_angle(camera.rotation.z, roll, delta * 8.0)
	if not _debug_cam_active:
		_constrain_camera_to_shelter()
	_update_third_person_animation(moving, delta)

#endregion


#region ANIMACIÓN TERCERA PERSONA (PlayerAnimation)
func _compute_skeleton_ground_target_y(bob: float = 0.0) -> float:
	var target_y := third_person_ground_offset + bob + _water_sink
	if third_person_model == null:
		return target_y
	if _anim_skel_dirty or _anim_skel_cache == null or not is_instance_valid(_anim_skel_cache):
		_anim_skel_cache = _find_skeleton(third_person_model)
		_anim_skel_dirty = false
	var skel := _anim_skel_cache
	if skel == null:
		return target_y
	var cur_anim: String = third_person_animation_player.current_animation if third_person_animation_player != null else ""
	_restore_aim_pitch_pose(skel)
	skel.force_update_all_bone_transforms()
	_prev_anim_name = cur_anim
	_bone_update_pending = false
	var sitting_or_sleeping_clip := (not cur_anim.is_empty() and (cur_anim == third_person_sit_animation or cur_anim == third_person_sleep_animation))
	if ((is_prone or is_sitting or is_sleeping) and third_person_action_timer <= 0.0 and not is_crouching) or sitting_or_sleeping_clip:
		# Align by hip/pelvis bone — feet are off ground when sitting/sleeping/prone
		var hip_model_y := 0.0
		var found_hip := false
		for i in range(skel.get_bone_count()):
			var bn := skel.get_bone_name(i)
			if bn.find("Hips") >= 0 or bn.find("Pelvis") >= 0 or bn.find("Spine") >= 0:
				var bone_world := skel.global_transform * skel.get_bone_global_pose(i).origin
				hip_model_y = bone_world.y - third_person_model.global_position.y
				found_hip = true
				break
		if found_hip:
			var has_rifle := _has_rifle_equipped()
			var sit_pose := is_sitting or (not cur_anim.is_empty() and cur_anim == third_person_sit_animation)
			var target_hip_ground_y := (0.85 if has_rifle else 0.25) if sit_pose else (0.2 if has_rifle else 0.15)
			target_y = target_hip_ground_y - hip_model_y + _water_sink
	else:
		# Standing, crouching, walking, eating (plant), foraging (gather), drinking, etc.: align by lowest foot/toe
		var min_foot_model_y := 1000000.0
		for i in range(skel.get_bone_count()):
			var bn := skel.get_bone_name(i)
			if bn.find("Foot") >= 0 or bn.find("Toe") >= 0:
				var bone_world := skel.global_transform * skel.get_bone_global_pose(i).origin
				var foot_offset_y := bone_world.y - third_person_model.global_position.y
				if foot_offset_y < min_foot_model_y:
					min_foot_model_y = foot_offset_y
		if min_foot_model_y < 999999.0:
			target_y = 0.025 - min_foot_model_y + bob + _water_sink
	return target_y

func _update_puppet_ground_alignment(delta: float) -> void:
	if is_instance_valid(rowing_boat) and not bool(rowing_boat.get("occupant_standing")):
		return
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	var target_y := _compute_skeleton_ground_target_y(0.0)
	character.position = character.position.lerp(Vector3(0.0, target_y, 0.0), minf(1.0, delta * 14.0))

func _update_third_person_animation(moving: bool, delta: float) -> void:
	var climbing_stairs := _update_stair_motion(moving, delta)
	if is_instance_valid(rowing_boat) and not _boat_standing:
		return
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	# Defensive guard: if a one-shot fishing animation is playing without an
	# active action timer, stop it immediately and clear the action state.
	# This prevents the fish start/end/cast animation from ever looping or
	# playing automatically at game start.
	if third_person_animation_player != null and third_person_action_timer <= 0.0:
		var cur := third_person_animation_player.current_animation
		if cur == _rod_fish_start_animation or cur == _rod_fish_end_animation or cur == _rod_cast_animation:
			third_person_animation_player.stop()
			third_person_animation_player.speed_scale = 1.0
			_rod_action_speed_scale = 1.0
			third_person_action_animation = ""
			third_person_action_start_offset = 0.0
			_rod_socket_active = false
	var base_rotation := Vector3(0.0, 180.0, 0.0) if character == third_person_model else Vector3.ZERO
	var bob: float = abs(sin(_walk_bob)) * (0.02 if _is_aiming else 0.08) * _walk_intensity if moving else 0.0
	var sway: float = sin(_walk_bob) * (0.6 if _is_aiming else 4.5) * _walk_intensity if moving else 0.0
	var target_y := _compute_skeleton_ground_target_y(bob)
	character.position = character.position.lerp(Vector3(0.0, target_y, 0.0), delta * 10.0)
	character.rotation_degrees = character.rotation_degrees.lerp(base_rotation + Vector3(0.0, 0.0, sway), delta * 9.0)
	if third_person_animation_player != null:
		if is_jumping and not third_person_jump_animation.is_empty():
			_jump_animation_timer = max(0.0, _jump_animation_timer - delta)
			if third_person_animation_player.current_animation != third_person_jump_animation:
				third_person_animation_player.play(third_person_jump_animation, 0.1)
			third_person_animation_player.speed_scale = 1.0
			return
		if _is_falling_from_height and not is_jumping and not third_person_jump_down_animation.is_empty():
			var fall_dist := _max_fall_height - global_position.y
			if fall_dist > 0.2:
				if third_person_animation_player.current_animation != third_person_jump_down_animation:
					third_person_animation_player.play(third_person_jump_down_animation, 0.1)
				third_person_animation_player.speed_scale = 1.0
				return
		var throw_aim_walking := (_throw_aim_hold or _throw_charging or (_has_throwable_weapon_equipped() and _is_aiming)) and moving and not _bow_aim_walk_animation.is_empty()
		if third_person_action_timer > 0.0 and not third_person_action_animation.is_empty() and not throw_aim_walking:
			third_person_action_timer = max(0.0, third_person_action_timer - delta)
			if third_person_animation_player.current_animation != third_person_action_animation:
				third_person_animation_player.play(third_person_action_animation, 0.08)
				if _throw_aim_hold and _throw_aim_frozen:
					third_person_animation_player.seek(THROW_ANIM_FREEZE_TIME, true)
				elif third_person_action_start_offset > 0.0:
					third_person_animation_player.seek(third_person_action_start_offset, true)
			if third_person_action_animation == _rod_fish_start_animation or third_person_action_animation == _rod_fish_end_animation or third_person_action_animation == _rod_cast_animation:
				third_person_animation_player.speed_scale = _rod_action_speed_scale
			elif _throw_aim_hold and _throw_aim_frozen:
				third_person_animation_player.speed_scale = 0.0
			elif _throw_charging:
				# Lanzamiento cargado: 1.0 los primeros 0.4s, luego congelar
				if _throw_charge_time < THROW_ANIM_FREEZE_TIME:
					third_person_animation_player.speed_scale = 1.0
				else:
					third_person_animation_player.speed_scale = 0.0
			else:
				third_person_animation_player.speed_scale = 1.0
			return
		elif third_person_action_timer <= 0.0:
			if _is_fishing and _has_fishing_rod and not _rod_idle_animation.is_empty():
				_is_fishing_idle = true
			_rod_socket_active = false
			_rod_action_speed_scale = 1.0
			third_person_action_animation = ""
			third_person_action_start_offset = 0.0
			_is_firing = false
		if is_prone and third_person_action_timer <= 0.0:
			var prone_anim := _rifle_prone_animation
			if _has_rifle_equipped() and not _rifle_prone_animation.is_empty():
				prone_anim = _rifle_prone_animation
			elif _has_rifle_equipped() and not _rifle_aim_idle_animation.is_empty():
				prone_anim = _rifle_aim_idle_animation
			if not prone_anim.is_empty():
				if third_person_animation_player.current_animation != prone_anim:
					third_person_animation_player.play(prone_anim, 0.1)
				third_person_animation_player.speed_scale = 1.0
				return
		if is_sitting and third_person_action_timer <= 0.0:
			var sit_anim := third_person_sit_animation
			if _has_rifle_equipped():
				if not _rifle_sit_animation.is_empty():
					sit_anim = _rifle_sit_animation
				elif not _rifle_aim_idle_animation.is_empty():
					sit_anim = _rifle_aim_idle_animation
			if not sit_anim.is_empty():
				if third_person_animation_player.current_animation != sit_anim:
					third_person_animation_player.play(sit_anim, 0.1)
				third_person_animation_player.speed_scale = 1.0
				return
		var target_animation := ""
		var low_health: bool = stats != null and stats.health <= 30.0 and not third_person_low_health_animation.is_empty()
		# Update rifle equipped state: _rifle_in_hands is set by _sync_third_person_equipment
		_has_rifle = _rifle_in_hands
		# Torch locomotion: use torch-specific animations when holding torch
		if _torch_in_hands and not _has_rifle and not is_sitting and not is_prone:
			if moving:
				if is_sprinting and not _torch_run_animation.is_empty():
					target_animation = _torch_run_animation
				elif is_crouching:
					if not _torch_crouch_walk_animation.is_empty():
						target_animation = _torch_crouch_walk_animation
					elif not _torch_walk_animation.is_empty():
						target_animation = _torch_walk_animation
					else:
						target_animation = third_person_walk_animation
				elif not _torch_walk_animation.is_empty():
					target_animation = _torch_walk_animation
				else:
					target_animation = third_person_walk_animation
			elif _turn_input < -2.0:
				if is_crouching and not _torch_crouch_turn_left_animation.is_empty():
					target_animation = _torch_crouch_turn_left_animation
				elif not _torch_turn_left_animation.is_empty():
					target_animation = _torch_turn_left_animation
			elif _turn_input > 2.0:
				if is_crouching and not _torch_crouch_turn_right_animation.is_empty():
					target_animation = _torch_crouch_turn_right_animation
				elif not _torch_turn_right_animation.is_empty():
					target_animation = _torch_turn_right_animation
			elif is_crouching:
				if not _torch_crouch_idle_animation.is_empty():
					target_animation = _torch_crouch_idle_animation
				elif not _torch_idle_animation.is_empty():
					target_animation = _torch_idle_animation
			elif not _torch_idle_animation.is_empty():
				target_animation = _torch_idle_animation
			if not target_animation.is_empty():
				if third_person_animation_player.current_animation != target_animation:
					third_person_animation_player.play(target_animation, 0.15)
				elif not third_person_animation_player.is_playing():
					third_person_animation_player.play(target_animation, 0.15)
				third_person_animation_player.speed_scale = 1.0 if is_sprinting else (0.55 if is_crouching else 1.0)
				_turn_input = lerp(_turn_input, 0.0, delta * 7.0)
				return
		# Fishing rod locomotion: use rod-specific animations when holding fishing rod
		if _has_fishing_rod and not _has_rifle and not is_sitting and not is_prone:
			if moving:
				_is_fishing_idle = false
			if _is_fishing_idle and not _rod_idle_animation.is_empty():
				target_animation = _rod_idle_animation
			elif moving and not _rod_walk_animation.is_empty():
				target_animation = _rod_walk_animation
			if not target_animation.is_empty():
				if third_person_animation_player.current_animation != target_animation:
					third_person_animation_player.play(target_animation, 0.15)
				elif not third_person_animation_player.is_playing():
					third_person_animation_player.play(target_animation, 0.15)
				third_person_animation_player.speed_scale = 1.0
				_turn_input = lerp(_turn_input, 0.0, delta * 7.0)
				return
			# No rod-specific animation available — fall through to normal locomotion
		if _has_rifle and not _is_aiming and not is_sprinting:
			# Rifle locomotion: use rifle-specific animations
			if moving:
				if is_crouching and not third_person_sneak_walk_animation.is_empty():
					target_animation = third_person_sneak_walk_animation
				elif is_crouching:
					target_animation = third_person_sneak_animation
				elif not _rifle_walk_animation.is_empty():
					target_animation = _rifle_walk_animation
				else:
					target_animation = third_person_walk_animation
			elif is_crouching and not third_person_sneak_animation.is_empty():
				target_animation = third_person_sneak_animation
			elif is_crouching and not _rifle_sit_animation.is_empty():
				target_animation = _rifle_sit_animation
			elif _turn_input < -2.0 and not _rifle_left_turn_animation.is_empty():
				target_animation = _rifle_left_turn_animation
			elif _turn_input > 2.0 and not _rifle_right_turn_animation.is_empty():
				target_animation = _rifle_right_turn_animation
			elif not _rifle_idle_animation.is_empty():
				target_animation = _rifle_idle_animation
			elif third_person_has_real_idle:
				target_animation = third_person_idle_animation
		elif _has_rifle and _is_aiming:
			# Aiming with rifle: use aim idle when stationary, walk when moving
			if moving:
				if not _rifle_walk_animation.is_empty():
					target_animation = _rifle_walk_animation
				else:
					target_animation = third_person_walk_animation
			elif _turn_input < -2.0 and not _rifle_left_turn_animation.is_empty():
				target_animation = _rifle_left_turn_animation
			elif _turn_input > 2.0 and not _rifle_right_turn_animation.is_empty():
				target_animation = _rifle_right_turn_animation
			elif not _rifle_aim_idle_animation.is_empty():
				target_animation = _rifle_aim_idle_animation
			elif not _rifle_idle_animation.is_empty():
				target_animation = _rifle_idle_animation
			elif third_person_has_real_idle:
				target_animation = third_person_idle_animation
		elif (_has_bow_equipped() or _has_throwable_weapon_equipped()) and (_is_aiming or _throw_charging) and not _bow_aim_idle_animation.is_empty():
			if moving and not _bow_aim_walk_animation.is_empty():
				target_animation = _bow_aim_walk_animation
			else:
				target_animation = _bow_aim_idle_animation
		elif moving:
			if low_health:
				target_animation = third_person_low_health_animation
			elif is_sprinting:
				if _has_rifle and not _rifle_run_animation.is_empty():
					target_animation = _rifle_run_animation
				else:
					target_animation = third_person_run_animation
			elif is_crouching and not third_person_sneak_walk_animation.is_empty():
				target_animation = third_person_sneak_walk_animation
			elif is_crouching:
				target_animation = third_person_sneak_animation
			else:
				target_animation = third_person_walk_animation
		elif _turn_input < -2.0 and not third_person_left_turn_animation.is_empty():
			if _is_aiming and not _rifle_left_turn_animation.is_empty():
				target_animation = _rifle_left_turn_animation
			else:
				target_animation = third_person_left_turn_animation
		elif _turn_input > 2.0 and not third_person_right_turn_animation.is_empty():
			if _is_aiming and not _rifle_right_turn_animation.is_empty():
				target_animation = _rifle_right_turn_animation
			else:
				target_animation = third_person_right_turn_animation
		elif is_crouching and not third_person_sneak_animation.is_empty():
			target_animation = third_person_sneak_animation
		elif is_crouching and _has_rifle and not _rifle_idle_animation.is_empty():
			target_animation = _rifle_idle_animation
		elif low_health:
			target_animation = third_person_low_health_animation
		elif third_person_has_real_idle:
			target_animation = third_person_idle_animation
		else:
			if third_person_animation_player.is_playing():
				third_person_animation_player.stop()
				if not third_person_walk_animation.is_empty():
					third_person_animation_player.play(third_person_walk_animation)
					third_person_animation_player.seek(0.0, true)
					third_person_animation_player.stop()
			return
		if climbing_stairs and not third_person_stairs_animation.is_empty() and not _has_rifle and not _torch_in_hands and not _has_fishing_rod:
			target_animation = third_person_stairs_animation
		if _has_rifle and target_animation != _last_rifle_animation_debug:
			_last_rifle_animation_debug = target_animation
		if not target_animation.is_empty() and third_person_animation_player.current_animation != target_animation:
			third_person_animation_player.play(target_animation, 0.15)
		elif not target_animation.is_empty() and not third_person_animation_player.is_playing():
			third_person_animation_player.play(target_animation, 0.15)
		_loop_third_person_animation(target_animation)
		if target_animation == third_person_low_health_animation:
			third_person_animation_player.speed_scale = 0.78 if moving else 0.58
		else:
			third_person_animation_player.speed_scale = 1.0 if is_sprinting else (0.55 if is_crouching else 1.0)
		_turn_input = lerp(_turn_input, 0.0, delta * 7.0)
		return
	var limb_swing: float = sin(_walk_bob) * 32.0 * _walk_intensity if moving else 0.0
	if third_person_left_arm != null:
		third_person_left_arm.rotation_degrees = third_person_left_arm.rotation_degrees.lerp(Vector3(limb_swing, 0.0, -7.0), delta * 12.0)
	if third_person_right_arm != null:
		third_person_right_arm.rotation_degrees = third_person_right_arm.rotation_degrees.lerp(Vector3(-limb_swing, 0.0, 7.0), delta * 12.0)
	if third_person_left_leg != null:
		third_person_left_leg.rotation_degrees = third_person_left_leg.rotation_degrees.lerp(Vector3(-limb_swing * 0.85, 0.0, 0.0), delta * 12.0)
	if third_person_right_leg != null:
		third_person_right_leg.rotation_degrees = third_person_right_leg.rotation_degrees.lerp(Vector3(limb_swing * 0.85, 0.0, 0.0), delta * 12.0)

func _loop_third_person_animation(animation_name: String) -> void:
	if third_person_animation_player == null or animation_name.is_empty():
		return
	# Never auto-restart one-shot action animations (fish start/end, cast)
	if animation_name == _rod_fish_start_animation or animation_name == _rod_fish_end_animation or animation_name == _rod_cast_animation:
		return
	var animation := third_person_animation_player.get_animation(animation_name)
	if animation == null:
		return
	if animation.loop_mode != Animation.LOOP_NONE:
		return
	var length := animation.length
	if length > 0.0 and third_person_animation_player.current_animation_position >= length - 0.05:
		third_person_animation_player.play(animation_name, 0.25)

func _nearby_rowboat() -> Node3D:
	var main := get_tree().current_scene
	if main == null or is_dead or is_sleeping:
		return null
	var boat = main.get("lake_rowboat")
	if is_instance_valid(boat) and boat.can_board_from(global_position):
		return boat
	return null

func _load_rowing_animation() -> void:
	if third_person_animation_player == null or third_person_animation_player.has_animation(_rowing_animation):
		return
	var source: Node = preload("res://assets/animations/rowing.glb").instantiate()
	var source_player := _find_animation_player(source)
	var source_skeleton := _find_skeleton(source)
	var target_skeleton := _find_skeleton(third_person_model)
	if source_player != null and source_skeleton != null and target_skeleton != null:
		var animation: Animation = source_player.get_animation("Animation").duplicate(true)
		for i in range(animation.get_track_count() - 1, -1, -1):
			var bone := _extract_mixamo_bone_name(str(animation.track_get_path(i)))
			if bone.is_empty() or (animation.track_get_type(i) != Animation.TYPE_ROTATION_3D and not bone.ends_with("Hips")):
				animation.remove_track(i)
		_retarget_rotation_tracks_with_source(animation, target_skeleton, source_skeleton)
		_retarget_animation_to_character_skeleton(animation)
		animation.length = 2.0
		animation.loop_mode = Animation.LOOP_LINEAR
		var library := AnimationLibrary.new()
		library.add_animation("Stroke", animation)
		third_person_animation_player.add_animation_library("rowing", library)
	source.free()

func _boat_movement_input() -> Vector2:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or get_tree().paused or _is_fishing or _consumption_pending:
		return Vector2.ZERO
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var relative := Vector3(input.x, 0, input.y).rotated(Vector3.UP, _rowing_view_yaw)
	return Vector2(relative.x, relative.z)

func prepare_to_row() -> bool:
	if is_dead or _consumption_pending or _interact_busy:
		return false
	if get_held_item() != null:
		_store_held_item()
		if get_held_item() != null:
			notice.emit("Necesitas las manos libres para sentarte a remar.")
			return false
	return true

func _cancel_boat_actions() -> void:
	_is_fishing = false
	_is_fishing_idle = false
	_fishing_session += 1
	_deactivate_rod_visual_overlay()
	third_person_action_animation = ""
	third_person_action_timer = 0.0
	_f_holding = false
	_g_holding = false
	_throw_charging = false
	if not is_puppet:
		if _is_aiming:
			_toggle_aim()
		var main := get_tree().current_scene
		if main != null and main.get("hud") != null and main.hud.has_method("hide_countdown"):
			main.hud.hide_countdown()

func begin_rowing(boat: Node3D) -> void:
	if is_instance_valid(rowing_boat) or is_dead or third_person_model == null:
		return
	_load_rowing_animation()
	rowing_boat = boat
	_rowing_model_transform = third_person_model.transform
	if camera != null:
		_rowing_camera_transform = camera.transform
	_rowing_view_yaw = PI
	_rowing_view_height = 3.5
	_rowing_view_dist = 7.0
	_boat_standing = false
	_boat_local_offset = Vector2.ZERO
	is_sleeping = false
	is_sitting = false
	is_prone = false
	is_crouching = false
	is_jumping = false
	_is_falling_from_height = false
	_is_fishing = false
	_is_fishing_idle = false
	_fishing_session += 1
	_deactivate_rod_visual_overlay()
	third_person_action_animation = ""
	third_person_action_timer = 0.0
	if not is_puppet:
		if _is_aiming:
			_toggle_aim()
		if get_held_item() != null:
			_store_held_item()
		_f_holding = false
		_g_holding = false
		_throw_charging = false
		var main := get_tree().current_scene
		if main != null and main.get("hud") != null:
			main.hud.hide_countdown()
	_update_crouch_collision()
	third_person_model.position = Vector3.ZERO
	third_person_model.rotation = Vector3(0, PI, 0)
	third_person_model.visible = true
	velocity = Vector3.ZERO
	var rowing_skeleton := _find_skeleton(third_person_model)
	if rowing_skeleton != null:
		rowing_skeleton.reset_bone_poses()
	if third_person_animation_player != null and third_person_animation_player.has_animation(_rowing_animation):
		third_person_animation_player.play(_rowing_animation)
		third_person_animation_player.pause()

func update_rowing_pose(time: float) -> void:
	if not is_instance_valid(rowing_boat):
		return
	var standing := bool(rowing_boat.get("occupant_standing"))
	if standing != _boat_standing:
		_set_boat_standing(standing)
	if not standing and third_person_animation_player != null and third_person_animation_player.has_animation(_rowing_animation):
		third_person_animation_player.seek(time, true)
	_update_backpack_socket()
	_update_hand_socket()
	_update_head_worn_items()
	if camera != null and not is_puppet:
		var desired := rowing_boat.to_global(Vector3(sin(_rowing_view_yaw) * _rowing_view_dist, _rowing_view_height, cos(_rowing_view_yaw) * _rowing_view_dist))
		var pivot := global_position + Vector3.UP * (1.45 if _boat_standing else 0.9)
		var query := PhysicsRayQueryParameters3D.create(pivot, desired, 1)
		query.exclude = [get_rid(), rowing_boat.get_rid()]
		var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
		camera.global_position = desired if obstruction.is_empty() else obstruction.position + obstruction.normal * 0.2
		if _boat_standing:
			var fwd := rowing_boat.global_basis * Vector3(-sin(_rowing_view_yaw), 0.0, -cos(_rowing_view_yaw))
			camera.look_at(pivot + fwd * 6.0)
		else:
			camera.look_at(pivot)

func _set_boat_standing(standing: bool) -> void:
	_boat_standing = standing
	if standing:
		_boat_local_offset = Vector2.ZERO
		if third_person_model != null:
			third_person_model.transform = _rowing_model_transform
		if third_person_animation_player != null and not third_person_idle_animation.is_empty():
			third_person_animation_player.play(third_person_idle_animation, 0.15)
	else:
		if not is_puppet:
			if _is_aiming:
				_toggle_aim()
			_is_fishing = false
			_is_fishing_idle = false
			_fishing_session += 1
			_deactivate_rod_visual_overlay()
			third_person_action_animation = ""
			third_person_action_timer = 0.0
			var main := get_tree().current_scene
			if main != null and main.get("hud") != null and main.hud.has_method("hide_countdown"):
				main.hud.hide_countdown()
			notice.emit("")
			if get_held_item() != null:
				_store_held_item()
		if third_person_model != null:
			third_person_model.position = Vector3.ZERO
			third_person_model.rotation = Vector3(0, PI, 0)
		if third_person_animation_player != null and third_person_animation_player.has_animation(_rowing_animation):
			third_person_animation_player.play(_rowing_animation)
			third_person_animation_player.pause()

func end_rowing(pos: Vector3) -> void:
	_cancel_boat_actions()
	rowing_boat = null
	_boat_standing = false
	is_rowing = false
	_boat_prompt_shown = ""
	_boat_prompt_timer = 0.0
	_boat_local_offset = Vector2.ZERO
	global_position = pos
	velocity = Vector3.ZERO
	_water_query_timer = 0.25
	is_in_water = false
	_water_depth = 0.0
	_water_sink = 0.0
	_is_falling_from_height = false
	_fall_height = 0.0
	_max_fall_height = 0.0
	if third_person_model != null:
		third_person_model.transform = _rowing_model_transform
	if camera != null:
		camera.transform = _rowing_camera_transform
	if third_person_model != null:
		var rowing_skeleton := _find_skeleton(third_person_model)
		if rowing_skeleton != null:
			rowing_skeleton.reset_bone_poses()
	if third_person_animation_player != null:
		third_person_animation_player.speed_scale = 1.0
		if not is_dead:
			third_person_animation_player.play(third_person_idle_animation, 0.15)
	if not is_puppet:
		prompt_changed.emit("")

func _get_current_anim() -> String:
	if is_dead:
		return "dead_melee" if _beaten_death else "dead"
	if third_person_animation_player != null:
		return third_person_animation_player.current_animation
	return "idle"

func _interact() -> void:
	if _interact_busy:
		return
	var boat_target := _nearby_rowboat()
	if boat_target != null:
		boat_target.interact(self)
		return
	var feed_target := _find_nearby_feedable_player()
	if feed_target != null:
		_give_food_or_drink_to_player(feed_target)
		return
	if _has_fishing_rod_in_hand() and not _is_fishing:
		var fishing_state := _get_fishing_water_state()
		if bool(fishing_state.get("near", false)):
			if bool(fishing_state.get("facing", false)):
				_start_fishing_near_water()
			else:
				notice.emit("Mira hacia el agua para poder pescar.")
			return
	var target = _get_interaction_target()
	if target == null:
		notice.emit("No hay nada al alcance.")
		return
	if camera != null:
		var tw := create_tween()
		tw.tween_property(camera, "fov", 72.0, 0.12).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(camera, "fov", 75.0, 0.18).set_ease(Tween.EASE_IN_OUT)
	target.interact(self)

func _start_fishing_near_water() -> void:
	if not _has_fishing_rod_in_hand():
		notice.emit("Necesitas una caña de pescar en la mano.")
		return
	if _is_fishing:
		return
	# Load rod animations on demand (only when actually fishing)
	_load_rod_animations()
	var fishing_state := _get_fishing_water_state()
	if not bool(fishing_state.get("near", false)):
		_can_fish_near_water = false
		notice.emit("Acércate a la orilla de un lago o río para pescar.")
		return
	if not bool(fishing_state.get("facing", false)):
		_can_fish_near_water = false
		notice.emit("Mira hacia el agua para poder pescar.")
		return
	var held = get_held_item()
	if held == null or str(held.item_type) != "tool_fishing":
		notice.emit("Necesitas una caña de pescar en la mano.")
		return
	if held.has_method("is_broken") and held.is_broken():
		notice.emit("Tu caña de pescar esta rota y no se puede usar.")
		return
	var main := get_tree().current_scene
	if main == null:
		return
	_is_fishing = true
	_fishing_session += 1
	var session := _fishing_session
	var fishing_origin := global_position
	var fish_start_anim := _rod_fish_start_animation
	var fish_start_duration := 2.0
	if not fish_start_anim.is_empty():
		play_action_animation("fish", fish_start_duration)
	elif not _rod_cast_animation.is_empty():
		fish_start_duration = 1.6
		play_action_animation("fish", fish_start_duration)
	notice.emit("Lanzas el hilo...")
	if main.get("hud") != null and main.hud.has_method("show_countdown"):
		main.hud.show_countdown("Lanzando", fish_start_duration)
	await get_tree().create_timer(fish_start_duration).timeout
	if session != _fishing_session:
		return
	if not _fishing_attempt_valid(session, held, fishing_origin):
		_is_fishing = false
		return

	# Continue with the authored fishing idle, including its rod and line, for
	# the full waiting period before deciding whether a fish bites.
	_is_fishing_idle = true
	third_person_action_timer = 0.0
	third_person_action_animation = ""
	if not _rod_idle_animation.is_empty():
		third_person_animation_player.play(_rod_idle_animation, 0.08)
		third_person_animation_player.speed_scale = 1.0
		_activate_rod_visual_overlay(THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION)
	if main.get("hud") != null and main.hud.has_method("show_countdown"):
		main.hud.show_countdown("Pescando", FISHING_IDLE_DURATION)
	await get_tree().create_timer(FISHING_IDLE_DURATION).timeout
	if session != _fishing_session:
		return
	if not _fishing_attempt_valid(session, held, fishing_origin):
		_is_fishing = false
		_is_fishing_idle = false
		_deactivate_rod_visual_overlay()
		return

	var caught_fish := randf() < 0.72
	_is_fishing_idle = false
	if caught_fish and not _rod_fish_end_animation.is_empty():
		var end_animation := third_person_animation_player.get_animation(_rod_fish_end_animation)
		var end_duration := end_animation.length if end_animation != null else 4.04
		play_action_animation("fish_end", end_duration)
		if main.get("hud") != null and main.hud.has_method("show_countdown"):
			main.hud.show_countdown("Recogiendo", end_duration)
		await get_tree().create_timer(end_duration).timeout
	if session != _fishing_session:
		return
	if not _fishing_attempt_valid(session, held, fishing_origin):
		_is_fishing = false
		_is_fishing_idle = false
		_deactivate_rod_visual_overlay()
		return
	if caught_fish:
		var on_boat := is_instance_valid(rowing_boat)
		var stored := false
		if on_boat and inventory != null:
			# En la barca el pez va directo al inventario; sin hueco cae en cubierta.
			stored = inventory.add_item(ItemScript.create("Pez crudo", "food", 0.55, 1, 24.0))
		if stored:
			notice.emit("Pescas un pez.")
		else:
			# Drop the fish on the ground instead of adding to inventory
			var drop_pos := global_position + (-global_basis.z * (0.6 if on_boat else 0.8))
			drop_pos.y = global_position.y + 0.05 if on_boat else 0.1
			item_dropped.emit("Pez crudo", "food", 0.55, 1, 24.0, drop_pos, Color(0, 0, 0, 0), false, 0.0)
			notice.emit("Pescas un pez. Lo dejas en la barca." if on_boat else "Pescas un pez. Lo has dejado en el suelo.")
	else:
		notice.emit("No pica nada.")
	if held != null and held.has_method("reduce_durability"):
		held.reduce_durability(3.0)
		if held.is_broken():
			notice.emit("Tu caña de pescar se ha roto!")
	_is_fishing = false
	_is_fishing_idle = false
	_deactivate_rod_visual_overlay()
	# Return to normal animation (same as when canceling fishing)
	third_person_action_animation = ""
	third_person_action_timer = 0.0
	if third_person_animation_player != null and not third_person_idle_animation.is_empty():
		third_person_animation_player.play(third_person_idle_animation, 0.3)
		third_person_animation_player.speed_scale = 1.0
	# Store the fishing rod back into inventory after fishing ends
	_store_held_item()

func get_interaction_text(_player = null) -> String:
	return ""

func interact(_player: Node) -> void:
	pass

func _collect() -> void:
	var target = _get_interaction_target()
	if target == null:
		return
	if target.has_method("collect"):
		target.collect(self)

# El boton derecho ejecuta la accion que el aviso anuncia primero
# ([F]/[C]/[M]/[K]) por las mismas rutas que sus teclas. Devuelve false si el
# aviso esta vacio para que el boton siga apuntando o usando el objeto en mano.
func _right_click_interact(target) -> bool:
	var prompt := ""
	if raycast != null and raycast.has_method("get_default_text"):
		prompt = str(raycast.get_default_text(target, self))
	elif target != null and target.has_method("get_interaction_text"):
		prompt = str(target.call("get_interaction_text", self))
	if prompt.is_empty():
		return false
	var best_pos := -1
	var best_tag := ""
	for tag in ["[F]", "[C]", "[M]", "[N]", "[K]"]:
		var tag_pos := prompt.find(tag)
		if tag_pos >= 0 and (best_pos < 0 or tag_pos < best_pos):
			best_pos = tag_pos
			best_tag = tag
	match best_tag:
		"[C]":
			# Misma prioridad que la tecla C: una mochila abierta vuelve a
			# abrirse, el resto se recoge.
			if target != null and target.has_method("interact") and "is_open" in target and target.is_open:
				target.interact(self)
			else:
				_collect()
		"[M]":
			_eat_action()
		"[N]":
			_light_action()
		"[K]":
			_open_pointed_container(target)
		_:
			# "[F]" o un aviso sin teclas: equivale a pulsar F.
			_interact()
	return true

func _open_pointed_container(target) -> void:
	var main := get_tree().current_scene
	if main == null:
		return
	var is_shelter_target: bool = str(target.get("action_type", "")) == "shelter"
	var is_container: bool = main.has_method("_is_backpack_container") and main._is_backpack_container(target)
	if (is_container or is_shelter_target) and main.has_method("_toggle_backpack_ui"):
		main._toggle_backpack_ui(target)
	else:
		_interact()

#endregion


#region INTERACCIÓN Y UI
func _update_interaction_prompt() -> void:
	if is_instance_valid(rowing_boat):
		# El aviso del bote se muestra unos segundos y luego se oculta solo;
		# reaparece cuando cambia el estado (entrar, sentarse, poder salir...).
		var boat_text: String = rowing_boat.passenger_prompt()
		if boat_text != _boat_prompt_shown:
			_boat_prompt_shown = boat_text
			_boat_prompt_timer = BOAT_PROMPT_SECONDS
		prompt_changed.emit(boat_text if _boat_prompt_timer > 0.0 else "")
		return
	var boat_target := _nearby_rowboat()
	if boat_target != null:
		prompt_changed.emit(boat_target.get_interaction_text(self))
		return
	if is_sleeping:
		prompt_changed.emit("")
		return
	# Check if player can fish near water with rod in hand
	if _has_fishing_rod_in_hand():
		var fishing_state := _get_fishing_water_state()
		_is_near_fishing_shore = bool(fishing_state.get("near", false))
		_can_fish_near_water = _is_near_fishing_shore and bool(fishing_state.get("facing", false))
		if _can_fish_near_water:
			prompt_changed.emit("Pescar - [F]")
			return
		if _is_near_fishing_shore:
			prompt_changed.emit("Mira hacia el agua para pescar")
			return
	_can_fish_near_water = false
	_is_near_fishing_shore = false
	# Cooperativo: si llevas comida o bebida en la mano y miras de cerca a otro
	# jugador vivo, mostrar el aviso para darle de comer o de beber con [F].
	var feed_peer := _find_nearby_feedable_player()
	if feed_peer != null:
		var held_f = get_held_item()
		var peer_label := _get_remote_player_display_name(feed_peer)
		var action_verb := "Dar de beber" if str(held_f.item_type) == "water" else "Dar de comer"
		prompt_changed.emit("%s (%s) a %s - [F]" % [action_verb, str(held_f.item_name), peer_label])
		return
	# Primero: acciones del mundo (WorldAction) apuntadas con la mirada
	var target = _get_interaction_target()
	if target != null:
		if raycast != null and raycast.has_method("get_default_text"):
			prompt_changed.emit(raycast.get_default_text(target, self))
		elif target.has_method("get_interaction_text"):
			prompt_changed.emit(target.call("get_interaction_text", self))
		else:
			prompt_changed.emit("Pulsa F para interactuar")
		return
	prompt_changed.emit("")

func _find_nearby_feedable_player() -> Node3D:
	if is_dead or _consumption_pending or _interact_busy:
		return null
	var held = get_held_item()
	if held == null:
		return null
	var itype := str(held.item_type)
	if itype != "food" and itype != "water":
		return null
	var iname := str(held.item_name)
	if held.has_method("is_broken") and held.is_broken():
		return null
	if iname.begins_with("Lata de ") and not iname.ends_with(" abierta"):
		return null
	if iname == "Carne humana" or iname.begins_with("Carne cruda"):
		return null
	var main := get_tree().current_scene if get_tree() != null else null
	if main == null or not ("remote_players" in main):
		return null
	var rps: Dictionary = main.remote_players
	if rps.is_empty():
		return null
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() > 0.0001:
		forward = forward.normalized()
	var best: Node3D = null
	var best_dist := 2.65
	for pid in rps.keys():
		var rp = rps[pid]
		if rp == null or not is_instance_valid(rp) or not (rp is Node3D):
			continue
		if bool(rp.get("is_dead")) or bool(rp.get_meta("proxy_dead", false)):
			continue
		var rpos: Vector3 = (rp as Node3D).global_position
		if absf(rpos.y - global_position.y) > 2.0:
			continue
		var delta_xz := Vector3(rpos.x - global_position.x, 0.0, rpos.z - global_position.z)
		var d := delta_xz.length()
		if d > best_dist:
			continue
		if d > 0.25 and forward.length_squared() > 0.0001:
			if forward.dot(delta_xz / d) < 0.35:
				continue
		best_dist = d
		best = rp as Node3D
	return best

func _get_remote_player_display_name(rp: Node3D) -> String:
	if rp == null or not is_instance_valid(rp):
		return "superviviente"
	var pid := int(rp.get_meta("peer_id", -1))
	var main := get_tree().current_scene if get_tree() != null else null
	if main != null and main.get("net") != null and pid > 0:
		var net_node = main.net
		if net_node.players.has(pid):
			var cn := str(net_node.players[pid].get("char_name", "")).strip_edges()
			if not cn.is_empty():
				return cn
	var fallback := str(rp.get("character_name")).strip_edges()
	return fallback if not fallback.is_empty() else "superviviente"

func _give_food_or_drink_to_player(target_puppet: Node3D) -> void:
	if target_puppet == null or not is_instance_valid(target_puppet) or is_dead or _consumption_pending or inventory == null:
		return
	var held = get_held_item()
	if held == null:
		return
	var itype := str(held.item_type)
	if itype != "food" and itype != "water":
		return
	var idx: int = inventory.items.find(held)
	if idx < 0:
		return
	var target_pid := int(target_puppet.get_meta("peer_id", -1))
	if target_pid <= 0:
		return
	var iname := str(held.item_name)
	var peer_label := _get_remote_player_display_name(target_puppet)
	var is_hot := iname == "Carne asada en palo" or iname == "Carne ensartada" or iname == "Pez ensartado"
	# Measure the exact stat restoration produced by Inventory.use_index on a probe stats object
	var probe := SurvivalStatsScript.new()
	probe.hunger = 20.0
	probe.thirst = 20.0
	probe.health = 50.0
	# The restore values are measured on a throwaway stats probe — suppress the
	# "Comes/Bebes..." item_used chatter so the giver only sees the give notice.
	var used_conns: Array = inventory.item_used.get_connections()
	for conn in used_conns:
		inventory.item_used.disconnect(conn.callable)
	var consumed: bool = inventory.use_index(idx, probe)
	for conn in used_conns:
		inventory.item_used.connect(conn.callable, conn.flags)
	var d_hunger := maxf(0.0, float(probe.hunger) - 20.0)
	var d_thirst := maxf(0.0, float(probe.thirst) - 20.0)
	var d_health := maxf(0.0, float(probe.health) - 50.0)
	probe.free()
	if not consumed:
		return
	play_action_animation("give", 1.4)
	_sync_held_item()
	var verb := "Le das de beber" if itype == "water" else "Le das de comer"
	notice.emit("%s (%s) a %s." % [verb, iname, peer_label])
	var main := get_tree().current_scene if get_tree() != null else null
	if main != null:
		var net_node = main.get("net")
		if net_node != null and net_node.is_connected:
			if net_node.is_host:
				if main.has_method("_net_feed_other_player"):
					main._net_feed_other_player(target_pid, iname, itype, d_hunger, d_thirst, d_health, is_hot, net_node.get_my_id())
			elif net_node.has_method("feed_other_player"):
				net_node.feed_other_player.rpc_id(1, target_pid, iname, itype, d_hunger, d_thirst, d_health, is_hot)
		if main.has_method("_sync_local_player_inventory"):
			main.call_deferred("_sync_local_player_inventory")

func _fishing_attempt_valid(session: int, rod, origin: Vector3) -> bool:
	if session != _fishing_session or not _is_fishing or is_dead:
		return false
	if rod == null or get_held_item() != rod or rod.is_broken():
		return false
	# En la barca la posicion la lleva el casco: una deriva suave no debe
	# cancelar el lance (el limite de 1 m es para quien pesca a pie).
	if not is_instance_valid(rowing_boat) and global_position.distance_to(origin) > 1.0:
		return false
	var water := _get_fishing_water_state()
	return bool(water.get("near", false)) and bool(water.get("facing", false))

func _has_fishing_rod_in_hand() -> bool:
	var held = get_held_item()
	return held != null and held.item_type == "tool_fishing" and not held.is_broken()

func _get_fishing_water_state() -> Dictionary:
	var result := {"near": false, "facing": false, "point": Vector3.ZERO}
	if is_in_water:
		_fishing_water_cache_pos = Vector3.INF
		return result
	if is_instance_valid(rowing_boat):
		# De pie en la barca el lance cae unos metros por delante, sobre el agua.
		if not _boat_standing:
			return result
		var cast_forward := global_transform.basis * Vector3.FORWARD
		cast_forward.y = 0.0
		if cast_forward.length_squared() < 0.0001:
			return result
		var cast_pos := global_position + cast_forward.normalized() * 4.0
		var boat_main := get_tree().current_scene
		if boat_main == null or not boat_main.has_method("get_river_depth_at"):
			return result
		if boat_main.get_river_depth_at(cast_pos) <= 0.05:
			return result
		result["near"] = true
		result["facing"] = true
		result["point"] = Vector3(cast_pos.x, boat_main.get_river_surface_y_at(cast_pos), cast_pos.z)
		return result
	# Cache: only recompute the expensive nearest-water scan when the player has
	# moved more than 0.5m or rotated since the last call. Facing is recomputed
	# from the cached point cheaply every call so the prompt stays responsive.
	var pos := global_position
	if _fishing_water_cache_pos.distance_squared_to(pos) > 0.25:
		_fishing_water_cache_pos = pos
		var main := get_tree().current_scene
		if main == null or not main.has_method("get_nearest_fishing_water_point"):
			_fishing_water_cache = result
			return result
		var water_info: Dictionary = main.get_nearest_fishing_water_point(pos, 5.0)
		if not bool(water_info.get("valid", false)):
			_fishing_water_cache = result
			return result
		var water_point: Vector3 = water_info.get("point", Vector3.ZERO)
		_fishing_water_cache = {"near": true, "facing": false, "point": water_point}
	var cached: Dictionary = _fishing_water_cache
	if not bool(cached.get("near", false)):
		return result
	var water_point: Vector3 = cached.get("point", Vector3.ZERO)
	var to_water := water_point - pos
	to_water.y = 0.0
	if to_water.length_squared() < 0.0001:
		return result
	var forward := global_transform.basis * Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return result
	result["near"] = true
	result["facing"] = forward.normalized().dot(to_water.normalized()) >= 0.25
	result["point"] = water_point
	return result

func _get_interaction_target():
	if raycast != null and raycast.has_method("get_interactable"):
		return raycast.get_interactable(self, camera, _aim_screen_offset)
	var collider = _get_aim_collider()
	if collider != null:
		return _find_interactable_owner(collider)
	return null

func _get_aim_collider():
	if camera == null or camera.get_world_3d() == null:
		return null
	var viewport := camera.get_viewport()
	if viewport == null:
		return null
	var aim_point := viewport.get_visible_rect().size * 0.5 + _aim_screen_offset
	var origin := camera.project_ray_origin(aim_point)
	var end := origin + camera.project_ray_normal(aim_point) * interaction_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if _cached_rids_dirty:
		_cached_exclude_rids = [self.get_rid()]
		_collect_child_collision_rids(self, _cached_exclude_rids)
		_cached_rids_dirty = false
	query.exclude = _cached_exclude_rids
	if is_instance_valid(rowing_boat):
		var boat_exclude: Array[RID] = _cached_exclude_rids.duplicate()
		boat_exclude.append(rowing_boat.get_rid())
		_collect_child_collision_rids(rowing_boat, boat_exclude)
		query.exclude = boat_exclude
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider", null)

func _collect_child_collision_rids(node: Node, rids: Array[RID]) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			rids.append((child as CollisionObject3D).get_rid())
		_collect_child_collision_rids(child, rids)

func _find_interactable_owner(node):
	var cursor = node
	while cursor != null:
		if cursor.is_in_group("interactable") or cursor.has_method("interact"):
			return cursor
		cursor = cursor.get_parent() if cursor is Node else null
	return null

func get_aim_screen_offset() -> Vector2:
	return _aim_screen_offset

func _find_nearby_world_action():
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var forward := -global_transform.basis.z.normalized()
	var eye := global_position + Vector3(0.0, 1.2, 0.0)
	var best = null
	var best_score := 9999.0
	# Opt: usar distance_squared_to para el filtro rápido (evita sqrt)
	const MAX_DIST_SQ := 4.2 * 4.2  # = 17.64
	for node in get_tree().get_nodes_in_group("world_actions"):
		if not node is Node3D:
			continue
		if node.get("depleted") == true and node.get("repeatable") == false:
			continue
		var action := node as Node3D
		var to_action := action.global_position - eye
		# Filtro rápido sin sqrt
		if to_action.length_squared() > MAX_DIST_SQ:
			continue
		var flat := Vector3(to_action.x, 0.0, to_action.z)
		if flat.length_squared() <= 0.0025:  # 0.05 * 0.05
			continue
		var facing := forward.dot(flat.normalized())
		if facing < 0.42:
			continue
		# Solo aquí hacemos sqrt para el score final (inevitable)
		var distance := to_action.length()
		var score := distance - facing * 1.6
		if score < best_score:
			best_score = score
			best = node
	return best

# Only one torch burns at a time: when lighting a stacked torch, split one
# unit off so the unlit remainder keeps stacking and the lit unit stays single.
func _split_torch_for_lighting(held):
	if held == null or int(held.quantity) <= 1 or inventory == null:
		return held
	held.quantity -= 1
	var lit_torch = held.duplicate_stack()
	lit_torch.quantity = 1
	inventory.items.append(lit_torch)
	_held_item_reference = lit_torch
	inventory.changed.emit()
	return lit_torch

func _toggle_flashlight() -> void:
	var held = get_held_item()
	if held != null and str(held.item_type) == "tool_torch":
		if held.is_broken():
			notice.emit("La antorcha está gastada.")
			return
		if torch_light.visible:
			torch_light.visible = false
			held.set_meta("torch_lit", false)
			notice.emit("Antorcha apagada.")
			return
		if not inventory.has_item_name("Cerillas"):
			if not inventory.has_item_name("Palo", 2):
				notice.emit("Necesitas cerillas o 2 palos para encender la antorcha.")
				return
			inventory.consume_item_name("Palo", 2)
			inventory.changed.emit()
			play_action_animation("forage", 8.0)
			notice.emit("Frotando palos para encender antorcha... (8s)")
			var _hud := get_parent().get_node_or_null("HUD")
			if _hud != null and _hud.has_method("show_countdown"):
				_hud.show_countdown("Encendiendo antorcha con palos", 8.0)
			await get_tree().create_timer(8.0).timeout
			torch_light.visible = true
			held = _split_torch_for_lighting(held)
			held.set_meta("torch_lit", true)
			notice.emit("Antorcha encendida frotando palos.")
			return
		inventory.consume_match_charge()
		inventory.changed.emit()
		torch_light.visible = true
		held = _split_torch_for_lighting(held)
		held.set_meta("torch_lit", true)
		notice.emit("Antorcha encendida con cerillas.")
		return
	if not inventory.has_item_type("tool"):
		notice.emit("No tienes linterna.")
		return
	if flashlight.visible:
		flashlight.visible = false
		_sync_held_item()
		notice.emit("Linterna apagada.")
		return
	if flashlight_charge <= 0.0:
		if inventory.consume_one_type("battery"):
			flashlight_charge = 90.0
			notice.emit("Pilas colocadas.")
		else:
			notice.emit("No quedan pilas.")
			return
	flashlight.visible = true
	_sync_held_item()
	notice.emit("Linterna encendida.")

func _update_flashlight(delta: float) -> void:
	if flashlight == null:
		return
	if flashlight.visible:
		flashlight_charge = max(0.0, flashlight_charge - delta)
		flashlight.light_energy = 1.1 + 2.2 * (flashlight_charge / 90.0)
		if flashlight_charge <= 0.0:
			flashlight.visible = false
			_sync_held_item()
			notice.emit("La linterna se queda sin pilas.")

var _torch_arm_active := false
var _torch_arm_bone_idx := -1
var _torch_forearm_bone_idx := -1
var _torch_hand_bone_idx := -1
var _torch_pose_connected := false

func _load_drink_animation() -> void:
	if _drink_animation_loaded:
		return
	_drink_animation_loaded = true
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	if not ResourceLoader.exists(DRINK_ANIMATION_GLB):
		return
	var loaded = load(DRINK_ANIMATION_GLB)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var src_skeleton := _find_skeleton(instance)
	var src_anim_player := _find_animation_player(instance)
	if src_anim_player == null:
		instance.queue_free()
		return
	var best_anim: Animation = null
	var best_length := 0.0
	for src_anim_name in src_anim_player.get_animation_list():
		var candidate: Animation = src_anim_player.get_animation(src_anim_name)
		if candidate == null:
			continue
		if candidate.length > best_length:
			best_length = candidate.length
			best_anim = candidate
	if best_anim == null:
		instance.queue_free()
		return
	var copied := best_anim.duplicate(true)
	copied.loop_mode = Animation.LOOP_LINEAR
	copied.step = 0.0166667
	_retarget_animation_to_character_skeleton(copied)
	_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
	_remove_non_hips_position_tracks(copied, false, 0.0)
	_smooth_loop_boundary(copied)
	instance.queue_free()
	var drink_lib: AnimationLibrary = AnimationLibrary.new()
	drink_lib.add_animation(THIRD_PERSON_EXTERNAL_DRINK_ANIMATION, copied)
	third_person_animation_player.add_animation_library("drink", drink_lib)
	if third_person_animation_player.has_animation("drink/" + THIRD_PERSON_EXTERNAL_DRINK_ANIMATION):
		third_person_drink_animation = "drink/" + THIRD_PERSON_EXTERNAL_DRINK_ANIMATION
		_drink_animation_length = copied.length

func _load_punch_animation() -> void:
	if _punch_animation_loaded:
		return
	_punch_animation_loaded = true
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	if not ResourceLoader.exists(PUNCH_ANIMATION_GLB):
		return
	var loaded = load(PUNCH_ANIMATION_GLB)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var src_skeleton := _find_skeleton(instance)
	var src_anim_player := _find_animation_player(instance)
	if src_anim_player == null:
		instance.queue_free()
		return
	var best_anim: Animation = null
	var best_length := 0.0
	for src_anim_name in src_anim_player.get_animation_list():
		var candidate: Animation = src_anim_player.get_animation(src_anim_name)
		if candidate == null:
			continue
		if candidate.length > best_length:
			best_length = candidate.length
			best_anim = candidate
	if best_anim == null:
		instance.queue_free()
		return
	var copied := best_anim.duplicate(true)
	copied.loop_mode = Animation.LOOP_NONE
	copied.step = 0.0166667
	_retarget_animation_to_character_skeleton(copied)
	_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
	_remove_non_hips_position_tracks(copied, false, 0.0)
	instance.queue_free()
	var punch_lib: AnimationLibrary = AnimationLibrary.new()
	punch_lib.add_animation(THIRD_PERSON_EXTERNAL_PUNCH_ANIMATION, copied)
	third_person_animation_player.add_animation_library("punch", punch_lib)
	if third_person_animation_player.has_animation("punch/" + THIRD_PERSON_EXTERNAL_PUNCH_ANIMATION):
		third_person_punch_animation = "punch/" + THIRD_PERSON_EXTERNAL_PUNCH_ANIMATION

func _load_melee_death_animation() -> void:
	if _melee_death_animation_loaded:
		return
	_melee_death_animation_loaded = true
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	if not ResourceLoader.exists(MELEE_DEATH_ANIMATION_GLB):
		return
	var loaded = load(MELEE_DEATH_ANIMATION_GLB)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var src_skeleton := _find_skeleton(instance)
	var src_anim_player := _find_animation_player(instance)
	if src_anim_player == null:
		instance.queue_free()
		return
	var best_anim: Animation = null
	var best_length := 0.0
	for src_anim_name in src_anim_player.get_animation_list():
		var candidate: Animation = src_anim_player.get_animation(src_anim_name)
		if candidate == null:
			continue
		if candidate.length > best_length:
			best_length = candidate.length
			best_anim = candidate
	if best_anim == null:
		instance.queue_free()
		return
	var copied := best_anim.duplicate(true)
	copied.loop_mode = Animation.LOOP_NONE
	copied.step = 0.0166667
	_retarget_animation_to_character_skeleton(copied)
	_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
	# Lock every position track to rest (hips included), then write the hips
	# fall back in — converted through world space because the rig's skeleton
	# axes differ from plain Y-up (the vertical drop lives in skeleton +Z).
	_remove_non_hips_position_tracks(copied, false, 0.0)
	_retarget_death_hips_track(copied, skel, best_anim, src_skeleton, instance)
	instance.queue_free()
	var death_lib: AnimationLibrary = AnimationLibrary.new()
	death_lib.add_animation(THIRD_PERSON_EXTERNAL_MELEE_DEATH_ANIMATION, copied)
	third_person_animation_player.add_animation_library("melee_death", death_lib)
	if third_person_animation_player.has_animation("melee_death/" + THIRD_PERSON_EXTERNAL_MELEE_DEATH_ANIMATION):
		third_person_melee_death_animation = "melee_death/" + THIRD_PERSON_EXTERNAL_MELEE_DEATH_ANIMATION

func _load_hit_animation() -> void:
	if _hit_animation_loaded:
		return
	_hit_animation_loaded = true
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	if not ResourceLoader.exists(HIT_ANIMATION_GLB):
		return
	var loaded = load(HIT_ANIMATION_GLB)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var src_skeleton := _find_skeleton(instance)
	var src_anim_player := _find_animation_player(instance)
	if src_anim_player == null:
		instance.queue_free()
		return
	var best_anim: Animation = null
	var best_length := 0.0
	for src_anim_name in src_anim_player.get_animation_list():
		var candidate: Animation = src_anim_player.get_animation(src_anim_name)
		if candidate == null:
			continue
		if candidate.length > best_length:
			best_length = candidate.length
			best_anim = candidate
	if best_anim == null:
		instance.queue_free()
		return
	var copied := best_anim.duplicate(true)
	copied.loop_mode = Animation.LOOP_NONE
	copied.step = 0.0166667
	_retarget_animation_to_character_skeleton(copied)
	_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
	_remove_non_hips_position_tracks(copied, false, 0.0)
	instance.queue_free()
	var hit_lib: AnimationLibrary = AnimationLibrary.new()
	hit_lib.add_animation(THIRD_PERSON_EXTERNAL_HIT_ANIMATION, copied)
	third_person_animation_player.add_animation_library("hit", hit_lib)
	if third_person_animation_player.has_animation("hit/" + THIRD_PERSON_EXTERNAL_HIT_ANIMATION):
		third_person_hit_animation = "hit/" + THIRD_PERSON_EXTERNAL_HIT_ANIMATION

func _load_shot_animation() -> void:
	if _shot_animation_loaded:
		return
	_shot_animation_loaded = true
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	if not ResourceLoader.exists(SHOT_ANIMATION_GLB):
		return
	var loaded = load(SHOT_ANIMATION_GLB)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var src_skeleton := _find_skeleton(instance)
	var src_anim_player := _find_animation_player(instance)
	if src_anim_player == null:
		instance.queue_free()
		return
	var best_anim: Animation = null
	var best_length := 0.0
	for src_anim_name in src_anim_player.get_animation_list():
		var candidate: Animation = src_anim_player.get_animation(src_anim_name)
		if candidate == null:
			continue
		if candidate.length > best_length:
			best_length = candidate.length
			best_anim = candidate
	if best_anim == null:
		instance.queue_free()
		return
	var copied := best_anim.duplicate(true)
	copied.loop_mode = Animation.LOOP_NONE
	copied.step = 0.0166667
	_retarget_animation_to_character_skeleton(copied)
	_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
	_remove_non_hips_position_tracks(copied, false, 0.0)
	instance.queue_free()
	var shot_lib: AnimationLibrary = AnimationLibrary.new()
	shot_lib.add_animation(THIRD_PERSON_EXTERNAL_SHOT_ANIMATION, copied)
	third_person_animation_player.add_animation_library("shot", shot_lib)
	if third_person_animation_player.has_animation("shot/" + THIRD_PERSON_EXTERNAL_SHOT_ANIMATION):
		third_person_shot_animation = "shot/" + THIRD_PERSON_EXTERNAL_SHOT_ANIMATION

func _load_give_food_animation() -> void:
	if _give_animation_loaded:
		return
	_give_animation_loaded = true
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	if not ResourceLoader.exists(GIVE_FOOD_ANIMATION_GLB):
		return
	var loaded = load(GIVE_FOOD_ANIMATION_GLB)
	if not loaded is PackedScene:
		return
	var instance = (loaded as PackedScene).instantiate()
	if not instance is Node3D:
		if instance != null:
			instance.queue_free()
		return
	var src_skeleton := _find_skeleton(instance)
	var src_anim_player := _find_animation_player(instance)
	if src_anim_player == null:
		instance.queue_free()
		return
	var best_anim: Animation = null
	var best_length := 0.0
	for src_anim_name in src_anim_player.get_animation_list():
		var candidate: Animation = src_anim_player.get_animation(src_anim_name)
		if candidate == null:
			continue
		if candidate.length > best_length:
			best_length = candidate.length
			best_anim = candidate
	if best_anim == null:
		instance.queue_free()
		return
	var copied := best_anim.duplicate(true)
	copied.loop_mode = Animation.LOOP_NONE
	copied.step = 0.0166667
	_retarget_animation_to_character_skeleton(copied)
	_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
	_remove_non_hips_position_tracks(copied, false, 0.0)
	instance.queue_free()
	var give_lib: AnimationLibrary = AnimationLibrary.new()
	give_lib.add_animation(THIRD_PERSON_EXTERNAL_GIVE_ANIMATION, copied)
	third_person_animation_player.add_animation_library("give", give_lib)
	if third_person_animation_player.has_animation("give/" + THIRD_PERSON_EXTERNAL_GIVE_ANIMATION):
		third_person_give_animation = "give/" + THIRD_PERSON_EXTERNAL_GIVE_ANIMATION

func _load_bow_animations() -> void:
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	var bow_lib := AnimationLibrary.new()
	var clips := {
		THIRD_PERSON_EXTERNAL_BOW_SHOOT_ANIMATION: [BOW_SHOOT_ANIMATION_GLB, Animation.LOOP_NONE],
		THIRD_PERSON_EXTERNAL_BOW_AIM_IDLE_ANIMATION: [BOW_AIM_IDLE_ANIMATION_GLB, Animation.LOOP_LINEAR],
		THIRD_PERSON_EXTERNAL_BOW_AIM_WALK_ANIMATION: [BOW_AIM_WALK_ANIMATION_GLB, Animation.LOOP_LINEAR],
	}
	for anim_key in clips:
		var glb_path: String = clips[anim_key][0]
		var loop_mode: int = clips[anim_key][1]
		if not ResourceLoader.exists(glb_path):
			continue
		var loaded = load(glb_path)
		if not (loaded is PackedScene):
			continue
		var instance = (loaded as PackedScene).instantiate()
		if not (instance is Node3D):
			if instance != null:
				instance.queue_free()
			continue
		var src_skeleton := _find_skeleton(instance)
		var src_anim_player := _find_animation_player(instance)
		var best_anim: Animation = null
		var best_length := 0.0
		if src_anim_player != null:
			for src_anim_name in src_anim_player.get_animation_list():
				var candidate: Animation = src_anim_player.get_animation(src_anim_name)
				if candidate != null and candidate.length > best_length:
					best_length = candidate.length
					best_anim = candidate
		if best_anim != null:
			var copied := best_anim.duplicate(true)
			copied.loop_mode = loop_mode
			copied.step = 0.0166667
			_retarget_animation_to_character_skeleton(copied)
			_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
			_remove_non_hips_position_tracks(copied, false, 0.0)
			bow_lib.add_animation(anim_key, copied)
		instance.queue_free()
	if bow_lib.get_animation_list().size() > 0:
		third_person_animation_player.add_animation_library("bow", bow_lib)
	if third_person_animation_player.has_animation("bow/" + THIRD_PERSON_EXTERNAL_BOW_SHOOT_ANIMATION):
		_bow_shoot_animation = "bow/" + THIRD_PERSON_EXTERNAL_BOW_SHOOT_ANIMATION
	if third_person_animation_player.has_animation("bow/" + THIRD_PERSON_EXTERNAL_BOW_AIM_IDLE_ANIMATION):
		_bow_aim_idle_animation = "bow/" + THIRD_PERSON_EXTERNAL_BOW_AIM_IDLE_ANIMATION
	if third_person_animation_player.has_animation("bow/" + THIRD_PERSON_EXTERNAL_BOW_AIM_WALK_ANIMATION):
		_bow_aim_walk_animation = "bow/" + THIRD_PERSON_EXTERNAL_BOW_AIM_WALK_ANIMATION

func _load_torch_animations() -> void:
	if _torch_animations_loaded:
		return
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	var torch_lib: AnimationLibrary = AnimationLibrary.new()
	var torch_anims := {
		THIRD_PERSON_EXTERNAL_TORCH_IDLE_ANIMATION: TORCH_IDLE_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_WALK_ANIMATION: TORCH_WALK_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_RUN_ANIMATION: TORCH_RUN_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_TURN_LEFT_ANIMATION: TORCH_TURN_LEFT_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_TURN_RIGHT_ANIMATION: TORCH_TURN_RIGHT_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_LEFT_ANIMATION: TORCH_CROUCH_TURN_LEFT_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_RIGHT_ANIMATION: TORCH_CROUCH_TURN_RIGHT_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_CROUCH_IDLE_ANIMATION: TORCH_CROUCH_IDLE_FBX,
		THIRD_PERSON_EXTERNAL_TORCH_CROUCH_WALK_ANIMATION: TORCH_CROUCH_WALK_FBX,
	}
	for anim_name in torch_anims:
		var fbx_path: String = torch_anims[anim_name]
		if not ResourceLoader.exists(fbx_path):
			continue
		var loaded = load(fbx_path)
		if loaded is PackedScene:
			var instance = (loaded as PackedScene).instantiate()
			if instance is Node3D:
				var src_skeleton := _find_skeleton(instance)
				var src_anim_player := _find_animation_player(instance)
				if src_anim_player != null:
					var src_lib_names := src_anim_player.get_animation_list()
					# Find the longest animation (skip "Take 001" which is a 0.001s rest pose)
					var best_anim: Animation = null
					var best_length := 0.0
					for src_anim_name in src_lib_names:
						var candidate: Animation = src_anim_player.get_animation(src_anim_name)
						if candidate == null:
							continue
						if candidate.length > best_length:
							best_length = candidate.length
							best_anim = candidate
					if best_anim != null:
						var copied := best_anim.duplicate(true)
						copied.loop_mode = Animation.LOOP_LINEAR
						copied.step = 0.0166667
						var track_count_before: int = copied.get_track_count()
						_retarget_animation_to_character_skeleton(copied)
						var resolved_count := 0
						var unresolved_count := 0
						for ti in range(copied.get_track_count()):
							var tp := str(copied.track_get_path(ti))
							var bn := _extract_mixamo_bone_name(tp)
							if not bn.is_empty():
								if skel.find_bone(bn) >= 0:
									resolved_count += 1
								else:
									unresolved_count += 1
						# Torch GLBs have a different skeleton (mixamorig5_) with different rest pose
						# and scale, so always retarget rotations using the source skeleton and remove position tracks
						_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
						var is_crouch_anim: bool = anim_name.find("Crouch") >= 0
						_remove_non_hips_position_tracks(copied, false, 0.0, is_crouch_anim)
						_smooth_loop_boundary(copied)
						torch_lib.add_animation(anim_name, copied)
				else:
					pass
			instance.queue_free()
	if torch_lib.get_animation_list().size() > 0:
		third_person_animation_player.add_animation_library("torch", torch_lib)
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_IDLE_ANIMATION):
			_torch_idle_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_IDLE_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_WALK_ANIMATION):
			_torch_walk_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_WALK_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_RUN_ANIMATION):
			_torch_run_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_RUN_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_TURN_LEFT_ANIMATION):
			_torch_turn_left_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_TURN_LEFT_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_TURN_RIGHT_ANIMATION):
			_torch_turn_right_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_TURN_RIGHT_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_IDLE_ANIMATION):
			_torch_crouch_idle_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_IDLE_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_WALK_ANIMATION):
			_torch_crouch_walk_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_WALK_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_LEFT_ANIMATION):
			_torch_crouch_turn_left_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_LEFT_ANIMATION
		if third_person_animation_player.has_animation("torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_RIGHT_ANIMATION):
			_torch_crouch_turn_right_animation = "torch/" + THIRD_PERSON_EXTERNAL_TORCH_CROUCH_TURN_RIGHT_ANIMATION
	_torch_animations_loaded = true

func _set_rod_overlay_mesh_visibility(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		var is_character_mesh := mesh_instance.skin != null or not mesh_instance.skeleton.is_empty()
		mesh_instance.visible = not is_character_mesh
	for child in node.get_children():
		_set_rod_overlay_mesh_visibility(child)

func _cache_normal_fishing_rod_pose(instance: Node3D, anim_player: AnimationPlayer, source_animation: String) -> void:
	var source_rod := instance.find_child("FishingRod", true, false) as Node3D
	var source_skeleton := _find_skeleton(instance)
	var source_clip := anim_player.get_animation(source_animation)
	if source_rod == null or source_skeleton == null or source_clip == null:
		return
	var hand_bone := -1
	for bone_name in ["mixamorig:RightHand", "mixamorig_RightHand", "RightHand"]:
		hand_bone = source_skeleton.find_bone(bone_name)
		if hand_bone != -1:
			break
	if hand_bone == -1:
		return

	# Use the final authored pose of the start-fishing clip. Both transforms
	# are converted to the imported scene root, so the result can be applied
	# directly below HandsSocket on the in-game character.
	anim_player.play(source_animation)
	anim_player.seek(source_clip.length, true)
	source_skeleton.force_update_all_bone_transforms()
	var root_inverse := instance.global_transform.affine_inverse()
	var hand_transform := root_inverse * (source_skeleton.global_transform * source_skeleton.get_bone_global_pose(hand_bone))
	var source_socket_transform := hand_transform
	source_socket_transform.origin += _hand_socket_offset
	# The imported Mixamo skeleton carries a 0.01 basis scale. HandsSocket is
	# updated with the hand rotation and position only, so remove that import
	# scale before calculating the rod's local transform. This keeps the rod's
	# own 0.01 scale instead of expanding its geometry 100 times in-game.
	source_socket_transform.basis = source_socket_transform.basis.orthonormalized()
	var rod_transform := root_inverse * source_rod.global_transform
	_normal_fishing_rod_source = source_rod
	_normal_fishing_rod_hand_transform = source_socket_transform.affine_inverse() * rod_transform
	# Place the handle through the centre of the adapted character's palm. The
	# authored fishing pose leaves the rod offset from the wrist when reused by
	# the normal idle/walk animations.
	_normal_fishing_rod_hand_transform.origin += NORMAL_FISHING_ROD_GRIP_CORRECTION
	_normal_fishing_rod_pose_ready = true
	anim_player.seek(0.0, true)
	anim_player.pause()

func _register_rod_visual_overlay(key: String, instance: Node3D, anim_player: AnimationPlayer, source_animation: String) -> bool:
	if third_person_model == null or instance == null or anim_player == null or source_animation.is_empty():
		return false
	var has_socket := instance.find_child("FishingRodSocket", true, false) != null
	var has_line := instance.find_child("Hilo de pesca", true, false) != null
	if not has_socket and not has_line:
		return false
	_set_rod_overlay_mesh_visibility(instance)
	instance.name = "RodVisual_" + key
	instance.position = Vector3.ZERO
	instance.rotation = Vector3.ZERO
	instance.scale = Vector3.ONE
	instance.visible = false
	third_person_model.add_child(instance)
	anim_player.play(source_animation)
	anim_player.seek(0.0, true)
	anim_player.pause()
	if key == THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION:
		_cache_normal_fishing_rod_pose(instance, anim_player, source_animation)
	_rod_visual_overlays[key] = {
		"root": instance,
		"player": anim_player,
		"animation": source_animation,
	}
	return true

func _set_normal_fishing_rod_visible(value: bool) -> void:
	if third_person_hand_item_root == null:
		return
	var normal_rod := third_person_hand_item_root.get_node_or_null("ThirdPersonFishingRod") as Node3D
	if normal_rod != null:
		normal_rod.visible = value

func _activate_rod_visual_overlay(key: String) -> void:
	_deactivate_rod_visual_overlay()
	if not _rod_visual_overlays.has(key):
		return
	var info: Dictionary = _rod_visual_overlays[key]
	var visual_root := info.get("root") as Node3D
	var visual_player := info.get("player") as AnimationPlayer
	var visual_animation := str(info.get("animation", ""))
	if visual_root == null or visual_player == null or visual_animation.is_empty():
		return
	_active_rod_visual_key = key
	_active_rod_visual_root = visual_root
	_active_rod_visual_player = visual_player
	_active_rod_visual_animation = visual_animation
	visual_root.visible = true
	visual_player.play(visual_animation)
	visual_player.seek(0.0, true)
	visual_player.pause()
	_set_normal_fishing_rod_visible(false)

func _deactivate_rod_visual_overlay() -> void:
	if _active_rod_visual_player != null and is_instance_valid(_active_rod_visual_player):
		_active_rod_visual_player.stop()
	if _active_rod_visual_root != null and is_instance_valid(_active_rod_visual_root):
		_active_rod_visual_root.visible = false
	_active_rod_visual_key = ""
	_active_rod_visual_root = null
	_active_rod_visual_player = null
	_active_rod_visual_animation = ""
	_set_normal_fishing_rod_visible(_has_fishing_rod)

func _update_rod_visual_overlay() -> void:
	if _active_rod_visual_root == null or _active_rod_visual_player == null:
		return
	if not is_instance_valid(_active_rod_visual_root) or not is_instance_valid(_active_rod_visual_player):
		_deactivate_rod_visual_overlay()
		return
	var is_matching_action := false
	if _active_rod_visual_key == THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION:
		is_matching_action = third_person_action_animation == _rod_fish_start_animation
	elif _active_rod_visual_key == THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION:
		is_matching_action = third_person_action_animation == _rod_fish_end_animation
	elif _active_rod_visual_key == THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION:
		is_matching_action = third_person_action_animation == _rod_cast_animation
	elif _active_rod_visual_key == THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION:
		is_matching_action = _is_fishing_idle and third_person_animation_player.current_animation == _rod_idle_animation
	var needs_action_timer := _active_rod_visual_key != THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION
	if not _has_fishing_rod_in_hand() or not is_matching_action or (needs_action_timer and third_person_action_timer <= 0.0):
		_deactivate_rod_visual_overlay()
		return
	var visual_animation := _active_rod_visual_player.get_animation(_active_rod_visual_animation)
	if visual_animation == null or third_person_animation_player == null:
		_deactivate_rod_visual_overlay()
		return
	var synchronized_time := clampf(third_person_animation_player.current_animation_position, 0.0, visual_animation.length)
	_active_rod_visual_player.seek(synchronized_time, true)

func _remove_rod_visual_tracks_from_character_animation(animation: Animation) -> void:
	for track_index in range(animation.get_track_count() - 1, -1, -1):
		var path_text := str(animation.track_get_path(track_index))
		if _extract_mixamo_bone_name(path_text).is_empty():
			animation.remove_track(track_index)

func _load_rod_animations() -> void:
	if _rod_animations_loaded or _rod_animations_loading:
		return
	if third_person_animation_player == null:
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		return
	_rod_animations_loading = true
	# Load synchronously — called only when fishing starts, not when equipping.
	_load_rod_animations_deferred()

func _preload_rod_pose() -> void:
	# Pre-cache the fishing rod pose from the fish_start GLB so the rod is
	# held correctly when equipped, without loading all animation GLBs.
	if _normal_fishing_rod_pose_ready:
		return
	if not ResourceLoader.exists(ROD_FISH_START_GLB):
		return
	var loaded = load(ROD_FISH_START_GLB)
	if not (loaded is PackedScene):
		return
	var instance = (loaded as PackedScene).instantiate()
	if not (instance is Node3D):
		return
	add_child(instance)
	instance.visible = false
	var src_anim_player := _find_animation_player(instance)
	var src_skeleton := _find_skeleton(instance)
	if src_anim_player != null and src_skeleton != null:
		var src_lib_names := src_anim_player.get_animation_list()
		var best_anim: Animation = null
		var best_source_animation := ""
		var best_length := 0.0
		for src_anim_name in src_lib_names:
			var candidate: Animation = src_anim_player.get_animation(src_anim_name)
			if candidate == null:
				continue
			if candidate.length > best_length:
				best_length = candidate.length
				best_anim = candidate
				best_source_animation = str(src_anim_name)
		if best_anim != null:
			_cache_normal_fishing_rod_pose(instance as Node3D, src_anim_player, best_source_animation)
	# Keep the source rod alive — _normal_fishing_rod_source points to it.
	# Reparent it to a hidden holder so it survives but isn't rendered.
	if _normal_fishing_rod_source != null and is_instance_valid(_normal_fishing_rod_source):
		_normal_fishing_rod_source.visible = false
	else:
		instance.queue_free()

func _load_rod_animations_deferred() -> void:
	if _rod_animations_loaded:
		_rod_animations_loading = false
		return
	if third_person_animation_player == null:
		_rod_animations_loading = false
		return
	var skel := _find_skeleton(third_person_model)
	if skel == null:
		_rod_animations_loading = false
		return
	var rod_lib: AnimationLibrary = AnimationLibrary.new()
	var rod_anims := {
		THIRD_PERSON_EXTERNAL_ROD_WALK_ANIMATION: ROD_WALK_GLB,
		THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION: ROD_CAST_GLB,
		THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION: ROD_IDLE_GLB,
		THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION: ROD_FISH_START_GLB,
		THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION: ROD_FISH_END_GLB,
	}
	for anim_name in rod_anims:
		var glb_path: String = rod_anims[anim_name]
		if not ResourceLoader.exists(glb_path):
			continue
		var loaded = load(glb_path)
		if loaded is PackedScene:
			var instance = (loaded as PackedScene).instantiate()
			if instance is Node3D:
				var src_skeleton := _find_skeleton(instance)
				var src_anim_player := _find_animation_player(instance)
				var keep_visual_instance := false
				if src_anim_player != null:
					var src_lib_names := src_anim_player.get_animation_list()
					var best_anim: Animation = null
					var best_source_animation := ""
					var best_length := 0.0
					# First pass: prefer animation whose name matches the expected anim_name
					var anim_name_lower: String = anim_name.to_lower()
					for src_anim_name in src_lib_names:
						var candidate: Animation = src_anim_player.get_animation(src_anim_name)
						if candidate == null:
							continue
						var src_lower := str(src_anim_name).to_lower()
						if src_lower.find(anim_name_lower) >= 0 or (src_lower.find("walk") >= 0 and anim_name_lower.find("walk") >= 0):
							best_anim = candidate
							best_source_animation = str(src_anim_name)
							best_length = candidate.length
							break
					# Fallback: pick the longest animation
					if best_anim == null:
						for src_anim_name in src_lib_names:
							var candidate: Animation = src_anim_player.get_animation(src_anim_name)
							if candidate == null:
								continue
							if candidate.length > best_length:
								best_length = candidate.length
								best_anim = candidate
								best_source_animation = str(src_anim_name)
					if best_anim != null:
						keep_visual_instance = _register_rod_visual_overlay(anim_name, instance as Node3D, src_anim_player, best_source_animation)
						if anim_name == THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION and not keep_visual_instance:
							_rod_socket_keyframes = _extract_rod_socket_keyframes(src_anim_player, src_lib_names)
						var copied := best_anim.duplicate(true)
						if keep_visual_instance:
							_remove_rod_visual_tracks_from_character_animation(copied)
						copied.loop_mode = Animation.LOOP_NONE if (anim_name == THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION or anim_name == THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION or anim_name == THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION) else Animation.LOOP_LINEAR
						copied.step = 0.0166667
						_retarget_animation_to_character_skeleton(copied)
						_retarget_rotation_tracks_with_source(copied, skel, src_skeleton)
						var is_fish_pose: bool = anim_name == THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION or anim_name == THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION
						_remove_non_hips_position_tracks(copied, false, 0.0, is_fish_pose)
						if is_fish_pose:
							_normalize_hips_anim_y_offset(copied, skel)
						if anim_name != THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION and anim_name != THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION and anim_name != THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION:
							_smooth_loop_boundary(copied)
						rod_lib.add_animation(anim_name, copied)
				if not keep_visual_instance:
					instance.queue_free()
	if rod_lib.get_animation_list().size() > 0:
		third_person_animation_player.add_animation_library("rod", rod_lib)
		if third_person_animation_player.has_animation("rod/" + THIRD_PERSON_EXTERNAL_ROD_WALK_ANIMATION):
			_rod_walk_animation = "rod/" + THIRD_PERSON_EXTERNAL_ROD_WALK_ANIMATION
		if third_person_animation_player.has_animation("rod/" + THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION):
			_rod_cast_animation = "rod/" + THIRD_PERSON_EXTERNAL_ROD_CAST_ANIMATION
		if third_person_animation_player.has_animation("rod/" + THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION):
			_rod_idle_animation = "rod/" + THIRD_PERSON_EXTERNAL_ROD_IDLE_ANIMATION
		if third_person_animation_player.has_animation("rod/" + THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION):
			_rod_fish_start_animation = "rod/" + THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION
		if third_person_animation_player.has_animation("rod/" + THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION):
			_rod_fish_end_animation = "rod/" + THIRD_PERSON_EXTERNAL_ROD_FISH_END_ANIMATION
	_rod_animations_loaded = true
	_rod_animations_loading = false

func _extract_rod_socket_keyframes(anim_player: AnimationPlayer, anim_names: Array) -> Array:
	var keyframes: Array = []
	for anim_name in anim_names:
		var anim: Animation = anim_player.get_animation(anim_name)
		if anim == null:
			continue
		for track_idx in range(anim.get_track_count()):
			var path_text := str(anim.track_get_path(track_idx))
			if path_text.find("FishingRodSocket") < 0:
				continue
			if anim.track_get_type(track_idx) != Animation.TYPE_POSITION_3D:
				continue
			var key_count := anim.track_get_key_count(track_idx)
			for key_idx in range(key_count):
				var time := anim.track_get_key_time(track_idx, key_idx)
				var pos: Vector3 = anim.track_get_key_value(track_idx, key_idx)
				keyframes.append({"time": time, "pos": pos})
			break
		if not keyframes.is_empty():
			break
	return keyframes

func _get_rod_socket_offset(anim_time: float) -> Vector3:
	if _rod_socket_keyframes.is_empty():
		return Vector3.ZERO
	if _rod_socket_keyframes.size() == 1:
		return Vector3.ZERO
	var base_pos: Vector3 = _rod_socket_keyframes[0]["pos"]
	var first_time: float = _rod_socket_keyframes[0]["time"]
	var last_idx := _rod_socket_keyframes.size() - 1
	var last_time: float = _rod_socket_keyframes[last_idx]["time"]
	if anim_time <= first_time:
		return Vector3.ZERO
	if anim_time >= last_time:
		var last_pos: Vector3 = _rod_socket_keyframes[last_idx]["pos"]
		return last_pos - base_pos
	for i in range(last_idx):
		var t1: float = _rod_socket_keyframes[i]["time"]
		var t2: float = _rod_socket_keyframes[i + 1]["time"]
		if anim_time >= t1 and anim_time <= t2:
			var p1: Vector3 = _rod_socket_keyframes[i]["pos"]
			var p2: Vector3 = _rod_socket_keyframes[i + 1]["pos"]
			var alpha: float = (anim_time - t1) / (t2 - t1) if t2 > t1 else 0.0
			return p1.lerp(p2, alpha) - base_pos
	return Vector3.ZERO

func _build_third_person_torch() -> void:
	# Place torch_stick.glb in the torch hand root (follows left hand bone via _update_torch_hand_socket)
	if _torch_hand_root == null or not is_instance_valid(_torch_hand_root):
		return

	# The light and its particles must be attached to the tip, not to the
	# character root. Detach it before recreating the visual model.
	_detach_torch_light_from_tip()
	# Clear previous children
	for child in _torch_hand_root.get_children():
		if child == torch_light:
			continue
		child.queue_free()

	# Check if torch is broken - show stick instead
	var held = get_held_item()
	var is_broken_torch: bool = held != null and str(held.item_type) == "tool_torch" and held.is_broken()
	var model_path: String = REAL_TORCH_MODEL if not is_broken_torch else REAL_WOOD_STICK_MODEL
	var torch_node := _load_external_node3d(model_path)
	if torch_node != null:
		torch_node.name = "HeldTorch"
		torch_node.scale = Vector3.ONE * (0.7 if not is_broken_torch else 0.4)
		torch_node.position = Vector3.ZERO
		torch_node.rotation_degrees = Vector3(0.0, 0.0, 90.0)
		_torch_hand_root.add_child(torch_node)
		_attach_torch_light_to_tip(torch_node)

	if torch_light != null and torch_light.get_node_or_null("FireVisuals") == null:
		var effects := preload("res://scripts/FireVisuals.gd").new()
		effects.name = "FireVisuals"
		effects.small = true
		effects.flicker = false
		torch_light.add_child(effects)

	# Torch animations from Mixamo handle the arm pose; no manual bone override needed.
	if torch_light != null:
		if is_puppet:
			# El puppet no tiene inventario con meta torch_lit: el estado
			# encendido lo dicta el remoto via puppet_set_torch.
			torch_light.visible = _puppet_torch_lit
		else:
			var has_lit_meta = held != null and held.has_meta("torch_lit")
			var lit_value = false
			if has_lit_meta:
				lit_value = bool(held.get_meta("torch_lit", false))
			if held != null and str(held.item_type) == "tool_torch" and not held.is_broken() and lit_value:
				torch_light.visible = true
			else:
				torch_light.visible = false

func _detach_torch_light_from_tip() -> void:
	if torch_light == null or third_person_model == null:
		return
	# Equipment is initialized before the newly created light is added to the tree.
	if torch_light.get_parent() == null:
		return
	if torch_light.get_parent() != third_person_model:
		torch_light.reparent(third_person_model, false)
		torch_light.position = Vector3(0.0, 1.8, -1.2)

func _attach_torch_light_to_tip(torch_node: Node3D) -> void:
	if torch_light == null or not is_instance_valid(torch_node):
		return
	var flame_tip := torch_node.get_node_or_null("TorchFlameTip") as Marker3D
	if flame_tip == null:
		flame_tip = Marker3D.new()
		flame_tip.name = "TorchFlameTip"
		var local_bounds := _hierarchy_local_aabb(torch_node)
		# The source model is upright: its positive local Y end is the burning tip.
		flame_tip.position = Vector3(local_bounds.get_center().x, local_bounds.position.y + local_bounds.size.y + 0.05, local_bounds.get_center().z)
		torch_node.add_child(flame_tip)
	if torch_light.get_parent() != flame_tip:
		torch_light.reparent(flame_tip, false)
	torch_light.position = Vector3.ZERO
	torch_light.rotation = Vector3.ZERO

func _override_torch_arm_pose() -> void:
	pass

func _clear_torch_attachment() -> void:
	_torch_arm_active = false
	if _torch_pose_connected:
		var skel := _find_skeleton(third_person_model)
		if skel != null and is_instance_valid(skel):
			if skel.pose_updated.is_connected(_override_torch_arm_pose):
				skel.pose_updated.disconnect(_override_torch_arm_pose)
			# Clear bone overrides
			skel.clear_bones_global_pose_override()
		_torch_pose_connected = false
	_torch_arm_bone_idx = -1
	_torch_forearm_bone_idx = -1
	_detach_torch_light_from_tip()
	# Clear torch from torch hand root (left hand)
	if _torch_hand_root != null and is_instance_valid(_torch_hand_root):
		for child in _torch_hand_root.get_children():
			if child == torch_light:
				continue
			child.queue_free()

func _update_torch(delta: float) -> void:
	if torch_light == null:
		return
	var held = get_held_item()
	if held == null or str(held.item_type) != "tool_torch":
		if torch_light.visible:
			torch_light.visible = false
		return
	if held.is_broken():
		if torch_light.visible:
			torch_light.visible = false
			notice.emit("La antorcha se ha apagado.")
		held.set_meta("torch_lit", false)
		# Transform broken torch into a stick
		held.item_name = "Palo"
		held.item_type = "resource"
		_sync_held_item()
		return
	var should_be_lit: bool = held.has_meta("torch_lit") and bool(held.get_meta("torch_lit", false))
	if should_be_lit and not torch_light.visible:
		torch_light.visible = true
	if not should_be_lit and torch_light.visible:
		torch_light.visible = false
	if torch_light.visible:
		held.reduce_durability(delta * 2.0)
		var pct: float = held.durability_pct()
		torch_light.light_energy = 1.0 + 4.0 * clamp(pct, 0.0, 1.0)
		torch_light.light_color = Color(1.0, 0.6 + 0.3 * clamp(pct, 0.0, 1.0), 0.2 + 0.2 * clamp(pct, 0.0, 1.0))
		stats.apply_external_heat(delta * 1.5 * pct, 37.5)
		if wetness > 0.0 or _any_equipped_wet():
			apply_warmth_drying(delta * 0.03 * pct)
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
		if held.is_broken():
			torch_light.visible = false
			notice.emit("La antorcha se ha apagado.")
			held.item_name = "Palo"
			held.item_type = "resource"
			_sync_held_item()

#endregion


#region VIDA, DAÑO Y COMBATE
func take_damage(amount: float, from_knife: bool = false, weapon: String = "melee") -> void:
	if is_puppet:
		# Puppet: send damage to server via RPC — the server validates range
		# per weapon type before applying it to the real player.
		var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
		if net_node != null:
			var peer_id: int = get_meta("peer_id", 0)
			if peer_id != 0:
				net_node.damage_player.rpc_id(1, peer_id, amount, weapon)
		# The server confirms the hit before blood, audio, or the flinch is shown;
		# otherwise an out-of-range client could fake hit feedback for everyone.
		return
	apply_damage(amount)

func _land_after_fall() -> void:
	var drop := _max_fall_height - global_position.y
	_is_falling_from_height = false
	_fall_height = 0.0
	_max_fall_height = 0.0
	if drop <= FALL_SAFE_HEIGHT or is_puppet:
		return
	var damage := (drop - FALL_SAFE_HEIGHT) * FALL_DAMAGE_SCALE
	if is_in_water or _water_depth >= 0.5:
		damage *= FALL_WATER_FACTOR
	if damage <= 0.0:
		return
	stats.feet_wound = minf(100.0, stats.feet_wound + damage * 0.5)
	# The dedicated landing grunt replaces the generic pain tick this frame.
	_pain_sound_timer = 1.5
	apply_damage(damage)
	if not is_dead:
		notice.emit("Te has hecho dano al caer.")
		_play_fall_damage_sound()

func apply_damage(amount: float) -> void:
	if is_puppet or is_dead:
		return
	if is_sleeping:
		stop_sleep()
		notice.emit("Te han despertado!")
	# Wolf attacks damage equipped clothing
	if amount >= 10.0:
		for item in inventory.items:
			if item != null and item.item_type == "clothing" and item.has_method("reduce_durability"):
				var is_equipped := false
				for slot_val in _equipped_slots.values():
					if str(slot_val) == item.item_name:
						is_equipped = true
						break
				if is_equipped:
					item.reduce_durability(3.0)
					if item.is_broken():
						notice.emit("%s se ha roto por el ataque!" % item.item_name)
		inventory.changed.emit()
	stats.health = max(0.0, stats.health - amount)
	stats.changed.emit()
	notice.emit("Has recibido dano.")
	_play_pain_sound()
	_spawn_blood_splatter()

func _melee_attack() -> void:
	if is_dead or _attack_cooldown > 0.0:
		return
	if stats.energy < 5.0:
		notice.emit("Estas demasiado cansado para atacar.")
		return
	# Determine damage and energy cost based on held item
	var held = get_held_item()
	# Play attack animation — bare fists use the cross punch clip
	var attack_anim_name := third_person_attack_animation
	if held == null and not third_person_punch_animation.is_empty():
		attack_anim_name = third_person_punch_animation
	if not attack_anim_name.is_empty() and third_person_animation_player != null:
		var atk_anim := third_person_animation_player.get_animation(attack_anim_name)
		if atk_anim != null:
			atk_anim.loop_mode = Animation.LOOP_NONE
		third_person_action_animation = attack_anim_name
		# The cross punch lands at ~0.95 s into its 2 s clip — give it enough
		# action time for the strike to read before blending back.
		third_person_action_timer = 0.8 if attack_anim_name == third_person_attack_animation else minf(1.15, atk_anim.length if atk_anim != null else 1.15)
		third_person_animation_player.play(attack_anim_name, 0.08)
	var base_damage := 10.0  # bare fists
	var energy_cost := 8.0
	var attack_range := 3.0
	var is_knife := false
	if held != null:
		match held.item_type:
			"weapon":
				base_damage = 60.0
				energy_cost = 4.0
				is_knife = true
				if held.item_name == "Lanza":
					base_damage = 75.0
					attack_range = 3.6
				elif held.item_name == "Lanza de hueso":
					base_damage = 85.0
					attack_range = 3.6
				elif held.item_name == "Cuchillo de piedra":
					base_damage = 45.0
				elif held.item_name == "Cuchillo de hueso":
					base_damage = 52.0
			"tool_spear":
				base_damage = 50.0
				energy_cost = 5.0
				attack_range = 3.5
				is_knife = true
			"tool_axe":
				base_damage = 55.0 if held.item_name == "Hacha de piedra" else 65.0
				energy_cost = 10.0
				attack_range = 3.5
			"tool":
				if held.item_name == "Hacha":
					base_damage = 65.0
					energy_cost = 10.0
					attack_range = 3.5
				elif held.item_name == "Pico":
					base_damage = 20.0
					energy_cost = 8.0
				elif held.item_name == "Pala":
					base_damage = 15.0
					energy_cost = 7.0
				elif held.item_name == "Martillo":
					base_damage = 18.0
					energy_cost = 7.0
				else:
					base_damage = 8.0
					energy_cost = 6.0
			_:
				# Resources and other items cannot be used to attack
				notice.emit("No puedes atacar con %s." % str(held.item_name))
				return
	if held != null and held.has_method("is_broken") and held.is_broken():
		notice.emit("%s esta roto y no se puede usar." % str(held.item_name))
		return
	stats.energy = max(0.0, stats.energy - energy_cost)
	stats.changed.emit()
	_attack_cooldown = 0.7 if is_knife else 1.0
	var impact_delay := MELEE_PUNCH_IMPACT_DELAY if attack_anim_name == third_person_punch_animation else MELEE_SWING_IMPACT_DELAY
	_schedule_melee_swing_sound(impact_delay)
	# Resolve the strike at the swing's contact frame so the damage, blood and
	# victim flinch land when the arm actually reaches — not at click time.
	get_tree().create_timer(impact_delay).timeout.connect(_resolve_melee_strike.bind(base_damage, is_knife, attack_range, held))

func _resolve_melee_strike(base_damage: float, is_knife: bool, attack_range: float, held) -> void:
	if is_dead or not is_inside_tree():
		return
	# Damage the closest target (wildlife or player) in range
	var closest_target: Node3D = null
	var closest_dist := attack_range
	var closest_dist_sq := attack_range * attack_range  # Opt: comparar con sq para evitar sqrt
	var fwd := -global_transform.basis.z.normalized()
	fwd.y = 0.0
	fwd = fwd.normalized()
	# Check wildlife
	for node in get_tree().get_nodes_in_group("wildlife"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var animal := node as Node3D
		if animal == self:
			continue
		var d_sq := global_position.distance_squared_to(animal.global_position)
		if d_sq > closest_dist_sq:
			continue
		var dir := animal.global_position - global_position
		dir.y = 0.0
		if dir.length() > 0.001:
			dir = dir.normalized()
		if fwd.dot(dir) < 0.15:
			continue
		closest_target = animal
		closest_dist_sq = d_sq
		closest_dist = sqrt(d_sq)
	# Check NPCs (NPCController class)
	for node in get_tree().get_nodes_in_group("npc"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var npc_node := node as Node3D
		var d_sq := global_position.distance_squared_to(npc_node.global_position)
		if d_sq > closest_dist_sq:
			continue
		var dir := (npc_node.global_position - global_position).normalized()
		if fwd.dot(dir) < 0.3:
			continue
		closest_target = npc_node
		closest_dist_sq = d_sq
		closest_dist = sqrt(d_sq)
	# Check server proxies (net_player_proxy group)
	for node in get_tree().get_nodes_in_group("net_player_proxy"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var proxy_node := node as Node3D
		var d_sq := global_position.distance_squared_to(proxy_node.global_position)
		if d_sq > closest_dist_sq:
			continue
		var dir := (proxy_node.global_position - global_position).normalized()
		if fwd.dot(dir) < 0.3:
			continue
		closest_target = proxy_node
		closest_dist_sq = d_sq
		closest_dist = sqrt(d_sq)
	# Check remote player avatars (puppets on clients)
	var scene := get_tree().current_scene
	if scene != null and scene.get("remote_players") != null:
		for pid in scene.remote_players.keys():
			var rp: Node3D = scene.remote_players[pid]
			if not is_instance_valid(rp):
				continue
			var d_sq := global_position.distance_squared_to(rp.global_position)
			if d_sq > closest_dist_sq:
				continue
			var dir := (rp.global_position - global_position).normalized()
			if fwd.dot(dir) < 0.3:
				continue
			closest_target = rp
			closest_dist_sq = d_sq
			closest_dist = sqrt(d_sq)
	if closest_target != null:
		if closest_target.has_method("take_damage"):
			# Wildlife recibe el atacante: un lobo al que golpeas pierde la
			# confianza ganada y uno domesticado se defiende.
			if closest_target is WildlifeController:
				closest_target.take_damage(base_damage, is_knife, self)
			else:
				closest_target.take_damage(base_damage, is_knife)
		elif closest_target.is_in_group("net_player_proxy"):
			# Server proxy: apply damage directly on server
			var peer_id: int = closest_target.get_meta("peer_id", 0)
			var is_dead: bool = closest_target.get_meta("proxy_dead", false)
			if not is_dead and peer_id != 0:
				var hp: float = closest_target.get_meta("proxy_health", 100.0)
				hp = max(0.0, hp - base_damage)
				closest_target.set_meta("proxy_health", hp)
				if hp <= 0.0:
					closest_target.set_meta("proxy_dead", true)
					closest_target.remove_from_group("net_player_proxy")
					# Drop loot, broadcast death, and force death on client
					var scene_node := get_tree().current_scene
					if scene_node != null:
						if scene_node.has_method("_drop_player_loot"):
							scene_node._drop_player_loot(peer_id, closest_target)
						if scene_node.has_method("_broadcast_player_death") and not closest_target.get_meta("death_broadcasted", false):
							closest_target.set_meta("death_broadcasted", true)
							scene_node._broadcast_player_death(peer_id, closest_target, "melee")
					var net_node2 := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
					if net_node2 != null and net_node2.peer != null and net_node2.peer_alive(peer_id):
						net_node2.force_death_to_client.rpc_id(peer_id, "melee")
				else:
					# Send damage to the client if connected
					var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
					if net_node != null and net_node.peer != null and net_node.peer_alive(peer_id):
						net_node.apply_damage_to_client.rpc_id(peer_id, base_damage, "melee")
		elif closest_target.has_method("apply_damage"):
			closest_target.apply_damage(base_damage)
		if held != null and held.has_method("reduce_durability"):
			held.reduce_durability(5.0)
			if held.is_broken():
				notice.emit("%s se ha roto!" % str(held.item_name))

func _has_rifle_equipped() -> bool:
	if not _rifle_in_hands:
		return false
	var held = get_held_item()
	if held == null:
		return false
	return held.item_type == "weapon_rifle"

# --- Perfil por arma: todo el comportamiento que cambia entre el
# francotirador y el fusil de asalto se decide por el nombre del item.
static func _is_rifle_item_name(item_name: String) -> bool:
	return item_name == RIFLE_NAME or item_name == M4_NAME

func _held_rifle_name() -> String:
	if is_puppet:
		return _puppet_held
	var held = get_held_item()
	return "" if held == null else str(held.item_name)

func _held_is_m4() -> bool:
	return _held_rifle_name() == M4_NAME

func _rifle_mag_size() -> int:
	return M4_MAG_SIZE if _held_is_m4() else RIFLE_MAG_SIZE

func _loaded_rounds() -> int:
	return _m4_magazine if _held_is_m4() else _rifle_magazine

func _set_loaded_rounds(v: int) -> void:
	if _held_is_m4():
		_m4_magazine = v
	else:
		_rifle_magazine = v

func _reserve_rounds() -> int:
	return _m4_reserve_ammo if _held_is_m4() else _rifle_reserve_ammo

func _set_reserve_rounds(v: int) -> void:
	if _held_is_m4():
		_m4_reserve_ammo = v
	else:
		_rifle_reserve_ammo = v

func _rifle_scope_mags() -> Array:
	return M4_SCOPE_MAGNIFICATIONS if _held_is_m4() else SCOPE_MAGNIFICATIONS

func _rifle_cooldown_time() -> float:
	return M4_COOLDOWN if _held_is_m4() else 1.5

func _rifle_model_path_for(item_name: String) -> String:
	return M4_MODEL if item_name == M4_NAME else REAL_RIFLE_MODEL

func _rifle_weapon_scale() -> float:
	return weapon_scale * M4_SCALE_FACTOR if (_mounted_rifle_is_m4 or _held_is_m4()) else weapon_scale

func _current_spread_deg() -> float:
	# Misma regla que _shoot_rifle: mas precision quieto/agachado/tumbado/apuntando
	var spread_deg := 0.6
	if is_crouching or is_sitting:
		spread_deg = 0.20
	if is_prone:
		spread_deg = 0.08
	if _is_aiming:
		spread_deg = .006 if is_prone else (.012 if (is_crouching or is_sitting) else .025)
		if _breath_hold_active: spread_deg *= .7
	if _held_is_m4():
		spread_deg *= M4_SPREAD_MULT
	if is_moving:
		spread_deg *= 2.5
	if not is_on_floor() and not (is_instance_valid(rowing_boat) and _boat_standing):
		spread_deg *= 4.0
	return minf(spread_deg, 12.0)

func _update_crosshair_spread(delta: float) -> void:
	if is_puppet:
		return
	_crosshair_bloom = maxf(0.0, _crosshair_bloom - delta * 90.0)
	var main := get_tree().current_scene
	if main == null or main.get("hud") == null or not main.hud.has_method("set_crosshair_spread"):
		return
	var is_bow_or_throw := _has_bow_equipped() or _has_throwable_weapon_equipped()
	if main.hud.has_method("set_crosshair_bow_aim"):
		main.hud.set_crosshair_bow_aim(_is_aiming and is_bow_or_throw, _has_bow_equipped())
	if _is_aiming and is_bow_or_throw:
		var move_extra := 6.0 if is_moving else 0.0
		var stance_mult := 0.55 if (is_crouching or is_sitting or is_prone) else 1.0
		var bow_gap := (5.5 + move_extra) * stance_mult + _crosshair_bloom
		main.hud.set_crosshair_spread(bow_gap)
		return
	if not _rifle_in_hands or _is_aiming:
		return
	var fov_y := deg_to_rad(camera.fov) if camera != null else deg_to_rad(55.0)
	var vp_h := get_viewport().get_visible_rect().size.y
	var px_per_rad: float = (vp_h * 0.5) / tan(fov_y * 0.5)
	var gap := tan(deg_to_rad(_current_spread_deg())) * px_per_rad + _crosshair_bloom
	main.hud.set_crosshair_spread(gap)

func _update_crosshair(is_rifle: bool) -> void:
	if is_puppet:
		return
	var main := get_tree().current_scene
	if main != null and main.hud != null and main.hud.has_method("set_crosshair_rifle"):
		main.hud.set_crosshair_rifle(is_rifle)

func _update_breath_hold(delta: float, shift_pressed: bool) -> void:
	var just_pressed := shift_pressed and not _breath_shift_pressed
	_breath_shift_pressed = shift_pressed
	_breath_hold_recover = maxf(0.0, _breath_hold_recover - delta)
	if not _is_aiming:
		_breath_hold_active = false
		return
	if just_pressed and not _breath_hold_active and _breath_hold_recover <= 0.0:
		_breath_hold_active = true
		_breath_hold_timer = 0.0
	if _breath_hold_active:
		_breath_hold_timer = minf(BREATH_HOLD_DURATION, _breath_hold_timer + delta)
		if _breath_hold_timer >= BREATH_HOLD_DURATION:
			_breath_hold_active = false
			_breath_hold_recover = 4.0

func _update_scope_zoom() -> void:
	if _has_bow_equipped() or _has_throwable_weapon_equipped():
		var p_mag := 1.45 if _has_bow_equipped() else 1.25
		if camera != null:
			camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_camera_fov) * 0.5) / p_mag))
		mouse_sensitivity = 0.0025 / p_mag
		return
	var mags := _rifle_scope_mags()
	_scope_zoom_index = clampi(_scope_zoom_index, 0, mags.size() - 1)
	var magnification: float = mags[_scope_zoom_index]
	if camera != null:
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(_camera_fov)*0.5)/magnification))
	mouse_sensitivity = 0.0025 / magnification
	if is_instance_valid(_scope_overlay): _scope_overlay.queue_redraw()

func _toggle_aim() -> void:
	_is_aiming = not _is_aiming
	if _is_aiming:
		if _has_rifle_equipped():
			_create_scope_overlay()
		_update_scope_zoom()
		if third_person_model != null and _has_rifle_equipped():
			third_person_model.visible = false
		_breath_hold_active = false
		_breath_hold_timer = 0.0
		_breath_hold_recover = 0.0
		if _has_bow_equipped():
			play_action_animation("bow_shoot", 0.52)
			var ac := _count_inventory_arrows()
			notice.emit("Apuntando con arco (%d flechas). Clic izq: disparar." % ac if ac > 0 else "No tienes flechas en el inventario.")
		elif _has_throwable_weapon_equipped():
			var h_it = get_held_item()
			var h_nm := str(h_it.item_name) if h_it != null else "arma"
			notice.emit("Apuntando con %s. Clic izq: lanzar." % h_nm)
			_throw_aim_hold = true
			_throw_aim_frozen = false
			if h_nm in ["Lanza", "Lanza de hueso", "Palo afilado"] and not _bow_aim_idle_animation.is_empty():
				third_person_action_timer = 0.0
				third_person_action_animation = ""
			else:
				_start_throw_animation()
	else:
		_throw_aim_hold = false
		_throw_aim_frozen = false
		if not _throw_charging and third_person_animation_player != null:
			third_person_animation_player.speed_scale = 1.0
		_remove_scope_overlay()
		if camera != null:
			camera.fov = _camera_fov
		mouse_sensitivity = 0.0025
		if third_person_model != null:
			third_person_model.visible = true
		_breath_hold_active = false

func _cancel_aim() -> void:
	if not _is_aiming:
		return
	_is_aiming = false
	_breath_hold_active = false
	_throw_aim_hold = false
	_throw_aim_frozen = false
	if not _throw_charging and third_person_animation_player != null:
		third_person_animation_player.speed_scale = 1.0
	_remove_scope_overlay()
	if camera != null:
		camera.fov = _camera_fov
	mouse_sensitivity = 0.0025
	if third_person_model != null:
		third_person_model.visible = true

func _create_scope_overlay() -> void:
	_remove_scope_overlay()
	var scope_script: GDScript = load("res://scripts/ScopeOverlay.gd")
	_scope_overlay = scope_script.new()
	_scope_overlay.name = "ScopeOverlay"
	var scope_layer := CanvasLayer.new()
	scope_layer.name = "ScopeCanvas"
	scope_layer.layer = 9
	get_tree().current_scene.add_child(scope_layer)
	scope_layer.add_child(_scope_overlay)

func _remove_scope_overlay() -> void:
	if _scope_overlay != null and is_instance_valid(_scope_overlay):
		var scope_parent := _scope_overlay.get_parent()
		if scope_parent is CanvasLayer:
			scope_parent.queue_free()
		else:
			_scope_overlay.queue_free()
	_scope_overlay = null

func _initialize_rifle_ammo() -> void:
	if _held_is_m4():
		if _m4_ammo_initialized:
			return
		_m4_ammo_initialized = true
		_m4_magazine = M4_MAG_SIZE
		if _m4_reserve_ammo <= 0:
			_m4_reserve_ammo = M4_MAG_SIZE * 3
		return
	if _rifle_ammo_initialized:
		return
	_rifle_ammo_initialized = true
	_rifle_magazine = RIFLE_MAG_SIZE
	if _equipped_slots.get("chaleco", "") == "Chaleco táctico":
		_rifle_reserve_ammo = maxi(_rifle_reserve_ammo, RIFLE_MAG_SIZE * 5)
	elif _rifle_reserve_ammo <= 0:
		_rifle_reserve_ammo = RIFLE_MAG_SIZE * 3

func get_vest_magazines_count() -> int:
	var mag_size := _rifle_mag_size()
	return int(ceil(float(maxi(0, _reserve_rounds())) / float(mag_size)))

func _reload_rifle() -> void:
	var rifle = get_held_item()
	if is_dead or rifle == null or rifle.item_type != "weapon_rifle":
		return
	if _is_reloading:
		return
	var mag_size := _rifle_mag_size()
	var needed := mag_size - _loaded_rounds()
	if needed <= 0:
		notice.emit("Cargador lleno (%d/%d). Reserva: %d cargadores (%d balas)." % [_loaded_rounds(), mag_size, get_vest_magazines_count(), _reserve_rounds()])
		return
	if _reserve_rounds() <= 0:
		notice.emit("Sin cargadores ni munición de reserva.")
		return
	_is_reloading = true
	_rifle_burst_revision += 1
	var selection_revision := _held_selection_revision
	notice.emit("Recargando fusil...")
	await get_tree().create_timer(2.2).timeout
	_is_reloading = false
	if is_dead or get_held_item() != rifle or selection_revision != _held_selection_revision:
		return
	var to_load: int = min(needed, _reserve_rounds())
	_set_reserve_rounds(_reserve_rounds() - to_load)
	_set_loaded_rounds(_loaded_rounds() + to_load)
	_is_reloading = false
	var mags_left := get_vest_magazines_count()
	notice.emit("Fusil recargado: %d/%d en cargador · %d cargadores en reserva (%d balas)." % [_loaded_rounds(), mag_size, mags_left, _reserve_rounds()])
	var main := get_tree().current_scene
	if main != null and main.get("hud") != null:
		if main.hud.has_method("_update_equipment_labels"):
			main.hud._update_equipment_labels()
		if main.hud.has_method("_update_inventory"):
			main.hud._update_inventory()
	if main != null and main.has_method("_sync_local_player_inventory"):
		main.call_deferred("_sync_local_player_inventory")

func _load_ammo_item(item, index := -1) -> void:
	if item == null or inventory == null or str(item.item_type) != "ammo":
		return
	var idx: int = index if index >= 0 else inventory.items.find(item)
	if idx < 0:
		return
	# La 5.56 del M4 va a su propia reserva; el resto alimenta el 7.62 del
	# francotirador. Los nombres de los items de municion deciden el calibre.
	var ammo_name := str(item.item_name)
	var is_556 := ammo_name.findn("5.56") >= 0 or ammo_name.findn("5,56") >= 0 or ammo_name.findn("m4") >= 0 or ammo_name.findn("asalto") >= 0
	var rounds := M4_MAG_SIZE if is_556 else RIFLE_MAG_SIZE
	if item.use_value > 0.0:
		rounds = int(item.use_value)
	inventory.remove_index(idx, 1)
	if is_556:
		_m4_reserve_ammo += rounds
	else:
		_rifle_reserve_ammo += rounds
	notice.emit("Munición guardada: +%d balas de reserva (%d en total). Mantén el fusil en las manos y pulsa [R] para recargar." % [rounds, _m4_reserve_ammo if is_556 else _rifle_reserve_ammo])
	var main := get_tree().current_scene
	if main != null and main.get("hud") != null:
		if main.hud.has_method("_update_equipment_labels"):
			main.hud._update_equipment_labels()
		if main.hud.has_method("_update_inventory"):
			main.hud._update_inventory()
	if main != null and main.has_method("_sync_local_player_inventory"):
		main.call_deferred("_sync_local_player_inventory")

func get_rifle_info(weapon_name := "") -> Dictionary:
	var is_m4 := _held_is_m4() if weapon_name.is_empty() else weapon_name == M4_NAME
	if is_m4:
		return {
			"name": M4_NAME,
			"ammo_type": M4_AMMO_TYPE,
			"magazine": _m4_magazine,
			"mag_size": M4_MAG_SIZE,
			"reserve": _m4_reserve_ammo,
			"magazines_left": int(ceil(float(maxi(0, _m4_reserve_ammo)) / float(M4_MAG_SIZE))),
			"damage": M4_DAMAGE,
			"range": RIFLE_RANGE,
			"magnification": M4_SCOPE_MAGNIFICATIONS[0],
			"zoom_fixed": true,
			"iron_sights": true,
			"zero_range": 100.0,
			"scope_fov": camera.fov if camera != null else 40.0,
		}
	return {
		"name": RIFLE_NAME,
		"ammo_type": RIFLE_AMMO_TYPE,
		"magazine": _rifle_magazine,
		"mag_size": RIFLE_MAG_SIZE,
		"reserve": _rifle_reserve_ammo,
		"magazines_left": get_vest_magazines_count(),
		"damage": RIFLE_DAMAGE,
		"range": RIFLE_RANGE,
		"magnification": _rifle_scope_mags()[clampi(_scope_zoom_index, 0, _rifle_scope_mags().size() - 1)],
		"zoom_fixed": false,
		"iron_sights": false,
		"zero_range": 100.0,
		"scope_fov": camera.fov if camera != null else 15.0,
	}

func get_wind_info() -> Dictionary:
	return {
		"strength": _wind_strength,
		"direction": _wind_dir,
		"target_strength": _wind_target_strength,
	}

func _rifle_sight_hit(origin: Vector3, direction: Vector3, excluded: Array[RID]) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * RIFLE_RANGE, 5)
	query.exclude = excluded.duplicate()
	query.collide_with_areas = true
	query.hit_from_inside = true
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	while not hit.is_empty() and hit.collider is Area3D and not "hitbox" in str(hit.collider.name).to_lower():
		var ignored := query.exclude
		ignored.append(hit.rid)
		query.exclude = ignored
		hit = space.intersect_ray(query)
	var world := get_tree().current_scene
	if world != null and world.has_method("raycast_distant_props"):
		var endpoint: Vector3 = hit.position if not hit.is_empty() else query.to
		var distant: Dictionary = world.raycast_distant_props(origin, endpoint)
		if not distant.is_empty():
			hit = distant
	return hit

func _apply_rifle_recoil(is_m4: bool) -> void:
	var recoil_kick := M4_RECOIL if is_m4 else 8.0
	if is_prone:
		recoil_kick *= 0.375
	elif is_crouching:
		recoil_kick *= 0.625
	if _is_aiming:
		recoil_kick *= 0.7
	_recoil_pitch -= deg_to_rad(recoil_kick)
	_recoil_yaw += deg_to_rad(randf_range(-recoil_kick * 0.4, recoil_kick * 0.4))
	if camera != null:
		camera.rotation.x = _pitch + _recoil_pitch + _breath_pitch_offset
		camera.rotation.y = _recoil_yaw + _breath_yaw_offset

func _shoot_rifle() -> void:
	var held = get_held_item()
	if is_dead or _is_reloading or camera == null or held == null or held.item_type != "weapon_rifle":
		return
	# Capture the sight line before recoil moves the camera.
	var aim_point := camera.get_viewport().get_visible_rect().size * 0.5 + (Vector2.ZERO if _is_aiming else _aim_screen_offset)
	var cam_ray_origin := camera.project_ray_origin(aim_point)
	var cam_ray_dir := camera.project_ray_normal(aim_point)
	if _shoot_cooldown > 0.0:
		return
	if _loaded_rounds() <= 0:
		if _reserve_rounds() > 0:
			notice.emit("Cargador vacío. Recargando... (o pulsa [R])")
			_reload_rifle()
		else:
			notice.emit("Sin munición. No quedan cargadores ni balas de reserva.")
		return
	var is_m4_shot := _held_is_m4()
	var energy_cost := M4_ENERGY_COST if is_m4_shot else 3.0
	if stats.energy < energy_cost:
		notice.emit("Estas demasiado cansado para disparar.")
		return
	var burst_rounds := mini(M4_BURST_ROUNDS, _loaded_rounds()) if is_m4_shot else 1
	# Consume only rounds that actually leave the barrel.
	_set_loaded_rounds(_loaded_rounds() - 1)
	_rifle_burst_revision += 1
	var burst_revision := _rifle_burst_revision
	var selection_revision := _held_selection_revision
	_shoot_cooldown = _rifle_cooldown_time()
	_crosshair_bloom = minf(_crosshair_bloom + 26.0, 60.0)
	stats.energy = max(0.0, stats.energy - energy_cost)
	stats.changed.emit()
	_is_firing = true
	var main_shot := get_tree().current_scene if is_inside_tree() else null
	if main_shot != null and main_shot.has_method("_sync_local_player_inventory"):
		main_shot.call_deferred("_sync_local_player_inventory")
	# Notify nearby wildlife of gunshot — all animals flee running
	var gunshot_pos := global_position
	for w in get_tree().get_nodes_in_group("wildlife"):
		if w == null or not is_instance_valid(w):
			continue
		if w.has_method("flee_from_gunshot"):
			w.flee_from_gunshot(gunshot_pos, 120.0)
	_apply_rifle_recoil(is_m4_shot)
	if third_person_animation_player != null:
		var fire_anim_name := ""
		if is_prone and not _rifle_prone_fire_animation.is_empty():
			fire_anim_name = _rifle_prone_fire_animation
		elif is_sitting and not _rifle_sit_fire_animation.is_empty():
			fire_anim_name = _rifle_sit_fire_animation
		elif not _rifle_fire_animation.is_empty():
			fire_anim_name = _rifle_fire_animation
		if not fire_anim_name.is_empty():
			var fire_anim := third_person_animation_player.get_animation(fire_anim_name)
			if fire_anim != null:
				fire_anim.loop_mode = Animation.LOOP_NONE
			third_person_action_animation = fire_anim_name
			third_person_action_timer = 1.0
			third_person_animation_player.play(fire_anim_name, 0.05)
	if not _is_aiming and not is_sitting and not is_prone:
		_update_rifle_visuals(0.0)
		_on_skeleton_updated()
	_play_shoot_sound(is_m4_shot)
	var space_state := get_world_3d().direct_space_state
	if _cached_rids_dirty:
		_cached_exclude_rids = [self.get_rid()]
		_collect_child_collision_rids(self, _cached_exclude_rids)
		_cached_rids_dirty = false
	var exclude_arr: Array[RID] = _cached_exclude_rids.duplicate()
	if is_instance_valid(rowing_boat):
		exclude_arr.append(rowing_boat.get_rid())
		_collect_child_collision_rids(rowing_boat, exclude_arr)
	var aim_dir: Vector3 = cam_ray_dir.normalized()
	var spread_rad := deg_to_rad(_current_spread_deg())
	# Uniform disk spread, without the old square-shaped distribution.
	var angle := randf()*TAU
	var radius := sqrt(randf())*tan(spread_rad)
	var right := camera.global_basis.x.normalized()
	var up := right.cross(aim_dir).normalized()
	aim_dir = (aim_dir+right*cos(angle)*radius+up*sin(angle)*radius).normalized()
	var shot_origin := global_position + Vector3(0, 0.3 if is_prone else (1.0 if is_crouching else 1.4), 0)
	# La bala nace en la boca del cañón solo si su transform sigue la línea de
	# puntería real — un WeaponOffset/top_level estaleado no debe desplazar el
	# origen fuera del eje de mira ni desviar el tiro.
	if is_instance_valid(_rifle_muzzle):
		var muzzle_pos: Vector3 = _rifle_muzzle.global_position
		var muzzle_off := muzzle_pos - cam_ray_origin
		var muzzle_along := muzzle_off.dot(cam_ray_dir)
		var muzzle_lateral := (muzzle_off - cam_ray_dir * muzzle_along).length()
		if muzzle_pos.is_finite() and muzzle_along > -0.6 and muzzle_along < 3.5 and muzzle_lateral < 0.9:
			shot_origin = muzzle_pos
	# Fixed 100 m optical zero in ADS; in third-person hip-fire, converge the
	# muzzle onto whatever is under the crosshair ray so the 6.5 m camera
	# offset does not send close shots below the target.
	var muzzle_speed := M4_MUZZLE_SPEED if _held_is_m4() else RIFLE_MUZZLE_SPEED
	var converge_dist := 100.0
	if not _is_aiming and space_state != null:
		var sight_hit := _rifle_sight_hit(cam_ray_origin, cam_ray_dir, exclude_arr)
		if not sight_hit.is_empty():
			var hit_d := cam_ray_origin.distance_to(sight_hit.position)
			if hit_d > 2.5:
				converge_dist = clampf(hit_d, 3.0, RIFLE_RANGE)
	var zero_target := cam_ray_origin + aim_dir * converge_dist
	var drop_dist := minf(shot_origin.distance_to(zero_target), 100.0)
	var flight_time := -log(maxf(0.05, 1.0 - drop_dist * 0.12 / muzzle_speed)) / 0.12
	zero_target.y += 0.5 * 9.81 * flight_time * flight_time
	aim_dir = (zero_target - shot_origin).normalized()
	if aim_dir.length_squared() < 0.5:
		aim_dir = cam_ray_dir
	# A muzzle pushed through cover must not shoot through that cover.
	var obstruction := PhysicsRayQueryParameters3D.create(cam_ray_origin, shot_origin, 5)
	obstruction.exclude = exclude_arr
	obstruction.collide_with_areas = false
	obstruction.hit_from_inside = true
	var blocked := space_state.intersect_ray(obstruction)
	if not blocked.is_empty():
		shot_origin = blocked.position - aim_dir*.01
	var shot_wind := _wind_dir * _wind_strength
	_launch_rifle_projectile(shot_origin, aim_dir, shot_wind, exclude_arr, true, is_m4_shot)
	# Fogonazo en la punta REAL del cañon (sin rayo/trazadora).
	var flash_pos: Vector3 = shot_origin
	_spawn_muzzle_flash(flash_pos, aim_dir)
	for extra_i in range(1, burst_rounds):
		get_tree().create_timer(0.09 * float(extra_i)).timeout.connect(func():
			if not is_inside_tree() or is_dead or _is_reloading or camera == null or not _held_is_m4() or get_held_item() != held or _held_selection_revision != selection_revision or _rifle_burst_revision != burst_revision or _loaded_rounds() <= 0:
				return
			var b_vp := camera.get_viewport().get_visible_rect().size * 0.5 + (Vector2.ZERO if _is_aiming else _aim_screen_offset)
			var b_cam_orig := camera.project_ray_origin(b_vp)
			var b_cam_dir := camera.project_ray_normal(b_vp).normalized()
			var b_right := camera.global_basis.x.normalized()
			var b_up := b_right.cross(b_cam_dir).normalized()
			var b_ang := randf() * TAU
			var b_rad := sqrt(randf()) * tan(spread_rad * 1.15)
			var b_aim := (b_cam_dir + b_right * cos(b_ang) * b_rad + b_up * sin(b_ang) * b_rad).normalized()
			var b_origin := global_position + Vector3(0, 0.3 if is_prone else (1.0 if is_crouching else 1.4), 0)
			if is_instance_valid(_rifle_muzzle):
				var b_muzzle_pos: Vector3 = _rifle_muzzle.global_position
				var b_off := b_muzzle_pos - b_cam_orig
				var b_along := b_off.dot(b_cam_dir)
				var b_lateral := (b_off - b_cam_dir * b_along).length()
				if b_muzzle_pos.is_finite() and b_along > -0.6 and b_along < 3.5 and b_lateral < 0.9:
					b_origin = b_muzzle_pos
			var b_space := get_world_3d().direct_space_state
			var b_conv := 100.0
			if not _is_aiming and b_space != null:
				var b_sh := _rifle_sight_hit(b_cam_orig, b_cam_dir, exclude_arr)
				if not b_sh.is_empty():
					var b_hd := b_cam_orig.distance_to(b_sh.position)
					if b_hd > 2.5:
						b_conv = clampf(b_hd, 3.0, RIFLE_RANGE)
			var b_zero := b_cam_orig + b_aim * b_conv
			var b_drop_d := minf(b_origin.distance_to(b_zero), 100.0)
			var b_ft := -log(maxf(0.05, 1.0 - b_drop_d * 0.12 / M4_MUZZLE_SPEED)) / 0.12
			b_zero.y += 0.5 * 9.81 * b_ft * b_ft
			var b_dir := (b_zero - b_origin).normalized()
			if b_dir.length_squared() < 0.5:
				b_dir = b_cam_dir
			if b_space != null:
				var b_obs := PhysicsRayQueryParameters3D.create(b_cam_orig, b_origin, 5)
				b_obs.exclude = exclude_arr
				b_obs.collide_with_areas = false
				b_obs.hit_from_inside = true
				var b_blk := b_space.intersect_ray(b_obs)
				if not b_blk.is_empty():
					b_origin = b_blk.position - b_dir * 0.01
			_apply_rifle_recoil(true)
			_set_loaded_rounds(_loaded_rounds() - 1)
			_launch_rifle_projectile(b_origin, b_dir, shot_wind, exclude_arr, true, true)
			var world := get_tree().current_scene
			if world != null and world.has_method("_sync_local_player_inventory"):
				world.call_deferred("_sync_local_player_inventory")
			if world != null and world.get("hud") != null and world.hud.has_method("_update_equipment_labels"):
				world.hud._update_equipment_labels()
			_spawn_muzzle_flash(b_origin, b_dir)
			if not is_puppet:
				var b_net := get_node_or_null("/root/NetworkManager")
				if b_net != null and b_net.is_connected:
					b_net.player_shot_rifle.rpc_id(1, b_net.get_my_id(), b_origin, b_dir, shot_wind))
	if _is_aiming and _scope_overlay != null and is_instance_valid(_scope_overlay) and _scope_overlay.has_method("muzzle_flash"):
		_scope_overlay.muzzle_flash()
	if not is_puppet:
		var net_node := get_node_or_null("/root/NetworkManager")
		if net_node != null and net_node.is_connected:
			net_node.player_shot_rifle.rpc_id(1, net_node.get_my_id(), shot_origin, aim_dir, shot_wind)
	# Refrescar contador de municion en el HUD
	var main := get_tree().current_scene
	if main != null and main.get("hud") != null and main.hud.has_method("_update_equipment_labels"):
		main.hud._update_equipment_labels()

func _apply_rifle_damage(collider, hit_pos: Vector3, hit_dist: float, hit_normal: Vector3 = Vector3.UP, is_m4 := false) -> void:
	# Smooth energy loss; damage remains a game abstraction rather than a medical model.
	var damage := (M4_DAMAGE if is_m4 else RIFLE_DAMAGE) * exp(-0.0002 * hit_dist)
	var is_headshot := false
	if collider is Node3D:
		var node: Node3D = collider as Node3D
		# Find the damageable entity by walking up the tree, skipping self
		var target_node: Node = null
		if node.name == "HeadHitbox":
			is_headshot = true
			var parent: Node = node.get_parent()
			while parent != null:
				if parent == self:
					break
				if parent.has_method("take_damage") and _is_rifle_damage_target(parent):
					target_node = parent
					break
				parent = parent.get_parent()
		elif node.name == "BodyHitbox":
			var parent: Node = node.get_parent()
			while parent != null:
				if parent == self:
					break
				if parent.has_method("take_damage") and _is_rifle_damage_target(parent):
					target_node = parent
					break
				parent = parent.get_parent()
		else:
			var walked: Node = node
			while walked != null:
				if walked == self:
					break
				if walked.has_method("take_damage") and _is_rifle_damage_target(walked):
					target_node = walked
					break
				walked = walked.get_parent()
		if target_node != null:
			var is_player_target := target_node.is_in_group("remote_player") or target_node.is_in_group("net_player_proxy")
			if is_player_target:
				# PvP rifle balance: headshot is a lethal 1-shot kill (120 dmg),
				# bodyshot deals 60 dmg (2 shots to kill a 100 HP player).
				var pvp_dmg := ((M4_PVP_HEAD if is_headshot else M4_PVP_BODY) if is_m4
					else (120.0 if is_headshot else 60.0))
				_apply_rifle_target_damage(target_node, pvp_dmg * exp(-0.0002 * hit_dist))
				_spawn_blood_splatter(hit_pos, 1.8 if is_headshot else 1.3)
				_hit_marker(bool(target_node.get("is_dead")))
				notice.emit("¡Disparo en la cabeza!" if is_headshot else "¡Impacto al jugador!")
				return
			if is_headshot:
				_apply_rifle_target_damage(target_node, damage * 3.0)
			else:
				_apply_rifle_target_damage(target_node, damage)
			_spawn_blood_splatter(hit_pos)
			_hit_marker(bool(target_node.get("_is_dead")))
			return
		# Handle net_player_proxy directly
		if node.is_in_group("net_player_proxy"):
			var peer_id: int = node.get_meta("peer_id", 0)
			var is_proxy_dead: bool = node.get_meta("proxy_dead", false)
			if not is_proxy_dead and peer_id != 0:
				var proxy_dmg := ((M4_PVP_HEAD if is_headshot else M4_PVP_BODY) if is_m4
					else (120.0 if is_headshot else 60.0))
				proxy_dmg *= exp(-0.0002 * hit_dist)
				var scene_node := get_tree().current_scene
				if scene_node != null and scene_node.has_method("_net_damage_player"):
					var my_id := 1
					var net_node := scene_node.get_node_or_null("/root/NetworkManager")
					if net_node != null and net_node.has_method("get_my_id"):
						my_id = net_node.get_my_id()
					scene_node._net_damage_player(peer_id, proxy_dmg, my_id, "rifle")
				else:
					var hp: float = node.get_meta("proxy_health", 100.0)
					hp = max(0.0, hp - proxy_dmg)
					node.set_meta("proxy_health", hp)
					node.set_meta("saved_health", hp)
					if hp <= 0.0:
						node.set_meta("proxy_dead", true)
						node.remove_from_group("net_player_proxy")
						if scene_node != null:
							if scene_node.has_method("_drop_player_loot"):
								scene_node._drop_player_loot(peer_id, node)
							if scene_node.has_method("_broadcast_player_death") and not node.get_meta("death_broadcasted", false):
								node.set_meta("death_broadcasted", true)
								scene_node._broadcast_player_death(peer_id, node)
					else:
						var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
						if net_node != null and net_node.peer != null and net_node.peer.has_peer(peer_id):
							net_node.apply_damage_to_client.rpc_id(peer_id, proxy_dmg, "rifle")
			_spawn_blood_splatter(hit_pos)
			_hit_marker(true)
			return
		if node.has_method("apply_damage"):
			node.apply_damage(damage)
	# Non-living surface: dust puff, debris chips and a bullet hole decal
	_alert_wildlife_near_point(hit_pos, 85.0)
	_spawn_bullet_impact(hit_pos, hit_normal, collider)

func _is_rifle_damage_target(node: Node) -> bool:
	return node.is_in_group("wildlife") or node.is_in_group("npc") or node.is_in_group("net_player_proxy") or node.is_in_group("remote_player")

func _apply_rifle_target_damage(target: Node, amount: float) -> void:
	# Remote-player puppets report the weapon so the server can validate the
	# shot distance per weapon type; NPCs use their own two-arg signature.
	if target.is_in_group("remote_player"):
		target.take_damage(amount, false, "rifle")
	elif target is WildlifeController:
		target.take_damage(amount, false, self)
	else:
		target.take_damage(amount, false)

func _spawn_bullet_tracer(from_pos: Vector3, dir: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null or dir.length_squared() < 0.001:
		return
	# Short-lived bright streak so remote shots are seen, not only heard.
	var tracer := MeshInstance3D.new()
	tracer.name = "BulletTracer"
	var mesh := BoxMesh.new()
	var length := 14.0
	mesh.size = Vector3(0.02, 0.02, length)
	tracer.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.55, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.35)
	mat.emission_energy_multiplier = 3.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tracer.material_override = mat
	scene.add_child(tracer)
	var forward := dir.normalized()
	tracer.global_position = from_pos + forward * (length * 0.5)
	tracer.look_at(from_pos + forward * length, Vector3.UP)
	var t := get_tree().create_timer(0.09)
	t.timeout.connect(func(): if is_instance_valid(tracer): tracer.queue_free())

func _spawn_blood_splatter(at_pos: Vector3 = Vector3.ZERO, strength: float = 1.0) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pos := at_pos if at_pos != Vector3.ZERO else global_position + Vector3(0, 1.2, 0)
	# Gotas: pequenas, rapidas, con gravedad fuerte
	var drops := GPUParticles3D.new()
	drops.name = "BloodDrops"
	drops.amount = max(4, int(40 * strength))
	drops.lifetime = 0.8
	drops.explosiveness = 1.0
	drops.randomness = 0.9
	drops.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 70.0
	mat.initial_velocity_min = 3.0 * strength
	mat.initial_velocity_max = 8.0 * strength
	mat.gravity = Vector3(0, -18.0, 0)
	mat.scale_min = 0.4
	mat.scale_max = 1.1
	mat.color = Color(0.45, 0.01, 0.01, 1.0)
	mat.hue_variation_min = -0.02
	mat.hue_variation_max = 0.02
	mat.color_ramp = _make_fade_ramp(0.03, 0.75)
	drops.process_material = mat
	drops.draw_pass_1 = _make_soft_mesh(Vector2(0.05, 0.05), Color.WHITE)
	scene.add_child(drops)
	drops.global_position = pos
	drops.emitting = true
	# Niebla: nube roja oscura que se expande y disipa
	var mist := GPUParticles3D.new()
	mist.name = "BloodMist"
	mist.amount = max(2, int(14 * strength))
	mist.lifetime = 0.7
	mist.explosiveness = 0.8
	mist.randomness = 1.0
	mist.one_shot = true
	var mmat := ParticleProcessMaterial.new()
	mmat.direction = Vector3(0, 0.4, 0)
	mmat.spread = 80.0
	mmat.initial_velocity_min = 0.5
	mmat.initial_velocity_max = 2.2
	mmat.gravity = Vector3(0, -0.8, 0)
	mmat.damping_min = 1.5
	mmat.damping_max = 3.0
	mmat.scale_min = 0.4
	mmat.scale_max = 0.9
	mmat.color = Color(0.35, 0.0, 0.0, 0.55)
	mmat.color_ramp = _make_fade_ramp(0.08, 0.5)
	var mist_scale := CurveTexture.new()
	var mist_curve := Curve.new()
	mist_curve.add_point(Vector2(0.0, 0.5))
	mist_curve.add_point(Vector2(1.0, 1.8))
	mist_scale.curve = mist_curve
	mmat.scale_curve = mist_scale
	mist.process_material = mmat
	mist.draw_pass_1 = _make_soft_mesh(Vector2(0.22, 0.22), Color.WHITE)
	scene.add_child(mist)
	mist.global_position = pos
	mist.emitting = true
	get_tree().create_timer(2.0).timeout.connect(func(): drops.queue_free(); mist.queue_free())

# --- Impactos en superficies no vivas ---
static var _bullet_hole_texture: Texture2D = null
static var _soft_particle_texture: Texture2D = null
static var _bullet_holes: Array = []
const MAX_BULLET_HOLES := 160

func _get_soft_particle_texture() -> Texture2D:
	if _soft_particle_texture != null:
		return _soft_particle_texture
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var d: float = (Vector2(x, y) - center).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = pow(a, 1.8)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	_soft_particle_texture = ImageTexture.create_from_image(img)
	return _soft_particle_texture

func _make_fade_ramp(fade_in_end := 0.15, fade_out_start := 0.55) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.add_point(fade_in_end, Color(1, 1, 1, 1.0))
	grad.add_point(fade_out_start, Color(1, 1, 1, 0.85))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex

func _make_soft_mesh(sz: Vector2, color: Color) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = sz
	var m := StandardMaterial3D.new()
	m.albedo_texture = _get_soft_particle_texture()
	m.albedo_color = color
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	quad.material = m
	return quad

func _hit_marker(lethal: bool) -> void:
	var main := get_tree().current_scene
	if main != null and main.get("hud") != null and main.hud.has_method("show_hit_marker"):
		main.hud.show_hit_marker(lethal)

func _spawn_bullet_impact(hit_pos: Vector3, hit_normal: Vector3, collider) -> void:
	if hit_normal.length_squared() < 0.01:
		hit_normal = Vector3.UP
	hit_normal = hit_normal.normalized()
	var dust_color := _guess_surface_dust_color(hit_normal, collider)
	var names := ""
	var surface: Node = collider as Node
	for i in 6:
		if surface == null: break
		names += String(surface.name).to_lower()+"|"
		surface = surface.get_parent()
	var water := "water" in names or "agua" in names
	var metal := "metal" in names or "barrel" in names or "vehicle" in names or "car_" in names
	_spawn_impact_dust(hit_pos, hit_normal, dust_color)
	_spawn_impact_chips(hit_pos, hit_normal, dust_color, metal)
	if not water:
		_spawn_bullet_hole_decal(hit_pos, hit_normal, collider)

func _guess_surface_dust_color(hit_normal: Vector3, collider) -> Color:
	# Heuristica por nombre del collider y sus padres
	var path_names := ""
	var c: Node = collider as Node
	var depth := 0
	while c != null and depth < 6:
		path_names += str(c.name).to_lower() + "|"
		c = c.get_parent()
		depth += 1
	if "water" in path_names or "agua" in path_names or "lake" in path_names or "lago" in path_names:
		return Color(0.75, 0.82, 0.9, 0.7)   # salpicadura
	if "wood" in path_names or "madera" in path_names or "tree" in path_names or "arbol" in path_names or "tronco" in path_names or "barn" in path_names or "granero" in path_names or "fence" in path_names or "door" in path_names or "puerta" in path_names or "hut" in path_names or "refugio" in path_names or "plank" in path_names:
		return Color(0.5, 0.38, 0.24, 0.85)  # madera
	if "metal" in path_names or "tent" in path_names or "tienda" in path_names or "barrel" in path_names or "bidon" in path_names:
		return Color(0.7, 0.68, 0.6, 0.85)   # metal
	if "wall" in path_names or "pared" in path_names or "house" in path_names or "casa" in path_names or "stone" in path_names or "piedra" in path_names or "rock" in path_names or "roca" in path_names or "concrete" in path_names or "boulder" in path_names or "brick" in path_names or "ladrillo" in path_names:
		return Color(0.6, 0.58, 0.52, 0.85)  # piedra/hormigon
	if hit_normal.y > 0.6:
		return Color(0.48, 0.38, 0.26, 0.8)  # tierra
	return Color(0.55, 0.52, 0.46, 0.8)    # generico

func _spawn_impact_dust(hit_pos: Vector3, hit_normal: Vector3, color: Color) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var particles := GPUParticles3D.new()
	particles.name = "BulletDust"
	particles.amount = 36
	particles.lifetime = 1.65
	particles.explosiveness = 0.82
	particles.randomness = 0.92
	particles.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = hit_normal
	mat.spread = 68.0
	mat.initial_velocity_min = 0.9
	mat.initial_velocity_max = 3.8
	mat.gravity = Vector3(0, -0.35, 0)
	mat.damping_min = 2.2
	mat.damping_max = 4.8
	mat.scale_min = 0.32
	mat.scale_max = 0.88
	mat.color = Color(minf(1.0, color.r + 0.08), minf(1.0, color.g + 0.08), minf(1.0, color.b + 0.08), 0.92)
	mat.hue_variation_min = -0.02
	mat.hue_variation_max = 0.02
	mat.color_ramp = _make_fade_ramp(0.08, 0.55)
	var scale_tex := CurveTexture.new()
	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0.0, 0.4))
	scale_curve.add_point(Vector2(0.35, 1.0))
	scale_curve.add_point(Vector2(1.0, 1.85))
	scale_tex.curve = scale_curve
	mat.scale_curve = scale_tex
	particles.process_material = mat
	particles.draw_pass_1 = _make_soft_mesh(Vector2(0.16, 0.16), Color.WHITE)
	scene.add_child(particles)
	particles.global_position = hit_pos + hit_normal * 0.05
	particles.emitting = true
	# Motas finas de polvo en suspensión alrededor del punto de impacto
	var motes := GPUParticles3D.new()
	motes.name = "BulletDustMotes"
	motes.amount = 28
	motes.lifetime = 2.1
	motes.explosiveness = 0.92
	motes.randomness = 0.95
	motes.one_shot = true
	var mmat := ParticleProcessMaterial.new()
	mmat.direction = (hit_normal + Vector3(0, 0.35, 0)).normalized()
	mmat.spread = 78.0
	mmat.initial_velocity_min = 0.45
	mmat.initial_velocity_max = 2.4
	mmat.gravity = Vector3(0, -0.65, 0)
	mmat.damping_min = 1.2
	mmat.damping_max = 2.6
	mmat.scale_min = 0.35
	mmat.scale_max = 0.95
	mmat.color = Color(minf(1.0, color.r + 0.16), minf(1.0, color.g + 0.15), minf(1.0, color.b + 0.12), 0.95)
	mmat.color_ramp = _make_fade_ramp(0.04, 0.65)
	motes.process_material = mmat
	motes.draw_pass_1 = _make_soft_mesh(Vector2(0.032, 0.032), Color.WHITE)
	scene.add_child(motes)
	motes.global_position = hit_pos + hit_normal * 0.04
	motes.emitting = true
	get_tree().create_timer(3.2).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
		if is_instance_valid(motes):
			motes.queue_free()
	)

func _spawn_impact_chips(hit_pos: Vector3, hit_normal: Vector3, color: Color, sparks: bool = false) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var particles := GPUParticles3D.new()
	particles.name = "BulletChips"
	particles.amount = 22
	particles.lifetime = 0.55
	particles.explosiveness = 1.0
	particles.randomness = 0.75
	particles.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = hit_normal
	mat.spread = 70.0
	mat.initial_velocity_min = 3.5
	mat.initial_velocity_max = 9.0
	mat.gravity = Vector3(0, -16.0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.4
	mat.color = Color(color.r + 0.08, color.g + 0.08, color.b + 0.08, 0.95)
	mat.color_ramp = _make_fade_ramp(0.05, 0.7)
	particles.process_material = mat
	particles.draw_pass_1 = _make_soft_mesh(Vector2(.012,.045) if sparks else Vector2(.025,.025), Color.WHITE)
	if sparks:
		mat.color = Color(1.0,.65,.18,1.0)
		var spark_material := particles.draw_pass_1.material as StandardMaterial3D
		if spark_material != null:
			spark_material.emission_enabled = true
			spark_material.emission = Color(1,.35,.06)
			spark_material.emission_energy_multiplier = 3.0
	scene.add_child(particles)
	particles.global_position = hit_pos + hit_normal * 0.025
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

func _get_bullet_hole_texture() -> Texture2D:
	if _bullet_hole_texture != null:
		return _bullet_hole_texture
	var size := 96
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in range(size):
		for x in range(size):
			var offset := Vector2(x, y) - center
			var d: float = offset.length() / (size * 0.5)
			var angle := atan2(offset.y, offset.x)
			# Borde irregular astillado con grietas radiales
			var crack := maxf(0.0, cos(angle * 7.0 + 0.4) * 0.14 + sin(angle * 13.0 + 1.9) * 0.09)
			var edge := 0.48 + 0.11 * sin(angle * 5.0 + 0.7) + 0.07 * sin(angle * 11.0 + 2.1) + crack
			var a := clampf(1.0 - d / max(edge, 0.01), 0.0, 1.0)
			a = pow(a, 0.48)
			# Centro perforado negro profundo + anillo astillado/desconchado alrededor
			var shade := 0.01 if d < edge * 0.42 else (0.22 if d < edge * 0.72 else 0.08)
			img.set_pixel(x, y, Color(shade, shade * 0.95, shade * 0.88, a * 0.96))
	_bullet_hole_texture = ImageTexture.create_from_image(img)
	return _bullet_hole_texture

func _spawn_bullet_hole_decal(hit_pos: Vector3, hit_normal: Vector3, collider = null) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var is_ground := hit_normal.y > 0.55
	var is_tree_or_rock := false
	var is_building := false
	var can_parent_to_collider := false
	if is_instance_valid(collider) and collider is Node3D:
		var cnode := collider as Node3D
		var cname := str(cnode.name).to_lower()
		var pname := str(cnode.get_parent().name).to_lower() if cnode.get_parent() != null else ""
		if "tree" in cname or "forestcol" in cname or "arbol" in cname or "tronco" in cname or "rock" in cname or "boulder" in cname or "tree" in pname:
			is_tree_or_rock = true
		if "house" in cname or "casa" in cname or "front" in cname or "back" in cname or "left" in cname or "right" in cname or "solid_" in cname or "city_" in pname or "house" in pname or "wall" in cname or "pared" in cname:
			is_building = true
		var cscale := cnode.global_transform.basis.get_scale()
		var uniform_scale := absf(cscale.x - cscale.y) < 0.05 and absf(cscale.y - cscale.z) < 0.05
		if uniform_scale and not ("forestcol" in cname):
			can_parent_to_collider = true
	var mi := MeshInstance3D.new()
	mi.name = "BulletHole"
	var quad := QuadMesh.new()
	var hole_size := 0.20 if is_ground else 0.16
	quad.size = Vector2(hole_size, hole_size)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _get_bullet_hole_texture()
	m.albedo_color = Color.WHITE
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 4
	quad.material = m
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Núcleo volumétrico achatado: garantiza que en troncos curvos de árboles,
	# rocas y terreno con desnivel o hierba la marca nunca quede enterrada.
	var core := MeshInstance3D.new()
	core.name = "BulletHoleCore"
	var core_sphere := SphereMesh.new()
	core_sphere.radius = hole_size * 0.28
	core_sphere.height = hole_size * 0.22
	core_sphere.radial_segments = 10
	core_sphere.rings = 5
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.05, 0.04, 0.035, 0.96)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.render_priority = 5
	core_sphere.material = core_mat
	core.mesh = core_sphere
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.add_child(core)
	if can_parent_to_collider:
		(collider as Node3D).add_child(mi)
	else:
		scene.add_child(mi)
	var surface_offset := 0.038 if is_ground else (0.062 if is_tree_or_rock else (0.056 if is_building else 0.028))
	var pos := hit_pos + hit_normal * surface_offset
	var up := Vector3.UP if absf(hit_normal.y) < 0.95 else Vector3.RIGHT
	var basis_ := Basis.looking_at(-hit_normal, up) * Basis(Vector3.BACK, randf() * TAU)
	mi.global_transform = Transform3D(basis_, pos)
	_bullet_holes.append(mi)
	while _bullet_holes.size() > MAX_BULLET_HOLES:
		var old = _bullet_holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func _spawn_muzzle_flash(at_pos: Vector3, dir: Vector3) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var flash_root := Node3D.new()
	flash_root.name = "MuzzleFlash"
	scene.add_child(flash_root)
	flash_root.global_position = at_pos
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.3)
	light.light_energy = 5.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.5
	flash_root.add_child(light)
	var particles := GPUParticles3D.new()
	particles.amount = 10
	particles.lifetime = 0.09
	particles.one_shot = true
	particles.explosiveness = 1.0
	var mat := ParticleProcessMaterial.new()
	mat.direction = dir
	mat.spread = 12.0
	mat.initial_velocity_min = 6.0
	mat.initial_velocity_max = 14.0
	mat.gravity = Vector3.ZERO
	mat.scale_min = 0.05
	mat.scale_max = 0.12
	mat.color = Color(1.0, 0.75, 0.3, 0.9)
	particles.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.albedo_color = Color(1.0, 0.72, 0.25, 0.9)
	quad_mat.emission_enabled = true
	quad_mat.emission = Color(1.0, 0.6, 0.2)
	quad_mat.emission_energy_multiplier = 3.0
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = quad_mat
	particles.draw_pass_1 = quad
	flash_root.add_child(particles)
	particles.emitting = true
	get_tree().create_timer(0.15).timeout.connect(func():
		if is_instance_valid(light):
			light.light_energy = 0.0)
	get_tree().create_timer(0.4).timeout.connect(func(): flash_root.queue_free())

func _make_action_sound_player(player_name: String, unit_size: float = 6.0, max_distance: float = 45.0) -> Node:
	var p: Node
	if is_puppet:
		var p3 := AudioStreamPlayer3D.new()
		p3.unit_size = unit_size
		p3.max_distance = max_distance
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE
		p = p3
	else:
		p = AudioStreamPlayer.new()
	p.name = player_name
	add_child(p)
	return p

func _play_shoot_sound(is_m4 := false) -> void:
	if _shoot_audio_player == null:
		# A gunshot carries far: full volume inside ~30 m, still audible at
		# the rifle's own max reach (320 m, matches the server reach check).
		_shoot_audio_player = _make_action_sound_player("ShootSound", 30.0, 320.0)
	var use_m4 := is_m4 or _held_is_m4()
	var stream := _load_audio_stream(M4_SHOOT_SOUND if use_m4 else "res://assets/audio/disparo.wav")
	if stream == null:
		return
	if use_m4 and _shoot_audio_player.playing and _shoot_audio_player.stream == stream and _shoot_audio_player.get_playback_position() < 1.15:
		return
	_shoot_audio_player.stream = stream
	_shoot_audio_player.volume_db = 3.0
	_shoot_audio_player.pitch_scale = randf_range(0.95, 1.05)
	_shoot_audio_player.play()

func play_rifle_shot_remote(_origin: Vector3, _dir: Vector3, wind: Vector3 = Vector3.ZERO) -> void:
	if is_puppet:
		if not _is_rifle_item_name(_puppet_held):
			return
	else:
		if not _has_rifle_equipped():
			return
	if not _rifle_fire_animation.is_empty() and third_person_animation_player != null:
		var fire_anim := third_person_animation_player.get_animation(_rifle_fire_animation)
		if fire_anim != null:
			fire_anim.loop_mode = Animation.LOOP_NONE
		third_person_action_animation = _rifle_fire_animation
		third_person_action_timer = 1.0
		_is_firing = true
		third_person_animation_player.play(_rifle_fire_animation, 0.05)
	var remote_m4 := is_puppet and _puppet_held == M4_NAME
	if not _is_aiming and not is_sitting and not is_prone:
		_update_rifle_visuals(0.0)
		_on_skeleton_updated()
	_play_shoot_sound(remote_m4)
	# Show muzzle flash at the reported muzzle (no tracer streak) and impact on static surfaces.
	_spawn_muzzle_flash(_origin, _dir)
	var excluded: Array[RID] = [get_rid()]
	_collect_child_collision_rids(self, excluded)
	_launch_rifle_projectile(_origin, _dir, wind, excluded, false, remote_m4)
	# Each RPC describes one actual round; never synthesize extra burst shots.

func _launch_rifle_projectile(origin: Vector3, direction: Vector3, wind: Vector3, excluded: Array[RID], deal_damage: bool, is_m4 := false) -> void:
	if direction.length_squared() < .001 or get_tree().current_scene == null: return
	var projectile := preload("res://scripts/RifleProjectile.gd").new()
	projectile.velocity = direction.normalized()*(M4_MUZZLE_SPEED if is_m4 else RIFLE_MUZZLE_SPEED)
	projectile.wind_velocity = wind
	projectile.max_distance = RIFLE_RANGE
	projectile.excluded = excluded.duplicate()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
	if deal_damage:
		projectile.impact.connect(_apply_rifle_damage.bind(is_m4))
	else:
		projectile.impact.connect(func(collider, point: Vector3, _distance: float, normal: Vector3):
			if not is_instance_valid(collider): return
			var target: Node = collider as Node
			while target != null:
				if _is_rifle_damage_target(target): return
				target = target.get_parent()
			_spawn_bullet_impact(point, normal, collider))

func _has_bow_equipped() -> bool:
	var held = get_held_item()
	return held != null and (str(held.item_type) == "weapon_bow" or str(held.item_name) in ["Arco de madera", "Arco reforzado"])

func _has_throwable_weapon_equipped() -> bool:
	var held = get_held_item()
	return held != null and (str(held.item_type) in ["tool_spear", "weapon_bola"] or str(held.item_name) in ["Palo afilado", "Lanza", "Lanza de hueso", "Boleadoras"])

func _count_inventory_arrows() -> int:
	if inventory == null:
		return 0
	var total := 0
	for it in inventory.items:
		if it != null and (str(it.item_type) == "ammo_arrow" or str(it.item_name) in ["Flecha de madera", "Flecha de piedra", "Flecha de hueso", "Flecha improvisada"]):
			total += int(it.quantity)
	return total

func _peek_best_arrow_name() -> String:
	if inventory == null:
		return ""
	for pref in ["Flecha de hueso", "Flecha de piedra", "Flecha de madera", "Flecha improvisada"]:
		if inventory.has_item_name(pref, 1):
			return pref
	for it in inventory.items:
		if it != null and str(it.item_type) == "ammo_arrow" and int(it.quantity) > 0:
			return str(it.item_name)
	return ""

func _consume_best_arrow() -> String:
	if inventory == null:
		return ""
	for pref in ["Flecha de hueso", "Flecha de piedra", "Flecha de madera", "Flecha improvisada"]:
		if inventory.has_item_name(pref, 1):
			inventory.consume_item_name(pref, 1)
			inventory.changed.emit()
			return pref
	for i in range(inventory.items.size()):
		var it = inventory.items[i]
		if it != null and str(it.item_type) == "ammo_arrow" and int(it.quantity) > 0:
			var aname := str(it.item_name)
			inventory.remove_index(i, 1)
			inventory.changed.emit()
			return aname
	return ""

func _shoot_bow() -> void:
	var held = get_held_item()
	if is_dead or camera == null or held == null or not _has_bow_equipped():
		return
	if held.has_method("is_broken") and held.is_broken():
		notice.emit("Tu %s está roto." % str(held.item_name))
		return
	if _shoot_cooldown > 0.0 or _bow_release_item != null:
		return
	if stats.energy < 3.5:
		notice.emit("Estás demasiado cansado para tensar el arco.")
		return
	if _count_inventory_arrows() <= 0:
		notice.emit("No tienes flechas en el inventario.")
		return
	_bow_release_item = held
	_bow_release_revision = _held_selection_revision
	_bow_release_timer = BOW_RELEASE_DELAY
	_shoot_cooldown = BOW_SHOT_DURATION
	play_action_animation("bow_shoot", BOW_SHOT_DURATION)

func _tick_primitive_releases(delta: float) -> void:
	if _bow_release_item != null:
		if is_dead or get_held_item() != _bow_release_item or _held_selection_revision != _bow_release_revision:
			_bow_release_item = null
			_bow_release_timer = 0.0
		else:
			_bow_release_timer -= delta
			if _bow_release_timer <= 0.0:
				_finish_bow_shot()
	if _throw_release_item != null:
		if is_dead or get_held_item() != _throw_release_item or _held_selection_revision != _throw_release_revision:
			_throw_release_item = null
			_throw_release_timer = 0.0
		else:
			_throw_release_timer -= delta
			if _throw_release_timer <= 0.0:
				_finish_aimed_throw()

func _finish_bow_shot() -> void:
	var held = _bow_release_item
	_bow_release_item = null
	_bow_release_timer = 0.0
	if held == null or is_dead or camera == null or get_held_item() != held or _held_selection_revision != _bow_release_revision or stats.energy < 3.5:
		return
	if held.has_method("is_broken") and held.is_broken():
		return
	var arrow_name := _consume_best_arrow()
	if arrow_name.is_empty():
		notice.emit("No tienes flechas en el inventario.")
		return
	_crosshair_bloom = minf(_crosshair_bloom + 18.0, 42.0)
	stats.energy = maxf(0.0, stats.energy - 3.5)
	stats.changed.emit()
	if held.has_method("reduce_durability"):
		held.reduce_durability(2.0)
	_schedule_melee_swing_sound(0.0)
	var is_reinf := str(held.item_name) == "Arco reforzado"
	var arrow_speed := 95.0 if is_reinf else 75.0
	var base_dmg := 125.0
	if arrow_name == "Flecha de piedra":
		base_dmg = 175.0
	elif arrow_name == "Flecha de hueso":
		base_dmg = 215.0
	elif arrow_name == "Flecha improvisada":
		# Sin punta ni emplumado: el astil desnudo sale más lento, tarda más en
		# llegar y golpea con mucha menos energía.
		base_dmg = 60.0
		arrow_speed *= 0.80
	if is_reinf:
		base_dmg *= 1.18
	var aim_point := camera.get_viewport().get_visible_rect().size * 0.5 + (Vector2.ZERO if _is_aiming else _aim_screen_offset)
	var cam_ray_origin := camera.project_ray_origin(aim_point)
	var cam_ray_dir := camera.project_ray_normal(aim_point).normalized()
	var exclude_arr: Array[RID] = [self.get_rid()]
	_collect_child_collision_rids(self, exclude_arr)
	var space_state := get_world_3d().direct_space_state
	var converge_dist := 35.0
	var zero_target := cam_ray_origin + cam_ray_dir * converge_dist
	var shot_origin := _bow_release_origin(exclude_arr, cam_ray_dir)
	if space_state != null:
		# Start the sight ray past the bow so obstacles between the third-person
		# over-shoulder camera and the player's hand never deflect the arrow.
		var bow_along_ray := maxf(0.0, (shot_origin - cam_ray_origin).dot(cam_ray_dir))
		var sight_start := cam_ray_origin + cam_ray_dir * (bow_along_ray + 0.35)
		var sight_hit := _rifle_sight_hit(sight_start, cam_ray_dir, exclude_arr)
		if not sight_hit.is_empty():
			var hit_d_from_bow := sight_start.distance_to(sight_hit.position)
			# The sight ray already excludes the actor and starts beyond the hand.
			# A nearby hit is real cover/target, not something to aim through.
			converge_dist = bow_along_ray + 0.35 + hit_d_from_bow
			zero_target = sight_hit.position
			shot_origin = _bow_release_origin(exclude_arr, cam_ray_dir, zero_target)
	var aim_dist := minf(shot_origin.distance_to(zero_target), 60.0)
	# Time of flight under exponential drag: x(t) = v0/k·(1-e^-kt), so
	# t = -ln(1 - x·k/v0)/k. Arrows arrive later than the vacuum estimate —
	# without this correction the compensated aim lands low past ~35 m.
	var arrow_drag := _primitive_projectile_drag("ammo_arrow", arrow_name)
	var flight_t := aim_dist / arrow_speed
	var drag_arg := 1.0 - aim_dist * arrow_drag / arrow_speed
	if arrow_drag > 0.001 and drag_arg > 0.05:
		flight_t = -log(drag_arg) / arrow_drag
	zero_target.y += 0.5 * 9.81 * flight_t * flight_t
	var aim_dir := (zero_target - shot_origin).normalized()
	if aim_dir.length_squared() < 0.5:
		aim_dir = cam_ray_dir
	_launch_primitive_projectile(shot_origin, aim_dir, arrow_speed, 140.0, exclude_arr, base_dmg, arrow_name, "ammo_arrow", 0.06, 3.0, false)
	var main := get_tree().current_scene
	if main != null and main.has_method("_sync_local_player_inventory"):
		main.call_deferred("_sync_local_player_inventory")

func _throw_aimed_weapon() -> void:
	var held = get_held_item()
	if is_dead or camera == null or held == null or not _has_throwable_weapon_equipped():
		return
	if _shoot_cooldown > 0.0 or _throw_release_item != null or _throw_charging:
		return
	if stats.energy < 6.0:
		notice.emit("Estás demasiado cansado para lanzar.")
		return
	# Capturar la dirección en el clic; la lanza sale del brazo cuando el
	# swing llega al punto de suelta, igual que al soltar la tecla G.
	var aim_point := camera.get_viewport().get_visible_rect().size * 0.5
	var cam_ray_dir := camera.project_ray_normal(aim_point).normalized()
	_throw_release_revision = _held_selection_revision
	var cam_origin := camera.project_ray_origin(aim_point)
	var excluded: Array[RID] = [get_rid()]
	_collect_child_collision_rids(self, excluded)
	var hand_approx := global_position + Vector3(0.0, 0.35 if is_prone else (1.0 if is_crouching else 1.42), 0.0)
	var hand_along := maxf(0.0, (hand_approx - cam_origin).dot(cam_ray_dir))
	var sight_start := cam_origin + cam_ray_dir * (hand_along + 0.35)
	var target_hit := _rifle_sight_hit(sight_start, cam_ray_dir, excluded)
	_throw_release_target = target_hit.position if not target_hit.is_empty() else cam_origin + cam_ray_dir * 35.0
	_throw_release_item = held
	_throw_release_timer = THROW_RELEASE_DELAY
	_throw_aim_hold = false
	_throw_aim_frozen = false
	_cancel_aim()
	_shoot_cooldown = 0.8
	# Reanudar el wind-up congelado en vez de reiniciar el clip desde cero.
	if third_person_animation_player != null:
		if third_person_animation_player.current_animation != third_person_attack_animation:
			_start_throw_animation()
		third_person_animation_player.seek(THROW_ANIM_FREEZE_TIME, true)
		third_person_animation_player.speed_scale = 1.0
		third_person_action_animation = third_person_attack_animation
		third_person_action_timer = 0.85
	else:
		play_action_animation("attack", 0.65)
	_schedule_melee_swing_sound(THROW_RELEASE_DELAY)

func _finish_aimed_throw() -> void:
	var held = _throw_release_item
	_throw_release_item = null
	_throw_release_timer = 0.0
	if held == null or camera == null or is_dead or get_held_item() != held or _held_selection_revision != _throw_release_revision:
		return
	if stats.energy < 6.0 or (held.has_method("is_broken") and held.is_broken()):
		return
	set_meta("last_dropped_durability", maxf(0.0, float(held.durability) - 4.0))
	set_meta("last_dropped_max_durability", float(held.max_durability))
	var item_name := str(held.item_name)
	var item_type := str(held.item_type)
	var item_weight := float(held.weight)
	var item_use := float(held.use_value)
	var idx: int = inventory.items.find(held) if inventory != null else -1
	if idx < 0 and not _held_item_external:
		return
	var exclude_arr: Array[RID] = [self.get_rid()]
	_collect_child_collision_rids(self, exclude_arr)
	# Read the animated grip BEFORE clearing/rebuilding the held visual.
	var release_origin := _spear_release_origin(exclude_arr)
	stats.energy = maxf(0.0, stats.energy - 6.0)
	stats.changed.emit()
	_held_item_reference = null
	_held_item_external = false
	held_index = -1
	_held_selection_revision += 1
	if idx >= 0:
		inventory.remove_index(idx, 1)
	_sync_held_item()
	var is_bola := item_type == "weapon_bola" or item_name == "Boleadoras"
	var proj_speed := 32.0 if is_bola else 38.0
	var base_dmg := 35.0 if is_bola else (110.0 if item_name == "Palo afilado" else (165.0 if item_name == "Lanza" else 210.0))
	var aim_target := _throw_release_target
	var aim_dist := minf(release_origin.distance_to(aim_target), 32.0)
	var proj_drag := _primitive_projectile_drag(item_type, item_name)
	var flight_t := aim_dist / proj_speed
	var drag_arg := 1.0 - aim_dist * proj_drag / proj_speed
	if proj_drag > 0.001 and drag_arg > 0.08:
		flight_t = -log(drag_arg) / proj_drag
	aim_target.y += 0.5 * 9.81 * flight_t * flight_t
	var throw_dir := (aim_target - release_origin).normalized()
	if throw_dir.length_squared() < 0.001:
		throw_dir = -camera.global_basis.z
	_launch_primitive_projectile(release_origin, throw_dir, proj_speed, 65.0, exclude_arr, base_dmg, item_name, item_type, item_weight, item_use, is_bola)
	notice.emit("Lanzas %s." % item_name)
	var main := get_tree().current_scene
	if main != null and main.has_method("_sync_local_player_inventory"):
		main.call_deferred("_sync_local_player_inventory")

func _bow_release_origin(excluded: Array[RID], cam_ray_dir: Vector3, target_pt: Vector3 = Vector3.INF) -> Vector3:
	var body := global_position + Vector3(0, 0.35 if is_prone else (1.0 if is_crouching else 1.42), 0)
	var fallback := body + cam_ray_dir * 0.45
	var grip := fallback
	if is_instance_valid(third_person_hand_item_root) and is_instance_valid(_hand_skeleton):
		_hand_skeleton.force_update_all_bone_transforms()
		_update_hand_socket()
		grip = third_person_hand_item_root.global_position
		body = Vector3(global_position.x, grip.y, global_position.z)
	if target_pt.is_finite():
		var body_to_target := body.distance_to(target_pt)
		var body_to_grip := body.distance_to(grip)
		if body_to_target < body_to_grip + 0.35:
			grip = body.lerp(grip, clampf((body_to_target - 0.25) / maxf(body_to_grip, 0.01), 0.0, 1.0))
	if grip.distance_squared_to(body) > 0.0001 and get_world_3d() != null:
		var query := PhysicsRayQueryParameters3D.create(body, grip, 5, excluded)
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var world := get_tree().current_scene
		if world != null and world.has_method("raycast_distant_props"):
			var end_pt: Vector3 = hit.position if not hit.is_empty() else grip
			var distant: Dictionary = world.raycast_distant_props(body, end_pt)
			if not distant.is_empty():
				hit = distant
		if not hit.is_empty():
			return hit.position - (grip - body).normalized() * 0.12
	return grip

func _spear_release_origin(excluded: Array[RID]) -> Vector3:
	var body := global_position + Vector3(0, 0.35 if is_prone else (1.0 if is_crouching else 1.42), 0)
	var grip := body
	if is_instance_valid(third_person_hand_item_root) and is_instance_valid(_hand_skeleton):
		_hand_skeleton.force_update_all_bone_transforms()
		_update_hand_socket()
		grip = third_person_hand_item_root.global_position
	# An animated hand beyond a wall must not spawn a projectile through it.
	if grip.distance_squared_to(body) > 0.0001:
		var query := PhysicsRayQueryParameters3D.create(body, grip, 5, excluded)
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var world := get_tree().current_scene
		if world != null and world.has_method("raycast_distant_props"):
			var endpoint: Vector3 = hit.position if not hit.is_empty() else grip
			var distant: Dictionary = world.raycast_distant_props(body, endpoint)
			if not distant.is_empty():
				hit = distant
		if not hit.is_empty():
			return hit.position - (grip - body).normalized() * 0.12
	return grip

# Exponential drag per thrown/shot projectile: light fletched arrows shed
# speed fast, heavy spears keep it, bolas tumble and stall quickest.
func _primitive_projectile_drag(item_type: String, item_name: String) -> float:
	match item_name:
		"Flecha improvisada":
			return 0.52
		"Flecha de madera":
			return 0.34
		"Flecha de piedra":
			return 0.28
		"Flecha de hueso":
			return 0.26
		"Lanza", "Lanza de hueso":
			return 0.20
		"Palo afilado":
			return 0.26
		"Boleadoras":
			return 0.40
	return 0.30 if item_type == "ammo_arrow" else 0.24

func _build_arrow_or_spear_visual(item_name: String, item_type: String, for_flight: bool = false) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "ProjectileVisual"
	var vis: Node3D = null
	if item_type == "ammo_arrow":
		var apath := ""
		if item_name == "Flecha de madera":
			apath = ARROW_WOOD_MODEL
		elif item_name == "Flecha de piedra":
			apath = ARROW_STONE_MODEL
		elif item_name == "Flecha de hueso":
			apath = ARROW_BONE_MODEL
		if not apath.is_empty():
			vis = _load_external_node3d(apath)
			if vis != null:
				# GLB shafts are modeled head-at-+Z; projectile forward is -Z, so
				# flip the visual or the arrow flies fletching-first.
				vis.rotation_degrees.y = 180.0
	if vis == null:
		vis = MaterialFactory.build_primitive_item_mesh(item_name)
		vis.rotation_degrees.x = -90.0 if item_type != "ammo_arrow" else 0.0
	wrapper.add_child(vis)
	if for_flight and item_type == "ammo_arrow":
		vis.scale = Vector3(2.4, 2.4, 1.40)
		var wake := MeshInstance3D.new()
		wake.name = "ArrowFlightStreak"
		var wcyl := CylinderMesh.new()
		wcyl.top_radius = 0.005
		wcyl.bottom_radius = 0.022
		wcyl.height = 1.65
		wcyl.radial_segments = 8
		wake.mesh = wcyl
		wake.rotation_degrees.x = 90.0
		wake.position = Vector3(0.0, 0.0, 1.15)
		var wmat := StandardMaterial3D.new()
		wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		wmat.albedo_color = Color(0.96, 0.94, 0.84, 0.42)
		wake.material_override = wmat
		wrapper.add_child(wake)
	return wrapper

func _launch_primitive_projectile(origin: Vector3, direction: Vector3, speed: float, max_dist: float, excluded: Array[RID], base_damage: float, item_name: String, item_type: String, item_weight: float, item_use: float, is_bola: bool, visual_only: bool = false, remote_wind: Vector3 = Vector3.ZERO) -> void:
	if direction.length_squared() < 0.001 or get_tree().current_scene == null:
		return
	var projectile := preload("res://scripts/RifleProjectile.gd").new()
	projectile.velocity = direction.normalized() * speed
	projectile.wind_velocity = remote_wind if visual_only else _wind_dir * _wind_strength * 0.35
	projectile.max_distance = max_dist
	projectile.excluded = excluded.duplicate()
	projectile.drag_coeff = _primitive_projectile_drag(item_type, item_name)
	projectile.launch_speed = speed
	projectile.align_flight = item_type == "ammo_arrow" or item_type == "tool_spear" or item_name in ["Lanza", "Lanza de hueso", "Palo afilado"]
	var vis := _build_arrow_or_spear_visual(item_name, item_type, true)
	projectile.add_child(vis)
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
	projectile.look_at(origin + direction.normalized(), Vector3.UP if absf(direction.normalized().y) < 0.97 else Vector3.FORWARD)
	if visual_only:
		return
	_alert_wildlife_along_shot(origin, direction.normalized(), minf(max_dist, 55.0), 22.0, 15.0)
	var network := get_node_or_null("/root/NetworkManager")
	if network != null and network.is_connected:
		if network.is_host:
			network.primitive_shot(network.get_my_id(), origin, direction, item_name, speed, projectile.wind_velocity)
		else:
			network.primitive_shot.rpc_id(1, network.get_my_id(), origin, direction, item_name, speed, projectile.wind_velocity)
	var recovered_state: Dictionary = {}
	if item_type != "ammo_arrow":
		for key in ["last_dropped_durability", "last_dropped_max_durability"]:
			if has_meta(key):
				recovered_state[key] = get_meta(key)
				remove_meta(key)
	projectile.expired.connect(func(pos: Vector3):
		_recover_primitive_item(pos, Vector3.UP, item_name, item_type, item_weight, item_use, recovered_state))
	projectile.impact.connect(func(collider, hit_pos: Vector3, hit_dist: float, hit_normal: Vector3):
		# Wounding power scales with the speed the shaft still carries: heavy
		# drag makes long shots land softer instead of using a fixed falloff.
		var energy := clampf(projectile.velocity.length() / maxf(speed, 1.0), 0.45, 1.0)
		var flight_dir := projectile.velocity.normalized()
		if flight_dir.length_squared() < 0.001:
			flight_dir = direction.normalized()
		_on_primitive_projectile_impact(collider, hit_pos, hit_dist, hit_normal, base_damage, item_name, item_type, item_weight, item_use, is_bola, energy, recovered_state, flight_dir)
	)

func _on_primitive_projectile_impact(collider, hit_pos: Vector3, hit_dist: float, hit_normal: Vector3, base_damage: float, item_name: String, item_type: String, item_weight: float, item_use: float, is_bola: bool, energy_mult: float = 1.0, recovered_state: Dictionary = {}, flight_dir: Vector3 = Vector3.ZERO) -> void:
	var is_headshot := false
	var target_node: Node = null
	if collider is Node3D:
		var node: Node3D = collider as Node3D
		if node.name == "HeadHitbox":
			is_headshot = true
		var walked: Node = node
		while walked != null:
			if walked == self:
				break
			if walked.has_method("take_damage") and _is_rifle_damage_target(walked):
				target_node = walked
				break
			walked = walked.get_parent()
		if target_node == null and node.is_in_group("net_player_proxy"):
			target_node = node
	if target_node != null:
		var dmg := base_damage * (2.2 if is_headshot else 1.0) * energy_mult
		if is_bola and target_node is Node3D:
			target_node.set_meta("bola_slow_until", Time.get_unix_time_from_system() + 6.0)
			notice.emit("¡Boleadoras! Has trabado a la presa (6s).")
		if target_node.is_in_group("remote_player") or target_node.is_in_group("net_player_proxy"):
			var pvp_dmg := (18.0 if is_bola else (75.0 if is_headshot else 42.0))
			if target_node.has_method("take_damage"):
				_apply_rifle_target_damage(target_node, pvp_dmg)
		elif is_bola and target_node is WildlifeController and target_node.is_puppet:
			var network := get_node_or_null("/root/NetworkManager")
			if network != null and network.is_connected:
				network.damage_animal.rpc_id(1, target_node.name, dmg, false, true)
		else:
			_apply_rifle_target_damage(target_node, dmg)
		_spawn_blood_splatter(hit_pos, 1.4 if is_headshot else 1.0)
		_hit_marker(bool(target_node.get("_is_dead")) or bool(target_node.get("is_dead")))
	else:
		_spawn_bullet_impact(hit_pos, hit_normal, collider)
	if not is_bola:
		_play_arrow_stick_sound(hit_pos, hit_dist, target_node != null)
	_alert_wildlife_near_point(hit_pos, 36.0)
	_recover_primitive_item(hit_pos, hit_normal, item_name, item_type, item_weight, item_use, recovered_state, flight_dir, target_node, collider)

func _alert_wildlife_near_point(pos: Vector3, radius: float) -> void:
	if not is_inside_tree():
		return
	for w in get_tree().get_nodes_in_group("wildlife"):
		if w != null and is_instance_valid(w) and w.has_method("flee_from_gunshot"):
			w.flee_from_gunshot(pos, radius)

func _alert_wildlife_along_shot(origin: Vector3, dir: Vector3, max_len: float, origin_radius: float, corridor_radius: float) -> void:
	if not is_inside_tree() or dir.length_squared() < 0.001:
		return
	var ndir := dir.normalized()
	for w in get_tree().get_nodes_in_group("wildlife"):
		if w == null or not is_instance_valid(w) or not (w is Node3D) or not w.has_method("flee_from_gunshot"):
			continue
		var wpos := (w as Node3D).global_position
		if wpos.distance_to(origin) <= origin_radius:
			w.flee_from_gunshot(origin, origin_radius + 2.0)
			continue
		var rel := wpos - origin
		var along := rel.dot(ndir)
		if along > 0.0 and along <= max_len:
			var closest := origin + ndir * along
			if wpos.distance_to(closest) <= corridor_radius:
				w.flee_from_gunshot(closest, corridor_radius + 4.0)

func _play_arrow_stick_sound(hit_pos: Vector3, hit_dist: float, hit_flesh: bool) -> void:
	if _impact_audio_player == null:
		_impact_audio_player = _make_action_sound_player("PunchImpactSound")
	var stream_path := "res://assets/audio/punch_impact.wav" if hit_flesh else "res://assets/external/audio/footstep_wood_01.wav"
	var stream := _load_wav_stream(stream_path)
	if stream == null:
		stream = _load_wav_stream("res://assets/audio/punch_impact.wav")
	if stream != null:
		_impact_audio_player.stream = stream
		_impact_audio_player.volume_db = clampf(5.5 - hit_dist * 0.14, -10.0, 5.5)
		_impact_audio_player.pitch_scale = randf_range(1.18, 1.38) if not hit_flesh else randf_range(0.92, 1.08)
		_impact_audio_player.play()
	var scene := get_tree().current_scene
	if scene != null and stream != null:
		var p3d := AudioStreamPlayer3D.new()
		p3d.stream = stream
		p3d.unit_size = 14.0
		p3d.max_distance = 55.0
		p3d.volume_db = 4.0
		p3d.pitch_scale = randf_range(1.22, 1.42)
		scene.add_child(p3d)
		p3d.global_position = hit_pos
		p3d.finished.connect(p3d.queue_free)
		p3d.play()

func _recover_primitive_item(hit_pos: Vector3, hit_normal: Vector3, item_name: String, item_type: String, item_weight: float, item_use: float, recovered_state: Dictionary = {}, flight_dir: Vector3 = Vector3.ZERO, target_node: Node = null, collider = null) -> void:
	var drop_pos := hit_pos + hit_normal * 0.08
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_get_exact_ground_y"):
		drop_pos.y = float(scene.call("_get_exact_ground_y", drop_pos.x, drop_pos.z, hit_pos.y + 2.0)) + 0.06
	# Drop handlers consume these synchronously; each projectile owns its state.
	for key in ["last_dropped_durability", "last_dropped_max_durability"]:
		if recovered_state.has(key):
			set_meta(key, recovered_state[key])
		elif has_meta(key):
			remove_meta(key)
	item_dropped.emit(item_name, item_type, item_weight, 1, item_use, drop_pos, Color(0, 0, 0, 0), false, 0.0)
	if flight_dir.length_squared() > 0.001 and (item_type == "ammo_arrow" or item_type == "tool_spear" or item_name in ["Lanza", "Lanza de hueso", "Palo afilado"]):
		_embed_stuck_projectile_visual(hit_pos, flight_dir.normalized(), item_name, item_type, target_node, collider)

func _embed_stuck_projectile_visual(hit_pos: Vector3, fdir: Vector3, item_name: String, item_type: String, target_node: Node = null, collider = null) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var pickup_node: Node3D = null
	var dropped_list = scene.get("_dropped_items")
	if dropped_list is Array and not (dropped_list as Array).is_empty():
		var last_entry = (dropped_list as Array).back()
		if last_entry is Dictionary and str(last_entry.get("name", "")) == item_name:
			var pid := "Pickup_" + str(last_entry.get("id", ""))
			pickup_node = scene.get_node_or_null(NodePath(pid)) as Node3D
	if pickup_node == null:
		pickup_node = Node3D.new()
		pickup_node.name = "StuckProjectile_%d" % [Time.get_ticks_usec() % 1000000]
		pickup_node.add_to_group("world_action_visual")
		scene.add_child(pickup_node)
	else:
		for ch in pickup_node.get_children():
			pickup_node.remove_child(ch)
			ch.queue_free()
	var shaft_vis := _build_arrow_or_spear_visual(item_name, item_type, false)
	if item_type == "ammo_arrow":
		shaft_vis.scale = Vector3(2.15, 2.15, 1.35)
		# Tip is at -0.425 * 1.35 = -0.57m; shifting +0.43m buries 14 cm of
		# arrowhead inside the hit surface and leaves ~78 cm of shaft + feathers sticking out.
		shaft_vis.position = Vector3(0.0, 0.0, 0.43)
	else:
		shaft_vis.scale = Vector3(1.25, 1.25, 1.15)
		shaft_vis.position = Vector3(0.0, 0.0, 0.72)
	pickup_node.add_child(shaft_vis)
	var attach_parent: Node3D = null
	if target_node is Node3D and is_instance_valid(target_node):
		attach_parent = target_node as Node3D
	elif collider is Node3D and is_instance_valid(collider):
		var col_node := collider as Node3D
		if col_node is Door or col_node.is_in_group("doors"):
			attach_parent = col_node
		elif not (col_node is StaticBody3D) and col_node != scene and (String(col_node.name).begins_with("ChoppableTree_") or String(col_node.name).begins_with("StuckTarget")):
			attach_parent = col_node
		elif col_node is StaticBody3D and String(col_node.name).ends_with("_Collision"):
			var vis_tree_name := String(col_node.name).trim_suffix("_Collision")
			var vis_tree := scene.get_node_or_null(NodePath(vis_tree_name)) as Node3D
			if vis_tree != null and String(vis_tree.name).begins_with("ChoppableTree_"):
				attach_parent = vis_tree
	if attach_parent != null and pickup_node.get_parent() != attach_parent:
		if pickup_node.get_parent() != null:
			pickup_node.get_parent().remove_child(pickup_node)
		attach_parent.add_child(pickup_node)
		var fallback_scene := scene
		var node_ref := pickup_node
		attach_parent.tree_exiting.connect(func():
			if is_instance_valid(node_ref) and is_instance_valid(fallback_scene) and node_ref.is_inside_tree():
				var xform := node_ref.global_transform
				node_ref.get_parent().remove_child(node_ref)
				fallback_scene.add_child(node_ref)
				node_ref.global_transform = xform
		, CONNECT_ONE_SHOT)
	var up_ref := Vector3.UP if absf(fdir.y) < 0.97 else Vector3.FORWARD
	var world_basis := Basis.looking_at(fdir, up_ref)
	pickup_node.global_transform = Transform3D(world_basis, hit_pos)

func _load_wav_stream(path: String) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			stream = AudioStreamWAV.load_from_file(disk_path)
	return stream

func _load_audio_stream(path: String) -> AudioStream:
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			if path.get_extension().to_lower() == "mp3":
				stream = AudioStreamMP3.load_from_file(disk_path)
			else:
				stream = AudioStreamWAV.load_from_file(disk_path)
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
	return stream

func _play_shot_received_sound() -> void:
	if _shot_audio_player == null:
		_shot_audio_player = _make_action_sound_player("ShotReceivedSound")
	var stream := _load_audio_stream("res://assets/audio/recibirdisparo.mp3")
	if stream == null:
		return
	_shot_audio_player.stream = stream
	_shot_audio_player.volume_db = 3.0
	_shot_audio_player.pitch_scale = randf_range(0.9, 1.1)
	_shot_audio_player.play()

func _play_fall_damage_sound() -> void:
	if _fall_audio_player == null:
		_fall_audio_player = _make_action_sound_player("FallDamageSound")
	var stream := _load_audio_stream("res://assets/audio/saltardano.mp3")
	if stream == null:
		return
	_fall_audio_player.stream = stream
	_fall_audio_player.volume_db = 3.0
	_fall_audio_player.pitch_scale = randf_range(0.9, 1.1)
	_fall_audio_player.play()

func _play_unwell_sound() -> void:
	if _unwell_audio_player == null:
		_unwell_audio_player = _make_action_sound_player("UnwellSound")
	var stream := _load_audio_stream("res://assets/audio/malo.mp3")
	if stream == null:
		return
	_unwell_audio_player.stream = stream
	_unwell_audio_player.volume_db = 3.0
	_unwell_audio_player.pitch_scale = randf_range(0.9, 1.1)
	_unwell_audio_player.play()

func _sync_condition_audio(condition: String) -> void:
	var net_node := get_tree().root.get_node_or_null("NetworkManager")
	if net_node == null or not net_node.get("is_connected"):
		return
	if net_node.get("is_host"):
		net_node._broadcast_player_condition_audio(net_node.get_my_id(), condition)
	else:
		net_node.player_condition_audio.rpc_id(1, condition)

func _schedule_melee_swing_sound(impact_delay: float) -> void:
	# The whoosh belongs to the arm's extension, not the initial recoil —
	# schedule it just ahead of the contact frame.
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(maxf(impact_delay - MELEE_SWING_SOUND_LEAD, 0.0)).timeout.connect(_play_melee_swing_sound)

func _play_melee_swing_sound() -> void:
	if _swing_audio_player == null:
		_swing_audio_player = _make_action_sound_player("MeleeSwingSound")
	var stream := _load_wav_stream("res://assets/audio/punch_swing.wav")
	if stream == null:
		return
	_swing_audio_player.stream = stream
	_swing_audio_player.volume_db = 2.0
	_swing_audio_player.pitch_scale = randf_range(0.9, 1.15)
	_swing_audio_player.play()

func _play_punch_impact_sound() -> void:
	if _impact_audio_player == null:
		_impact_audio_player = _make_action_sound_player("PunchImpactSound")
	var stream := _load_wav_stream("res://assets/audio/punch_impact.wav")
	if stream == null:
		return
	_impact_audio_player.stream = stream
	_impact_audio_player.volume_db = 3.0
	_impact_audio_player.pitch_scale = randf_range(0.85, 1.1)
	_impact_audio_player.play()

func _play_pain_sound() -> void:
	if _pain_sound_timer > 0.0:
		return
	_pain_sound_timer = 1.5
	if _pain_audio_player == null:
		_pain_audio_player = _make_action_sound_player("PainSound")
	var paths := [
		"res://assets/external/audio/downloaded/pain1.wav",
		"res://assets/external/audio/downloaded/pain2.wav",
		"res://assets/external/audio/downloaded/pain3.wav"
	]
	var path: String = paths[randi() % paths.size()]
	var stream := _load_audio_stream(path)
	if stream == null:
		return
	_pain_audio_player.stream = stream
	_pain_audio_player.volume_db = 3.0
	_pain_audio_player.pitch_scale = randf_range(0.85, 1.15)
	_pain_audio_player.play()

func to_dict() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"stats": stats.to_dict(),
		"inventory": inventory.to_array(),
		"inventory_max_slots": inventory.max_slots,
		"inventory_max_weight": inventory.max_weight,
		"equipped_clothing": equipped_clothing,
		"equipped_backpack": equipped_backpack,
		"flashlight_charge": flashlight_charge,
		"wetness": wetness
	}

func from_dict(data: Dictionary) -> void:
	var pos = data.get("position", [])
	if pos is Array and pos.size() == 3:
		global_position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	rotation.y = float(data.get("rotation_y", rotation.y))
	if data.get("stats", null) is Dictionary:
		stats.from_dict(data["stats"])
	inventory.max_slots = int(data.get("inventory_max_slots", inventory.max_slots))
	inventory.max_weight = float(data.get("inventory_max_weight", inventory.max_weight))
	if data.get("inventory", null) is Array:
		inventory.from_array(data["inventory"])
	equipped_clothing = str(data.get("equipped_clothing", equipped_clothing))
	equipped_backpack = str(data.get("equipped_backpack", equipped_backpack))
	flashlight_charge = float(data.get("flashlight_charge", flashlight_charge))
	wetness = float(data.get("wetness", wetness))
	_recalculate_carry_capacity()
	if not equipped_clothing.is_empty():
		_wear_clothing_visual(equipped_clothing)
	_sync_held_item()

# Uso rápido del objeto en mano: delega a la implementación real
func _quick_use_held_item() -> void:
	_quick_use_held_item_impl()

func _inventory_has_blade() -> bool:
	if inventory == null:
		return false
	for item in inventory.items:
		if item != null and item.item_name in ["Cuchillo", "Hacha"] and not item.is_broken():
			return true
	return false

func _quick_use_held_item_impl() -> void:
	var item = get_held_item()
	if item == null:
		return
	match item.item_type:
		"food":
			_eat_held_item()
		"water":
			_drink_held_item()
		_:
			if item.item_name == "Cerillas":
				var target = _get_interaction_target()
				if target != null and target is WorldAction and target.action_type == "light_campfire":
					target.interact(self)

func _eat_action() -> void:
	# Una accion comestible apuntada tiene prioridad: el prompt muestra
	# "[M] Comer" sobre ese objeto, asi que M debe comerlo a el y no el
	# objeto que ya llevamos en la mano (p.ej. un pez sostenido).
	var target = _get_interaction_target()
	if target != null and target is WorldAction:
		if target.action_type == "eat_food" or target.action_type == "wolf_meat_raw" or target.action_type == "bird_meat_raw":
			var main := get_tree().current_scene
			if main != null and main.has_method("handle_world_action_eat"):
				main.handle_world_action_eat(target, self)
			else:
				target.interact(self)
			return
	# Solo se come lo que se lleva en la mano. M nunca saca comida del
	# inventario por atajo (antes comia items[held_index] clampeado).
	_eat_held_item()

func _light_action() -> void:
	var target = _get_interaction_target()
	if target != null and target is WorldAction:
		if target.action_type == "light_campfire":
			target.interact(self)
		elif target.action_type == "shelter":
			var main := get_tree().current_scene
			if main != null and main.has_method("handle_shelter_dismantle"):
				main.handle_shelter_dismantle(target, self)

#endregion

func clothing_has_camo(item_name: String, item = null) -> bool:
	if SURVIVAL_CLOTHING.get(item_name, {}).has("camo"):
		return true
	if item != null and item.has_meta("clothing_camo"):
		return bool(item.get_meta("clothing_camo"))
	if inventory != null:
		for candidate in inventory.items:
			if candidate.item_name == item_name and candidate.has_meta("clothing_camo"):
				return bool(candidate.get_meta("clothing_camo"))
	var session := get_node_or_null("/root/GameSession")
	if session != null and item_name in ["Camiseta", "Pantalones"]:
		return bool(session.get_meta("top_camo" if item_name == "Camiseta" else "bottom_camo", false))
	return false

func _update_stair_motion(moving: bool, delta: float) -> bool:
	var travelled := global_position - _stairs_last_position
	_stairs_last_position = global_position
	if not _stairs_position_valid:
		_stairs_position_valid = true
		return false
	_stairs_grace = maxf(0.0, _stairs_grace-delta)
	if not moving or is_crouching or is_sitting or is_prone or is_jumping or travelled.length()>1.5:
		_stairs_grace = 0.0
		return false
	if travelled.y>delta*.04 and Vector2(travelled.x,travelled.z).length()>delta*.1:
		var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*.4,global_position-Vector3.UP*.7)
		ray.collision_mask=1
		ray.exclude=[get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and hit.collider.is_in_group("stair_surface"):
			_stairs_grace=.16
	return _stairs_grace>0.0
