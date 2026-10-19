shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled;

// HDR viewport textures are linear; do not apply a source_color conversion.
uniform sampler2D cloud_texture : filter_linear, repeat_disable;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 cloud = texture(cloud_texture, SCREEN_UV);
	if (cloud.a < 0.002) { discard; }
	// A transparent render target contains premultiplied radiance. Undo that
	// here because the main spatial alpha blend applies its opacity once.
	ALBEDO = cloud.rgb / max(cloud.a, 0.00001);
	ALPHA = cloud.a;
}
