shader_type spatial;
render_mode cull_disabled;

uniform float world_time = 0.0;
uniform vec4 base_color : source_color = vec4(0.42, 0.26, 0.14, 1.0);
uniform bool use_vertex_color = false;
uniform bool skin_color_comparison = false;
uniform float pale_amount : hint_range(0.0, 1.0) = 0.0;
uniform float surface_roughness : hint_range(0.0, 1.0) = 0.7;

uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform float normal_strength=.22;
void vertex() {
	// One continuous field moves the arm and its cup geometry together. It
	// fades out at the head/web and reads the host's time, never shader TIME.
	vec2 p = VERTEX.xz - vec2(0.030, 0.0);
	float r = max(length(p), 0.0001);
	float u = clamp((r - 0.15) / 0.37, 0.0, 1.0);
	float w = u * u * (3.0 - 2.0 * u);
	float phase = world_time * 0.39269908 + 2.0 * atan(p.y, p.x);
	float f = 0.007 * w * sin(phase);
	float dw = 6.0 * u * (1.0 - u) / 0.37;
	vec2 gradient = 0.007 * (dw * p / r * sin(phase)
		+ w * cos(phase) * 2.0 * vec2(-p.y, p.x) / (r * r));
	VERTEX.y += f;
	NORMAL = normalize(vec3(NORMAL.x - NORMAL.y * gradient.x,
		NORMAL.y, NORMAL.z - NORMAL.y * gradient.y));
}

void fragment() {
	vec3 pigment = use_vertex_color ? COLOR.rgb : base_color.rgb;
	if(has_albedo) pigment *= .55+texture(albedo_map,UV).rgb*.9;
	if (skin_color_comparison) {
		// Preserve the authored mottles under the bright reef exposure.
		float mottle = smoothstep(0.33, 0.48, pigment.r);
		pigment = mix(vec3(0.075, 0.035, 0.014), vec3(0.48, 0.265, 0.11), mottle);
		vec3 pale = vec3(0.56, 0.45, 0.30) + (pigment - vec3(0.28, 0.15, 0.06)) * 0.35;
		pigment = mix(pigment, pale, pale_amount);
	}
	ALBEDO = pigment;
	if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
	ROUGHNESS = surface_roughness;
	SPECULAR = 0.32;
}
