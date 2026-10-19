shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// Authored underwater pigment, not measured tissue optics. UV layout and the
// three stripe paths follow the frozen percula mesh; glTF flips Blender's V.
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : filter_linear_mipmap_anisotropic;
uniform bool has_roughness_texture = false;
uniform int roughness_channel = 0;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.28;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.26;
uniform float pigment_variation : hint_range(0.0, 1.0) = 1.0;

float hash_cell(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float pigment_noise(vec2 p, float period_y) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash_cell(vec2(cell.x, mod(cell.y, period_y)));
	float b = hash_cell(vec2(cell.x + 1.0, mod(cell.y, period_y)));
	float c = hash_cell(vec2(cell.x, mod(cell.y + 1.0, period_y)));
	float d = hash_cell(vec2(cell.x + 1.0, mod(cell.y + 1.0, period_y)));
	// Fade subpixel detail before it can turn into swimming colour at distance.
	vec2 pixel_width = fwidth(p);
	float detail_visibility = 1.0 - smoothstep(0.30, 1.0, max(pixel_width.x, pixel_width.y));
	return (mix(mix(a, b, f.x), mix(c, d, f.x), f.y) - 0.5) * detail_visibility;
}

float square(float value) { return value * value; }

vec3 pigment_band(vec3 color, float u, float center, float width, float border, float edge_wobble, float dorsal) {
	float distance_to_center = abs(u - center - edge_wobble);
	float aa = max(fwidth(distance_to_center) * 0.85, 0.0017);
	float black = 1.0 - smoothstep((width + border) * 0.5 - aa, (width + border) * 0.5 + aa, distance_to_center);
	float white = 1.0 - smoothstep(width * 0.5 - aa, width * 0.5 + aa, distance_to_center);
	vec3 ink = vec3(0.065, 0.052, 0.035);
	vec3 cream = vec3(0.71, 0.725, 0.67) - dorsal * vec3(0.07, 0.07, 0.065);
	return mix(mix(color, ink, black), cream, white);
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float theta = uv.y * TAU;
	float dorsal = max(cos(theta), 0.0);
	float belly = max(-cos(theta), 0.0);
	float coarse = pigment_noise(uv * vec2(9.0, 12.0), 12.0);
	float medium = pigment_noise(uv * vec2(37.0, 36.0) + vec2(11.7, 0.0), 36.0);
	float fine = pigment_noise(uv * vec2(153.0, 128.0) + vec2(23.2, 0.0), 128.0);
	float variation = (coarse * 0.052 + medium * 0.024 + fine * 0.014) * pigment_variation;
	float body_value = 0.91 - 0.24 * dorsal + 0.07 * belly + 0.035 * sin(uv.x * 5.7);
	vec3 color = vec3(0.69 + variation, 0.34 + 0.036 * belly + variation * 0.55,
		0.085 + 0.023 * belly + variation * 0.13) * body_value;
	float wobble = pigment_noise(vec2(uv.x * 3.0 + 5.1, uv.y * 84.0), 84.0) * 0.0032;
	float border = 0.032 + 0.037 * dorsal;
	color = pigment_band(color, uv.x, 0.043 + 0.004 * cos(theta * 2.0),
		0.041 + 0.005 * cos(theta), border + 0.013 * square(cos(theta * 2.0)), wobble, dorsal);
	float flank = pow(abs(sin(theta)), 5.0);
	color = pigment_band(color, uv.x, 0.406 + 0.050 * flank + 0.010 * cos(theta),
		0.078 + 0.065 * flank + 0.016 * square(cos(theta)), border + 0.013 * square(cos(theta * 2.0 + 1.0)), wobble, dorsal);
	color = pigment_band(color, uv.x, 0.717 + 0.020 * cos(theta) + 0.011 * cos(theta * 2.0),
		0.073 + 0.014 * cos(theta), border + 0.013 * square(cos(theta * 2.0 + 2.0)), wobble, dorsal);
	float detail = clamp((0.80 - uv.x) * 8.0, 0.045, 1.0);
	// Carry slow pigment variation through the white bars too; constant bars
	// read as a separate coat of paint under the same underwater illumination.
	color *= 1.0 + (coarse * 0.055 + medium * 0.024 + fine * 0.028) * detail * pigment_variation;
	// The baked v3 source stores these authored values in the sRGB PNG domain.
	// Convert once to the same linear-light domain used by source_color samplers.
	ALBEDO = mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), greaterThan(color, vec3(0.04045)));
	vec3 scale_normal = texture(normal_texture, UV).rgb;
	// Relief breaks up the wet highlight without a second colour grid.
	float scale_relief = length(scale_normal.xy * 2.0 - 1.0);
	// Reuse the authored scale roughness with the same UV as the normal map.
	// The former uniform gloss hid the overlapping scale rims on the white bars.
	float mapped_roughness = 0.44;
	if (has_roughness_texture) {
		vec4 sample_roughness = texture(roughness_texture, UV);
		mapped_roughness = roughness_channel == 1 ? sample_roughness.g :
			(roughness_channel == 2 ? sample_roughness.b : (roughness_channel == 3 ? sample_roughness.a : sample_roughness.r));
	}
	ROUGHNESS = clamp(mapped_roughness + 0.015 + 0.035 * dorsal + 0.07 * coarse + scale_relief * 0.14, 0.38, 0.62);
	METALLIC = 0.0;
	SPECULAR = specular_strength;
	CLEARCOAT = 0.025;
	CLEARCOAT_ROUGHNESS = 0.40;
	NORMAL_MAP = scale_normal;
	NORMAL_MAP_DEPTH = normal_strength;
}
