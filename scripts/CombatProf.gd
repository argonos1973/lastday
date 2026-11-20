class_name CombatProf
extends RefCounted
## Lightweight usec probe for combat freezes. Disabled it costs one static bool
## read per call site. Segments accumulate sum/max/count for the periodic dump
## AND per rendered frame, so a slow frame can be attributed: when a frame
## exceeds `spike_ms` its sections and events (shot, impact, damage, death,
## RPC received) are stored in a small ring instead of being printed per bullet.
##
## `enabled` = sampling (LD_COMBAT_PROF or the opt-in ClientFrameProfiler).
## `driver`  = LD_COMBAT_PROF only: SurvivorBotManager arms rifle bots on the
##             local player. Sampling alone never changes gameplay.

const SPIKE_CAPACITY := 48
const SPIKE_TOP_SECTIONS := 6

static var enabled := OS.has_environment("LD_COMBAT_PROF")
static var driver := OS.has_environment("LD_COMBAT_PROF")
static var spike_ms := 50.0
static var _sum := {}
static var _max := {}
static var _cnt := {}
static var _ev_total := {}
static var _frame := {}
static var _frame_ev := {}
static var _spikes: Array = []
static var _spike_count := 0

static func mark(seg: String, t0_usec: int) -> void:
	add(seg, Time.get_ticks_usec() - t0_usec, 1)

## Pre-accumulated time: hot loops (projectile substeps) sum locally and report
## once per physics tick instead of touching the dictionaries per substep.
static func add(seg: String, usec: int, count: int = 1) -> void:
	_sum[seg] = int(_sum.get(seg, 0)) + usec
	_cnt[seg] = int(_cnt.get(seg, 0)) + count
	if usec > int(_max.get(seg, 0)):
		_max[seg] = usec
	_frame[seg] = int(_frame.get(seg, 0)) + usec

## Per-frame attribution only (sections already totalled elsewhere).
static func frame_only(seg: String, usec: int) -> void:
	_frame[seg] = int(_frame.get(seg, 0)) + usec

## Context tag for the current frame: "shot.local", "rpc.shot_rifle", "death.player"...
static func event(tag: String) -> void:
	_frame_ev[tag] = int(_frame_ev.get(tag, 0)) + 1
	_ev_total[tag] = int(_ev_total.get(tag, 0)) + 1

## Called once per rendered frame by whoever owns the frame clock. `extra`
## travels with a stored slow frame (e.g. renderer CPU/GPU time of that frame).
static func end_frame(frame_ms: float, extra: Dictionary = {}) -> void:
	if frame_ms >= spike_ms:
		_spike_count += 1
		# Retain early context plus the worst later spike when the buffer fills.
		if _spikes.size() < SPIKE_CAPACITY or frame_ms > float(_spikes.back().ms):
			var segs := _frame.keys()
			segs.sort_custom(func(a, b): return int(_frame[a]) > int(_frame[b]))
			var top := {}
			for i in range(mini(SPIKE_TOP_SECTIONS, segs.size())):
				top[segs[i]] = int(_frame[segs[i]])
			if _spikes.size() == SPIKE_CAPACITY:
				_spikes.pop_back()
			_spikes.append({"ms": frame_ms, "events": _frame_ev.duplicate(), "sections_usec": top, "extra": extra})
	if not _frame.is_empty():
		_frame.clear()
	if not _frame_ev.is_empty():
		_frame_ev.clear()

## Events and script time (usec, all sections; nested ones overlap) of the
## frame in progress — read before end_frame() clears them.
static func frame_events() -> Dictionary:
	return _frame_ev

static func frame_has(seg: String) -> bool:
	return _frame.has(seg)

## Raw totals since the last reset: {seg: {usec, calls, max_usec}}.
static func snapshot() -> Dictionary:
	var out := {}
	for seg in _sum:
		out[seg] = {"usec": int(_sum[seg]), "calls": int(_cnt[seg]), "max_usec": int(_max.get(seg, 0))}
	return out

static func events_snapshot() -> Dictionary:
	return _ev_total.duplicate()

static func take_spikes() -> Dictionary:
	var out := {"count": _spike_count, "samples": _spikes.duplicate()}
	_spikes.clear()
	_spike_count = 0
	return out

static func reset() -> void:
	_sum.clear()
	_max.clear()
	_cnt.clear()
	_ev_total.clear()
	_frame.clear()
	_frame_ev.clear()
	_spikes.clear()
	_spike_count = 0

static func dump_and_reset() -> String:
	var parts: Array = []
	var segs := _sum.keys()
	segs.sort_custom(func(a, b): return int(_sum[a]) > int(_sum[b]))
	for seg in segs:
		var n := int(_cnt[seg])
		parts.append("%s tot=%.1fms n=%d avg=%.0fus max=%.1fms" % [seg, float(_sum[seg]) / 1000.0, n, float(_sum[seg]) / maxf(1.0, n), float(_max[seg]) / 1000.0])
	_sum.clear()
	_max.clear()
	_cnt.clear()
	_ev_total.clear()
	return " | ".join(parts)
