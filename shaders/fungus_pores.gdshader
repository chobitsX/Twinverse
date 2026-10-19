shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// UVs carry authored metres. These are pore-surface marks, not internal tubes.
uniform bool show_pores = true;
void fragment() {
	vec2 p = UV * 4500.0;
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	float detail = 1.0 - smoothstep(.45,1.2,footprint);
	p.x += mod(floor(p.y),2.0)*.5;
	vec2 q = fract(p)-.5;
	float d = length(q*vec2(1.0,1.12));
	float aa = max(.015,fwidth(d));
	float hole = (1.0-smoothstep(.23-aa,.29+aa,d))*detail;
	if (!show_pores) { hole = 0.0; }
	ALBEDO = mix(vec3(.62,.59,.48),vec3(.20,.18,.135),hole);
	ROUGHNESS = .93;
	SPECULAR = .15;
}
