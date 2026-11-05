shader_type canvas_item;
render_mode unshaded, blend_add;
uniform bool eye = false;

void fragment() {
	float r = length((UV - vec2(0.5)) * 2.0);
	if (r >= 1.0) discard;
	vec4 center = eye ? vec4(1.0, 240.0 / 255.0, 200.0 / 255.0, 1.0) : vec4(1.0, 150.0 / 255.0, 40.0 / 255.0, 0.55);
	vec4 outer = vec4(1.0, 90.0 / 255.0, 20.0 / 255.0, 0.0);
	vec4 col;
	if (eye && r < 0.35) col = mix(center, vec4(1.0, 170.0 / 255.0, 50.0 / 255.0, 1.0), r / 0.35);
	else if (eye) col = mix(vec4(1.0, 170.0 / 255.0, 50.0 / 255.0, 1.0), outer, (r - 0.35) / 0.65);
	else col = mix(center, outer, r);
	COLOR = col * COLOR;
}
