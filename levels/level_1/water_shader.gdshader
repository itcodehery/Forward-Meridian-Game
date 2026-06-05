shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec4 water_color : source_color = vec4(0.05, 0.45, 0.38, 0.85);
uniform vec4 water_deep : source_color = vec4(0.02, 0.22, 0.28, 1.0);
uniform vec4 foam_color : source_color = vec4(0.7, 1.0, 0.8, 1.0);

uniform float wave_speed = 0.6;
uniform float wave_frequency = 2.5;
uniform float wave_amplitude = 0.08;

uniform float foam_threshold = 0.72;
uniform float foam_noise_scale = 6.0;

uniform sampler2D normal_map_a : hint_normal;
uniform sampler2D normal_map_b : hint_normal;

uniform float normal_scroll_speed = 0.04;
uniform float normal_strength = 1.2;

uniform float fresnel_power = 3.0;
uniform float roughness = 0.08;
uniform float metallic = 0.1;

// Simple noise without a texture
float hash(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash(i), hash(i + vec2(1,0)), f.x),
        mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
        f.y
    );
}

void vertex() {
    vec2 uv = UV;
    float t = TIME * wave_speed;

    // Two overlapping sine waves for the surface
    float wave = sin(uv.x * wave_frequency + t) * wave_amplitude;
    wave += sin(uv.y * wave_frequency * 0.8 + t * 1.3) * wave_amplitude * 0.6;
    wave += sin((uv.x + uv.y) * wave_frequency * 1.2 + t * 0.7) * wave_amplitude * 0.4;

    VERTEX.y += wave;
}

void fragment() {
    vec2 uv = UV;
    float t = TIME;

    // Scroll two normal maps in opposite directions
    vec2 uv_a = uv + vec2(t * normal_scroll_speed, t * normal_scroll_speed * 0.7);
    vec2 uv_b = uv - vec2(t * normal_scroll_speed * 0.8, t * normal_scroll_speed * 1.1);

    vec3 n_a = texture(normal_map_a, uv_a * 3.0).rgb;
    vec3 n_b = texture(normal_map_b, uv_b * 3.0).rgb;
    vec3 combined_normal = normalize(mix(n_a, n_b, 0.5) * 2.0 - 1.0);

    // Fresnel for edge transparency / rim highlight
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
    fresnel = clamp(fresnel, 0.0, 1.0);

    // Noise-based foam patches
    float n = noise(uv * foam_noise_scale + vec2(t * 0.1, t * 0.07));
    float n2 = noise(uv * foam_noise_scale * 1.7 - vec2(t * 0.08, t * 0.12));
    float foam_mask = smoothstep(foam_threshold, 1.0, (n + n2) * 0.5);

    // Depth fade (shallow = brighter)
    vec4 base = mix(water_color, water_deep, 0.4 - fresnel * 0.4);

    // Add foam
    vec3 final_color = mix(base.rgb, foam_color.rgb, foam_mask * 0.6);
    // Add fresnel rim
    final_color = mix(final_color, foam_color.rgb * 0.9, fresnel * 0.3);

    ALBEDO = final_color;
    ALPHA = mix(water_color.a, 1.0, fresnel * 0.3);
    METALLIC = metallic;
    ROUGHNESS = roughness;
    NORMAL_MAP = combined_normal;
    NORMAL_MAP_DEPTH = normal_strength;
    SPECULAR = 0.9;
}