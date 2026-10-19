shader_type spatial;
render_mode cull_disabled;
uniform vec4 season_color:source_color=vec4(.77,.55,.12,1.);
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic;
uniform bool has_albedo=false;
uniform bool has_normal=false;
uniform float normal_strength=.22;
void fragment(){
 float detail=has_albedo ? dot(texture(albedo_map,UV).rgb,vec3(.2126,.7152,.0722)) : dot(COLOR.rgb,vec3(.2126,.7152,.0722));
 ALBEDO=season_color.rgb*clamp(.68+detail,.70,1.25);
 if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=normal_strength;}
 if(!FRONT_FACING) NORMAL=-NORMAL;
 ROUGHNESS=.78;
 BACKLIGHT=ALBEDO*.15;
}
