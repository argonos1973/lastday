extends CharacterBody3D
class_name PlayerController

const SurvivalStatsScript = preload("res://scripts/SurvivalStats.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const ItemScript = preload("res://scripts/Item.gd")
const InteractionRaycastScript = preload("res://scripts/InteractionRaycast.gd")
const PlayerEquipmentScript = preload("res://scripts/PlayerEquipment.gd")
const PlayerHandsScript = preload("res://scripts/PlayerHands.gd")
const REAL_KNIFE_MODEL := "res://assets/external/realistic/root_glb/knife.glb"
const REAL_AXE_MODEL := "res://assets/external/realistic/root_glb/axe_survival.glb"
const REAL_HOE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-hoe.glb"
const REAL_SHOVEL_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-shovel.glb"
const REAL_HAMMER_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-hammer.glb"
const REAL_PICKAXE_MODEL := "res://assets/external/kenney_survival_kit/Models/GLB format/tool-pickaxe.glb"
const REAL_BACKPACK_MODEL := "res://assets/external/realistic/root_glb/low_poly_game_ready_military_tactical_backpack.glb"
const POLY_LIFE_JACKET_MODEL := "res://assets/external/polyhaven/life_jacket/life_jacket_1k.gltf"
const POLY_FISHERMANS_HAT_MODEL := "res://assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf"
const POLY_RUBBER_BOOTS_MODEL := "res://assets/external/polyhaven/rubber_boots/rubber_boots_1k.gltf"
const POLY_GARDEN_GLOVES_MODEL := "res://assets/external/polyhaven/garden_gloves_01/garden_gloves_01_1k.gltf"
const ROOT_VEST_MODEL := "res://assets/external/realistic/root_glb/vest_armor_holster_lowpoly_gameready_pack.glb"
# Wearable visuals placed on the body relative to its measured bounding box, so
# they fit regardless of the character model's scale/proportions.
#   frac_y: anchor height as a fraction of body height (0 = feet, 1 = head top)
#   size:   item height as a fraction of body height
#   forward: shift toward the front of the body (fraction of depth)
#   align:  "center" (default) or "bottom"; "strip" hides duplicate variant meshes
const CLOTHING_VISUALS := {
	"Chaleco salvavidas": {"path": POLY_LIFE_JACKET_MODEL, "frac_y": 0.70, "size": 0.30, "yaw": 180.0, "forward": 0.05},
	"Chaleco tactico": {"path": ROOT_VEST_MODEL, "frac_y": 0.70, "size": 0.30, "yaw": 0.0, "forward": 0.05},
	"Sombrero de pescador": {"path": POLY_FISHERMANS_HAT_MODEL, "frac_y": 0.96, "size": 0.12, "yaw": 0.0, "align": "bottom"},
	"Botas de goma": {"path": POLY_RUBBER_BOOTS_MODEL, "frac_y": 0.0, "size": 0.20, "yaw": 0.0, "align": "bottom", "strip": ["dirty", "dirt"]},
	"Guantes de trabajo": {"path": POLY_GARDEN_GLOVES_MODEL, "frac_y": 0.45, "size": 0.09, "yaw": 0.0, "forward": 0.2}
}
# Adapted character (Mixamo body + survival clothing skinned to the same rig).
# Loaded first so the deformable survival garments are available to wear.
const ADAPTED_PLAYER_MODEL := "res://assets/characters/adapted/player_with_clothes.glb"

# Survival garments that are skinned to the Mixamo rig inside ADAPTED_PLAYER_MODEL.
# item_name -> mesh node to show + Mixamo default meshes to hide while worn.
const SURVIVAL_CLOTHING := {
	"Chaqueta survival": {"mesh": "cloth_torso", "hides": ["Tops"]},
	"Vaqueros survival": {"mesh": "cloth_legs", "hides": ["Bottoms"]},
	"Guantes survival": {"mesh": "cloth_hands", "hides": []},
	"Botas survival": {"mesh": "cloth_feet", "hides": ["Shoes"]},
}

const THIRD_PERSON_MODEL_CANDIDATES := [
	"res://assets/characters/adapted/player_with_clothes.glb",
	"res://inicio.glb",
	"res://walking.glb",
	"res://Walking.glb",
	"res://untitled.glb",
	"res://Walking.gltf",
	"res://Walking.fbx",
	"res://assets/external/quaternius_zombie_apocalypse/Characters/glTF/Characters_Matt_SingleWeapon.gltf"
]
const THIRD_PERSON_RUN_ANIMATION_SOURCE := "res://correr.glb"
const THIRD_PERSON_IDLE_ANIMATION_SOURCE := "res://idle.glb"
const THIRD_PERSON_WALK_ANIMATION_SOURCE := "res://walking.glb"
const THIRD_PERSON_SNEAK_ANIMATION_SOURCE := "res://walking.glb"
const THIRD_PERSON_LEFT_TURN_ANIMATION_SOURCE := "res://leftturn.glb"
const THIRD_PERSON_RIGHT_TURN_ANIMATION_SOURCE := "res://rightturn.glb"
const THIRD_PERSON_PLANT_ANIMATION_SOURCE := "res://plantar.glb"
const THIRD_PERSON_GATHER_ANIMATION_SOURCE := "res://recoger.glb"
const THIRD_PERSON_FISH_ANIMATION_SOURCE := "res://Fishing Cast.glb"
const THIRD_PERSON_INTERACT_ANIMATION_SOURCE := "res://coger.glb"
const THIRD_PERSON_LOW_HEALTH_ANIMATION_SOURCE := "res://malo.glb"
const THIRD_PERSON_DYING_ANIMATION_SOURCE := "res://muerto.glb"
const THIRD_PERSON_EXTERNAL_RUN_ANIMATION := "RunExternal"
const THIRD_PERSON_EXTERNAL_IDLE_ANIMATION := "IdleExternal"
const THIRD_PERSON_EXTERNAL_WALK_ANIMATION := "WalkExternal"
const THIRD_PERSON_EXTERNAL_SNEAK_ANIMATION := "SneakExternal"
const THIRD_PERSON_EXTERNAL_LEFT_TURN_ANIMATION := "LeftTurnExternal"
const THIRD_PERSON_EXTERNAL_RIGHT_TURN_ANIMATION := "RightTurnExternal"
const THIRD_PERSON_EXTERNAL_PLANT_ANIMATION := "PlantExternal"
const THIRD_PERSON_EXTERNAL_GATHER_ANIMATION := "GatherExternal"
const THIRD_PERSON_EXTERNAL_FISH_ANIMATION := "FishExternal"
const THIRD_PERSON_EXTERNAL_INTERACT_ANIMATION := "InteractExternal"
const THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION := "LowHealthExternal"
const THIRD_PERSON_EXTERNAL_DYING_ANIMATION := "DyingExternal"
const THIRD_PERSON_CAMERA_POS := Vector3(0.0, 2.65, 5.15)
const THIRD_PERSON_DEFAULT_SCALE := 1.55
const MIXAMO_CHARACTER_SCALE := 0.72
const MIXAMO_GROUND_CORRECTION := 0.38
const BASE_CARRY_SLOTS := 8
const BASE_CARRY_WEIGHT := 12.0
const JACKET_CARRY_SLOTS := 4
const JACKET_CARRY_WEIGHT := 4.0
const SMALL_BACKPACK_SLOTS := 8
const SMALL_BACKPACK_WEIGHT := 10.0

signal prompt_changed(text: String)
signal notice(text: String)

@export var walk_speed := 4.0
@export var sprint_speed := 7.0
@export var crouch_speed := 2.0
@export var mouse_sensitivity := 0.0025
@export var interaction_distance := 0.5

var stats
var inventory
var equipment
var hands
var camera: Camera3D
var audio_listener: AudioListener3D
var raycast
var flashlight: SpotLight3D
var body_mesh: MeshInstance3D
var third_person_model: Node3D
var third_person_hand_item_root: Node3D
var third_person_back_item_root: Node3D
var _spine_skeleton: Skeleton3D = null
var _spine_bone_idx: int = -1
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
var third_person_left_turn_animation := ""
var third_person_right_turn_animation := ""
var third_person_plant_animation := ""
var third_person_gather_animation := ""
var third_person_fish_animation := ""
var third_person_interact_animation := ""
var third_person_low_health_animation := ""
var third_person_dying_animation := ""
var third_person_ground_offset := 0.0
var third_person_has_real_idle := false
var third_person_loaded_path := ""
var third_person_action_animation := ""
var third_person_action_timer := 0.0
var is_dead := false
var death_pose_time := 0.0
var is_sprinting := false
var is_crouching := false
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

var _pitch := 0.0
var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float
var _walk_bob := 0.0
var _walk_intensity := 0.0
var _turn_input := 0.0
var _water_depth := 0.0
var _water_sink := 0.0
var _water_notice_cooldown := 0.0
var _aim_screen_offset := Vector2.ZERO

func _ready() -> void:
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

	_create_body()
	_add_starting_items()
	_recalculate_carry_capacity()
	_select_default_held_item()
	_sync_held_item()
	_apply_view_mode()
	call_deferred("_capture_mouse")

func _input(event: InputEvent) -> void:
	if is_dead:
		return
	if event is InputEventMouseButton and event.pressed:
		_capture_mouse()
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_turn_input = clamp(event.relative.x, -80.0, 80.0)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-78.0), deg_to_rad(78.0))
		camera.rotation.x = _pitch
	if event.is_action_pressed("interact"):
		_interact()
	if event.is_action_pressed("flashlight"):
		_toggle_flashlight()
	if event.is_action_pressed("toggle_inventory"):
		notice.emit("Inventario alternado.")
	if event is InputEventKey and event.pressed and not event.echo:
		var inventory_index := _inventory_index_for_key(event.keycode)
		if inventory_index >= 0:
			held_index = inventory_index
			_use_inventory_index(inventory_index)
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
	var item = inventory.items[index]
	var item_name := str(item.item_name)
	var item_type := str(item.item_type)
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
	equipped_clothing = item_name
	# Survival garments are skinned to the Mixamo rig: just reveal the mesh so it
	# deforms with the animations. Everything else uses the legacy bbox visual.
	if SURVIVAL_CLOTHING.has(item_name):
		_wear_survival_clothing(item_name, true)
	else:
		_wear_clothing_visual(item_name)
	_recalculate_carry_capacity()
	_sync_held_item()
	if inventory != null:
		inventory.changed.emit()

func unequip_clothing(item_name: String) -> void:
	if SURVIVAL_CLOTHING.has(item_name):
		_wear_survival_clothing(item_name, false)
	if equipped_clothing == item_name:
		equipped_clothing = ""
	_recalculate_carry_capacity()
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
	var stack: Array = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if wanted.has(mi.name):
				_survival_cloth_nodes[mi.name] = mi
				mi.visible = false
			elif body_names.has(mi.name):
				_survival_body_nodes[mi.name] = mi
		for c in node.get_children():
			stack.append(c)

# Shows/hides a survival garment mesh and toggles the Mixamo default meshes it
# replaces (e.g. wearing the jacket hides the default Tops to avoid clipping).
func _wear_survival_clothing(item_name: String, worn: bool) -> void:
	if not SURVIVAL_CLOTHING.has(item_name):
		return
	var cfg: Dictionary = SURVIVAL_CLOTHING[item_name]
	var mi: MeshInstance3D = _survival_cloth_nodes.get(String(cfg["mesh"]))
	if mi != null:
		mi.visible = worn
	for h in cfg["hides"]:
		var bn: MeshInstance3D = _survival_body_nodes.get(String(h))
		if bn != null:
			bn.visible = not worn
	_worn_survival[item_name] = worn

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
	var node := _load_external_node3d(str(cfg["path"]))
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
	if inventory != null and inventory.has_item_name("Mochila pequena"):
		equipped_backpack = "Mochila pequena"
	_recalculate_carry_capacity()
	_sync_held_item()

func _recalculate_carry_capacity() -> void:
	if inventory == null:
		return
	var slots := BASE_CARRY_SLOTS
	var weight := BASE_CARRY_WEIGHT
	if not equipped_clothing.is_empty():
		slots += JACKET_CARRY_SLOTS
		weight += JACKET_CARRY_WEIGHT
	if not equipped_backpack.is_empty() or inventory.has_item_name("Mochila pequena"):
		slots += SMALL_BACKPACK_SLOTS
		weight += SMALL_BACKPACK_WEIGHT
	inventory.max_slots = slots
	inventory.max_weight = weight

func _physics_process(delta: float) -> void:
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
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_key_pressed(KEY_R) and not is_crouching and stats.energy > 4.0 and input_dir.length() > 0.1
	var speed := crouch_speed if is_crouching else (sprint_speed if is_sprinting else walk_speed)
	_update_water_state(delta)
	if is_in_water:
		speed = crouch_speed if is_crouching else walk_speed
		speed *= lerp(0.72, 0.48, _water_depth)
		is_sprinting = false

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	_update_walk_motion(delta, input_dir.length())
	_update_interaction_prompt()
	_update_flashlight(delta)
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

func _update_water_state(delta: float) -> void:
	_water_notice_cooldown = max(0.0, _water_notice_cooldown - delta)
	var river_depth := _query_river_depth()
	_water_depth = river_depth
	is_in_water = river_depth > 0.02
	if is_in_water:
		wetness = min(1.0, wetness + delta * (0.38 + river_depth * 0.55))
		stats.energy = max(0.0, stats.energy - delta * 0.018 * (0.8 + river_depth))
		stats.body_temperature = max(32.0, stats.body_temperature - delta * 0.010 * (0.5 + wetness + river_depth))
		stats.changed.emit()
		if _water_notice_cooldown <= 0.0:
			notice.emit("Te mojas. La ropa fria te roba calor.")
			_water_notice_cooldown = 8.0
	else:
		wetness = max(0.0, wetness - delta * 0.035)
		if wetness > 0.25:
			stats.body_temperature = max(32.0, stats.body_temperature - delta * 0.004 * wetness)
			stats.changed.emit()

func _query_river_depth() -> float:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("get_river_depth_at"):
		return float(scene.call("get_river_depth_at", global_position))
	return 0.0

func _create_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

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
	return

func _create_third_person_model() -> void:
	var character: Node3D = null
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
		var character_scale := MIXAMO_CHARACTER_SCALE if _is_mixamo_root_asset(third_person_loaded_path) else THIRD_PERSON_DEFAULT_SCALE
		character.scale = Vector3.ONE * character_scale
		add_child(character)
		third_person_model = character
		_hide_third_person_held_props(character)
		_hide_third_person_export_helpers(character)
		_init_survival_clothing(character)
		_create_third_person_item_slots()
		_setup_third_person_animation(character)
		_align_third_person_model_to_ground()
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
	_add_held_box(rig, "RigBackpack", Vector3(0.36, 0.50, 0.16), Vector3(0.0, 1.18, 0.18), Color(0.08, 0.12, 0.09), Vector3.ZERO)

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
	third_person_hand_item_root.position = Vector3(-0.38, 1.04, -0.16)
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
	_import_external_animation(THIRD_PERSON_IDLE_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_IDLE_ANIMATION)
	_import_external_animation(THIRD_PERSON_WALK_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_WALK_ANIMATION)
	_import_external_animation(THIRD_PERSON_RUN_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_RUN_ANIMATION)
	_import_external_animation(THIRD_PERSON_SNEAK_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_SNEAK_ANIMATION)
	_import_external_animation(THIRD_PERSON_LEFT_TURN_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_LEFT_TURN_ANIMATION)
	_import_external_animation(THIRD_PERSON_RIGHT_TURN_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_RIGHT_TURN_ANIMATION)
	_import_external_animation(THIRD_PERSON_PLANT_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_PLANT_ANIMATION)
	_import_external_animation(THIRD_PERSON_GATHER_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_GATHER_ANIMATION)
	_import_external_animation(THIRD_PERSON_FISH_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_FISH_ANIMATION)
	_import_external_animation(THIRD_PERSON_INTERACT_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_INTERACT_ANIMATION)
	_import_external_animation(THIRD_PERSON_LOW_HEALTH_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION)
	_import_external_animation(THIRD_PERSON_DYING_ANIMATION_SOURCE, THIRD_PERSON_EXTERNAL_DYING_ANIMATION)
	var names := third_person_animation_player.get_animation_list()
	for animation_name in names:
		var name_text := String(animation_name)
		var animation := third_person_animation_player.get_animation(animation_name)
		if animation != null:
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
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION):
		third_person_low_health_animation = "external/" + THIRD_PERSON_EXTERNAL_LOW_HEALTH_ANIMATION
	if third_person_animation_player.has_animation("external/" + THIRD_PERSON_EXTERNAL_DYING_ANIMATION):
		third_person_dying_animation = "external/" + THIRD_PERSON_EXTERNAL_DYING_ANIMATION
		var dying_animation := third_person_animation_player.get_animation(third_person_dying_animation)
		if dying_animation != null:
			dying_animation.loop_mode = Animation.LOOP_NONE
	if third_person_run_animation.is_empty():
		third_person_run_animation = third_person_walk_animation
	if third_person_sneak_animation.is_empty():
		third_person_sneak_animation = third_person_walk_animation
	if third_person_has_real_idle and not third_person_idle_animation.is_empty():
		third_person_animation_player.play(third_person_idle_animation)
	else:
		third_person_animation_player.stop()

func _import_external_animation(source_path: String, animation_name: String) -> void:
	if third_person_animation_player == null or not _resource_path_exists(source_path):
		return
	var source_scene := _load_external_node3d(source_path)
	if source_scene == null:
		return
	var source_player := _find_animation_player(source_scene)
	if source_player == null:
		source_scene.queue_free()
		return
	var source_names := source_player.get_animation_list()
	if source_names.is_empty():
		source_scene.queue_free()
		return
	var source_animation: Animation = null
	var best_track_count := 0
	for source_name in source_names:
		var candidate := source_player.get_animation(source_name)
		if candidate != null and candidate.get_track_count() > best_track_count:
			source_animation = candidate
			best_track_count = candidate.get_track_count()
	if source_animation != null:
		var copied_animation := source_animation.duplicate(true) as Animation
		copied_animation.loop_mode = Animation.LOOP_LINEAR
		copied_animation.step = 0.0166667
		_retarget_animation_to_character_skeleton(copied_animation)
		_remove_root_motion_drift(copied_animation)
		var library: AnimationLibrary
		if third_person_animation_player.has_animation_library("external"):
			library = third_person_animation_player.get_animation_library("external")
		else:
			library = AnimationLibrary.new()
			third_person_animation_player.add_animation_library("external", library)
		if library.has_animation(animation_name):
			library.remove_animation(animation_name)
		library.add_animation(animation_name, copied_animation)
	source_scene.queue_free()

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

func _remove_root_motion_drift(animation: Animation) -> void:
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
		var lock_x := is_root_hips or absf(drift.x) > 2.0
		var lock_y := absf(drift.y) > 2.0
		var lock_z := is_root_hips or absf(drift.z) > 2.0
		if not lock_x and not lock_y and not lock_z:
			continue
		for key_index in range(key_count):
			var value: Variant = animation.track_get_key_value(track_index, key_index)
			if value is Vector3:
				var locked_position := value as Vector3
				if lock_x:
					locked_position.x = first_position.x
				if lock_y:
					locked_position.y = first_position.y
				if lock_z:
					locked_position.z = first_position.z
				animation.track_set_key_value(track_index, key_index, locked_position)

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
		"interact", "chop":
			target_animation = third_person_interact_animation
	if target_animation.is_empty():
		return
	third_person_action_animation = target_animation
	third_person_action_timer = duration
	third_person_animation_player.play(target_animation, 0.08)

func die() -> void:
	if is_dead:
		return
	is_dead = true
	death_pose_time = 0.0
	_apply_view_mode()
	flashlight.visible = false
	velocity = Vector3.ZERO
	stats.health = 0.0
	stats.dead = true
	stats.changed.emit()
	if third_person_animation_player != null and not third_person_dying_animation.is_empty():
		third_person_animation_player.speed_scale = 1.0
		third_person_animation_player.play(third_person_dying_animation, 0.05)
	elif third_person_animation_player != null:
		third_person_animation_player.stop()

func _update_death_pose(delta: float) -> void:
	death_pose_time += delta
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	if third_person_animation_player != null and not third_person_dying_animation.is_empty() and death_pose_time < 0.95:
		character.position = character.position.lerp(Vector3(0.0, max(0.04, third_person_ground_offset * 0.18) + _water_sink * 0.25, 0.0), delta * 8.0)
		return
	if third_person_animation_player != null and third_person_animation_player.is_playing():
		third_person_animation_player.stop()
	var fall_ratio: float = clamp((death_pose_time - 0.65) / 0.75, 0.0, 1.0)
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
		or file_name.find("rightturn") >= 0

func _align_third_person_model_to_ground() -> void:
	if third_person_model == null:
		return
	third_person_ground_offset = 0.0
	third_person_model.position = Vector3.ZERO
	var meshes := []
	_collect_mesh_instances(third_person_model, meshes)
	var min_y := 1000000.0
	for mesh_node in meshes:
		var mesh_instance := mesh_node as MeshInstance3D
		var world_aabb: AABB = mesh_instance.global_transform * mesh_instance.get_aabb()
		min_y = min(min_y, world_aabb.position.y)
	if min_y < 999999.0:
		third_person_ground_offset = -min_y
		if _is_mixamo_root_asset(third_person_loaded_path):
			third_person_ground_offset += MIXAMO_GROUND_CORRECTION
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
	var instance: Node = null
	if ResourceLoader.exists(path):
		var loaded = load(path)
		if loaded is PackedScene:
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
		return generated_scene as Node3D
	if generated_scene != null:
		generated_scene.queue_free()
	return null

func _select_default_held_item() -> void:
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

func _cycle_held_item() -> void:
	if inventory.items.is_empty():
		return
	held_index = (held_index + 1) % inventory.items.size()
	_sync_held_item()
	var item = inventory.items[held_index]
	notice.emit("En mano: %s." % item.item_name)

func _sync_held_item() -> void:
	if inventory == null or inventory.items.is_empty():
		_sync_third_person_equipment(null)
		return
	held_index = clampi(held_index, 0, inventory.items.size() - 1)
	var held_item = inventory.items[held_index]
	_sync_third_person_equipment(held_item)

func _sync_third_person_equipment(held_item) -> void:
	if third_person_hand_item_root == null or third_person_back_item_root == null:
		return
	if hands == null or not hands.has_item_in_hands():
		for child in third_person_hand_item_root.get_children():
			child.queue_free()
	var equip_has_bp: bool = equipment != null and equipment.has_equipped("backpack")
	if not equip_has_bp:
		for child in third_person_back_item_root.get_children():
			child.queue_free()
	var inv_has_bp: bool = inventory != null and inventory.has_item_name("Mochila pequena")
	var eq_bp_set: bool = equipped_backpack == "Mochila pequena"
	if inventory != null and not equip_has_bp and (inv_has_bp or eq_bp_set):
		_build_third_person_backpack()
	if hands != null and hands.has_item_in_hands():
		return
	if held_item == null or held_item.item_type == "backpack":
		return
	if flashlight.visible and inventory.has_item_type("tool"):
		_build_third_person_flashlight()
		return
	match held_item.item_type:
		"weapon":
			_build_third_person_knife()
		"tool":
			_build_third_person_flashlight()
		"food":
			_build_third_person_can()
		"water":
			_build_third_person_bottle()
		"medical":
			_build_third_person_bandage()
		"battery":
			_build_third_person_battery()
		"resource":
			_build_third_person_resource(str(held_item.item_name))
		"seed":
			_build_third_person_seed_bag()
		"clothing":
			_build_third_person_clothing_bundle()
		"tool_axe":
			_build_third_person_tool(REAL_AXE_MODEL, "ThirdPersonAxe", Color(0.23, 0.16, 0.08))
		"tool_hoe":
			_build_third_person_tool(REAL_HOE_MODEL, "ThirdPersonHoe", Color(0.20, 0.14, 0.08))
		"tool_shovel":
			_build_third_person_tool(REAL_SHOVEL_MODEL, "ThirdPersonShovel", Color(0.18, 0.16, 0.12))
		"tool_hammer":
			_build_third_person_tool(REAL_HAMMER_MODEL, "ThirdPersonHammer", Color(0.20, 0.15, 0.09))
		"tool_pickaxe":
			_build_third_person_tool(REAL_PICKAXE_MODEL, "ThirdPersonPickaxe", Color(0.18, 0.15, 0.10))
		_:
			_build_third_person_pack()

func _build_third_person_backpack() -> void:
	var bp_node := _load_external_node3d(REAL_BACKPACK_MODEL)
	if bp_node != null:
		var raw_aabb := _hierarchy_local_aabb(bp_node)
		if raw_aabb.size.y > 0.0001 and raw_aabb.size.x > 0.0001 and raw_aabb.size.z > 0.0001:
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
			return
		bp_node.queue_free()

func _build_third_person_knife() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, REAL_KNIFE_MODEL, "ThirdPersonKnife", Vector3(0.0, 0.0, 0.0), Vector3(82, 0, 0), Vector3.ONE * 0.15)

func _build_third_person_flashlight() -> void:
	pass

func _build_third_person_can() -> void:
	pass

func _build_third_person_bottle() -> void:
	_try_add_model_to_parent(third_person_hand_item_root, "res://assets/external/kenney_survival_kit/Models/GLB format/bottle.glb", "ThirdPersonBottle", Vector3(0, 0, -0.12), Vector3(0, 0, 0), Vector3.ONE * 0.3)

func _build_third_person_bandage() -> void:
	pass

func _build_third_person_battery() -> void:
	pass

func _build_third_person_resource(item_name: String) -> void:
	if item_name == "Tronco" or item_name == "Madera" or item_name == "Ramas":
		_try_add_model_to_parent(third_person_hand_item_root, "res://assets/external/kenney_survival_kit/Models/GLB format/resource-wood.glb", "HeldLog", Vector3(0, 0, -0.18), Vector3(82, 0, 8), Vector3.ONE * 0.3)
	elif item_name == "Piedra":
		_try_add_model_to_parent(third_person_hand_item_root, "res://assets/external/kenney_survival_kit/Models/GLB format/resource-stone.glb", "HeldStone", Vector3(0, 0, -0.12), Vector3(8, 18, 6), Vector3.ONE * 0.25)

func _build_third_person_seed_bag() -> void:
	pass

func _build_third_person_clothing_bundle() -> void:
	pass

func _build_third_person_tool(path: String, node_name: String, fallback_color: Color) -> void:
	_try_add_model_to_parent(third_person_hand_item_root, path, node_name, Vector3(0.0, -0.02, -0.11), Vector3(82, 0, 18), Vector3.ONE * 0.44)

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
		camera.fov = 72.0

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
	camera.position = camera.position.lerp(target_position, delta * 10.0)
	camera.rotation.z = lerp_angle(camera.rotation.z, roll, delta * 8.0)
	_update_third_person_animation(moving, delta)

func _update_third_person_animation(moving: bool, delta: float) -> void:
	var character: Node3D = third_person_model if third_person_model != null else body_mesh
	if character == null:
		return
	var base_rotation := Vector3(0.0, 180.0, 0.0) if character == third_person_model else Vector3.ZERO
	var bob: float = abs(sin(_walk_bob)) * 0.08 * _walk_intensity if moving else 0.0
	var sway: float = sin(_walk_bob) * 4.5 * _walk_intensity if moving else 0.0
	character.position = character.position.lerp(Vector3(0.0, third_person_ground_offset + bob + _water_sink * 0.55, 0.0), delta * 10.0)
	character.rotation_degrees = character.rotation_degrees.lerp(base_rotation + Vector3(0.0, 0.0, sway), delta * 9.0)
	if third_person_animation_player != null:
		if third_person_action_timer > 0.0 and not third_person_action_animation.is_empty():
			third_person_action_timer = max(0.0, third_person_action_timer - delta)
			if third_person_animation_player.current_animation != third_person_action_animation:
				third_person_animation_player.play(third_person_action_animation, 0.08)
			third_person_animation_player.speed_scale = 1.0
			return
		elif third_person_action_timer <= 0.0:
			third_person_action_animation = ""
		var target_animation := ""
		var low_health: bool = stats != null and stats.health <= 30.0 and not third_person_low_health_animation.is_empty()
		if moving:
			if low_health:
				target_animation = third_person_low_health_animation
			elif is_sprinting:
				target_animation = third_person_run_animation
			elif is_crouching:
				target_animation = third_person_sneak_animation
			else:
				target_animation = third_person_walk_animation
		elif _turn_input < -2.0 and not third_person_left_turn_animation.is_empty():
			target_animation = third_person_left_turn_animation
		elif _turn_input > 2.0 and not third_person_right_turn_animation.is_empty():
			target_animation = third_person_right_turn_animation
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
		if not target_animation.is_empty() and third_person_animation_player.current_animation != target_animation:
			third_person_animation_player.play(target_animation)
		elif not target_animation.is_empty() and not third_person_animation_player.is_playing():
			third_person_animation_player.play(target_animation)
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
		third_person_animation_player.seek(0.0, true)

func _interact() -> void:
	var target = _get_interaction_target()
	if target == null:
		notice.emit("No hay nada al alcance.")
		return
	if camera != null:
		var tw := create_tween()
		tw.tween_property(camera, "fov", 72.0, 0.12).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(camera, "fov", 75.0, 0.18).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	target.interact(self)

func _update_interaction_prompt() -> void:
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
	if flashlight.visible:
		flashlight_charge = max(0.0, flashlight_charge - delta)
		flashlight.light_energy = 1.1 + 2.2 * (flashlight_charge / 90.0)
		if flashlight_charge <= 0.0:
			flashlight.visible = false
			_sync_held_item()
			notice.emit("La linterna se queda sin pilas.")

func apply_damage(amount: float) -> void:
	if is_dead:
		return
	stats.health = max(0.0, stats.health - amount)
	stats.changed.emit()
	notice.emit("Has recibido dano.")
	if stats.health <= 0.0 and not stats.dead:
		stats.dead = true
		stats.died.emit()

func to_dict() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"rotation_y": rotation.y,
		"stats": stats.to_dict(),
		"inventory": inventory.to_array(),
		"inventory_max_slots": inventory.max_slots,
		"inventory_max_weight": inventory.max_weight,
		"equipped_clothing": equipped_clothing,
		"equipped_backpack": equ