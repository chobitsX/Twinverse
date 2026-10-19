shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool has_texture = false;
uniform bool has_normal = false;
uniform bool has_roughness = false;
uniform int roughness_channel = 1;
uniform vec4 tint : source_color = vec4(0.65, 0.62, 0.48, 1.0);
uniform float roughness_value = 0.8;
uniform float surface_normal_depth = 0.6;
uniform float world_time = 0.0;
uniform float caustic_strength = 0.25;
uniform float flex_strength = 0.0;
uniform float tile_scale = 1.0;
// Authored coastal substrate; colour and one-metre tiling are look-dev choices.
uniform sampler2D cover_rock_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cover_normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D cover_arm_texture : filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool ground_surface = false;
uniform bool rock_surface = false;
uniform float saturation : hint_range(0.0, 1.0) = 1.0;
uniform float mottle_strength : hint_range(0.0, 0.3) = 0.0;
instance uniform vec4 colony_tint : source_color = vec4(1.0);
varying vec3 world_position;
varying float substrate_cover;

float hash2(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float noise2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	float flex = COLOR.a * COLOR.a * flex_strength;
	VERTEX.x += sin(world_time * 1.5 + VERTEX.y * 20.0 + VERTEX.z * 16.0) * flex;
	VERTEX.z += cos(world_time * 1.2 + VERTEX.y * 16.0 + VERTEX.x * 11.0) * flex * 0.6;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	substrate_cover = COLOR.r;
}

void fragment() {
	vec2 uv = UV * tile_scale;
	float ground_blend = 0.0;
	vec2 cover_uv = world_position.xz;
	if (ground_surface) {
		// Metre-space tiling remains uniform on the nonuniform terrain grid.
		uv = world_position.xz * tile_scale;
	}
	vec3 base = tint.rgb * colony_tint.rgb;
	if (has_texture) { base *= texture(base_texture, uv).rgb; }
	float luminance = dot(base, vec3(0.2126, 0.7152, 0.0722));
	base = mix(vec3(luminance), base, saturation);
	float mottle = noise2(world_position.xz * 1.7 + world_position.y * 0.6);
	base *= 1.0 + (mottle - 0.5) * mottle_strength;
	if (has_normal) { NORMAL_MAP = texture(normal_texture, uv).rgb; NORMAL_MAP_DEPTH = surface_normal_depth; }
	if (rock_surface) {
		// World-space, continuous across mesh UV seams; authored surface cover,
		// not species identification or an ecological state measurement.
		vec3 weights = abs(normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz));
		weights /= max(weights.x + weights.y + weights.z, 0.001);
		float turf = noise2(world_position.xz * 4.5 + world_position.y * 1.7);
		float crust = noise2(world_position.yz * 17.0) * weights.x
			+ noise2(world_position.xz * 17.0) * weights.y
			+ noise2(world_position.xy * 17.0) * weights.z;
		float patch = smoothstep(0.43, 0.68, crust + (turf - 0.5) * 0.45);
		base = mix(base, base * vec3(0.70, 0.76, 0.48), smoothstep(0.32, 0.70, turf) * 0.50);
		vec3 crust_color = vec3(0.25, 0.15, 0.105) * colony_tint.rgb;
		base = mix(base, crust_color, patch * 0.28);
		base *= 0.86 + crust * 0.28;
	}
	if (ground_surface) {
		float broad = noise2(world_position.xz * 1.7);
		float fine = noise2(world_position.xz * 8.0);
		float cover = smoothstep(0.08, 0.58, substrate_cover + (broad - 0.5) * 0.26);
		float rubble = cover * mix(0.80, 1.0, smoothstep(0.2, 0.8, fine));
		ground_blend = rubble * 0.90;
		base = mix(tint.rgb * 0.76, base, 0.63);
		base *= 0.89 + noise2(world_position.xz * 0.65) * 0.18;
		vec3 debris = texture(cover_rock_texture, cover_uv).rgb;
		float debris_luminance = dot(debris, vec3(0.2126, 0.7152, 0.0722));
		debris = mix(vec3(debris_luminance), debris, 0.60);
		debris = mix(vec3(0.16, 0.145, 0.105), debris, 0.72);
		debris *= vec3(0.40, 0.46, 0.40);
		base = mix(base, debris, ground_blend);
		float fine_fade = 1.0 - smoothstep(0.004, 0.035, length(fwidth(world_position.xz)));
		float ripple = sin(world_position.x * 34.0 + world_position.z * 4.0 + noise2(world_position.xz * 0.6) * 2.0);
		NORMAL_MAP = normalize(vec3(-ripple * 0.12 * fine_fade, 0.025 * sin(world_position.z * 47.0) * fine_fade, 1.0)) * 0.5 + 0.5;
		vec3 ground_normal = NORMAL_MAP * 2.0 - 1.0;
		vec3 cover_normal = texture(cover_normal_texture, cover_uv).xyz * 2.0 - 1.0;
		NORMAL_MAP = normalize(mix(ground_normal, cover_normal, ground_blend)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 0.6;
		AO = mix(1.0, texture(cover_arm_texture, cover_uv).r, ground_blend * 0.65);
	}
	vec2 p = world_position.xz * 7.0;
	p += vec2(sin(p.y * 0.7 + world_time * 0.38), cos(p.x * 0.8 - world_time * 0.34)) * 0.28;
	float c1 = abs(sin(p.x * 2.8 + sin(p.y * 2.1 + world_time * 0.7)));
	float c2 = abs(sin(p.y * 2.3 + sin(p.x * 2.7 - world_time * 0.6)));
	float caustic = pow(max(0.0, 1.0 - min(c1, c2)), 15.0);
	float upward = max(0.0, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	ALBEDO = base;
	ROUGHNESS = roughness_value;
	if (has_roughness) {
		vec4 sampled = texture(roughness_texture, uv);
		float value = sampled.g;
		if (roughness_channel == 0) { value = sampled.r; }
		if (roughness_channel == 2) { value = sampled.b; }
		if (roughness_channel == 3) { value = sampled.a; }
		if (roughness_channel == 4) { value = dot(sampled.rgb, vec3(0.333333)); }
		ROUGHNESS = clamp(value * roughness_value, 0.20, 0.98);
	}
	if (ground_surface) { ROUGHNESS = mix(roughness_value, texture(cover_arm_texture, cover_uv).g, ground_blend); }
	SPECULAR = 0.28;
	EMISSION = base * vec3(0.66, 0.87, 1.0) * caustic * caustic_strength * upward;
}
