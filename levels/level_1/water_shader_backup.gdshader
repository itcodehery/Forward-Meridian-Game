shader_type spatial;
// specular_toon makes the light reflections snap into hard, comic-style bands
render_mode blend_mix, specular_toon;

uniform vec4 water_color : source_color = vec4(0.0, 0.8, 0.4, 0.8); // Toxic Green!
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0); // Pure White

// Grabs the depth of the level behind the water
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform float foam_thickness : hint_range(0.0, 2.0) = 0.3;

// The moving surface ripples
uniform sampler2D noise_texture;
uniform vec2 wave_speed = vec2(2, 4);
uniform float wave_threshold : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	// 1. Calculate exactly how deep the water is at this exact pixel
	float depth_raw = texture(depth_texture, SCREEN_UV).r;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth_raw);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float depth_blend = -view.z - (-VERTEX.z);

	// 2. EDGE FOAM: If the water depth is very shallow (touching a wall), draw foam!
	// 'step' is the magic comic-book function. It forces the gradient into a hard, solid line.
	float is_foam = step(depth_blend, foam_thickness);

	// 3. SURFACE WAVES: Scroll a noise texture over time to fake ripples
	float noise_val = texture(noise_texture, UV * 5.0 + TIME * wave_speed).r;
	// Another 'step' to make the ripples look like hard, hand-drawn comic shapes
	float wave_foam = step(wave_threshold, noise_val);

	// 4. Paint the final picture
	vec3 final_color = mix(water_color.rgb, foam_color.rgb, clamp(is_foam + wave_foam * 0.5, 0.0, 1.0));

	ALBEDO = final_color;
	ALPHA = water_color.a; // Use the alpha from the color picker!
	ROUGHNESS = 1.0; // Blurs out the sky reflection completely
	SPECULAR = 0.0;  // Stops it from acting like a realistic mirror
}