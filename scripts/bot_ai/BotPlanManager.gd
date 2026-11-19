extends RefCounted
## Lifecycle of the existing ai_directive, not a second planner.
const Diagnostics = preload("res://scripts/bot_ai/BotPlanDiagnostics.gd")
const Interruptions = preload("res://scripts/bot_ai/BotInterruptionManager.gd")
const Validator = preload("res://scripts/bot_ai/BotGoalValidator.gd")
const TERMINAL := ["COMPLETED", "FAILED", "CANCELLED"]

static func prompt_steps(steps: Array) -> Array:
	# Persistence checkpoints are not advisor context. Keep token usage bounded
	# to the actionable pending decisions, excluding clocks and progress internals.
	var result: Array = []
	for step in steps.slice(0, 4):
		if not (step is Dictionary):
			continue
		var decision := {}
		for key in ["goal", "action", "target", "priority", "reason", "purpose"]:
			if step.has(key):
				decision[key] = step[key]
		result.append(decision)
	return result

static func step_key(step: Dictionary) -> String:
	var action := str(step.get("action", ""))
	var target := str(step.get("target", ""))
	if target.is_empty() and action in ["return_home", "rest", "fortify_camp"]:
		target = "camp"
	return JSON.stringify([action, target, Validator.purpose(step)])

static func same_steps(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if step_key(a[i]) != step_key(b[i]):
			return false
	return true

static func repeats_completed_prefix(cur: Dictionary, steps: Array) -> bool:
	if steps.is_empty() or not (cur.get("_completed_keys", []) as Array).has(step_key(steps[0])):
		return false
	var expected: Array = [cur] + cur.get("_remaining_steps", [])
	for i in range(1, steps.size()):
		if steps.size() - i != expected.size():
			continue
		var same := true
		for j in range(expected.size()):
			same = same and step_key(steps[i + j]) == step_key(expected[j])
		if same:
			return true
	return false

static func clock(b: Dictionary, d: Dictionary, now: int) -> void:
	# A stale observation must not move the accounting cursor backwards and
	# count the same suspended interval twice on the next observation.
	now = maxi(now, int(d.get("_clock_ms", now)))
	var elapsed := maxi(0, now - int(d.get("_clock_ms", now)))
	d["_clock_ms"] = now
	if str(d.get("state", "RUNNING")) == "SUSPENDED":
		d["suspended_ms"] = int(d.get("suspended_ms", 0)) + elapsed
		d["_interruption_ms"] = int(d.get("_interruption_ms", 0)) + elapsed
		# Shift each deadline once per elapsed interval, including chained
		# interruptions. No refresh of the remaining active budget.
		for key in ["until", "_step_deadline_ms", "_prog_ref_ms", "_applied_at"]:
			if d.has(key):
				d[key] = int(d[key]) + elapsed
		if (d.get("interruptions", []) as Array).has("sleep"):
			Diagnostics.metric(b, "sleep_suspended_seconds", elapsed / 1000.0)
	else:
		d["active_ms"] = int(d.get("active_ms", 0)) + elapsed

static func start(b: Dictionary, d: Dictionary, steps: Array, now: int, previous: Dictionary = {}, saved: Dictionary = {}) -> void:
	if not previous.is_empty():
		for key in ["plan_id", "active_ms", "suspended_ms", "total_steps", "_plan_root", "_plan_goal", "_plan_losses", "_completed_keys"]:
			d[key] = previous.get(key, [] if key == "_completed_keys" else 0)
		d["_plan_root"] = str(previous.get("_plan_root", previous.get("action", "")))
		d["_plan_goal"] = str(previous.get("_plan_goal", previous.get("goal", previous.get("action", ""))))
		d["step_index"] = int(previous.get("step_index", 0)) + 1
	else:
		var mem: Dictionary = b.get("_mem", {})
		mem["plan_sequence"] = int(mem.get("plan_sequence", 0)) + 1
		d["plan_id"] = "%d:%d:%d" % [int(b.get("bot_id", 0)), int(Time.get_unix_time_from_system()), int(mem["plan_sequence"])]
		d["step_index"] = 0
		d["total_steps"] = steps.size()
		d["active_ms"] = 0
		d["suspended_ms"] = 0
		d["_plan_goal"] = str(d.get("goal", d.get("action", "")))
		d["_plan_root"] = str(d.get("_plan_root", d.get("action", "")))
		d["_completed_keys"] = []
	var resumed := not saved.is_empty() and not str(saved.get("plan_id", "")).is_empty()
	if resumed:
		for key in ["plan_id", "step_index", "total_steps", "active_ms", "suspended_ms", "_plan_root", "_plan_goal", "_plan_losses", "_completed_keys"]:
			if saved.has(key):
				d[key] = saved[key]
	d["state"] = "RUNNING"
	d["_clock_ms"] = now
	d["evidence"] = {}
	if resumed:
		Diagnostics.metric(b, "resumptions")
		d["resume_status"] = "resumed"
		Diagnostics.event(b, d, "plan_resumed", "session_revalidated")
	elif previous.is_empty():
		Diagnostics.metric(b, "plans_started")
		Diagnostics.event(b, d, "plan_started", "decision_accepted")
		Diagnostics.event(b, d, "decision_local" if str(d.get("source", "")).begins_with("local") else "decision_qwen" if str(d.get("source", "")).begins_with("qwen") else "decision_memory")
	Diagnostics.event(b, d, "step_started")

static func finish(b: Dictionary, d: Dictionary, state: String, reason: String, now: int) -> void:
	if d.is_empty() or str(d.get("state", "")) in TERMINAL:
		return
	clock(b, d, now)
	d["state"] = state
	d["result"] = reason
	var key := state.to_lower()
	Diagnostics.metric(b, "plans_" + key)
	Diagnostics.metric(b, "finished_active_seconds", float(d.get("active_ms", 0)) / 1000.0)
	Diagnostics.metric(b, "plans_finished")
	Diagnostics.event(b, d, "plan_" + key, reason, state)
	var mem: Dictionary = b.get("_mem", {})
	mem["last_plan_result"] = {"id": str(d.get("plan_id", "")), "goal": str(d.get("_plan_goal", d.get("goal", ""))),
		"state": state, "reason": reason, "time": Time.get_unix_time_from_system()}
	if str(d.get("goal", "")) == "gear_up_at_military_base":
		b["equip_mission"] = false

static func sync(m, b: Dictionary, now: int) -> void:
	var d: Dictionary = b.get("ai_directive", {})
	if d.is_empty() or str(d.get("state", "")) in TERMINAL:
		return
	if not d.has("plan_id"):
		start(b, d, [d] + d.get("_remaining_steps", []), now)
	clock(b, d, now)
	var proxy = b.get("proxy")
	if not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		finish(b, d, "FAILED", "actor_dead", now)
		b["ai_directive"] = {}
		b.get("_mem", {})["pending_goals"] = []
		return
	var reasons := Interruptions.reasons(b, d, m._is_world_night())
	var old: Array = d.get("interruptions", [])
	if not reasons.is_empty():
		d.erase("_resume_clear_ms")
		if str(d.get("state", "")) != "SUSPENDED":
			d["state"] = "SUSPENDED"
			d["_suspend_ms"] = now
			d["_interruption_ms"] = 0
			d["suspended_at"] = Time.get_unix_time_from_system()
			Diagnostics.metric(b, "suspensions")
			Diagnostics.event(b, d, "plan_suspended", ",".join(reasons))
		elif reasons != old:
			Diagnostics.event(b, d, "interruption_changed", ",".join(reasons))
		d["interruptions"] = reasons
		d["interruption_priority"] = Interruptions.priority(reasons)
		# Sleeping is governed by the existing wake rules. For unresolved
		# field jobs, expose a real lack of local progress and release stale
		# targets, without treating the strategic mission as a failure.
		if not reasons.has("sleep") and not reasons.has("combat") and not reasons.has("escape"):
			var recovery_stats = b.get("vstats")
			var fingerprint := [snappedf(proxy.global_position.x, 3.0), snappedf(proxy.global_position.z, 3.0),
				int(float(b.get("hunger", 100.0)) / 5), int(float(b.get("thirst", 100.0)) / 5),
				int(float(b.get("health", 100.0)) / 5), str(b.get("_act", "")),
				snappedf(float(recovery_stats.body_temperature), 0.1) if recovery_stats != null else 0,
				int(float(recovery_stats.sleep) / 5) if recovery_stats != null else 0,
				snappedf(float(recovery_stats.bleeding), 0.1) if recovery_stats != null else 0]
			if fingerprint != d.get("_recovery_fingerprint", []):
				d["_recovery_fingerprint"] = fingerprint
				d["_recovery_progress_ms"] = now
			elif now - int(d.get("_recovery_progress_ms", now)) > 180000:
				d["_recovery_progress_ms"] = now
				for key in ["_forage", "_farm"]:
					b[key] = {}
				b["sense_t"] = 0.0
				b["_forage_scan"] = 0.0
				Diagnostics.metric(b, "recovery_retries")
				Diagnostics.event(b, d, "recovery_retry", "local_task_stalled")
		# Measure an avoided watchdog once per suspended step, only when the
		# original active deadline would actually have expired.
		if not bool(d.get("_avoided_reported", false)) \
				and now - int(d.get("_suspend_ms", now)) > int(d.get("_step_deadline_ms", now)) - now:
			d["_avoided_reported"] = true
			Diagnostics.metric(b, "suspension_deadlines_avoided")
		return
	if str(d.get("state", "")) == "SUSPENDED":
		# Require a short quiet window; combat -> wounds -> sleep is still
		# one interruption, not a new plan or repeated resume/suspend loop.
		if not d.has("_resume_clear_ms"):
			d["_resume_clear_ms"] = now
		if now - int(d["_resume_clear_ms"]) < 2000:
			return
		var invalid := Validator.viable(m, b, d, now)
		if not invalid.is_empty():
			m._ai_fail_stalled_step(int(b.get("bot_id", 0)), b, d, invalid)
			return
		d["state"] = "RUNNING"
		d["interruptions"] = []
		d["interruption_priority"] = 0
		d["resume_status"] = "resumed"
		d["_prog_ref_m"] = m._ai_step_target_dist(b, d)
		# Distance is rebased after a detour, but time already spent stuck
		# before suspension is retained.
		d.erase("_avoided_reported")
		b["path_timer"] = 0.0
		if str(d.get("mode", "")) == "poi":
			b["explore_target"] = d.get("_dest_pos", Vector3.INF)
		Diagnostics.metric(b, "resumptions")
		Diagnostics.event(b, d, "plan_resumed", "objective_revalidated")

static func completed(m, b: Dictionary, d: Dictionary) -> bool:
	if str(d.get("state", "")) == "SUSPENDED":
		return false
	var evidence := Validator.result(m, b, d)
	d["evidence"] = evidence
	return bool(evidence.get("complete", false))

static func apply(m, bot_id: int, content: String, source: String = "qwen", previous: Dictionary = {}) -> bool:
	if not m.bots.has(bot_id):
		return false
	var b: Dictionary = m.bots[bot_id]
	b["_ai_last_apply"] = "rejected"
	var steps: Array = m._ai_parse_plan(content, b)
	if steps.is_empty():
		return false
	var d: Dictionary = m._ai_parse_decision(JSON.stringify(steps[0]), b)
	if d.is_empty():
		return false
	var saved: Dictionary = steps[0].get("_runtime", {}) if source == "memory" and steps[0].get("_runtime", {}) is Dictionary else {}
	if str(d.get("action", "")) == "seek_ally" and saved.has("_ally_id"):
		d["_ally_id"] = int(saved["_ally_id"])
	# Positional/ally requirements must be checked before equivalence/inertia.
	# Otherwise "return_home" could reaffirm an impossible legacy INF target.
	var pinned := str(d.get("mode", "")) in ["pos", "ally"]
	if pinned and not m._ai_pin_step_destination(bot_id, b, d):
		return false
	var now := Time.get_ticks_msec()
	var cur: Dictionary = b.get("ai_directive", {})
	if not cur.is_empty():
		clock(b, cur, now)
		if repeats_completed_prefix(cur, steps):
			b["_ai_last_apply"] = "kept"
			m._ai_stat_inc(b, "plan_kept")
			return true
		var same := step_key(cur) == step_key(d) and same_steps(cur.get("_remaining_steps", []), steps.slice(1))
		if same:
			# Preserve destination, evidence AND budget. Reaffirmation cannot
			# turn a genuinely stuck mission into an immortal plan.
			b["_ai_last_apply"] = "reaffirmed"
			return true
		var age := (now - int(cur.get("_applied_at", now - 300000))) / 1000.0
		if cur.get("state") == "SUSPENDED" or (age < m.AI_DIRECTIVE_MIN_COMMIT_SEC and int(d.get("priority", 3)) <= int(cur.get("priority", 3))):
			m._ai_stat_inc(b, "plan_kept")
			b["_ai_last_apply"] = "kept"
			return true
	if str(d.get("goal", "")) == "gear_up_at_military_base":
		if not Validator.bind_gear_target(m, b, d):
			return false
	elif not pinned and not m._ai_pin_step_destination(bot_id, b, d):
		return false
	if not cur.is_empty():
		finish(b, cur, "CANCELLED", "replaced_by_priority" if int(d.get("priority", 3)) > int(cur.get("priority", 3)) else "strategic_review", now)
	d["source"] = source
	d["purpose"] = Validator.purpose(d)
	d["_remaining_steps"] = steps.slice(1)
	d["_applied_at"] = now
	d["until"] = now + m.AI_DIRECTIVE_TTL_MSEC
	d["_plan_root"] = str(d.get("action", ""))
	d["_ev0"] = Validator.baseline(b)
	d["_home_bound"] = str(d.get("action", "")) in ["return_home", "rest", "fortify_camp"]
	d["_step_deadline_ms"] = now + m._ai_step_budget_msec(b, d)
	d["_prog_ref_m"] = m._ai_step_target_dist(b, d)
	d["_prog_ref_ms"] = now
	if not saved.is_empty():
		var dest = saved.get("destination", [])
		if dest is Array and dest.size() == 3 and str(d.get("mode", "")) == "poi":
			var pos := Vector3(float(dest[0]), float(dest[1]), float(dest[2]))
			if pos.is_finite() and not m._is_goal_blacklisted(b, pos):
				d["_dest_pos"] = pos
				d["_dest_id"] = str(saved.get("destination_id", ""))
		d["_prog_ref_m"] = m._ai_step_target_dist(b, d)
		d["_step_deadline_ms"] = now + m._ai_step_budget_msec(b, d)
	start(b, d, steps, now, previous, saved)
	d["evidence"] = Validator.result(m, b, d)
	b["ai_directive"] = d
	b["current_goal"] = str(d.get("goal", d.get("action", "survive")))
	m._ensure_bot_memory(bot_id, b.get("cfg", {}))["pending_goals"] = steps.duplicate(true)
	if str(d.get("goal", "")) == "gear_up_at_military_base":
		b["equip_mission"] = true
	m._ai_stat_inc(b, "steps_started")
	b["_ai_last_apply"] = "applied"
	print("[AI-ADV] %s: %s -> %s (p=%d, %s)" % [str(b.get("name", bot_id)), str(d.get("goal", "?")), str(d.get("action", "?")), int(d.get("priority", 3)), str(d.get("reason", ""))])
	return true

static func checkpoint(b: Dictionary, now: int) -> void:
	var d: Dictionary = b.get("ai_directive", {})
	var mem: Dictionary = b.get("_mem", {})
	var pending: Array = mem.get("pending_goals", [])
	if d.is_empty() or pending.is_empty() or str(d.get("state", "")) in TERMINAL:
		return
	clock(b, d, now)
	# Only execution metadata is added to the existing pending first step.
	# Absolute monotonic deadlines never cross a process/session boundary.
	var saved := {}
	for key in ["plan_id", "step_index", "total_steps", "active_ms", "suspended_ms", "_plan_root", "_plan_goal", "_plan_losses", "_completed_keys", "_ally_id"]:
		if d.has(key):
			saved[key] = d[key]
	var pos = d.get("_dest_pos", Vector3.INF)
	if pos is Vector3 and pos.is_finite():
		saved["destination"] = [pos.x, pos.y, pos.z]
		saved["destination_id"] = str(d.get("_dest_id", ""))
	pending[0]["_runtime"] = saved

static func advance(m, bot_id: int, b: Dictionary, d: Dictionary) -> bool:
	var remaining: Array = d.get("_remaining_steps", [])
	var root := str(d.get("_plan_root", d.get("action", "")))
	clock(b, d, Time.get_ticks_msec())
	b["ai_directive"] = {}
	m._ensure_bot_memory(bot_id, b.get("cfg", {}))["pending_goals"] = []
	m.record_strategy_outcome(bot_id, str(d.get("action", "")), true, 0.05, "step_completed")
	m._ai_stat_inc(b, "steps_completed")
	Diagnostics.metric(b, "steps_completed")
	Diagnostics.event(b, d, "step_completed", str(d.get("evidence", {}).get("reason", "objective_verified")), "COMPLETED")
	var completed_keys: Array = d.get("_completed_keys", [])
	completed_keys.append(step_key(d))
	d["_completed_keys"] = completed_keys.slice(-4)
	if remaining.is_empty():
		var losses := int(d.get("_plan_losses", 0))
		b["_plan_last_result"] = "plan_completed" if losses == 0 else "plan_partial"
		m.record_plan_outcome(bot_id, root, losses == 0, 0.08, str(b["_plan_last_result"]))
		m._ai_stat_inc(b, "plans_completed" if losses == 0 else "plans_failed")
		finish(b, d, "COMPLETED" if losses == 0 else "FAILED", str(b["_plan_last_result"]), Time.get_ticks_msec())
		return false
	if not apply(m, bot_id, JSON.stringify({"steps": remaining}), str(d.get("source", "qwen")), d):
		b["_plan_last_result"] = "precondition_failed"
		var failed: Dictionary = remaining[0]
		m.record_strategy_outcome(bot_id, str(failed.get("action", "")), false, 0.14, "precondition")
		m.record_plan_outcome(bot_id, root, false, 0.10, "plan_broken")
		m._ai_note_failed_goal(b, failed, "precondition")
		m._ai_stat_inc(b, "steps_failed")
		m._ai_stat_inc(b, "plans_failed")
		Diagnostics.metric(b, "steps_failed")
		finish(b, d, "FAILED", "precondition_failed", Time.get_ticks_msec())
		return false
	b["_plan_last_result"] = "step_completed"
	return true

static func stalled(m, b: Dictionary, d: Dictionary, now: int) -> String:
	sync(m, b, now)
	if d.get("state") == "SUSPENDED" or str(d.get("state", "")) in TERMINAL:
		return ""
	var invalid := Validator.viable(m, b, d, now)
	if not invalid.is_empty():
		return invalid
	if int(d.get("_prog_ref_ms", 0)) <= 0:
		d["_prog_ref_m"] = m._ai_step_target_dist(b, d)
		d["_prog_ref_ms"] = now
	if int(d.get("_step_deadline_ms", 0)) <= 0:
		d["_step_deadline_ms"] = now + m._ai_step_budget_msec(b, d)
	var dist: float = m._ai_step_target_dist(b, d)
	var gained_progress := dist != INF and dist < float(d.get("_prog_ref_m", INF)) - 3.0
	if gained_progress:
		d["_prog_ref_m"] = dist
	var ev: float = m._ai_step_evidence(b, d)
	if ev != INF:
		var ref := float(d.get("_prog_sref", INF))
		if ref == INF:
			d["_prog_sref"] = ev
		elif ev > ref + 0.49:
			d["_prog_sref"] = ev
			gained_progress = true
	if gained_progress:
		d["_prog_ref_ms"] = now
		if str(d.get("action", "")) == "rest":
			# Rest is execution of this objective. Real recovery renews its
			# budget, instead of granting an unconditional sleep exemption.
			d["_step_deadline_ms"] = now + m._ai_step_budget_msec(b, d)
	elif (dist != INF or ev != INF) and now - int(d.get("_prog_ref_ms", now)) > 90000:
		if dist != INF and dist <= 12.0 and ev == INF:
			pass
		elif m._ai_step_busy(b) and int(d.get("_busy_ext", 0)) < 4:
			d["_busy_ext"] = int(d.get("_busy_ext", 0)) + 1
			d["_prog_ref_ms"] = now
		else:
			return "no_progress"
	if now > int(d.get("_step_deadline_ms", now)):
		if m._ai_step_busy(b) and int(d.get("_busy_ext", 0)) < 4:
			d["_busy_ext"] = int(d.get("_busy_ext", 0)) + 1
			d["_step_deadline_ms"] = now + m._ai_step_budget_msec(b, d)
		else:
			return "timeout"
	return ""

static func fail_step(m, bot_id: int, b: Dictionary, d: Dictionary, cause: String) -> void:
	clock(b, d, Time.get_ticks_msec())
	var root := str(d.get("_plan_root", d.get("action", "")))
	var rem: Array = d.get("_remaining_steps", [])
	b["ai_directive"] = {}
	b["_plan_last_result"] = "step_" + cause
	m._ai_note_failed_goal(b, d, cause)
	m._ensure_bot_memory(bot_id, b.get("cfg", {}))["pending_goals"] = []
	m.record_strategy_outcome(bot_id, str(d.get("action", "")), false, 0.12, cause)
	m._ai_stat_inc(b, "steps_failed")
	m._ai_stat_inc(b, "blocked_recoveries")
	Diagnostics.metric(b, "steps_failed")
	if cause in ["timeout", "no_progress", "nav_blocked", "stuck_timeout"]:
		Diagnostics.metric(b, "real_blocks")
	Diagnostics.event(b, d, "step_failed", cause, "FAILED")
	d["_plan_losses"] = int(d.get("_plan_losses", 0)) + 1
	if not rem.is_empty() and apply(m, bot_id, JSON.stringify({"steps": rem}), str(d.get("source", "qwen")), d):
		return
	finish(b, d, "FAILED", cause, Time.get_ticks_msec())
	m.record_plan_outcome(bot_id, root, false, 0.08, "plan_broken")
	m._ai_stat_inc(b, "plans_failed")
	m._ai_apply_local_fallback_decision(bot_id, "step_" + cause)
	m._ai_enqueue_request(bot_id, 3, "step_" + cause, true)
