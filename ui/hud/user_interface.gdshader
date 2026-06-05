shader_type canvas_item;

// Visor shape
uniform float visor_curve : hint_range(0.0, 0.5) = 0.18;
uniform float visor_tilt : hint_range(-0.1, 0.1) = 0.02; // slight vertical asymmetry
uniform float visor_zoom : hint_range(0.5, 2.5) = 1.15;
// Realism
uniform float ca_strength : hint_range(0.0, 0.003) = 0.0008;
uniform float noise_strength : hint_range(0.0, 0.04) = 0.012;
uniform float edge_fade : hint_range(0.0, 0.6) = 0.22;
//uniform float brightness_flicker : hint_range(0.0, 0.02) = 0.006;

// The HUD texture from SubViewport
//uniform sampler2D hud_texture : filter_linear;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
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

vec2 visor_warp(vec2 uv, float k, float tilt) {
    vec2 c = uv - 0.5;
    // Slight vertical offset simulates visor sitting lower in FOV
    c.y -= tilt;
    float r2 = dot(c, c);
    // Pincushion distortion — pushes corners outward, reads as convex glass
	c *= 1.0 - k * r2 * 2.5;
	c *= visor_zoom;
    c.y += tilt;
    return c + 0.5;
}

void fragment() {
    vec2 uv = UV;

    // Warp UV for visor curvature
    vec2 warped = visor_warp(uv, visor_curve, visor_tilt);

    // Discard pixels that map outside the HUD texture (the "beyond the glass" area)
    if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
        COLOR = vec4(0.0);
        discard;
    }

// Micro CA on the warped HUD only
float ca = ca_strength;
vec2 r_uv = visor_warp(uv + vec2( ca,  ca * 0.4), visor_curve, visor_tilt);
vec2 b_uv = visor_warp(uv + vec2(-ca, -ca * 0.4), visor_curve, visor_tilt);

// Swap 'hud_texture' out for 'TEXTURE' here:
float r_ch = texture(TEXTURE, r_uv).r;
float g_ch = texture(TEXTURE, warped).g;
float b_ch = texture(TEXTURE, b_uv).b;
float a_ch = texture(TEXTURE, warped).a;

    vec4 color = vec4(r_ch, g_ch, b_ch, a_ch);

    // Edge fade — HUD elements dim toward screen edges like real visor glass
// Edge fade — correct version
vec2 edge = smoothstep(0.0, edge_fade, warped)
          * (1.0 - smoothstep(1.0 - edge_fade, 1.0, warped));
float fade = edge.x * edge.y;
color.a *= fade;
color.rgb *= fade; // ← add this line, it was missing

    // Grain on the HUD surface only
    float grain = noise(uv * vec2(320.0, 180.0) + fract(TIME * 0.5) * 17.3);
    color.rgb += (grain - 0.5) * noise_strength * color.a; // only where HUD is visible

    //// Subtle flicker
    //float flicker = 1.0 + brightness_flicker
        //* sin(TIME * 47.3 + hash(vec2(TIME, 0.0)) * 6.283);
    //color.rgb *= flicker;

    COLOR = color;
}