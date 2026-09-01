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
var sleep := 100.0
var body_temperature := 36.6
var warmth_bonus := 0.0
var heat_protection_bonus := 0.0
var heat_retention_bonus := 0.0
var wetness := 0.0
var sick := false
var sick_timer := 0.0
var dead := false
var hot_food_charges := 0
var hot_food_temp_bonus := 0.0
var survival_seconds := 0.0
var overeat_count := 0
var overdrink_count := 0

var hunger_decay := 0.12
var thirst_decay := 0.22
var energy_decay := 0.06
var sleep_decay := 0.15
var cold_decay := 0.012

func add_hot_food(charges: int) -> void:
	hot_food_charges = max(hot_food_charges, charges)
	hot_food_temp_bonus = 2.5
	changed.emit()

func consume_food(value: float) -> void:
	if dead:
		return
	hunger = min(max_stat, hunger + value)
	changed.emit()

func consume_water(value: float) -> void:
	if dead:
		return
	thirst = min(max_stat, thirst + value)
	changed.emit()

func tick(delta: float, sprinting: bool, ambient_temperature: float, sheltered: bool, warmth := 0.0, night := false, moving := false, sleeping := false, carry_ratio := 0.0, jumping := false, on_bed := false) -> void:
	if dead:
		return
	survival_seconds += delta
	var sleep_factor := 0.3 if sleeping else 1.0
	var sprint_multiplier := 3.0 if sprinting else 1.0
	var move_multiplier := 2.0 if moving else 1.0
	if sleeping:
		sprint_multiplier = 1.0
		move_multiplier = 1.0
	# Sheltered (under roof): reduced exertion, less calorie/water loss
	var shelter_factor := 0.7 if sheltered else 1.0
	# High body temperature increases thirst drain (sweating)
	var temp_thirst_mult := 1.0
	if body_temperature > 37.0:
		temp_thirst_mult = 1.0 + (body_temperature - 37.0) * 0.5
	# Extreme cold increases hunger drain (body burns calories to stay warm)
	var temp_hunger_mult := 1.0
	if body_temperature < 36.0:
		temp_hunger_mult = 1.0 + (36.0 - body_temperature) * 0.3
	hunger = max(0.0, hunger - hunger_decay * delta * move_multiplier * sprint_multiplier * 0.5 * sleep_factor * shelter_factor * temp_hunger_mult)
	if hunger < max_stat - 10.0:
		overeat_count = 0
	thirst = max(0.0, thirst - thirst_decay * delta * sprint_multiplier * move_multiplier * sleep_factor * shelter_factor * temp_thirst_mult)
	if thirst < max_stat - 10.0:
		overdrink_count = 0
	energy = max(0.0, energy - energy_decay * delta * sprint_multiplier * move_multiplier * sleep_factor * (1.0 + carry_ratio * 8.0))
	# Sleep decay increases with: low energy (fatigue), high body temp (heat), night time
	var sleep_mult := sprint_multiplier
	if energy < 30.0:
		sleep_mult *= 1.5
	if body_temperature > 37.5:
		sleep_mult *= 1.4
	if night:
		sleep_mult *= 2.0
	sleep = max(0.0, sleep - sleep_decay * delta * sleep_mult * sleep_factor)

	# Wet clothes dry faster when it's warm, slower when cold
	var dry_rate: float = 0.012 + max(0.0, (ambient_temperature - 10.0)) * 0.004
	wetness = max(0.0, wetness - delta * dry_rate)

	var protection: float = clamp(warmth + warmth_bonus, 0.0, 1.5)
	var target_temperature := 36.6
	# Ambient temperature effect: below 18°C starts cooling the body
	if ambient_temperature < 18.0:
		target_temperature -= (18.0 - ambient_temperature) * (0.08 / max(0.2, protection + 0.2))
	# Hot ambient: above 28°C starts heating the body, clothing retains heat
	if ambient_temperature > 28.0:
		var heat_retention: float = 1.0 + heat_retention_bonus
		var heat_reduction: float = 1.0 - clamp(heat_protection_bonus, 0.0, 0.8)
		target_temperature += (ambient_temperature - 28.0) * 0.08 * heat_retention * heat_reduction
	# Wet clothes significantly lower body temperature until dry
	if wetness > 0.05:
		target_temperature -= wetness * 2.5 * (1.0 - protection * 0.3)
	# Physical activity raises body temperature
	if not sleeping:
		if moving:
			target_temperature += 0.4
		if sprinting:
			target_temperature += 0.8
		if jumping:
			target_temperature += 0.5
	# Sun exposure during daytime raises body temperature when not sheltered
	if not night and not sheltered:
		target_temperature += 0.6

	if sheltered:
		target_temperature = clamp(target_temperature, 35.5, 37.0)
	# Hot food bonus: increases body temp, decays over time
	if hot_food_charges > 0:
		target_temperature += hot_food_temp_bonus
		hot_food_temp_bonus = max(0.0, hot_food_temp_bonus - delta * 0.08)
		if hot_food_temp_bonus <= 0.01:
			hot_food_charges = 0
	body_temperature = lerp(body_temperature, target_temperature, delta * 0.03)

	if hunger <= 0.0:
		health = max(0.0, health - 2.0 * delta)
	if thirst <= 0.0:
		health = max(0.0, health - 2.5 * delta)
	if sleep <= 0.0:
		health = max(0.0, health - 8.0 * delta)
	elif sleep < 50.0:
		health = max(0.0, health - (50.0 - sleep) * 0.2 * delta)
	# Health damage starts when temp color changes from white (deviation >= 1.2°C)
	if body_temperature < 35.4:
		health = max(0.0, health - 1.0 * delta)
	if body_temperature < 34.5:
		health = max(0.0, health - 2.5 * delta)
	if body_temperature > 37.8:
		health = max(0.0, health - 1.0 * delta)
	if body_temperature > 39.0:
		health = max(0.0, health - 3.0 * delta)

	if sick:
		sick_timer -= delta
		if sick_timer <= 0.0:
			sick = false
		health = max(0.0, health - 1.0 * delta)
	# Passive slow health regen when not suffering any critical condition
	if not sick and hunger > 0.0 and thirst > 0.0 and sleep > 50.0 and body_temperature >= 35.4 and body_temperature < 37.8 and health < max_health:
		var regen_rate: float = 0.5
		if hunger > 60.0 and thirst > 60.0:
			regen_rate = 1.2
		if sleeping and on_bed:
			regen_rate *= 2.0
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

func do_sleep(hours: float) -> void:
	if dead:
		return
	sleep = min(max_stat, sleep + 5.0 * hours)
	energy = min(max_stat, energy + 3.0 * hours)
	# Only heal during sleep if not starving or dehydrated
	if sleep >= max_stat and hunger > 0.0 and thirst > 0.0:
		health = min(max_stat, health + 8.0 * hours)
	changed.emit()

func get_survival_days() -> int:
	return int(survival_seconds / 86400.0)

func get_survival_time_text() -> String:
	var total_hours := int(survival_seconds / 3600.0)
	var days := total_hours / 24
	var hours := total_hours % 24
	var minutes := int(fmod(survival_seconds, 3600.0) / 60.0)
	if days > 0:
		return "Dia %d - %02d:%02d" % [days + 1, hours, minutes]
	return "Dia 1 - %02d:%02d" % [hours, minutes]

func get_sick(duration: float) -> void:
	sick = true
	sick_timer = max(sick_timer, duration)
	hunger *= 0.5
	thirst *= 0.5
	health *= 0.5
	changed.emit()

func equip_warmth(value: float) -> void:
	warmth_bonus = value
	changed.emit()

func equip_heat_protection(value: float) -> void:
	heat_protection_bonus = value
	changed.emit()

func to_dict() -> Dictionary:
	return {
		"health": health,
		"hunger": hunger,
		"thirst": thirst,
		"body_temperature": body_temperature,
		"energy": energy,
		"sleep": sleep,
		"warmth_bonus": warmth_bonus,
		"heat_protection_bonus": heat_protection_bonus,
		"wetness": wetness,
		"sick": sick,
		"sick_timer": sick_timer,
		"hot_food_charges": hot_food_charges,
		"hot_food_temp_bonus": hot_food_temp_bonus,
		"survival_seconds": survival_seconds,
		"overeat_count": overeat_count,
		"overdrink_count": overdrink_count,
		"dead": dead
	}

func from_dict(data: Dictionary) -> void:
	health = float(data.get("health", health))
	hunger = float(data.get("hunger", hunger))
	thirst = float(data.get("thirst", thirst))
	body_temperature = float(data.get("body_temperature", body_temperature))
	energy = float(data.get("energy", energy))
	sleep = float(data.get("sleep", sleep))
	warmth_bonus = float(data.get("warmth_bonus", warmth_bonus))
	heat_protection_bonus = float(data.get("heat_protection_bonus", heat_protection_bonus))
	wetness = float(data.get("wetness", wetness))
	sick = bool(data.get("sick", false))
	sick_timer = float(data.get("sick_timer", 0.0))
	hot_food_charges = int(data.get("hot_food_charges", 0))
	hot_food_temp_bonus = float(data.get("hot_food_temp_bonus", 0.0))
	survival_seconds = float(data.get("survival_seconds", 0.0))
	overeat_count = int(data.get("overeat_count", 0))
	overdrink_count = int(data.get("overdrink_count", 0))
	dead = bool(data.get("dead", health <= 0.0))
	changed.emit()
