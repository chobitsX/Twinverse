shader_type spatial;
// Transparent markers intentionally show the illustrative path through opaque walls.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled;
#include "res://shaders/anatomy_deform.gdshaderinc"
uniform sampler2D flow_path : filter_linear, repeat_disable;
uniform float flow_opacity : hint_range(0.0, 1.0) = 0.6;
varying float endpoint_fade;

void vertex() {
	float u = fract((reference_enabled ? reference_beat * 0.158536585 : world_time * 0.13) * motion_amount + INSTANCE_CUSTOM.r);
	vec3 center = textureLod(flow_path, vec2(u, 0.5), 0.0).rgb;
	center += vec3(0.0, sin(INSTANCE_CUSTOM.g * 6.283185307), cos(INSTANCE_CUSTOM.g * 6.283185307)) * 0.006;
	endpoint_fade = smoothstep(0.0, 0.035, u) * (1.0 - smoothstep(0.965, 1.0, u));
	VERTEX = anatomy_position(center) + VERTEX;
}

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = vec3(0.97, 0.47, 0.19);
	EMISSION = ALBEDO * 0.3;
	ALPHA = flow_opacity * endpoint_fade * (0.3 + 0.7 * facing);
}
