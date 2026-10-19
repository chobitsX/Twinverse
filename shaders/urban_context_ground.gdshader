shader_type spatial;
varying vec2 point;
float h(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 p){vec2 i=floor(p), f=fract(p);f=f*f*(3.-2.*f);return mix(mix(h(i),h(i+vec2(1,0)),f.x),mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x),f.y);}
void vertex(){point=(MODEL_MATRIX*vec4(VERTEX,1.)).xz;}
void fragment(){
	float distance_from_center=max(abs(point.x),abs(point.y));
	float outer=smoothstep(115.,195.,distance_from_center);
	float near_detail=n(point*.8)*.5+n(point*4.)*.3+n(point*26.)*.2;
	float far_detail=n(point*.022)*.7+n(point*.17)*.3;
	vec3 color=mix(vec3(.49,.49,.42),vec3(.24,.31,.17),outer);
	ALBEDO=color*mix(.75+near_detail*.45,.83+far_detail*.25,outer);
	ROUGHNESS=.95;
}
