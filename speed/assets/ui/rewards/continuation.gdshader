shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float chain_step = 2.0;
uniform float elapsed = 0.0;

void fragment() {
	vec2 p = (UV - vec2(0.5, 0.42)) * vec2(1.78, 1.0);
	float r = length(p);
	float a = atan(p.y, p.x);
	float gather = 1.0 - smoothstep(0.0, 0.32, progress);
	float release = smoothstep(0.20, 0.85, progress);
	float radius = mix(0.46, 0.13, 1.0 - gather) + release * 0.43;
	float ring = exp(-abs(r - radius) * 95.0);
	float halo = exp(-abs(r - radius) * 18.0);
	float spokes = pow(max(0.0, sin(a * 14.0 + r * 24.0 - elapsed * 3.0)), 14.0);
	float filaments = spokes * exp(-abs(r - mix(0.3, 0.1, progress)) * 12.0);
	float lens = exp(-abs(p.y) * 130.0) * exp(-abs(p.x) * 3.0);
	float core = exp(-r * 16.0);
	float envelope = smoothstep(0.0, 0.10, progress) * (1.0 - smoothstep(0.65, 1.0, progress));
	vec3 gold = mix(vec3(0.20, 0.79, 0.91), vec3(1.0, 0.65, 0.16), (chain_step - 2.0) * 0.5);
	vec3 light = gold * (halo * 0.65 + filaments * 0.8 + core * 0.25);
	light += vec3(1.0, 0.94, 0.72) * (ring * 1.4 + lens * release);
	COLOR = vec4(light, clamp((halo + filaments + lens + core) * envelope, 0.0, 0.9));
}
