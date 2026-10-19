shader_type spatial;
render_mode diffuse_burley;
// Reused CC0 rock photograph is an art surface, not regional geology data.
uniform sampler2D rock_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_position;
varying vec3 world_normal;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() {
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
 vec3 n=normalize(world_normal);
 vec3 weights=pow(abs(n),vec3(4.0));
 weights/=max(dot(weights,vec3(1.0)),.001);
 vec3 p=world_position;
 vec3 rock=texture(rock_color,p.yz).rgb*weights.x
          +texture(rock_color,p.xz).rgb*weights.y
          +texture(rock_color,p.xy).rgb*weights.z;
 rock*=vec3(.52,.40,.29)*(.78+.30*noise(world_position.xz*.035));
 // Match the existing basin soil at both mesh boundaries; no detached rim.
 vec2 ground=world_position.xz;
 float wash=1.0-smoothstep(3.0,8.2,abs(ground.x-(8.0+3.0*sin(ground.y*.055))));
 vec3 soil=mix(vec3(.25,.16,.086),vec3(.47,.34,.19),noise(ground*.24));
 soil=mix(soil,mix(vec3(.27,.23,.17),vec3(.40,.33,.24),noise(ground*.13)),wash*.78);
 float exposed=smoothstep(.02,.25,UV.y)*(1.0-smoothstep(.78,1.0,UV.y));
 ALBEDO=mix(soil,rock,exposed);
 ROUGHNESS=.94;
}
