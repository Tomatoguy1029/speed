// Iris opening adapted from pixelfx a841596, Copyright 2026 Patch / Hugo Duprez, MIT.
// See assets/ui/rewards/pixelfx_LICENSE.txt and pixelfx_NOTICE.txt.
shader_type canvas_item;
render_mode unshaded;

uniform float progress = -1.0;
uniform vec4 dim_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float dim_amount = 0.54;
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
	vec4 source_ui = texture(TEXTURE, UV);
	source_ui.rgb = mix(source_ui.rgb, dim_color.rgb, dim_amount * dim_color.a);
	if (progress < 0.0) { COLOR = source_ui; } else {
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
	vec3 color = source_ui.rgb;
	float alpha = outside ? source_ui.a : 0.0;
	if (outside && edge < rim_width) {
		color = edge < rim_width * 0.32 ? highlight_color.rgb : transition_color.rgb;
		alpha = (edge < rim_width * 0.32 ? highlight_color.a : transition_color.a) * transition_opacity * (1.0 - u);
	}
	float light = pow(max(0.0, 1.0 - edge / glow_width), 2.0) * glow_strength * (1.0 - u);
	if (outside && edge >= rim_width) {
		color = source_ui.a > 0.0 ? mix(source_ui.rgb, transition_color.rgb, light) : transition_color.rgb;
		alpha = max(alpha, light * transition_color.a * transition_opacity);
	}
	COLOR = u >= 1.0 ? vec4(0.0) : vec4(color, alpha);
	}
}
