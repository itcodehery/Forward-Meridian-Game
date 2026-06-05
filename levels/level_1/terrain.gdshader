shader_type spatial;

uniform float min_height = 0.0;
uniform float max_height = 2.0;
uniform vec3 low_color : source_color = vec3(0.4, 0.6, 0.9);
uniform vec3 high_color : source_color = vec3(0.9, 0.8, 0.8);

varying float world_y;

void vertex() {
    // This calculates the vertex position relative to the whole world
    world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
    // Use the world_y we calculated in the vertex function
    float weight = clamp((world_y - min_height) / (max_height - min_height), 0.0, 1.0);
    
    ALBEDO = mix(low_color, high_color, weight);
}