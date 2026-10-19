shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// Original display texture; stock_fraction is relative stock, not measured cover.
uniform float stock_fraction : hint_range(0.0,1.0) = .9;
uniform float world_time = 0.0;
varying vec3 local_at;
varying vec3 world_at;
float grain(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float field(vec2 p) {
	vec2 c=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(grain(c),grain(c+vec2(1,0)),f.x),mix(grain(c+vec2(0,1)),grain(c+vec2(1,1)),f.x),f.y);
}
void vertex() {
	local_at=VERTEX;
	world_at=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	float mosaic=field(local_at.xz*22.0);
	float turf=(1.0-smoothstep(stock_fraction-.05,stock_fraction+.05,mosaic))*smoothstep(-.15,.20,local_at.y);
	float fibres=field(local_at.xz*180.0);
	vec3 rock=vec3(.36,.34,.26)*(0.78+.32*mosaic);
	vec3 algae=mix(vec3(.075,.15,.035),vec3(.30,.40,.095),fibres);
	float ripple=sin(world_at.x*18.0+world_time*.7)*sin(world_at.z*17.0-world_time*.5);
	ALBEDO=mix(rock,algae,turf)*(1.0+.06*ripple);
	ROUGHNESS=.93;
}
