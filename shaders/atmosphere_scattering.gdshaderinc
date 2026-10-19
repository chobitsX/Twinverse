// Shared single-scattering model for sky and camera-to-cloud aerial perspective.
// Origins and lengths use the caller's scene units; coefficients are per kilometre.
#include "res://shaders/eclipse_visibility.gdshaderinc"
vec2 air_sphere_hit(vec3 origin, vec3 direction, float radius) {
	float b = dot(origin, direction);
	// Closest-approach form avoids subtracting two large squared distances.
	// Thin atmosphere shells must remain stable through a distant long lens.
	vec3 closest = origin - direction * b;
	float h = radius * radius - dot(closest, closest);
	if (h < 0.0) { return vec2(1e8, -1e8); }
	float root = sqrt(h);
	return vec2(-b - root, -b + root);
}
vec2 air_density(vec3 p, float radius, float unit_km) {
	float height = max((length(p) - radius) * unit_km, 0.0);
	return vec2(exp(-height / 8.0), exp(-height / 1.2));
}
vec3 air_scattering(vec3 origin, vec3 ray, vec3 light, float start, float finish,
		float radius, float outer_radius, float unit_km, float exposure, out vec3 transmittance) {
	vec3 beta_r = vec3(0.0058, 0.0135, 0.0331);
	vec3 beta_m = vec3(0.0040);
	float step_exponent = (length(origin) - radius) * unit_km < 100.0 ? 2.0 : 1.0;
	vec2 optical = vec2(0.0);
	vec3 sum_r = vec3(0.0), sum_m = vec3(0.0);
	for (int i = 0; i < 20; i++) {
		float segment_start = mix(start, finish, pow(float(i) / 20.0, step_exponent));
		float segment_end = mix(start, finish, pow(float(i + 1) / 20.0, step_exponent));
		float dt = segment_end - segment_start;
		vec3 p = origin + ray * (segment_start + dt * 0.5);
		vec2 d = air_density(p, radius, unit_km) * dt * unit_km;
		vec2 midpoint_optical = optical + d * 0.5;
		optical += d;
		vec2 sun_ground = air_sphere_hit(p, light, radius);
		if (sun_ground.x > 0.001) { continue; }
		float sun_length = air_sphere_hit(p, light, outer_radius).y;
		vec2 sun_optical = vec2(0.0);
		for (int j = 0; j < 4; j++) {
			sun_optical += air_density(p + light * ((float(j) + 0.5) * sun_length / 4.0), radius, unit_km) * sun_length * unit_km / 4.0;
		}
		// Enabled only in the geocentric lunar stage (planet centre = origin).
		vec3 attenuation = exp(-beta_r * (midpoint_optical.x + sun_optical.x) - beta_m * (midpoint_optical.y + sun_optical.y)) * eclipse_visibility(p);
		sum_r += d.x * attenuation;
		sum_m += d.y * attenuation;
	}
	float mu = dot(ray, light), g = 0.76;
	float rayleigh_phase = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	float mie_phase = (1.0 - g * g) / (4.0 * PI * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
	transmittance = exp(-beta_r * optical.x - beta_m * optical.y);
	vec3 single_scattered = (sum_r * beta_r * rayleigh_phase + sum_m * beta_m * mie_phase) * exposure;
	// Authored skylight fill approximates unresolved multiple scattering. It
	// keeps long haze paths from becoming a yellow strip under blue clouds.
	vec3 midpoint = origin + ray * ((start + finish) * 0.5);
	float day_side = smoothstep(-0.10, 0.25, dot(normalize(midpoint), light));
	vec3 sky_fill = vec3(0.009, 0.0225, 0.045) * (1.0 - transmittance) * day_side * eclipse_visibility(midpoint);
	return single_scattered + sky_fill;
}
