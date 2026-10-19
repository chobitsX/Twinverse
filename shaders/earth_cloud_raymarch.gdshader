shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, depth_test_disabled, fog_disabled;

// Local kilometres. A bounded 3-D cloud field, independent of the orbital map.
uniform vec3 box_min = vec3(-650.0, -70.0, -650.0);
uniform vec3 box_max = vec3(650.0, 11.0, 650.0);
uniform sampler3D shape_noise : filter_linear, repeat_enable;
uniform vec3 sun_direction = vec3(0.55, 0.80, -0.24);
uniform float world_time = 0.0;
uniform float extinction_per_km = 1.6;
uniform int view_steps : hint_range(32, 256) = 192;
varying vec3 world_point;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float field_noise(vec3 p) {
	return textureLod(shape_noise, p, 0.0).r;
}
float cloud_density(vec3 p, vec3 eye) {
	// Curved local altitude keeps the broad cloud deck attached to the globe.
	float altitude = length(p + vec3(0.0, 6371.0, 0.0)) - 6371.0;
	if (altitude < 0.9 || altitude > 10.5) { return 0.0; }
	p.x -= world_time * 0.002;
	vec2 weather_uv = p.xz * 0.0015;
	vec2 warp = vec2(field_noise(vec3(weather_uv, 0.31)), field_noise(vec3(weather_uv.yx, 0.73))) - 0.5;
	float weather = field_noise(vec3(weather_uv + warp * 0.18, 0.17));
	float coverage = smoothstep(0.30, 0.67, weather);
	float towers = field_noise(vec3(p.xz * 0.014, 0.63));
	float top = 2.2 + coverage * 3.0 + smoothstep(0.28, 0.74, towers) * 6.0;
	float bottom = 1.0 + smoothstep(0.25, 0.75, field_noise(vec3(p.xz * 0.025, 0.41))) * 1.2;
	float vertical = smoothstep(bottom, bottom + 0.8, altitude) * (1.0 - smoothstep(top * 0.57, top, altitude));
	if (vertical < 0.005) { return 0.0; }
	float detail = 1.0 - smoothstep(70.0, 230.0, distance(p, eye));
	vec3 q = p * vec3(0.022, 0.030, 0.022);
	q.xz += warp * 0.15;
	float shape = field_noise(q) * (1.0 - 0.24 * detail) + field_noise(q * 2.87 + 0.43) * 0.24 * detail;
	float threshold = mix(0.74, 0.37, coverage);
	shape -= threshold + (1.0 - vertical) * 0.32;
	float erosion = (1.0 - field_noise(p * 0.24 + 0.27)) * 0.045 * detail;
	float edge = 1.0 - smoothstep(510.0, 650.0, max(abs(p.x), abs(p.z)));
	return smoothstep(-0.035, 0.16, shape - erosion) * vertical * edge;
}
vec2 sphere_hit(vec3 origin, vec3 direction, float radius) {
	vec3 p = origin - vec3(0.0, -6371.0, 0.0);
	float b = dot(p, direction);
	float h = b * b - (dot(p,p) - radius * radius);
	if (h < 0.0) { return vec2(1e8); }
	return vec2(-b - sqrt(h), -b + sqrt(h));
}
#include "res://shaders/atmosphere_scattering.gdshaderinc"

vec3 air_to_cloud(vec3 origin, vec3 direction, float distance_to_cloud, vec3 radiance, vec3 sun) {
	vec3 relative_origin = origin + vec3(0.0, 6371.0, 0.0);
	vec2 hit = air_sphere_hit(relative_origin, direction, 6471.0);
	float start = max(hit.x, 0.0), finish = min(hit.y, distance_to_cloud);
	if (finish <= start) { return radiance; }
	vec3 transmittance;
	vec3 scattered = air_scattering(relative_origin, direction, sun, start, finish,
		6371.0, 6471.0, 1.0, 2.6, transmittance);
	return radiance * transmittance + scattered;
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec3 origin = CAMERA_POSITION_WORLD;
	vec3 ray = normalize(world_point - origin);
	vec3 inv_ray = 1.0 / (ray + vec3(0.0000001));
	vec3 slab_a = (box_min - origin) * inv_ray;
	vec3 slab_b = (box_max - origin) * inv_ray;
	vec3 near_axis = min(slab_a, slab_b), far_axis = max(slab_a, slab_b);
	float begin = max(max(max(near_axis.x, near_axis.y), near_axis.z), 0.0);
	float end = min(min(far_axis.x, far_axis.y), far_axis.z);
	// March only the curved altitude band, avoiding long empty-space steps.
	vec2 outer = sphere_hit(origin, ray, 6381.5);
	begin = max(begin, outer.x);
	end = min(end, outer.y);
	vec2 base = sphere_hit(origin, ray, 6372.0);
	if (base.x > 0.0) { end = min(end, base.x); }
	else if (base.y > 0.0) { begin = max(begin, base.y); }
	vec2 ground = sphere_hit(origin, ray, 6371.0);
	if (ground.x > 0.0) { end = min(end, ground.x); }
	if (end <= begin) { discard; }
	vec3 sun = normalize(sun_direction);
	// More samples near the camera preserve depth during cloud penetration.
	float transmission = 1.0;
	vec3 radiance = vec3(0.0);
	float weighted_distance = 0.0;
	// Fixed screen-space jitter breaks coherent marching planes without TIME.
	float jitter = hash3(vec3(FRAGCOORD.xy, 3.0));
	// Distances are fixed from entry, independent of the far shell/ground hit.
	// A tangent ground miss must not redistribute the camera's near samples.
	float distance_growth = log(1.0 + length(box_max - box_min));
	// Empty pockets also need coherent near samples while within the deck.
	float eye_altitude = length(origin + vec3(0.0, 6371.0, 0.0)) - 6371.0;
	float near_deck = 1.0 - smoothstep(10.5, 24.0, eye_altitude);
	for (int i = 0; i < 256; i++) {
		if (i >= view_steps || transmission < 0.012) { break; }
		float u0 = float(i) / float(view_steps);
		float u1 = float(i + 1) / float(view_steps);
		float regular_begin = begin + (end - begin) * u0 * (0.15 + 0.85 * u0);
		float regular_end = begin + (end - begin) * u1 * (0.15 + 0.85 * u1);
		float segment_begin = mix(regular_begin, begin + exp(u0 * distance_growth) - 1.0, near_deck);
		if (segment_begin >= end) { break; }
		float segment_end = min(mix(regular_end, begin + exp(u1 * distance_growth) - 1.0, near_deck), end);
		float step_length = segment_end - segment_begin;
		float sample_offset = mix(0.5, fract(jitter + float(i) * 0.61803398875), 0.18);
		float distance_along_ray = mix(segment_begin, segment_end, sample_offset);
		vec3 p = origin + ray * distance_along_ray;
		// A coarse segment can cross a cloud even when its centre is empty.
		// Integrate before skipping; otherwise distant marching planes turn
		// into coherent bright stripes at grazing angles.
		float density = 0.0;
		float density_moment = 0.0;
		int density_samples = step_length > 1.5 ? 4 : 2;
		for (int sample_index = 0; sample_index < 4; sample_index++) {
			if (sample_index >= density_samples) { break; }
			float offset = (float(sample_index) + sample_offset) / float(density_samples);
			float sample_distance = mix(segment_begin, segment_end, offset);
			float sample_density = cloud_density(origin + ray * sample_distance, origin);
			density += sample_density / float(density_samples);
			density_moment += sample_density * sample_distance / float(density_samples);
		}
		if (density < 0.005) { continue; }
		distance_along_ray = density_moment / density;
		p = origin + ray * distance_along_ray;
		float optical_sun = 0.0;
		for (int j = 0; j < 4; j++) {
			float offset = 0.25 + float(j * j) * 0.60;
			float width = 0.60 * float(2 * j + 1);
			optical_sun += cloud_density(p + sun * offset, origin) * width;
		}
		float sun_transmit = exp(-optical_sun * extinction_per_km * 1.05);
		// Density gradients reveal wind-shaped relief on sunlit cloud tops.
		float e = 0.30;
		float point_density = cloud_density(p, origin);
		vec3 gradient = vec3(cloud_density(p + vec3(e,0,0), origin), cloud_density(p + vec3(0,e,0), origin), cloud_density(p + vec3(0,0,e), origin)) - vec3(point_density);
		float diffuse = mix(0.42, 1.0, max(dot(normalize(-gradient + vec3(0.0,0.0001,0.0)), sun), 0.0));
		diffuse = mix(diffuse, 0.72, smoothstep(80.0, 270.0, distance_along_ray));
		float altitude = length(p + vec3(0.0, 6371.0, 0.0)) - 6371.0;
		float upper_sky = smoothstep(1.4, 7.0, altitude);
		vec3 ambient = mix(vec3(0.065, 0.09, 0.14), vec3(0.13, 0.18, 0.26), upper_sky);
		// Soft hemispheric fill varies with the cloud boundary, including bases.
		vec3 normal = normalize(-gradient + vec3(0.0, 0.0001, 0.0));
		float side_fill = 0.65 + 0.35 * dot(normal, normalize(vec3(-0.45, 0.3, 0.7)));
		ambient *= side_fill * mix(1.25, 0.65, smoothstep(0.0, 0.6, density));
		float forward_lobe = 0.10 * pow(max(dot(ray, sun), 0.0), 5.0);
		vec3 light = ambient + vec3(1.0, 0.96, 0.86) * (0.65 * diffuse + forward_lobe) * sun_transmit;
		// Segment optical depth uses the integrated density, not the lighting point.
		light = mix(light, vec3(0.16, 0.25, 0.38), smoothstep(100.0, 530.0, distance_along_ray) * 0.72);
		float alpha_step = 1.0 - exp(-density * extinction_per_km * step_length);
		float weight = transmission * alpha_step;
		radiance += light * weight;
		weighted_distance += distance_along_ray * weight;
		transmission *= 1.0 - alpha_step;
	}
	float alpha = 1.0 - transmission;
	if (alpha < 0.002) { discard; }
	ALBEDO = air_to_cloud(origin, ray, weighted_distance / alpha, radiance / alpha, sun);
	ALPHA = alpha;
}
