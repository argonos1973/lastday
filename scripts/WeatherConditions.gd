extends RefCounted
## Shared WMO weather interpretation. Amounts are mm of rain and cm of snow.

static func from_observation(code: int, rain: float, snow: float) -> Dictionary:
	var state := {"cloud": 0.1, "darkness": 0.0, "fog": 0.0,
		"rain": maxf(rain, 0.0), "snow": maxf(snow, 0.0), "storm": false}
	match code:
		0: state.cloud = 0.0
		1: state.cloud = 0.18
		2: state.cloud = 0.42; state.darkness = 0.08
		3: state.cloud = 0.88; state.darkness = 0.25
		45, 48:
			state.cloud = 0.65; state.darkness = 0.2; state.fog = 0.008
		51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82:
			var minimum := 0.3
			if code in [53, 61, 66, 80]: minimum = 0.8
			if code in [55, 57, 63, 67, 81]: minimum = 2.5
			if code in [65, 82]: minimum = 6.0
			state.rain = maxf(rain, minimum)
			state.cloud = 0.75 + clampf(state.rain / 30.0, 0.0, 0.2)
			state.darkness = clampf(state.rain * 0.06, 0.18, 0.45)
			state.fog = clampf(state.rain * 0.0002, 0.0, 0.0015)
		71, 73, 75, 77, 85, 86:
			state.snow = maxf(snow, 0.1 if code in [71, 77] else 0.5)
			state.cloud = 0.85; state.darkness = 0.2; state.fog = 0.001
		95, 96, 99:
			state.storm = true; state.rain = maxf(rain, 6.0)
			state.cloud = 1.0; state.darkness = 0.6; state.fog = 0.002
	return state
