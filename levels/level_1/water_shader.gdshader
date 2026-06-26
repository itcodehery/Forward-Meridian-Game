shader_type spatial;
render_mode specular_schlick_ggx, blend_mix;

// --- Colors ---
uniform vec4 base_water_color : source_color = vec4(0.25, 0.82, 0.65, 0.9); // Mint green
uniform vec4 patch_color : source_color = vec4(0.85, 0.95, 0.90, 1.0);      // Whitish foam/patches

// --- Cartoony Patches ---
uniform sampler2D patch_noise;
uniform float patch_scale = 5.0;
uniform float patch_threshold = 0.55;
uniform vec2 patch_pan_speed = vec2(0.015, 0.01);

// --- Realistic Lighting & Ripples ---
uniform sampler2D wave_normal_1 : hint_normal;
uniform sampler2D wave_normal_2 : hint_normal;
uniform vec2 wave_dir_1 = vec2(0.04, 0.02);
uniform vec2 wave_dir_2 = vec2(-0.03, 0.05);
uniform float wave_strength = 0.7;
uniform float water_roughness = 0.05; // Extremely low roughness for sharp, realistic reflections

void fragment() {
    // 1. GENERATE THE CARTTOONY BASE
    // Pan the UV coordinates over time for the patches to drift
    vec2 patch_uv = UV * patch_scale + (TIME * patch_pan_speed);
    
    // Sample the noise texture
    float noise_val = texture(patch_noise, patch_uv).r;

    // The magic trick for the "cartoony" look: 
    // step() forces the noise to be either completely 0.0 or 1.0, removing all gradients.
    float is_patch = step(patch_threshold, noise_val);

    // Apply the colors based on that sharp noise mask
    ALBEDO = mix(base_water_color.rgb, patch_color.rgb, is_patch);
    ALPHA = mix(base_water_color.a, patch_color.a, is_patch);

    // 2. LAYER THE REALISTIC LIGHTING
    // Pan two normal maps in different directions at different speeds
    vec2 wave_uv_1 = UV + (TIME * wave_dir_1);
    vec2 wave_uv_2 = UV + (TIME * wave_dir_2);

    vec3 normal_1 = texture(wave_normal_1, wave_uv_1).rgb;
    vec3 normal_2 = texture(wave_normal_2, wave_uv_2).rgb;

    // Blend the normal maps to create complex, non-repeating realistic water ripples
    NORMAL_MAP = mix(normal_1, normal_2, 0.5);
    NORMAL_MAP_DEPTH = wave_strength;

    // Apply PBR properties for that realistic AAA shine
    ROUGHNESS = water_roughness;
    METALLIC = 0.0;
}