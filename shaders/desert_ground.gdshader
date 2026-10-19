shader_type spatial;
render_mode diffuse_burley;
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex(){ world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
 vec2 p=world_position.xz;
 float wash=1.0-smoothstep(3.0,8.2,abs(p.x-(8.0+3.0*sin(p.y*.055))));
 float broad=noise(p*.24),grain=noise(p*11.0);
 vec3 soil=mix(vec3(.25,.16,.086),vec3(.47,.34,.19),broad);
 vec3 gravel=mix(vec3(.27,.23,.17),vec3(.40,.33,.24),noise(p*.13));
 soil=mix(soil,gravel,wash*.78);
 float shoulder=smoothstep(.65,3.4,world_position.y)*(1.0-wash);
 soil=mix(soil,soil*vec3(.68,.70,.72),shoulder*.58);
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 ALBEDO=soil*(1.0+(grain-.5)*.29*(1.0-smoothstep(.07,.30,footprint)));
 ROUGHNESS=.96;
}
