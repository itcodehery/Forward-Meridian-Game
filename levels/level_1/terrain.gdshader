shader_type spatial;

uniform float min_height = 0.0;
uniform float max_height = 2.0;
uniform vec3 low_color : source_color = vec3(0.1, 0.0, 0.1);
uniform vec3 high_color : source_color = vec3(0.9, 0.8, 0.8);

varying float world_y;

void vertex() {
    // Use local vertex height so the gradient scales naturally with the object
    world_y = VERTEX.y;
}

void fragment() {
    // Use the world_y we calculated in the vertex function
    float weight = clamp((world_y - min_height) / (max_height - min_height), 0.0, 1.0);
    
    ALBEDO = mix(low_color, high_color, weight);
}