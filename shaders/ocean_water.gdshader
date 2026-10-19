shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/ocean_air.gdshaderinc"

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform float world_time = 0.0;
uniform float immersion = 0.0;
uniform float surface_visibility = 1.0;
// Bound by the ocean owner to the same current distance-fog density.
uniform float underwater_fog_density = 0.0;
uniform vec3 light_direction = vec3(-0.3, 0.86, -0.2);
varying vec3 world_position;

// Authored directional wave field. Long waves alone displace the mesh;
// sub-mesh ripples use analytic slopes with footprint filtering.
// Twelve authored ripple directions break long repeated highlights; these are
// visual parameters, not a measured wind spectrum or authoritative simulation.
vec3 swell(vec2 p, float t) {
	vec2 a = normalize(vec2(0.96,0.28));
	vec2 b = normalize(vec2(-0.38,0.92));
	vec2 c = normalize(vec2(0.57,0.82));
	float pa = dot(p,a)*1.208 + t*0.84;
	float pb = dot(p,b)*1.698 - t*1.17 + 3.1;
	float pc = dot(p,c)*2.244 + t*1.42 + 1.7;
	float h = sin(pa)*0.028 + sin(pb)*0.018 + sin(pc)*0.008;
	vec2 slope = a*cos(pa)*0.028*1.208 + b*cos(pb)*0.018*1.698 + c*cos(pc)*0.008*2.244;
	return vec3(h,slope);
}
vec2 ripple(vec2 p, vec2 direction, float frequency, float amplitude, float phase, float footprint) {
	float fade = 1.0 - smoothstep(0.8,2.4,frequency*footprint);
	return direction*cos(dot(p,direction)*frequency+phase)*amplitude*fade;
}
void vertex() {
	vec3 wave = swell(VERTEX.xz,world_time*0.7);
	// The sparse horizon ring carries shading detail without undersampled displacement.
	float geometry_weight = 1.0 - smoothstep(32.0, 40.0, max(abs(VERTEX.x), abs(VERTEX.z)));
	VERTEX.y += wave.x * geometry_weight;
	NORMAL = normalize(vec3(-wave.y,1.0,-wave.z));
	world_position = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float t = world_time*0.7;
	float footprint = max(length(dFdx(p)),length(dFdy(p)));
	vec2 slope = ripple(p,normalize(vec2(0.96,0.28)),1.208,0.028*1.208,t*0.84,footprint);
	slope += ripple(p,normalize(vec2(-0.38,0.92)),1.698,0.018*1.698,-t*1.17+3.1,footprint);
	slope += ripple(p,normalize(vec2(0.57,0.82)),2.244,0.008*2.244,t*1.42+1.7,footprint);
	slope += ripple(p,vec2(0.927183855,0.374606593),4.200,0.030,-t*2.760117715+0.000000000,footprint);
	slope += ripple(p,vec2(-0.224951054,0.974370065),4.900,0.028,-t*2.981267868+2.399963230,footprint);
	slope += ripple(p,vec2(0.694658370,-0.719339800),6.100,0.026,-t*3.326349486+4.799926459,footprint);
	slope += ripple(p,vec2(0.390731128,0.920504853),7.600,0.024,-t*3.712870103+0.916704382,footprint);
	slope += ripple(p,vec2(0.996194698,-0.087155743),9.200,0.022,-t*4.085045263+3.316667612,footprint);
	slope += ripple(p,vec2(-0.754709580,0.656059029),11.900,0.020,-t*4.645970415+5.716630841,footprint);
	slope += ripple(p,vec2(0.788010754,0.615661475),15.300,0.018,-t*5.268035279+1.833408764,footprint);
	slope += ripple(p,vec2(0.275637356,-0.961261696),19.700,0.016,-t*5.977726934+4.233371994,footprint);
	slope += ripple(p,vec2(0.052335956,0.998629535),25.100,0.014,-t*6.747452253+0.350149916,footprint);
	slope += ripple(p,vec2(-0.927183855,0.374606593),32.900,0.012,-t*7.725043048+2.750113146,footprint);
	slope += ripple(p,vec2(0.990268069,0.139173101),42.100,0.010,-t*8.738643196+5.150076376,footprint);
	slope += ripple(p,vec2(-0.438371147,0.898794046),53.800,0.008,-t*9.878570352+1.266854298,footprint);
	// Authored wind patches soften uniform short-wave bands.
	float wind_patch = 0.82 + 0.18 * sin(p.x * 0.43 + sin(p.y * 0.29));
	slope *= wind_patch;
	vec3 normal_world = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	float d = texture(depth_texture, SCREEN_UV).r;
	vec4 view_position = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	view_position.xyz /= view_position.w;
	float thickness = max(0.0, -view_position.z + VERTEX.z) / max(abs(normalize(VERTEX).z), 0.15);
	// The opaque screen already carries camera-to-object underwater fog.
	// Hand surface absorption to that volume continuously; the back face looks into air.
	thickness *= FRONT_FACING ? (1.0 - immersion) : 0.0;
	float presence = surface_visibility * smoothstep(0.018, 0.16, length(VERTEX));
	// The opaque screen already carries underwater distance fog. Fade the
	// interface contribution with its camera path instead of fogging that image twice.
	if (underwater_fog_density > 0.0) {
		presence *= exp(-length(VERTEX) * underwater_fog_density);
	}
	// Partial coverage blends with the original opaque image. Keep both
	// silhouettes aligned until the interface is nearly fully visible.
	vec2 offset = NORMAL.xy * 0.012 * min(thickness, 1.0) * smoothstep(0.92, 1.0, presence);
	vec2 edge = min(SCREEN_UV, vec2(1.0) - SCREEN_UV);
	offset *= smoothstep(0.0, 0.025, min(edge.x, edge.y));
	vec2 refraction_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
	// Do not refract an opaque object that lies in front of this water fragment.
	vec4 offset_position = INV_PROJECTION_MATRIX * vec4(refraction_uv * 2.0 - 1.0, texture(depth_texture, refraction_uv).r, 1.0);
	if (offset_position.z / offset_position.w > VERTEX.z) { refraction_uv = SCREEN_UV; }
	vec3 refracted = texture(screen_texture, refraction_uv).rgb;
	vec3 transmittance = exp(-vec3(0.32, 0.095, 0.042) * min(thickness, 24.0));
	vec3 water_scatter = vec3(0.008, 0.060, 0.095);
	float fresnel = 0.02 + 0.98 * pow(1.0 - clamp(dot(NORMAL, normalize(VIEW)), 0.0, 1.0), 5.0);
	// The screen texture already contains lit opaque geometry. Relighting it as
	// diffuse ALBEDO washed the reef out; keep transmitted radiance in EMISSION.
	ALBEDO = vec3(0.0);
	EMISSION = (refracted * transmittance + water_scatter * (1.0 - transmittance)) * (1.0 - fresnel);
	ROUGHNESS = 0.14 + min(footprint * 0.26, 0.19);
	METALLIC = 0.0;
	SPECULAR = 0.35;
	// The interface must not fog its already-fogged underwater screen sample.
	// Above water, a separate air path brings distant reflection into the same
	// horizon radiance as the sky instead of leaving a dark band at grazing angles.
	float air_path = max(length(VERTEX) - 20.0, 0.0);
	vec3 sightline = normalize(world_position - CAMERA_POSITION_WORLD);
	FOG = vec4(ocean_air_horizon(sightline, normalize(light_direction)), (1.0 - exp(-air_path * 0.025)) * (1.0 - immersion));
	// Fade within the wave band and before near clipping; transparent water
	// must not leave an invisible depth occluder for fish fins or particles.
	ALPHA = presence;
}
