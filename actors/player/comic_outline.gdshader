shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D normal_texture : hint_normal_roughness_texture, filter_nearest;

uniform float edge_thickness : hint_range(0.0, 5.0) = 1.0;
uniform float depth_threshold : hint_range(0.0, 5.0) = 0.05;
uniform float normal_threshold : hint_range(0.0, 5.0) = 0.5;
uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = vec2(edge_thickness) / VIEWPORT_SIZE;

	// Grab the screen color AND the alpha channel!
	vec4 screen_tex = texture(screen_texture, uv);
	vec3 screen_color = screen_tex.rgb;
	float screen_alpha = screen_tex.a; 

	float d_center = texture(depth_texture, uv).r;
	float d_up     = texture(depth_texture, uv + vec2(0.0, offset.y)).r;
	float d_down   = texture(depth_texture, uv + vec2(0.0, -offset.y)).r;
	float d_left   = texture(depth_texture, uv + vec2(-offset.x, 0.0)).r;
	float d_right  = texture(depth_texture, uv + vec2(offset.x, 0.0)).r;
	float depth_diff = abs(d_center - d_up) + abs(d_center - d_down) + abs(d_center - d_left) + abs(d_center - d_right);

	vec3 n_center = texture(normal_texture, uv).rgb;
	vec3 n_up     = texture(normal_texture, uv + vec2(0.0, offset.y)).rgb;
	vec3 n_down   = texture(normal_texture, uv + vec2(0.0, -offset.y)).rgb;
	vec3 n_left   = texture(normal_texture, uv + vec2(-offset.x, 0.0)).rgb;
	vec3 n_right  = texture(normal_texture, uv + vec2(offset.x, 0.0)).rgb;
	float normal_diff = length(n_center - n_up) + length(n_center - n_down) + length(n_center - n_left) + length(n_center - n_right);

	float edge = 0.0;
	if (depth_diff > depth_threshold * 0.01 || normal_diff > normal_threshold) {
		edge = 1.0;
	}

	//ALBEDO = mix(screen_color, outline_color.rgb, edge);
//
	//// The Magic Fix: If it's an edge, draw it solid. 
	//// Otherwise, use the original transparency of the viewport!
	//ALPHA = max(screen_alpha, edge);
	//ALPHA = 1.0;
	//ALPHA = 0.0;
	ALBEDO = outline_color.rgb; // Only use the black ink color
	ALPHA = edge; // If it's an edge, draw it solid (1.0). If not, make it 100% invisible (0.0)!
}