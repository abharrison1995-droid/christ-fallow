shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec2 target_resolution = vec2(560.0, 315.0);
uniform float color_depth : hint_range(8.0, 64.0) = 28.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.65;
uniform float vignette_intensity : hint_range(0.0, 1.5) = 0.36;
uniform float grit_contrast : hint_range(0.8, 1.6) = 1.08;
uniform float desaturation : hint_range(0.0, 1.0) = 0.18;
uniform float brightness_boost : hint_range(0.8, 2.0) = 1.25;

float bayer4x4(vec2 cell) {
	int x = int(mod(cell.x, 4.0));
	int y = int(mod(cell.y, 4.0));
	mat4 bayer = mat4(
		vec4(0.0, 12.0,  3.0, 15.0),
		vec4(8.0,  4.0, 11.0,  7.0),
		vec4(2.0, 14.0,  1.0, 13.0),
		vec4(10.0, 6.0,  9.0,  5.0)
	);
	float val = 0.0;
	if (x == 0) {
		val = bayer[0][y];
	} else if (x == 1) {
		val = bayer[1][y];
	} else if (x == 2) {
		val = bayer[2][y];
	} else {
		val = bayer[3][y];
	}
	return (val / 16.0) - 0.5;
}

void fragment() {
	vec2 psx_cell = floor(SCREEN_UV * target_resolution);
	vec2 snapped_uv = (psx_cell + vec2(0.5)) / target_resolution;
	vec3 col = texture(screen_tex, snapped_uv).rgb;

	// Gamma lift + readable Diablo contrast & grading
	col = pow(max(col, vec3(0.0)), vec3(0.82)) * brightness_boost;
	col = clamp(col, 0.0, 1.0);

	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturation);
	col = clamp((col - 0.5) * grit_contrast + 0.5, 0.0, 1.0);

	// Subtle warm torch highlight / cool umber shadow split-tone
	vec3 shadow_tint = vec3(0.95, 0.92, 0.96);
	vec3 highlight_tint = vec3(1.04, 0.99, 0.90);
	col *= mix(shadow_tint, highlight_tint, clamp(luma * 1.25, 0.0, 1.0));

	// PSX ordered 4x4 Bayer dithering + color quantization
	float dither = bayer4x4(psx_cell) * (dither_strength / color_depth);
	col = clamp(col + vec3(dither), 0.0, 1.0);
	col = floor(col * color_depth + 0.5) / color_depth;

	// Lighter readable Diablo edge vignette
	vec2 centered = SCREEN_UV - vec2(0.5);
	float dist = dot(centered, centered) * 2.0;
	float vig = clamp(1.0 - dist * vignette_intensity, 0.48, 1.0);
	col *= vig;

	COLOR = vec4(col, 1.0);
}
