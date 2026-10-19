shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform bool has_normal = false;
uniform float world_phase = 0.0;
uniform float flying = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness_value = 0.65;

vec3 feather_pose(vec3 p) {
	float span = abs(p.z);
	float wing = smoothstep(0.029, 0.048, span);
	float side = p.z < 0.0 ? -1.0 : 1.0;
	float along = clamp((span - 0.028) / 0.151, 0.0, 1.0);
	vec3 folded = p;
	folded.x -= 0.135 * along;
	folded.z = side * (0.028 + 0.006 * along);
	folded.y = mix(p.y, 0.118 - 0.013 * along, wing);
	vec3 posed = mix(p, folded, wing * (1.0 - flying));
	float flap = side * sin(world_phase) * 0.60 * flying * wing;
	vec2 offset = posed.yz - vec2(0.125, side * 0.028);
	posed.yz = vec2(cos(flap)*offset.x - sin(flap)*offset.y,
		sin(flap)*offset.x + cos(flap)*offset.y) + vec2(0.125, side*0.028);
	return posed;
}

void vertex() {
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	vec3 t = normalize(abs(n.y) < 0.95 ? cross(n,vec3(0.0,1.0,0.0)) : cross(n,vec3(1.0,0.0,0.0)));
	vec3 b = cross(n,t);
	vec3 at = feather_pose(p);
	NORMAL = normalize(cross(feather_pose(p+t*0.0001)-at,feather_pose(p+b*0.0001)-at));
	VERTEX = at;
}

void fragment() {
	ALBEDO = texture(albedo_map,UV).rgb * tint.rgb;
	ROUGHNESS = roughness_value;
	METALLIC = 0.0;
	if (has_normal) NORMAL_MAP = texture(normal_map,UV).rgb;
}
