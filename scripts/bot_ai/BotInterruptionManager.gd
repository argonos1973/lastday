extends RefCounted
## Observes the existing reactive system; never performs combat or survival actions.
## Ordered reasons share ONE suspended interval, including chained emergencies.
const PRIORITY := {"combat": 100, "escape": 95, "cold": 90, "heat": 90, "bleeding": 85,
	"thirst": 80, "hunger": 75, "exhaustion": 70, "recovery": 70, "night_refuge": 65,
	"sleep": 60, "supplies": 50, "trip_water": 55, "regroup": 45}

static func priority(reasons_list: Array) -> int:
	var value := 0
	for reason in reasons_list:
		value = maxi(value, int(PRIORITY.get(reason, 0)))
	return value

static func dry_recovery_leg(world, from_pos: Vector3, to_pos: Vector3) -> bool:
	# Check the whole short warming leg, not just its endpoint. Normal travel
	# may ford water; a hypothermia recovery must not repeatedly soak the bot.
	if world == null or not world.has_method("get_river_depth_at"):
		return true
	var depth := float(world.get_river_depth_at(from_pos))
	var samples := maxi(1, ceili(Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z).length()))
	for i in range(1, samples + 1):
		var next_depth := float(world.get_river_depth_at(from_pos.lerp(to_pos, float(i) / samples)))
		# If already wet, permit an exit that does not lead deeper. Once dry,
		# stay dry even when the destination is on another bank.
		if next_depth > (0.05 if depth <= 0.05 else depth + 0.02):
			return false
		depth = next_depth
	return depth <= 0.05

static func reasons(b: Dictionary, d: Dictionary, night: bool = false) -> Array:
	var out: Array = []
	var old: Array = d.get("interruptions", [])
	var action := str(d.get("action", ""))
	var act := str(b.get("_act", ""))
	for key in ["_s_predator", "_s_foe", "aggro_target"]:
		if is_instance_valid(b.get(key)):
			out.append("combat")
			break
	if float(b.get("flee_until", 0.0)) > 0.0 or float(b.get("hide_timer", 0.0)) > 0.0:
		out.append("escape")
	var st = b.get("vstats")
	if st != null:
		if float(st.body_temperature) < (35.7 if old.has("cold") else 35.45):
			out.append("cold")
		if float(st.body_temperature) > (GameConst.BOT_HEAT_RECOVERY_TEMP if old.has("heat") else GameConst.BOT_HEAT_ALERT_TEMP):
			out.append("heat")
		if float(st.bleeding) > 0.0:
			out.append("bleeding")
		if action != "rest" and float(st.sleep) < (35.0 if old.has("exhaustion") else 15.0):
			out.append("exhaustion")
	if (action != "forage" or str(d.get("purpose", "")) == "water") and float(b.get("hunger", 100.0)) < (50.0 if old.has("hunger") else 35.0):
		out.append("hunger")
	if str(d.get("purpose", "")) != "water" and float(b.get("thirst", 100.0)) < (50.0 if old.has("thirst") else 30.0):
		out.append("thirst")
	if bool(b.get("sleeping", false)) and action != "rest":
		out.append("sleep")
	# Comfort positioning around a fire is not itself an emergency. Actual
	# cold/heat above already keeps recovery suspended until its safe band;
	# treating every warm_up/cool_off as urgent can prevent leaving camp.
	if action != "rest" and act in ["freeze_march", "fire_rescue", "night_supplies", "firstaid", "water_escape", "need_light"]:
		out.append("recovery")
	if night and action not in ["rest", "return_home"] and act in ["rest", "rest_home"]:
		out.append("night_refuge")
	# A finite local food/water job can interrupt a strategic trip even above
	# critical thresholds. Mere stale work dictionaries do not suspend a plan.
	if action not in ["forage", "hunt"] and act in ["forage", "farm", "cook", "eat", "drink"] \
			and (float(b.get("hunger", 100.0)) < 75.0 or float(b.get("thirst", 100.0)) < 65.0):
		out.append("supplies")
	if b.has("_trip_water"):
		out.append("trip_water")
	if b.has("_regroup") and int(b["_regroup"].get("until", 0)) > Time.get_ticks_msec():
		out.append("regroup")
	return out
