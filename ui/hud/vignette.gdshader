shader_type canvas_item;

uniform vec4 vignette_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float intensity = 1.0;

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    float vignette = smoothstep(0.45, 0.75, dist) * intensity;
    COLOR = vignette_color;
    COLOR.a *= vignette;
}
