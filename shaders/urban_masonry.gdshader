shader_type spatial;
// Original metre-space surface patterns, authored palette rather than measured reflectance.
uniform vec4 wall_color : source_color = vec4(.56,.33,.27,1.);
uniform vec4 joint_color : source_color = vec4(.53,.49,.43,1.);
uniform int finish_kind = 0;
varying vec3 point;
varying vec3 face_normal;
float hash2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void vertex() { point=VERTEX; face_normal=NORMAL; }
void fragment() {
	vec2 p=vec2(abs(face_normal.x)>.5?point.z:point.x,point.y);
	vec2 unit=finish_kind==0?vec2(.24,.075):vec2(1.2,.63);
	float row=floor(p.y/unit.y);
	vec2 grid=p/unit;
	if(finish_kind==0) grid.x+=mod(row,2.)*.5;
	vec2 cell=fract(grid);
	vec2 edge=min(cell,1.-cell)*unit;
	vec2 aa=max(fwidth(p),vec2(.0001));
	float gap=finish_kind==0?.0035:.002;
	float inside=smoothstep(gap-aa.x,gap+aa.x,edge.x)*smoothstep(gap-aa.y,gap+aa.y,edge.y);
	float resolve=1.-smoothstep(.012,.055,max(aa.x,aa.y));
	float joint=(1.-inside)*resolve*(1.-step(.5,abs(face_normal.y)));
	float tile=hash2(floor(grid));
	float tone=mix(1.,.90+tile*.18,resolve);
	// Plaster stays continuous; only brick and cladding retain course/joint lines.
	if(finish_kind==1) joint=0.;
	float grain=(hash2(floor(p*230.))-.5)*.045*resolve;
	ALBEDO=mix(wall_color.rgb*tone,joint_color.rgb,joint)*(1.+grain);
	ROUGHNESS=finish_kind==2?.67:.88;
}
