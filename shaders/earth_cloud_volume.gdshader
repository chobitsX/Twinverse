shader_type fog;
uniform float world_time = 0.0;
uniform float cloud_density = 1.25;
float hash3(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise3(vec3 p) {
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void fog() {
	vec3 p=WORLD_POSITION*vec3(0.14,0.29,0.14)+vec3(world_time*0.0005,0,0);
	float macro=noise3(p*0.28+16.0);
	float detail=noise3(p)*0.56+noise3(p*2.08+11.0)*0.29+noise3(p*4.1)*0.15;
	float bottom=smoothstep(0.8,1.6,WORLD_POSITION.y);
	float top=1.0-smoothstep(3.8+macro*4.5,5.0+macro*4.5,WORLD_POSITION.y);
	float edge=smoothstep(0.0,0.12,UVW.x)*(1.0-smoothstep(0.88,1.0,UVW.x))*smoothstep(0.0,0.12,UVW.z)*(1.0-smoothstep(0.88,1.0,UVW.z));
	DENSITY=smoothstep(0.39,0.66,detail+macro*0.15)*bottom*top*edge*cloud_density;
	ALBEDO=vec3(0.96,0.97,1.0);
	EMISSION=vec3(0.009,0.012,0.017);
}
