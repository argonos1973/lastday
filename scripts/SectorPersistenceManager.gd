class_name SectorPersistenceManager
extends Node

## Gestor de Persistencia por Sectores para Mundo Abierto
## Guarda y restaura únicamente las modificaciones dinámicas (loot recogido, construcciones, puertas, animales)
## evitando duplicar información estática del mapa base.

var _chunk_persistence: Dictionary = {} # Vector2i -> Dictionary

func save_sector_changes(coords: Vector2i, changes: Dictionary) -> void:
	if not _chunk_persistence.has(coords):
		_chunk_persistence[coords] = {}
	
	var current: Dictionary = _chunk_persistence[coords]
	for key in changes.keys():
		current[key] = changes[key]

func get_sector_changes(coords: Vector2i) -> Dictionary:
	if _chunk_persistence.has(coords):
		return _chunk_persistence[coords]
	return {}

func has_sector_changes(coords: Vector2i) -> bool:
	return _chunk_persistence.has(coords) and not _chunk_persistence[coords].is_empty()

func clear_all() -> void:
	_chunk_persistence.clear()
