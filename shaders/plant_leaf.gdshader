shader_type spatial;
render_mode cull_disabled;
uniform float world_time = 0.0;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform float normal_strength=.22;
void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	// Authored leaf flutter, fixed at each leaf/needle base; shared world time.
	float root_coordinate = (has_albedo || has_normal) ? UV2.x : UV.x;
	float weight = root_coordinate * root_coordinate;
	VERTEX.y += sin(world_time*1.1+at.x*11.0+at.z*7.0)*weight*.002;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	if(has_albedo) ALBEDO *= .55+.9*dot(texture(albedo_map,UV).rgb,vec3(.2126,.7152,.0722));
	if (!FRONT_FACING) NORMAL = -NORMAL;
	if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
	ROUGHNESS = .84;
	BACKLIGHT = ALBEDO*.18;
}
