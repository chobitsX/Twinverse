// Authored dense fin pigmentation; geometric rays carry the principal ribs.
// glTF flips Blender's V. Both root and thin-edge pieces use the same field.
vec4 fin_surface(vec2 uv) {
	float u = uv.x;
	float v = 1.0 - uv.y;
	float edge_start = 0.83 + 0.020 * sin(u * 9.7) + 0.006 * sin(u * 22.3);
	float aa = max(fwidth(v), 0.0005);
	float margin = smoothstep(edge_start - aa, edge_start + 0.070 + aa, v);
	float root_shade = 0.88 + 0.12 * smoothstep(0.02, 0.32, v);
	float fiber = sin(u * 565.5 + sin(v * 7.0) * 0.55);
	float fiber_weight = 1.0 - smoothstep(0.5, 2.0, fwidth(u) * 565.5);
	float pigment_depth = 0.96 + 0.045 * sin(u * 13.1 + v * 4.2) + 0.025 * sin(u * 29.7 - v * 8.4);
	vec3 pigment = vec3(0.67, 0.33, 0.09) * root_shade * pigment_depth * (1.0 + fiber * fiber_weight * 0.055);
	// Pigment thickens gradually toward the margin; the last transparent edge
	// and all root/ray UV sampling stay shared to preserve the existing joins.
	pigment = mix(pigment, vec3(0.070, 0.055, 0.034) * pigment_depth, margin);
	vec3 linear_color = mix(pigment / 12.92, pow((pigment + 0.055) / 1.055, vec3(2.4)), greaterThan(pigment, vec3(0.04045)));
	// Dense pigment absorbs the body bars behind the membrane. A 5% neutral
	// transmission made those bars read as a second painted pattern on the fin.
	float opacity = mix(1.0, 0.995, smoothstep(0.25, 0.65, v));
	opacity = mix(opacity, 0.997, margin);
	// Only the terminal membrane tapers to zero coverage, keeping a genuine
	// translucent edge while avoiding the old see-through fabric appearance.
	opacity *= 1.0 - smoothstep(0.988 - aa, 1.0, v);
	return vec4(linear_color, opacity);
}
