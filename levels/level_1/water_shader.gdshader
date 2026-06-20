shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 water_color : source_color = vec4(0.0, 0.95, 0.65, 0.85);
uniform vec4 foam_color : source_color = vec4(0.95, 1.0, 0.95, 1.0);

uniform float wave_speed = 0.5;
uniform float wave_frequency = 2.0;
uniform float wave_amplitude = 0.1;

uniform float foam_threshold = 0.55;
uniform float foam_noise_scale = 15.0;

// Simple random and noise
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for(int i = 0; i < 3; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void vertex() {
    float t = TIME * wave_speed;
    float wave = sin(VERTEX.x * wave_frequency + t) * wave_amplitude;
    wave += cos(VERTEX.z * wave_frequency * 0.8 + t * 1.3) * wave_amplitude * 0.8;
    VERTEX.y += wave;
}

void fragment() {
    vec2 uv = UV * foam_noise_scale;
    float t = TIME * wave_speed * 0.5;
    
    // Distort UVs slightly with time
    vec2 distorted_uv = uv + vec2(t, t * 0.8);
    
    // Generate noise value
    float n = fbm(distorted_uv);
    
    // Create hard edge for foam using step
    float foam = step(foam_threshold, n);
    
    // Mix the base water color and foam color based on the mask
    vec4 final_color = mix(water_color, foam_color, foam);
    
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}