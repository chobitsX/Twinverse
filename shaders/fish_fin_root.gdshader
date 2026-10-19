shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
#include "res://shaders/fish_fin_surface.gdshaderinc"

void fragment() {
	ALBEDO = fin_surface(UV).rgb;
	ROUGHNESS = 0.49;
	SPECULAR = 0.18;
	// Forward+ cull_disabled already orients the shading normal to the visible side.
}
