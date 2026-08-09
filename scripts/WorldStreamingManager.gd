class_name WorldStreamingManager
extends Node

## Gestor Central de Streaming por Sectores (Chunks) para Mundo Abierto en Godot 4
## Soporta streaming asíncrono, histéresis anti-oscilación, multijugador y pooling.

signal chunk_activated(chunk_coords: Vector2i, sector_node: Node3D)
signal chunk_deactivated(chunk_coords: Vector2i)

@export_group("Configuración de Sectores")
@export var chunk_size: float = 256.0
@export var active_radius: int = 1 # 3x3 cuadrícula alrededor de cada jugador
@export var preload_radius: int = 2 # 5x5 cuadrícula
@export var hysteresis_margin: float = 16.0 # Margen anti-oscilación en metros

@export_group("Rendimiento por Fotograma")
@export var max_instantiates_per_frame: int = 2
@export var max_unloads_per_frame: int = 2

# Estado de sectores
enum SectorState { UNLOADED, PRELOADING, PRELOADED, ACTIVATING, ACTIVE }

class SectorInfo:
	var coords: Vector2i
	var state: SectorState = SectorState.UNLOADED
	var node: Node3D = null
	var resource_path: String = ""
	var is_persistent: bool = false
	var last_active_time: float = 0.0

var _sectors: Dictionary = {} # Vector2i -> SectorInfo
var _player_positions: Array[Vector3] = []
var _active_chunk_coords: Array[Vector2i] = []
var _preloaded_chunk_coords: Array[Vector2i] = []

# Colas de procesamiento por fotograma
var _load_queue: Array[Vector2i] = []
var _unload_queue: Array[Vector2i] = []
var _pending_instantiates: Array[Vector2i] = []

# Pool de nodos reciclables
var _sector_pool: Array[Node3D] = []

# Referencia a Main / Mundo
var _world_node: Node3D = null

func _ready() -> void:
	name = "WorldStreamingManager"

func setup(world_node: Node3D) -> void:
	_world_node = world_node

func update_player_positions(positions: Array[Vector3]) -> void:
	_player_positions = positions
	_recalculate_target_chunks()

func world_to_chunk_coords(pos: Vector3) -> Vector2i:
	var cx := int(floor((pos.x + chunk_size * 0.5) / chunk_size))
	var cz := int(floor((pos.z + chunk_size * 0.5) / chunk_size))
	return Vector2i(cx, cz)

func chunk_coords_to_world_center(coords: Vector2i) -> Vector3:
	return Vector3(coords.x * chunk_size, 0.0, coords.y * chunk_size)

func get_sector_state(coords: Vector2i) -> SectorState:
	if _sectors.has(coords):
		var info: SectorInfo = _sectors[coords]
		return info.state
	return SectorState.UNLOADED

func _recalculate_target_chunks() -> void:
	if _player_positions.is_empty():
		return
	
	var target_active: Dictionary = {}
	var target_preload: Dictionary = {}
	
	# Calcular unión de sectores para todos los jugadores (Multijugador)
	for p_pos in _player_positions:
		var p_chunk := world_to_chunk_coords(p_pos)
		
		# Zona activa (3x3 por defecto)
		for dx in range(-active_radius, active_radius + 1):
			for dz in range(-active_radius, active_radius + 1):
				var coords := Vector2i(p_chunk.x + dx, p_chunk.y + dz)
				target_active[coords] = true
				target_preload[coords] = true
		
		# Zona de precarga (5x5 por defecto)
		for dx in range(-preload_radius, preload_radius + 1):
			for dz in range(-preload_radius, preload_radius + 1):
				var coords := Vector2i(p_chunk.x + dx, p_chunk.y + dz)
				target_preload[coords] = true
	
	# Aplicar Histéresis: Evitar descarga inminente si el jugador está a menos de (radius * size + hysteresis)
	for coords in _sectors.keys():
		var info: SectorInfo = _sectors[coords]
		if info.state == SectorState.ACTIVE and not target_active.has(coords):
			# Verificar si algún jugador sigue dentro del margen de histéresis
			var hill_center := chunk_coords_to_world_center(coords)
			var keep_active := false
			var active_threshold := (float(active_radius) + 0.5) * chunk_size + hysteresis_margin
			for p_pos in _player_positions:
				var dist_xz := Vector2(p_pos.x - hill_center.x, p_pos.z - hill_center.z).length()
				if dist_xz <= active_threshold:
					keep_active = true
					break
			if keep_active:
				target_active[coords] = true
				target_preload[coords] = true
	
	# Encolar sectores para activar / precargar
	for coords in target_preload.keys():
		if not _sectors.has(coords):
			var info := SectorInfo.new()
			info.coords = coords
			info.state = SectorState.UNLOADED
			_sectors[coords] = info
		
		var info: SectorInfo = _sectors[coords]
		if target_active.has(coords):
			if info.state != SectorState.ACTIVE and info.state != SectorState.ACTIVATING:
				if not _load_queue.has(coords):
					_load_queue.append(coords)
		elif info.state == SectorState.UNLOADED:
			if not _load_queue.has(coords):
				_load_queue.append(coords)
	
	# Encolar sectores para descargar
	for coords in _sectors.keys():
		var info: SectorInfo = _sectors[coords]
		if not target_preload.has(coords) and (info.state == SectorState.ACTIVE or info.state == SectorState.PRELOADED):
			if not _unload_queue.has(coords):
				_unload_queue.append(coords)

func _process(_delta: float) -> void:
	_process_load_queue()
	_process_unload_queue()

func _process_load_queue() -> void:
	var processed := 0
	while not _load_queue.is_empty() and processed < max_instantiates_per_frame:
		var coords: Vector2i = _load_queue.pop_front()
		if not _sectors.has(coords):
			continue
		var info: SectorInfo = _sectors[coords]
		
		if info.state == SectorState.UNLOADED:
			# Activar sector
			info.state = SectorState.ACTIVE
			var sector_node := _create_or_recycle_sector_node(coords)
			info.node = sector_node
			if _world_node != null:
				_world_node.add_child(sector_node)
			chunk_activated.emit(coords, sector_node)
			processed += 1

func _process_unload_queue() -> void:
	var processed := 0
	while not _unload_queue.is_empty() and processed < max_unloads_per_frame:
		var coords: Vector2i = _unload_queue.pop_front()
		if not _sectors.has(coords):
			continue
		var info: SectorInfo = _sectors[coords]
		if info.node != null:
			chunk_deactivated.emit(coords)
			if _world_node != null and info.node.get_parent() == _world_node:
				_world_node.remove_child(info.node)
			_recycle_sector_node(info.node)
			info.node = null
		info.state = SectorState.UNLOADED
		_sectors.erase(coords)
		processed += 1

func _create_or_recycle_sector_node(coords: Vector2i) -> Node3D:
	var node: Node3D = null
	if not _sector_pool.is_empty():
		node = _sector_pool.pop_back()
		node.visible = true
	else:
		node = Node3D.new()
	
	node.name = "Sector_%d_%d" % [coords.x, coords.y]
	node.position = chunk_coords_to_world_center(coords)
	return node

func _recycle_sector_node(node: Node3D) -> void:
	# Limpiar hijos dinámicos antes de devolver al pool
	for child in node.get_children():
		child.queue_free()
	node.visible = false
	if _sector_pool.size() < 30: # Limite del pool
		_sector_pool.append(node)
	else:
		node.queue_free()

func get_debug_info() -> Dictionary:
	var active_count := 0
	var preloaded_count := 0
	for info in _sectors.values():
		if info.state == SectorState.ACTIVE:
			active_count += 1
		elif info.state == SectorState.PRELOADED:
			preloaded_count += 1
	
	return {
		"total_registered": _sectors.size(),
		"active_sectors": active_count,
		"preloaded_sectors": preloaded_count,
		"queued_loads": _load_queue.size(),
		"queued_unloads": _unload_queue.size(),
		"pool_size": _sector_pool.size(),
		"chunk_size": chunk_size
	}
