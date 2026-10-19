// Rendering filter only. Physical position and body basis remain at shared JD.
// Average longitude when fast-forward skips visible surface detail per frame.
uniform float rotation_exposure_turns = 0.0;

float rotation_filter_weight() {
	return smoothstep(0.06, 0.25, abs(rotation_exposure_turns));
}

vec4 rotation_filtered_map(sampler2D image, vec2 uv, vec2 dx, vec2 dy) {
	vec4 sharp = textureGrad(image, uv, dx, dy);
	float weight = rotation_filter_weight();
	if (weight < 0.001) { return sharp; }
	float span = clamp(rotation_exposure_turns, -1.0, 1.0);
	// Sixteen bounded samples; a full-turn average uses fixed longitudes so it
	// cannot alias into another false apparent spin. It is a display filter,
	// not exact physical shutter integration or a separately slowed clock.
	vec4 blurred = vec4(0.0);
	for (int k = 0; k < 16; k++) {
		float longitude = abs(span) >= 0.999 ? (float(k) + 0.5) / 16.0 : uv.x + span * (float(k) + 0.5) / 16.0;
		// Keep original latitude resolution; longitude averaging already handles
		// temporal aliasing, without choosing a coarse isotropic mip level.
		blurred += textureGrad(image, vec2(longitude, uv.y), dx, dy);
	}
	return mix(sharp, blurred / 16.0, weight);
}
