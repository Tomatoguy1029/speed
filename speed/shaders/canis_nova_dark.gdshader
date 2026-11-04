shader_type canvas_item;
render_mode unshaded;

uniform float strength = 0.0;

void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float mask = clamp((1.0 - radius) / 0.85, 0.0, 1.0);
	COLOR = vec4(vec3(2.0, 4.0, 12.0) / 255.0, strength * mask);
}
