shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.12) = 0.025;
uniform float line_count : hint_range(120.0, 1000.0) = 420.0;

void fragment() {
	float scan = step(0.52, fract(UV.y * line_count));
	COLOR = vec4(vec3(0.0), scan * strength);
}
