shader_type sky;

// Realistic dynamic sky with procedural volumetric-looking clouds.
// Driven automatically by the scene's DirectionalLight (the Sun), so it
// transitions between day, sunset and night as the sun moves.

uniform vec3 day_zenith : source_color = vec3(0.09, 0.30, 0.66);
uniform vec3 day_horizon : source_color = vec3(0.68, 0.82, 0.94);
uniform vec3 night_zenith : source_color = vec3(0.006, 0.012, 0.035);
uniform vec3 night_horizon : source_color = vec3(0.02, 0.035, 0.085);
uniform vec3 sunset_color : source_color = vec3(0.98, 0.45, 0.18);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.84);
uniform vec3 ground_color : source_color = vec3(0.10, 0.11, 0.10);

uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.50;
uniform float cloud_sharpness : hint_range(0.02, 0.6) = 0.18;
uniform float cloud_scale = 2.1;
uniform float cloud_speed = 0.0045;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.95;
uniform vec3 cloud_lit : source_color = vec3(1.0, 0.99, 0.96);
uniform vec3 cloud_dark : source_color = vec3(0.46, 0.50, 0.58);
uniform vec3 cloud_night : source_color = vec3(0.028, 0.035, 0.055);

// World-space direction pointing toward the sun (set from the day/night cycle).
uniform vec3 sun_direction = vec3(0.0, 0.35, -0.94);

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 m = mat2(vec2(1.6, 1.2), vec2(-1.2, 1.6));
	for (int i = 0; i < 6; i++) {
		v += a * vnoise(p);
		p = m * p;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sun_dir = normalize(sun_direction);
	float sun_elev = sun_dir.y;

	float day = smoothstep(-0.18, 0.15, sun_elev);
	float dusk = smoothstep(-0.28, 0.06, sun_elev) * (1.0 - smoothstep(0.06, 0.35, sun_elev));

	// Base vertical gradient
	float h = clamp(dir.y, 0.0, 1.0);
	vec3 zenith = mix(night_zenith, day_zenith, day);
	vec3 horizon = mix(night_horizon, day_horizon, day);
	vec3 sky_col = mix(horizon, zenith, pow(h, 0.55));

	// Warm sunset/sunrise band near the sun's azimuth at the horizon
	vec3 flat_dir = normalize(vec3(dir.x, 0.0, dir.z) + 0.0001);
	vec3 flat_sun = normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + 0.0001);
	float az_align = max(dot(flat_dir, flat_sun), 0.0);
	float horizon_band = exp(-abs(dir.y) * 5.5);
	sky_col = mix(sky_col, sunset_color, clamp(dusk * horizon_band * az_align, 0.0, 1.0) * 0.9);

	// Sun disc + glow
	float sd = max(dot(dir, sun_dir), 0.0);
	float disc = smoothstep(0.9990, 0.9996, sd);
	float glow = pow(sd, 250.0) * 0.6 + pow(sd, 10.0) * 0.10;
	float sun_vis = clamp(day + 0.12, 0.0, 1.0);
	vec3 sun_c = sun_color * (disc * 9.0 + glow) * sun_vis;

	vec3 col = sky_col;

	// Procedural clouds in the upper hemisphere
	if (dir.y > 0.0) {
		vec2 uv = dir.xz / (dir.y + 0.28);
		vec2 wind = vec2(TIME * cloud_speed, TIME * cloud_speed * 0.55);
		float base = fbm(uv * cloud_scale + wind);
		float detail = fbm(uv * cloud_scale * 3.2 + wind * 2.4);
		float d_field = base * 0.7 + detail * 0.3;

		float cov = 1.0 - cloud_coverage;
		float clouds = smoothstep(cov, cov + cloud_sharpness, d_field);
		clouds *= smoothstep(0.0, 0.20, dir.y);
		clouds *= cloud_opacity;

		// Fake self-shadow / silver lining by sampling toward the sun
		vec2 sun_off = normalize(vec2(sun_dir.x, sun_dir.z) - vec2(dir.x, dir.z) + 0.0001) * 0.16;
		float toward = fbm((uv + sun_off) * cloud_scale + wind);
		float lit = clamp((d_field - toward) * 2.6 + 0.5, 0.0, 1.0);

		vec3 cloud_day_c = mix(cloud_dark, cloud_lit, lit);
		cloud_day_c = mix(cloud_day_c, sun_color, glow * 0.6 * lit);
		vec3 cloud_col = mix(cloud_night, cloud_day_c, day);

		col = mix(col, cloud_col, clouds);
		// The sun is occluded by clouds in front of it
		sun_c *= (1.0 - clouds * 0.92);
	}

	col += sun_c;

	// Darken below the horizon toward the ground
	col = mix(col, mix(ground_color * 0.25, ground_color, day), smoothstep(0.0, -0.05, dir.y));

	COLOR = col;
}
