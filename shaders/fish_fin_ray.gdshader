shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
#include "res://shaders/fish_fin_surface.gdshaderinc"

void fragment() {
	// The shallow ray shell needs the deformed surface direction for lighting.
	// Interpolated vertex normals produced dotted highlights even after the
	// authored normals were repaired. VERTEX is in view space here.
	vec3 face_normal = cross(dFdx(VERTEX), dFdy(VERTEX));
	float face_length_squared = dot(face_normal, face_normal);
	if (face_length_squared > 1e-24) {
		face_normal *= inversesqrt(face_length_squared);
		NORMAL = dot(face_normal, VIEW) < 0.0 ? -face_normal : face_normal;
	}
	// COLOR.rg carries the supporting fin's glTF UV, not a display color.
	ALBEDO = fin_surface(COLOR.rg).rgb * 0.94;
	ROUGHNESS = 0.54;
	SPECULAR = 0.10;
}
