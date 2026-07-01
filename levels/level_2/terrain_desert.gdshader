shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// ---------------------------------------------------------
// Height bands
// ---------------------------------------------------------
// Each band has its own color. Bands blend into each other based on
// world-space height, with an adjustable blend sharpness per transition.

group_uniforms Height_Bands;
uniform float base_height   = 0.0;   // World Y where the lowest color starts
uniform float rock_height   = 8.0;   // World Y where bare rock starts taking over
uniform float snow_height   = 18.0;  // World Y where snow starts taking over
uniform float blend_sharpness : hint_range(0.5, 20.0) = 4.0; // Higher = crisper transitions

uniform vec3 low_color   : source_color = vec3(0.20, 0.28, 0.10); // valley grass
uniform vec3 mid_color   : source_color = vec3(0.35, 0.30, 0.20); // dirt / scrub
uniform vec3 rock_color  : source_color = vec3(0.32, 0.30, 0.28); // exposed rock
uniform vec3 snow_color  : source_color = vec3(0.92, 0.94, 0.98); // snow cap

// ---------------------------------------------------------
// Slope
// ---------------------------------------------------------
// Steep faces read as rock regardless of height (cliffs poking through
// grass, snow that can't cling to a vertical face, etc).

group_uniforms Slope;
uniform float slope_rock_start : hint_range(0.0, 1.0) = 0.55; // dot(normal, up) below this = full rock
uniform float slope_rock_end   : hint_range(0.0, 1.0) = 0.80; // dot(normal, up) above this = no slope rock
uniform vec3  steep_rock_color : source_color = vec3(0.22, 0.20, 0.19); // darker, wetter-looking cliff rock

// ---------------------------------------------------------
// Surface variation
// ---------------------------------------------------------
// A noise texture breaks up the height bands so they don't look like
// perfectly flat contour lines painted on the mountain.

group_uniforms Surface_Detail;
uniform sampler2D detail_noise : hint_default_white, repeat_enable;
uniform float noise_scale = 0.02;       // World-space UV scale for the noise sample
uniform float noise_height_influence = 3.0; // How many meters the noise can shift a band boundary
uniform float noise_color_influence : hint_range(0.0, 1.0) = 0.15; // Subtle per-pixel color jitter

// ---------------------------------------------------------
// Material response
// ---------------------------------------------------------
group_uniforms Material_Response;
uniform float grass_roughness : hint_range(0.0, 1.0) = 0.9;
uniform float rock_roughness  : hint_range(0.0, 1.0) = 0.75;
uniform float snow_roughness  : hint_range(0.0, 1.0) = 0.35;
uniform float snow_specular   : hint_range(0.0, 1.0) = 0.5;


varying float world_y;
varying vec3 world_normal;
varying vec2 world_xz;

void vertex()
{
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_y = world_pos.y;
	world_xz = world_pos.xz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment()
{
	// Sample noise using world-space XZ so it doesn't stretch or slide
	// with the mesh's own UVs, and reads consistently across tiled terrain chunks.
	float noise = texture(detail_noise, world_xz * noise_scale).r; // 0..1
	float noise_signed = (noise - 0.5) * 2.0; // -1..1

	float sampled_height = world_y + noise_signed * noise_height_influence;

	// --- Height-based blend weights ---
	float low_to_mid  = clamp((sampled_height - base_height) / max(0.001, (rock_height - base_height)) * blend_sharpness - (blend_sharpness - 1.0) * 0.5, 0.0, 1.0);
	float mid_to_rock = clamp((sampled_height - rock_height) / max(0.001, (snow_height - rock_height)) * blend_sharpness - (blend_sharpness - 1.0) * 0.5, 0.0, 1.0);
	float rock_to_snow = clamp((sampled_height - snow_height) / max(0.001, 6.0) * blend_sharpness - (blend_sharpness - 1.0) * 0.5, 0.0, 1.0);

	vec3 height_color = mix(low_color, mid_color, low_to_mid);
	height_color = mix(height_color, rock_color, mid_to_rock);
	height_color = mix(height_color, snow_color, rock_to_snow);

	// --- Slope-based rock override ---
	float slope = clamp(dot(normalize(world_normal), vec3(0.0, 1.0, 0.0)), 0.0, 1.0);
	float slope_weight = 1.0 - smoothstep(slope_rock_start, slope_rock_end, slope);
	vec3 final_color = mix(height_color, steep_rock_color, slope_weight);

	// Snow can't cling to steep faces even if it's high enough — bias it back
	// toward rock on cliffs near/above the snow line.
	final_color = mix(final_color, steep_rock_color, slope_weight * rock_to_snow * 0.6);

	// Subtle per-pixel tint variation so large flat color bands don't look flat/painted.
	final_color *= 1.0 + (noise_signed * noise_color_influence);

	// --- Roughness varies by what's dominant on this pixel ---
	float roughness = mix(grass_roughness, rock_roughness, mid_to_rock);
	roughness = mix(roughness, snow_roughness, rock_to_snow * (1.0 - slope_weight));

	ALBEDO = final_color;
	ROUGHNESS = roughness;
	SPECULAR = mix(0.2, snow_specular, rock_to_snow * (1.0 - slope_weight));
	METALLIC = 0.0;
}
