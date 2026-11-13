class_name CombatProf
extends RefCounted
## Lightweight usec probe for the "bots shoot the player" freeze diagnosis.
## Enabled via the LD_COMBAT_PROF env var; disabled it costs one static bool read
## per call site. Segments accumulate sum/max/count; the driver dumps every 10 s.

static var enabled := OS.has_environment("LD_COMBAT_PROF")
static var _sum := {}
static var _max := {}
static var _cnt := {}

static func mark(seg: String, t0_usec: int) -> void:
	var d := Time.get_ticks_usec() - t0_usec
	_sum[seg] = int(_sum.get(seg, 0)) + d
	_cnt[seg] = int(_cnt.get(seg, 0)) + 1
	if d > int(_max.get(seg, 0)):
		_max[seg] = d

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
	return " | ".join(parts)
