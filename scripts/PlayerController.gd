extends CharacterBody3D
class_name PlayerController

const SurvivalStatsScript = preload("res://scripts/SurvivalStats.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const ItemScript = preload("res://scripts/Item.gd")
const InteractionRaycastScript = preload("res://scripts/InteractionRaycast.gd")
const PlayerEquipmentScript = preload("res://scripts/PlayerEquipment.gd")
const PlayerHandsScript = preload("res://scripts/PlayerHands.gd")
const CraftingSystemScript = preload("res://scripts/CraftingSystem.gd")
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
const POLY_LIFE_JACKET_MODEL := "res://assets/external/polyhaven/life_jacket/life_jacket_1k.gltf"
const POLY_FISHERMANS_HAT_MODEL := "res://assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf"
const POLY_RUBBER_BOOTS_MODEL := "res://assets/external/polyhaven/rubber_boots/rubber_boots_1k.gltf"
const POLY_GARDEN_GLOVES_MODEL := "res://assets/external/polyhaven/garden_gloves_01/garden_gloves_01_1k.gltf"
# Wearable visuals placed on the body relative to its measured bounding box, so
# they fit regardless of the character model's scale/proportions.
#   frac_y: anchor height as a fraction of body height (0 = feet, 1 = head top)
#   size:   item height as a fraction of body height
#   forward: shift toward the front of the body (fraction of depth)
#   align:  "center" (default) or "bottom"; "strip" hides duplicate variant meshes
const CLOTHING_VISUALS := {
	"Chaleco salvavidas": {"path": POLY_LIFE_JACKET_MODEL, "frac_y": 0.70, "size": 0.30, "yaw": 180.0, "forward": 0.05},
	"Sombrero de pescador": {"path": POLY_FISHERMANS_HAT_MODEL, "frac_y": 0.96, "size": 0.12, "yaw": 0.0, "align": "bottom"},
	"Botas de goma": {"path": POLY_RUBBER_BOOTS_MODEL, "frac_y": 0.0, "size": 0.20, "yaw": 0.0, "align": "bottom", "strip": ["dirty", "dirt"]},
	"Guantes de trabajo": {"path": POLY_GARDEN_GLOVES_MODEL, "frac_y": 0.45, "size": 0.09, "yaw": 0.0, "forward": 0.2},
}
# Adapted character (Mixamo body + survival clothing skinned to the same rig).
# Loaded first so the deformable survival garments are available to wear.
const ADAPTED_PLAYER_MODEL := "res://assets/characters/adapted/player_with_clothes.glb"

const SOLDADO_MODEL := "res://assets/adapted/soldado_parts.glb"

# Survival garments that are skinned to the Mixamo rig inside ADAPTED_PLAYER_MODEL.
# item_name -> mesh node to show + Mixamo default meshes to hide while worn.
const SURVIVAL_CLOTHING := {
	"Chaqueta survival": {"mesh": "cloth_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": []},
	"Vaqueros survival": {"mesh": "cloth_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"]},
	"Guantes survival": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": []},
	"Botas survival": {"mesh": "cloth_feet", "hides": ["Shoes"], "skin_hides": ["Desnudo_feet"], "body_hides": ["Body_feet"]},
	"Chaqueta militar": {"mesh": "soldier_torso", "hides": ["Tops"], "skin_hides": ["Desnudo_torso", "Desnudo_arms"], "body_hides": []},
	"Pantalones militares": {"mesh": "soldier_legs", "hides": ["Bottoms"], "skin_hides": ["Desnudo_legs"], "body_hides": ["Body_legs"]},
	"Guantes militares": {"mesh": "cloth_hands", "hides": [], "skin_hides": ["Desnudo_hands"], "body_hides": []},
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
	"Pantalones": [],
	"Zapatillas": ["Desnudo_feet"],
	"Chaqueta survival": ["Desnudo_torso", "Desnudo_arms"],
	"Chaqueta militar": ["Desnudo_torso", "Desnudo_arms"],
	"Vaqueros survival": ["Desnudo_legs"],
	"Pantalones militares": ["Desnudo_legs"],
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
	"Chaqueta survival": ["torso", "brazos_superiores"],
	"Chaqueta militar": ["torso", "brazos_superiores"],
	"Vaqueros survival": ["cadera", "piernas"],
	"Pantalones militares": ["cadera", "piernas"],
	"Guantes survival": ["manos"],
	"Guantes militares": ["manos"],
	"Botas survival": ["pies"],
	"Chaqueta de abrigo": ["torso", "brazos_superiores"],
	"Chaleco salvavidas": ["torso"],
	"Botas de goma": ["pies"],
	"Guantes de trabajo": ["manos"],
	"Sombrero de pescador": ["cabeza"],
}

# Maps each clothing item to a body slot for exchange logic.
const CLOTHING_SLOTS := {
	"Camiseta": "torso",
	"Pantalones": "legs",
	"Zapatillas": "feet",
	"Chaqueta survival": "torso",
	"Vaqueros survival": "legs",
	"Guantes survival": "hands",
	"Botas survival": "feet",
	"Chaqueta militar": "torso",
	"Pantalones militares": "legs",
	"Guantes militares": "hands",
	"Chaqueta de abrigo": "torso",
	"Chaleco salvavidas": "torso",
	"Botas de goma": "feet",
	"Guantes de trabajo": "hands",
	"Sombrero de pescador": "head",
}

# Warmth value per clothing item. Higher = warmer.
# Short sleeves / shorts give little warmth; jackets and long pants give more.
const CLOTHING_WARMTH := {
	"Camiseta": 0.05,
	"Pantalones": 0.08,
	"Zapatillas": 0.05,
	"Chaqueta survival": 0.22,
	"Vaqueros survival": 0.16,
	"Guantes survival": 0.08,
	"Botas survival": 0.18,
	"Chaqueta militar": 0.28,
	"Pantalones militares": 0.20,
	"Guantes militares": 0.10,
	"Chaqueta de abrigo": 0.45,
	"Chaleco salvavidas": 0.06,
	"Botas de goma": 0.10,
	"Guantes de trabajo": 0.08,
	"Sombrero de pescador": 0.07,
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
const RIFLE_DAMAGE := 80.0
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
const THIRD_PERSON_CAMERA_POS := Vector3(0.0, 2.65, 5.15)
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
signal item_dropped(item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3)

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
var _camera_fov := 75.0
var audio_listener: AudioListener3D
var raycast
var flashlight: SpotLight3D
var body_mesh: MeshInstance3D
var _collision_shape: CollisionShape3D
var third_person_model: Node3D
var _full_body_mesh: MeshInstance3D = null
var _head_mesh: MeshInstance3D = null
var third_person_hand_item_root: Node3D
var third_person_back_item_root: Node3D
var _spine_skeleton: Skeleton3D = null
var _spine_bone_idx: int = -1
var _hand_skeleton: Skeleton3D = null
var _hand_bone_idx: int = -1
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
var _has_rifle := false
var _is_reloading := false
var _is_firing := false
var _rifle_magazine := 0
var _rifle_reserve_ammo := 0
var _rifle_bone_attachment: BoneAttachment3D = null
var _rifle_weapon_offset: Node3D = null
var _rifle_root: Node3D = null
var _rifle_model: Node3D = null
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
var _rifle_has_cache: bool = false
var _rifle_debug_spheres: Dictionary = {}
var _rifle_current_ik_weight := 1.0
var _rifle_target_ik_weight := 1.0
var _last_rifle_animation_debug := ""
var _auto_align_enabled := false
var _auto_align_iteration := 0
var _auto_align_rifleidle_timer := 0.0
var _auto_align_converged := false
var _auto_align_samples: Array = []
var _ik_calibration_enabled := false
var _ik_calibration_levels := [0.0, 0.1, 0.25, 0.5, 0.75, 1.0]
var _ik_calibration_idx := 0
var _ik_calibration_timer := 0.0
var _ik_calibration_stable_influence := 0.0
var _ik_calibration_log_timer := 0.0
var _manual_search_enabled := false
var _manual_search_axis := 0 # 0=X, 1=Z, 2=Y
var _manual_search_phase := 0 # 0=measure current, 1=try +step, 2=try -step, 3=decide
var _manual_search_timer := 0.0
var _manual_search_step := 2.0
var _manual_search_best_dist := 999.0
var _manual_search_best_pos := Vector3.ZERO
var _manual_search_current_dist := 0.0
var _manual_search_samples: Array = []
var _manual_search_converged := true
var _manual_search_round := 0
# Phase 1 measurement state (right hand only)
var _rh_grip_measure_timer := 0.0
var _rh_grip_measure_samples: Array = []
var _rh_grip_last_dist := 0.0
var _rh_grip_logged := false
# Controlled small-step alignment for RifleRoot local (right hand only)
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
@export var weapon_debug_visuals: bool = false
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
var _anim_debug_label: Label = null
var _anim_debug_enabled := false
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
	set_process(true)
	set_process_input(false)
	set_physics_process(false)

var _puppet_clothing := ""
var _puppet_held := ""
var _puppet_backpack := ""

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

func puppet_set_rifle(has_rifle: bool) -> void:
	if not is_puppet:
		return
	_has_rifle = has_rifle

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

func _process(delta: float) -> void:
	if is_puppet:
		_update_hand_socket()
		_update_backpack_socket()
		if is_dead:
			_update_death_pose(delta)
			if _puppet_naked_pending:
				_puppet_naked_timer += delta
				if _puppet_naked_timer >= 2.0:
					_puppet_naked_pending = false
					_puppet_swap_to_naked()
		return
	if _anim_debug_enabled:
		_update_anim_debug_label()
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
	# Debug camera overrides
	if camera != null and (_frontal_camera or _side_camera or _left_camera or _rear_camera):
		var char_forward := -global_basis.z.normalized()
		var char_right := global_basis.x.normalized()
		var char_up := global_basis.y.normalized()
		if _frontal_camera:
			camera.global_position = global_position + char_forward * 3.0 + char_up * 2.6
			camera.look_at(global_position + char_up * 1.3, char_up)
			camera.fov = 40.0
		elif _side_camera:
			camera.global_position = global_position + char_right * 4.0 + char_up * 1.6
			camera.look_at(global_position + char_up * 1.3, char_up)
			camera.fov = 40.0
		elif _left_camera:
			camera.global_position = global_position - char_right * 4.0 + char_up * 1.6
			camera.look_at(global_position + char_up * 1.3, char_up)
			camera.fov = 40.0
		elif _rear_camera:
			camera.global_position = global_position - char_forward * 3.0 + char_up * 2.6
			camera.look_at(global_position + char_up * 1.3, char_up)
			camera.fov = 40.0

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
			if has_rifle:
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
			camera.rotation.x = _pitch
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
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		_frontal_camera = not _frontal_camera
		_side_camera = false
		_left_camera = false
		_rear_camera = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		_side_camera = not _side_camera
		_frontal_camera = false
		_left_camera = false
		_rear_camera = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		_left_camera = not _left_camera
		_frontal_camera = false
		_side_camera = false
		_rear_camera = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_rear_camera = not _rear_camera
		_frontal_camera = false
		_side_camera = false
		_left_camera = false
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		_frontal_camera = false
		_side_camera = false
		_left_camera = false
		_rear_camera = false
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
		if event.keycode == KEY_F7:
			toggle_anim_debug()
			return
	if event.is_action_pressed("quick_use_1"):
		held_index = 0
		_use_inventory_index(0)
	if event.is_action_pressed("quick_use_2"):
		held_index = 1
		_use_inventory_index(1)
	if event.is_action_pressed("quick_use_3"):
		held_index = 2
		_use_inventory_index(2)
	if event.is_action_pressed("quick_use_4"):
		held_index = 3
		_use_inventory_index(3)
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
		KEY_1:
			return 0
		KEY_2:
			return 1
		KEY_3:
			return 2
		KEY_4:
			return 3
		KEY_5:
			return 4
		KEY_6:
			return 5
		KEY_7:
			return 6
		KEY_8:
			return 7
		KEY_9:
			return 8
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
		equip_clothing(item_name)
	elif not used:
		_sync_held_item()

func _on_inventory_changed() -> void:
	_recalculate_carry_capacity()
	_sync_held_item()

func equip_clothing(item_name: String) -> void:
	var slot := ""
	if CLOTHING_SLOTS.has(item_name):
		slot = CLOTHING_SLOTS[item_name]
	# Unequip previous item in the same slot and drop it on the ground
	if not slot.is_empty() and _equipped_slots.get(slot, "") != item_name:
		var prev_name := str(_equipped_slots.get(slot, ""))
		if not prev_name.is_empty() and prev_name != item_name:
			unequip_clothing(prev_name)
			# Remove old clothing from inventory and drop it on the ground
			if inventory != null:
				for i in range(inventory.items.size()):
					if str(inventory.items[i].item_name) == prev_name:
						inventory.remove_index(i)
						break
			var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
			drop_pos.y = global_position.y
			item_dropped.emit(prev_name, "clothing", 0.5, 1, 0.1, drop_pos)
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
	if all_equipped and not has_survival_skin_hide:
		if _full_body_mesh != null:
			_full_body_mesh.visible = true
			_full_body_mesh.material_override = null
		if _head_mesh != null:
			_head_mesh.visible = false
		for dn in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
			var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
			if dmi != null:
				dmi.visible = false
		for bn in ["Body_legs", "Body_feet"]:
			var bmi: MeshInstance3D = _find_mesh_in_third_person(bn)
			if bmi != null:
				bmi.visible = false
	else:
		if _full_body_mesh != null:
			_full_body_mesh.visible = false
			_full_body_mesh.material_override = null
		if _head_mesh != null:
			_head_mesh.visible = true
		for dn in ["Desnudo_arms", "Desnudo_hands", "Desnudo_torso", "Desnudo_legs", "Desnudo_feet"]:
			var dmi: MeshInstance3D = _find_mesh_in_third_person(dn)
			if dmi != null:
				dmi.visible = true
		# Hide Body_legs/Body_feet — they overlap with Desnudo_legs/feet
		for bn in ["Body_legs", "Body_feet"]:
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
	elif SURVIVAL_CLOTHING.has(item_name):
		_wear_survival_clothing(item_name, true)
	else:
		_wear_clothing_visual(item_name)
	if not slot.is_empty():
		_equipped_slots[slot] = item_name
	# Custom character: show the clothing mesh, hide Desnudo_* for covered zones
	if is_custom_character and not slot.is_empty():
		var cloth_mi := _find_custom_slot_mesh(slot)
		if cloth_mi != null:
			cloth_mi.visible = true
			print("[CLOTHING] Equipada: ", item_name, " | slot=", slot, " | mesh=", cloth_mi.name)
			if CLOTHING_COVERED_ZONES.has(item_name):
				print("[CLOTHING] Zonas cubiertas: ", CLOTHING_COVERED_ZONES[item_name])
		# Hide Desnudo_* parts covered by this clothing item
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = false
					print("[CLOTHING] Ocultando: ", skin_name)
	_recalculate_carry_capacity()
	_recalculate_warmth()
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
	if CLOTHING_SLOTS.has(item_name):
		if _equipped_slots.get(slot, "") == item_name:
			_equipped_slots.erase(slot)
	if equipped_clothing == item_name:
		equipped_clothing = ""
	_recalculate_carry_capacity()
	_recalculate_warmth()
	# Hide _full_body_mesh, show _head_mesh (face stays visible).
	# Show Desnudo_* for exposed areas.
	var hide_legs := not (_equipped_slots.has("legs") and not str(_equipped_slots["legs"]).is_empty())
	var hide_torso := not (_equipped_slots.has("torso") and not str(_equipped_slots["torso"]).is_empty())
	if _full_body_mesh != null:
		_full_body_mesh.visible = false
		_full_body_mesh.material_override = null
	if _head_mesh != null:
		_head_mesh.visible = true
	# Hide Body_legs/Body_feet — they overlap with Desnudo_legs/feet
	for bn in ["Body_legs", "Body_feet"]:
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
	# Custom character: hide the clothing mesh, show Desnudo_* for uncovered zones
	if is_custom_character and not slot.is_empty():
		var cloth_mi := _find_custom_slot_mesh(slot)
		if cloth_mi != null:
			cloth_mi.visible = false
			print("[CLOTHING] Retirada: ", item_name, " | slot=", slot, " | mesh=", cloth_mi.name)
		# Show Desnudo_* parts that were covered by this clothing item
		if DEFAULT_SKIN_HIDES.has(item_name):
			for skin_name in DEFAULT_SKIN_HIDES[item_name]:
				var skin_mi: MeshInstance3D = _find_mesh_in_third_person(skin_name)
				if skin_mi != null:
					skin_mi.visible = true
					print("[CLOTHING] Restaurando: ", skin_name)
		if CLOTHING_COVERED_ZONES.has(item_name):
			print("[CLOTHING] Zonas restauradas: ", CLOTHING_COVERED_ZONES[item_name])
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
	for bn in ["Body_arms", "Body_hands", "soldier_hands"]:
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
	# The source model is in cm, the custom character's skeleton is in meters.
	# Scale factor converts source bind poses to match destination skeleton units.
	var src_height := _skeleton_height(src_skel)
	var dst_height := _skeleton_height(dst_skel)
	var scale_factor := 0.01
	if src_height > 0.01 and dst_height > 0.01:
		scale_factor = dst_height / src_height
	print("[DESNUDO-CUSTOM] scale_factor=", scale_factor, " character_scale=", character_scale)
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
			for bi in range(bone_count):
				var bind_bone := src_skin.get_bind_bone(bi)
				var bone_name: StringName = src_skin.get_bind_name(bi)
				if bind_bone >= 0:
					bone_name = src_skel.get_bone_name(bind_bone)
				if bone_name.is_empty():
					continue
				var dst_bone_idx: int = dst_bone_map.get(bone_name, -1)
				if dst_bone_idx < 0:
					continue
				# Convert source bind pose from cm to m while preserving rotation.
				# The mesh vertices are already scaled by scale_factor, so only
				# the origin (translation) needs scaling; the basis (rotation)
				# must stay unchanged to avoid deformation.
				var bind_pose: Transform3D = src_skin.get_bind_pose(bi)
				bind_pose.origin *= scale_factor
				new_skin.add_bind(dst_bone_idx, bind_pose)
			clone.skin = new_skin
		dst_skel.add_child(clone)
		clone.skeleton = dst_skel.get_path()
		print("[CLOTHING-INIT] Desnudo añadido: ", desnudo_name, " has_skin=", clone.skin != null)
	# Split the custom Body so only the head remains visible; Desnudo_* cover the rest.
	_add_custom_head_mesh()
	# Hide custom character's built-in clothing meshes — survival clothing replaces them
	for cloth_name in ["Bottoms", "Tops", "Shoes", "Pants", "Shirt", "Jacket", "Dress", "Skirt", "Ch42_Shirt", "Ch42_Shorts", "Ch42_Sneakers"]:
		var cmi: MeshInstance3D = _find_mesh_in_third_person(cloth_name)
		if cmi != null:
			cmi.visible = false
			print("[CLOTHING-INIT] Hidden built-in clothing mesh: ", cloth_name)
	src_scene.free()

func _wear_survival_clothing(item_name: String, worn: bool) -> void:
	if not SURVIVAL_CLOTHING.has(item_name):
		return
	var cfg: Dictionary = SURVIVAL_CLOTHING[item_name]
	var mesh_name := String(cfg["mesh"])
	var mi: MeshInstance3D = _survival_cloth_nodes.get(mesh_name)
	if mi != null:
		mi.visible = worn
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
func _wear_clothing_visual(item_name: String) -> void:
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
	if cfg.has("tint"):
		var tint: Color = cfg["tint"]
		var meshes: Array = []
		_collect_mesh_instances(node, meshes)
		for mi in meshes:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = tint
			mat.roughness = 0.9
			mat.metallic = 0.0
			mi.material_override = mat

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
	if is_crouching:
		capsule.height = 1.1
		_collision_shape.position.y = bottom_y + 0.55
	else:
		capsule.height = 1.75
		_collision_shape.position.y = bottom_y + 0.875

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
		_update_interaction_prompt()
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
	var crouch_input := Input.is_action_pressed("crouch")
	if crouch_input:
		_force_crouch = false
	if _force_crouch and not crouch_input and input_dir.length() < 0.1:
		is_crouching = true
	else:
		is_crouching = crouch_input
		_force_crouch = false
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
		stats.changed.emit()
	elif not is_jumping and is_on_floor():
		stats.energy = min(stats.max_stat, stats.energy + (8.0 - carry * 4.0) * delta)
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
	_update_interaction_prompt()
	_update_flashlight(delta)
	_update_backpack_socket()
	_update_hand_socket()

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
		stats.changed.emit()
		if _water_notice_cooldown <= 0.0:
			notice.emit("Te mojas. La ropa fria te roba calor.")
			_water_notice_cooldown = 8.0
	else:
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
			stats.changed.emit()

func _query_river_depth() -> float:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_river_depth_at"):
		return float(scene.call("get_river_depth_at", global_position))
	return 0.0

func _create_body() -> void:
	_collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	_collision_shape.shape = capsule
	_collision_shape.position.y = 0.9
	add_child(_collision_shape)

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
	_create_third_person_model()

func _add_starting_items() -> void:
	inventory.add_item(ItemScript.create("Camiseta", "clothing", 0.3, 1, 0.05))
	inventory.add_item(ItemScript.create("Pantalones", "clothing", 0.5, 1, 0.10))
	inventory.add_item(ItemScript.create("Zapatillas", "clothing", 0.4, 1, 0.08))

func _create_third_person_model() -> void:
	var character: Node3D = null
	# Check GameState for a selected custom character (Remy, personaje2, etc.)
	if not is_puppet:
		var gs := get_node_or_null("/root/GameState")
		if gs != null:
			var custom_path: String = gs.get_selected_model_path()
			if not custom_path.is_empty():
				character = _load_external_node3d(custom_path)
				if character != null:
					third_person_loaded_path = custom_path
	# Puppet: use puppet_model_path if set
	if character == null and is_puppet and not puppet_model_path.is_empty():
		character = _load_external_node3d(puppet_model_path)
		if character != null:
			third_person_loaded_path = puppet_model_path
	# Fallback: try default candidates
	if character == null:
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
		var is_clothing_model := third_person_loaded_path.find("player_with_clothes") >= 0
		add_child(character)
		third_person_model = character
		_hide_third_person_held_props(character)
		_hide_third_person_export_helpers(character)
		is_custom_character = not is_clothing_model
		# Calculate and apply scale after adding to scene tree so skeleton poses are valid
		var character_scale: float
		if is_clothing_model:
			character_scale = MIXAMO_CHARACTER_SCALE
		else:
			# Custom characters: calculate scale from skeleton height so they match
			# Remy's visual height (skeleton_height * 0.72). This ensures personaje2
			# and any future custom character are the same size as Remy.
			var skel := _find_skeleton(character)
			if skel != null:
				var skel_height := _skeleton_height(skel)
				if skel_height > 0.01:
					character_scale = (3.69 * MIXAMO_CHARACTER_SCALE) / skel_height
				else:
					character_scale = MIXAMO_CHARACTER_SCALE
			else:
				character_scale = MIXAMO_CHARACTER_SCALE
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
							equip_clothing(str(item.item_name))
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
				third_person_back_item_root = Node3D.new()
				third_person_back_item_root.name = "BackpackSocket"
				third_person_back_item_root.position = Vector3(0.0, -0.05, -0.18)
				third_person_model.add_child(third_person_back_item_root)
		_setup_third_person_animation(character)
		_align_third_person_model_to_ground()
		if not is_puppet and third_person_model != null:
			third_person_model.visible = true
		if is_custom_character and not is_puppet:
			get_tree().create_timer(0.5).timeout.connect(_debug_drop_and_screenshot)
		return
	_create_procedural_third_person_model()

func _create_procedural_third_person_model() -> void:
	var rig := Node3D.new()
	rig.name = "ThirdPersonAnimatedRig"
	rig.visible = false
	add_child(rig)
	third_person_model = rig

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
	if _hand_skeleton != null:
		for bone_name in ["mixamorig:RightHand", "mixamorig:LeftHand", "mixamorig_RightHand", "mixamorig_LeftHand", "RightHand", "LeftHand"]:
			_hand_bone_idx = _hand_skeleton.find_bone(bone_name)
			if _hand_bone_idx != -1:
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
		# print("[RIFLE_DEBUG] AnimPlayer root_node=", debug_root, " skel_path=", debug_skel_path, " anim_count=", third_person_animation_player.get_animation_list().size())
	var lib: AnimationLibrary = AnimationLibrary.new()
	var skip_post_process := [THIRD_PERSON_EXTERNAL_SLEEP_ANIMATION, THIRD_PERSON_EXTERNAL_SIT_ANIMATION]
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
		# DEBUG: verify animation is playing and track types
		var _dbg_anim := third_person_animation_player.get_animation(third_person_idle_animation)
		if _dbg_anim != null:
			var _pos_count := 0
			var _rot_count := 0
			var _scale_count := 0
			for _ti in range(_dbg_anim.get_track_count()):
				var _tt := _dbg_anim.track_get_type(_ti)
				if _tt == Animation.TYPE_POSITION_3D:
					_pos_count += 1
				elif _tt == Animation.TYPE_ROTATION_3D:
					_rot_count += 1
				elif _tt == Animation.TYPE_SCALE_3D:
					_scale_count += 1
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

func _remove_non_hips_position_tracks(animation: Animation, allow_hips_y: bool = false, sit_fraction: float = 0.0) -> void:
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
			# But preserve Y offset for sit/sleep animations
			var bone_name := "mixamorig_Hips"
			var bone_idx := skeleton.find_bone(bone_name)
			if bone_idx == -1:
				bone_idx = skeleton.find_bone("mixamorig:Hips")
			if bone_idx != -1:
				var rest_pos := skeleton.get_bone_rest(bone_idx).origin
				var key_count := animation.track_get_key_count(track_index)
				if allow_hips_y and sit_fraction > 0.0:
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
	for track_index in range(animation.get_track_count()):
		if animation.track_get_type(track_index) != Animation.TYPE_ROTATION_3D:
			continue
		var path_text := str(animation.track_get_path(track_index))
		var bone_name := _extract_mixamo_bone_name(path_text)
		if bone_name.is_empty():
			continue
		var resolved_name := _resolve_mixamo_bone_name(skeleton, bone_name)
		if resolved_name.is_empty():
			continue
		var target_idx := skeleton.find_bone(resolved_name)
		if target_idx == -1:
			continue
		var target_rest_rot := skeleton.get_bone_rest(target_idx).basis.get_rotation_quaternion()
		var source_rest_rot := _get_source_skeleton_rest_rot(bone_name)
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
	return ""

func _resolve_mixamo_bone_name(skeleton: Skeleton3D, imported_bone_name: String) -> String:
	var candidates: Array[String] = [imported_bone_name]
	if imported_bone_name.begins_with("mixamorig:"):
		candidates.append("mixamorig_" + imported_bone_name.substr("mixamorig:".length()))
	elif imported_bone_name.begins_with("mixamorig_"):
		candidates.append("mixamorig:" + imported_bone_name.substr("mixamorig_".length()))
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
	print("[HEAD-CUSTOM] body_mi=", src_body.name, " mesh=", src_body.mesh, " skin=", src_body.skin)
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
		print("[HEAD-CUSTOM] AABB pos=", aabb.position, " size=", aabb.size, " cy_thresh=", cy_threshold, " cx_thresh=", cx_threshold)
		print("[HEAD-CUSTOM] face_count=", mdt.get_face_count())
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
		head_mat.set_shader_parameter("clip_y", cy_threshold)
		head_dup.material_override = head_mat
		head_dup.mesh = mesh_res
		print("[HEAD-CUSTOM] head_faces=", head_faces.size(), " head_mesh_surfaces=", head_mesh.get_surface_count())
	src_body.get_parent().add_child(head_dup)
	# Ensure HeadMesh uses the same skeleton and skin as the original Body
	head_dup.skeleton = src_body.skeleton
	head_dup.skin = src_body.skin
	_full_body_mesh = src_body
	_head_mesh = head_dup
	_head_mesh.visible = true
	src_body.visible = false

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
			if bone_name.find("Foot") >= 0 or bone_name.find("foot") >= 0 \
					or bone_name.find("Head") >= 0 or bone_name.find("head") >= 0:
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
	# For custom characters, use skeleton foot bone global positions
	# which are more accurate than mesh AABB (which reflects T-pose, not actual pose)
	var min_y := 1000000.0
	if is_custom_character:
		var skeleton := _find_skeleton(third_person_model)
		if skeleton != null:
			for i in range(skeleton.get_bone_count()):
				var bone_name := skeleton.get_bone_name(i)
				if bone_name.find("Foot") >= 0 or bone_name.find("foot") >= 0:
					var gp := skeleton.get_bone_global_pose(i)
					min_y = min(min_y, gp.origin.y)
			# Also check Toe bones
			for i in range(skeleton.get_bone_count()):
				var bone_name := skeleton.get_bone_name(i)
				if bone_name.find("Toe") >= 0 or bone_name.find("toe") >= 0:
					var gp := skeleton.get_bone_global_pose(i)
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
		third_person_ground_offset = -min_y + 0.06
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
	held_index = 0

func equip_item_by_name(item_name: String) -> void:
	if inventory == null:
		return
	for i in range(inventory.items.size()):
		if inventory.items[i].item_name == item_name:
			held_index = i
			_sync_held_item()
			return

func get_held_item():
	if inventory == null or inventory.items.is_empty():
		return null
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	return inventory.items[held_index]

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
	item_dropped.emit("campfire", "campfire", 0.0, 1, 0.0, pos)
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
	item_dropped.emit("shelter", "shelter", 0.0, 1, 0.0, pos)
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

func drop_inventory_item(index: int) -> void:
	if inventory == null or index < 0 or index >= inventory.items.size():
		return
	var item = inventory.items[index]
	var item_name := str(item.item_name)
	var item_type := str(item.item_type)
	if item_type == "backpack":
		equipped_backpack = ""
		_recalculate_carry_capacity()
	if item_name == "Chaqueta de abrigo" and not equipped_clothing.is_empty():
		equipped_clothing = ""
		_recalculate_carry_capacity()
	if CLOTHING_SLOTS.has(item_name):
		unequip_clothing(item_name)
	var drop_qty := int(item.quantity) if item.has_method("get") and "quantity" in item else 1
	var drop_pos := global_position + (global_transform.basis * Vector3.FORWARD * 0.8)
	drop_pos.y = global_position.y
	item_dropped.emit(item_name, item_type, float(item.weight), drop_qty, float(item.use_value), drop_pos)
	inventory.remove_index(index, drop_qty)
	if held_index >= inventory.items.size():
		held_index = max(0, inventory.items.size() - 1)
	_sync_held_item()
	notice.emit("Sueltas %s." % item_name)

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
	if third_person_hand_item_root == null or third_person_back_item_root == null:
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			pass # print("[RIFLE_VERIFY] sync blocked: hand_root=", third_person_hand_item_root, " back_root=", third_person_back_item_root)
		return
	if is_sleeping:
		for child in third_person_hand_item_root.get_children():
			third_person_hand_item_root.remove_child(child)
			child.free()
		_clear_rifle_attachment()
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			pass # print("[RIFLE_VERIFY] sync blocked: player sleeping")
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
	if hands != null and hands.has_item_in_hands():
		if held_item != null and str(held_item.item_type) == "weapon_rifle":
			pass # print("[RIFLE_VERIFY] sync blocked: PlayerHands already contains ", hands.get_current_hand_item())
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
			# print("[RIFLE_AABB] mesh #%d name=%s local_pos=%s local_size=%s acc_origin=%s" % [mc, mi.name, str(local_aabb.position), str(local_aabb.size), str(accumulated.origin)])
			# print("[RIFLE_AABB]   -> world_aabb pos=%s size=%s" % [str(world_aabb.position), str(world_aabb.size)])
	for child in node.get_children():
		if child is Node3D:
			var child_acc := accumulated * (child as Node3D).transform
			_traverse_mesh_aabb(child, child_acc, state)
		else:
			_traverse_mesh_aabb(child, accumulated, state)

func _build_third_person_rifle() -> void:
	if third_person_hand_item_root == null or not is_instance_valid(third_person_hand_item_root):
		return
	_clear_rifle_attachment()
	var model := _load_external_node3d(REAL_RIFLE_MODEL)
	if model == null:
		pass # print("[RIFLE_VERIFY] model load failed: ", REAL_RIFLE_MODEL)
		return
	var skeleton := _spine_skeleton if _spine_skeleton != null else _find_skeleton(third_person_model)
	if skeleton == null or not is_instance_valid(skeleton):
		model.queue_free()
		# print("[RIFLE_VERIFY] skeleton not found for model: ", third_person_model)
		return
	var resolved_bone := _resolve_bone_name_safe(right_hand_bone_name, skeleton)
	if resolved_bone.is_empty():
		model.queue_free()
		# print("[RIFLE_VERIFY] Right-hand bone not found: ", right_hand_bone_name, " skeleton=", skeleton.get_path())
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
		# print("[RIFLE_AABB] meshes found=%d" % mesh_count)
		# print("[RIFLE_AABB] combined_aabb position=%s size=%s" % [str(combined_aabb.position), str(combined_aabb.size)])
		# print("[RIFLE_AABB] stock (max Z) = (%.4f, %.4f, %.4f)" % [stock_x, stock_y, stock_z])
		# print("[RIFLE_AABB] muzzle (min Z) = (%.4f, %.4f, %.4f)" % [muzzle_x, muzzle_y, muzzle_z])
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
	_rifle_muzzle.name = "Muzzle"
	_rifle_muzzle.position = Vector3(muzzle_x, muzzle_y, muzzle_z)
	_rifle_root.add_child(_rifle_muzzle)
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
	# Debug
	if weapon_debug_visuals:
		_create_rifle_debug_spheres()
	# FASE 5: Diagnostics
	_rifle_bone_attachment.force_update_transform()
	_rifle_weapon_offset.force_update_transform()
	_rifle_root.force_update_transform()
	var grip_world := _rifle_right_grip.global_position
	var muzzle_world := _rifle_muzzle.global_position
	var stock_world := _rifle_stock_ref.global_position
	var rh_world := _rifle_bone_attachment.global_position
	var rh_bone_name := _resolve_bone_name_safe(right_hand_bone_name, skeleton)
	var rh_dist := -1.0
	if not rh_bone_name.is_empty():
		var rh_idx := skeleton.find_bone(rh_bone_name)
		if rh_idx >= 0:
			rh_world = (skeleton.global_transform * skeleton.get_bone_global_pose(rh_idx)).origin
			rh_dist = rh_world.distance_to(grip_world)
	# Right elbow distance to stock
	var re_bone := _resolve_bone_name_safe("mixamorig:RightForeArm", skeleton)
	var re_world := Vector3.ZERO
	var re_dist := -1.0
	if not re_bone.is_empty():
		var re_idx := skeleton.find_bone(re_bone)
		if re_idx >= 0:
			re_world = (skeleton.global_transform * skeleton.get_bone_global_pose(re_idx)).origin
			re_dist = re_world.distance_to(stock_world)
	# print("[RIFLE_FASE5] rifle_global_pos=", _rifle_root.global_position)
	# print("[RIFLE_FASE5] rifle_global_rot=", _rifle_root.global_rotation_degrees)
	# print("[RIFLE_FASE5] rifle_global_scale=", _rifle_root.global_transform.basis.get_scale())
	# print("[RIFLE_FASE5] grip_world=", grip_world, " rh_world=", rh_world)
	# print("[RIFLE_FASE5] dist_rightHand_to_RightGrip=", rh_dist)
	# print("[RIFLE_FASE5] dist_rightElbow_to_Stock=", re_dist)
	# print("[RIFLE_FASE5] muzzle_world=", muzzle_world, " stock_world=", stock_world)
	# print("[RIFLE_FASE5] ik_enabled=", ik_enabled, " ik_influence=", _rifle_left_arm_ik.influence if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik) else "N/A")
	# Orientation diagnostics
	var barrel_dir := (muzzle_world - grip_world).normalized()
	var char_forward := -global_basis.z
	var char_right := global_basis.x
	var stock_rel := stock_world - rh_world
	var muzzle_rel := muzzle_world - rh_world
	# print("[RIFLE_ORIENT] stock_rel_RH=", stock_rel, " muzzle_rel_RH=", muzzle_rel)
	# print("[RIFLE_ORIENT] barrel_dot_forward=", barrel_dir.dot(char_forward), " barrel_dot_right=", barrel_dir.dot(char_right))
	# Basis diagnostics: check inherited rotation from bone
	var ba_basis := _rifle_bone_attachment.global_basis.orthonormalized()
	var wo_basis := _rifle_weapon_offset.global_basis.orthonormalized()
	var wo_local_basis := _rifle_weapon_offset.basis.orthonormalized()
	# print("[RIFLE_BASIS] BoneAttachment global_basis:")
	# print("  x=", ba_basis.x, " y=", ba_basis.y, " z=", ba_basis.z)
	# print("[RIFLE_BASIS] WeaponOffset global_basis:")
	# print("  x=", wo_basis.x, " y=", wo_basis.y, " z=", wo_basis.z)
	# print("[RIFLE_BASIS] WeaponOffset local_basis (relative to bone):")
	# print("  x=", wo_local_basis.x, " y=", wo_local_basis.y, " z=", wo_local_basis.z)
	# What direction does model +Z point in world space?
	var model_z_world := wo_basis.z
	# print("[RIFLE_BASIS] model_+Z_world=", model_z_world, " (this is barrel direction)")
	var model_y_world := wo_basis.y
	# print("[RIFLE_BASIS] model_+Y_world=", model_y_world, " (this is rifle up direction)")
	# Diagnostic completo de jerarquía y transformaciones (solo lectura)
	_diagnose_rifle_hierarchy_and_transforms(skeleton, true)

func _print_node_tree(node: Node, indent: String = "") -> void:
	var type_str := node.get_class()
	# print("[RIFLE_HIERARCHY] %s%s (%s)" % [indent, node.name, type_str])
	for c in node.get_children():
		_print_node_tree(c, indent + "  ")

func _print_node_transforms_diagnostics(node: Node, label: String) -> void:
	if node == null or not is_instance_valid(node):
		pass # print("[RIFLE_DIAG] %s: null or invalid" % label)
		return
	if not (node is Node3D):
		pass # print("[RIFLE_DIAG] %s: not Node3D" % label)
		return
	var n3d := node as Node3D
	var local_t: Transform3D = n3d.transform
	var global_t: Transform3D = n3d.global_transform
	var global_scale: Vector3 = global_t.basis.get_scale()
	# print("[RIFLE_DIAG] === %s (%s) ===" % [label, node.get_class()])
	# print("[RIFLE_DIAG]   path=%s" % str(node.get_path()))
	# print("[RIFLE_DIAG]   top_level=%s" % str(n3d.top_level))
	var local_euler := local_t.basis.get_euler()
	var global_euler := global_t.basis.get_euler()
	# print("[RIFLE_DIAG]   local_position=%s" % str(local_t.origin))
	# print("[RIFLE_DIAG]   local_rotation_degrees=%s" % str(Vector3(rad_to_deg(local_euler.x), rad_to_deg(local_euler.y), rad_to_deg(local_euler.z))))
	# print("[RIFLE_DIAG]   local_scale=%s" % str(local_t.basis.get_scale()))
	# print("[RIFLE_DIAG]   local_transform=%s" % str(local_t))
	# print("[RIFLE_DIAG]   global_position=%s" % str(global_t.origin))
	# print("[RIFLE_DIAG]   global_rotation_degrees=%s" % str(Vector3(rad_to_deg(global_euler.x), rad_to_deg(global_euler.y), rad_to_deg(global_euler.z))))
	# print("[RIFLE_DIAG]   global_scale=%s" % str(global_scale))
	# print("[RIFLE_DIAG]   global_transform=%s" % str(global_t))

func _relative_transform(parent: Node3D, child: Node3D) -> Transform3D:
	if parent == null or child == null or not is_instance_valid(parent) or not is_instance_valid(child):
		return Transform3D.IDENTITY
	return parent.global_transform.affine_inverse() * child.global_transform

func _find_first_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _find_first_mesh(c)
		if found != null:
			return found
	return null

func _diagnose_rifle_hierarchy_and_transforms(skel: Skeleton3D, full: bool = false) -> void:
	# DIAGNÓSTICO COMPLETO: no modifica valores, solo imprime.
	if _rifle_root == null or not is_instance_valid(_rifle_root):
		return

	# 1. Jerarquía real
	# print("\n[RIFLE_HIERARCHY] === JERARQUIA REAL ===")
	_print_node_tree(self)

	# 2. Nodos obligatorios
	var rh_bone_name := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var rh_idx := -1
	if not rh_bone_name.is_empty():
		rh_idx = skel.find_bone(rh_bone_name)

	# print("\n[RIFLE_DIAG] === INFORMACIÓN DEL BONE ATTACHMENT ===")
	# print("[RIFLE_DIAG] bone_name=%s" % _rifle_bone_attachment.bone_name if _rifle_bone_attachment != null else "N/A")
	# print("[RIFLE_DIAG] bone_index=%d" % skel.find_bone(_rifle_bone_attachment.bone_name) if _rifle_bone_attachment != null else -1)
	if rh_idx >= 0:
		pass # print("[RIFLE_DIAG] mixamorig:RightHand global_transform=%s" % str(skel.global_transform * skel.get_bone_global_pose(rh_idx)))
	else:
		pass # print("[RIFLE_DIAG] mixamorig:RightHand no encontrado")

	_print_node_transforms_diagnostics(skel, "Skeleton3D")
	_print_node_transforms_diagnostics(_rifle_bone_attachment, "BoneAttachment3D_RightHand")
	_print_node_transforms_diagnostics(_rifle_weapon_offset, "WeaponOffset")
	_print_node_transforms_diagnostics(_rifle_root, "RifleRoot")
	_print_node_transforms_diagnostics(_rifle_model, "GLBRoot (RifleMesh)")
	var main_mesh := _find_first_mesh(_rifle_model) if _rifle_model != null else null
	_print_node_transforms_diagnostics(main_mesh, "MeshInstance3D principal")
	_print_node_transforms_diagnostics(_rifle_right_grip, "RightGrip")
	_print_node_transforms_diagnostics(_rifle_left_hand_grip, "LeftHandGrip")
	_print_node_transforms_diagnostics(_rifle_stock_ref, "StockReference")
	_print_node_transforms_diagnostics(_rifle_muzzle, "Muzzle")

	# 3. Distancia RightGrip a RightHand
	if _rifle_right_grip != null and rh_idx >= 0:
		var rh_world := skel.global_transform * skel.get_bone_global_pose(rh_idx)
		var grip_t := _rifle_right_grip.global_transform
		var dist_rg := rh_world.origin.distance_to(grip_t.origin)
		# print("\n[RIFLE_DIAG] === RELACIÓN RightHand -> RightGrip ===")
		# print("[RIFLE_DIAG] RightHand origin=%s" % str(rh_world.origin))
		# print("[RIFLE_DIAG] RightGrip origin=%s" % str(grip_t.origin))
		# print("[RIFLE_DIAG] dist_RightGrip_RightHand=%.6f" % dist_rg)
		# print("[RIFLE_DIAG] relative_RightHand_to_RightGrip=%s" % str(rh_world.affine_inverse() * grip_t))

	# 4. Transformaciones relativas
	# print("\n[RIFLE_DIAG] === TRANSFORMACIONES RELATIVAS ===")
	# print("[RIFLE_DIAG] BoneAttachment -> WeaponOffset = %s" % str(_relative_transform(_rifle_bone_attachment, _rifle_weapon_offset)))
	# print("[RIFLE_DIAG] WeaponOffset -> RifleRoot = %s" % str(_relative_transform(_rifle_weapon_offset, _rifle_root)))
	# print("[RIFLE_DIAG] RifleRoot -> GLBRoot = %s" % str(_relative_transform(_rifle_root, _rifle_model)))
	if _rifle_model != null and main_mesh != null:
		pass # print("[RIFLE_DIAG] GLBRoot -> MeshInstance3D = %s" % str(_relative_transform(_rifle_model, main_mesh)))

	# 5. Detección de transformaciones duplicadas / errores
	# print("\n[RIFLE_DIAG] === DETECCIÓN DE DUPLICADOS ===")
	var errors: Array[String] = []
	if _rifle_weapon_offset != null and not _rifle_weapon_offset.top_level:
		errors.append("ERROR: WeaponOffset.top_level = false")
	if _rifle_root != null and not _rifle_root.top_level:
		errors.append("ERROR: RifleRoot.top_level = false")
	var root_basis := _rifle_root.global_basis.orthonormalized() if _rifle_root != null else Basis.IDENTITY
	var model_basis := _rifle_model.global_basis.orthonormalized() if _rifle_model != null else Basis.IDENTITY
	if root_basis.is_equal_approx(model_basis):
		errors.append("ADVERTENCIA: RifleRoot y GLBRoot comparten la misma base (uno podría ser redundante)")
	var root_scale := _rifle_root.global_transform.basis.get_scale() if _rifle_root != null else Vector3.ONE
	var model_scale := _rifle_model.global_transform.basis.get_scale() if _rifle_model != null else Vector3.ONE
	if not root_scale.is_equal_approx(Vector3.ONE) and not model_scale.is_equal_approx(Vector3.ONE):
		errors.append("ERROR: escala aplicada en dos niveles (RifleRoot=%s y GLBRoot=%s)" % [str(root_scale), str(model_scale)])
	if _rifle_weapon_offset != null:
		var wo_rot := _rifle_weapon_offset.global_rotation_degrees
		if absf(wo_rot.y) > 1.0:
			errors.append("ADVERTENCIA: WeaponOffset rota Y=%.1f" % wo_rot.y)
	if main_mesh != null:
		var mesh_rot := main_mesh.global_rotation_degrees
		if mesh_rot.length() > 1.0:
			errors.append("ADVERTENCIA: MeshInstance3D principal tiene rotación %s" % str(mesh_rot))
		var mesh_scale := main_mesh.global_transform.basis.get_scale()
		if not mesh_scale.is_equal_approx(Vector3.ONE):
			errors.append("ADVERTENCIA: MeshInstance3D principal tiene escala %s" % str(mesh_scale))
	if _rifle_right_grip != null and not _rifle_right_grip.position.is_equal_approx(Vector3.ZERO):
		pass # print("[RIFLE_DIAG] RightGrip local position=%s (desplazado del origen)" % str(_rifle_right_grip.position))
	for e in errors:
		pass # print("[RIFLE_DIAG] %s" % e)
	if errors.is_empty():
		pass # print("[RIFLE_DIAG] No se detectaron duplicados obvios.")

	# 6. Per-frame RifleIdle diagnostics
	if full:
		return
	# print("\n[RIFLE_HIERARCHY] === PER-FRAME RIFLE IDLE ===")
	# print("[RIFLE_HIERARCHY] RightHand global_transform = %s" % (str(skel.global_transform * skel.get_bone_global_pose(rh_idx)) if rh_idx >= 0 else "N/A"))
	# print("[RIFLE_HIERARCHY] BoneAttachment global_transform = %s" % str(_rifle_bone_attachment.global_transform if _rifle_bone_attachment != null else "N/A"))
	# print("[RIFLE_HIERARCHY] WeaponOffset global_transform = %s" % str(_rifle_weapon_offset.global_transform if _rifle_weapon_offset != null else "N/A"))
	# print("[RIFLE_HIERARCHY] RifleRoot global_transform = %s" % str(_rifle_root.global_transform))
	# print("[RIFLE_HIERARCHY] GLBRoot global_transform = %s" % str(_rifle_model.global_transform if _rifle_model != null else "N/A"))
	# print("[RIFLE_HIERARCHY] RightGrip global_transform = %s" % str(_rifle_right_grip.global_transform))
	# print("[RIFLE_HIERARCHY] Muzzle global_transform = %s" % str(_rifle_muzzle.global_transform if _rifle_muzzle != null else "N/A"))
	# print("[RIFLE_HIERARCHY] StockReference global_transform = %s" % str(_rifle_stock_ref.global_transform if _rifle_stock_ref != null else "N/A"))
	# print("[RIFLE_HIERARCHY] Pitch=%.2f Yaw=%.2f Roll=%.2f" % [rad_to_deg(_rifle_root.global_rotation.x), rad_to_deg(_rifle_root.global_rotation.y), rad_to_deg(_rifle_root.global_rotation.z)])

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

	var rh_bone_name := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var lh_bone_name := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	var shoulder_bone_name := _resolve_bone_name_safe("mixamorig:RightShoulder", skel)
	if shoulder_bone_name.is_empty():
		shoulder_bone_name = _resolve_bone_name_safe("mixamorig:RightArm", skel)
	if rh_bone_name.is_empty() or lh_bone_name.is_empty() or shoulder_bone_name.is_empty():
		return
	var rh_idx := skel.find_bone(rh_bone_name)
	var lh_idx := skel.find_bone(lh_bone_name)
	var sh_idx := skel.find_bone(shoulder_bone_name)
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
	_rifle_weapon_offset.global_basis = weapon_basis
	_rifle_root.position = Vector3.ZERO
	_rifle_weapon_offset.global_position = rh_pos - weapon_basis * rg_local
	_rifle_weapon_offset.force_update_transform()
	_rifle_root.force_update_transform()

	# Apply -5° pitch when aiming (local rotation around the right grip pivot).
	if _is_aiming:
		weapon_basis = weapon_basis * Basis(Vector3(1.0, 0.0, 0.0), deg_to_rad(-5.0))
		_rifle_weapon_offset.global_basis = weapon_basis
		_rifle_weapon_offset.global_position = rh_pos - weapon_basis * rg_local
		_rifle_weapon_offset.force_update_transform()
		_rifle_root.force_update_transform()

	# Shift the whole rifle 3 cm along the real barrel line (from muzzle toward stock)
	# without changing rotation or scale. Direction is taken from the actual Muzzle/Stock markers.
	if _rifle_muzzle != null and is_instance_valid(_rifle_muzzle) and _rifle_stock_ref != null and is_instance_valid(_rifle_stock_ref):
		var barrel_dir := (_rifle_muzzle.global_position - _rifle_stock_ref.global_position).normalized()
		_rifle_root.global_position += barrel_dir * 0.40

	# Disable IK so the arms stay in animation pose
	if _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik):
		_rifle_left_arm_ik.active = false
		_rifle_left_arm_ik.influence = 0.0

	if weapon_debug_visuals:
		_update_rifle_debug_spheres()

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
	# print("[RIFLE_PHASE1] RifleIdle estable 2s | dist_RH (mano der - RightGrip) = %.6f m (objetivo < 0.02)" % avg)
	# print("[RIFLE_PHASE1] rh_world=(%.3f,%.3f,%.3f) rg_world=(%.3f,%.3f,%.3f)" % [rh_pos.x, rh_pos.y, rh_pos.z, rg_pos.x, rg_pos.y, rg_pos.z])
	# print("[RIFLE_PHASE1] weapon_offset_pos=(0,0,0) fijo | rifle_root_offset=%s" % str(rifle_root_offset))
	# print("[RIFLE_PHASE1] Si dist_RH >= 0.02, ajusta rifle_root_offset en pasos <=5 unidades. No actives IK todavia.")

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
	# print("[ROOT_ALIGN] round=%d axis=%s phase=%d avg_dist_RH=%.6f rifle_root_offset=%s samples=%d" % [
		# _root_align_round, axis_name, _root_align_phase, avg, str(rifle_root_offset), n_int
	# ])
	match _root_align_phase:
		0: # base measurement
			_root_align_best_dist = avg
			_root_align_best_offset = rifle_root_offset
			# try +step on current axis
			_apply_root_offset_delta(_root_align_axis, _root_align_step)
			_root_align_phase = 1
			# print("[ROOT_ALIGN] Trying %s +%.1f" % [axis_name, _root_align_step])
		1: # after +
			if avg < _root_align_best_dist:
				_root_align_best_dist = avg
				_root_align_best_offset = rifle_root_offset
				# print("[ROOT_ALIGN] %s + IMPROVED to %.6f" % [axis_name, avg])
				# continue in same direction
				_apply_root_offset_delta(_root_align_axis, _root_align_step)
				_root_align_phase = 1
			else:
				pass # print("[ROOT_ALIGN] %s + did NOT improve (%.6f >= %.6f)" % [axis_name, avg, _root_align_best_dist])
				rifle_root_offset = _root_align_best_offset
				_apply_root_offset_delta(_root_align_axis, -_root_align_step)
				_root_align_phase = 2
				# print("[ROOT_ALIGN] Trying %s -%.1f" % [axis_name, _root_align_step])
		2: # after -
			if avg < _root_align_best_dist:
				_root_align_best_dist = avg
				_root_align_best_offset = rifle_root_offset
				# print("[ROOT_ALIGN] %s - IMPROVED to %.6f" % [axis_name, avg])
				_apply_root_offset_delta(_root_align_axis, -_root_align_step)
				_root_align_phase = 2
			else:
				pass # print("[ROOT_ALIGN] %s - did NOT improve (%.6f >= %.6f)" % [axis_name, avg, _root_align_best_dist])
				rifle_root_offset = _root_align_best_offset
				_next_root_axis()
	# convergence check
	if _root_align_best_dist < 0.02:
		rifle_root_offset = _root_align_best_offset
		_root_align_converged = true
		# print("[ROOT_ALIGN] CONVERGED! dist_RH=%.6f < 0.02" % _root_align_best_dist)
		# print("[ROOT_ALIGN] FINAL rifle_root_offset = Vector3(%.4f, %.4f, %.4f)" % [rifle_root_offset.x, rifle_root_offset.y, rifle_root_offset.z])
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
		# print("[ROOT_ALIGN] dist_RH=%.4f | dist_LH=%.4f | dist_stock_elbow=%.4f" % [
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
	# print("[ROOT_ALIGN] Best so far: dist_RH=%.6f at %s | next axis step=%.2f" % [
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
	# print("[RIFLE_IK] L_inf=%.2f R_inf=%.2f | dist_RH=%.4f dist_LH=%.4f dist_stock=%.4f | RH=(%.3f,%.3f,%.3f) RG=(%.3f,%.3f,%.3f)" % [
		# left_inf, right_inf, dist_rh, dist_lh, dist_stock,
		# rh_pos.x, rh_pos.y, rh_pos.z, rg_pos.x, rg_pos.y, rg_pos.z
	# ])

func _manual_offset_search(skel: Skeleton3D, delta: float) -> void:
	if not _manual_search_enabled or _manual_search_converged:
		return
	if _rifle_right_grip == null or not is_instance_valid(_rifle_right_grip):
		return
	# Check RifleIdle
	var anim := _get_rifle_anim_player()
	if anim == null or not anim.is_playing():
		return
	if anim.current_animation != "external/RifleIdleExternal":
		_manual_search_timer = 0.0
		_manual_search_samples.clear()
		return
	_manual_search_timer += delta
	# Collect dist_RH samples
	var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var rh_pos := Vector3.ZERO
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var rg_pos := _rifle_right_grip.global_position
	var dist_rh := rh_pos.distance_to(rg_pos)
	_manual_search_samples.append(dist_rh)
	# Wait 2 seconds to accumulate samples
	if _manual_search_timer < 2.0:
		return
	# Average distance
	var avg_dist := 0.0
	for s in _manual_search_samples:
		avg_dist += s
	avg_dist /= float(_manual_search_samples.size())
	var n_samples := _manual_search_samples.size()
	_manual_search_samples.clear()
	_manual_search_timer = 0.0
	var axis_name: String = ["X", "Z", "Y"][_manual_search_axis]
	# print("[MANUAL_SEARCH] round=%d axis=%s phase=%d avg_dist_RH=%.6f weapon_offset_pos=(%.2f,%.2f,%.2f) samples=%d" % [
		# _manual_search_round, axis_name, _manual_search_phase, avg_dist,
		# weapon_offset_pos.x, weapon_offset_pos.y, weapon_offset_pos.z, n_samples
	# ])
	match _manual_search_phase:
		0: # Measure current
			_manual_search_best_dist = avg_dist
			_manual_search_best_pos = weapon_offset_pos
			_manual_search_current_dist = avg_dist
			# Try +step
			_manual_search_set_axis(_manual_search_axis, _manual_search_step)
			_manual_search_phase = 1
			# print("[MANUAL_SEARCH] Trying %s + %.1f" % [axis_name, _manual_search_step])
		1: # Measured +step
			if avg_dist < _manual_search_best_dist:
				_manual_search_best_dist = avg_dist
				_manual_search_best_pos = weapon_offset_pos
				# print("[MANUAL_SEARCH] %s + %.1f IMPROVED to %.6f" % [axis_name, _manual_search_step, avg_dist])
				# Try larger step in same direction
				_manual_search_set_axis(_manual_search_axis, _manual_search_step * 2.0)
				_manual_search_phase = 4 # continue in same direction
			else:
				pass # print("[MANUAL_SEARCH] %s + %.1f did NOT improve (%.6f >= %.6f)" % [axis_name, _manual_search_step, avg_dist, _manual_search_best_dist])
				# Revert and try -step
				weapon_offset_pos = _manual_search_best_pos
				_manual_search_set_axis(_manual_search_axis, -_manual_search_step)
				_manual_search_phase = 2
				# print("[MANUAL_SEARCH] Trying %s - %.1f" % [axis_name, _manual_search_step])
		2: # Measured -step
			if avg_dist < _manual_search_best_dist:
				_manual_search_best_dist = avg_dist
				_manual_search_best_pos = weapon_offset_pos
				# print("[MANUAL_SEARCH] %s - %.1f IMPROVED to %.6f" % [axis_name, _manual_search_step, avg_dist])
				# Try larger step in same direction
				_manual_search_set_axis(_manual_search_axis, -_manual_search_step * 2.0)
				_manual_search_phase = 5 # continue in same direction
			else:
				pass # print("[MANUAL_SEARCH] %s - %.1f did NOT improve (%.6f >= %.6f)" % [axis_name, _manual_search_step, avg_dist, _manual_search_best_dist])
				# Revert to best, move to next axis
				weapon_offset_pos = _manual_search_best_pos
				_manual_search_next_axis()
		4: # Continuing +direction with larger step
			if avg_dist < _manual_search_best_dist:
				_manual_search_best_dist = avg_dist
				_manual_search_best_pos = weapon_offset_pos
				# print("[MANUAL_SEARCH] %s + larger IMPROVED to %.6f" % [axis_name, avg_dist])
				# Keep going
				_manual_search_set_axis(_manual_search_axis, _manual_search_step)
				_manual_search_phase = 4
			else:
				pass # print("[MANUAL_SEARCH] %s + larger did NOT improve, reverting" % axis_name)
				weapon_offset_pos = _manual_search_best_pos
				_manual_search_next_axis()
		5: # Continuing -direction with larger step
			if avg_dist < _manual_search_best_dist:
				_manual_search_best_dist = avg_dist
				_manual_search_best_pos = weapon_offset_pos
				# print("[MANUAL_SEARCH] %s - larger IMPROVED to %.6f" % [axis_name, avg_dist])
				# Keep going
				_manual_search_set_axis(_manual_search_axis, -_manual_search_step)
				_manual_search_phase = 5
			else:
				pass # print("[MANUAL_SEARCH] %s - larger did NOT improve, reverting" % axis_name)
				weapon_offset_pos = _manual_search_best_pos
				_manual_search_next_axis()
	# Check convergence
	if _manual_search_best_dist < 0.02:
		weapon_offset_pos = _manual_search_best_pos
		_manual_search_converged = true
		# print("[MANUAL_SEARCH] CONVERGED! dist_RH=%.6f < 0.02" % _manual_search_best_dist)
		# print("[MANUAL_SEARCH] FINAL weapon_offset_pos = Vector3(%.4f, %.4f, %.4f)" % [weapon_offset_pos.x, weapon_offset_pos.y, weapon_offset_pos.z])
		# Log all distances
		var lh_bone2 := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
		var lh_pos2 := Vector3.ZERO
		if not lh_bone2.is_empty():
			var lh_idx2 := skel.find_bone(lh_bone2)
			if lh_idx2 >= 0:
				lh_pos2 = (skel.global_transform * skel.get_bone_global_pose(lh_idx2)).origin
		var re_bone2 := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
		var re_pos2 := Vector3.ZERO
		if not re_bone2.is_empty():
			var re_idx2 := skel.find_bone(re_bone2)
			if re_idx2 >= 0:
				re_pos2 = (skel.global_transform * skel.get_bone_global_pose(re_idx2)).origin
		# print("[MANUAL_SEARCH] dist_RH=%.4f dist_LH=%.4f dist_stock_elbow=%.4f" % [
			# _manual_search_best_dist,
			# lh_pos2.distance_to(_rifle_left_hand_grip.global_position),
			# re_pos2.distance_to(_rifle_stock_ref.global_position)
		# ])

func _manual_search_set_axis(axis: int, value: float) -> void:
	match axis:
		0: weapon_offset_pos.x += value
		1: weapon_offset_pos.z += value
		2: weapon_offset_pos.y += value

func _manual_search_next_axis() -> void:
	_manual_search_axis += 1
	_manual_search_phase = 0
	_manual_search_round += 1
	if _manual_search_axis > 2:
		# All axes done, do another round with smaller step
		_manual_search_axis = 0
		_manual_search_step *= 0.5
		if _manual_search_step < 0.1:
			_manual_search_step = 0.1
		# print("[MANUAL_SEARCH] Starting new round with step=%.2f" % _manual_search_step)
	# print("[MANUAL_SEARCH] Best so far: dist_RH=%.6f pos=(%.2f,%.2f,%.2f)" % [
		# _manual_search_best_dist, _manual_search_best_pos.x, _manual_search_best_pos.y, _manual_search_best_pos.z
	# ])

func _log_ik_calibration(skel: Skeleton3D, influence: float) -> void:
	# Left hand position
	var lh_bone := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	var lh_pos := Vector3.ZERO
	if not lh_bone.is_empty():
		var lh_idx := skel.find_bone(lh_bone)
		if lh_idx >= 0:
			lh_pos = (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	# Left elbow position
	var le_bone := _resolve_bone_name_safe("mixamorig:LeftForeArm", skel)
	var le_pos := Vector3.ZERO
	if not le_bone.is_empty():
		var le_idx := skel.find_bone(le_bone)
		if le_idx >= 0:
			le_pos = (skel.global_transform * skel.get_bone_global_pose(le_idx)).origin
	# LeftHandGrip position
	var lgrip_pos := _rifle_left_hand_grip.global_position
	# Right hand position
	var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
	var rh_pos := Vector3.ZERO
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	# RightGrip position
	var rgrip_pos := _rifle_right_grip.global_position
	# Distances
	var dist_lh := lh_pos.distance_to(lgrip_pos)
	var dist_rh := rh_pos.distance_to(rgrip_pos)
	# Check if elbow is inside torso (rough check: elbow x close to spine x)
	var spine_bone := _resolve_bone_name_safe("mixamorig:Spine", skel)
	var spine_pos := Vector3.ZERO
	if not spine_bone.is_empty():
		var spine_idx := skel.find_bone(spine_bone)
		if spine_idx >= 0:
			spine_pos = (skel.global_transform * skel.get_bone_global_pose(spine_idx)).origin
	var elbow_near_torso := le_pos.distance_to(spine_pos) < 0.15
	# Pole position
	var pole_pos := _rifle_left_elbow_pole.global_position
	# IK target position
	var ik_target_pos := _rifle_left_hand_grip.global_position
	# print("[IK_CAL] influence=%.2f | LH=(%.3f,%.3f,%.3f) LGrip=(%.3f,%.3f,%.3f) IKTarget=(%.3f,%.3f,%.3f) dist_LH=%.4f | RH_dist=%.4f | elbow=(%.3f,%.3f,%.3f) near_torso=%s | pole=(%.3f,%.3f,%.3f)" % [
		# influence,
		# lh_pos.x, lh_pos.y, lh_pos.z,
		# lgrip_pos.x, lgrip_pos.y, lgrip_pos.z,
		# ik_target_pos.x, ik_target_pos.y, ik_target_pos.z,
		# dist_lh,
		# dist_rh,
		# le_pos.x, le_pos.y, le_pos.z,
		# str(elbow_near_torso),
		# pole_pos.x, pole_pos.y, pole_pos.z
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
	for key in _rifle_debug_spheres.keys():
		var sphere: MeshInstance3D = _rifle_debug_spheres[key]
		if sphere != null and is_instance_valid(sphere):
			sphere.queue_free()
	_rifle_debug_spheres.clear()

func _setup_rifle_left_arm_ik(skel: Skeleton3D, target: Node3D) -> void:
	var upper_arm := _resolve_bone_name_safe("mixamorig:LeftArm", skel)
	var forearm := _resolve_bone_name_safe("mixamorig:LeftForeArm", skel)
	var left_hand := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	if upper_arm.is_empty() or left_hand.is_empty():
		pass # print("[RIFLE_IK_SETUP] FAILED: missing bones")
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
	# print("[RIFLE_IK_SETUP] SUCCESS: active=", _rifle_left_arm_ik.active, " target=", target_path, " pole=", pole_path, " bones=", upper_arm, "/", forearm, "/", left_hand)

func _setup_rifle_right_arm_ik(skel: Skeleton3D, target: Node3D) -> void:
	var upper_arm := _resolve_bone_name_safe("mixamorig:RightArm", skel)
	var forearm := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
	var right_hand := _resolve_bone_name_safe("mixamorig:RightHand", skel)
	if upper_arm.is_empty() or right_hand.is_empty():
		pass # print("[RIFLE_IK_SETUP] FAILED: missing right arm bones")
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
	# print("[RIFLE_IK_SETUP] RIGHT SUCCESS: active=", _rifle_right_arm_ik.active, " target=", skel.get_path_to(target), " bones=", upper_arm, "/", forearm, "/", right_hand)

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
	# print("[AUTO_ALIGN] Iteracion %d (muestras=%d)" % [_auto_align_iteration, _auto_align_samples.size()])
	# print("[AUTO_ALIGN] Error culata-codo = %.6f m (objetivo < 0.05)" % dist_stock)
	# print("[AUTO_ALIGN] Error mano izq-grip = %.6f m (objetivo < 0.03)" % dist_left)
	# print("[AUTO_ALIGN] Error mano der-grip = %.6f m (objetivo < 0.02)" % dist_right)
	# Check convergence with user-specified thresholds
	if dist_stock < 0.05 and dist_left < 0.03 and dist_right < 0.02:
		pass # print("[AUTO_ALIGN] CONVERGIDO! Todos los errores dentro de tolerancia")
		# print("[AUTO_ALIGN] weapon_offset_pos = %s" % str(weapon_offset_pos))
		# print("[AUTO_ALIGN] StockRef = %s (FIJO)" % str(_rifle_stock_ref.position))
		# print("[AUTO_ALIGN] RightGrip = %s (FIJO)" % str(_rifle_right_grip.position))
		# print("[AUTO_ALIGN] LeftGrip = %s (FIJO)" % str(_rifle_left_hand_grip.position))
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
	# print("[AUTO_ALIGN] Ajustando weapon_offset_pos:")
	# print("[AUTO_ALIGN] weapon_offset_pos = Vector3(%.4f, %.4f, %.4f)" % [weapon_offset_pos.x, weapon_offset_pos.y, weapon_offset_pos.z])
	# print("[AUTO_ALIGN] Markers FIJOS: StockRef=%s RightGrip=%s LeftGrip=%s" % [str(_rifle_stock_ref.position), str(_rifle_right_grip.position), str(_rifle_left_hand_grip.position)])
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

func _create_rifle_debug_spheres() -> void:
	var colors := {
		"right_grip": Color.RED,
		"char_right_hand": Color(0.0, 1.0, 0.0),
		"stock_ref": Color.YELLOW,
		"shoulder_target": Color(1.0, 0.5, 0.0),
		"muzzle": Color.ORANGE,
		"aim_target": Color.CYAN,
		"left_hand_grip": Color(0.0, 1.0, 1.0),
		"left_elbow_pole": Color(1.0, 0.0, 1.0),
	}
	for key in colors:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = colors[key]
		mat.emission_enabled = true
		mat.emission = colors[key]
		mat.emission_energy_multiplier = 1.0
		mat.no_depth_test = true
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var sphere := MeshInstance3D.new()
		var is_char: bool = key.begins_with("char_") or key.ends_with("_target")
		var sm := SphereMesh.new()
		sm.radius = 0.06 if is_char else 0.04
		sm.height = 0.12 if is_char else 0.08
		sphere.mesh = sm
		sphere.material_override = mat
		sphere.name = "DebugSphere_" + key
		sphere.top_level = true
		get_tree().current_scene.add_child(sphere)
		_rifle_debug_spheres[key] = sphere

func _update_rifle_debug_spheres() -> void:
	if _rifle_debug_spheres.is_empty():
		return
	if _rifle_right_grip != null and is_instance_valid(_rifle_right_grip):
		(_rifle_debug_spheres.get("right_grip") as MeshInstance3D).global_position = _rifle_right_grip.global_position
	if _rifle_stock_ref != null and is_instance_valid(_rifle_stock_ref):
		(_rifle_debug_spheres.get("stock_ref") as MeshInstance3D).global_position = _rifle_stock_ref.global_position
	if _rifle_muzzle != null and is_instance_valid(_rifle_muzzle):
		(_rifle_debug_spheres.get("muzzle") as MeshInstance3D).global_position = _rifle_muzzle.global_position
	if _rifle_shoulder_target != null and is_instance_valid(_rifle_shoulder_target):
		(_rifle_debug_spheres.get("shoulder_target") as MeshInstance3D).global_position = _rifle_shoulder_target.global_position
	if _rifle_aim_target != null and is_instance_valid(_rifle_aim_target):
		(_rifle_debug_spheres.get("aim_target") as MeshInstance3D).global_position = _rifle_aim_target.global_position
	if _rifle_left_hand_grip != null and is_instance_valid(_rifle_left_hand_grip):
		(_rifle_debug_spheres.get("left_hand_grip") as MeshInstance3D).global_position = _rifle_left_hand_grip.global_position
	if _rifle_left_elbow_pole != null and is_instance_valid(_rifle_left_elbow_pole):
		(_rifle_debug_spheres.get("left_elbow_pole") as MeshInstance3D).global_position = _rifle_left_elbow_pole.global_position
	# Character right hand
	var skel := _spine_skeleton if _spine_skeleton != null and is_instance_valid(_spine_skeleton) else _find_skeleton(third_person_model)
	if skel != null:
		var rh_bone := _resolve_bone_name_safe(right_hand_bone_name, skel)
		if not rh_bone.is_empty():
			var rh_idx := skel.find_bone(rh_bone)
			if rh_idx >= 0:
				(_rifle_debug_spheres.get("char_right_hand") as MeshInstance3D).global_position = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin

func _update_rifle_debug_label(skel: Skeleton3D) -> void:
	# Right hand → RightGrip distance
	var rh_bone := _resolve_bone_name_safe("mixamorig:RightHand", skel)
	var rh_pos := Vector3.ZERO
	if not rh_bone.is_empty():
		var rh_idx := skel.find_bone(rh_bone)
		if rh_idx >= 0:
			rh_pos = (skel.global_transform * skel.get_bone_global_pose(rh_idx)).origin
	var rg_pos := _rifle_right_grip.global_position if _rifle_right_grip != null else Vector3.ZERO
	var grip_dist := rh_pos.distance_to(rg_pos)
	# Left hand → LeftHandGrip distance
	var lh_bone := _resolve_bone_name_safe("mixamorig:LeftHand", skel)
	var lh_pos := Vector3.ZERO
	if not lh_bone.is_empty():
		var lh_idx := skel.find_bone(lh_bone)
		if lh_idx >= 0:
			lh_pos = (skel.global_transform * skel.get_bone_global_pose(lh_idx)).origin
	var lg_pos := _rifle_left_hand_grip.global_position if _rifle_left_hand_grip != null else Vector3.ZERO
	var ik_dist := lh_pos.distance_to(lg_pos)
	# Stock → right elbow distance
	var re_bone := _resolve_bone_name_safe("mixamorig:RightForeArm", skel)
	var re_pos := Vector3.ZERO
	if not re_bone.is_empty():
		var re_idx := skel.find_bone(re_bone)
		if re_idx >= 0:
			re_pos = (skel.global_transform * skel.get_bone_global_pose(re_idx)).origin
	var stock_pos := _rifle_stock_ref.global_position if _rifle_stock_ref != null else Vector3.ZERO
	var stock_dist := stock_pos.distance_to(re_pos)
	# print("[RIFLE_DEBUG] grip_dist=%.4f ik_dist=%.4f stock_elbow=%.4f ik_weight=%.2f ik_active=%s" % [grip_dist, ik_dist, stock_dist, _rifle_current_ik_weight, _rifle_left_arm_ik != null and is_instance_valid(_rifle_left_arm_ik) and _rifle_left_arm_ik.active])
	# print("[RIFLE_DEBUG] char_right_elbow=%s stock=%s | char_left_hand=%s left_grip=%s | rh_grip=%s" % [str(re_pos), str(stock_pos), str(lh_pos), str(lg_pos), str(rh_pos)])

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

func _build_third_person_flashlight() -> void:
	pass

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

func _build_third_person_bandage() -> void:
	pass

func _build_third_person_battery() -> void:
	pass

func _build_third_person_resource(item_name: String) -> void:
	if item_name == "Tronco" or item_name == "Madera" or item_name == "Ramas":
		_try_add_model_to_parent(third_person_hand_item_root, REAL_WOOD_MODEL, "ThirdPersonWood", Vector3(0, 0, -0.18), Vector3(82, 0, 8), Vector3.ONE * 0.5)
	elif item_name == "Piedra":
		_try_add_model_to_parent(third_person_hand_item_root, REAL_STONE_MODEL, "ThirdPersonStone", Vector3(0, 0, -0.12), Vector3(8, 18, 6), Vector3.ONE * 0.5)

func _build_third_person_seed_bag() -> void:
	pass

func _build_third_person_clothing_bundle() -> void:
	pass

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

func _build_third_person_pack() -> void:
	pass

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
	var target_sink := -0.24 * _water_depth if is_in_water else 0.0
	_water_sink = lerp(_water_sink, target_sink, delta * 5.0)
	var target_position := Vector3(side_bob, base_height + vertical_bob, 0.0)
	var third_height := (1.55 if is_crouching else THIRD_PERSON_CAMERA_POS.y) + vertical_bob * 0.45
	target_position = Vector3(side_bob * 0.45, third_height, THIRD_PERSON_CAMERA_POS.z)
	target_position.y += _water_sink
	if _is_aiming:
		# First-person eye position looking down the rifle barrel.
		# Height adapts to stance.
		var aim_height: float = 1.65
		if is_crouching:
			aim_height = 1.25
		elif is_prone:
			aim_height = 0.45
		aim_height += vertical_bob * 0.2
		# Position the camera at the player's eye level, slightly forward
		target_position = Vector3(0.0, aim_height + _water_sink, 0.15)
		camera.position = camera.position.lerp(target_position, delta * 18.0)
		# Use _pitch for vertical aim control (mouse up/down)
		camera.rotation.x = _pitch
	else:
		camera.position = camera.position.lerp(target_position, delta * 10.0)
		camera.rotation.x = _pitch
	camera.rotation.z = lerp_angle(camera.rotation.z, roll, delta * 8.0)
	_update_third_person_animation(moving, delta)

func _update_third_person_animation(moving: bool, delta: float) -> void:
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	var base_rotation := Vector3(0.0, 180.0, 0.0) if character == third_person_model else Vector3.ZERO
	var bob: float = abs(sin(_walk_bob)) * 0.08 * _walk_intensity if moving else 0.0
	var sway: float = sin(_walk_bob) * 4.5 * _walk_intensity if moving else 0.0
	var crouch_lift := 0.25 if is_crouching else 0.0
	var target_y := third_person_ground_offset + bob + crouch_lift + _water_sink * 0.55
	if third_person_action_timer > 0.0 and is_custom_character and third_person_model != null:
		var skel := _find_skeleton(third_person_model)
		if skel != null:
			skel.force_update_all_bone_transforms()
			var min_foot_model_y := 1000000.0
			for i in range(skel.get_bone_count()):
				var bn := skel.get_bone_name(i)
				if bn.find("Foot") >= 0 or bn.find("Toe") >= 0:
					var bone_world := skel.global_transform * skel.get_bone_global_pose(i).origin
					var bone_model := third_person_model.to_local(bone_world)
					if bone_model.y < min_foot_model_y:
						min_foot_model_y = bone_model.y
			if min_foot_model_y < 999999.0:
				var rest_foot_y := -third_person_ground_offset + 0.06
				target_y = third_person_ground_offset + (rest_foot_y - min_foot_model_y)
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
		if is_prone and third_person_action_timer <= 0.0 and not _rifle_prone_animation.is_empty():
			if third_person_animation_player.current_animation != _rifle_prone_animation:
				third_person_animation_player.play(_rifle_prone_animation, 0.1)
			third_person_animation_player.speed_scale = 1.0
			return
		if is_sitting and third_person_action_timer <= 0.0:
			var sit_anim := _rifle_sit_animation if _has_rifle_equipped() and not _rifle_sit_animation.is_empty() else third_person_sit_animation
			if not sit_anim.is_empty():
				if third_person_animation_player.current_animation != sit_anim:
					third_person_animation_player.play(sit_anim, 0.1)
				third_person_animation_player.speed_scale = 1.0
				return
		var target_animation := ""
		var low_health: bool = stats != null and stats.health <= 30.0 and not third_person_low_health_animation.is_empty()
		# Update rifle equipped state
		_has_rifle = _has_rifle_equipped()
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
			elif _turn_input < -2.0 and not _rifle_left_turn_animation.is_empty():
				target_animation = _rifle_left_turn_animation
			elif _turn_input > 2.0 and not _rifle_right_turn_animation.is_empty():
				target_animation = _rifle_right_turn_animation
			elif is_crouching and not third_person_sneak_animation.is_empty():
				target_animation = third_person_sneak_animation
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
			pass # print("[RIFLE_VERIFY] requested=", target_animation, " active_before=", third_person_animation_player.current_animation, " playing=", third_person_animation_player.is_playing(), " rifle=", _has_rifle)
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

func toggle_anim_debug() -> void:
	_anim_debug_enabled = not _anim_debug_enabled
	if _anim_debug_enabled:
		_create_anim_debug_label()
	else:
		if _anim_debug_label != null and is_instance_valid(_anim_debug_label):
			_anim_debug_label.queue_free()
		_anim_debug_label = null

func _create_anim_debug_label() -> void:
	if _anim_debug_label != null and is_instance_valid(_anim_debug_label):
		return
	var label := Label.new()
	label.name = "AnimDebugLabel"
	label.position = Vector2(10, 10)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 0.3))
	label.z_index = 100
	get_tree().current_scene.add_child(label)
	_anim_debug_label = label

func _update_anim_debug_label() -> void:
	if _anim_debug_label == null or not is_instance_valid(_anim_debug_label):
		return
	var lines := [
		"== Animation Debug ==",
		"has_rifle: %s" % str(_has_rifle),
		"is_aiming: %s" % str(_is_aiming),
		"is_reloading: %s" % str(_is_reloading),
		"is_firing: %s" % str(_is_firing),
		"is_crouching: %s" % str(is_crouching),
		"is_sprinting: %s" % str(is_sprinting),
		"moving: %s" % str(velocity.length() > 0.5),
		"current_anim: %s" % _get_current_anim(),
		"rifle_idle: %s" % str(not _rifle_idle_animation.is_empty()),
		"rifle_aim: %s" % str(not _rifle_aim_idle_animation.is_empty()),
		"rifle_walk: %s" % str(not _rifle_walk_animation.is_empty()),
		"rifle_run: %s" % str(not _rifle_run_animation.is_empty()),
		"rifle_fire: %s" % str(not _rifle_fire_animation.is_empty()),
	]
	_anim_debug_label.text = "\n".join(lines)

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
	query.exclude = [self]
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider", null)

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
	for node in get_tree().get_nodes_in_group("world_actions"):
		if not node is Node3D:
			continue
		if node.get("depleted") == true and node.get("repeatable") == false:
			continue
		var action := node as Node3D
		var to_action := action.global_position - eye
		var distance := to_action.length()
		if distance > 4.2:
			continue
		var flat := Vector3(to_action.x, 0.0, to_action.z)
		if flat.length() <= 0.05:
			continue
		var facing := forward.dot(flat.normalized())
		if facing < 0.42:
			continue
		var score := distance - facing * 1.6
		if score < best_score:
			best_score = score
			best = node
	return best

func _toggle_flashlight() -> void:
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
	var fwd := -global_transform.basis.z.normalized()
	# Check wildlife
	for node in get_tree().get_nodes_in_group("wildlife"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var animal := node as Node3D
		if animal == self:
			continue
		var d := global_position.distance_to(animal.global_position)
		if d > closest_dist:
			continue
		var dir := (animal.global_position - global_position).normalized()
		if fwd.dot(dir) < 0.3:
			continue
		closest_target = animal
		closest_dist = d
	# Check NPCs (NPCController class)
	for node in get_tree().get_nodes_in_group("npc"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var npc_node := node as Node3D
		var d := global_position.distance_to(npc_node.global_position)
		if d > closest_dist:
			continue
		var dir := (npc_node.global_position - global_position).normalized()
		if fwd.dot(dir) < 0.3:
			continue
		closest_target = npc_node
		closest_dist = d
	# Check server proxies (net_player_proxy group)
	for node in get_tree().get_nodes_in_group("net_player_proxy"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		var proxy_node := node as Node3D
		var d := global_position.distance_to(proxy_node.global_position)
		if d > closest_dist:
			continue
		var dir := (proxy_node.global_position - global_position).normalized()
		if fwd.dot(dir) < 0.3:
			continue
		closest_target = proxy_node
		closest_dist = d
	# Check remote player avatars (puppets on clients)
	var scene := get_tree().current_scene
	if scene != null and scene.get("remote_players") != null:
		for pid in scene.remote_players.keys():
			var rp: Node3D = scene.remote_players[pid]
			if not is_instance_valid(rp):
				continue
			var d := global_position.distance_to(rp.global_position)
			if d > closest_dist:
				continue
			var dir := (rp.global_position - global_position).normalized()
			if fwd.dot(dir) < 0.3:
				continue
			closest_target = rp
			closest_dist = d
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
	else:
		pass # print("DEBUG CROSSHAIR: main=", main, " hud=", main.hud if main != null else "null", " is_rifle=", is_rifle)

func _toggle_aim() -> void:
	_is_aiming = not _is_aiming
	if _is_aiming:
		_create_scope_overlay()
		if camera != null:
			camera.fov = 20.0
		mouse_sensitivity = 0.0008
		if third_person_model != null:
			third_person_model.visible = false
	else:
		_remove_scope_overlay()
		if camera != null:
			camera.fov = _camera_fov
		mouse_sensitivity = 0.0025
		if third_person_model != null:
			third_person_model.visible = true

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
	var ray_origin := camera.project_ray_origin(aim_point)
	var ray_dir := camera.project_ray_normal(aim_point)
	# Realistic spread: wider when moving, narrower when crouching/aiming
	var spread_deg := 2.0
	if is_crouching:
		spread_deg = 0.5
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
	# Bullet drop: apply gravity over the trajectory
	var hit_dist := RIFLE_RANGE
	var space_state := get_world_3d().direct_space_state
	# First ray to find hit distance
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * RIFLE_RANGE)
	var exclude_arr: Array = [self.get_rid()]
	for child in find_children("*", "CollisionObject3D", true, false):
		exclude_arr.append(child.get_rid())
	query.exclude = exclude_arr
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result := space_state.intersect_ray(query)
	var hit_pos: Vector3 = ray_origin + ray_dir * RIFLE_RANGE
	if not result.is_empty():
		hit_dist = ray_origin.distance_to(result["position"])
		hit_pos = result["position"]
	# Apply bullet drop: offset the hit point downward based on distance
	var bullet_drop := 0.5 * 9.8 * (hit_dist / 200.0) * (hit_dist / 200.0)
	# Re-cast with adjusted target if distance is significant
	if hit_dist > 10.0 and bullet_drop > 0.05:
		var adjusted_target := ray_origin + ray_dir * hit_dist + Vector3(0, -bullet_drop, 0)
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
		return
	var collider = result["collider"]
	# print("DEBUG SHOOT: hit=", collider.name, " class=", collider.get_class(), " pos=", hit_pos, " dist=", hit_dist)
	# Damage falloff: full damage up to 50m, linear falloff to 20% at max range
	var damage := 80.0
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
			pass # print("DEBUG SHOOT: target=", target_node.name, " is_wildlife=", target_node.is_in_group("wildlife"))
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

func _quick_use_held_item() -> void:
	pass

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

func _debug_drop_and_screenshot() -> void:
	if not is_custom_character or is_puppet:
		return
	# Drop all default clothing to show nude state
	for slot in _equipped_slots.keys():
		var item := str(_equipped_slots[slot])
		if not item.is_empty():
			unequip_clothing(item)
	# Equip only Pantalones to verify legs
	await get_tree().create_timer(0.2).timeout
	equip_clothing("Pantalones")
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var viewport_texture := get_viewport().get_texture()
	var img := viewport_texture.get_image()
	if img != null and img.get_width() > 0:
		var path := ProjectSettings.globalize_path("res://godot_shot.png")
		img.save_png(path)
		print("[DEBUG-SCREENSHOT] saved to ", path)
	else:
		print("[DEBUG-SCREENSHOT] image was null or empty")
