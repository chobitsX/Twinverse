shader_type spatial;
render_mode unshaded,blend_add,depth_draw_never,cull_disabled,fog_disabled;
uniform float night_strength = 1.0;
uniform float world_time = 0.0;
varying vec3 direction;
void vertex() {
	vec3 center=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xyz;
	direction=normalize(center-CAMERA_POSITION_WORLD);
	vec3 p=(VIEW_MATRIX*vec4(center,1.0)).xyz;
	float pixels=clamp(length(MODEL_MATRIX[0].xyz)*3.0,1.5,10.0);
	float size=pixels*2.0*abs(p.z)/max(VIEWPORT_SIZE.y*abs(PROJECTION_MATRIX[1][1]),1.0);
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*size,INV_VIEW_MATRIX[1]*size,INV_VIEW_MATRIX[2]*size,vec4(center,1.0));
}
void fragment() {
	float r=length(UV-.5)*2.0;
	float core=exp(-r*r*24.0);
	float halo=exp(-r*r*4.0)*.13;
	float horizon=smoothstep(0.012,0.10,direction.y);
	float scintillation=1.0+.045*sin(world_time*1.4+direction.x*67.0+direction.z*31.0)*(1.0-horizon);
	ALBEDO=COLOR.rgb*(core*2.2+halo);
	ALPHA=clamp(COLOR.a*(1.0-smoothstep(.72,1.0,r))*night_strength*horizon*scintillation,0.0,1.0);
}
