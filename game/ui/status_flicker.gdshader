shader_type canvas_item;

uniform float strength : hint_range(0.0, 0.15) = 0.035;
uniform float speed : hint_range(0.1, 8.0) = 2.0;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * speed + UV.y * 18.0);
	float flicker = 1.0 - strength * pulse;
	COLOR = texture(TEXTURE, UV) * vec4(vec3(flicker), 1.0);
}
