extends RefCounted
# Referenciado via preload desde SurvivorBotManager (const BotUtilityAI) — sin
# class_name global para no depender de la cache de clases en builds headless.

# Motor matemático de utilidad esperada para la decisión local de los bots.
# Funciones puras y verificables — ninguna toca el mundo ni la memoria.
#
# Modelo:  U = P(éxito) × beneficio − coste − aversión × riesgo
# Todas las escalas comparten la unidad "punto de decisión" (la misma escala
# que usaban los brackets heurísticos de decide_situational_action: ~0..3).

const P_FLOOR := 0.15 # un plan nunca es imposible a priori
const P_CEIL := 0.95 # ni garantizado: el azar manda
const FOE_HALF_LIFE_MS := 45000.0 # la pista de un enemigo pierde la mitad de valor en 45 s
const ZONE_RISK_CAP := 0.45 # el historial de combate de la zona nunca pasa de media moneda

# Beta-binomial con priors (1,1): con 0 observaciones devuelve 0.5 (moneda),
# y las probabilidades se acercan a 0/1 solo con evidencia acumulada real.
static func success_prob(successes: int, failures: int) -> float:
	return clampf(float(successes + 1) / float(successes + failures + 2), P_FLOOR, P_CEIL)

static func strat_prob(strat: Dictionary) -> float:
	if strat.is_empty():
		return 0.5
	return success_prob(int(strat.get("success", 0)), int(strat.get("fail", 0)))

# P(botín útil | zona): zone_yield[kind] = {n recogidos, good útiles}.
static func zone_yield_prob(zk: Dictionary) -> float:
	if zk.is_empty():
		return 0.5
	var n := int(zk.get("n", 0))
	return clampf(float(int(zk.get("good", 0)) + 1) / float(n + 2), 0.05, P_CEIL)

# Coeficiente de aversión al riesgo [0.15..1.8]: instinto de supervivencia y
# desconfianza encarecen el riesgo; valentía y agresividad lo abaratan.
static func risk_aversion(pers: Dictionary) -> float:
	var a := 0.45 \
		+ float(pers.get("survival_instinct", 0.7)) * 0.85 \
		+ float(pers.get("distrust", 0.35)) * 0.45 \
		- float(pers.get("bravery", 0.5)) * 0.70 \
		- float(pers.get("aggression", 0.3)) * 0.35
	return clampf(a, 0.15, 1.8)

static func expected_utility(benefit: float, p_success: float, cost: float, risk: float, aversion: float) -> float:
	return p_success * benefit - cost - aversion * risk

# Coste del desplazamiento en unidades de decisión: ~0.5 por cada 300 m,
# multiplicado hasta ×2.2 cuando el cuerpo ya no puede (agotado, hambriento
# o sediento sin provisiones). Un destino lejano sin reservas se encarece.
static func travel_cost(dist_m: float, energy: float, hunger: float, thirst: float, has_supplies: bool) -> float:
	var c := dist_m / 300.0 * 0.5
	var frail := 1.0
	if energy < 30.0:
		frail += (30.0 - energy) / 30.0 * 0.7
	if hunger < 35.0 and not has_supplies:
		frail += (35.0 - hunger) / 35.0 * 0.3
	if thirst < 30.0 and not has_supplies:
		frail += (30.0 - thirst) / 30.0 * 0.3
	return c * minf(frail, 2.2)

# Probabilidad de amenaza en la zona combinando evidencias legítimas sin
# omnisciencia. Dos fuentes independientes se fusionan con noisy-OR
# (1−∏(1−p)) — evita contar dos veces pistas correlacionadas:
#   · _foe_mem: la última posición conocida del enemigo, con conf por fuente
#     (seen 1.0 / heard 0.3-0.65 / told 0.15-0.8) y decaimiento exponencial
#     por antigüedad — información vieja pierde influencia.
#   · combat_risk de la zona (memoria known_locations): prior de antecedentes.
static func threat_posterior(foe_mem: Dictionary, now_ms: int, zone_combat_risk: float) -> float:
	var p_obs := 0.0
	if not foe_mem.is_empty():
		var age_ms := float(maxi(0, now_ms - int(foe_mem.get("t", now_ms))))
		var decay := pow(0.5, age_ms / FOE_HALF_LIFE_MS)
		p_obs = clampf(float(foe_mem.get("conf", 0.0)) * decay, 0.0, 1.0)
	var p_zone := clampf(zone_combat_risk / 3.0 * 0.6, 0.0, ZONE_RISK_CAP)
	return clampf(1.0 - (1.0 - p_obs) * (1.0 - p_zone), 0.0, 1.0)

# Riesgo de combate estimado de una presa según el arma elegida: con arma de
# fuego municionada la presa muere lejos; arco lo intenta; solo cuerpo a
# cuerpo contra un ciervo sano es casi siempre pérdida (baja P, sube riesgo).
static func hunt_weapon_profile(weapon_kind: String) -> Dictionary:
	match weapon_kind:
		"m4", "rifle":
			return {"p": 0.9, "risk": 0.10}
		"bow":
			return {"p": 0.65, "risk": 0.22}
		_:
			return {"p": 0.35, "risk": 0.45}
