shader_type spatial;
render_mode cull_disabled;
uniform float world_time=0.0;
varying vec3 ground_position;
void vertex() { ground_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float grain=fract(sin(dot(floor(ground_position.xz*6.0),vec2(12.9898,78.233)))*43758.5453);
	float strata=.5+.5*sin(ground_position.y*5.0+ground_position.x*.19+sin(ground_position.z*.047)*2.0);
	ALBEDO=mix(vec3(.12,.105,.09),vec3(.26,.23,.19),grain*.25+strata*.36);
	ROUGHNESS=.97;
}
