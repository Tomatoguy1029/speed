// Five-point iris adapted from pixelfx a841596, Copyright 2026 Patch / Hugo Duprez, MIT.
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
uniform float easing_power = 1.15;
uniform float glow_strength = 0.22;
uniform float glow_width = 12.0;
uniform float inner_ratio = 0.46;
uniform float spin_turns = 0.32;
uniform vec4 transition_color : source_color = vec4(0.745, 0.447, 0.612, 1.0);
uniform vec4 highlight_color : source_color = vec4(0.980, 0.843, 0.937, 1.0);
uniform vec4 ink_color : source_color = vec4(0.094, 0.055, 0.153, 1.0);

vec2 point_at(int i, float radius, float turn) {
	float angle = turn + float(i) * PI / 5.0;
	float r = radius * (i % 2 == 0 ? 1.0 : inner_ratio);
	return vec2(cos(angle), sin(angle)) * r;
}


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
	vec2 p = (floor(UV * design_size / pixel_size) + 0.5) * pixel_size - focus * design_size;
	float u = clamp(progress, 0.0, 1.0);
	float eased = u < 0.5 ? 4.0 * u * u * u : 1.0 - pow(-2.0 * u + 2.0, 3.0) / 2.0;
	eased = pow(transition_easing == 0 ? eased : shaped(u), easing_power);
	float radius = (length(max(focus, vec2(1.0) - focus) * design_size) / inner_ratio + rim_width * 3.0) * eased;
	float turn = -PI / 2.0 - eased * spin_turns * TAU;
	bool inside = false;
	float edge = 100000.0;
	for (int i = 0; i < 10; i++) {
		vec2 a = point_at(i, radius, turn);
		vec2 b = point_at((i + 1) % 10, radius, turn);
		vec2 e = b - a;
		float nearest = clamp(dot(p - a, e) / max(dot(e, e), 0.00001), 0.0, 1.0);
		edge = min(edge, length(p - a - e * nearest));
		if ((a.y > p.y) != (b.y > p.y)) {
			if (p.x < a.x + (p.y - a.y) * e.x / e.y) { inside = !inside; }
		}
	}
	vec3 color = source_ui.rgb;
	float alpha = inside ? 0.0 : source_ui.a;
	if (!inside && edge < rim_width) {
		color = edge < rim_width * 0.32 ? highlight_color.rgb : transition_color.rgb;
		alpha = (edge < rim_width * 0.32 ? highlight_color.a : transition_color.a) * transition_opacity * (1.0 - u);
	}
	float light = pow(max(0.0, 1.0 - edge / glow_width), 2.0) * glow_strength * (1.0 - u);
	if (!inside && edge >= rim_width) {
		color = source_ui.a > 0.0 ? mix(source_ui.rgb, transition_color.rgb, light) : transition_color.rgb;
		alpha = max(alpha, light * transition_color.a * transition_opacity);
	}
	COLOR = u >= 1.0 ? vec4(0.0) : vec4(color, alpha);
	}
}
