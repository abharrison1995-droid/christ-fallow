shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

// Depth-safe & fog-safe PSX spatial shader for skinned Skeleton3D characters.
// Applies screen-space XY vertex snapping while keeping clip-space Z/W untouched
// so Forward+ hardware depth buffers, shadow maps, and distance fog remain pristine.

// PSX screen-space vertex snapping & jitter parameters
uniform bool enable_jitter = true;
uniform vec2 snap_resolution = vec2(320.0, 240.0);
uniform float jitter_intensity : hint_range(0.0, 1.0) = 0.45;

// Surface material controls
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.92;

// Faction & palette color customization
uniform vec4 faction_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float faction_tint_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool use_palette_lut = false;
uniform sampler2D palette_lut : source_color, filter_nearest;
uniform int palette_row = 0;
uniform int total_palette_rows = 16;

// Emission (for Ash-Walker ember tattoos / eyes)
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;

void vertex() {
	// Godot 4 automatically applies Skeleton3D GPU skinning to VERTEX before this function runs.
	vec4 view_pos = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vec4 clip_pos = PROJECTION_MATRIX * view_pos;

	if (enable_jitter && snap_resolution.x > 0.0 && snap_resolution.y > 0.0) {
		// Snap ONLY screen-space (X, Y) normalized device coordinates (NDC).
		// Leaving clip_pos.z and clip_pos.w untouched preserves the hardware depth buffer,
		// shadow map cascades, SSAO, and Forward+ volumetric/distance fog.
		vec2 ndc = clip_pos.xy / clip_pos.w;
		vec2 snap_grid = floor(snap_resolution * (1.0 - jitter_intensity * 0.7));
		snap_grid = max(snap_grid, vec2(1.0));
		vec2 snapped_ndc = floor(ndc * snap_grid + 0.5) / snap_grid;
		clip_pos.xy = snapped_ndc * clip_pos.w;
	}

	POSITION = clip_pos;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	vec4 col = tex * base_color;

	if (use_palette_lut) {
		// Index into LUT using Red channel of albedo texture
		float y_coord = (float(palette_row) + 0.5) / float(max(total_palette_rows, 1));
		vec4 lut_col = texture(palette_lut, vec2(tex.r, y_coord));
		col = lut_col * base_color;
	}

	if (faction_tint_strength > 0.0) {
		col.rgb = mix(col.rgb, col.rgb * faction_tint.rgb, faction_tint_strength);
	}

	ALBEDO = col.rgb;
	ROUGHNESS = max(roughness, 0.86);
	SPECULAR = 0.0;

	if (emission_energy > 0.0) {
		EMISSION = emission_color.rgb * emission_energy;
	}
}
