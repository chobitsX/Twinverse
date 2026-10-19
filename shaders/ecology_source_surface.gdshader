shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_normal=false;
uniform int species=0;
varying vec3 local_at;
void vertex(){local_at=(species==1 || species==2) ? vec3(UV2,0.0) : VERTEX;}
void fragment(){
	vec3 raw=texture(albedo_map,UV).rgb;
	float luma=dot(raw,vec3(.2126,.7152,.0722));
	vec3 pigment=raw;
	if(species==1){
		float belly=clamp((.078-local_at.y)/.044,0.,1.);
		vec3 coat=mix(vec3(.25,.15,.072),vec3(.65,.55,.40),belly);
		pigment=coat*(.68+.6*luma);
		if(local_at.x>.07 && local_at.y>.10 && luma<.13) pigment=raw;
	}else if(species==2){
		// Remove only the source's male-like white collar and yellow bill.
		// Fine mottled body feathers and the blue speculum keep their texture.
		float collar=smoothstep(.275,.293,local_at.y)*(1.-smoothstep(.335,.350,local_at.y));
		collar*=smoothstep(.09,.12,local_at.x)*(1.-smoothstep(.215,.25,local_at.x));
		pigment=mix(raw,vec3(.20,.105,.038)*(.72+.80*luma),collar);
		if(local_at.x>.20 && local_at.y>.34 && luma>.04)
			pigment=mix(raw,vec3(.32,.078,.014)*(.66+.55*luma),smoothstep(.20,.22,local_at.x));
	}else if(species==3){
		float belly=clamp((-local_at.y-.08)/.16,0.,1.);
		pigment=mix(vec3(.13,.08,.038),vec3(.44,.35,.23),belly)*(.65+.70*luma);
		if(local_at.x>.28 && luma<.065) pigment=raw;
	}
	ALBEDO=pigment;
	if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=.18;}
	ROUGHNESS=.72;
	SPECULAR=.27;
}
