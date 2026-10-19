shader_type spatial;
uniform float world_time = 0.0;
vec3 rotate_axis(vec3 p, vec3 axis, float angle) {
	return p*cos(angle)+cross(axis,p)*sin(angle)+axis*dot(axis,p)*(1.0-cos(angle));
}
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform float normal_strength=.22;
void vertex() {
	// glTF flips Blender's V coordinate. Each rod rotates about its own
	// fixed tubercle; the amplitudes/frequency are authored, not biomechanics.
	vec2 authored_uv=(has_albedo || has_normal) ? UV2 : UV;
	float phi = authored_uv.x*6.28318530718;
	float c = clamp(1.0-authored_uv.y,-1.0,1.0);
	float s = sqrt(max(0.0,1.0-c*c));
	vec3 anchor = vec3(.03*s*cos(phi),.021+.015*c,.03*s*sin(phi));
	vec3 axis = vec3(-sin(phi),0.0,cos(phi));
	float angle = .025*sin(world_time*.6+phi*3.0+c*2.0);
	VERTEX = anchor+rotate_axis(VERTEX-anchor,axis,angle);
	NORMAL = rotate_axis(NORMAL,axis,angle);
}
void fragment() {
	ALBEDO = COLOR.rgb;
	if(has_albedo) ALBEDO *= .55+.9*dot(texture(albedo_map,UV).rgb,vec3(.2126,.7152,.0722));
	if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
	ROUGHNESS = .36;
	SPECULAR = .40;
}
