// Iris opening adapted from pixelfx a841596, Copyright 2026 Patch / Hugo Duprez, MIT.
// See assets/ui/rewards/pixelfx_LICENSE.txt and pixelfx_NOTICE.txt.
shader_type canvas_item;
render_mode unshaded;

uniform float progress = 0.0;
uniform int transition_easing = 0;
uniform float transition_opacity = 1.0;
uniform vec2 design_size = vec2(640.0, 360.0);
uniform vec2 focus = vec2(0.5, 0.44);
uniform float pixel_size = 2.0;
uniform float rim_width = 3.0;
uniform float easing_power = 1.0;
uniform float glow_strength = 0.22;
uniform float glow_width = 12.0;
uniform vec4 transition_color : source_color = vec4(0.357, 0.784, 0.859, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.878, 0.969, 1.0, 1.0);


float shaped(float u) {
	int mode = transition_easing - 1;
	if (mode == 1) return 1.0 - pow(1.0 - u, 3.0);
	if (mode == 2) return u < 0.5 ? 4.0 * u * u * u : 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0;
	if (mode == 3) return 1.0 - pow(1.0 - u, 4.0);
	if (mode == 4) return u * u * u;
	return u;
}

void fragment() {
	vec2 p = (floor(UV * design_size / pixel_size) + 0.5) * pixel_size;
	vec2 center = focus * design_size;
	vec2 extent = max(center, design_size - center);
	float far_radius = length(extent) + rim_width * 3.0;
	float u = clamp(progress, 0.0, 1.0);
	float eased = transition_easing == 0 ? 1.0 - pow(1.0 - u, 4.0) : shaped(u);
	float radius = far_radius * pow(eased, easing_power);
	float distance_to_rim = length(p - center) - radius;
	float edge = abs(distance_to_rim);
	bool outside = distance_to_rim >= 0.0;
	// TEXTURE is the incoming background; card and badge keep independent clocks.
	// The old dimmed view stays
	// visible outside the aperture. No solid black cover or unrelated circle UI.
	vec4 incoming = texture(TEXTURE, UV);
	vec3 color = incoming.rgb;
	float alpha = outside ? 0.0 : incoming.a;
	if (outside && edge < rim_width) {
		color = edge < rim_width * 0.32 ? highlight_color.rgb : transition_color.rgb;
		alpha = (edge < rim_width * 0.32 ? highlight_color.a : transition_color.a) * transition_opacity * (1.0 - u);
	}
	float light = pow(max(0.0, 1.0 - edge / glow_width), 2.0) * glow_strength * (1.0 - u);
	if (outside && edge >= rim_width) {
		color = transition_color.rgb;
		alpha = light * transition_color.a * transition_opacity;
	}
	COLOR = u >= 1.0 ? incoming : vec4(color, alpha);
}
