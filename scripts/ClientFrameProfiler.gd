extends Node
## Optional real-client profiler. It is created only when LD_CLIENT_PROFILE=1.
## Reports engine frame, physics and renderer counters plus measured GDScript sections.
## It also turns on CombatProf sampling (never its bot driver): combat sections
## (shots, projectiles, raycasts, wildlife alerts, damage, FX) are totalled per
## report and every frame over SPIKE_MS is stored with the events that happened
## in it, so a hitch can be tied to a shot, impact, damage, death or RPC.

const SAMPLE_CAPACITY := 600
const REPORT_INTERVAL := 10.0
const SPIKE_MS := 50.0
const SPIKE_REPORT_LIMIT := 8
const COMBAT_SECTION_LIMIT := 14

var _world: Node = null
var _samples: Dictionary = {
	"frame_ms": [],
	"process_ms": [],
	"physics_ms": [],
	"navigation_ms": [],
	"draw_calls": [],
	"primitives": [],
	"render_cpu_ms": [],
	"render_gpu_ms": [],
}
var _viewport_rid: RID
var _sections: Dictionary = {}
var _report_elapsed := 0.0
var _sample_count := 0
var _sample_write_index := 0

func setup(world: Node) -> void:
	_world = world
	process_priority = 10000
	set_process(true)
	CombatProf.spike_ms = SPIKE_MS
	CombatProf.enabled = true
	# Renderer time of the main viewport: tells a script hitch from a draw-side
	# one (shader/pipeline compilation, uploads) in the stored slow frames.
	_viewport_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_viewport_rid, true)
	print("[CLIENT_PROFILE] enabled; sampling real client for connected gameplay")

func record_section(label: String, started_usec: int) -> void:
	if started_usec <= 0:
		return
	var elapsed := maxi(0, Time.get_ticks_usec() - started_usec)
	var item: Dictionary = _sections.get(label, {"calls": 0, "total_usec": 0, "max_usec": 0})
	item.calls = int(item.calls) + 1
	item.total_usec = int(item.total_usec) + elapsed
	item.max_usec = maxi(int(item.max_usec), elapsed)
	_sections[label] = item
	CombatProf.frame_only(label, elapsed)

func _process(delta: float) -> void:
	# Values belong to the frame that just finished drawing, like `delta`.
	var render_cpu := RenderingServer.viewport_get_measured_render_time_cpu(_viewport_rid) + RenderingServer.get_frame_setup_time_cpu() if _viewport_rid.is_valid() else 0.0
	var render_gpu := RenderingServer.viewport_get_measured_render_time_gpu(_viewport_rid) if _viewport_rid.is_valid() else 0.0
	_push_sample("render_cpu_ms", render_cpu)
	_push_sample("render_gpu_ms", render_gpu)
	CombatProf.end_frame(delta * 1000.0, {"render_cpu_ms": render_cpu, "render_gpu_ms": render_gpu} if delta * 1000.0 >= SPIKE_MS else {})
	_push_sample("frame_ms", delta * 1000.0)
	_push_sample("process_ms", Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_push_sample("physics_ms", Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	_push_sample("navigation_ms", Performance.get_monitor(Performance.TIME_NAVIGATION_PROCESS) * 1000.0)
	_push_sample("draw_calls", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_push_sample("primitives", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	if _sample_count < SAMPLE_CAPACITY:
		_sample_count += 1
	else:
		_sample_write_index = (_sample_write_index + 1) % SAMPLE_CAPACITY
	_report_elapsed += delta
	if _report_elapsed < REPORT_INTERVAL:
		return
	_report_elapsed = fmod(_report_elapsed, REPORT_INTERVAL)
	_print_report()

func _push_sample(label: String, value: float) -> void:
	var values: Array = _samples[label]
	if _sample_count < SAMPLE_CAPACITY:
		values.append(value)
	else:
		values[_sample_write_index] = value

func _percentile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array = values.duplicate()
	sorted.sort()
	var index := clampi(int(ceil(float(sorted.size() - 1) * fraction)), 0, sorted.size() - 1)
	return float(sorted[index])

func _print_report() -> void:
	var frame: Array = _samples.frame_ms
	var over_50 := 0
	var over_100 := 0
	for value: float in frame:
		if value > 50.0:
			over_50 += 1
		if value > 100.0:
			over_100 += 1
	var world_pos := Vector3.ZERO
	if _world != null and _world.get("player") is Node3D:
		world_pos = (_world.get("player") as Node3D).global_position
	var connected := false
	var is_host := false
	if _world != null and _world.get("net") != null:
		connected = bool(_world.get("net").get("is_connected"))
		is_host = bool(_world.get("net").get("is_host"))
	print("[CLIENT_PROFILE] connected=%s host=%s fps=%.1f frame_p50/p95/p99/max=%.2f/%.2f/%.2f/%.2fms spikes>50=%d spikes>100=%d render_cpu_p95/max=%.2f/%.2fms render_gpu_p95=%.2fms process_p95=%.2fms physics_p95=%.2fms navigation_p95=%.3fms drawcalls_p95=%.0f primitives_p95=%.0f nodes=%d physics_active=%d memory_static=%.0fMB pos=(%.1f,%.1f,%.1f) renderer=%s viewport=%s" % [
		connected, is_host, Engine.get_frames_per_second(),
		_percentile(frame, .50), _percentile(frame, .95), _percentile(frame, .99), float(frame.max()) if not frame.is_empty() else 0.0, over_50, over_100,
		_percentile(_samples.render_cpu_ms, .95), float((_samples.render_cpu_ms as Array).max()) if not (_samples.render_cpu_ms as Array).is_empty() else 0.0, _percentile(_samples.render_gpu_ms, .95),
		_percentile(_samples.process_ms, .95), _percentile(_samples.physics_ms, .95), _percentile(_samples.navigation_ms, .95),
		_percentile(_samples.draw_calls, .95), _percentile(_samples.primitives, .95),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), int(Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)),
		float(OS.get_static_memory_usage()) / 1048576.0, world_pos.x, world_pos.y, world_pos.z,
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), str(get_viewport().get_visible_rect().size),
	])
	var ranked: Array = []
	for label: String in _sections:
		ranked.append({"label": label, "total_usec": int(_sections[label].total_usec)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.total_usec) > int(b.total_usec))
	for index in range(mini(10, ranked.size())):
		var label: String = ranked[index].label
		var item: Dictionary = _sections[label]
		var calls := maxi(1, int(item.calls))
		print("[CLIENT_PROFILE]   %s calls=%d total=%.2fms avg=%.3fms max=%.3fms" % [
			label, calls, float(item.total_usec) / 1000.0, float(item.total_usec) / float(calls) / 1000.0, float(item.max_usec) / 1000.0,
		])
	_print_combat_report()
	_sections.clear()
	for label: String in _samples:
		(_samples[label] as Array).clear()
	_sample_count = 0
	_sample_write_index = 0

## Combat sections, context events and the stored slow frames. Printed once per
## report (never per bullet); silent when nothing combat-related happened.
func _print_combat_report() -> void:
	var combat: Dictionary = CombatProf.snapshot()
	var events: Dictionary = CombatProf.events_snapshot()
	var spikes: Dictionary = CombatProf.take_spikes()
	if not combat.is_empty():
		var labels: Array = combat.keys()
		labels.sort_custom(func(a: String, b: String) -> bool: return int(combat[a].usec) > int(combat[b].usec))
		for index in range(mini(COMBAT_SECTION_LIMIT, labels.size())):
			var item: Dictionary = combat[labels[index]]
			var calls := maxi(1, int(item.calls))
			print("[CLIENT_PROFILE]   combat %s calls=%d total=%.2fms avg=%.3fms max=%.3fms" % [
				labels[index], calls, float(item.usec) / 1000.0, float(item.usec) / float(calls) / 1000.0, float(item.max_usec) / 1000.0,
			])
	if not events.is_empty():
		print("[CLIENT_PROFILE]   combat events=%s" % str(events))
	var samples: Array = spikes.samples
	for index in range(mini(SPIKE_REPORT_LIMIT, samples.size())):
		var spike: Dictionary = samples[index]
		var parts: Array = []
		for label: String in spike.sections_usec:
			parts.append("%s=%.2fms" % [label, float(spike.sections_usec[label]) / 1000.0])
		var extra: Dictionary = spike.get("extra", {})
		print("[CLIENT_PROFILE]   spike %.1fms render_cpu=%.1fms render_gpu=%.1fms events=%s sections=[%s]" % [
			float(spike.ms), float(extra.get("render_cpu_ms", 0.0)), float(extra.get("render_gpu_ms", 0.0)),
			str(spike.events) if not (spike.events as Dictionary).is_empty() else "none", ", ".join(parts),
		])
	if int(spikes.count) > samples.size() or samples.size() > SPIKE_REPORT_LIMIT:
		print("[CLIENT_PROFILE]   spikes stored=%d total=%d (showing first %d)" % [samples.size(), int(spikes.count), mini(SPIKE_REPORT_LIMIT, samples.size())])
	CombatProf.reset()

func _exit_tree() -> void:
	CombatProf.enabled = CombatProf.driver
