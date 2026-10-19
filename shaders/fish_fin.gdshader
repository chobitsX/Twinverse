shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled, depth_prepass_alpha;
// Put the near-opaque membrane into the depth prepass so DOF uses the fin,
// rather than the background between its separate opaque rays. Keep the alpha fade.
#include "res://shaders/fish_fin_surface.gdshaderinc"

void fragment() {
	vec4 surface = fin_surface(UV);
	ALBEDO = surface.rgb;
	ALPHA = surface.a;
	ROUGHNESS = 0.49;
	SPECULAR = 0.18;
	// Forward+ cull_disabled already orients the shading normal to the visible side.
}
