extends RefCounted

const LING := "inclusionai/ling-3.2-flash:free"
const GEMMA := "google/gemma-4-31b-it:free"
const BRIEFS := {
	"strategy": "Build a long-term survival plan with reserves, a safe known campsite and an achievable resource expedition.",
	"recovery": "Diagnose why the previous plan failed. Change the route, resource or objective; do not repeat a failed step.",
	"weather": "Prepare for dusk or a storm: compare shelter, dry clothing, warmth and stocked supplies.",
	"clothing": "Compare the worn clothes, wetness and temperature. Plan a safe search for dry insulation using purpose clothing or a warming stop.",
	"logistics": "Allocate scarce food, water and tools. Plan a resource expedition or hunt. For hunt you may set prey to deer or fox.",
	"risk": "Assess the observed encounter. Use avoid_zone as the first step to recommend disengaging. Otherwise leave the immediate reaction to the NPC. Never issue attack commands.",
	"social": "Assess trust from observed behaviour of humans and NPCs. Decide whether to seek an ally or avoid contact; never invent trust or alliances.",
}

static func topic(m, b: Dictionary, reason: String) -> String:
	if reason.begins_with("step_") or reason in ["plan_stuck", "plan_blocked", "plan_impossible", "invalid_or_impossible_decision"]:
		return "recovery"
	if reason.begins_with("attacked_by_") or m._sensed_node(b, "_s_foe") != null or m._sensed_node(b, "_s_predator") != null:
		return "risk"
	var weather: Dictionary = m._bot_weather_observation()
	var stats = b.get("vstats")
	if m._is_pre_night() or int(weather.get("weather_code", 0)) >= 95 or float(weather.get("rain", 0)) >= 0.5 \
			or float(weather.get("snow", 0)) > 0:
		return "weather"
	if stats != null and (stats.wetness > 0.5 or stats.body_temperature < 35.7):
		return "clothing"
	if minf(float(b.get("hunger", 100)), float(b.get("thirst", 100))) < 45 or m._sensed_node(b, "_s_prey") != null:
		return "logistics"
	if Time.get_ticks_msec() < int(b.get("_advisor_social_until", 0)):
		return "social"
	return "strategy" if str(b.get("shelter_id", "")).is_empty() or reason == "scheduled" else "logistics"

static func model_for(topic_name: String) -> String:
	if topic_name in ["weather", "clothing"]:
		return GEMMA
	return LING if topic_name in ["strategy", "recovery"] else ""

static func free_payload(payload: Dictionary) -> Dictionary:
	if payload.get("model", "") not in [LING, GEMMA]:
		return {}
	# Whitelist the wire schema: no alternate models, plugins or paid tools.
	var wire := {}
	for key in ["model", "messages", "temperature", "max_tokens", "response_format"]:
		if payload.has(key):
			wire[key] = payload[key]
	wire["provider"] = {"allow_fallbacks":false, "max_price":{"prompt":0, "completion":0, "request":0}}
	wire["plugins"] = []
	return wire
