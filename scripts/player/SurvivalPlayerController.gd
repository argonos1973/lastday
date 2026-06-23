extends CharacterBody3D
class_name SurvivalPlayerController

signal prompt_changed(text: String)
signal notice(text: String)

@export var walk_speed := 4.0
@export var sprint_speed := 6.8
@export var crouch_speed := 2.0
@export var jump_velocity := 4.2
@export var mouse_sensitivity := 0.0022
@export var ambient_temperature := 12.0

var stats: PlayerStats
var inventory: InventorySystem
var interactor: PlayerInteractor
var camera: Camera3D
var camera_pivot: Node3D

var is_crouching := false
var is_running := false
var is_resting := false

var _pitch := 0.0
var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float

func _ready() -> void:
	_ensure_child_systems()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if stats != null and stats.is_dead:
		return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clamp(_pitch - event.relative.y * mouse_sensitivity, deg_to_rad(-78.0), deg_to_rad(78.0))
		if camera_pivot != null:
			camera_pivot.rotation.x = _pitch
	if event.is_action_pressed("interact") and interactor != null:
		interactor.interact(self)
	if event.is_action_pressed("toggle_inventory"):
		notice.emit("Inventario.")
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if stats != null and stats.is_dead:
		velocity.x = 0.0
		velocity.z = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_dir := (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	is_crouching = Input.is_action_pressed("crouch")
	is_running = Input.is_action_pressed("sprint") and input_dir.length() > 0.1 and not is_crouching and stats.stamina > 8.0
	is_resting = input_dir.length() < 0.05 and is_on_floor()
	var speed := crouch_speed if is_crouching else (sprint_speed if is_running else walk_speed)
	if stats.stamina < 18.0:
		speed *= 0.72

	velocity.x = move_dir.x * speed
	velocity.z = move_dir.z * speed
	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_crouching and stats.stamina > 15.0:
		velocity.y = jump_velocity
		stats.stamina = max(0.0, stats.stamina - 12.0)
	_apply_gravity(delta)
	move_and_slide()

	stats.tick(delta, is_running, is_resting, ambient_temperature, inventory.get_equipped_warmth())
	if interactor != null:
		interactor.update_prompt(self)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

func _ensure_child_systems() -> void:
	stats = get_node_or_null("PlayerStats") as PlayerStats
	if stats == null:
		stats = PlayerStats.new()
		stats.name = "PlayerStats"
		add_child(stats)
	stats.status_message.connect(func(text: String) -> void: notice.emit(text))
	stats.died.connect(func() -> void: notice.emit("La partida ha terminado."))

	inventory = get_node_or_null("InventorySystem") as InventorySystem
	if inventory == null:
		inventory = InventorySystem.new()
		inventory.name = "InventorySystem"
		add_child(inventory)
	inventory.message.connect(func(text: String) -> void: notice.emit(text))

	camera_pivot = get_node_or_null("CameraPivot") as Node3D
	if camera_pivot == null:
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraPivot"
		camera_pivot.position = Vector3(0.0, 1.55, 0.0)
		add_child(camera_pivot)

	camera = camera_pivot.get_node_or_null("Camera3D") as Camera3D
	if camera == null:
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.position = Vector3(0.0, 0.0, 0.0)
		camera_pivot.add_child(camera)

	interactor = get_node_or_null("PlayerInteractor") as PlayerInteractor
	if interactor == null:
		interactor = PlayerInteractor.new()
		interactor.name = "PlayerInteractor"
		add_child(interactor)
	interactor.setup(camera)
	interactor.prompt_changed.connect(func(text: String) -> void: prompt_changed.emit(text))
