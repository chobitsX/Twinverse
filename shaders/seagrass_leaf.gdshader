shader_type spatial;
render_mode cull_disabled;
uniform float world_time = 0.0;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform float normal_strength=.22;
void vertex() {
	// Small authored current sway. All parts share one continuous deformation;
	// buried roots stay fixed and no new simulation clock is introduced.
	vec3 origin = MODEL_MATRIX[3].xyz;
	float weight = clamp(VERTEX.y / .03, 0.0, 1.0);
	float sway = sin(world_time * .8 + origin.x * 2.0 + origin.z * 3.0) * .0008;
	VERTEX.x += sway * weight * weight;
	if (weight > 0.0 && weight < 1.0) NORMAL.y -= NORMAL.x * sway * 2.0 * weight / .03;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	if(has_albedo) ALBEDO *= .55+.9*dot(texture(albedo_map,UV).rgb,vec3(.2126,.7152,.0722));
	if (!FRONT_FACING) NORMAL = -NORMAL;
	if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
	ROUGHNESS = .65;
	BACKLIGHT = ALBEDO * .20;
}
