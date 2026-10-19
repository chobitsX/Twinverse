shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D color_map : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_map : filter_linear_mipmap, repeat_enable;
uniform vec4 garment_color : source_color = vec4(.24,.43,.44,1.0);
uniform bool female_style = false;
uniform bool has_normal = false;
uniform bool has_roughness = false;
uniform float roughness_value = .8;
void fragment() {
	vec3 source = texture(color_map, UV).rgb;
	float lightness = dot(source,vec3(.2126,.7152,.0722));
	// The teal/sage jacket is isolated by its texture colour, preserving seams,
	// face, hair, ivory undershirt, trousers and shoes on one continuous surface.
	float peak = max(max(source.r, source.g), source.b);
	float chroma = female_style ? source.g - max(source.r,source.b) : min(source.g,source.b) - source.r;
	float mask = smoothstep(female_style ? .035 : .06, female_style ? .13 : .20, chroma / max(peak,.001));
	float reference_luma = female_style ? .125 : .065;
	ALBEDO = mix(source, garment_color.rgb * clamp(lightness / reference_luma, .22, 2.4), mask);
	ROUGHNESS = has_roughness ? texture(roughness_map,UV).g : roughness_value;
	METALLIC = 0.0;
	if (has_normal) NORMAL_MAP = texture(normal_map,UV).rgb;
}
