shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
// A visible proxy on the existing living tissue, not a radiative-transfer model.
uniform vec4 tissue_color : source_color = vec4(.22,.13,.065,1.0);
uniform bool vertex_pigment = false;
uniform float tissue_roughness = .7;
uniform float symbiont_proxy : hint_range(0.,1.) = 1.;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform float normal_strength=.22;
void fragment() {
	vec3 original = tissue_color.rgb;
	if (vertex_pigment) { original *= COLOR.rgb; }
	if(has_albedo) original *= texture(albedo_map,UV).rgb;
	vec3 pale = vec3(.70,.72,.65);
	ALBEDO = mix(pale,original,clamp(symbiont_proxy,0.,1.));
	if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
	ROUGHNESS = tissue_roughness;
	SPECULAR = .32;
}
