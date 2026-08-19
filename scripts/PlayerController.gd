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
const REAL_KNIFE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/Knife.gltf"
const REAL_BOTTLE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/bottle.glb"
const REAL_PLASTIC_BOTTLE_MODEL := "res://assets/models/props/plastic_water_bottle.glb"
const REAL_WOOD_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/resource-wood.glb"
const REAL_STONE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/resource-stone.glb"
const REAL_AXE_MODEL := "res://assets/models/props/simple_axe.glb"
const REAL_HOE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-hoe.glb"
const REAL_SHOVEL_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-shovel.glb"
const REAL_HAMMER_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-hammer.glb"
const REAL_PICKAXE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-pickaxe.glb"
const REAL_BACKPACK_MODEL := "res://assets/external/realistic/root_glb/low_poly_game_ready_military_tactical_backpack.glb"
const REAL_MEAT_ON_STICK_MODEL := "res://assets/models/props/cc0_-_raw_meat_4.glb"
const REAL_WOOD_STICK_MODEL := "res://assets/models/props/wood_stick.glb"
const REAL_TORCH_MODEL := "res://assets/animations/torch_stick.glb"
const POLY_FISHERMANS_HAT_MODEL := "res://assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf"
const POLY_GARDEN_GLOVES_MODEL := "res://assets/external/polyhaven/garden_gloves_01/garden_gloves_01_1k.gltf"
# Wearable visuals placed on the body relative to its measured bounding box, so
# they fit regardless of the character model's scale/proportions.
#   frac_y: anchor height as a fraction of body height (0 = feet, 1 = head top)
#   size:   item height as a fraction of body height
#   forward: shift toward the front of the body (fraction of depth)
#   align:  "center" (default) or "bottom"; "strip" hides duplicate variant meshes
const CLOTHING_VISUALS := {
	"Sombrero de pescador": {"path": POLY_FISHERMANS_HAT_MODEL, "frac_y": 0.94, "size": 0.06, "yaw": 0.0, "align": "bottom", "forward": -0.04},
	"Guantes de trabajo": {"path": POLY_GARDEN_GLOVES_MODEL, "frac_y": 0.45, "size": 0.09, "yaw": 0.0, "forward": 0.2},
}
# Adapted character (Mixamo body + survival clothing skinned to the same rig).
# Loaded first so the deformable survival garments are available to wear.
const ADAPTED_PLAYER_MODEL := "res://assets/characters/adapted/player_with_clothes.glb"

const SOLDADO_MODEL := "res://assets/adapted/soldado_parts.glb"

# Survival garments that are skinned to the Mixamo rig inside ADAPTED_PLAYER_MODEL.
# item_name -> mesh node to show + Mixamo default meshes to hide while worn.
const SURVIVAL_CLOTHING := {
	"Guantes survival": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": []},
	"Botas survival": {"mesh": "cloth_feet", "hides": ["Shoes"], "skin_hides": ["Desnudo_feet"], "body_hides": ["Body_feet"], "tint": Color(0.05, 0.05, 0.05)},
	"Chaqueta militar": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_torso", "Body_arms"]},
	"Pantalones militares": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"]},
	"Guantes militares": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": []},
	"Chaqueta militar azul": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_torso", "Body_arms"], "tint": Color(0.03, 0.05, 0.10)},
	"Pantalones militares azules": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "tint": Color(0.02, 0.04, 0.08)},
	"Chaqueta militar negra II": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": ["Body_torso", "Body_arms"], "tint": Color(0.03, 0.03, 0.04)},
	"Pantalones militares negros II": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "tint": Color(0.02, 0.02, 0.03)},
	"Pantalones camuflaje": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "camo": Color(0.18, 0.22, 0.13)},
	"Pantalones camuflaje desert": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"], "camo": Color(0.32, 0.28, 0.16)},
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
	"Camiseta": ["Desnudo_torso"],
	"Pantalones": ["Desnudo_legs"],
	"Zapatillas": ["Desnudo_feet"],
	"Chaqueta militar": ["Desnudo_torso", "Desnudo_arms"],
	"Pantalones militares": ["Desnudo_legs"],
	"Chaqueta militar azul": ["Desnudo_torso", "Desnudo_arms"],
	"Pantalones militares azules": ["Desnudo_legs"],
	"Chaqueta militar negra II": ["Desnudo_torso", "Desnudo_arms"],
	"Pantalones militares negros II": ["Desnudo_legs"],
	"Pantalones camuflaje": ["Desnudo_legs"],
	"Pantalones camuflaje desert": ["Desnudo_legs"],
	"Guantes survival": ["Desnudo_hands"],
	"Guantes militares": ["Desnudo_hands"],
	"Botas survival": ["Desnudo_feet"],
}

const DEFAULT_BODY_HIDES := {
	"Camiseta": [],
	"Pantalones": [],
	"Zapatillas": ["Body_feet"],
}

# Map of body zones covered by each clothing item.
# Used for debug messages and to know which body regions to restore on unequip.
const CLOTHING_COVERED_ZONES := {
	"Camiseta": ["torso"],
	"Pantalones": ["cadera", "piernas"],
	"Zapatillas": ["pies"],
	"Chaqueta militar": ["torso", "brazos_superiores"],
	"Pantalones militares": ["cadera", "piernas"],
	"Chaqueta militar azul": ["torso", "brazos_superiores"],
	"Pantalones militares azules": ["cadera", "piernas"],
	"Chaqueta militar negra II": ["torso", "brazos_superiores"],
	"Pantalones militares negros II": ["cadera", "piernas"],
	"Pantalones camuflaje": ["cadera", "piernas"],
	"Pantalones camuflaje desert": ["cadera", "piernas"],
	"Guantes survival": ["manos"],
	"Guantes militares": ["manos"],
	"Botas survival": ["pies"],
	"Guantes de trabajo": ["manos"],
	"Sombrero de pescador": ["cabeza"],
}

# Maps each clothing item to a body slot for exchange logic.
const CLOTHING_SLOTS := {
	"Camiseta": "torso",
	"Pantalones": "legs",
	"Zapatillas": "feet",
	"Guantes survival": "hands",
	"Botas survival": "feet",
	"Chaqueta militar": "torso",
	"Pantalones militares": "legs",
	"Guantes militares": "hands",
	"Chaqueta militar azul": "torso",
	"Pantalones militares azules": "legs",
	"Chaqueta militar negra II": "torso",
	"Pantalones militares negros II": "legs",
	"Pantalones camuflaje": "legs",
	"Pantalones camuflaje desert": "legs",
	"Guantes de trabajo": "hands",
	"Sombrero de pescador": "head",
}

# Warmth value per clothing item. Higher = warmer.
# Short sleeves / shorts give little warmth; jackets and long pants give more.
const CLOTHING_WARMTH := {
	"Camiseta": 0.05,
	"Pantalones": 0.08,
	"Zapatillas": 0.05,
	"Guantes survival": 0.08,
	"Botas survival": 0.18,
	"Chaqueta militar": 0.28,
	"Pantalones militares": 0.20,
	"Chaqueta militar azul": 0.28,
	"Pantalones militares azules": 0.20,
	"Chaqueta militar negra II": 0.28,
	"Pantalones militares negros II": 0.20,
	"Pantalones camuflaje": 0.20,
	"Pantalones camuflaje desert": 0.20,
	"Guantes militares": 0.10,
	"Guantes de trabajo": 0.08,
	"Sombrero de pescador": 0.07,
}

# Heat protection: reduces body temperature gain in hot environments.
# Hats and headwear shield from the sun; other clothing has no heat protection.
const CLOTHING_HEAT_PROTECTION := {
	"Sombrero de pescador": 0.35,
}

const THIRD_PERSON_MODEL_CANDIDATES := [
	"res://assets/characters/adapted/player_with_clothes.glb",
	"res://assets/animations/inicio.glb",
	"res://assets/animations/walking.glb",
	"res://assets/external/quaternius_zombie_apocalypse/Characters/glTF/Characters_Matt_SingleWeapon.gltf"
]
const THIRD_PERSON_ANIMATION_LIBRARY := preload("res://assets/animations/third_person_animations.res")
const REAL_RIFLE_MODEL := "res://assets/models/weapons/modern_sniper_rifle__free_lowpoly.glb"
const RIFLE_RANGE := 150.0
const RIFLE_NAME := "Rifle francotirador"
const RIFLE_AMMO_TYPE := "7.62x54mm"
const RIFLE_MAG_SIZE := 5
const RIFLE_DAMAGE := 100.0
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
const THIRD_PERSON_EXTERNAL_ATTACK_ANIMATION := "AttackExternal"
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
const THIRD_PERSON_CAMERA_POS := Vector3(0.0, 2.8, 6.5)
const THIRD_PERSON_DEFAULT_SCALE := 1.55
const MIXAMO_CHARACTER_SCALE := 0.72
const MIXAMO_GROUND_CORRECTION := 0.38
const BASE_CARRY_SLOTS := 4
const BASE_CARRY_WEIGHT := 6.0
const TORSO_CARRY_SLOTS := 2
const TORSO_CARRY_WEIGHT := 2.0
const LEGS_CARRY_SLOTS := 2
const LEGS_CARRY_WEIGHT := 2.0
const FEET_CARRY_SLOTS := 1
const FEET_CARRY_WEIGHT := 1.0
const HANDS_CARRY_SLOTS := 1
const HANDS_CARRY_WEIGHT := 1.0
const HEAD_CARRY_SLOTS := 1
const HEAD_CARRY_WEIGHT := 0.5
const SMALL_BACKPACK_SLOTS := 8
const SMALL_BACKPACK_WEIGHT := 10.0

signal prompt_changed(text: String)
signal notice(text: String)
signal item_dropped(item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3, color: Color)

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
var _left_hand_bone_idx: int = -1
var _spine_skeleton: Skeleton3D = null
var _spine_bone_idx: int = -1
var _hand_skeleton: Skeleton3D = null
var _hand_bone_idx: int = -1
var _head_skeleton: Skeleton3D = null
var _head_bone_idx: int = -1
var _backpack_rest_pos: Vector3 = Vector3(0.0, -0.05, -0.18)
var _backpack_crouch_offset: Vector3 = Vector3(0.0, -0.12, -0.06)
var _backpack_action_offset: Vector3 = Vector3(0.0, -0.18, -0.10)
var third_person_left_arm: Node3D
var third_person_right_arm: Node3D
var third_person_left_leg: Node3D
var third_person_right_leg: Node3D
var third_person_animation_player: AnimationPlayer
var third_person_idle_animation := ""
var third_person_walk_animation := ""
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
var is_prone := false
var _sit_cooldown := 0.0
var _auto_sleep_triggered := false
var _clothing_wear_timer := 0.0
var _is_falling_from_height := false
var _fall_height := 0.0
var _max_fall_height := 0.0
var third_person_ground_offset := 0.0
var third_person_has_real_idle := false
var _pain_audio_player: AudioStreamPlayer = null
var _shoot_audio_player: AudioStreamPlayer = null
var _pain_sound_timer := 0.0
var third_person_loaded_path := ""
var third_person_action_animation := ""
var third_person_action_timer := 0.0
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
var _torch_in_hands := false
var _has_rifle := false
var _rifle_in_hands := false
var _is_reloading := false
var _is_firing := false
var _rifle_magazine := 0
var _rifle_reserve_ammo := 0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _recoil_recover_speed := 3.0
var _wind_dir := Vector3(1.0, 0.0, 0.3).normalized()
var _wind_strength := 0.0
var _wind_target_strength := 0.0
var _wind_timer := 0.0
var _breath_timer := 0.0
var _breath_pitch_offset := 0.0
var _breath_yaw_offset := 0.0
var _breath_hold_timer := 0.0
var _breath_hold_active := false
var _breath_hold_recover := 0.0
var _rifle_bone_attachment: BoneAttachment3D = null
var _rifle_weapon_offset: Node3D = null
var _rifle_root: Node3D = null
var _rifle_model: Node3D = null
var _rifle_on_back: Node3D = null
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
var is_crouching := false
var _force_crouch := false
var is_moving := false
var in_shelter := false
var is_in_water := false
var wetness := 0.0
var flashlight_charge := 0.0
var held_index := 0
var equipped_clothing := ""
var equipped_backpack := ""
# Survival deformable clothing nodes inside the adapted model (mesh name -> node).
var _survival_cloth_nodes := {}
var _survival_body_nodes := {}
var _worn_survival := {}        # item_name -> true while the garment is shown
var _equipped_slots := {}         # slot -> item_name currently equipped

var _pitch := 0.0
var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _walk_bob := 0.0
var _walk_intensity := 0.0
var _turn_input := 0.0
var _water_depth := 0.0
var _water_sink := 0.0
var _water_notice_cooldown := 0.0
var _aim_screen_offset := Vector2.ZERO
var is_puppet := false
var _puppet_anim := "idle"
var _puppet_current_anim := ""
var is_custom_character: bool = false
var is_clothing_model: bool = false
var _custom_body_mesh_name: String = ""
var _custom_clothing_mesh_names: Dictionary = {}
var _camo_texture_cache: Dictionary = {}
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
			_hand_skeleton = _spine_skeleton
			_hand_bone_idx = -1
			if _hand_skeleton != null:
				for bone_name in ["mixamorig:RightHand", "mixamorig:LeftHand", "mixamorig_RightHand", "mixamorig_LeftHand", "RightHand", "LeftHand"]:
					_hand_bone_idx = _hand_skeleton.find_bone(bone_name)
					if _hand_bone_idx != -1:
						break
			_head_skeleton = _spine_skeleton
			_head_bone_idx = -1
			if _head_skeleton != null:
				for bone_name in ["mixamorig:Head", "mixamorig_Head", "Head"]:
					_head_bone_idx = _head_skeleton.find_bone(bone_name)
					if _head_bone_idx != -1:
						break
	set_process(true)
	set_process_input(false)
	set_physics_process(false)

var _puppet_clothing := ""
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
	if is_dead:
		# Still update position for dead puppets (corpse sync)
		global_position = pos
		rotation.y = rot
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
		if third_person_animation_player != null:
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
			elif lower.find("attack") >= 0:
				target = third_person_attack_animation
			elif lower.find("sit") >= 0:
				target = third_person_sit_animation
			elif lower.find("sleep") >= 0:
				target = third_person_sleep_animation
			elif lower.find("drink") >= 0:
				target = third_person_drink_animation
			elif lower.find("dying") >= 0 or lower.find("dead") >= 0:
				target = third_person_dying_animation
			elif lower.find("low") >= 0:
				target = third_person_low_health_animation
		if not target.is_empty() and third_person_animation_player.has_animation(target):
			third_person_animation_player.play(target, 0.15)
			_puppet_current_anim = anim

func puppet_apply_visuals(clothing: String, held_item: String, backpack: String) -> void:
	if not is_puppet:
		return
	# If dead and naked swap not yet done, ensure pending is active
	if is_dead and clothing.is_empty() and not _puppet_naked_pending:
		if third_person_model != null and third_person_model.name != "NakedCorpse":
			_puppet_naked_pending = true
			_puppet_naked_timer = 0.0
	# Update clothing
	if clothing != _puppet_clothing:
		var old_items: Array = []
		for item_name in _puppet_clothing.split(","):
			var name := item_name.strip_edges()
			if not name.is_empty():
				old_items.append(name)
		_puppet_clothing = clothing
		var new_items: Array = []
		if clothing.is_empty():
			if is_dead:
				# Dead body: delay naked swap until death animation finishes
				_puppet_naked_pending = true
				_puppet_naked_timer = 0.0
				new_items = []
			else:
				# Living puppet with no clothing: show naked body
				new_items = []
		else:
			for item_name in clothing.split(","):
				var name := item_name.strip_edges()
				if not name.is_empty():
					new_items.append(name)
		# Unequip items that were worn before but are no longer in the list
		for name in old_items:
			if not new_items.has(name):
				unequip_clothing(name)
		# Equip items in the new list
		for name in new_items:
			equip_clothing(name)
	# Update held item
	if held_item != _puppet_held:
		_puppet_held = held_item
		_update_puppet_held_item(held_item)
	# Update backpack
	if backpack != _puppet_backpack:
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
		else:
			tmat.albedo_texture = null
			tmat.albedo_color = _puppet_top_color
		top_mi.material_override = tmat
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
		else:
			bmat.albedo_texture = null
			bmat.albedo_color = _puppet_bottom_color
		bot_mi.material_override = bmat
	# Apply Shoes
	var shoes_mi: MeshInstance3D = _find_mesh_in_third_person("Shoes")
	if shoes_mi != null:
		var skey := "puppet_shoes"
		var smat: StandardMaterial3D = _skin_mat_cache.get(skey) as StandardMaterial3D
		if smat == null:
			smat = StandardMaterial3D.new()
			smat.roughness = 0.8
			_skin_mat_cache[skey] = smat
		smat.albedo_color = _puppet_shoes_color
		shoes_mi.material_override = smat
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

func puppet_set_torch(lit: bool) -> void:
	if not is_puppet:
		return
	if torch_light != null:
		torch_light.visible = lit

func puppet_set_flashlight(on: bool) -> void:
	if not is_puppet:
		return
	if flashlight != null:
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
	# Remove any worn visual garments
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
	# Clear current held item
	for child in third_person_hand_item_root.get_children():
		third_person_hand_item_root.remove_child(child)
		child.free()
	if item_name.is_empty():
		return
	# Build visual based on item name
	match item_name:
		"Cuchillo":
			_build_third_person_knife()
		"Rifle francotirador":
			_build_third_person_rifle()
		"Hacha":
			_build_third_person_axe()
		"Pala":
			_build_third_person_tool(REAL_SHOVEL_MODEL, "PuppetShovel", Color(0.6, 0.4, 0.2))
		"Martillo":
			_build_third_person_tool(REAL_HAMMER_MODEL, "PuppetHammer", Color(0.5, 0.5, 0.5))
		"Pico":
			_build_third_person_tool(REAL_PICKAXE_MODEL, "PuppetPickaxe", Color(0.4, 0.4, 0.4))
		"Botella de agua":
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
		_:
			_build_third_person_pack()


#region PROCESO PRINCIPAL (_process + input)
func _process(delta: float) -> void:
	if is_puppet:
		_update_hand_socket()
		_update_torch_hand_socket()
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
	# Breath hold: press Shift while aiming to steady aim, limited duration
	if _is_aiming and Input.is_key_pressed(KEY_SHIFT) and _breath_hold_recover <= 0.0:
		if not _breath_hold_active:
			_breath_hold_active = true
			_breath_hold_timer = 0.0
	if _breath_hold_active:
		_breath_hold_timer += delta
		if _breath_hold_timer > 5.0:
			_breath_hold_active = false
			_breath_hold_recover = 4.0
	if _breath_hold_recover > 0.0:
		_breath_hold_recover -= delta
	if _is_aiming and not is_moving:
		# Fatigue increases breath amplitude: less energy = more sway
		var fatigue_mult := 1.0
		if stats != null:
			fatigue_mult = 1.0 + (1.0 - clamp(stats.energy / 100.0, 0.0, 1.0)) * 1.5
		var breath_amp_pitch := 2.5 * fatigue_mult
		var breath_amp_yaw := 1.8 * fatigue_mult
		if _breath_hold_active:
			var hold_factor: float = 1.0 - clamp(_breath_hold_timer / 5.0, 0.0, 1.0)
			breath_amp_pitch *= 0.1 * hold_factor
			breath_amp_yaw *= 0.1 * hold_factor
		_breath_pitch_offset = deg_to_rad(breath_amp_pitch * sin(_breath_timer * 1.2))
		_breath_yaw_offset = deg_to_rad(breath_amp_yaw * sin(_breath_timer * 0.8))
		if is_prone:
			_breath_pitch_offset *= 0.3
			_breath_yaw_offset *= 0.3
		elif is_crouching:
			_breath_pitch_offset *= 0.5
			_breath_yaw_offset *= 0.5
	_crosshair_check_timer += delta
	if _crosshair_check_timer >= 0.5:
		_crosshair_check_timer = 0.0
		var main := get_tree().current_scene
		if main != null and main.hud != null:
			_update_crosshair(_has_rifle_equipped())
	# Update rifle: two-point alignment
	if _rifle_weapon_offset != null and is_instance_valid(_rifle_weapon_offset) and _rifle_bone_attachment != null and is_instance_valid(_rifle_bone_attachment):
		var skel := _spine_skeleton if _spine_skeleton != null and is_instance_valid(_spine_skeleton) else _find_skeleton(third_person_model)
		if skel != null:
			_update_rifle_ik(skel, delta)
	# Update rifle strap mesh in real-time to follow animations
	_update_rifle_strap(delta)
	# Camera overrides for debug views only
	if camera != null and (_frontal_camera or _side_camera or _left_camera or _rear_camera or _top_camera):
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

	equipment = PlayerEquipmentScript.new()
	equipment.name = "PlayerEquipment"
	add_child(equipment)

	hands = PlayerHandsScript.new()
	hands.name = "PlayerHands"
	add_child(hands)

	_add_starting_items()
	_create_body()
	_recalculate_carry_capacity()
	_select_default_held_item()
	_sync_held_item()
	_apply_view_mode()
	call_deferred("_capture_mouse")

func _input(event: InputEvent) -> void:
	if is_puppet or is_dead:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseButton and event.pressed:
		_capture_mouse()
		var has_rifle := _has_rifle_equipped()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if has_rifle:
				_shoot_rifle()
			else:
				_melee_attack()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if has_rifle and not _is_aiming:
				_toggle_aim()
			else:
				_quick_use_held_item()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_fov = clamp(_camera_fov - 4.0, 30.0, 90.0)
			if camera != null:
				camera.fov = _camera_fov
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_fov = clamp(_camera_fov + 4.0, 30.0, 90.0)
			if camera != null:
				camera.fov = _camera_fov
	elif event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT and _is_aiming:
			_toggle_aim()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_turn_input = clamp(event.relative.x, -80.0, 80.0)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-78.0), deg_to_rad(78.0))
		if camera != null:
			camera.rotation.x = _pitch + _recoil_pitch + _breath_pitch_offset
			if _is_aiming:
				camera.rotation.y = _breath_yaw_offset * 0.5
	if event.is_action_pressed("interact"):
		_interact()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		var target = _get_interaction_target()
		if target != null and target.has_method("interact") and "is_open" in target and target.is_open:
			target.interact(self)
		else:
			_collect()
	if event.is_action_pressed("drop_item"):
		_drop_held_item()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_store_held_item()
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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			_frontal_camera = not _frontal_camera
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			return
		if event.keycode == KEY_2:
			_side_camera = not _side_camera
			_frontal_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			return
		if event.keycode == KEY_3:
			_left_camera = not _left_camera
			_frontal_camera = false
			_side_camera = false
			_rear_camera = false
			_top_camera = false
			return
		if event.keycode == KEY_4:
			_rear_camera = not _rear_camera
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_top_camera = false
			return
		if event.keycode == KEY_5:
			_top_camera = not _top_camera
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			return
		if event.keycode == KEY_6:
			_frontal_camera = false
			_side_camera = false
			_left_camera = false
			_rear_camera = false
			_top_camera = false
			return
		var inventory_index := _inventory_index_for_key(event.keycode)
		if inventory_index >= 0:
			held_index = inventory_index
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
		if event.keycode == KEY_T and _has_rifle_equipped():
			_reload_rifle()
			return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

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
	# Food items: first put in hand, then eat with animation when used again
	if item_type == "food":
		if held_index == index and hands != null and hands.has_item_in_hands():
			_eat_held_item()
		else:
			held_index = index
			_sync_held_item()
			notice.emit("Tienes %s en la mano. Pulsa usar de nuevo para comer." % item_name)
		return
	# Water items: first put in hand, then drink with animation when used again
	if item_type == "water":
		if held_index == index and hands != null and hands.has_item_in_hands():
			_drink_held_item()
		else:
			held_index = index
			_sync_held_item()
			notice.emit("Tienes %s en la mano. Pulsa usar de nuevo para beber." % item_name)
		return
	# Plastic bottle: put in hand, then fill at river
	if item_name == "Botella de plastico":
		held_index = index
		_sync_held_item()
		notice.emit("Tienes la botella en la mano. Ve al rio y pulsa E para llenarla.")
		return
	var used: bool = inventory.use_index(index, stats)
	if used:
		stats.changed.emit()
	if used and item_type == "clothing":
		var _inv_color: Color = item.get_meta("clothing_color", Color(0, 0, 0, 0))
		equip_clothing(item_name, _inv_color)
	elif not used:
		_sync_held_item()

func _on_inventory_changed() -> void:
	_recalculate_carry_capacity()
	_sync_held_item()

#endregion


#region ROPA Y APARIENCIA (PlayerAppearance)
func get_current_clothing_color(item_name: String) -> Color:
	if inventory != null:
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
	return Color(0, 0, 0, 0)

func equip_clothing(item_name: String, clothing_color: Color = Color(0, 0, 0, 0)) -> void:
	var slot := ""
	if CLOTHING_SLOTS.has(item_name):
		slot = CLOTHING_SLOTS[item_name]
	# Unequip previous item in the same slot and drop it on the ground
	if not slot.is_empty() and _equipped_slots.get(slot, "") != item_name:
		var prev_name := str(_equipped_slots.get(slot, ""))
		if not prev_name.is_empty() and prev_name != item_name:
			var prev_color := get_current_clothing_color(prev_name)
			unequip_clothing(prev_name)
			# Remove old clothing from inventory and drop it on the ground
			if inventory != null:
				for i in range(inventory.items.size()):
					if str(inventory.items[i].item_name) == prev_name:
						if false:
							pass
						inventory.remove_index(i)
						break
			var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
			drop_pos.y = global_position.y
			item_dropped.emit(prev_name, "clothing", 0.5, 1, 0.1, drop_pos, prev_color)
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
			var mat := StandardMaterial3D.new()
			mat.albedo_color = clothing_color
			mat.roughness = 0.8
			mat.metallic = 0.0
			bn.material_override = mat
	elif SURVIVAL_CLOTHING.has(item_name):
		_wear_survival_clothing(item_name, true, clothing_color)
	else:
		_wear_clothing_visual(item_name, clothing_color)
	if not slot.is_empty():
		_equipped_slots[slot] = item_name
	# Custom character: show the clothing mesh, hide Desnudo_* for covered zones
	# Skip for survival clothing items — _wear_survival_clothing handles mesh visibility
	if is_custom_character and not slot.is_empty() and not SURVIVAL_CLOTHING.has(item_name):
		var cloth_mi := _find_custom_slot_mesh(slot)
		if cloth_mi != null:
			cloth_mi.visible = true
			if clothing_color.a > 0.0:
				var mat := StandardMaterial3D.new()
				mat.albedo_color = clothing_color
				mat.roughness = 0.8
				mat.metallic = 0.0
				cloth_mi.material_override = mat
		# Hide Desnudo_* parts covered by this clothing item
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = false
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
	# Remove the attached 3D garment visual (vests, hat, rubber boots, gloves)
	# so swapping two visual garments in the same slot doesn't leave the old one
	# stuck on the character.
	if CLOTHING_VISUALS.has(item_name) and third_person_model != null:
		var worn := third_person_model.get_node_or_null("Worn_" + item_name)
		if worn != null:
			worn.free()
		_head_worn_rel.erase("Worn_" + item_name)
	if CLOTHING_SLOTS.has(item_name):
		if _equipped_slots.get(slot, "") == item_name:
			_equipped_slots.erase(slot)
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
func _init_survival_clothing(root: Node) -> void:
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
			if wanted.has(mi.name):
				_survival_cloth_nodes[mi.name] = mi
				mi.visible = false
				if mi.name == "cloth_hands" or mi.name == "cloth_feet":
					var black_mat := StandardMaterial3D.new()
					black_mat.albedo_color = Color(0.05, 0.05, 0.05)
					black_mat.roughness = 0.9
					mi.material_override = black_mat
			elif body_names.has(mi.name):
				_survival_body_nodes[mi.name] = mi
				mi.visible = false
				if mi.name == "Shoes":
					var shoe_mat := StandardMaterial3D.new()
					shoe_mat.albedo_color = Color(0.85, 0.82, 0.78)
					shoe_mat.roughness = 0.8
					mi.material_override = shoe_mat
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
		else:
			tmat.albedo_texture = null
			tmat.albedo_color = top_color
		top_mi.material_override = tmat
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
		else:
			bmat.albedo_texture = null
			bmat.albedo_color = bottom_color
		bot_mi.material_override = bmat
	# Apply Shoes
	var shoes_mi: MeshInstance3D = _find_mesh_in_third_person("Shoes")
	if shoes_mi != null:
		var smat: StandardMaterial3D = _skin_mat_cache.get("char_shoes") as StandardMaterial3D
		if smat == null:
			smat = StandardMaterial3D.new()
			smat.roughness = 0.8
			_skin_mat_cache["char_shoes"] = smat
		smat.albedo_color = shoes_color
		shoes_mi.material_override = smat
	# Apply skin color to Desnudo_* (bare skin) and Body_* (base body)
	for body_name in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet",
			"Body_torso", "Body_arms", "Body_hands", "Body_legs", "Body_feet"]:
		var bmi: MeshInstance3D = _find_mesh_in_third_person(body_name)
		_tint_mesh(bmi, skin_color, 0.9)
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

func _make_camo_texture(base_color: Color = Color(0.25, 0.3, 0.15)) -> ImageTexture:
	var cache_key := str(base_color)
	if _camo_texture_cache.has(cache_key):
		return _camo_texture_cache[cache_key]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var camo_colors := [base_color, base_color.darkened(0.3), base_color.lightened(0.2), base_color.darkened(0.5)]
	img.fill(camo_colors[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for blob in range(40):
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var radius := rng.randi_range(8, 25)
		var color: Color = camo_colors[rng.randi() % camo_colors.size()]
		for x in range(maxi(0, cx - radius), mini(size, cx + radius)):
			for y in range(maxi(0, cy - radius), mini(size, cy + radius)):
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy <= radius * radius:
					img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_camo_texture_cache[cache_key] = tex
	return tex

# Shows/hides a survival garment mesh and toggles the Mixamo default meshes it
# replaces (e.g. wearing the jacket hides the default Tops to avoid clipping).
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

func _tint_mesh(mi: MeshInstance3D, color: Color, roughness: float = 0.9) -> void:
	if mi == null:
		return
	var orig := mi.get_active_material(0)
	if orig != null and orig is StandardMaterial3D:
		var mat := (orig as StandardMaterial3D).duplicate()
		mat.albedo_color = color
		mat.roughness = roughness
		mi.material_override = mat
	else:
		var mat2 := StandardMaterial3D.new()
		mat2.albedo_color = color
		mat2.roughness = roughness
		mi.material_override = mat2

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
	var src_path := "res://assets/adapted/player_with_clothes.glb"
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
	var survival_mesh_names := ["cloth_hands", "cloth_feet"]
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
	var cfg: Dictionary = SURVIVAL_CLOTHING[item_name]
	var mesh_name := String(cfg["mesh"])
	var mi: MeshInstance3D = _survival_cloth_nodes.get(mesh_name)
	if mi != null:
		mi.visible = worn
		if worn and loot_color.a > 0.0:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = loot_color
			mat.roughness = 0.85
			mat.metallic = 0.0
			mi.material_override = mat
		elif worn and (cfg.has("tint") or cfg.has("camo")):
			var mat := StandardMaterial3D.new()
			mat.roughness = 0.85
			mat.metallic = 0.0
			if cfg.has("camo"):
				mat.albedo_texture = _make_camo_texture(cfg["camo"])
				mat.albedo_color = Color.WHITE
			else:
				mat.albedo_color = cfg["tint"]
			mi.material_override = mat
		elif worn:
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
	node = _load_external_node3d(str(cfg["path"]))
	if node == null:
		return
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
	if loot_color.a > 0.0:
		var meshes2: Array = []
		_collect_mesh_instances(node, meshes2)
		for mi in meshes2:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = loot_color
			mat.roughness = 0.9
			mat.metallic = 0.0
			mi.material_override = mat
	elif cfg.has("tint"):
		var tint: Color = cfg["tint"]
		var meshes: Array = []
		_collect_mesh_instances(node, meshes)
		for mi in meshes:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.roughness = 0.9
			mat.metallic = 0.0
			mi.material_override = mat
	# If this is a head-slot item and we have a head bone, store the relative
	# transform so _update_head_worn_items() can follow the bone each frame.
	if CLOTHING_SLOTS.get(item_name, "") == "head" and _head_skeleton != null and _head_bone_idx >= 0:
		var bone_pose := _head_skeleton.get_bone_global_pose(_head_bone_idx)
		var skel_global := _head_skeleton.global_transform
		var bone_world := skel_global * bone_pose
		var local_to_model := third_person_model.global_transform.affine_inverse()
		var bone_local := local_to_model * bone_world
		_head_worn_rel[worn_name] = bone_local.affine_inverse() * node.transform
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
	if exclude_worn and node.name.begins_with("Worn_"):
		return
	if exclude_worn and (node.name == "BackpackSocket" or node.name == "HandsSocket"):
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
	_recalculate_carry_capacity()
	_sync_held_item()
	if inventory != null:
		inventory.changed.emit()

func refresh_carry_capacity() -> void:
	_recalculate_carry_capacity()
	_sync_held_item()

func _recalculate_carry_capacity() -> void:
	if inventory == null:
		return
	var slots := BASE_CARRY_SLOTS
	var weight := BASE_CARRY_WEIGHT
	# Bonus per equipped clothing slot
	for slot in _equipped_slots:
		match slot:
			"torso":
				slots += TORSO_CARRY_SLOTS
				weight += TORSO_CARRY_WEIGHT
			"legs":
				slots += LEGS_CARRY_SLOTS
				weight += LEGS_CARRY_WEIGHT
			"feet":
				slots += FEET_CARRY_SLOTS
				weight += FEET_CARRY_WEIGHT
			"hands":
				slots += HANDS_CARRY_SLOTS
				weight += HANDS_CARRY_WEIGHT
			"head":
				slots += HEAD_CARRY_SLOTS
				weight += HEAD_CARRY_WEIGHT
	# Backpack bonus only if actually equipped (not just in inventory)
	if not equipped_backpack.is_empty():
		slots += SMALL_BACKPACK_SLOTS
		weight += SMALL_BACKPACK_WEIGHT
	inventory.max_slots = slots
	inventory.max_weight = weight

func _recalculate_warmth() -> void:
	if stats == null:
		return
	var total := 0.0
	for slot in _equipped_slots:
		var item_name: String = str(_equipped_slots[slot])
		if CLOTHING_WARMTH.has(item_name):
			total += CLOTHING_WARMTH[item_name]
	stats.warmth_bonus = total
	stats.changed.emit()

func _recalculate_heat_protection() -> void:
	if stats == null:
		return
	var total := 0.0
	for slot in _equipped_slots:
		var item_name: String = str(_equipped_slots[slot])
		if CLOTHING_HEAT_PROTECTION.has(item_name):
			total += CLOTHING_HEAT_PROTECTION[item_name]
	stats.heat_protection_bonus = total
	stats.changed.emit()

func _get_carry_weight_ratio() -> float:
	if inventory == null or inventory.max_weight <= 0.0:
		return 0.0
	var current: float = inventory.get_total_weight()
	return clamp(current / inventory.max_weight, 0.0, 1.0)

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

#endregion


#region FÍSICA Y MOVIMIENTO (_physics_process)
func _physics_process(delta: float) -> void:
	if is_puppet:
		return
	_pain_sound_timer = max(0.0, _pain_sound_timer - delta)
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_shoot_cooldown = max(0.0, _shoot_cooldown - delta)
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
			for item in inventory.items:
				if item != null and item.item_type == "clothing" and item.has_method("reduce_durability"):
					var is_equipped := false
					for slot_val in _equipped_slots.values():
						if str(slot_val) == item.item_name:
							is_equipped = true
							break
					if is_equipped:
						item.reduce_durability(1.0)
						if item.is_broken():
							notice.emit("%s se ha deteriorado y ya no sirve." % item.item_name)
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
		return
	# Auto-sleep when sleep reaches minimum
	if not is_sleeping and stats.sleep <= 0.0 and not _auto_sleep_triggered and not is_in_water:
		_auto_sleep_triggered = true
		start_sleep()
		notice.emit("Te quedas dormido del cansancio. Pulsa D para despertar.")
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
			_pitch = lerp(_pitch, deg_to_rad(-12.0), delta * 5.0)
			camera.rotation.x = _pitch
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
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
	if Input.is_action_just_pressed("crouch"):
		is_crouching = not is_crouching
		_force_crouch = false
	if _force_crouch and input_dir.length() < 0.1:
		is_crouching = true
	_update_crouch_collision()
	is_sprinting = Input.is_key_pressed(KEY_R) and not is_crouching and stats.energy > 4.0 and input_dir.length() > 0.1
	var carry := _get_carry_weight_ratio()
	var speed := crouch_speed if is_crouching else (sprint_speed * (1.0 - carry * 0.4) if is_sprinting else walk_speed * (1.0 - carry * 0.2))
	# Reduce speed when aiming with rifle for careful movement
	if _is_aiming and _has_rifle_equipped():
		speed = crouch_speed * 0.8
		is_sprinting = false
	# Lock movement while attacking
	if third_person_action_timer > 0.0 and third_person_action_animation == third_person_attack_animation:
		direction = Vector3.ZERO
		speed = 0.0
		is_sprinting = false
	if is_sprinting:
		stats.energy = max(0.0, stats.energy - (3.0 + carry * 7.0) * delta)
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
	elif not is_jumping and is_on_floor():
		stats.energy = min(stats.max_stat, stats.energy + (8.0 - carry * 4.0) * delta)
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
	_update_water_state(delta)
	if is_in_water:
		speed = crouch_speed if is_crouching else walk_speed
		speed *= lerp(0.72, 0.48, _water_depth)
		is_sprinting = false

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if is_jumping:
		velocity.y -= _gravity * delta
		move_and_slide()
		if not is_on_floor():
			_jump_apex = true
		if _jump_apex and is_on_floor() and velocity.y <= 0.0:
			is_jumping = false
			_jump_velocity = 0.0
			velocity.y = 0.0
			_jump_animation_timer = 0.0
			_is_falling_from_height = false
			_fall_height = 0.0
			_max_fall_height = 0.0
			_jump_apex = false
	elif not is_on_floor():
		if not _is_falling_from_height:
			_is_falling_from_height = true
			_fall_height = global_position.y
		_max_fall_height = max(_max_fall_height, global_position.y)
		velocity.y -= _gravity * delta
		move_and_slide()
		if is_on_floor():
			_is_falling_from_height = false
			_fall_height = 0.0
			_max_fall_height = 0.0
			velocity.y = 0.0
	else:
		velocity.y = -1.0
		move_and_slide()
		velocity.y = 0.0

	_update_walk_motion(delta, input_dir.length())
	_interaction_prompt_timer += delta
	if _interaction_prompt_timer >= 0.1:
		_interaction_prompt_timer = 0.0
		_update_interaction_prompt()
	_update_flashlight(delta)
	_update_torch(delta)
	_update_backpack_socket()
	_update_hand_socket()
	_update_torch_hand_socket()
	_update_head_worn_items()

#endregion


#region SOCKETS Y ACCESORIOS (mochila, manos, cabeza)
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
	var offset := _backpack_rest_pos
	var tilt := 0.0
	if third_person_action_timer > 0.0:
		offset += _backpack_action_offset
		tilt = 12.0
	elif is_crouching:
		offset += _backpack_crouch_offset
		tilt = 8.0
	third_person_back_item_root.position = bone_local.origin + offset
	third_person_back_item_root.rotation_degrees = Vector3(tilt, 0.0, 0.0)

var _hand_socket_offset := Vector3(0.10, 0.0, 0.0)
var _head_worn_rel: Dictionary = {}

func _update_hand_socket() -> void:
	if _hand_skeleton == null or _hand_bone_idx < 0 or third_person_hand_item_root == null:
		return
	if not is_instance_valid(_hand_skeleton) or not is_instance_valid(third_person_hand_item_root):
		return
	var bone_pose := _hand_skeleton.get_bone_global_pose(_hand_bone_idx)
	var skel_global := _hand_skeleton.global_transform
	var bone_world := skel_global * bone_pose
	var local_to_model := third_person_model.global_transform.affine_inverse()
	var bone_local := local_to_model * bone_world
	third_person_hand_item_root.position = bone_local.origin + _hand_socket_offset
	var euler := bone_local.basis.get_euler()
	third_person_hand_item_root.rotation_degrees = Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))

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

#endregion


#region ENTORNO (agua, temperatura)
func _update_water_state(delta: float) -> void:
	_water_notice_cooldown = max(0.0, _water_notice_cooldown - delta)
	var river_depth := _query_river_depth()
	_water_depth = river_depth
	is_in_water = river_depth > 0.02
	if is_in_water:
		wetness = min(1.0, wetness + delta * (0.38 + river_depth * 0.55))
		stats.wetness = wetness
		stats.energy = max(0.0, stats.energy - delta * 0.018 * (0.8 + river_depth))
		stats.body_temperature = max(32.0, stats.body_temperature - delta * 0.020 * (0.5 + wetness + river_depth))
		_stats_emit_timer += delta
		if _stats_emit_timer >= 0.25:
			_stats_emit_timer = 0.0
			stats.changed.emit()
		if _water_notice_cooldown <= 0.0:
			notice.emit("Te mojas. La ropa fria te roba calor.")
			_water_notice_cooldown = 8.0
	else:
		if wetness <= 0.0:
			return
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
		var dry_rate: float = 0.035 + max(0.0, (ambient - 10.0)) * 0.008
		wetness = max(0.0, wetness - delta * dry_rate)
		stats.wetness = wetness
		if wetness > 0.05:
			stats.body_temperature = max(32.0, stats.body_temperature - delta * 0.008 * wetness)
			_stats_emit_timer += delta
			if _stats_emit_timer >= 0.25:
				_stats_emit_timer = 0.0
				stats.changed.emit()

func _query_river_depth() -> float:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_river_depth_at"):
		return float(scene.call("get_river_depth_at", global_position))
	return 0.0

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
	inventory.add_item(ItemScript.create("Camiseta", "clothing", 0.3, 1, 0.05))
	inventory.add_item(ItemScript.create("Pantalones", "clothing", 0.5, 1, 0.10))
	inventory.add_item(ItemScript.create("Zapatillas", "clothing", 0.4, 1, 0.08))

func _create_third_person_model() -> void:
	var character: Node3D = null
	# Always use player_with_clothes.glb for the in-game model
	var model_path := ADAPTED_PLAYER_MODEL
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
							equip_clothing(str(item.item_name), _def_color)
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
	_head_skeleton = _spine_skeleton
	_head_bone_idx = -1
	if _head_skeleton != null:
		for bone_name in ["mixamorig:Head", "mixamorig_Head", "Head"]:
			_head_bone_idx = _head_skeleton.find_bone(bone_name)
			if _head_bone_idx != -1:
				break

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
	_load_torch_animations()
	# Warm the rifle model cache at startup so selecting it later is instant.
	if not is_puppet:
		var warm_rifle := _load_external_node3d(REAL_RIFLE_MODEL)
		if warm_rifle != null:
			warm_rifle.queue_free()
	var names := third_person_animation_player.get_animation_list()
	var non_loop_keywords := ["jump", "attack", "dying", "dead", "drink", "interact", "gather", "plant", "fish", "coger", "recoger", "beber", "muerto", "pegar", "riflefire"]
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
	var src_model: Node3D = load(ADAPTED_PLAYER_MODEL).instantiate()
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
	match action_name:
		"plant":
			target_animation = third_person_plant_animation
		"fish":
			target_animation = third_person_fish_animation
		"forage":
			target_animation = third_person_gather_animation
			if target_animation.is_empty():
				target_animation = third_person_interact_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
		"pickup", "collect":
			target_animation = third_person_interact_animation
		"cook":
			target_animation = third_person_sit_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
		"drink":
			target_animation = third_person_drink_animation
			if target_animation.is_empty():
				target_animation = third_person_plant_animation
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
	third_person_action_animation = target_animation
	third_person_action_timer = duration
	third_person_animation_player.play(target_animation, 0.08)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	_is_aiming = false
	_remove_scope_overlay()
	mouse_sensitivity = 0.0025
	_death_anim_played = true
	death_pose_time = 0.0
	_apply_view_mode()
	flashlight.visible = false
	velocity = Vector3.ZERO
	stats.health = 0.0
	stats.dead = true
	stats.changed.emit()
	if third_person_animation_player != null:
		third_person_animation_player.stop()
	# Unequip all clothing so the body shows naked parts
	for slot in _equipped_slots.keys():
		var equipped_item := str(_equipped_slots[slot])
		if not equipped_item.is_empty():
			unequip_clothing(equipped_item)

func _update_death_pose(delta: float) -> void:
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
	# For custom characters and clothing model, use skeleton foot bone global positions
	# which are more accurate than mesh AABB (which reflects T-pose, not actual pose)
	var min_y := 1000000.0
	if is_custom_character or is_clothing_model:
		var skeleton := _find_skeleton(third_person_model)
		if skeleton != null:
			for i in range(skeleton.get_bone_count()):
				var bone_name := skeleton.get_bone_name(i)
				if bone_name.find("Foot") >= 0 or bone_name.find("foot") >= 0 or bone_name.find("Toe") >= 0 or bone_name.find("toe") >= 0:
					var gp := skeleton.get_bone_global_pose(i)
					# For clothing model, bone poses are in skeleton local space (cm).
					# Convert to world space via skeleton.global_transform (includes model scale).
					if is_clothing_model:
						var world_pos: Vector3 = skeleton.global_transform * gp.origin
						min_y = min(min_y, world_pos.y)
					else:
						min_y = min(min_y, gp.origin.y)
	# Fallback: use global AABB of non-Body meshes
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
			min_y = min(min_y, world_aabb.position.y)
		third_person_model.visible = was_visible
	if min_y < 999999.0:
		third_person_ground_offset = -min_y + 0.45
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

func _select_default_held_item() -> void:
	for i in range(inventory.items.size()):
		if inventory.items[i].item_type == "weapon_rifle":
			held_index = i
			return
	for i in range(inventory.items.size()):
		if inventory.items[i].item_type == "weapon":
			held_index = i
			return
	for i in range(inventory.items.size()):
		if inventory.items[i].item_type == "tool_axe":
			held_index = i
			return
	held_index = 0

func equip_item_by_name(item_name: String) -> void:
	if inventory == null:
		return
	for i in range(inventory.items.size() - 1, -1, -1):
		if inventory.items[i].item_name == item_name:
			held_index = i
			_sync_held_item()
			return

func get_held_item():
	if inventory == null or inventory.items.is_empty():
		return null
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	return inventory.items[held_index]

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
	if hands != null:
		hands.clear_hands()

func _cycle_held_item() -> void:
	if inventory.items.is_empty():
		return
	if _is_aiming:
		_cancel_aim()
	held_index = (held_index + 1) % inventory.items.size()
	_sync_held_item()
	var item = inventory.items[held_index]
	notice.emit("En mano: %s." % item.item_name)

func _craft_campfire() -> void:
	if inventory == null:
		return
	if not inventory.has_item_name("Tronco", 2):
		notice.emit("Necesitas 2 troncos para craftear una fogata.")
		return
	if not inventory.has_item_name("Palo", 1):
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
	pos.y = 0.15
	item_dropped.emit("campfire", "campfire", 0.0, 1, 0.0, pos, Color(0, 0, 0, 0))
	notice.emit("Has crafteado una fogata. Enciendela con cerillas.")

func _craft_shelter() -> void:
	if inventory == null:
		return
	if not inventory.has_item_name("Palo", 11):
		notice.emit("Necesitas 11 palos para construir un refugio.")
		return
	inventory.consume_item_name("Palo", 11)
	play_action_animation("plant", 3.0)
	notice.emit("Construyendo refugio...")
	var parent_node := get_parent()
	if parent_node != null and parent_node.has_node("HUD"):
		var hud_node := parent_node.get_node("HUD")
		if hud_node != null and hud_node.has_method("show_countdown"):
			hud_node.show_countdown("Construyendo refugio", 3.0)
	await get_tree().create_timer(3.0).timeout
	var pos: Vector3 = global_position + (global_transform.basis * Vector3.FORWARD * 2.0)
	pos.y = 0.0
	item_dropped.emit("shelter", "shelter", 0.0, 1, 0.0, pos, Color(0, 0, 0, 0))
	notice.emit("Has construido un refugio.")

func craft_recipe(recipe: Dictionary) -> void:
	if inventory == null:
		return
	var out: Dictionary = recipe["output"]
	# Fogata uses the full campfire flow with animation + spawn
	if out["type"] == "campfire":
		_craft_campfire()
		return
	if out["type"] == "shelter":
		_craft_shelter()
		return
	# Unequip any clothing items that will be consumed by this recipe
	for input_name in recipe["inputs"]:
		if CLOTHING_SLOTS.has(input_name):
			for sk in _equipped_slots.keys():
				if str(_equipped_slots[sk]) == input_name:
					unequip_clothing(input_name)
					break
	if not CraftingSystemScript.craft(recipe, inventory):
		notice.emit("No tienes los materiales necesarios.")
		return
	inventory.changed.emit()
	# Play crafting animation
	play_action_animation("forage", 2.0)
	notice.emit("Has crafteado: %s." % out["name"])

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
	if inventory == null or inventory.items.is_empty():
		notice.emit("No tienes nada en la mano.")
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	var item = inventory.items[held_index]
	if item.item_type != "food":
		notice.emit("No tienes comida en la mano.")
		return
	# Canned food must be opened with knife/axe before eating
	if item.item_name.begins_with("Lata de ") and item.durability > 0.0:
		if not _inventory_has_blade():
			notice.emit("Necesitas un cuchillo o hacha para abrir la lata.")
			return
		if item.quantity > 1:
			# Split one can from the stack, open only that one
			item.quantity -= 1
			var opened = ItemScript.create(item.item_name + " abierta", item.item_type, item.weight, 1, item.use_value)
			opened.durability = 0.0
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
			_sync_held_item()
		else:
			item.durability = 0.0
			item.item_name = item.item_name + " abierta"
			inventory.changed.emit()
		notice.emit("Abres la lata con el cuchillo. Ahora puedes comer.")
		return
	# Play eating animation (same as campfire crafting)
	play_action_animation("plant", 2.0)
	notice.emit("Comiendo %s..." % item.item_name)
	# Consume the food after animation
	var item_name := str(item.item_name)
	var food_value := float(item.use_value)
	var eat_timer := Timer.new()
	eat_timer.wait_time = 2.0
	eat_timer.one_shot = true
	eat_timer.timeout.connect(func():
		if stats != null:
			stats.consume_food(food_value)
			stats.changed.emit()
		inventory.remove_index(held_index)
		inventory.changed.emit()
		_sync_held_item()
		notice.emit("Comes %s. +%d hambre." % [item_name, int(food_value)])
		if item_name == "Carne humana":
			notice.emit("La carne humana esta en mal estado... te sientes muy mal.")
			if stats != null:
				stats.health = 0.0
				stats.changed.emit()
			if has_method("die"):
				die()
	)
	add_child(eat_timer)
	eat_timer.start()

func _drink_held_item() -> void:
	if inventory == null or inventory.items.is_empty():
		notice.emit("No tienes nada en la mano.")
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	var item = inventory.items[held_index]
	if item.item_type != "water":
		notice.emit("No tienes agua en la mano.")
		return
	# Show drink bottle model in hand during animation
	_build_third_person_plastic_bottle()
	play_action_animation("drink", 2.0)
	notice.emit("Bebiendo %s..." % item.item_name)
	var item_name := str(item.item_name)
	var drink_timer := Timer.new()
	drink_timer.wait_time = 2.0
	drink_timer.one_shot = true
	drink_timer.timeout.connect(func():
		if stats != null:
			stats.thirst = min(stats.max_stat, stats.thirst + item.use_value)
			if stats.thirst > 35.0:
				stats.health = min(stats.max_health, stats.health + max(2.0, item.use_value * 0.15))
			stats.changed.emit()
		if item_name == "Botella de agua" and item.has_method("is_broken") and item.is_broken():
			inventory.remove_index(held_index)
			inventory.add_item(ItemScript.create("Botella de plastico", "misc", 0.1, 1, 0.0))
		elif item_name == "Botella de agua":
			item.reduce_durability(float(item.max_durability) * 0.25)
			if item.is_broken():
				inventory.remove_index(held_index)
				inventory.add_item(ItemScript.create("Botella de plastico", "misc", 0.1, 1, 0.0))
		else:
			inventory.remove_index(held_index)
		inventory.changed.emit()
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
		_sync_held_item()
		notice.emit("Bebes %s." % item_name)
	)
	add_child(drink_timer)
	drink_timer.start()

func _drop_held_item() -> void:
	if inventory == null or inventory.items.is_empty():
		notice.emit("No tienes nada que soltar.")
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	drop_inventory_item(held_index)

func _store_held_item() -> void:
	if inventory == null or inventory.items.is_empty():
		notice.emit("No tienes nada en la mano.")
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	var item = inventory.items[held_index]
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
	var eq_bp_set: bool = equipped_backpack == "Mochila pequena"
	if third_person_back_item_root != null:
		if not equip_has_bp:
			for child in third_person_back_item_root.get_children():
				third_person_back_item_root.remove_child(child)
				child.free()
		if inventory != null and not equip_has_bp and eq_bp_set:
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
	if item_type == "backpack":
		equipped_backpack = ""
		_recalculate_carry_capacity()
	if CLOTHING_SLOTS.has(item_name):
		unequip_clothing(item_name)
	if item_type == "tool_torch":
		set_meta("last_torch_durability", float(item.durability))
		set_meta("last_torch_lit", torch_light != null and torch_light.visible)
		if torch_light != null:
			torch_light.visible = false
	var drop_qty := 1
	var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
	drop_pos.y = global_position.y
	var drop_color := get_current_clothing_color(item_name)
	item_dropped.emit(item_name, item_type, float(item.weight), drop_qty, float(item.use_value), drop_pos, drop_color)
	inventory.remove_index(index, drop_qty)
	if held_index >= inventory.items.size():
		held_index = max(0, inventory.items.size() - 1)
	_sync_held_item()
	notice.emit("Sueltas %s." % item_name)

#endregion


#region ITEMS EN MANO Y EQUIPAMIENTO (PlayerHeldItems)
func _sync_held_item() -> void:
	if inventory == null or inventory.items.is_empty():
		_sync_third_person_equipment(null)
		_update_crosshair(false)
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	var held_item = inventory.items[held_index]
	_sync_third_person_equipment(held_item)
	_update_crosshair(_has_rifle_equipped())

func _sync_third_person_equipment(held_item) -> void:
	_rifle_in_hands = held_item != null and str(held_item.item_type) == "weapon_rifle"
	# Hide torch character when not holding a torch
	_torch_in_hands = held_item != null and str(held_item.item_type) == "tool_torch"
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
	if hands == null or not hands.has_item_in_hands():
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
		# Clean up IK when clearing held items
		_clear_rifle_attachment()
	var equip_has_bp: bool = equipment != null and equipment.has_equipped("backpack")
	if not equip_has_bp:
		for child in third_person_back_item_root.get_children():
			third_person_back_item_root.remove_child(child)
			child.free()
	var eq_bp_set: bool = equipped_backpack == "Mochila pequena"
	if inventory != null and not equip_has_bp and eq_bp_set:
		_build_third_person_backpack()
	# Rifle on back: check if rifle is in inventory but not held in hands
	var _has_rifle_in_inventory := false
	if inventory != null and not inventory.items.is_empty():
		for item in inventory.items:
			if item != null and str(item.item_type) == "weapon_rifle":
				_has_rifle_in_inventory = true
				break
	if _has_rifle_in_inventory and not _rifle_in_hands:
		_build_rifle_on_back()
	else:
		_clear_rifle_on_back()
	if hands != null and hands.has_item_in_hands():
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			_build_third_person_rifle()
			return
	if held_item == null or held_item.item_type == "backpack":
		return
	if flashlight.visible and inventory.has_item_type("tool"):
		_build_third_person_flashlight()
		return
	match held_item.item_type:
		"weapon":
			_build_third_person_knife()
			_clear_rifle_attachment()
		"weapon_rifle":
			_build_third_person_rifle()
			if _rifle_magazine == 0 and _rifle_reserve_ammo == 0:
				_rifle_magazine = RIFLE_MAG_SIZE
				_rifle_reserve_ammo = RIFLE_MAG_SIZE * 3
		"tool":
			_build_third_person_flashlight()
			_clear_rifle_attachment()
		"food":
			var fname := str(held_item.item_name)
			if fname.find("ensartada") >= 0 or fname.find("asada") >= 0:
				_build_third_person_can()
			else:
				_build_third_person_pack()
			_clear_rifle_attachment()
		"water":
			var wname := str(held_item.item_name)
			if wname == "Botella de agua":
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
		"resource":
			_build_third_person_resource(str(held_item.item_name))
			_clear_rifle_attachment()
		"seed":
			_build_third_person_seed_bag()
			_clear_rifle_attachment()
		"clothing":
			_build_third_person_clothing_bundle()
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
		"tool_axe":
			_build_third_person_axe()
			_clear_rifle_attachment()
		"tool_hoe":
			_build_third_person_tool(REAL_HOE_MODEL, "ThirdPersonHoe", Color(0.20, 0.14, 0.08))
			_clear_rifle_attachment()
		"tool_shovel":
			_build_third_person_tool(REAL_SHOVEL_MODEL, "ThirdPersonShovel", Color(0.18, 0.16, 0.12))
			_clear_rifle_attachment()
		"tool_hammer":
			_build_third_person_tool(REAL_HAMMER_MODEL, "ThirdPersonHammer", Color(0.20, 0.15, 0.09))
			_clear_rifle_attachment()
		"tool_pickaxe":
			_build_third_person_tool(REAL_PICKAXE_MODEL, "ThirdPersonPickaxe", Color(0.18, 0.15, 0.10))
			_clear_rifle_attachment()
		_:
			_build_third_person_pack()
			_clear_rifle_attachment()

func _build_third_person_backpack() -> void:
	var bp_node := _load_external_node3d(REAL_BACKPACK_MODEL)
	if bp_node == null:
		return
	var raw_aabb := _hierarchy_local_aabb(bp_node)
	if raw_aabb.size.y <= 0.0001 or raw_aabb.size.x <= 0.0001 or raw_aabb.size.z <= 0.0001:
		bp_node.queue_free()
		return
	bp_node.name = "BackpackAsset"
	var bp_scale := 1.3 / raw_aabb.size.y
	bp_node.scale = Vector3.ONE * bp_scale
	var center_offset := Vector3(
		-(raw_aabb.position.x + raw_aabb.size.x * 0.5) * bp_scale,
		-(raw_aabb.position.y + raw_aabb.size.y * 0.5) * bp_scale,
		-(raw_aabb.position.z + raw_aabb.size.z * 0.5) * bp_scale
	)
	bp_node.position = center_offset
	bp_node.rotation_degrees = Vector3(0, 180, 0)
	third_person_back_item_root.add_child(bp_node)

func _build_third_person_knife() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, REAL_KNIFE_MODEL, "ThirdPersonKnife", Vector3(0.0, 0.09, 0.02), Vector3(0, 90, 0), Vector3.ONE * 0.8)

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

func _build_rifle_on_back() -> void:
	_clear_rifle_on_back()
	if third_person_back_item_root == null or not is_instance_valid(third_person_back_item_root):
		return
	var skeleton := _spine_skeleton if _spine_skeleton != null else _find_skeleton(third_person_model)
	if skeleton == null or not is_instance_valid(skeleton):
		return
	var model := _load_external_node3d(REAL_RIFLE_MODEL)
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
	# Scale: target ~1.8m length on the back
	var model_length: float = max(raw_aabb.size.x, max(raw_aabb.size.y, raw_aabb.size.z))
	var back_scale: float = 1.8 / model_length
	model.scale = Vector3.ONE * back_scale
	# Center the model on its midpoint
	var center_offset := Vector3(
		-(raw_aabb.position.x + raw_aabb.size.x * 0.5) * back_scale,
		-(raw_aabb.position.y + raw_aabb.size.y * 0.5) * back_scale,
		-(raw_aabb.position.z + raw_aabb.size.z * 0.5) * back_scale
	)
	model.position = center_offset
	# Rotate: barrel up (+Y), stock down (-Y). Model barrel points -Z.
	model.rotation_degrees = Vector3(90.0, 0.0, -15.0)
	model.visible = true
	_rifle_on_back.add_child(model)
	_disable_collision_recursive(model)
	_rifle_on_back.position = Vector3(0.12, 0.05, -0.25)
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

func _build_third_person_rifle() -> void:
	if third_person_hand_item_root == null or not is_instance_valid(third_person_hand_item_root):
		return
	_clear_rifle_attachment()
	var model := _load_external_node3d(REAL_RIFLE_MODEL)
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
	model.rotation = Vector3.ZERO
	var skel_scale := skeleton.global_transform.basis.get_scale().x
	var effective_scale := weapon_scale * skel_scale
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
	_traverse_mesh_aabb(model, Transform3D.IDENTITY, aabb_state)
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
	_rifle_right_grip.position = Vector3(0.5000, -0.5000, 1.2000)
	_rifle_right_grip.rotation_degrees = Vector3(0.0, 0.0, 0.0)
	_rifle_root.add_child(_rifle_right_grip)
	# LeftHandGripTarget: guardamanos, delante del grip, lado izquierdo del rifle
	_rifle_left_hand_grip = Marker3D.new()
	_rifle_left_hand_grip.name = "LeftHandGripTarget"
	_rifle_left_hand_grip.position = Vector3(-1.5, -0.5, -3.8)
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
	var weapon_basis_init := rot_basis_init.scaled(Vector3.ONE * weapon_scale * skel_scale_wo)
	_rifle_weapon_offset.global_basis = weapon_basis_init
	# Offset so RightGrip sits on the right hand bone
	_rifle_weapon_offset.global_position = rh_world_init + _rifle_weapon_offset.global_basis * (weapon_offset_pos - _rifle_right_grip.position)
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

	var skel_scale_wo := skel.global_transform.basis.get_scale().x
	var s := weapon_scale * skel_scale_wo
	var rh_pos := (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var lh_pos := (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	var shoulder_pos := (skel.global_transform * skel.get_bone_global_pose(sh_idx)).origin

	# Raw shoulder aim: right shoulder muscle pad
	var char_basis := global_basis.orthonormalized()
	var raw_shoulder := shoulder_pos + char_basis.x * 0.06 + char_basis.z * 0.02 - char_basis.y * 0.08

	var rg_local := _rifle_right_grip.position
	var lg_local := _rifle_left_hand_grip.position
	var stock_local := _rifle_stock_ref.position

	var v_world_dir := (lh_pos - rh_pos).normalized()
	var v_local_dir := (lg_local - rg_local).normalized()
	if v_world_dir.length_squared() < 0.0001 or v_local_dir.length_squared() < 0.0001:
		return

	# Move the left hand marker along the handguard so its world distance matches the animated left hand
	var target_len := (lh_pos - rh_pos).length() / s
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

	# Build the world transform for WeaponOffset
	var weapon_basis := r.scaled(Vector3.ONE * s)
	_rifle_root.position = Vector3.ZERO
	# Apply -15° pitch when aiming (local rotation around the right grip pivot).
	if _is_aiming:
		weapon_basis = weapon_basis * Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(-15.0))
	_rifle_weapon_offset.global_basis = weapon_basis
	_rifle_weapon_offset.global_position = rh_pos - weapon_basis * rg_local
	_rifle_weapon_offset.force_update_transform()

	# Shift the whole rifle along the real barrel line (from muzzle toward stock)
	# without changing rotation or scale. Direction is taken from the actual Muzzle/Stock markers.
	# Skip when sitting or prone to avoid the rifle sinking into the ground.
	if not is_sitting and not is_prone and _rifle_muzzle != null and is_instance_valid(_rifle_muzzle) and _rifle_stock_ref != null and is_instance_valid(_rifle_stock_ref):
		var barrel_dir := (_rifle_muzzle.global_position - _rifle_stock_ref.global_position).normalized()
		_rifle_root.global_position += barrel_dir * 0.40

	# Raise the rifle slightly when aiming so the left hand reaches the handguard
	if _is_aiming:
		_rifle_root.global_position += Vector3.UP * 0.05

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

	# Store references for the skeleton_updated callback
	_ik_skel = skel
	_ik_lh_idx = lh_idx
	var ua_bone_name := _resolve_bone_name_cached("ua", "mixamorig:LeftArm", skel)
	var fa_bone_name := _resolve_bone_name_cached("fa", "mixamorig:LeftForeArm", skel)
	if not ua_bone_name.is_empty():
		_ik_upper_arm_idx = _find_bone_cached("ua_idx", ua_bone_name, skel)
	if not fa_bone_name.is_empty():
		_ik_forearm_idx = _find_bone_cached("fa_idx", fa_bone_name, skel)
	if not _ik_skeleton_connected and skel != null:
		skel.skeleton_updated.connect(_on_skeleton_updated)
		_ik_skeleton_connected = true

func _on_skeleton_updated() -> void:
	if not _is_aiming:
		return
	if _ik_skel == null or not is_instance_valid(_ik_skel):
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
	# Set hand at target with grip marker rotation
	skel.set_bone_global_pose(_ik_lh_idx, grip_in_skel)

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
	_rifle_weapon_offset = null
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

# Linterna: no se muestra en tercera persona (efecto de luz es suficiente)
func _build_third_person_flashlight() -> void:
	return

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
	_try_add_model_to_parent(third_person_hand_item_root, REAL_PLASTIC_BOTTLE_MODEL, "ThirdPersonPlasticBottle", Vector3(0, 0, -0.12), Vector3(180, 0, 0), Vector3.ONE * 0.015)

func _build_third_person_drink_bottle() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, REAL_PLASTIC_BOTTLE_MODEL, "ThirdPersonDrinkBottle", Vector3(0, 0, -0.12), Vector3(180, 0, 0), Vector3.ONE * 0.5)

# Vendaje: sin modelo 3P (no es necesario, el efecto es instantáneo)
func _build_third_person_bandage() -> void:
	return

# Batería: sin modelo 3P
func _build_third_person_battery() -> void:
	return

func _build_third_person_resource(item_name: String) -> void:
	if item_name == "Tronco" or item_name == "Madera" or item_name == "Ramas":
		_try_add_model_to_parent(third_person_hand_item_root, REAL_WOOD_MODEL, "ThirdPersonWood", Vector3(0, 0, -0.18), Vector3(82, 0, 8), Vector3.ONE * 0.5)
	elif item_name == "Piedra":
		_try_add_model_to_parent(third_person_hand_item_root, REAL_STONE_MODEL, "ThirdPersonStone", Vector3(0, 0, -0.12), Vector3(8, 18, 6), Vector3.ONE * 0.5)

# Semillas: sin modelo 3P diferenciado, usa pack genérico
func _build_third_person_seed_bag() -> void:
	_build_third_person_pack()

# Bundle de ropa: sin modelo 3P diferenciado, usa pack genérico
func _build_third_person_clothing_bundle() -> void:
	_build_third_person_pack()

func _build_third_person_tool(path: String, node_name: String, _fallback_color: Color) -> void:
	_try_add_model_to_parent(third_person_hand_item_root, path, node_name, Vector3(0.0, -0.02, -0.11), Vector3(82, 0, 18), Vector3.ONE * 0.44)

func _build_third_person_axe() -> void:
	var node := _load_external_node3d(REAL_AXE_MODEL)
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

func _try_add_model_to_parent(parent: Node, path: String, node_name: String, pos: Vector3, rot: Vector3, scale_value: Vector3) -> bool:
	if parent == null:
		return false
	var node := _load_external_node3d(path)
	if node == null:
		return false
	node.name = node_name
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
	var target_sink := -0.6 * _water_depth if is_in_water else 0.0
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
		if not is_moving:
			breath_sway_x = sin(_breath_timer * 0.8) * 0.02 * fatigue_mult
			breath_sway_y = sin(_breath_timer * 1.2) * 0.015 * fatigue_mult
			if _breath_hold_active:
				var hf: float = 1.0 - clamp(_breath_hold_timer / 5.0, 0.0, 1.0)
				breath_sway_x *= 0.1 * hf
				breath_sway_y *= 0.1 * hf
		else:
			# Weapon sway when moving while aiming: more intense bob
			var move_sway: float = 0.02 * _walk_intensity
			breath_sway_x = sin(_walk_bob * 0.5) * move_sway
			breath_sway_y = abs(sin(_walk_bob)) * move_sway * 0.7
			if not is_on_floor():
				breath_sway_x *= 2.0
				breath_sway_y *= 2.0
		# Position the camera at the player's eye level, slightly forward
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
	_update_third_person_animation(moving, delta)

#endregion


#region ANIMACIÓN TERCERA PERSONA (PlayerAnimation)
func _update_third_person_animation(moving: bool, delta: float) -> void:
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	var base_rotation := Vector3(0.0, 180.0, 0.0) if character == third_person_model else Vector3.ZERO
	var bob: float = abs(sin(_walk_bob)) * 0.08 * _walk_intensity if moving else 0.0
	var sway: float = sin(_walk_bob) * 4.5 * _walk_intensity if moving else 0.0
	var crouch_lift := 0.0
	var sit_drop := 0.0
	var target_y := third_person_ground_offset + bob + crouch_lift + sit_drop + _water_sink
	if third_person_model != null:
		# Cache del skeleton para evitar búsqueda recursiva cada frame
		if _anim_skel_dirty or _anim_skel_cache == null or not is_instance_valid(_anim_skel_cache):
			_anim_skel_cache = _find_skeleton(third_person_model)
			_anim_skel_dirty = false
		var skel := _anim_skel_cache
		if skel != null:
			# Solo forzar update de bones cuando cambia la animación o hay cambio de postura
			var cur_anim: String = third_person_animation_player.current_animation if third_person_animation_player != null else ""
			if _bone_update_pending or cur_anim != _prev_anim_name:
				skel.force_update_all_bone_transforms()
				_prev_anim_name = cur_anim
				_bone_update_pending = false
			if is_prone and third_person_action_timer <= 0.0 and not is_crouching:
				# Align by hip/pelvis bone — feet are off ground when sitting
				var hip_model_y := 0.0
				var found_hip := false
				for i in range(skel.get_bone_count()):
					var bn := skel.get_bone_name(i)
					if bn.find("Hips") >= 0 or bn.find("Pelvis") >= 0 or bn.find("Spine") >= 0:
						var bone_world := skel.global_transform * skel.get_bone_global_pose(i).origin
						var bone_model := third_person_model.to_local(bone_world)
						hip_model_y = bone_model.y
						found_hip = true
						break
				if found_hip:
					# Target hip height above ground: sitting ~0.6, prone ~0.2
					var has_rifle := _has_rifle_equipped()
					var target_hip_ground_y := (0.85 if has_rifle else 0.25) if is_sitting else (0.2 if has_rifle else 0.15)
					target_y = target_hip_ground_y - hip_model_y
			else:
				# Standing, crouching, walking, or transitions: align by feet
				var min_foot_model_y := 1000000.0
				for i in range(skel.get_bone_count()):
					var bn := skel.get_bone_name(i)
					if bn.find("Foot") >= 0 or bn.find("Toe") >= 0:
						var bone_world := skel.global_transform * skel.get_bone_global_pose(i).origin
						var bone_model := third_person_model.to_local(bone_world)
						if bone_model.y < min_foot_model_y:
							min_foot_model_y = bone_model.y
				if min_foot_model_y < 999999.0:
					# Target: feet at ground level (capsule bottom = 0.025), sink in water
					target_y = 0.025 - min_foot_model_y + _water_sink
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
		if third_person_action_timer > 0.0 and not third_person_action_animation.is_empty():
			third_person_action_timer = max(0.0, third_person_action_timer - delta)
			if third_person_animation_player.current_animation != third_person_action_animation:
				third_person_animation_player.play(third_person_action_animation, 0.08)
			third_person_animation_player.speed_scale = 1.0
			return
		elif third_person_action_timer <= 0.0:
			third_person_action_animation = ""
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
	var animation := third_person_animation_player.get_animation(animation_name)
	if animation == null:
		return
	if animation.loop_mode != Animation.LOOP_NONE:
		return
	var length := animation.length
	if length > 0.0 and third_person_animation_player.current_animation_position >= length - 0.05:
		third_person_animation_player.play(animation_name, 0.25)

func _get_current_anim() -> String:
	if is_dead:
		return "dead"
	if third_person_animation_player != null:
		return third_person_animation_player.current_animation
	return "idle"

func _interact() -> void:
	var target = _get_interaction_target()
	if target == null:
		notice.emit("No hay nada al alcance.")
		return
	if camera != null:
		var tw := create_tween()
		tw.tween_property(camera, "fov", 72.0, 0.12).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(camera, "fov", 75.0, 0.18).set_ease(Tween.EASE_IN_OUT)
	target.interact(self)

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

#endregion


#region INTERACCIÓN Y UI
func _update_interaction_prompt() -> void:
	if is_sleeping:
		prompt_changed.emit("")
		return
	var target = _get_interaction_target()
	if target != null:
		if raycast != null and raycast.has_method("get_default_text"):
			prompt_changed.emit(raycast.get_default_text(target, self))
		elif target.has_method("get_interaction_text"):
			prompt_changed.emit(target.call("get_interaction_text", self))
		else:
			prompt_changed.emit("Pulsa E para interactuar")
		return
	prompt_changed.emit("")

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
			held.set_meta("torch_lit", true)
			notice.emit("Antorcha encendida frotando palos.")
			return
		inventory.consume_item_name("Cerillas", 1)
		inventory.changed.emit()
		torch_light.visible = true
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

func _build_third_person_torch() -> void:
	# Place torch_stick.glb in the torch hand root (follows left hand bone via _update_torch_hand_socket)
	if _torch_hand_root == null or not is_instance_valid(_torch_hand_root):
		return

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

	# Torch animations from Mixamo handle the arm pose; no manual bone override needed.
	if torch_light != null:
		var has_lit_meta = held != null and held.has_meta("torch_lit")
		var lit_value = false
		if has_lit_meta:
			lit_value = bool(held.get_meta("torch_lit", false))
		if held != null and str(held.item_type) == "tool_torch" and not held.is_broken() and lit_value:
			torch_light.visible = true
		else:
			torch_light.visible = false

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
		torch_light.light_energy = 1.0 + 4.0 * pct
		torch_light.light_color = Color(1.0, 0.6 + 0.3 * pct, 0.2 + 0.2 * pct)
		stats.body_temperature = min(37.5, stats.body_temperature + delta * 1.5 * pct)
		if wetness > 0.0:
			wetness = max(0.0, wetness - delta * 0.03 * pct)
			stats.wetness = wetness
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
func take_damage(amount: float, from_knife: bool = false) -> void:
	if is_puppet:
		# Puppet: send damage to server via RPC
		var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
		if net_node != null:
			var peer_id: int = get_meta("peer_id", 0)
			if peer_id != 0:
				net_node.damage_player.rpc_id(1, peer_id, amount)
		_spawn_blood_splatter()
		return
	apply_damage(amount)

func apply_damage(amount: float) -> void:
	return # INVULNERABLE: no attack damage
	if is_dead:
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
	stats.health = max(1.0, stats.health - amount)
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
	# Play attack animation
	if not third_person_attack_animation.is_empty() and third_person_animation_player != null:
		var atk_anim := third_person_animation_player.get_animation(third_person_attack_animation)
		if atk_anim != null:
			atk_anim.loop_mode = Animation.LOOP_NONE
		third_person_action_animation = third_person_attack_animation
		third_person_action_timer = 0.8
		third_person_animation_player.play(third_person_attack_animation, 0.08)
	# Determine damage and energy cost based on held item
	var held = null
	if inventory != null and not inventory.items.is_empty():
		held = inventory.items[held_index]
	var base_damage := 5.0  # bare fists
	var energy_cost := 8.0
	var attack_range := 3.0
	var is_knife := false
	if held != null:
		match held.item_type:
			"weapon":
				base_damage = 25.0
				energy_cost = 4.0
				is_knife = true
			"tool_axe":
				base_damage = 35.0
				energy_cost = 10.0
				attack_range = 3.5
			"tool":
				if held.item_name == "Hacha":
					base_damage = 35.0
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
	# Damage the closest target (wildlife or player) in range
	var closest_target: Node3D = null
	var closest_dist := attack_range
	var closest_dist_sq := attack_range * attack_range  # Opt: comparar con sq para evitar sqrt
	var fwd := -global_transform.basis.z.normalized()
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
		var dir := (animal.global_position - global_position).normalized()
		if fwd.dot(dir) < 0.3:
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
							scene_node._broadcast_player_death(peer_id, closest_target)
					var net_node2 := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
					if net_node2 != null and net_node2.peer != null and net_node2.peer.get_peer(peer_id) != null:
						net_node2.force_death_to_client.rpc_id(peer_id)
				else:
					# Send damage to the client if connected
					var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
					if net_node != null and net_node.peer != null and net_node.peer.get_peer(peer_id) != null:
						net_node.apply_damage_to_client.rpc_id(peer_id, base_damage)
		elif closest_target.has_method("apply_damage"):
			closest_target.apply_damage(base_damage)
		if held != null and held.has_method("reduce_durability"):
			held.reduce_durability(5.0)
			if held.is_broken():
				notice.emit("%s se ha roto!" % str(held.item_name))

func _has_rifle_equipped() -> bool:
	if not _rifle_in_hands:
		return false
	if inventory == null or inventory.items.is_empty():
		return false
	var held = inventory.items[held_index]
	if held == null:
		return false
	return held.item_type == "weapon_rifle"

func _update_crosshair(is_rifle: bool) -> void:
	if is_puppet:
		return
	var main := get_tree().current_scene
	if main != null and main.hud != null and main.hud.has_method("set_crosshair_rifle"):
		main.hud.set_crosshair_rifle(is_rifle)

func _toggle_aim() -> void:
	_is_aiming = not _is_aiming
	if _is_aiming:
		_create_scope_overlay()
		if camera != null:
			camera.fov = 25.0
		mouse_sensitivity = 0.0008
		if third_person_model != null:
			third_person_model.visible = false
		_breath_hold_active = false
		_breath_hold_timer = 0.0
		_breath_hold_recover = 0.0
	else:
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
	get_tree().current_scene.add_child(_scope_overlay)

func _remove_scope_overlay() -> void:
	if _scope_overlay != null and is_instance_valid(_scope_overlay):
		_scope_overlay.queue_free()
	_scope_overlay = null

func _reload_rifle() -> void:
	if _is_reloading:
		return
	var needed := RIFLE_MAG_SIZE - _rifle_magazine
	if needed <= 0:
		notice.emit("Cargador lleno.")
		return
	if _rifle_reserve_ammo <= 0:
		notice.emit("Sin municion de reserva.")
		return
	_is_reloading = true
	var to_load: int = min(needed, _rifle_reserve_ammo)
	_rifle_reserve_ammo -= to_load
	_rifle_magazine += to_load
	_is_reloading = false
	notice.emit("Recargado: %d/%d en cargador, %d en reserva." % [_rifle_magazine, RIFLE_MAG_SIZE, _rifle_reserve_ammo])

func get_rifle_info() -> Dictionary:
	return {
		"name": RIFLE_NAME,
		"ammo_type": RIFLE_AMMO_TYPE,
		"magazine": _rifle_magazine,
		"mag_size": RIFLE_MAG_SIZE,
		"reserve": _rifle_reserve_ammo,
		"damage": RIFLE_DAMAGE,
		"range": RIFLE_RANGE,
	}

func get_wind_info() -> Dictionary:
	return {
		"strength": _wind_strength,
		"direction": _wind_dir,
		"target_strength": _wind_target_strength,
	}

func _shoot_rifle() -> void:
	if _shoot_cooldown > 0.0:
		return
	if _rifle_magazine <= 0:
		notice.emit("Sin municion. Pulsa T para recargar.")
		return
	if stats.energy < 3.0:
		notice.emit("Estas demasiado cansado para disparar.")
		return
	_rifle_magazine -= 1
	_shoot_cooldown = 1.5
	stats.energy = max(0.0, stats.energy - 3.0)
	stats.changed.emit()
	_is_firing = true
	# Notify nearby wildlife of gunshot — wolves flee, prey scatters
	var gunshot_pos := global_position
	for w in get_tree().get_nodes_in_group("wildlife"):
		if w == null or not is_instance_valid(w):
			continue
		if w.has_method("flee_from_gunshot"):
			w.flee_from_gunshot(gunshot_pos, 80.0)
		elif w.has_method("attract_to_noise"):
			w.attract_to_noise(gunshot_pos, 80.0)
	# Recoil: strong kick camera up, less when prone/crouching/aiming
	var recoil_kick := 8.0
	if is_prone:
		recoil_kick = 3.0
	elif is_crouching:
		recoil_kick = 5.0
	if _is_aiming:
		recoil_kick *= 0.7
	_recoil_pitch -= deg_to_rad(recoil_kick)
	_recoil_yaw += deg_to_rad(randf_range(-recoil_kick * 0.4, recoil_kick * 0.4))
	if camera != null:
		camera.rotation.x = _pitch + _recoil_pitch + _breath_pitch_offset
		camera.rotation.y = _recoil_yaw + _breath_yaw_offset
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
	notice.emit("Bang!")
	_play_shoot_sound()
	var vp := camera.get_viewport()
	var aim_point := vp.get_visible_rect().size * 0.5 + _aim_screen_offset
	var cam_ray_origin := camera.project_ray_origin(aim_point)
	var cam_ray_dir := camera.project_ray_normal(aim_point)
	var space_state := get_world_3d().direct_space_state
	# Usar RIDs cacheados para evitar recorrer el árbol en cada disparo
	if _cached_rids_dirty:
		_cached_exclude_rids = [self.get_rid()]
		_collect_child_collision_rids(self, _cached_exclude_rids)
		_cached_rids_dirty = false
	var exclude_arr: Array[RID] = _cached_exclude_rids
	# In third-person, the camera is behind/above the player. Cast a ray from
	# the camera through the crosshair to find the intended target point, then
	# fire the actual damage ray from the player's weapon position toward that
	# point so nearby ground-level enemies are hit correctly.
	var cam_query := PhysicsRayQueryParameters3D.create(cam_ray_origin, cam_ray_origin + cam_ray_dir * RIFLE_RANGE)
	cam_query.exclude = exclude_arr
	cam_query.collide_with_areas = true
	cam_query.collide_with_bodies = true
	var cam_result := space_state.intersect_ray(cam_query)
	var target_point: Vector3 = cam_ray_origin + cam_ray_dir * RIFLE_RANGE
	var cam_hit_collider = null
	if not cam_result.is_empty():
		target_point = cam_result["position"]
		cam_hit_collider = cam_result["collider"]
	# Sync rifle shot with other clients
	if not is_puppet:
		var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
		if net_node != null and net_node.is_connected:
			var my_id: int = net_node.get_my_id()
			net_node.player_shot_rifle.rpc_id(1, my_id, cam_ray_origin, cam_ray_dir)
	# If camera ray hit a hitbox directly, use that result for damage (avoids parallax miss)
	if cam_hit_collider != null and cam_hit_collider is Node3D:
		var cam_node: Node3D = cam_hit_collider as Node3D
		if cam_node.name == "BodyHitbox" or cam_node.name == "HeadHitbox":
			var direct_hit_pos: Vector3 = cam_result["position"]
			var direct_hit_dist: float = cam_ray_origin.distance_to(direct_hit_pos)
			_apply_rifle_damage(cam_hit_collider, direct_hit_pos, direct_hit_dist)
			return
	# Weapon origin: player position at chest/shoulder height
	var weapon_origin: Vector3 = global_position + Vector3(0.0, 1.4, 0.0)
	if is_crouching:
		weapon_origin = global_position + Vector3(0.0, 1.0, 0.0)
	elif is_prone:
		weapon_origin = global_position + Vector3(0.0, 0.3, 0.0)
	var ray_dir: Vector3 = (target_point - weapon_origin).normalized()
	var ray_origin: Vector3 = weapon_origin
	# Realistic spread: wider when moving, narrower when crouching/aiming
	var spread_deg := 2.0
	if is_crouching:
		spread_deg = 0.5
	if is_prone:
		spread_deg = 0.3
	if _is_aiming:
		spread_deg *= 0.3
	if is_moving:
		spread_deg *= 2.5
	if not is_on_floor():
		spread_deg *= 4.0
	spread_deg = min(spread_deg, 12.0)
	if spread_deg > 0.01:
		var spread_rad := deg_to_rad(spread_deg)
		ray_dir = ray_dir.rotated(Vector3.UP, randf_range(-spread_rad, spread_rad))
		var right := ray_dir.cross(Vector3.UP).normalized()
		ray_dir = ray_dir.rotated(right, randf_range(-spread_rad, spread_rad))
		ray_dir = ray_dir.normalized()
	# Breath sway: small vertical oscillation when aiming and still
	if _is_aiming and not is_moving:
		var breath_deg := 0.15 * sin(_breath_timer * 1.2)
		if is_prone:
			breath_deg *= 0.3
		elif is_crouching:
			breath_deg *= 0.5
		var right2 := ray_dir.cross(Vector3.UP).normalized()
		ray_dir = ray_dir.rotated(right2, deg_to_rad(breath_deg))
		ray_dir = ray_dir.normalized()
	# Bullet drop: apply gravity over the trajectory
	var hit_dist := RIFLE_RANGE
	# First ray to find hit distance
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * RIFLE_RANGE)
	query.exclude = exclude_arr
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	var hit_pos: Vector3 = ray_origin + ray_dir * RIFLE_RANGE
	if not result.is_empty():
		hit_dist = ray_origin.distance_to(result["position"])
		hit_pos = result["position"]
	# Apply bullet drop: gravity-based drop over trajectory (realistic for 7.62mm)
	var bullet_drop := 0.5 * 9.8 * (hit_dist / 180.0) * (hit_dist / 180.0)
	# Wind deflection: lateral push proportional to distance and wind strength
	# Stronger effect: 3.5 m/s wind can deflect ~1m at 100m
	var wind_deflect := _wind_strength * (hit_dist / 100.0) * 1.2
	var wind_offset := _wind_dir * wind_deflect
	# Re-cast with adjusted target if distance is significant
	if hit_dist > 5.0 and (bullet_drop > 0.02 or wind_deflect > 0.02):
		var adjusted_target := ray_origin + ray_dir * hit_dist + Vector3(0, -bullet_drop, 0) + wind_offset
		var drop_query := PhysicsRayQueryParameters3D.create(ray_origin, adjusted_target)
		drop_query.exclude = exclude_arr
		drop_query.collide_with_areas = true
		drop_query.collide_with_bodies = true
		var drop_result := space_state.intersect_ray(drop_query)
		if not drop_result.is_empty():
			result = drop_result
			hit_pos = drop_result["position"]
			hit_dist = ray_origin.distance_to(hit_pos)
	# Sync rifle shot with other clients
	if not is_puppet:
		var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
		if net_node != null and net_node.is_connected:
			var my_id: int = net_node.get_my_id()
			net_node.player_shot_rifle.rpc_id(1, my_id, ray_origin, ray_dir)
	if result.is_empty():
		# Fallback: check for wildlife along the ray path (Area3D hitboxes may not be detected)
		var wl := _find_wildlife_along_ray(ray_origin, ray_dir, RIFLE_RANGE)
		if not wl.is_empty():
			_apply_rifle_damage(wl["node"], ray_origin + ray_dir * wl["dist"], wl["dist"])
		return
	# Check if the raycast hit a wildlife entity by walking up the tree
	var hit_collider = result["collider"]
	var hit_is_wildlife := false
	if hit_collider is Node3D:
		var walked: Node = hit_collider
		while walked != null:
			if walked == self:
				break
			if walked.has_method("take_damage") and walked.is_in_group("wildlife"):
				hit_is_wildlife = true
				break
			walked = walked.get_parent()
	if not hit_is_wildlife:
		# Fallback: check for wildlife along the full ray path (not just to hit point)
		# The raycast may hit ground/terrain before reaching a distant animal because
		# the weapon origin is lower than the camera, but the player is aiming at the animal.
		var wl := _find_wildlife_along_ray(ray_origin, ray_dir, RIFLE_RANGE)
		if not wl.is_empty():
			_apply_rifle_damage(wl["node"], ray_origin + ray_dir * wl["dist"], wl["dist"])
			return
	_apply_rifle_damage(hit_collider, hit_pos, hit_dist)

func _find_wildlife_along_ray(ray_origin: Vector3, ray_dir: Vector3, max_dist: float) -> Dictionary:
	var closest_wildlife: Node = null
	var closest_along: float = 0.0
	var closest_perp: float = INF
	# Use XZ-plane for perpendicular distance check since animals are at ground level (y=0)
	# but the ray originates from camera height (~1.7m)
	var ray_origin_xz := Vector2(ray_origin.x, ray_origin.z)
	var ray_dir_xz := Vector2(ray_dir.x, ray_dir.z).normalized()
	for w in get_tree().get_nodes_in_group("wildlife"):
		if w == null or not is_instance_valid(w):
			continue
		if w == self:
			continue
		if not w.has_method("take_damage"):
			continue
		if w.get("_is_dead") == true:
			continue
		var w_pos: Vector3 = w.global_position
		# Project onto XZ plane for along-ray and perpendicular distance
		var to_w_xz := Vector2(w_pos.x, w_pos.z) - ray_origin_xz
		var along_xz: float = to_w_xz.dot(ray_dir_xz)
		if along_xz < 0.0 or along_xz > max_dist:
			continue
		var closest_pt_xz := ray_origin_xz + ray_dir_xz * along_xz
		var perp_xz: float = Vector2(w_pos.x, w_pos.z).distance_to(closest_pt_xz)
		# 2.0m threshold on XZ plane to account for animal body width
		if perp_xz < 2.0 and perp_xz < closest_perp:
			closest_wildlife = w
			closest_along = along_xz
			closest_perp = perp_xz
	if closest_wildlife != null:
		return {"node": closest_wildlife, "dist": closest_along, "perp": closest_perp}
	return {}

func _apply_rifle_damage(collider, hit_pos: Vector3, hit_dist: float) -> void:
	# Damage: lethal at close range, falloff at long range
	# Base 200: close-range body shot (200*1.5=300) kills NPC (240hp)
	var damage := 200.0
	# Close range bonus: 1.5x within 15m, scaling down to 1.0 at 50m
	if hit_dist < 15.0:
		damage *= 1.5
	elif hit_dist < 50.0:
		damage *= lerp(1.5, 1.0, (hit_dist - 15.0) / 35.0)
	# Long range falloff: linear from 50m to 20% at max range
	if hit_dist > 50.0:
		var falloff: float = clamp(1.0 - (hit_dist - 50.0) / (RIFLE_RANGE - 50.0), 0.2, 1.0)
		damage *= falloff
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
				if parent.has_method("take_damage") and (parent.is_in_group("wildlife") or parent.is_in_group("npc") or parent.is_in_group("net_player_proxy")):
					target_node = parent
					break
				parent = parent.get_parent()
		elif node.name == "BodyHitbox":
			var parent: Node = node.get_parent()
			while parent != null:
				if parent == self:
					break
				if parent.has_method("take_damage") and (parent.is_in_group("wildlife") or parent.is_in_group("npc") or parent.is_in_group("net_player_proxy")):
					target_node = parent
					break
				parent = parent.get_parent()
		else:
			var walked: Node = node
			while walked != null:
				if walked == self:
					break
				if walked.has_method("take_damage") and (walked.is_in_group("wildlife") or walked.is_in_group("npc") or walked.is_in_group("net_player_proxy")):
					target_node = walked
					break
				walked = walked.get_parent()
		if target_node != null:
			if is_headshot:
				target_node.take_damage(9999.0, false)
			else:
				target_node.take_damage(damage, false)
			_spawn_blood_splatter(hit_pos)
			return
		# Handle net_player_proxy directly
		if node.is_in_group("net_player_proxy"):
			var peer_id: int = node.get_meta("peer_id", 0)
			var is_proxy_dead: bool = node.get_meta("proxy_dead", false)
			if not is_proxy_dead and peer_id != 0:
				var hp: float = node.get_meta("proxy_health", 100.0)
				hp = max(0.0, hp - damage)
				node.set_meta("proxy_health", hp)
				if hp <= 0.0:
					node.set_meta("proxy_dead", true)
					node.remove_from_group("net_player_proxy")
					var scene_node := get_tree().current_scene
					if scene_node != null:
						if scene_node.has_method("_drop_player_loot"):
							scene_node._drop_player_loot(peer_id, node)
						if scene_node.has_method("_broadcast_player_death") and not node.get_meta("death_broadcasted", false):
							node.set_meta("death_broadcasted", true)
							scene_node._broadcast_player_death(peer_id, node)
				else:
					var net_node := get_tree().current_scene.get_node_or_null("/root/NetworkManager")
					if net_node != null and net_node.peer != null and net_node.peer.has_peer(peer_id):
						net_node.apply_damage_to_client.rpc_id(peer_id, damage)
		elif node.has_method("apply_damage"):
			node.apply_damage(damage)
		_spawn_blood_splatter(hit_pos)

func _spawn_blood_splatter(at_pos: Vector3 = Vector3.ZERO) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "BloodSplatter"
	particles.amount = 60
	particles.lifetime = 1.2
	particles.explosiveness = 1.0
	particles.randomness = 1.0
	particles.one_shot = true
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 60.0
	mat.initial_velocity_min = 4.0
	mat.initial_velocity_max = 9.0
	mat.gravity = Vector3(0, -15.0, 0)
	mat.scale_min = 0.08
	mat.scale_max = 0.15
	mat.color = Color(0.6, 0.02, 0.02, 1.0)
	mat.hue_variation_min = -0.03
	mat.hue_variation_max = 0.03
	particles.process_material = mat
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	var blood_mat := StandardMaterial3D.new()
	blood_mat.albedo_color = Color(0.6, 0.02, 0.02)
	blood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blood_mat.no_depth_test = true
	sphere.material = blood_mat
	particles.draw_pass_1 = sphere
	get_tree().current_scene.add_child(particles)
	if at_pos != Vector3.ZERO:
		particles.global_position = at_pos
	else:
		particles.global_position = global_position + Vector3(0, 1.2, 0)
	particles.emitting = true
	get_tree().create_timer(2.5).timeout.connect(func(): particles.queue_free())

func _play_shoot_sound() -> void:
	if _shoot_audio_player == null:
		_shoot_audio_player = AudioStreamPlayer.new()
		_shoot_audio_player.name = "ShootSound"
		add_child(_shoot_audio_player)
	var path := "res://assets/audio/disparo.wav"
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			stream = AudioStreamWAV.load_from_file(disk_path)
	if stream == null:
		return
	_shoot_audio_player.stream = stream
	_shoot_audio_player.volume_db = 3.0
	_shoot_audio_player.pitch_scale = randf_range(0.95, 1.05)
	_shoot_audio_player.play()

func play_rifle_shot_remote(_origin: Vector3, _dir: Vector3) -> void:
	if is_puppet:
		if _puppet_held != "Rifle francotirador":
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
		third_person_animation_player.play(_rifle_fire_animation, 0.05)
	_play_shoot_sound()

func _play_pain_sound() -> void:
	if _pain_sound_timer > 0.0:
		return
	_pain_sound_timer = 1.5
	if _pain_audio_player == null:
		_pain_audio_player = AudioStreamPlayer.new()
		_pain_audio_player.name = "PainSound"
		add_child(_pain_audio_player)
	var paths := [
		"res://assets/external/audio/downloaded/pain1.wav",
		"res://assets/external/audio/downloaded/pain2.wav",
		"res://assets/external/audio/downloaded/pain3.wav"
	]
	var path: String = paths[randi() % paths.size()]
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path)
	if stream == null:
		var disk_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(disk_path):
			stream = AudioStreamWAV.load_from_file(disk_path)
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
		if item != null and (item.item_type == "weapon" or item.item_name == "Hacha"):
			return true
	return false

func _quick_use_held_item_impl() -> void:
	if inventory == null or inventory.items.is_empty():
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	var item = inventory.items[held_index]
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
	if inventory != null and not inventory.items.is_empty():
		held_index = clampi(held_index, 0, inventory.items.size() - 1)
		var item = inventory.items[held_index]
		if item != null and item.item_type == "food":
			_eat_held_item()
			return
	var target = _get_interaction_target()
	if target != null and target is WorldAction:
		if target.action_type == "eat_food" or target.action_type == "wolf_meat_raw":
			var main := get_tree().current_scene
			if main != null and main.has_method("handle_world_action_eat"):
				main.handle_world_action_eat(target, self)
			else:
				target.interact(self)

func _light_action() -> void:
	var target = _get_interaction_target()
	if target != null and target is WorldAction and target.action_type == "light_campfire":
		target.interact(self)

#endregion
