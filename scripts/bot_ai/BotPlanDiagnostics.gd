extends RefCounted
## Bounded, JSON-safe lifecycle telemetry. No prompts, credentials or model reasoning.
const HISTORY_LIMIT := 48
const MEMORY_FIELDS := ["plan_history", "plan_metrics", "last_plan_result", "plan_sequence"]

static func metric(b: Dictionary, key: String, amount: float = 1.0) -> void:
	var mem: Dictionary = b.get("_mem", {})
	var metrics: Dictionary = mem.get("plan_metrics", {})
	metrics[key] = float(metrics.get(key, 0.0)) + amount
	mem["plan_metrics"] = metrics

static func event(b: Dictionary, d: Dictionary, kind: String, reason: String = "", result: String = "") -> void:
	var mem: Dictionary = b.get("_mem", {})
	var history: Array = mem.get("plan_history", [])
	var entry := {
		"time": Time.get_unix_time_from_system(), "type": kind,
		"plan_id": str(d.get("plan_id", "")), "goal": str(d.get("_plan_goal", d.get("goal", ""))),
		"step_goal": str(d.get("goal", "")),
		"action": str(d.get("action", "")), "source": str(d.get("source", "")),
		"step": int(d.get("step_index", 0)) + 1, "state": str(d.get("state", "RUNNING")),
		"reason": reason, "result": result,
		"item": str(b.get("_plan_last_item", "")) if kind == "loot_result" else "",
	}
	history.append(entry)
	while history.size() > HISTORY_LIMIT:
		history.pop_front()
	mem["plan_history"] = history

static func snapshot(b: Dictionary, now: int) -> Dictionary:
	var mem: Dictionary = b.get("_mem", {})
	var d: Dictionary = b.get("ai_directive", {})
	var plan: Dictionary = {}
	if not d.is_empty():
		var suspended := str(d.get("state", "RUNNING")) == "SUSPENDED"
		var elapsed := maxi(0, now - int(d.get("_clock_ms", now)))
		var dest = d.get("pos", d.get("_dest_pos", Vector3.INF))
		plan = {
			"id": str(d.get("plan_id", "")), "goal": str(d.get("_plan_goal", d.get("goal", ""))),
			"step_goal": str(d.get("goal", "")),
			"action": str(d.get("action", "")), "target": str(d.get("target", "")),
			"destination": [dest.x, dest.y, dest.z] if dest is Vector3 and dest.is_finite() else [],
			"priority": int(d.get("priority", 3)), "source": str(d.get("source", "")),
			"state": str(d.get("state", "RUNNING")), "step": int(d.get("step_index", 0)) + 1,
			"total_steps": int(d.get("total_steps", 1)),
			"remaining": (d.get("_remaining_steps", []) as Array).map(func(s): return {"action": str(s.get("action", "")), "target": str(s.get("target", ""))}),
			"active_seconds": (float(d.get("active_ms", 0)) + (0 if suspended else elapsed)) / 1000.0,
			"suspended_seconds": (float(d.get("suspended_ms", 0)) + (elapsed if suspended else 0)) / 1000.0,
			"interruption_seconds": (float(d.get("_interruption_ms", 0)) + elapsed) / 1000.0 if suspended else 0.0,
			"suspended_at": float(d.get("suspended_at", 0.0)),
			"reasons": d.get("interruptions", []).duplicate(),
			"interruption_priority": int(d.get("interruption_priority", 0)),
			"resume_status": "waiting" if suspended else str(d.get("resume_status", "")),
			"evidence": d.get("evidence", {}).duplicate(true),
		}
	return {
		"plan": plan, "activity": str(b.get("_act", "")),
		"last_result": mem.get("last_plan_result", {}).duplicate(true),
		"history": mem.get("plan_history", []).duplicate(true),
		"metrics": mem.get("plan_metrics", {}).duplicate(true),
	}
