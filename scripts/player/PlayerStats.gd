extends Node
class_name PlayerStats

signal changed
signal status_message(text: String)
signal died

@export var max_health := 100.0
@export var max_stamina := 100.0
@export var max_need := 100.0
@export var normal_temperature := 36.6
@export var min_safe_temperature := 35.0

@export var hunger_decay_per_second := 0.020
@export var thirst_decay_per_second := 0.034
@export var stamina_recovery_per_second := 10.0
@export var fatigue_recovery_per_second := 2.0
@export var starvation_damage_per_second := 0.45
@export var dehydration_damage_per_second := 0.65
@export var cold_damage_per_second := 0.55
@export var bleeding_damage_per_second := 1.10
@export var infection_damage_per_second := 0.18

var health := 100.0
var stamina := 100.0
var hunger := 82.0
var thirst := 76.0
var temperature := 36.6
var bleeding := 0.0
var infection := 0.0
var fatigue := 0.0
var wetness := 0.0
var is_dead := false

var _message_cooldown := 0.0

func tick(delta: float, is_running: bool, is_resting: bool, ambient_temperature: float, warmth: float, rain_exposure := 0.0) -> void:
	if is_dead:
		return
	_message_cooldown = max(0.0, _message_cooldown - delta)
	var exertion := 1.0
	if is_running:
		exertion = 2.65
		stamina = max(0.0, stamina - delta * 17.0)
		thirst = max(0.0, thirst - delta * thirst_decay_per_second * 2.0)
		fatigue = min(100.0, fatigue + delta * 0.75)
	elif is_resting:
		stamina = min(max_stamina, stamina + delta * stamina_recovery_per_second * 1.8)
		fatigue = max(0.0, fatigue - delta * fatigue_recovery_per_second * 1.6)
	else:
		stamina = min(max_stamina, stamina + delta * stamina_recovery_per_second)
		fatigue = max(0.0, fatigue - delta * fatigue_recovery_per_second)

	hunger = max(0.0, hunger - delta * hunger_decay_per_second * exertion)
	thirst = max(0.0, thirst - delta * thirst_decay_per_second)
	_update_temperature(delta, ambient_temperature, warmth, rain_exposure)
	_apply_survival_damage(delta)
	_emit_state_messages()
	changed.emit()

func consume_food(value: float) -> void:
	if is_dead:
		return
	hunger = min(max_need, hunger + value)
	status_message.emit("Comes algo. El hambre baja un poco.")
	changed.emit()

func consume_water(value: float) -> void:
	if is_dead:
		return
	thirst = min(max_need, thirst + value)
	status_message.emit("Bebes agua.")
	changed.emit()

func heal(value: float) -> void:
	if is_dead:
		return
	health = min(max_health, health + value)
	status_message.emit("Te tratas la herida.")
	changed.emit()

func apply_damage(amount: float, can_bleed := false, infection_risk := 0.0) -> void:
	if is_dead:
		return
	health = max(0.0, health - amount)
	if can_bleed:
		bleeding = min(100.0, bleeding + randf_range(18.0, 34.0))
	if infection_risk > 0.0 and randf() < infection_risk:
		infection = min(100.0, infection + 10.0)
	_check_death()
	changed.emit()

func stop_bleeding(amount := 100.0) -> void:
	bleeding = max(0.0, bleeding - amount)
	status_message.emit("La venda frena la hemorragia.")
	changed.emit()

func get_health_state() -> String:
	if is_dead:
		return "Muerto"
	if health <= 20.0:
		return "Critico"
	if bleeding > 0.0:
		return "Sangrando"
	if infection > 0.0:
		return "Infectado"
	if temperature < min_safe_temperature:
		return "Hipotermia"
	if hunger <= 0.0:
		return "Hambriento"
	if thirst <= 0.0:
		return "Sediento"
	return "Sano"

func to_dict() -> Dictionary:
	return {
		"health": health,
		"stamina": stamina,
		"hunger": hunger,
		"thirst": thirst,
		"temperature": temperature,
		"bleeding": bleeding,
		"infection": infection,
		"fatigue": fatigue,
		"wetness": wetness,
		"is_dead": is_dead
	}

func from_dict(data: Dictionary) -> void:
	health = float(data.get("health", health))
	stamina = float(data.get("stamina", stamina))
	hunger = float(data.get("hunger", hunger))
	thirst = float(data.get("thirst", thirst))
	temperature = float(data.get("temperature", temperature))
	bleeding = float(data.get("bleeding", bleeding))
	infection = float(data.get("infection", infection))
	fatigue = float(data.get("fatigue", fatigue))
	wetness = float(data.get("wetness", wetness))
	is_dead = bool(data.get("is_dead", is_dead))
	changed.emit()

func _update_temperature(delta: float, ambient_temperature: float, warmth: float, rain_exposure: float) -> void:
	wetness = clamp(wetness + rain_exposure * delta * 0.08 - delta * 0.012, 0.0, 1.0)
	# Wet clothes dry faster when it's warm, slower when cold
	var dry_rate := 0.012 + max(0.0, (ambient_temperature - 10.0)) * 0.004
	wetness = max(0.0, wetness - delta * dry_rate)
	var protection := clamp(warmth, 0.0, 1.5)
	var target_temperature := normal_temperature
	# Ambient temperature effect: below 15°C starts cooling the body
	if ambient_temperature < 15.0:
		target_temperature -= (15.0 - ambient_temperature) * (0.045 / max(0.25, protection + 0.35))
	# Wet clothes significantly lower body temperature until dry
	if wetness > 0.05:
		target_temperature -= wetness * 2.5 * (1.0 - protection * 0.3)
	temperature = lerp(temperature, target_temperature, delta * 0.025)

func _apply_survival_damage(delta: float) -> void:
	if hunger <= 0.0:
		health = max(0.0, health - starvation_damage_per_second * delta)
	if thirst <= 0.0:
		health = max(0.0, health - dehydration_damage_per_second * delta)
	if temperature < min_safe_temperature:
		health = max(0.0, health - cold_damage_per_second * delta * (min_safe_temperature - temperature))
	if bleeding > 0.0:
		health = max(0.0, health - bleeding_damage_per_second * delta * (bleeding / 100.0))
		infection = min(100.0, infection + delta * 0.18)
	if infection > 0.0:
		health = max(0.0, health - infection_damage_per_second * delta * (infection / 100.0))
	# Passive slow health regen when not suffering any critical condition
	if hunger > 0.0 and thirst > 0.0 and temperature >= min_safe_temperature and bleeding <= 0.0 and infection <= 0.0 and health < max_health:
		var regen_rate := 0.5
		if hunger > 60.0 and thirst > 60.0:
			regen_rate = 1.2
		health = min(max_health, health + regen_rate * delta)
	_check_death()

func _emit_state_messages() -> void:
	if _message_cooldown > 0.0:
		return
	if bleeding > 0.0:
		status_message.emit("Estoy sangrando.")
	elif thirst < 18.0:
		status_message.emit("Necesito beber.")
	elif hunger < 18.0:
		status_message.emit("Tengo hambre.")
	elif temperature < min_safe_temperature:
		status_message.emit("Tengo mucho frio.")
	elif fatigue > 82.0:
		status_message.emit("Me siento debil.")
	else:
		return
	_message_cooldown = 10.0

func _check_death() -> void:
	if health > 0.0 or is_dead:
		return
	is_dead = true
	health = 0.0
	status_message.emit("Has muerto.")
	died.emit()
