shader_type spatial;
render_mode unshaded;
#include "res://shaders/cosmos_noise.gdshaderinc"
#include "res://shaders/rotation_filter.gdshaderinc"
uniform vec4 planet_colour : source_color = vec4(0.7, 0.55, 0.35, 1.0);
uniform vec3 planet_center = vec3(0.0);
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform int planet_kind = 0;
uniform bool has_planet_map = false;
uniform float map_polar_limit = 0.0;
uniform float map_longitude_border = 0.0;
uniform vec3 ring_normal = vec3(0.0, 1.0, 0.0);
uniform float ring_inner = 0.0;
uniform float ring_outer = 0.0;
uniform sampler2D planet_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float world_time = 0.0;
varying vec3 world_point;
varying vec3 sphere_position;
void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	sphere_position = normalize(VERTEX);
}
void fragment() {
	vec3 p = normalize(sphere_position);
	// Procedural giant colours are illustrations; damp unresolved longitude
	// detail while keeping latitude bands. The mesh still has its exact IAU pose.
	p = mix(p, vec3(sqrt(max(0.0, 1.0-p.y*p.y)), p.y, 0.0), rotation_filter_weight());
	float detail = cosmic_fbm(p * 12.0);
	float low = cosmic_fbm(p * 3.0);
	vec3 pigment = planet_colour.rgb * mix(0.53, 1.20, detail);
	if (planet_kind >= 4) {
		float bands = sin(p.y * 45.0 + cosmic_fbm(p * 8.0) * 4.0);
		float wisps = cosmic_fbm(vec3(p.x * 7.0, p.y * 48.0, p.z * 7.0));
		pigment = mix(planet_colour.rgb * 0.75, planet_colour.rgb * 1.20, smoothstep(-0.8, 0.8, bands));
		pigment *= 0.84 + 0.28 * wisps;
		if (planet_kind >= 6) { pigment = mix(planet_colour.rgb, pigment, 0.26); }
	} else if (planet_kind == 1) {
		pigment = planet_colour.rgb * (0.80 + 0.35 * cosmic_fbm(p * vec3(9,30,9)));
	} else {
		pigment *= mix(0.65, 1.18, smoothstep(0.30, 0.64, low));
	}
	if (has_planet_map) {
		vec3 map_normal = normalize(sphere_position);
		vec2 map_uv = vec2(atan(map_normal.x, map_normal.z) / TAU + 0.5, acos(clamp(map_normal.y, -1.0, 1.0)) / PI);
		// The Hubble map has unobserved black polar strips. Extend edge colour
		// for the illustration only; the source image itself stays unchanged.
		map_uv.y = clamp(map_uv.y, map_polar_limit, 1.0 - map_polar_limit);
		vec2 uv_dx = dFdx(map_uv), uv_dy = dFdy(map_uv);
		uv_dx.x -= round(uv_dx.x);
		uv_dy.x -= round(uv_dy.x);
		pigment = rotation_filtered_map(planet_map, map_uv, uv_dx, uv_dy).rgb;
		// The Mercury browse has a dark image frame at its longitude edges.
		// Bridge only those border texels; keep the original map and body pose.
		float border = map_longitude_border;
		if (border > 0.0 && (map_uv.x < border || map_uv.x > 1.0 - border)) {
			vec3 left = rotation_filtered_map(planet_map, vec2(border, map_uv.y), uv_dx, uv_dy).rgb;
			vec3 right = rotation_filtered_map(planet_map, vec2(1.0 - border, map_uv.y), uv_dx, uv_dy).rgb;
			float longitude = map_uv.x > 0.5 ? map_uv.x - 1.0 : map_uv.x;
			pigment = mix(right, left, (longitude + border) / (2.0 * border));
		}
		if (planet_kind == 5) {
			float luminance = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
			pigment = mix(vec3(luminance), pigment, 0.78);
		}
	}
	vec3 n = normalize(world_point - planet_center);
	vec3 light = normalize(sun_direction);
	float daylight = smoothstep(-0.07, 0.18, dot(n, light)) * max(dot(n, light), 0.0);
	if (ring_outer > ring_inner && abs(dot(light, ring_normal)) > 0.001) {
		vec3 offset = world_point - planet_center;
		float distance_to_ring = -dot(offset, ring_normal) / dot(light, ring_normal);
		float radius_on_ring = length(offset + light * distance_to_ring);
		float coverage = smoothstep(ring_inner, ring_inner + 0.04, radius_on_ring) * (1.0 - smoothstep(ring_outer - 0.04, ring_outer, radius_on_ring));
		float ring_uv = (radius_on_ring - ring_inner) / (ring_outer - ring_inner);
		coverage *= smoothstep(0.018, 0.030, abs(ring_uv - 0.64));
		daylight *= 1.0 - coverage * smoothstep(0.0, 0.04, distance_to_ring) * 0.75;
	}
	vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_point);
	float rim = pow(1.0 - max(dot(n, view_dir), 0.0), 4.0);
	float haze = planet_kind == 0 || planet_kind == 3 ? 0.025 : 0.10;
	// A small display fill preserves the silhouette; the terminator, ring
	// shadows and bright face still follow the actual direction of the Sun.
	ALBEDO = pigment * (0.035 + 1.24 * daylight) + planet_colour.rgb * rim * haze * smoothstep(-0.12, 0.35, dot(n, light));
}
