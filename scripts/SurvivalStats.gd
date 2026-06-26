extends Node
class_name SurvivalStats

signal changed
signal died

@export var max_health := 100.0
@export var max_stat := 100.0
var health := 100.0
var hunger := 78.0
var thirst := 70.0
var energy := 85.0
var body_temperature := 36.6
var warmth_bonus := 0.0
var dead := false

var hunger_decay := 0.08
var thirst_decay := 0.11
var energy_decay := 0.06
var cold_decay := 0.012

func tick(delta: float, sprinting: bool, cold_factor: float, sheltered: bool) -> void:
	if dead:
		return
	var sprint_multiplier := 3.0 if sprinting else 1.0
	hunger = max(0.0, hunger - hunger_decay * delta)
	thirst = max(0.0, thirst - thirst_decay * delta * sprint_multiplier)
	energy = max(0.0, energy - energy_decay * delta * sprint_multiplier)

	var night_cold_boost := 1.0
	if cold_factor > 5.0:
		night_cold_boost = 2.5
	elif cold_factor > 2.0:
		night_cold_boost = 1.6

	if sheltered:
		body_temperature = min(36.6, body_temperature + 0.008 * delta)
	else:
		var cold_amount: float = max(0.15, cold_factor - warmth_bonus)
		body_temperature -= cold_decay * cold_amount * night_cold_boost * delta
		body_temperature -= 0.004 * delta

	if hunger <= 0.0:
		health -= 0.8 * delta
	if thirst <= 0.0:
		health -= 1.25 * delta
	if body_temperature < 35.0:
		health -= (35.0 - body_temperature) * 0.16 * delta

	health = clamp(health, 0.0, max_health)
	changed.emit()
	if health <= 0.0 and not dead:
		dead = true
		died.emit()

func rest(hours: float) -> void:
	if dead:
		return
	energy = min(max_stat, energy + 16.0 * hours)
	body_temperature = min(36.6, body_temperature + 0.4 * hours)
	hunger = max(0.0, hunger - 3.0 * hours)
	thirst = max(0.0, thirst - 5.0 * hours)
	changed.emit()

func equip_warmth(value: float) -> void:
	warmth_bonus = max(warmth_bonus, value)
	body_temperature = min(36.6, body_temperature + 0.25)
	changed.emit()

func to_dict() -> Dictionary:
	return {
		"health": health,
		"hunger": hunger,
		"thirst": thirst,
		"energy": energy,
		"body_temperature": body_temperature,
		"warmth_bonus": warmth_bonus,
		"dead": dead
	}

func from_dict(data: Dictionary) -> void:
	health = float(data.get("health", health))
	hunger = float(data.get("hunger", hunger))
	thirst = float(data.get("thirst", thirst))
	energy = float(data.get("energy", energy))
	body_temperature = float(data.get("body_temperature", body_temperature))
	warmth_bonus = float(data.get("warmth_bonus", warmth_bonus))
	dead = bool(data.get("dead", health <= 0.0))
	changed.emit()
