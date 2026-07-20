extends CharacterBody3D
class_name NPCController

signal npc_notice(text: String)

const HOSTILE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Characters/glTF/Characters_Matt_SingleWeapon.gltf"

@export var patrol_speed := 2.0
@export var chase_speed := 4.2
@export var detection_range := 14.0
@export var attack_range := 1.6
@export var attack_damage := 9.0

var patrol_points: Array[Vector3] = []
var patrol_index := 0
var player
var attack_cooldown := 0.0
var warned := false
var health := 240.0
var max_health := 240.0
var is_dead := false
var _hit_flash_timer := 0.0
var _gravity := ProjectSettings.get_setting("physics/3d/default_gravity") as float

func setup(new_player, points: Array[Vector3]) -> void:
	player = new_player
	patrol_points = points
	add_to_group("npc")
	_create_body()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if player == null:
		return
	attack_cooldown = max(0.0, attack_cooldown - delta)
	var distance := global_position.distance_to(player.global_position)
	if distance <= detection_range and _has_line_of_sight():
		if not warned:
			warned = true
			npc_notice.emit("Una voz grita: largate de aqui.")
		_chase_or_attack(delta, distance)
	else:
		warned = false
		_patrol(delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	if _hit_flash_timer > 0.0:
		_hit_flash_timer -= delta
		var mesh_node := get_node_or_null("HostileHumanModel")
		if mesh_node != null and mesh_node is MeshInstance3D:
			var mat = (mesh_node as MeshInstance3D).material_override
			if mat is StandardMaterial3D:
				if _hit_flash_timer > 0.0:
					(mat as StandardMaterial3D).albedo_color = Color(1.0, 0.3, 0.3)
				else:
					(mat as StandardMaterial3D).albedo_color = Color(0.20, 0.11, 0.09)

func take_damage(amount: float, _from_knife: bool) -> void:
	if is_dead:
		return
	health = max(0.0, health - amount)
	_hit_flash_timer = 0.3
	if health <= 0.0:
		is_dead = true
		_hit_flash_timer = 2.0
		velocity = Vector3.ZERO
		var tween := create_tween()
		tween.tween_property(self, "rotation_degrees:x", 90.0, 0.5)
		npc_notice.emit("El desconocido ha muerto.")
		set_physics_process(false)

func _patrol(delta: float) -> void:
	if patrol_points.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target := patrol_points[patrol_index]
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var direction := flat_target - global_position
	if direction.length() < 0.7:
		patrol_index = (patrol_index + 1) % patrol_points.size()
		return
	direction = direction.normalized()
	look_at(global_position + Vector3(direction.x, 0.0, direction.z), Vector3.UP)
	velocity.x = direction.x * patrol_speed
	velocity.z = direction.z * patrol_speed

func _chase_or_attack(_delta: float, distance: float) -> void:
	var direction: Vector3 = player.global_position - global_position
	direction.y = 0.0
	if direction.length() > 0.01:
		direction = direction.normalized()
		look_at(global_position + direction, Vector3.UP)
	if distance <= attack_range:
		velocity.x = 0.0
		velocity.z = 0.0
		if attack_cooldown <= 0.0:
			attack_cooldown = 1.4
			player.apply_damage(attack_damage)
			npc_notice.emit("El desconocido te golpea.")
	else:
		velocity.x = direction.x * chase_speed
		velocity.z = direction.z * chase_speed

func _has_line_of_sight() -> bool:
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.4, player.global_position + Vector3.UP * 1.2)
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return result.is_empty() or result.get("collider") == player

func _create_body() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)
	# Body hitbox for rifle raycast
	var body_area := Area3D.new()
	body_area.name = "BodyHitbox"
	var body_col := CollisionShape3D.new()
	var body_shape := CapsuleShape3D.new()
	body_shape.radius = 0.34
	body_shape.height = 1.5
	body_col.shape = body_shape
	body_col.position.y = 0.9
	body_area.add_child(body_col)
	add_child(body_area)
	# Head hitbox for headshots
	var head_area := Area3D.new()
	head_area.name = "HeadHitbox"
	var head_col := CollisionShape3D.new()
	var head_shape := SphereShape3D.new()
	head_shape.radius = 0.18
	head_col.shape = head_shape
	head_col.position.y = 1.7
	head_area.add_child(head_col)
	add_child(head_area)

	if _try_create_external_model():
		return
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.34
	capsule_mesh.height = 1.7
	mesh.mesh = capsule_mesh
	mesh.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.20, 0.11, 0.09)
	material.roughness = 1.0
	mesh.material_override = material
	add_child(mesh)

func _try_create_external_model() -> bool:
	if not ResourceLoader.exists(HOSTILE_MODEL):
		return false
	var packed := load(HOSTILE_MODEL)
	if not (packed is PackedScene):
		return false
	var scene := packed as PackedScene
	var instance := scene.instantiate()
	if not (instance is Node3D):
		return false
	var node := instance as Node3D
	node.name = "HostileHumanModel"
	node.position = Vector3(0, 0, 0)
	node.rotation_degrees = Vector3(0, 180, 0)
	node.scale = Vector3(1.0, 1.0, 1.0)
	add_child(node)
	return true
