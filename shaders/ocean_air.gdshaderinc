// Shared, authored linear-radiance palette for the local sky and sea horizon.
// This is a look-development approximation, not a weather or scattering model.
vec3 ocean_air_horizon(vec3 ray, vec3 sun) {
	vec2 horizontal = ray.xz / max(length(ray.xz), 0.001);
	vec2 sun_horizontal = sun.xz / max(length(sun.xz), 0.001);
	float sunward = pow(max(dot(horizontal, sun_horizontal), 0.0), 4.0);
	return vec3(0.20, 0.32, 0.43) + vec3(0.045, 0.037, 0.022) * sunward;
}

float ocean_cloud_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 h = fract(sin(vec4(dot(i, vec2(127.1, 311.7)), dot(i + vec2(1,0), vec2(127.1,311.7)),
		dot(i + vec2(0,1), vec2(127.1,311.7)), dot(i + vec2(1,1), vec2(127.1,311.7)))) * 43758.5453);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

vec3 ocean_air_sky(vec3 ray, vec3 sun) {
	float elevation = max(ray.y, 0.0);
	vec3 horizon = ocean_air_horizon(ray, sun);
	vec3 air = mix(horizon, vec3(0.032, 0.105, 0.225), pow(elevation, 0.48));
	// Fade before the projection floor; clamping a visible layer made vertical
	// curtains at shallow viewing angles. Fine octaves soften large flat lobes.
	vec2 p = ray.xz / max(elevation, 0.025);
	vec2 warp = vec2(ocean_cloud_noise(p * 0.7), ocean_cloud_noise(p * 0.7 + vec2(11.8))) - 0.5;
	p += warp * 0.65;
	float cloud = ocean_cloud_noise(p * 1.1) * 0.48 + ocean_cloud_noise(p * 2.4 + vec2(7.1)) * 0.27 + ocean_cloud_noise(p * 5.3) * 0.15 + ocean_cloud_noise(p * 11.7) * 0.07 + ocean_cloud_noise(p * 24.5) * 0.03;
	float veil = smoothstep(0.49, 0.72, cloud) * smoothstep(0.026, 0.12, elevation) * 0.72;
	vec3 cloud_radiance = mix(vec3(0.30, 0.38, 0.44), vec3(0.56, 0.60, 0.62), smoothstep(0.50, 0.76, cloud));
	air = mix(air, cloud_radiance, veil);
	if (ray.y < 0.0) { air = mix(horizon, vec3(0.015, 0.10, 0.14), min(-ray.y * 3.0, 1.0)); }
	return air;
}
