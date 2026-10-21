shader_type canvas_item;
render_mode unshaded;
uniform float progress : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.52)) * vec2(1.78, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float gather = smoothstep(0.0, 0.55, progress);
	float release = smoothstep(0.48, 1.0, progress);
	float wave = sin(a * 9.0 + r * 22.0 + progress * 6.0);
	float silk = pow(max(0.0, wave), 12.0) * exp(-r * 2.6);
	float column_width = mix(0.34, 0.025, gather) + release * 0.06;
	float column = exp(-abs(p.x) / column_width) * (0.5 + 0.5 * exp(-abs(p.y) * 2.0));
	float radius = mix(0.58, 0.14, gather) + release * 0.45;
	float corona = exp(-abs(r - radius) * 35.0);
	float core = exp(-r * 14.0) * gather;
	float rays = pow(max(0.0, cos(a * 5.0 - progress)), 20.0) * exp(-r * 5.0) * release;
	float fade = smoothstep(0.0, 0.14, progress) * (1.0 - smoothstep(0.76, 1.0, progress));
	vec3 gold = vec3(1.0, 0.63, 0.20);
	vec3 light = gold * (silk * 0.8 + column * 0.45 + corona * 0.5);
	light += vec3(1.0, 0.95, 0.76) * (core + rays + corona * 0.65);
	COLOR = vec4(light, clamp((silk + column + core + corona + rays) * fade, 0.0, 0.9));
}
