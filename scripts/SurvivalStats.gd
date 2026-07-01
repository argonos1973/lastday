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
var wetness := 0.0
var sick := false
var sick_timer := 0.0
var dead := false

var hunger_decay := 0.08
var thirst_decay := 0.11
var energy_decay := 0.06
var cold_decay := 0.012

func tick(delta: float, sprinting: bool, ambient_temperature: float, sheltered: bool, warmth := 0.0) -> void:
	if dead:
		return
	var sprint_multiplier := 3.0 if sprinting else 1.0
	hunger = max(0.0, hunger - hunger_decay * delta)
	thirst = max(0.0, thirst - thirst_decay * delta * sprint_multiplier)
	energy = max(0.0, energy - energy_decay * delta * sprint_multiplier)

	# Wet clothes dry faster when it's warm, slower when cold
	var dry_rate: float = 0.012 + max(0.0, (ambient_temperature - 10.0)) * 0.004
	wetness = max(0.0, wetness - delta * dry_rate)

	var protection: float = clamp(warmth + warmth_bonus, 0.0, 1.5)
	var target_temperature := 36.6
	# Ambient temperature effect: below 15°C starts cooling the body
	if ambient_temperature < 15.0:
		target_temperature -= (15.0 - ambient_temperature) * (0.045 / max(0.25, protection + 0.35))
	# Wet clothes significantly lower body temperature until dry
	if wetness > 0.05:
		target_temperature -= wetness * 2.5 * (1.0 - protection * 0.3)

	if sheltered:
		target_temperature = max(target_temperature, 35.5)
	body_temperature = lerp(body_temperature, target_temperature, delta * 0.025)

	if hunger <= 0.0:
		health -= 0.8 * delta
	if thirst <= 0.0:
		health -= 1.25 * delta
	if body_temperature < 35.0:
		health -= (35.0 - body_temperature) * 0.16 * delta

	if sick:
		sick_timer -= delta
		health -= 2.0 * delta
		thirst = max(0.0, thirst - thirst_decay * 2.5 * delta)
		if sick_timer <= 0.0:
			sick = false
		health = clamp(health, 0.0, max_health)
	# Passive slow health regen when not suffering any critical condition
	if not sick and hunger > 0.0 and thirst > 0.0 and body_temperature >= 35.0 and health < max_health:
		var regen_rate: float = 0.5
		if hunger > 60.0 and thirst > 60.0:
			regen_rate = 1.2
		health = min(max_health, health + regen_rate * delta)
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

func get_sick(duration: float) -> void:
	sick = true
	sick_timer = max(sick_timer, duration)
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
		"body_temperature": body_temperature,
		"energy": energy,
		"warmth_bonus": warmth_bonus,
		"wetness": wetness,
		"sick": sick,
		"sick_timer": sick_timer,
		"dead": dead
	}

func from_dict(data: Dictionary) -> void:
	health = float(data.get("health", health))
	hunger = float(data.get("hunger", hunger))
	thirst = float(data.get("thirst", thirst))
	body_temperature = float(data.get("body_temperature", body_temperature))
	energy = float(data.get("energy", energy))
	warmth_bonus = float(data.get("warmth_bonus", warmth_bonus))
	wetness = float(data.get("wetness", wetness))
	sick = bool(data.get("sick", false))
	sick_timer = float(data.get("sick_timer", 0.0))
	dead = bool(data.get("dead", health <= 0.0))
	changed.emit()
