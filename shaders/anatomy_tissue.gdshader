shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
#include "res://shaders/anatomy_deform.gdshaderinc"

uniform sampler2D base_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tissue_color : source_color = vec4(0.55, 0.13, 0.12, 1.0);
uniform bool has_base_texture = false;
uniform bool has_normal_texture = false;
uniform float tissue_roughness = 0.42;
uniform float normal_strength = 0.35;
uniform float translucency = 0.08;
uniform vec3 selected_center = vec3(0.0);
uniform float selected_radius = 0.0;
varying vec3 anatomy_rest_position;

// Rest-space pigment stays attached while the common beat deforms the organ.
// These are authored material variations, not a histology or vascular map.
float tissue_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float tissue_noise(vec3 p) {
	vec3 cell = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float value = mix(mix(mix(tissue_hash(cell), tissue_hash(cell + vec3(1,0,0)), f.x),
		mix(tissue_hash(cell + vec3(0,1,0)), tissue_hash(cell + vec3(1,1,0)), f.x), f.y),
		mix(mix(tissue_hash(cell + vec3(0,0,1)), tissue_hash(cell + vec3(1,0,1)), f.x),
		mix(tissue_hash(cell + vec3(0,1,1)), tissue_hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
	float footprint = max(length(dFdx(p)), length(dFdy(p)));
	return (value - 0.5) * (1.0 - smoothstep(0.35, 1.0, footprint));
}

void vertex() {
	vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	anatomy_rest_position = p;
	vec3 q = anatomy_position(p);
	float e = 0.001;
	mat3 jacobian = mat3(
		(anatomy_position(p + vec3(e, 0.0, 0.0)) - q) / e,
		(anatomy_position(p + vec3(0.0, e, 0.0)) - q) / e,
		(anatomy_position(p + vec3(0.0, 0.0, e)) - q) / e);
	vec3 world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_normal = normalize(transpose(inverse(jacobian)) * world_normal);
	NORMAL = normalize(transpose(mat3(MODEL_MATRIX)) * world_normal);
	// Tangent-space relief must follow the same deformation as the geometric
	// normal. Leaving its basis at rest rotates the highlight during a beat.
	if (dot(TANGENT, TANGENT) > 0.0001 && dot(BINORMAL, BINORMAL) > 0.0001) {
		vec3 world_tangent = jacobian * (mat3(MODEL_MATRIX) * TANGENT);
		vec3 world_binormal = jacobian * (mat3(MODEL_MATRIX) * BINORMAL);
		world_tangent = normalize(world_tangent - world_normal * dot(world_tangent, world_normal));
		world_binormal = normalize(world_binormal - world_normal * dot(world_binormal, world_normal)
			- world_tangent * dot(world_binormal, world_tangent));
		TANGENT = normalize(inverse(mat3(MODEL_MATRIX)) * world_tangent);
		BINORMAL = normalize(inverse(mat3(MODEL_MATRIX)) * world_binormal);
	}
	VERTEX = (inverse(MODEL_MATRIX) * vec4(q, 1.0)).xyz;
}

void fragment() {
	vec3 pigment = tissue_color.rgb;
	if (has_base_texture) { pigment *= texture(base_texture, UV).rgb; }
	float mottle = tissue_noise(anatomy_rest_position * 27.0);
	float grain = tissue_noise(anatomy_rest_position * vec3(190.0, 72.0, 190.0) + vec3(9.7));
	float luminance = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
	pigment = mix(vec3(luminance), pigment, 0.68);
	// Broad, attached tissue bundles give the surfaces a common organic finish.
	// They illustrate material structure; they are not a histological fibre map.
	float bundle_phase = dot(anatomy_rest_position, vec3(145.0, 52.0, 81.0)) + mottle * 2.8;
	float bundle = sin(bundle_phase) * (1.0 - smoothstep(0.6, 2.0, fwidth(bundle_phase)));
	ALBEDO = pigment * (1.0 + mottle * 0.22 + grain * 0.035 + bundle * 0.025);
	// Fine detail lives mainly in the normal map. Keep the broad specular lobe
	// smooth instead of turning every pigment fleck into an isolated glint.
	ROUGHNESS = clamp(tissue_roughness + 0.065 + mottle * 0.075, 0.55, 0.76);
	METALLIC = 0.0;
	SPECULAR = 0.20;
	// The tissue lobe already represents the moist interface. A second coat
	// gives the cutaway an even varnish unrelated to its local roughness.
	CLEARCOAT = 0.0;
	SSS_STRENGTH = translucency;
	if (has_normal_texture) {
		NORMAL_MAP = texture(normal_texture, UV).rgb;
		NORMAL_MAP_DEPTH = normal_strength;
	}
	float focus = (1.0 - smoothstep(selected_radius * 0.55, max(selected_radius, 0.0001), distance(anatomy_rest_position, selected_center))) * step(0.0001, selected_radius);
	EMISSION = vec3(0.18, 0.075, 0.025) * focus;
}
