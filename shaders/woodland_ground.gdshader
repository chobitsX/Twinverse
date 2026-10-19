shader_type spatial;
uniform sampler2D litter_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D litter_arm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bank_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 p;
float h(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float n(vec2 q){vec2 a=floor(q),b=fract(q);b=b*b*(3.-2.*b);return mix(mix(h(a),h(a+vec2(1,0)),b.x),mix(h(a+vec2(0,1)),h(a+vec2(1,1)),b.x),b.y);}
void vertex(){p=VERTEX;}
void fragment(){
 vec2 uv=p.xz*.5;
 vec3 tex=texture(litter_color,uv).rgb;
 float macro=n(p.xz*.16)*.65+n(p.xz*.055)*.35;
 float meadow=1.-smoothstep(10.,26.,length(p.xz-vec2(3,-2)));
 vec3 grass_tint=vec3(.34,.40,.14)*(0.65+.6*macro);
 tex=mix(tex,tex*vec3(.65,.82,.34)+grass_tint*.13,meadow*.62);
 float damp=1.-smoothstep(-.58,.0,p.y);
 ALBEDO=tex*vec3(.52,.60,.42)*(.72+.42*macro)*(1.-damp*.30);
 // Existing rock colour gives a restrained mineral bank between water and
 // litter. The band follows the actual terrain height, not a painted river path.
 float bank=1.-smoothstep(-.42,.05+(macro-.5)*.18,p.y);
 vec3 mineral=texture(bank_color,p.xz*1.4).rgb*vec3(.46,.40,.29);
 ALBEDO=mix(ALBEDO,mineral*(1.-damp*.32),bank*.85);
 NORMAL_MAP=texture(litter_normal,uv).rgb; NORMAL_MAP_DEPTH=.55;
 vec3 arm=texture(litter_arm,uv).rgb;
 AO=mix(1.,arm.r,.65);ROUGHNESS=mix(max(.72,arm.g),.6,damp);
}
