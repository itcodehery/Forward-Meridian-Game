shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 5.0) = 2.5;

void fragment() {
	// Grabs the screen behind the UI and blurs it
	COLOR = textureLod(screen_texture, SCREEN_UV, blur_amount);
	// Optional: darkens the blurred image slightly so white text is easier to read
	COLOR.rgb *= 0.3; 
}