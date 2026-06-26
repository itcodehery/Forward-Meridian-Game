shader_type canvas_item;

// How much the HUD curves inward (concave visor). 0 = flat.
uniform float curvature : hint_range(0.0, 1.0, 0.01) = 0.12;
// Zoom to compensate for edge pull. Decrease if content gets too small.
uniform float zoom : hint_range(0.5, 1.5, 0.01) = 0.94;

void fragment() {
	// Center UV and pre-scale for zoom compensation
	vec2 uv = (UV - 0.5) / zoom;

	// Pincushion distortion: edges pull inward like a concave visor
	float r2 = dot(uv, uv);
	uv *= 1.0 - curvature * r2;

	// Map back to texture space
	uv += 0.5;

	// Transparent for out-of-bounds
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv);
	}
}
